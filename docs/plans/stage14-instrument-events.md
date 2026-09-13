# 第十四阶段：统一 EVENT 仪器核心集成

在现有 command_gateway_axi 的 AXI 地址空间实现 register_map 中的 EVENT_COUNT/LATCH/POP/WORD_0..15/DROP_EVENT，不并入另一个配置控制器。IRQ bit4 同源定义为 UNIFIED_EVENT_AVAILABLE，默认仍只使能命令完成。第十三阶段可选 CSR 模式作为独立兼容组件保留。

真实资格 PDW 同时进入旧查询队列和新的独立普通 EVENT 队列；两者各自出队，缓冲满时丢弃普通通知并饱和计数，绝不反压 ADC/RAW。统一缓冲 head 保持到仲裁 ready，复用 qualified_pdw_queue 的格式/令牌校验。DROP_EVENT 是通过握手传送并在 ctrl 域锁存的延迟一致快照，不是逐位同步的多位计数器。

真实 rf_fault_queue 的前端上升沿和同一时刻逻辑快照直接送到 fault_event_retainer，独立于旧历史队列是否接收成功。仍只表示联锁锁存上升沿观测，非所有硬件根因；聚合保留首快照和次数，饱和为下界。软采集复位/清故障/旧队列 POP 均不清统一 EVENT；协调硬复位清空。

- [x] 真实 ADC/FIR/RAW 测试扩展后，旧核心拒绝 IRQ bit4，得到预期失败。
- [x] 完成生产端、队列、网关寄存器及 IRQ 接线，更新同源 IRQ 合同与 C 接口。
- [x] 定向仪器核心检查 PDW 与 RAW 推导结果逐字一致、旧 POP 独立、软复位保留。
- [x] 实际 RF 联锁 40 次上升沿，旧历史队列溢出后统一 EVENT 仍保留全部发生次数。
- [x] 完整回归、A53 构建和 Vivado XSim。
- [x] 完整数字核心综合、时序/CDC 审查、工程源清单更新、输入哈希与证据归档。

本批次完成的是 PDW/RF_FAULT 统一通道。完整 TX/DAC 生命周期、AUX 和 FIR 系数生命周期的后续事件仍需各自开发后接入。板级 IP/GIC/BSP/真实 RF 参数和布局布线验收不属于本次数字核心综合结论。
