# v0.5 实施边界

## 当前阶段授权

用户已要求按阶段恢复，全部在当前任务操作，不使用子窗口或子任务。第一阶段定位并修复采集子系统时序/CDC问题，验证后汇报并停在阶段边界。

第一阶段已完成：53项回归、3项XSim通过；采集综合 WNS +0.629 ns、CDC Critical 0。详见 reports/stage1_capture_closure.md。用户已再次要求继续，第二阶段业务数据顶层集成现已完成：55项回归、3项XSim及联合综合通过，WNS +0.387ns，CDC Critical 0。当前工程顶层calibrator_dataplane_system，尚非PS/RFDC板级顶层。见 reports/stage2_dataplane_integration.md；按阶段边界暂停，未启动第三阶段。

## 历史暂停状态

2026-09-12 用户最新要求：“完成综合后暂停，汇报新分支的进度”。本轮综合和证据归档后暂停，不启动后续开发或实现任务。此前自主继续授权不覆盖此暂停指令。进度与剩余问题见 reports/branch-development.md。

## 2026-09-12 持续开发授权

用户明确要求新建 Git 分支并在新分支完成所有新模块，不再请求“继续”或“同意”。已初始化本地仓库，main 基线提交为 78fd4a0，开发分支为 feature/complete-new-modules。后续按合同自主开发、验证、集成和本地提交；不因每个模块完成而等待用户继续。该授权替代旧文档中“非 Git/仅备份”及实施暂停的历史描述。硬件待绑定参数保持外置，未经实测不得声明板级验收。

用户于 2026-09-11 要求按 v0.5 使用 SystemVerilog / Vivado 2025.2 在现有工程完成实现，并确认板卡资料位于 E:/temp/save_v2.1。该授权替代旧设计提案的实施暂停状态；不代表板级待验证参数已验证。

活动设计来源：docs/releases/Vivado_PLPS_标定仪框架设计包_v0.5/；contracts/ 已同步该包。docs/design-package/ 与 docs/legacy-contracts-before-v0.5/ 仅用于历史溯源。

活动速率为八路500MS/s复数4SPC→HB19 D2→FIR75 D2→125MS/s；核心及FIR同125MHz，DMA200MHz；四组各四个16384×64bit轮换bank。旧D8/62.5MHz核心和两bank要求被本次用户指定的v0.5替代。其余证据、安全、数值与所有权规则继续适用。

当前工程为部分已验证数字实现，不能把它当完整板级标定仪。Vivado2025.2和v0.5速率已由用户指定；PS clk_mem目标200MHz已确认。未确认的引脚、射频PLL配置、实物速度等级与未验证IP属性不得猜填；DDR候选以板卡原理图和已记录的厂家参数证据验证。

## 单一信息源

用户确认的 RF 抽象边界：H/V 三档、增益标定和 RF 联锁采用逻辑抽象与物理绑定分离。缺少最终 RF 前端资料不阻塞 PL/PS 功能、寄存器、状态机、校准表格式与验证环境的完成。实际控制码、实测增益、GPIO 引脚、有效电平及联锁时序参数保存在独立板级绑定合同，不得硬编码到核心 RTL。未绑定状态必须显式报告，不能伪称校准有效或允许实际 RF 使能。测试绑定只用于仿真，不得自动转为生产绑定。详见 contracts/rf_binding_policy.json 与 docs/RF逻辑与板级绑定.md。

`contracts/system_contract.json`、`module_catalog.json`、`amd_ip_targets.json`、`frame_format.json`、`register_map.json`和`verification_matrix.json`是设计输入。拟议字段完善并审批后，同源生成SV常量/C头/MATLAB解析器/文档，禁止四份手动维护。

## 禁止的捷径

1. 不改v0.5的500M→PL D4→125M、H/V共同选档或取消RAW来让测试容易通过。
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
