# 活动主包约束

- 本目录规范状态不是实现状态。不要宣称XCI/RTL/时序/板级已完成；只用实际运行证据。
- 只读本包contracts/specs作为实现基线；本包不附历史归档，不把旧PL D8/62.5MHz核心/FIR250MHz配置混入。
- 核心和全部FIR同clk_rf125MHz，DMA/记录clk_mem200MHz，控制100MHz候选。
- RFDC后500MS/s复数、4SPC，PL RX D4为HB19→FIR75，TX L4逆序；RFDC内部ADC D8不改。
- 8ADC全持续，六主+两独立AUX-MID；不能在主MID内部复用；8TXFIR不等8套DRFM。
- 所有可用bank广播滚动历史，触发选定一块继续捕获，窗口冻结直接双口读；bank编号无固定角色，无bank间隐式复制。
- 四组各4bank，A64×16384@125，B128×8192@200；count至少15bit。容量和检测延迟历史双检。
- 主三档共同脉冲上下文、原子准入、整脉冲共同选档；资格/记录准入/仲裁分别负责。
- 管理器单125MHz所有权，先pin再发descriptor；核对owner_epoch/group/bank/generation/consumer；旧ACK不释放新代。
- TX本地A口不经DDR/MM2S；安全合法任务因果检查；normal尾补零42仅PL最低，测量其他延迟；fault物理安全优先。
- DMA普通SG，cyclic关闭，512×256KiB软件槽，未消费不覆盖；捕获/RAM读完/BD完/RF完/host验证分开。
- ZU27DR只是design target，完整part/preset/工具/native映射仍null；Gen3 L16/8GS/s不可用作Gen1基线。
- 增益顺序、模拟阈值、detector最大延迟、各IP时延不得猜；未测则阻止实际精密ARM。
- 1536FIR/1932功能/2415～2815规划是预算；63tap分数延迟是占位；实际资源/误差/时序逐项验证。
- 本包仅提供设计说明、机器可读合同和任务计划，不附生成器或测试程序。实施时应先编写合同常量/ABI生成器与自动测试；JSON与文档同时修改。FIR整数系数从contracts/fir_coefficients.json按coefficient_set读取，生成COE时不得重新归一化。
