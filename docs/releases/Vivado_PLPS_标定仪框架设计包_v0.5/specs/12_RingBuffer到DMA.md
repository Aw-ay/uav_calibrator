# 12 RingBuffer → DMA

```text
所选/诊断/独立AUX冻结bank
 → 引用预留 → descriptor异步FIFO(125→200)
 → 按记录round-robin仲裁并锁定源
 → frozen_frame_reader：B口128bit@200MHz，解环/奇数carry
 → formatter：128B header + IQ + 可选16B CRC trailer
 → AXIS FIFO4096×128，非packet-mode
 → AXI DMA S2MM+普通SG
 → M_AXI_S2MM和M_AXI_SG经SmartConnect → HP0 DDR
 → 软件接收池 → 存储/host
```

reader按ready/credit控制读请求，已发RAM请求需要暂存；当前record最后握手前不切组。所有有效字节连续打包，N奇数的IQ末尾不提前TLAST。RAW由B口读取，不先经一条125→200全吞吐FIFO。

原始脉冲数据只在捕获完成冻结后进入服务队列。例120us完整四组共480576Byte，在假设2.4GB/s服务下需200.24us纯搬运，最末不早于320.24us绝对时刻；多bank允许与下一捕获重叠。不能只用平均小于峰值就证明任意停顿不丢记录。

DMA保持128bit@200MHz理论3.2GB/s，实际Bps待测；256KiB槽×512。普通SG支持软件轮转但不等于cyclic覆盖。每槽只有用户release后才能重交DMA；descriptor64B对齐和buffer64B对齐目标（DRE关闭）；长度按实际BD+header交叉核对。CRC/sequence或DMA错误生成lost事件，不假装host已收到。

READER_DONE表示RAW不再被上传端读取，不等DDR完成；跟本地replay_ref共同决定bank归还。若策略要求失败可重试，则RAW需保留到更晚确认，重算hold-time。慢SSD长期速率低于平均输入时，任何有限环最终会满。
