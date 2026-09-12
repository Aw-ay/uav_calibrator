# AMD IP配置与RTL/IP筛选

## 1. 选择原则

能用成熟IP完成的总线、DMA、时钟、FIFO、BRAM和常规DSP，不重新手写；与本仪器业务相关的时序、状态、质量、参考面和任务契约自己实现。完整参数目标见 `contracts/amd_ip_targets.json`，其内容是设计输入，不是已验证的XCI。

## 2. RFDC：最容易配错的部分

### 2.1 RX目标

ADC实采样4GS/s，real→complex fine mixer，RFDC decimation8，目标每个物理接收信号500MS/s complex。16bit是RFDC数字输出码宽，不是宣称所有器件物理ADC都16bit。源频率/Nyquist区/NCO符号必须用已知单音与短窗模型验证。[A01][A19]

逻辑通道映射维持H HIGH/MID/LOW、V HIGH/MID/LOW及H/V参考；`ADC0/ADC4`等是项目逻辑编号，不能直接当RFDC tile/block编号。生成 `converter_map`，包括连接器、ADC、tile、DDC block、I/Q stream、lane顺序及校准ID。

### 2.2 八个word不总是八个复样点

Dual real→IQ布局可将I和Q分别输出到两个stream；若各stream为8个16bit字@62.5MHz，拼合后才是每通道8个复样点。Quad IQ常用单stream交织，8个16bit字只有4个复样点，500MS/s需要125MHz接口。最终以实际器件GUI生成的端口/样点率表为准。[A01][A02]

若native格式不支持期望布局：只允许增加明确的同步宽度/速率适配器并复验，不允许假装把16bit当32bit复样点。在MTS组中还需满足共同PL时钟关系。

### 2.3 MTS由谁做

RFDC提供机制，PS使用匹配BSP的RFdc驱动API执行ADC/DAC多转换器同步，再同步NCO/QMC等数字特性。无需自写一个声称替代MTS的RTL模块。PL只消费MTS状态和数据有效条件。[A07]

先测得可实现的latency，再按官方单位和余量固化Target_Latency；失败或达不到目标不能标READY。[A08]

### 2.4 ADC/DAC并非普通弹性AXIS

ADC的TREADY不停止实际采样；输入适配/抽取必须永久满足吞吐。DAC的TVALID不控制数模静音；空闲和故障时必须给安全零码。待DAC ready后要连续供数。[A03][A04]

## 3. FIR Compiler RX配置目标

| 项目 | 建议 |
|---|---|
| 实例 | 3套（每模拟量程一套）；参考通道可增1套同结构但独立使能 |
| 类型 | Integer/Polyphase Decimator，不是自动选择Halfband |
| 抽取率 | 8 |
| 样点率/时钟 | 500MHz / 62.5MHz |
| 并行实数数据路径 | 4：H_I,H_Q,V_I,V_Q |
| Interleaved channels | 1；不把三个模拟量程写成时间复用channels |
| SSR | 每path输入8样点/clock，输出1样点/clock |
| 输入 | signed16 |
| 系数 | 项目145tap Blackman低通；固定、对称、离线量化 |
| 系数宽 | 18bit候选，整数/小数格式由数值模型锁定 |
| 输出 | 保留累加精度，再convergent rounding＋外部饱和到记录格式 |
| 重载 | RX固定D8抗混叠滤波器首版关闭reload |
| 流控 | 不允许FIR阻塞RFDC；SSR和架构必须OOC证实全速接受 |

源文件导出的指标是总有效复带宽20MHz、通带边缘10MHz、阻带起31.25MHz、纹波目标0.1dB、阻带目标60dB。145tap的144ns只代表线性相位群延迟，必须另加IP流水/适配延迟并用输入输出标记实测。[R02]

PG149支持SSR的整数抽取/插值，但不保证所有宽度组合都利用对称性；SSR不利用Halfband优化。[A10][A11]

不得把145tap改成短滤波器、CIC或三级“看似相同”的半带而不回归其ENBW、纹波、延迟和边沿误差。主处理频率62.5MHz不意味着前端算力可忽略。

## 4. TX插值FIR

