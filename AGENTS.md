# v0.5 实施边界

## 最新开发与验证节奏（第二开发分支）

用户要求从第一开发分支当前成果创建第二分支，并改用分层验证。当前分支为 `feature/module-first-validation`，起点为 `feature/complete-new-modules` 的 `a18e304`，继承第八阶段及此前所有已提交实现和证据。第一分支保留在原提交；以后两分支的新提交不自动同步。

本节优先于下文历史记录中的“每阶段完整联合综合”节奏：

1. 单模块开发：定向TB、受影响的相关回归、模块级综合；报告功能结果、综合资源和模块时序估算。不得仅因一个小模块完成而重跑整个数字核心综合。
2. 若干关联模块集成完成：核对接口/复位/CDC和约束，运行集成测试及适当的全量回归，再做一次完整数字核心综合。模块实现前明确所属集成批次及边界；顶层接口、跨域连接或时钟/约束出现实质变化时及时进行相应集成检查。
3. 真实板级顶层及约束齐备后：执行整机布局布线及建立/保持/脉宽、CDC、约束覆盖验收；只有这些检查满足要求，才能判断整机时序验收通过。模块综合和数字核心综合均不能代替该结论。

继续在当前任务和现有工作区操作，不使用子窗口或子任务；阶段完成后给出结果回复，不重复请求“继续/同意”。保留RF逻辑与物理绑定分离、未绑定静音和既有所有权/数值规则。当前工作区既有 `rtl/arithmetic/complex_cal_core.sv` 未提交修改保留，不自动纳入新提交。已生成但未纳入Git的本地构建产物留在同一工作区，仍须按输入哈希判断适用性，不把旧报告当作后续修改后的新结果。

## 当前模块批次

统一EVENT通道批次正在开发。第九阶段独立 `fault_event_retainer` 已完成：相关回归4/4、XSim1/1，125MHz模块综合WNS +6.854ns / WHS +0.071ns、失败端点0，资源447 LUT/585 FF，无BRAM/DSP，见reports/stage9_fault_retainer.md。实现为不可变待发送头记录加一个首快照/饱和计数聚合槽。只验证模块和相关组件，尚未接入数字核心。第十阶段独立event_priority_arbiter及其与retainer的组合验证已完成：相关回归5/5、XSim2/2，125MHz模块综合WNS +7.278ns / WHS +0.124ns，失败端点0、779 LUT/519 FF，无BRAM/DSP。见reports/stage10_event_priority.md。严格故障准入优先，不抢占已呈现普通记录，持续故障可阻塞普通流。第十一阶段故障聚合512bit编码、C解码与跨时钟邮箱组件验证已完成：相关回归6/6、XSim2/2、A53十个C源文件构建通过；局部综合WNS +1.676ns/WHS +0.057ns、失败端点0，CDC 0 Critical/8192 Warning/2 Info（握手邮箱数据位，未豁免）。见reports/stage11_fault_transport.md；后续仍需PS/CSR及真实生产端接线；这些关联模块集成完成后再运行完整核心综合。既有故障历史队列行为尚未改变，不能宣称系统高优先级fault保障已经完成。

第十二阶段统一 EVENT 软件读取器完成：相关回归4/4、A53十一个C源文件构建通过。新增显式 fetch/pop、未知格式原始记录保留及 POP 不确定状态保护；未修改RTL，未重复综合。见 reports/stage12_unified_reader.md。

第十三阶段统一 EVENT 可选接入 AXI CSR 完成：相关回归5/5、XSim1/1；局部综合 WNS +1.676ns/WHS +0.045ns、失败端点0，3826 LUT/11791 FF，CDC 0 Critical/8478 Warning/6 Info，未豁免。UNIFIED_EVENTS 默认0保留旧模式，主顶层尚未启用新通道。见 reports/stage13_unified_event_axi.md。

