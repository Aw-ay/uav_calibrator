# v0.6 无 FD 回放链

活动回放现为 `replay_reader → RXCAL → Target`。删除了 FD63 实例、系数表匹配、31样点群延时与62点输入补零；不以phase=0伪装旁路。原FD实现及旧64位上传reader/formatter保留为历史独立测试，原Vivado工程将其排除出综合源集合，新全核心脚本不读取这些源，并在综合后检查没有FD实例。

## ABI、所有权与安全

192字节任务布局不变，`fraction_q32`仅允许0。即使外部旧`fractional_supported`输入为1，也不能授权非零fraction；合法上下文下返回现有原因码6（LATENCY_OR_FRACTION），在任何RAM读取前拒绝。其他安全/上下文错误仍保持原拒绝优先级。

旧FD配置引脚和寄存器地址为兼容保留，不能改变数据路径或阻碍RX/Target配置。FD table_version、active_fd_version、active_fd_phase输出为0。RX DC/gain、矩阵及RX/Target/Doppler版本仍须在安全边界冻结，任务ID必须匹配。不得将旧FD字段当作仍支持分数波形延时。

RAW引用归还与DSP流水线排空依然独立。真实valid流水线排空后才能结束DSP所有权；输入间断不代表结束。故障立即抑制输出，排空后保持取消状态，必须重新准备配置。owner epoch改变、读响应缺失、时间/时钟/RF许可丢失的既有取消路径保留。

完整核心首次综合暴露看门狗→RAW置零→RXCAL算术的29级路径：WNS−0.145ns、192个setup失败端点。修复将reader寄存载荷直接送内部RXCAL，仍由原raw_valid/processing_fault限定接收；对外RAW和Target仍立即静音，不增加寄存级或改变GSC。新增真实非零RAW及DSP在途时的故障测试，核对立即归零、禁止接收、引用归还、排空及强制重新准备。失败证据保留在本机reports/v06_no_fd_before_payload_split。

## 延迟与尾部

RXCAL在接收边沿n锁存，Target输出位于n+2，合计3级寄存器。由于RAW reader自身在边沿输出，RAW输出到Target输出相隔3个RF时钟，即12个GSC tick（24ns）。真实RAM回放TB用目标GSC验证这一参考平面。相对旧phase0路径的168 tick（336ns），这一数字子链减少156 tick（312ns）；不能外推为完整射频路径的实测延迟。最终输入在n接受，正常done在n+4；无FD样点尾。

任务Doppler在正式派发同拍从冻结队首参数装载，不再等待注册task_started脉冲；否则最早合法任务在删除FD后会首样点相位未就绪。13个最近时刻及相邻派发边界用例覆盖1/4/7样点、不同参考索引、初相、频率和输出偏移，首样点及目标GSC均精确。上一任务done与新派发同拍时，新装载优先于旧done取消，真实processing_fault仍优先取消。相位仍按Target输入边沿及显式参考偏移计算，正交初相位和非零频率已在真实RAM路径验证；外部phase输入不是生产回放的相位来源。

12 tick仅是该数字子链参考平面。完整下游延迟还包括TXCAL、TX FIR、RFDC及实际射频链，必须重新绑定和实测才能认定物理latency_validated。TX FIR最低42个零输入的尾部要求保持，不能把删除FD补零理解为删除全部TX尾。

## 验证与重现

- tests/test_replay_no_fd_vectors.py：640个独立整数参考样点，含正负极值、ties-to-even舍入、饱和、20套配置、输入间断，逐拍核对3级输出及样点数量。
- tests/test_replay_processing_chain.py及Vivado XSim：非零DC/增益、交换H/V矩阵、复相位、配置冻结、故障及重新准备，实际输出8个输入对应8个结果。
- tests/test_calibrator_replay_system.py：真实16-bank RAM、精确目标GSC、全部32个非零fraction单比特值、任意退役FD配置、生命周期阻塞/过期、缺响应、epoch变化以及任务Doppler。
- 安全门数据分离后最终133/133项整轮回归全部通过，0重试；同时复验Fine结果与队列、真实仪器核心、DMA及TX尾部；成对回放隔离比较实际启动GSC和93个RAW IQ/GSC样点。

模块综合：Vivado2025.2、xczu27dr-fsve1156-2-i、125MHz，734 LUT、144 FF、0 BRAM、42 DSP，WNS+2.254ns/WHS+0.080ns，无失败端点。完整回放子系统（含队列、合法性检查、RAW reader和任务相位）为4990 LUT、4241 FF、4 BRAM、48 DSP，125MHz WNS+2.254ns/WHS+0.074ns，失败端点0。安全数据分离后子系统WNS由+1.436ns提高至+2.254ns，寄存器/DSP不增。完整核心资源已出：209094 LUT、245540 FF、553.5 BRAM、2414 DSP；相对Fine交付2ca0959减少15477 LUT、10174 FF和252 DSP，BRAM不变。活动FD实例为0。完整核心综合后WNS+0.629ns/WHS+0.033ns/WPWS+1.958ns，建立/保持/脉宽失败端点均为0。单时钟域WNS：RF125MHz +1.753ns、mem200MHz +0.655ns、ctrl100MHz +2.999ns。

原192个setup失败端点已消除，最差路径转为RF→mem确认同步器的跨域路径；没有加false path或放宽时钟。CDC为0 Critical、17760 Warning、25 Info，未作豁免；这不等于完整CDC签核。内部无时钟/未约束端点/组合环均为0，但1697个输入和1345个输出仍缺板级I/O延迟。当前OOC时钟关系及布线估算仍须由真实板级顶层、时钟源与约束替换后验收。

先运行tools/snapshot_v06_no_fd_inputs.py冻结输入，再运行tools/run_regression.py；Vivado batch分别运行hw/tcl/v06_replay_no_fd.tcl、v06_replay_no_fd_tb.tcl、v06_replay_system_no_fd.tcl和instrument_v06_no_fd.tcl。备份原工程后运行update_project_2025_2.tcl与verify_project.tcl。整轮结束后运行tools/retry_v06_no_fd_regression.py，仅重试失败项（没有失败时只收集），保留原始完整回归和每次失败/重试输出；前两次Fine持续负载触及300秒主机时限；外部等待上限改为900秒，仿真内60606拍周期断言及10ms watchdog不变。3个旧系统TB的31点前缀/62点补零预期已改为直接RAW→Target样点及12 tick参考；初次失败与两次相位边界红测均保留。最终133项整轮针对冻结后的全部修复重新运行，不用旧PASS拼接替代。最后tools/verify_v06_no_fd_integration.py核验报告、输入哈希及保护文件，产出本机reports/v06_no_fd_delivery.json。

报告和检查点不提交Git。证据覆盖当前工作区及其6个受保护外部RTL修改，这些修改不自动纳入本批提交；不能据此声称仅干净检出本批提交会得到相同网表。板卡未连接，板级绑定、DDR/cache/IRQ/SG实测和布局布线仍未验收。

此前Fine交付文档及contracts/fine_verification.json记录的是2ca0959批次，当时的D11待办由本文及本批replay合同更新取代；其旧全核心资源不能当作无FD版本的资源。
