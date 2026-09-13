# 第十三阶段：统一 EVENT 接入 AXI CSR

本阶段为统一 EVENT 批次的 CSR 子组件集成，沿用第二分支分层验证节奏，不修改仪器主顶层及 RF 物理绑定。

`csr_control_axi` 增加 `UNIFIED_EVENTS` 参数（默认 0）及 RF 故障脉冲/256bit 快照输入。参数为 1 时，内部使用既有 `fault_event_transport`，普通流遵守 valid/ready 保持协议；参数为 0 时保持旧单周期事件尝试语义，故障输入忽略。`EVENT_ADDR_W` 默认 4，生产候选深度 16；定向压力仿真使用深度 2。

保持已有 EVENT_COUNT/LATCH/WORD_0..15/POP 地址、AXI 响应与 WSTRB 语义。故障脉冲来自 RF 域的逻辑观测；不将 ctrl 域 fault_set 直接作为跨域事件源。故障优先只影响仲裁准入，不抢占已经呈现的普通记录。

- [x] 先建立新参数/接口测试，确认旧实现无法 elaboration。
- [x] 增加可选统一通道，保留旧模式回归。
- [x] 定向 TB：满队列、40 次故障计数/首快照守恒、4 条普通记录、正反字序和重复 LATCH、W 先于 AW、B/R 等待稳定、非法命令/WSTRB、POP 恰好一次、协调复位。
- [x] 相关回归与 Vivado XSim。
- [x] Vivado 2025.2 局部综合，检查资源、时序、CDC 和约束覆盖后归档。

后续仍需主顶层生产端和中断连接，完成统一 EVENT 关联批次后运行完整数字核心综合。当前 CSR 的 tx_enable 固定零是原有保守行为，未新增发射使能路径。旧模式默认值不代表主工程已启用统一 EVENT。
