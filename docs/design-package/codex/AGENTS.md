# 后续Codex开发边界（待用户批准设计后采用）

当前交付是DESIGN_PROPOSAL，不能把它当完成的RTL项目。首先与用户核对board/toolchain/TX rate plan；未确认前不写死引脚、PLL、DDR和未验证IP属性。

## 单一信息源

`contracts/system_contract.json`、`module_catalog.json`、`amd_ip_targets.json`、`frame_format.json`、`register_map.json`和`verification_matrix.json`是设计输入。拟议字段完善并审批后，同源生成SV常量/C头/MATLAB解析器/文档，禁止四份手动维护。

## 禁止的捷径

1. 不改500M→D8→62.5M、H/V共同选档或取消RAW来让测试容易通过。
2. 不把8个16bit word当8复样点；不猜RFDC tile/stream布局。
3. 不把普通ADC流当能背压的AXIS；不以DAC TVALID替代零码静音。
4. 不用一个双口RAM暗中承担写、回放、DMA、Fine四个端口。
5. 不为改善时序未经批准修改clock或添加false/multicycle path；不自动upgrade IP。
6. 不读取仿真真值、预知未来EOP或利用host完成时间改变已发脉冲。
7. 不把DMA计划/软件中断当字节有效或实际RF输出证据。
8. 不让Linux/GUI/VIO绕过PL或物理RF安全联锁。
9. 不下载未获批准镜像，不烧Flash/eFUSE，不默认开启高功率RF。
10. 不用零输出占位器返回PASS；缺功能、数据、工具或许可证明确标记NOT_IMPLEMENTED/BLOCKED/TOOL_UNAVAILABLE。

## 开发节奏

一次完成一个任务/模块：读取接口和数值合同→写测试及期望失败→实现→运行测试→审查diff和日志→记录残余问题。测试不运行就不宣称通过。每次产生的XCI/BD/bit/XSA/ELF都绑定工具版本和SHA256。

## 分工

先做平台壳、ADC/FIR/capture/DMA与DDS五模式闭环，再加三档完整资格、RX/TX校准、分数延迟和监测。B只增加观测/参数层，C复杂盲多径继续留上位机。需要PL DDR、MM2S、高速网络、多目标、SIC、实时host反馈等，先提出变更，不自动实现。
