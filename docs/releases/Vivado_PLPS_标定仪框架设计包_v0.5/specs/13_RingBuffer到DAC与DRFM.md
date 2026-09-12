# 13 RingBuffer → DAC / DRFM

本地确定时延链不走DMA/DDR，MM2S基线关闭。所选冻结H/V经A64bit@125MHz按绝对时刻预取，RXCAL副本→分数波形延迟→目标矩阵/多普勒→源MUX→8DAC路由→每DAC独立TXCAL→FIR75 L2→HB19 L2→DAC adapter4SPC@125MHz→RFDC内部L8候选→4GS/s DAC/RF。

DDS/AWG在源MUX进入，同样经过后面的每DAC校准。八路TXFIR不是八套独立DRFM；当前1个H/V目标引擎，八源/多目标单独评审。目标算子和本机校准保留可追溯独立参数，不重复补偿Doppler或固定时延。

## 定时与因果

任务含目标输出参考面、参考样点在记录中的index、target_GSC和RAW/系数版本。read_start由目标时刻反推，包含RAM和运算真实latency。前触发记录的第0点不是脉冲onset，不能忽略其位置。整脉冲捕获+资格之后才允许读，too-early/too-late/冲突/loopback源明确拒绝，不把延后实发说成原时刻成功。

当前不是边收边发的LIVE结构。单天线OTA默认禁LIVE；超PRI延时按所有时隙/资源/guard检查，不一概拒绝或一概允许。63tap分数延迟仅DSP占位，最终全±50MHz及所有fraction误差需独立验收。

## 输出连续性与尾

所有TXFIR同clk_rf125MHz，1→2→4SPC；不再125/250gearbox。DAC接口ready后每拍供波形或安全零；TVALID不是mute，TLAST不是RF关断。欠载中止并记录真实事件，不重复旧样点续播。[A31]

两级TX系数按Q16，每级L2增益补偿一次；不能重复增益。PL FIR群延迟166ns，末输入影响跨度332ns，正常结束需至少42个125MS/s零输入覆盖此两级尾。上游RXCAL/Farrow/TXCAL、实际IP/RFDC和模拟guard另计。RAM_READ_DONE、TX_PIPELINE_DONE、RF_DONE独立；硬故障立即安全优先。

RAW最后需要的RAM读完可归还replay_ref，系数/任务引用可能持续到RF_DONE；其他record_ref仍在则不可重写bank。提前预取所需数据，DMA背压不能改动已接受TX时刻。共享时钟异常/复位要废弃错误任务并执行物理安全，不只更新软件状态。
