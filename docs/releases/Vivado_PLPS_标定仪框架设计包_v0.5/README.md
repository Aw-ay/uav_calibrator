# 无人机有源标定仪 Vivado / PL+PS 框架设计包 v0.5

**状态：已合并的设计规格与实施计划，不是已编译或可直接上板的FPGA工程。**

本版仅调整交付格式，沿用已确认的v0.5设计基线。与最初框架包保持相同组织方式：`specs/`、`contracts/`、`codex/`，根目录保留本说明与两份检查/校验文件。不附仿真源码、独立报告目录、历史压缩包、生成代码或工程实现文件。

## 目录

```text
Vivado_PLPS_标定仪框架设计包_v0.5/
├── README.md
├── SHA256SUMS.json
├── 设计包检查记录.json
├── specs/       设计说明、信号链、RingBuffer、资源预算与验证要求
├── contracts/   JSON合同，包括完整冻结FIR整数系数
└── codex/       AGENTS.md、任务顺序.md
```

## 固定主线

| 项目 | 本版设计基线 |
|---|---|
| 接收 | 八路独立连续采样；主六路＋独立AUX-MID两路 |
| RFDC规范接口 | 每路500 MS/s复数，4复SPC @125 MHz |
| RX FIR | HB19 D2→FIR75 D2；4→2→1SPC；全部125 MHz |
| 核心处理 | 125 MS/s，滤波方案总有效复带宽100 MHz |
| TX FIR | FIR75 L2→HB19 L2；1→2→4SPC；全部125 MHz |
| DMA | 128 bit @200 MHz，S2MM＋普通SG；不默认cyclic覆盖 |
| Capture RAM | 四组×四个同功能轮换bank×16384个64bit H/V时间点；RAW共2 MiB |
| RAM端口 | A64bit @125 MHz采集或冻结回放；B128bit @200 MHz冻结上传 |
| DDR接收池 | 256 KiB/槽×512槽；未消费记录不得覆盖 |
| 量程 | 三档同时捕获、EOP后H/V共同选档，默认上传所选H/V |
| DRFM | 从所选冻结bank本地读取，不经DMA/DDR；一组H/V目标处理基线 |
| 器件参考 | ZU27DR Gen1；真实板卡、完整part、工具及RFDC物理映射待确认 |

## 阅读顺序

1. [总体设计](specs/00_总体设计.md)及[时钟与数据合同说明](specs/03_时钟缓存与数据契约.md)。
2. [RingBuffer设计](specs/10_RingBuffer设计.md)、ADC／DMA／DAC三段链路说明及[FIR资源预算](specs/08_FIR资源核算与滤波器设计.md)。
3. `contracts/`全部活动合同；FIR整数唯一来源为`contracts/fir_coefficients.json`，按`fir_plan.json`中的`coefficient_set`读取。RX Q17、TX Q16，不得自动归一化或重复补偿增益。
4. [Codex约束](codex/AGENTS.md)、[任务顺序](codex/任务顺序.md)、[来源与待确认项](specs/09_来源与待确认项.md)。

## 使用边界

FIR系数与已确认的数值参数保持不变；只将外部系数文件收进JSON合同，并去除对已移除程序、报告、归档的依赖。软件目录示例属于后续待开发的工程布局，不是本包已有源码。合同生成器、COE导出器和自动测试属于Codex实施任务。

根目录`设计包检查记录.json`记录本次格式、引用、合同与系数检查，以及上一完整包的历史验证摘要。历史77项通过不意味着本版带有对应可执行测试，也不意味着完成RTL、Vivado/Vitis、CDC、MTS或上板验收。硬件验收项继续保持NOT_RUN；资源数仍为预算。

`SHA256SUMS.json`以包根目录相对路径列出所有其他文件的SHA-256，用于发行完整性核对。不得把规格中的未确认值补成猜测值以绕过实施门。
