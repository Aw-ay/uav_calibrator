# 第二阶段：共享银行与业务顶层集成

用户已授权在当前任务内继续，逐阶段交付，不使用子任务。按现有接口落地数据平面，板级绑定保持外置。

1. 增加只读 replay_leased 状态，从银行管理器逐层传出，禁止由软件猜测 FROZEN 即有回放占用。
2. 实现 capture_replay_binding：将一基 group/零基 bank 转为16银行索引；从实际 owner 状态查代次、冻结、资格和回放租约；校验脉冲、起始样本、读范围；读响应锁存索引；返回 token 校验 consumer/epoch/generation 后仅产生一次 ACK。
3. 实现 calibrator_dataplane_system，实例化现有采集、回放和发送模块，共享唯一 capture RAM；回放 DSP 输出接 DRFM，LIVE 显式选择三档之一且无效选档静音，软复位阻止新任务并排空。
4. 先运行真实缺模块的失败测试，再跑 binding 边界测试和 capture→RAW/DMA→replay→DSP 的真实 RAM 集成测试。发送模块保持 UNBOUND 静音测试。
5. 登记统一回归和 XSim，更新原工程源文件；保存阶段报告后暂停。本阶段不把外露的配置事务端口说成已实现PS装载，也不声称已完成RFDC/PS板级顶层或整机布线。

验证包括四组索引、越界、过期身份、未持有租约、读响应流水索引、重复/过期token，以及FIFO背压期间RAW与replay独立占用。保持8ns/5ns时钟，不添加时序例外。

执行补充：新增未提交回放租约的软复位用例，证实原银行管理器在所有消费者排空后通过 epoch 更新清除租约，无须新增取消 RTL。工程综合顶层更新为 calibrator_dataplane_system；原 calibrator_top 数值核心保留。
