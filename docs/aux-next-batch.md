# AUX 独立采集下一批次核查

状态：实施准备，尚未完成AUX生产端集成，不计入第二十一阶段综合范围。

已有原语包括aux_source_controller、八路独立RX FIR、四组四bank、记录仲裁及tx_reference_analyzer。当前仪器receive_event_producer只产生主六路检测上下文，尚无AUX独立窗口命令/元数据生产端。不能因为存在第四组RAM就声明AUX回环采集已完成。

实施顺序：

1. 将AUX的来源有效性、独立source_epoch和两路校准身份隔离于主六路。模拟选择控制0/1/2映射帧source_role 0/2/3，不能直接复制控制值。真实开关反馈、极性与定时继续来自板级绑定。
2. 用实际RX级联TB验证来源切换后的settling/flush边界，覆盖FIR历史与流水寄存器；不能只把已有独立控制器默认42当成完整链路已验证的界限。切换不复位或停止主六路。
3. 实现独立AUX窗口请求、容量/时间检查及上下文冻结，使用第四组bank，关联64位TX生命周期token。AUX capture_id独立，帧通过metadata_id关联TX sidecar，不声称两个独立窗口同时发生。
4. 接入实际生产/完成/DMA路径，验证主三档与AUX同时采集、公平仲裁、有限容量丢帧计数和软复位归还。LOOPBACK来源不得自动回放。
5. 增加PS命令、同源字段与解码、定向TB和局部综合；关联模块完成后再做一轮完整数字核心综合。

物理输入匹配、实测增益与开关GPIO不阻塞以上逻辑开发；没有真实绑定时仍明确UNBOUND/invalid。
