# 下一关联批次：REPLAY 退休事件

状态：第十八至二十一阶段已依次完成独立排空观察、完整身份事件、共享TX生命周期及仪器顶层接线。85项完整回归、核心XSim及提前停止/延迟确认的整核心测试通过；第二十一阶段完整核心综合结果以 reports/stage21_replay_lifecycle_integration.md 为准。以下保留实施依据与次序，不再表示这些接线尚未实现。

## 已核实的生产端

- calibrator_replay_system.task_started 是实际 frozen_replay_reader 接受，submit_accepted 只是描述符入队，两者必须区分。
- active_task 保留1536位描述符，含64位 task_id、pulse_id、owner_epoch、generation，以及 config/fir/校准身份。不能把64位 task_id 截成 DDS/AWG 的32位 command_sequence。
- token_valid/ready 表示 RAW 读口及在途访问结束，允许释放 bank 读取引用；它不表示 FD63、Target 或 TX FIR 已排空。
- replay_processing_chain 在正常结束时产生 dsp_done；取消时可能只有 cancelled/busy 变化，不保证正常 done 脉冲。因此不能只接 dsp_done，否则首样点前取消和中途故障可永不退休。
- 最后 RAW 数据与 reader token 可以同拍，DSP busy 在后续时钟才更新。读取退休当拍的 !dsp_busy 不能单独作为排空证据。
- 当前 dispatcher 可在读口归还且处理链恢复后派发下一任务。新的生命周期准入必须加入派发条件，并保持已接受绝对 GSC 不被 EVENT/PS 背压更改。

## 实施次序

1. 定义保留完整回放身份的事件格式和同源 C/SV/MATLAB 解码；优先采用明确的新事件类型，禁止挤占现有格式保留位后仍沿用旧标签。保证 PS 能无歧义关联 RAW、任务、生命周期令牌。
2. 独立实现 RAW 退休、DSP 排空、TX 尾部及可选接收确认的汇合；保留 bank 归还时点，不用等待 RF 反馈占用已无读取需求的 RAM。
3. 用真实 reader + processing TB 覆盖正常、首读前取消、读中取消、欠载、GSC 跳变、FD/Target 尾部和令牌阻塞。任务与取消信息在新配置或新 epoch 到来后仍保持。
4. 将生命周期容量加入 dispatcher 的派发准入。排队任务在资源恢复后重新做时间/上下文合法性检查，晚到明确拒绝，不能挪动已承诺时刻。
5. 接到实际仪器统一 EVENT，再运行关联集成回归及一次完整核心综合。板级消费证据仍由独立物理适配器提供。

## 其余工作边界

AUX 独立触发/采集/上传和 TX 事件关联、主 FIR 运行时系数装载与引用释放、平台 PS/DDR/DMA/RFDC 连接及 BSP、板级绑定和物理约束仍另有实现/验收工作。上述可独立开发的逻辑不因 RF 前端资料未齐而暂停；实际消费、射频幅相和整机时序则必须保留真实板级证据门槛。
