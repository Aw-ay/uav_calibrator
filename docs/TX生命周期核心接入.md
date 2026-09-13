# 发送生命周期的仪器核心接入

DDS、AWG、REPLAY 共用 tx_task_lifecycle 和64位生命周期令牌，输出接入原统一 EVENT。旧 SOURCE_EVENT 仍只描述 DDS/AWG 源完成；它与完整数字尾部完成、接收端确认含义不同。

## 实际信号与所有权

DDS/AWG 使用真实 accepted/done/sources_drained。REPLAY 使用 frozen_replay_reader 的实际 task_started，提交成功仅表示入队；读口归还从真实 bank token valid/ready 产生，随后观察 RXCAL/FD63/Target 是否排空，最后等待共用 TX FIR tail_empty。

bank 读取引用在真实读取结束后归还，不因等待 FIR 或接收端确认而延长。首样点前取消没有正常 DSP done 也可完成排空；欠载或 DSP 取消保留 REPLAY_ABORT=4，STOP/安全等已有原因仍按首个非零原因保留。

新 DDS/AWG、非静音模式切换和 REPLAY 实际派发使用共同生命周期容量。回放容量限制加在 processing_ready，不关闭合法性评估；过期或上下文不匹配仍拒绝，不能移动目标 GSC。紧急静音不等待这些准入条件。

## 事件顺序与软件关联

DDS/AWG 输出一个 TX_DIGITAL_RETIRE。REPLAY 先输出 REPLAY_IDENTITY(tag0x60001)，再输出同token的 TX_DIGITAL_RETIRE(source3、command_sequence0)。身份事件保留64位task_id、pulse_id、owner_epoch、generation，以及config/fir/source epoch和bank位置；不得用32位command_sequence代替回放任务号。

身份不等于完成。软件在同一协调复位域内按token关联两种记录。RF_FAULT 可插入两者之间；共享发布器保证身份先进入通道，已呈现记录不被抢占。统一读取器分别提供 CAL_UE_REPLAY_IDENTITY 与 CAL_UE_TX，显式POP，未知/坏格式保留原始数据。

TX记录先于新的PDW准入，外层RF_FAULT仍最高准入优先级。长时间故障或PS不取EVENT会限制后续发送；ADC/RAW不因此背压，普通PDW满缓冲仍按既有策略计数丢弃。

## 逻辑接收适配接口

所有信号属于rf_clk域，板级适配器负责实际跨域及消费证据，不能直接接异步GPIO。

|信号|约定|
|---|---|
|tx_sink_binding_valid|任务接受时采样；无绑定置0，只报告数字排空|
|tx_sink_fence_valid/token|源与数字尾部排空后提供任务令牌，保持至ready握手|
|tx_sink_fence_ready|适配器接受请求，不等于消费完成|
|tx_sink_ack_valid/token|请求接受后或同周期，以相同token确认此前数据已消费|
|tx_sink_protocol_error|错误/过早ACK或内部生命周期准入、身份、读取归还协议错误脉冲|

没有合法ACK时持续等待，不伪造超时成功。硬复位清空全部状态并重新开始token；接收适配器必须同复位丢弃旧ACK。软复位保留已跟踪任务和待发记录。接收绑定与RF安全绑定分别定义，不得互相替代。

## 验证和边界

实际仪器TB核验RAW所有权、全64位任务号、数字退休和软复位保留；另一独立测试通过真实STOP在首样点前取消，要求零回放样点、bank归还和中止记录。绑定回放测试延迟13拍接受fence，并在等待期间核验bank读取引用已经释放，最后核对精确token确认记录。DDS/AWG保留七任务、错误ACK、延迟接收及40次故障聚合测试。

这些都是数字逻辑证据。真实RFDC/DAC消费适配器、模拟RF输出和整机布局布线验收仍待板级证据。
