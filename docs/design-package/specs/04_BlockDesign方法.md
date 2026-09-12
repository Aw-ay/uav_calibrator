# Block Design设计方法

## 1. 推荐层次

最终顶层建议 `calibrator_top` 包含 `calibrator_bd_wrapper` 和必要板级IO安全逻辑。BD中的主要对象：

```text
calibrator_bd
  ps_0                           Zynq UltraScale+ MPSoC
  rfdc_0                         RF Data Converter
  sample_clocking                IBUFDS / Clocking Wizard / SYSREF capture
  rst_ctrl / rst_mem / rst_rf     reset synchronization and sequencing
  axi_ctrl_0                     SmartConnect control
  axi_mem_0                      SmartConnect DMA→PS DDR
  axi_dma_iq                     AXI DMA S2MM + SG
  calib_pl_top                   自研顶层封装（内含RX/capture/replay/TX/control）
  awg_bram_ctrl / coeff_bram_ctrl AXI BRAM Controllers，按实现接口决定
  awg_memory / coeff_memory      双bank memory
  axis_iq_fifo                   128bit@200MHz burst cushion
  irq_concat                     各源同步后连PS GIC
  debug                          ILA / APM
```

`calib_pl_top`内部用RTL层次管理几十个小模块；常规FIR/DDS IP可在wrapper中实例化。也可把frontend/engine/backend分成3个packaged IP，但接口先稳定再拆，避免重复控制寄存器和不可追溯时延。

早期使用Module Reference便于迭代，稳定后打包为自有IP便于版本化。两种流程都由UG994支持，各有管理代价。[A16]

### BD边界要求

BD引出的接口使用确定宽度的packed vector与AXIS/AXI-Lite标准信号；复杂SV struct和多维unpacked array保留内部。明确时钟、ASSOCIATED_BUSIF、FREQ_HZ与reset polarity。对module reference导入能力有疑义时先做一个只含端口的最小合法实例检查，不能让Codex凭借GUI自动推断。

## 2. 控制路径

```text
PS/M_AXI_HPM0_FPD
  → axi_ctrl_0/S00_AXI
  → RFDC/s_axi
  → AXI_DMA/S_AXI_LITE
  → calib_pl_top/S_AXI_CTRL
  → AXI_BRAM_CONTROLLER_AWG/S_AXI
  → AXI_BRAM_CONTROLLER_COEFF/S_AXI
```

控制目标100MHz。PS HPM的命名是从PS视角的master；HP0是PL master进入PS DDR的slave，不能颠倒。[A14]

AWG与系数RAM的CPU写端和核心读端跨域通过存储和所有权协议；PS只写inactive bank。校准全表提交必须核查length/CRC和版本，不允许仅翻一个bit就让一半新一半旧系数生效。

## 3. 大数据路径

```text
capture RAM B口(冻结、128bit、clk_mem)
  → frozen_frame_reader
  → iq_frame_formatter
  → AXIS FIFO / register slice
  → axi_dma_iq/S_AXIS_S2MM

axi_dma_iq/M_AXI_S2MM ─> axi_mem_0/S00_AXI ┐
axi_dma_iq/M_AXI_SG   ─> axi_mem_0/S01_AXI ┴─> PS/S_AXI_HP0_FPD
```

m_axi_s2mm_aclk与m_axi_sg_aclk均接200MHz；s_axi_lite_aclk接100MHz；DMA复位按其控制时钟要求提供。使能async clock后检查其时钟频率关系满足官方限制。[A12][A21]

如果采用其他存储方案、formatter在clk_rf，则必须增加显式AXIS异步FIFO；不要同时复制两套数据跨域方法导致时间和流控不一致。

主链首版只用一个S2MM。三档诊断按记录串行复用，其它DMA仅在后续批准后加入。不能把一个普通DMA想象为根据header自动路由到不同DDR ring；不同数据类型由统一记录和PS索引区分，或显式独立DMA通道。

## 4. RF数据连接

```text
RFDC ADC native ports → calib_pl_top ADC adapters
  → RX FIR wrappers → capture/measurement

calib_pl_top TX interpolator/adapters → RFDC DAC ports
```

物理模拟端口、converter tile、PL SYSREF、参考时钟从厂家BSP和原理图导入，不根据逻辑ADC0/ADC4猜芯片位置。参考ADC3/7是逻辑用途编号，并不是固定tile/block索引。

