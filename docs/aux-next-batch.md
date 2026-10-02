# AUX 独立采集下一批次核查

状态：第二十二阶段已完成独立aux_receive_guard及真实八路RX FIR切换验证。完整链路保护下限58拍，主六路连续性、ACK后反馈失配重资格化、来源角色及校准身份冻结通过；尚未接入仪器生产端。后续继续窗口、bank、TX元数据与PS命令；不计入第二十一阶段综合范围。

已有原语包括aux_source_controller、八路独立RX FIR、四组四bank、记录仲裁及tx_reference_analyzer。当前仪器receive_event_producer只产生主六路检测上下文，尚无AUX独立窗口命令/元数据生产端。不能因为存在第四组RAM就声明AUX回环采集已完成。

实施顺序：

1. 将AUX的来源有效性、独立source_epoch和两路校准身份隔离于主六路。模拟选择控制0/1/2映射帧source_role 0/2/3，不能直接复制控制值。真实开关反馈、极性与定时继续来自板级绑定。
2. 用实际RX级联TB验证来源切换后的settling/flush边界，覆盖FIR历史与流水寄存器；不能只把已有独立控制器默认42当成完整链路已验证的界限。切换不复位或停止主六路。
3. 实现独立AUX窗口请求、容量/时间检查及上下文冻结，使用第四组bank，关联64位TX生命周期token。AUX capture_id独立，帧通过metadata_id关联TX sidecar，不声称两个独立窗口同时发生。
4. 接入实际生产/完成/DMA路径，验证主三档与AUX同时采集、公平仲裁、有限容量丢帧计数和软复位归还。LOOPBACK来源不得自动回放。
5. 增加PS命令、同源字段与解码、定向TB和局部综合；关联模块完成后再做一轮完整数字核心综合。

物理输入匹配、实测增益与开关GPIO不阻塞以上逻辑开发；没有真实绑定时仍明确UNBOUND/invalid。

第二十三阶段已完成第3项的独立窗口跟踪、真实第四组bank绑定和TX token冻结。后续推进元数据/记录头/PS及生产端集成；尚无完整AUX上传链路。


第二十四阶段 AUX RAW帧头/96字节sidecar配对及C解码完成；4项相关回归、8项合同检查、XSim1项、A53十四源文件通过。模块综合WNS +6.926ns/WHS +0.082ns，133 LUT/1312 FF。尚需metadata_id分配、sidecar传输、PS及生产端接线；见 reports/stage24_aux_metadata.md。


第二十五阶段 AUX完成适配器完成：实际bank长度与所有权核验、metadata_id单调分配/耗尽保护；5项相关回归、8项合同检查、真实bank组合XSim1项通过。模块综合WNS +5.997ns/WHS +0.069ns，727 LUT/1378 FF。尚需触发容量预留、sidecar运输、统计发布、PS及仪器生产端接线；见 reports/stage25_aux_admission.md。
