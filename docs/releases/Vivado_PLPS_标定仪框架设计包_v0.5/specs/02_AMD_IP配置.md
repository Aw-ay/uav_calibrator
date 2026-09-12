# 02 AMD IP语义配置目标

权威参数：contracts/amd_ip_targets.json、fir_plan.json。这里不是可直接source的Vivado Tcl；具体IP版本、属性名、part与原生端口须C00/C02确认。

## 1. RFDC与PS

PS启用控制HPM、128bit HP0、必要中断；DDR/MIO/GEM/PCIe/SD按真实板卡BSP，不猜引脚。RFDC八ADC持续开；原生Tile/Stream与逻辑ADC编号分别建表。目标RFDC D8后500MS/s复数；规范4复SPC@125MHz。Gen1 DAC内部L8候选到4GS/s，不使用Gen3 L16、DSA/VOP/TDD能力假设。QMC、输出电流等实际功能在匹配API和器件能力范围内校准控制。

## 2. 四种FIR OOC配置

| IP类型 | 每路输入→输出 | 复SPC输入→输出 | 时钟 | 系数/小数位 |
|---|---|---|---:|---|
| RX HB19 D2 | 500→250MS/s | 4→2 |125MHz| RX_STAGE1,Q17 |
| RX FIR75 D2 | 250→125MS/s | 2→1 |125MHz| RX_STAGE2,Q17 |
| TX FIR75 L2 | 125→250MS/s | 1→2 |125MHz| TX_STAGE1,Q16 |
| TX HB19 L2 | 250→500MS/s | 2→4 |125MHz| TX_STAGE2,Q16 |

每对H/V对应4条独立实数路径，4组；每方向2级，共8个组级实例候选。可以拆分实例，但总吞吐/独立历史不变。Interleaved channels=1；SSR不是多通道参数，lane并非独立时间序列。输入Sample Frequency按实际样点率填写，不把所有字段改125MHz。数据内部24bit候选，累加48bit，系数18bit；完整输出后显式舍入。

SSR不自动利用半带零系数优化；普通对称也受位宽/器件限制。首级评估显式稀疏对称多相实现与通用SSR IP，后级选择合适systolic结构。不得以1536算术预算替代综合report。每个候选检查实际II、pipeline、输出位宽、对称/DSP列数、WNS和频响。[A10][A11][A23][A24][A25]

## 3. Capture RAM

四组×四个独立bank，真双口BRAM目标。A64×16384@125MHz用于采集写或冻结回放读；B128×8192@200MHz只读冻结数据。read latency由IP导出并加入预取信用。常规宽度拼接示例32 RAMB36/bank，共512块；只是映射估计。ECC开启改变位宽与资源，不默认为免费功能。

URAM只有共同内存时钟，不能直接套入双时钟A/B配置；改URAM须重新设计时钟/端口调度。[A22][A29]

## 4. DMA和互连

单AXI DMA，S2MM+SG，MM2S关闭，MicroDMA关闭，128bit S_AXIS和M_AXI_S2MM，数据/SG200MHz，控制100MHz；DRE0，burst64，地址40bit候选，长度23bit候选。普通SG，不默认cyclic。实际参数存在性按已锁定IP查询，不能无声升级。

S2MM与SG两个master均接SmartConnect到HP0 DDR；SG数据宽度可不同。AXIS FIFO128×4096@200MHz，TKEEP/TLAST开启，非packet mode；不承担整条持续数据无限缓存。

## 5. 时钟与复位

clk_rf125MHz是一个共同参考派生的合规时钟网络，不保留clk_fir250。clk_mem200MHz与clk_ctrl100MHz独立CDC。采样/回放域不直接取PS任意同名频率充当相参时钟。SmartConnect/AXI复位协调；XPM FIFO resetbusy时不读写；算法soft-clear保持AXI协议壳正常。[A06][A08][A09][A15][A21]

## 6. DDS/AWG/校准

DDS48bit相位/16bit输出是候选，clk_rf125MHz，包络按真实latency延迟。AWG双bank总孔径256KiB，PS仅写inactive，校验长度/CRC后commit；回放64bit@125MHz。校准共用系数版本管理，路由后每DAC独立。Complex Multiplier按真实位宽评估DSP；63tap分数延迟只作容量占位。