RFDC ADC与DAC接口reset释放前，相关clock必须稳定；MTS后禁止未经记录地单独复位某tile。软件报告MTS成功不是所有模拟电缆时延被校准，后续要共同注入信号核验。

## 5. 中断与外设

- DMA S2MM完成/error、event watermark、fault、RFDC irq连接PS的PL中断输入。
- 每源依据真实输出域跨到目的域，电平/锁存事件比短脉冲直接concat更可靠。
- 默认不再增加AXI Interrupt Controller：PS GIC能直接接现有合适数量的PL中断。超出容量才评审汇聚。
- 低速时钟芯片、温度、电压和导航接口使用实际板级PS外设或EMIO；只有物理接PL时才添加AXI IIC/SPI/UART。
- RF PA/T-R最终使能必须来自safety模块与物理联锁，不允许AXI GPIO/VIO绕过。

## 6. 地址分配建议

| Segment | 基地址 | 预留范围 |
|---|---|---|
| RFDC |0xA0000000|256KiB |
| DMA |0xA0040000|64KiB |
| 自研CSR |0xA0050000|64KiB |
| AWG |0xA0100000|256KiB |
| Coeff RAM |0xA0200000|64KiB |

这是建议地址，不是当前Vivado已分配结果。由BD生成并导出唯一地址表，PS头文件和设备树跟随。实际RFDC地址segment以IP输出为准，若范围不同需重新验证所有区间。DDR DMA物理buffer由操作系统/BSP管理，不在上述MMIO地址里硬编码。

## 7. 构建过程（批准后由Codex实现）

1. **board profile**：核对完整part字符串、工具版本、许可证、PS DDR/MIO preset、XDC、时钟芯片配置和RF daughtercard。
2. **IP smoke**：单独生成RFDC、RX FIR、TX FIR、DMA和非对称BRAM，检查端口/速率/延迟/资源。特别确认8复样点的实际native stream组成。
3. **平台壳层**：PS、RFDC、时钟reset、CSR、DMA和测试数据源；未实现功能只可报告未实现且TX保持零。
4. **源/IP导入**：add RTL、IP repository path、XCI；固定VLNV和IP版本，不批量自动upgrade。
5. **BD连接**：按连接矩阵连时钟/复位/AXI/stream/IRQ，显式标注多时钟边界。
6. **地址与规则检查**：assign地址后检查不重叠、SG与S2MM均可达DDR、无悬空控制流、ADC永不背压。
7. **generate output products / wrapper**：生成BD目标与wrapper，以顶层XDC约束外部IO。
8. **synthesis → implementation**：看真实WNS/TNS、DRC、CDC、资源和功耗，不只看BD validate通过。
9. **导出平台**：仅在真实实现通过后write hardware platform，保存bit/LTX/XSA与散列；用匹配Vitis/BSP生成软件。
10. **受控上板**：下载前确认物理衰减、ADC输入限制、参考时钟和默认静音；无需也不允许自动烧eFUSE/Flash。

## 8. Tcl组织，不直接猜一份大脚本

拟议脚本名称：

```text
hw/tcl/check_environment.tcl
hw/tcl/create_project.tcl
hw/tcl/create_ip.tcl
hw/tcl/create_bd.tcl
hw/tcl/assign_addresses.tcl
hw/tcl/build_synth.tcl
hw/tcl/build_impl.tcl
hw/tcl/export_xsa.tcl
```

正式脚本应从人工核准的GUI配置导出的 `write_bd_tcl` 与 `report_property` 建立，不直接把抽象参数名猜成CONFIG属性。

后续可采用的检查/生成命令种类包括 `validate_bd_design`、`generate_target`、`make_wrapper`、`report_ip_status`、`report_clocks`、`report_cdc`、`report_drc`、`report_timing_summary`、`report_utilization`、`write_hw_platform`。具体参数与对象路径由被固定的工具版本导出。

没有目标Vivado/BSP时，不交付一份宣称可直接运行的Tcl。本包因此只给设计与连接规范。

## 9. 特别禁止的简化

- 不用BD里一个AXIS Broadcaster把ADC同时扇出到会背压的DMA和回放。
- 不因TREADY=0而暂停GSC或同一个脉冲的回放时间。
- 不把每个sample都附带64bit GSC写RAM；保存frame base+stride即可。
- 不把所有CDC用set_false_path掩盖；clock constraint应反映真实同步关系。
- 不用host完成结果提前填“final header”；不把planned TX称为actual TX。
- 不把RX/TX校准的增益、固定延迟或极化基在两个模块中重复执行。
