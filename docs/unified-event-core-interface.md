# 仪器核心统一 EVENT 接口

`calibrator_instrument_core` 的既有 AXI 命令网关同时提供以下寄存器。地址常量仍来自 `contracts/register_map.json`，IRQ 常量来自 `contracts/command_gateway.json`。

| 地址 | 用途 |
|---|---|
| 0x0300 | EVENT_COUNT：ctrl 队列中的完整记录数，不含 RF 侧待发送记录 |
| 0x0304 | EVENT_LATCH：写 1 锁存队首，不删除；空队列返回 SLVERR |
| 0x0308 | EVENT_POP：写 1 删除已锁存的队首；没有锁存时返回 SLVERR |
| 0x0340–0x037C | EVENT_WORD_0–15：读取锁存的 512bit 记录，未锁存时返回 SLVERR |
| 0x0408 | DROP_EVENT：普通 EVENT 缓冲溢出的饱和计数，经跨域握手采样，允许延迟 |
| 0x4020 / 0x4024 bit4 | 统一 EVENT 非空中断使能 / 原始状态；默认不使能 |

收到非空中断后，软件按 COUNT→LATCH→16 字快照→解析处理→显式 POP 的顺序操作。`cal_unified_event_fetch/pop` 可用于这一流程；仍需板级软件提供完成且有序的 MMIO 回调以及 GIC 配置。一次只允许一个软件所有者操作队列，并与复位协调。POP 回调失败可能已经删除记录，读取器会保留快照并禁止自动重试，必须由外部核实或协调复位后恢复。

当前记录类型为 CAPTURE_PDW（0x00010001）和 RF_FAULT_AGGREGATE（0x00040001）。PDW 来自实际最终资格统计，普通通知满时可以丢弃并计数，不能反压 ADC/RAW。RF_FAULT 直接观察实际联锁锁存上升沿，在旧故障历史队列溢出时仍送到保留器；聚合保存首快照与次数，次数饱和时表示下界，不保证每次故障的完整快照。

旧 CMD_PDW_PEEK/POP、CMD_RF_FAULT_PEEK/POP 及其 IRQ 保持独立。兼容期同一观测可在两个接口中分别读取，调用方应选择自己的消费路径，避免把它们误计为两次物理事件。旧接口 POP 不删除统一事件，统一 POP 也不解除安全锁存。

采集软 RESET、STOP、清故障和命令 DONE 清除均不清统一事件队列；协调硬复位清空所有缓存及计数。COUNT 为零或 IRQ 降低仅表示 ctrl 队列当前为空，RF 侧在途记录可能随后到达。

此接口尚不包含完整 TX/DAC 生命周期、AUX、FIR 系数生命周期事件；它也不代表实际 DAC/RF 输出完成或板级验收。
