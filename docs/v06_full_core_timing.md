# v0.6 当前数字核心综合与时序复核

2026-09-30 按用户要求重跑。Vivado 2025.2，xczu27dr-fsve1156-2-i，
顶层 calibrator_instrument_core，OOC 综合；14:05:36 至 14:26:49，约21分钟。
综合和全部报告正常结束，未改 RTL、频率、时序例外或升级 IP。

## 结论

当前数字核心在现有约束下的综合后时序估算无违例。**不能据此判定板级整机时序验收通过。**
D05 在线统计已经包含在本次网表中；Fine CORDIC 尚未实例化，完整 Fine 引擎尚未实现，活动回放仍含 FD63。
输入是 a8517703ba2db78db7928fcb2f744beb98cf6e2a 加现有工作区修改，包括受保护的六个外部 RTL。
129 个输入文件的运行前后 SHA256 一致；不是纯 Git 提交树的综合结论。

| 时钟域 | 频率 | 建立余量 WNS | 保持余量 WHS |
|---|---:|---:|---:|
| RF | 125 MHz | +0.318 ns | +0.043 ns |
| DMA/存储 | 200 MHz | +2.581 ns | +0.043 ns |
| 控制 | 100 MHz | +7.293 ns | +0.072 ns |
| 全部受分析路径，含跨域 | — | +0.318 ns | +0.037 ns |

TNS=0，建立/保持/脉宽失败端点均为0，最小脉宽余量+1.958 ns。
与上次 DMA 核心综合相比，最差余量及关键路径未变。

## 主要时序风险

最差建立路径为 `dataplane/transmit/safety/watchdog_age_reg[16]` 到
`dataplane/replay/processing/hv[0].cal/core/out_i_reg[12]`。
路径经过看门狗超时判断、安全故障门控和回放校准运算，29级逻辑，
数据延迟7.662 ns（逻辑4.019 ns、估算布线3.643 ns）。+0.318 ns 余量较小，
布局布线后可能恶化；在线统计不是本次最紧路径。

后续优化应评估切分校准数据运算或安全控制扇出，保持最终 DAC 故障静音响应，
同步更新流水线延迟合同和故障注入 TB。不能直接延迟安全联锁或增加 false path 来消除该路径。
本次仅完成诊断，没有修改该逻辑或受保护的 complex_cal_core。

最差保持路径是上传完成 CDC 的 payload 到 completion_hold，+0.037 ns。
这是综合估算，需随真实时钟网络和布线重新检查。

## CDC 与约束缺口

- CDC：0 Critical、15929 Warning、15 Info，与上次一致；警告全部为 CDC-15 时钟使能控制跨域结构，未豁免。
- clock_interaction 对四组跨域方向均报告 `No Common Clock / Timed (unsafe)`。
  当前是独立定义的主时钟；跨域数值为正不等于真实异步传输已经验收。
  需根据 PS/RFDC 实际时钟来源确认相关性，并验证邮箱数据保持、握手、复位及适用的物理约束。
- 无缺失内部时钟、无未约束内部端点、无组合环；1697 个输入和1345个输出没有延迟约束。
  CDC 工具明确跳过未设置输入延迟的端口，0 Critical 不覆盖这些边界。
- 三个 OOC 时钟端口没有 HD.CLK_SRC，无法估算实际时钟树延迟/偏斜。
  board_pending.xdc 仍为空，当前网表不是完整 PS/RFDC 板级系统。

## 资源与普通告警

| 资源 | 用量 | 器件占比 | 相比上次全核心 |
|---|---:|---:|---:|
| LUT | 154252 | 36.27% | +4892 |
| FF | 206809 | 24.31% | +2001 |
| BRAM Tile | 538.5 | 49.86% | +4 |
| DSP | 2618 | 61.28% | 0 |

无未解析黑盒、综合错误或严重警告。普通告警包括未用/未连接端口、声明次序、
event_mailbox 存储器推断及置位/复位描述告警；这些没有被当作已消除。
部分 AWG/NCO RAM 未合并输出寄存器，工具提示可能影响时序，但不是当前最差路径。

## 证据与下一步

入口：hw/tcl/instrument_v06_online.tcl；汇总工具：tools/report_v06_full_core.py。
本地证据：reports/v06_full_core_inputs.json、reports/v06_full_core_review.json，
以及 reports/instrument_v06_online/ 下的 timing_synth、setup_paths、hold_paths、
check_timing、clock_interaction、cdc、utilization 报告及 synth.dcp。
报告和检查点保留本地，不上传到公开源码仓库。

本次补齐 D05 后全数字核心综合证据，不替代后续 Fine 集成后的批次验证。
真实板级顶层、RFDC/PS 时钟复位、引脚和 I/O/CDC 约束齐备后，
才能进行整机布局布线，并以布线后 setup/hold/pulse、约束覆盖和 CDC 审查判断整机时序验收。
