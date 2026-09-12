# ZU27DR 标定仪 v0.5 实施工程

**状态：部分数字核心已实现并验证，完整 PL/PS 标定仪尚未完成，不可直接下载上板。**

使用 Vivado 2025.2 打开 `build/calibrator_zu27dr/calibrator_zu27dr.xpr`。已在原工程加入 SystemVerilog 源码、测试和三个新生成 IP。修改前工程完整备份在 `build/calibrator_zu27dr_before_2025_2/`。

## 已实现

- `calibrator_top`：八路独立 RX/TX FIR、RFDC native 位序适配、缺样补零且保持时间网格、57 拍质量恢复、饱和标志和 DAC 连续静音零码。这是数字接口 OOC 核心，不是板级顶层。
- `rtl/control`、`rtl/time`：独立 AXI-Lite 控制、原子配置跨时钟握手、64 位 GSC 快照和故障 W1C。目前仅支持 mute/measure，其余功能返回错误，CAPABILITIES 为 0。
- `rtl/capture`：16 个独立混合位宽 RAM 阵列、低层所有权管理、共同选档、冻结读取和 ABI5 打包；新增功率门限脉冲检测器，保留真实尾沿序号、滞回、保持、最大长度与缺样中止。检测器尚未接入整脉冲调度。
- `rtl/data/record_upload_groups.sv`：四组冻结描述符轮询、原子跨时钟交接、16-bank B 口选择、帧打包、4096 拍 FIFO 到 DMA 流接口。仅在整帧被 FIFO 接收后返回 RAW 租约；DMA 停顿时 FIFO 继续拥有记录。
- `rtl/capture/capture_record_system.sv`：实际连接 bank 所有权管理器、16-bank RAM 和四组上传通路。每组描述符校验期望 epoch/generation，拒绝复位后的旧记录头绑定新数据；回放引用可继续保留 bank；软复位先停准入、排空读取再更新 epoch。检测、整脉冲资格和语义元数据仍由显式上游接口提供。
- `rtl/frontend/native_overload_monitor.sv`：检查抽取前八路各四个复数样点，区分 DDC 近削顶、缺样和未知硬件过载；不把 DDC 幅度正常当作 ADC 未过载证据。
- `rtl/replay/frozen_replay_reader.sv`：单套 H/V 整数 RAW 定时预取，包含目标样点参考位置、迟到/上下文拒绝、故障排空及独立租约归还。它不包含分数延迟、校准或完整 DRFM/RF 完成判定。
- `sw/common`：可移植 C 帧校验/解码、非 cyclic DMA 槽所有权核心；使用生成偏移，验证实际长度和 CRC，拒绝重叠地址与过期归还。它不是裸机或 Linux 硬件驱动。
- `build/platform_candidate_2025_2`：已通过 Vivado 检查的 PS/SG S2MM/HP0 候选 BD，包含有来源依据的 DDR/UART 子集。目标 FCLK200 的实际计算值为 199.998001 MHz。完整 RF 平台尚未接入。
- 同源 SV/C 常量、精确整数 COE、ABI5 软件编解码及回归入口。
- Vivado 2025.2 已生成 RFDC、BMG、普通 SG S2MM DMA 并完成三者独立综合；实际 BMG 整容量双时钟读写仿真通过。

## 验证及边界

实际回归记录见 `reports/regression_latest.json`：当前 16 组软件/RTL 测试通过。各模块报告和独立审查见 `reports/`。单路 RX/TX FIR 已完成 125 MHz 独立布局布线，内部 WNS 为 4.915 ns / 4.385 ns、TNS 为 0；外部 I/O 延迟未建立，不是整机时序签核。

PS 接收核心还通过本机 Vitis 2025.2 Cortex-A53 严格 C11 交叉编译，产物为 `build/ps_common_a53_2025_2/libcalibrator_receive.a`；没有启动代码/BSP/ELF，不代表 PS 程序可运行。

完整采集上传子系统已用真实 RAM 网表综合：23882 LUT、10922 FF、472.5 BRAM tile，未解析模块为 0。该检查显式采用 DETECTOR_LATENCY=1，不改变生产默认值 0 的禁止准入行为，也不代表整体时序或检测延迟已标定。

记录 FIFO 在 200 MHz 独立布局布线后的内部 WNS 为 2.397 ns、TNS 为 0，使用 16.5 个 BRAM tile。上传组合模块综合成功；CDC 报告识别 1163 条握手控制的多位数据路径警告，仍需完整端点的物理约束与审查，未将其豁免或宣称 CDC 签核通过。76 次记录桥测试和四组组合测试覆盖实际 FIFO、满容量、环绕、错误帧头、字节比对及 DMA 背压。

检测器使用 4 DSP、655 LUT、522 FF。独立实现的内部路径通过，但补加理想同钟端口延迟后的诊断为 setup 0.044 ns、hold -0.080 ns，**不能认定检测器完整接口时序已闭合**。实际输入/输出寄存器、时钟树和布线尚未集成；未用 false path 或更改频率掩盖该结果。见 `reports/pulse_detector_ooc/timing_interface.rpt`。

