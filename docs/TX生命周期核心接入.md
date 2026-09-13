# DDS/AWG 发送生命周期的仪器核心接入

本批次接入 DDS/AWG。REPLAY 的完整任务身份和退休事件尚未接入；常量中的 REPLAY=3 不能视为已实现。原 SOURCE_EVENT 查询记录描述源完成，统一 EVENT 中的 TX_DIGITAL_RETIRE 描述数字尾部及可选接收端确认，两者不可互换。

## 数据和准入

实际 dds_accepted / awg_play_accepted 捕获源类型、命令序号、已生效配置 ID 和 GSC。实际 done、sources_drained、TX tail_empty 三项共同限定数字排空。新 DDS/AWG 任务以及非静音模式切换同时受 lifecycle_ready 限制；未确认或待发事件占用时拒绝准入，不以丢失完成记录换取连续发送。STOP、MUTE 和硬故障静音仍立即生效。

TX 记录先与 PDW 仲裁，再进入原 RF_FAULT 优先通道。RF_FAULT 在新记录准入时优先于 TX，TX 优先于 PDW，已呈现记录保持稳定而不被抢占。长期故障或软件不取 EVENT 可能阻塞 TX 完成记录并限制后续发送；普通 PDW 仍采用有限队列及丢弃计数，ADC/RAW 不因此背压。

## 接收端逻辑适配接口

以下信号均属 rf_clk 域，实际板级适配器必须负责跨域和物理消费证据，不能直接接异步 GPIO。

|信号|约定|
|---|---|
|tx_sink_binding_valid|在任务接受时采样，决定本任务是否必须取得接收端确认；无绑定时置0|
|tx_sink_fence_valid / token|数字尾部排空后提供本次唯一64位令牌，保持直到 ready 握手|
|tx_sink_fence_ready|适配器接受该令牌的握手，并非消费完成本身|
|tx_sink_ack_valid / token|仅在接受令牌之后或同周期，以相同令牌确认本任务此前数据已经消费|
|tx_sink_protocol_error|错误、过早或当前无待确认任务的 ACK 产生一个 RF 周期错误脉冲，需板级适配器观测|

无绑定时仅产生 DIGITAL_DRAINED，SINK_CONFIRMED=0。需要确认但没有合法 ACK 时持续等待，不超时伪造成功。硬复位清除状态并重启令牌，适配器必须同复位清除所有旧确认；软复位不丢弃已跟踪任务和待发记录。接收端绑定有效不等于 RF 安全绑定有效，两者职责独立。

## 软件

沿用 EVENT_COUNT/LATCH/WORD/POP 以及 IRQ bit4，64字节格式来自 contracts/tx_lifecycle_event.json。cal_unified_event_fetch 将该格式解码为 CAL_UE_TX，显式 POP 才移除。命令完成 IRQ 不等于发送退休，旧 SOURCE_EVENT 也不能替代 TX 退休记录。

## 验证范围

仪器 TB 使用明确标注的仿真接收端：首任务延迟接受令牌，注入过早错误 ACK，检查等待期间不能准入新任务，随后正确确认。七个实际 DDS/AWG 任务逐字段检查类型、原因、命令/配置身份、令牌、时间顺序和保留位；40次真实故障边沿仍被统一通道计数保留。该验证不证明实际 RFDC、DAC 或射频前端消费完成。
