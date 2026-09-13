# Vivado PL/PS 标定仪主设计包 v0.5

**唯一活动基线：8路独立ADC；125 MS/s核心；RX/TX FIR同一125 MHz时钟；DMA域200 MHz。**

这是从v0.3主设计包、v0.4滤波仿真、三段信号链核对、RingBuffer行为验证和ZU27DR资源核算合并得到的完整设计规格包，不是要求再叠加某个补丁的补充包。

状态：**MERGED_DESIGN_BASELINE_NOT_IMPLEMENTED**。用户本次授权合并规格/计划；未执行Vivado/Vitis、未生成XCI/BD/可综合RTL/bitstream/XSA/ELF、未上板。`generated/`仅为合同导出的常量/偏移定义，不是实现过的FPGA工程。

## 活动配置

| 项目 | 本包基线 |
|---|---|
| 主接收 | H/V三量程，共6路，掩码0x77 |
| 辅助接收 | ADC3/7独立AUX-MID，掩码0x88；不复用原MID |
| RFDC规范接口 | 每接收通道500 MS/s复数，4复SPC@125 MHz |
| RX | HB19 D2 → FIR75 D2，4→2→1SPC，同一clk_rf125 MHz |
| 主处理 | 125 MS/s；±50 MHz目标通带，滤后IQ16 |
| TX | FIR75 L2 → HB19 L2，1→2→4SPC，同一clk_rf125 MHz |
| DMA | S2MM+普通SG，MM2S关闭；128bit@200 MHz；不默认cyclic |
| 捕获RAM | 四组独立；每组4个同功能轮换bank；16384×64bit/bank；共2 MiB RAW |
| A/B口 | A64bit@125 MHz采集或冻结回放；B128bit@200 MHz冻结上传 |
| DDR接收池 | 256 KiB/槽×512槽=128 MiB地址空间；有效记录长度独立 |
| 记录策略 | 三档都捕获，整脉冲共同选档后默认只传所选H/V；AUX独立预算 |
| DRFM | 所选冻结H/V经A口本地定时读取，不绕DDR/DMA；1组目标引擎 |
| 器件参考 | ZU27DR Gen1；封装/板卡/工具/BSP/时钟与原生映射未确认 |
| ZU27DR TX速率目标 | 125M×PL4→500M×RFDC8→4 GS/s；不是Gen3×16/8 GS/s |
| 资源预算 | 优化FIR1536 DSP；含约定DRFM等功能算量1932；规划2415～2815；未综合 |

## 文件优先级与入口

1. `contracts/`：机器可读的活动合同；冲突时不能直接选旧报告的值，应让一致性检查失败并修正。
2. `specs/`：对应解释和实现要求；`codex/任务顺序.md`：后续实现顺序与硬件交付门。
3. `filters/`：本profile冻结整数系数；RX Q17，TX同整数Q16，不得按文件名自动归一化。
4. `models/`、`tools/`、`tests/`：Python参考行为/数值与合同检验；不是RTL/CDC时序模型。
5. `generated/`：由合同生成的C和SystemVerilog参数/偏移；不要手改。
6. `reports/`：本轮实际运行输出、合并追踪和未验证项。
7. `provenance/`：原始输入与旧版本，仅供追溯；**禁止作为活动实现配置**。

建议先读 [合并说明](修改说明.md)、[总体设计](specs/00_总体设计.md)、[RingBuffer](specs/10_RingBuffer设计.md) 和 [实施门](specs/09_来源与待确认项.md)。

## 复算

Python3.10及以上，依赖见requirements.txt。在包根目录执行：

```bash
python -m pip install -r requirements.txt
python tools/verify_all.py
```

或Windows：`verify.cmd`。运行离线，不下载板卡资料、不访问GitHub，不需要Vivado。输出在reports/，变更报告后原发行哈希自然不同；需核对原发行完整性时，解压后先运行 `python tools/check_integrity.py`。

复算覆盖合同/ABI、系数频响、参考定点、脉冲队列、bank状态/引用、广播轮换及TX补零。**通过Python不意味着OOC、时序、MTS、DMA驱动或实物计量验收通过。**

## 不替用户猜测

保留空值：实际板卡/完整part、Vivado/Vitis/BSP、RFDC Tile/word映射、真实模拟增益优先级、检测最大延迟、各级实现latency、真实DDR/SSD吞吐、分数延迟最终结构和精度。设计目标与硬件“已启用/已测得”严格分开。