八路核心综合成功：2128 DSP、14762 LUT、62447 FF，无错误和严重警告。报告见 `reports/digital_core_*`，不包含 PS/RFDC/capture/DMA/控制系统的整体资源。记录流采用保守单请求 RAM 读取和串行头 CRC，尚无持续 DMA 吞吐结论。

旧 BD 中的 RFDC 保留且不参与综合/仿真，2025.2 报告其 IP 数据不兼容。未自动升级；新的 `rfdc_probe` 为独立生成 IP，不能将旧 BD 当成完整系统。

用户补充已记录：`clk_mem` 目标为 PS FCLK 200 MHz；原理图第 10 页 UT19 为 RC21008A，具有 `RC_CLK_P/N` 外部参考入口。该芯片的实际配置仍待核对，不能把 PL 200 MHz 当成射频相干参考。J4 上 ADC226/227、DAC228 需要外部射频前端；SYSREF 需外部补充。

## 完整工程仍缺少

1. PS 候选配置的实板训练验证、射频时钟芯片配置/SYSREF、逻辑 H/V/量程接线、RF 联锁接口及实际时延。
2. 完整 RF 平台 BD、控制与已实现采集上传子系统的连接、跨时钟物理约束，以及 FIR/检测器/整脉冲资格统计和不可变语义元数据集成。
3. DDS/AWG/确定性 DRFM 调度、RX/TX 校准、获认可的分数延迟算法、PS 裸机与 Linux 驱动/服务和五模式端到端验证。
4. 集成实现、CDC/时序/资源验收及真实板卡 DMA/MTS/RF 测试。没有 bitstream、XSA、ELF 或板级通过结论。

## 来源

活动规格为 `docs/releases/Vivado_PLPS_标定仪框架设计包_v0.5/` 和 `contracts/`：RX 500 MS/s → HB19 D2 → FIR75 D2 → 125 MS/s，TX 逆序；FIR 同 125 MHz，DMA 200 MHz。`docs/design-package/` 与 `docs/legacy-contracts-before-v0.5/` 仅用于旧版溯源。新增控制位定义见 `contracts/control_implementation.json`。

板卡资料：`E:/temp/save_v2.1/XCZU27DR-v2.1.pdf` 及厂家例程。详见 `reports/board_source_audit.md`。RF/GTY 工程为 -2-i、MEM 为 -1-i；暂保留原项目 xczu27dr-fsve1156-2-i。MEM 的 DDR 容量匹配原理图，GTY 的 UART 路由匹配原理图，不能直接整套照搬任一 preset。

## 重现

2026-09-12 新增六路逻辑 H/V 三档功率/峰值/能量统计，18 组回归通过。该模块为资格判定的统计基础，SNR、档间线性资格和系统连接仍待完成；见 `reports/range_statistics_progress.md`。

在本目录执行 `python tools/run_regression.py`。Icarus/vvp 默认路径为 `C:/iverilog/bin`。

功能 TB 的场景、判定与波形查看方法见 [TB验证说明](docs/TB验证说明.md)。新增随机检测计分板已纳入 17 组回归；`python tools/run_functional_xsim.py` 在 Vivado 2025.2 中运行四个自检 TB，生成独立仿真工程和波形。

Vivado 可执行文件为 `C:/AMDDesignTools/2025.2/Vivado/bin/vivado.bat`；PATH 可能仍指向 2025.1。

- `hw/tcl/update_project_2025_2.tcl`：在原工程登记源码和 IP。
- `hw/tcl/verify_project.tcl`：重新打开检查。
- `hw/tcl/digital_core_ooc.tcl`：八路数字核心综合。
- `hw/tcl/fir_ooc.tcl -tclargs rx` 或 `tx`：单路 FIR 综合/布局布线。
- `hw/tcl/run_xsim.tcl -tclargs tb_capture_bmg`：生成 BMG 的整容量仿真。
- `hw/tcl/platform_create_candidate.tcl`、`platform_candidate_test.tcl`：PS/DMA 候选及配置验证。
- `hw/tcl/record_fifo_ooc.tcl`、`record_upload_ooc.tcl`、`pulse_detector_ooc.tcl`：新增模块的独立实现/综合诊断。
- `hw/tcl/capture_record_ooc.tcl`：采集上传子系统及实际 16-bank RAM 网表的综合检查。
- `hw/tcl/native_replay_ooc.tcl`：原生过载监测及整数 RAW 回放读取器综合。
- `python tools/build_ps_common.py`：Vitis 2025.2 A53 静态库交叉编译。

以上脚本使用 `vivado -mode batch -source <脚本>`。创建脚本拒绝覆盖已存在工程；空目录重建需先生成合同/FIR源码及 probe IP，再运行 `create_project.tcl`。