第十四阶段 PDW/RF_FAULT 统一 EVENT 已接入 calibrator_instrument_core 实际生产端、现有命令网关 EVENT 寄存器及 IRQ bit4，旧查询队列独立。75/75全量回归、XSim2/2、A53十一源文件通过；完整核心综合 WNS +0.337ns/WHS +0.037ns/WPWS +1.958ns，失败端点0；CDC 0 Critical/14075 Warning/15 Info，未豁免。原工程已更新并重开核验。见 reports/stage14_instrument_events.md。前述第九至十三阶段未接入状态为历史记录；后续 TX/DAC、AUX、FIR 生命周期和板级工作仍未完成。

第十五阶段 TX 数字 tail_empty 状态完成，实际校准/FIR尾部、零值有效拍、重触发、静音与复位验证通过；相关回归5/5、最终XSim1/1，TX链模块综合WNS +3.515ns/WHS +0.066ns、失败端点0。未重跑完整核心；该状态尚未接入任务完成事件，不能代表DAC消费完成。见 reports/stage15_tx_tail_status.md。

## 当前阶段授权

用户已要求按阶段恢复，全部在当前任务操作，不使用子窗口或子任务。第一阶段定位并修复采集子系统时序/CDC问题，验证后汇报并停在阶段边界。

第一阶段已完成：53项回归、3项XSim通过；采集综合 WNS +0.629 ns、CDC Critical 0。详见 reports/stage1_capture_closure.md。用户已再次要求继续，第二阶段业务数据顶层集成现已完成：55项回归、3项XSim及联合综合通过，WNS +0.387ns，CDC Critical 0。当前工程顶层calibrator_dataplane_system，尚非PS/RFDC板级顶层。见 reports/stage2_dataplane_integration.md；用户再次要求继续，第三阶段PS控制与实际采样生产端集成已完成：60项回归、4项XSim通过，联合综合 WNS +0.309 ns / WHS +0.037 ns、CDC Critical 0。当前工程顶层calibrator_instrument_core，仍非PS/RFDC板级顶层。详见 reports/stage3_control_ingress.md；用户再次要求继续；第四阶段 DDS/AWG PS 命令验证及软件接口已完成：62项回归、3项XSim通过，修复 AWG COMMIT 网关死锁及正常 STOP 的 PA 反馈误报；联合综合 WNS +0.391 ns / WHS +0.037 ns，CDC Critical 0。详见 reports/stage4_waveform_commands.md；用户再次要求继续，第五阶段最终资格 PDW 至 PS 命令队列已完成：64项回归、3项XSim通过；联合综合 WNS +0.391 ns / WHS +0.037 ns，CDC 0 Critical / 7945 Warning / 8 Info。见 reports/stage5_qualified_pdw.md；用户再次要求继续，第六阶段 PDW 到 PS 的可屏蔽电平中断已完成：64项回归、2项XSim通过，联合综合 WNS +0.391 ns / WHS +0.037 ns，CDC 0 Critical / 7945 Warning / 9 Info；新增同步链被识别为两级 ASYNC_REG。见 reports/stage6_pdw_interrupt.md，用户再次要求继续，第七阶段 DDS/AWG 源排空事件、命令身份/取消原因及 PS 队列中断已完成：66项回归、3项XSim、A53八个C源文件构建通过；联合综合 WNS +0.373 ns / WHS +0.037 ns，CDC 0 Critical / 7978 Warning / 10 Info。详见 reports/stage7_source_events.md。用户再次要求继续，第八阶段独立 RF 故障历史、PS 队列和中断已完成：68项回归、3项XSim、A53九个C源文件构建通过；联合综合 WNS +0.379 ns / WHS +0.037 ns，CDC 0 Critical / 7979 Warning / 11 Info。见 reports/stage8_rf_fault_history.md；本阶段暂停，不启动整机布局布线。统一EVENT及高优先级fault保留策略仍待完成。

## 历史暂停状态

2026-09-12 用户此前要求：“完成综合后暂停，汇报新分支的进度”。本轮综合和证据归档后暂停，不启动后续开发或实现任务。此前自主继续授权不覆盖此暂停指令。进度与剩余问题见 reports/branch-development.md。

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
