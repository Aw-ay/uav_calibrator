# 07 八ADC与独立AUX-MID

| 逻辑组ID | H ADC | V ADC | 物理掩码 |
|---|---:|---:|---:|
| 1 HIGH_HV |0|4|0x11|
| 2 MID_HV |1|5|0x22|
| 3 LOW_HV |2|6|0x44|
| 4 AUX_MID_HV |3|7|0x88|

总掩码0xFF，主0x77。编号不是Tile/Block原生索引；channel_roles.json中物理映射仍空。各ADC/DDC/FIR历史独立，8ADC数据持续更新；AUX不复用主MID，不能仅在loopback模式才打开其采样。

AUX独立模拟MID范围，可选SAFE_TERMINATED、REDUNDANT_EXTERNAL_MID、RF_LOOPBACK。切换H/V成对提交，只影响ADC3/7，不改变主六路数据源或复位主链。没有真实模拟开关/耦合/衰减限幅时不报告切换成功。RF发射仍须联锁。

切换增加source_epoch，样点编号继续；模拟稳定、RFDC历史、PL响应跨度和实现流水完成前标无效。PL两级最小history清除按ceil166/4=42输出间隔，不按166ns群延迟等待。各源状态、校准键、实际TX事件都要在sidecar可追溯。

AUX bank独立触发和资源；loopback不能自动成为DRFM输入，不混入主三档资格。冗余只能在外部MID路径和独立校准有效后，通过脉冲边界显式授权替代原MID；不能覆盖HIGH/LOW量程能力或共同天线/时钟/FPGA故障。

持续数字采样不等于主天线在TX期间一定能同时获得有效外部信号；单天线半双工的RF有效区间和质量标志仍必须真实反映。

## 来源枚举不可直接复用

AUX切换控制值0/1/2分别为安全/外部冗余/回环；上传帧和内部描述符的source_role值分别映射为0/2/3。主三档正常外部测量为1。见channel_roles.source_role_encoding，不得将控制寄存器原值直接复制到帧。
