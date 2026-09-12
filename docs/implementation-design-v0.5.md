# v0.5 工程实现方案与输入核查

日期：2026-09-11。状态：实现前核查；尚未实现 RTL，未运行综合、实现或上板验收。

## 已确定输入

- 用户指定 SystemVerilog、Vivado 2025.2，在现有 calibrator_zu27dr 工程中实施。
- 用户描述的分段路径不存在；实际找到 E:/uav/Vivado_PLPS_标定仪框架设计包_v0.5.zip。
- ZIP SHA256：4E5C9DAD4730A15BA5BDBAE0C737BCFF4EEE7E334E5ACFA210A3D6B2F227FDA1。
- 现有工程：build/calibrator_zu27dr/calibrator_zu27dr.xpr，记录版本 2025.1，part 为 xczu27dr-fsve1156-2-i。
- 找到 2025.2 可执行文件 C:/AMDDesignTools/2025.2/Vivado/bin/vivado.bat。环境默认命令仍指向 C:/Xilinx/2025.1/Vivado/bin/vivado.bat，实施脚本须显式选择 2025.2。
- 工程 docs/design-package 与 contracts 是旧规格：D8、62.5 MHz、两 bank。不得继续作为本轮实现输入。

## 实现结构

以本次 ZIP 内完整 contracts/specs 为单一来源。保存旧版本，独立保存 v0.5 发行原件及其校验记录，再更新工程活动合同和版本引用。旧 AGENTS 中的旧速率限制由本次用户指定的 v0.5 基线替代，其证据与安全规则仍保留。

采用平台 BD 加 SystemVerilog 核心：BD 负责 PS、RFDC、复位、AXI、普通 SG S2MM DMA；RTL 负责时间、控制、连续数据适配、捕获与所有权、帧格式、确定性回放及安全输出。FIR 先根据冻结系数试生成 AMD IP 并验证 SSR、延迟、资源、时序，再确定封装。不得将资源预算当实际综合结果。

- 八路连续 ADC：六主路及两路独立 AUX-MID。
- RFDC 后每路 500 MS/s、4 SPC；RX HB19 D2 → FIR75 D2，全链同一 125 MHz 核心时钟。
- 四组各四个轮换 bank；A64×16384 @125 MHz，B128×8192 @200 MHz，RAW 总计 2 MiB。
- 主三档原子准入，EOP 后 H/V 共同选档。冻结 bank 先 pin 再分发描述符；按 epoch/generation/consumer 校验归还。
- 128 bit @200 MHz 上传；ABI v5；SG 非 cyclic；软件池 512×256 KiB，未消费不覆盖。
- 本地回放通过 RAM A 口，不经过 DMA/DDR。基线一套 H/V DRFM，八路 TX FIR 不等同八套独立波形源。
- TX FIR75 L2 → HB19 L2，1→2→4 SPC。Gen1 4 GS/s、RFDC L8 是待板级核验的速率目标。
- CSR、GSC、命令/事件 CDC、校准版本、TX 零码及物理联锁使用显式状态和错误反馈。

## 分阶段产物及验收

1. 合同校验、ABI/SV/C 常量和 COE 同源生成器；验证字段布局、系数整数值及发行完整性。
2. RFDC/FIR/RAM/DMA 的 2025.2 最小生成与 OOC；记录真实端口、资源、延迟和时序，失败则保留失败证据。
3. CSR、原子配置、GSC、CDC、连续采样与 FIR；测试复位、异步更新、顺序、饱和和数值一致性。
4. 捕获管理及 RAM；测试预触发、尾沿、检测延迟、容量、满 bank、所有权与旧 ACK。
5. 冻结读、打包与 DMA；测试背压、环绕、奇数长度、CRC、TLAST 和字节数。
6. DDS/AWG/LIVE/回放、TX 插值、校准执行和安全联锁；测试因果调度、断流补零、故障及系数版本。
7. 平台 BD 集成、PS 裸机和 Linux 接口；运行可用工具下的仿真、综合、实现、CDC、时序及工件 SHA256 记录。
8. 实际 DMA DDR、MTS、RF 输出、五模式与模拟校准需要真实板卡/仪器证据；没有硬件执行条件时逐项保留 NOT_RUN，不能宣称整机验收。

## 仍需实际板卡依据

现有 board.json 指向 E:/temp/save_v2.1。该目录包含 ADC_DAC_27DR_TEST、GTY_20G、XCZU27_MEM_TEST_TOP。既有记录中 ADC/DAC 与 GTY 使用 -2-i，内存例程使用 -1-i，尚无法证明实物速度等级。

ADC/DAC 例程 XDC 有 200 MHz tile 参考时钟以及 57.5 MHz 调试控制时钟。这只能证明例程配置，不能直接证明 v0.5 要求的八路映射、4 GS/s 采样、125 MHz 相干时钟、PS DDR/MIO、SYSREF/MTS 和 RF 联锁引脚。

需确认该资料目录是否就是目标实物板的权威资料，并取得完整料号、PCB/原理图及 PS/时钟配置来源。与实物相关的未确认参数不得猜填。分数延迟架构、模拟增益顺序和误差预算仍按包内实现门处理。
