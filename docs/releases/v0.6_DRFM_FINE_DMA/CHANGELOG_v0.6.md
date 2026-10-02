# v0.6 变更说明

基于 GitHub `feature/module-first-validation` / `e428b1fc196ba05701cb367560a0b181c3065ae1` 与 v0.5 框架，v0.6 只聚焦 DRFM、Fine、B口和DMA，不借机重写无关模块。

## 1. 取消的旧设计

1. 活动 DRFM 不再使用 `fractional_delay_profile/FD63`；删除其profile/version/62点flush等关键路径依赖。
2. 正常捕获路径不再用 A口 `capture_statistics_reader` 完整扫描作为DRFM/Fine准入前提；该模块可暂留诊断/回归用途。
3. `frozen_record_reader.sv` 的 128→64 串行化结构退出活动DMA链。
4. v0.5“奇数起点统一carry拼接后再给所有消费者”的设计被替换为自然B word + mask；Fine不做跨word重排。
5. Fine不再默认放host，也不允许占A口；改为PL B口一遍流式精测。
6. `record_ref` 不再同时代表分析与上传；明确拆成三种引用。

## 2. 新的关键模块边界

- `b_port_reader_128.sv`：只解决连续B口地址、真实读延迟、inflight credit和prefetch。
- `b_port_access_fabric.sv`：允许Fine(bank X)与DMA(bank Y)并行，禁止同bank双主访问。
- `dma_payload_packer.sv`：只在DMA支路把mask后的逻辑64-bit样点紧凑为128-bit payload。
- `fine_measurement_engine.sv`：一套全局引擎，H/V并行，主三档顺序处理。
- `fine_result_queue.sv`：Fine sidecar独立于RAW和粗 `CAPTURE_PDW`。

## 3. Fine算法定义变化

- H/V独立：`PH=IH²+QH²`，`PV=IV²+QV²`。
- 在线同时保留 raw peak 与用于边沿的 TOP estimate；TOP默认采用4样点移动平均后的最大净功率，避免单点过冲抬高50%门限。
- `P50 = N + TOP_signal/2`，严格是半功率(-3.0103 dB)。
- Fine一遍RAM扫描；16–32 sample局部delay buffer确保最终8点边沿仍可决定后续PDW统计窗口。
- timing PDW使用50%边沿；频率/chirp/HV相位使用边沿内缩后的 stable body window。
- residual frequency是固定RFDC NCO后的基带残余频率；chirp斜率不会被固定NCO消除。

## 4. DMA定义变化

- RAW frame ABI v5不变；Fine不得裁RAW。
- 128-bit payload路径一直保持到AXIS；不再reader先拆64、formatter再拼128。
- 奇数payload与16-byte trailer继续满足原ABI“无未声明padding”的打包规则。
- B口理论3.2GB/s只表示RAM物理峰值；系统验收必须报告实测持续Bps。

## 5. 兼容性

- `fraction_q32` 暂时保留在192-byte replay task以避免无必要ABI破坏，但只允许0；非0必须在任何RAM访问前拒绝。
- RAW `frame_format.json` ABI版本保持5。
- Fine PDW采用新的128-byte sidecar格式和独立PEEK/POP，不修改RAW header。
- v0.5未受影响的FIR整数系数和数据位宽继续有效。