62.5→500MS/s，L=8，四个实数并行路径，每拍1入8出。TX滤波器必须单独确定通带、图像阻带与幅度归一化。采用插零卷积定义时，维持原幅度通常对应系数和8；若IP另行缩放，则必须计入统一gain ledger。不能把归一化系数和1的RX D8文件原样用于TX然后丢失18.06dB幅度。

## 5. AXI DMA目标

| 项目 | 候选参数 |
|---|---|
| Scatter Gather | c_include_sg=1 |
| 只开接收 | c_include_s2mm=1; c_include_mm2s=0 |
| 微型DMA | c_micro_dma=0 |
| S2MM AXIS宽/MM宽 | 128/128 |
| 主数据clock | 200MHz |
| AXI-Lite | 100MHz，启用并验证异步clock选项 |
| 地址宽度 | 40bit候选；PS物理地址、dma_mask与DT保持一致 |
| Length width | c_sg_length_width=23 |
| Max burst | 64beat首选起点；更大值只在实测后采用 |
| DRE | 0；内存buffer地址至少64byte对齐 |
| 控制/状态stream | 关闭，避免无消费者的额外接口 |

官方默认Length width14不是适合本项目的值。8192×8+128=65664B，若CRC尾16B则65680B；16bit也不够表示最大记录。23bit目标避免这类低级截断，但软件仍必须检查每个BD长度。[A12][A13]

一个DMA先够用。三个量程在62.5MS/s、H/V IQ16下连续总载荷1.5GB/s；120us×3.3kHz时三档载荷594MB/s（不含pre/post/header）。单128bit×200MHz口理论3.2GB/s，不应因为旧500MS/s讨论就必然配置三个DMA。是否连续无损以DDR实测和合法波形组合决定。[A14]

三档诊断按3个带相同pulse_id的子帧串行发送。MCDMA只在需要独立软件队列/通道隔离且已批准时加入；它不创造DDR带宽。

## 6. 其他IP

- DDS Compiler：48bit相位、16bit sine/cosine候选；固定频率用programmed PINC，LFM由自研斜率控制器输出streaming PINC。数据延迟与脉冲包络显式对齐。
- Complex Multiplier或推断DSP48：用于复增益、NCO混频和2x2矩阵；普通定点乘加不必堆大量可视化模块。
- Block Memory Generator：RAW捕获采用TDP BRAM，A/B口具有明确角色；AWG用另一组双bank存储。不能默认URAM具有同样异步/非对称端口能力。
- XPM：同步/异步FIFO、总线握手和复位同步优先使用；多个时钟生产者不能同时写一只async FIFO。
- AXI BRAM Controller：PS装载AWG、可重载系数或小mailbox；inactive bank才可写。
- SmartConnect：控制平面和大数据平面分开实例。HP0最大128bit；加宽PL到512bit不会让单HP口自然快4倍。[A14]
- ILA/APM：至少观察ADC有效/标志、EOP/选档、bank引用、AXIS背压、实际TX时间和fault；APM只测量不改变流控。
- AXI GPIO/IIC/SPI：只在板级走PL引脚时添加。若时钟芯片或网络已接PS MIO，就使用PS外设；板载M.2经PS PCIe连接时也不默认增加PL PCIe IP。
- 不增加JESD204B/C数据收发IP：本方案为RFSoC内部ADC/DAC，不是外接串行JESD转换器。

## 7. 定点数值合同是配置的一部分

建议RAW记录仍为IQ16，内部计算先按24bit数据/18bit系数做资源探索，但这些数字不是最终精度保证。必须逐算子定义signed、binary point、乘法全精度、加法增长、舍入和饱和。

尤其RX逆增益可能跨很多数量级：不能把1e-5等系数硬塞进不合适的18bit小数格式导致近乎归零。采用已规定的粗指数/移位＋近1复系数，或扩大系数位宽；每脉冲的scale_id/指数必须随记录和TX任务保存。功率转W/dBm在PS/C按真实标校标度完成，不能把ADC code自动称为瓦。

在参数版本未冻结前，Codex只生成参数合同和测试，不自选二进制定点位置。
