# v0.6 Fine 数字链交付

本页保留2ca0959批次的Fine交付证据；后续FD63退出及新全核心结果见[无FD回放迁移](v06_replay_no_fd.md)。下文D11待办描述是该历史批次的范围边界。

本批完成 Fine 引擎、主三档接入、bank 分析引用、结果队列和 PS 命令。活动顶层为 `calibrator_instrument_core`，`ENABLE_FINE=1`；不是仅独立模块或候选 BD。原始设计包保持不可修改，本地合同保留既有 AUX 命令22–24，Fine 使用25/26、IRQ bit5。

## 数据与数值

每次真实资格准入冻结三档的 pulse_id、owner_epoch、generation、config_id、bank、RAW 起点/长度、GSC、onset noise、TOP4、peak 和来源质量。TOP 已是扣噪后的净功率，不再次扣噪。selected 在发布/丢弃决定时冻结。

一套200 MHz引擎依次处理三档，每档 H/V 各自寻找 coarse±8 内第一合法上升沿和最后合法下降沿，标记多交点/振铃。局部最多8点，2点插值及OLS拟合经方差加权融合；低SNR、来源错误、缺边沿、溢出均显式 invalid。Q16边沿是数值分辨率，不代表实物标定精度。

自然128位B口只读一遍，32个逻辑IQ样点本地缓存；内部最多每拍退还两个按时间排序的样点。奇数满窗在首尾访问同一物理字，8193次请求仍是一次逻辑遍历。局部查询和统计只用缓存，没有整窗副本或第二遍扫描。缓存采用同拍退休信用，保留逐样点顺序与因果判定。

stable body 为 ceil(rise)+4 到 floor(fall)-4（含端点）。本构建 guard=4、8 segments，由数值合同固定，没有声称提供动态guard CSR。各段累计相邻复乘、能量、精确时间中心；FINALIZE复用CORDIC及有符号256位算术计算均值、SNR、相干性、残余频率、chirp和H/V差分相位。频率参考RAW第0样点/GSC，RFDC物理符号需板级绑定。SNR饱和在flags bit0/1显式报告。无效结果不伪装成有效零值。

活动引擎选择 FAST_MATH=1：进位选择加减、32×32流水乘法、逐位精确除法；保留原慢速算术供比较。两种模式都使用相同有理数参考，未引入倒数近似或更改舍入。

## 所有权、端口与复位

bank有三种独立引用：RAW上传、回放、Fine分析。选中档发布时原子建立相应引用；未选中档可保持仅分析引用。所有返回均验证epoch/generation/bank，六种完成顺序、过期与重复返回均测试。最后一项引用归还前不能重新ARM。Fine返回先锁存RF域的epoch/generation/bank和错误位，再在owner消费ACK同拍更新元数据与调度状态；不会用跨域bank编号直接解码状态。

同一bank的B口先RAW，收到RAW引用归还后Fine才占用；整任务占用期间不切换尚未返回的RAM响应。不同bank可并行DMA/Fine，A口回放独立。12个主bank按轮转挑选，避免固定低编号优先。Fine不参与已合法DRFM的启动条件；长期DMA阻塞或分析积压仍会消耗有限bank容量，不能承诺无限输入缓存。

取消必须排空已发出的RAM响应再归还引用。捕获软RESET等待分析任务排空，已入队Fine结果及token保留；共享冷复位清队列。内部分析失败无伪造sidecar，返回准确引用并增加丢失计数。

## PS接口

- `CMD_FINE_PDW_PEEK=25`：无输入；原子快照36个32位字：count、dropped、token低/高、128字节Fine PDW。空队列token和PDW为零。
- `CMD_FINE_PDW_POP=26`：两个输入字组成64位token；只接受当前队首准确token。重复或过期POP失败，不误删下一条。
- IRQ bit5（0x20）反映非空电平，屏蔽IRQ不删除结果；RF/mem/ctrl跨域采用事务邮箱及电平同步。命令payload先锁存到mem域寄存器，再比较token、控制队列RAM和损失计数，避免把这些组合逻辑接在跨域数据总线上。
- 64条队列永不反压Fine生产者。满时丢弃sidecar并饱和累计dropped；同时发生队列溢出和分析失败计两次。token从1开始，u64耗尽后禁止复用，直到冷复位。
- `sw/common/fine_control.c`提供PEEK/POP启动和严格布局/标志/范围/长度解码，保留signed频率、chirp、相位。PS须按valid/quality判断字段，并处理dropped变化。

## 验证证据

本次验证覆盖当前工作区，包含此前已有、受保护且未纳入本批提交的6个RTL修改；其哈希单列于 `reports/v06_external_baseline.json`，另有1个受保护工程辅助文件。不能仅凭本批Git提交宣称另一干净检出具有同一综合网表。

详细命令、输出和源码哈希保存于本机 `reports/v06_fine_delivery.json` 及其引用日志；报告、检查点不作为GitHub工程源码上传。

- engine：31种窗口/波形，RAM延迟1/2/3、1..16384点、奇偶/环回、CW正/负/零频、上/下chirp及H/V不同边沿/增益/噪声、全部128字节逐位比较、逐退休IQ顺序、32点容量、结果反压、多个阶段取消排空。
- edge：320组精确根/方差/融合向量，慢模式另核对精确周期；signed256为320组，fast unsigned为255组；FINALIZE为18组均值/SNR/频率/chirp/相位/质量。
- 两样点统计：16558样点、6任务，包括短尾、极值、停顿、mask、分段及错误取消。
- service：256/16384点三档，准入后篡改生产端输入仍保持冻结上下文，RAW优先、异bank推进、故障计数与全部引用归还。
- 真实核心：ADC/FIR/检测/捕获生成的RAW和onset噪声供独立批处理参考；三档Fine结果、真实AXI PEEK/POP/IRQ、错误token、soft RESET排空/队列保留与回放生命周期一并检查。
- 队列：满、环回、重复/错误token、空/非空IRQ、冷复位、饱和损失、双损失、token耗尽。
- XSim：优化后的完整Fine引擎通过，与独立参考逐字段相符。
- 回放隔离补充对照：同一真实核心已接受任务，零DMA服务/Fine不调度与随机DMA停顿/Fine忙两次运行，actual_start_gsc及93个RAW样点的值/GSC逐项相同。
- 完整回归：最终命令接收及返回寄存修复后的131/131全部通过；此前6项受影响套件也独立通过；Cortex-A53公共库17个C源构建并验证Fine API符号。

### 资源及时序

模块OOC，xczu27dr-fsve1156-2-i，Vivado2025.2，clk_mem=200 MHz：62177 LUT、34654 FF、0.5 BRAM、48 DSP。WNS +0.604 ns、WHS +0.043 ns、WPWS +1.958 ns，失败端点0。快速算术前的慢速引擎报告不能替代本版证据。

集成时发现旧命令比较路径跨RF→mem域、WNS −0.780 ns；已增加mem域接收寄存级，未改变125/200 MHz约束或添加时序例外。修复后的Fine transport局部OOC为WNS +0.703 ns、WHS +0.033 ns，失败端点0。随后完整CDC检查定位12条返回编号直解码路径；RF域登记返回字段后，完整Fine service模块WNS +0.591 ns、WHS +0.043 ns、Critical CDC=0，无新增时序例外。

最终完整数字核心综合于2026-09-30 18:48完成（RF125 MHz、mem200 MHz、ctrl100 MHz）：WNS +0.318 ns、WHS +0.033 ns、WPWS +1.958 ns，建立/保持/脉宽失败端点均为0。资源224571 LUT、255714 FF、553.5 BRAM、2666 DSP。最终返回寄存修复消除了12条Critical；当前CDC为0 Critical、17800 Warning、25 Info，未做豁免。Warning为时钟使能控制的跨域结构，仍需在真实板级约束及CDC验收中逐类审查。

无时钟、未约束内部端点、组合环及锁存环均为0；仍有1697个输入和1345个输出未绑定I/O延迟，跨域时钟关系及未布线时钟网络也不构成板级验收。上述结果仅证明当前工作区数字核心综合估算满足已施加约束，不能称整机布局布线时序收敛。

### F7负载范围

12个连续脉冲，每脉冲三档各16384点，周期60606个mem拍（约3.3 kHz）；真实16-bank RAM模型同时进行完整RAW B口上传和同bank A口回放，逐样点比较。参考信号为测试中定义的单脉冲平滑边沿、已知噪声、双极化相位；所有36个结果与独立数值参考一致，且每周期前排空。最慢三档用时50101拍，即250.505 µs，低于303.03 µs周期；单引擎满窗在RAM延迟1/2/3时分别为16685/16686/16687拍。

这是明确波形/RAW及时归还条件下的吞吐测试。多交点会增加候选求解次数，外部DMA停顿会延后选中档分析；不能外推成任意波形或无限外部背压下的3.3 kHz保证。复杂/低相干波形输出quality，host可用RAW重算，不隐式二遍读RAM。

## 尚不在本批完成范围

板卡未连接：RFDC/PS/BSP物理绑定、实际DDR/cache/IRQ/SG验证、射频标定和完整板级布局布线时序仍待硬件条件。v0.6 D11旧FD63路径退出也是独立迁移项，Fine完成不表示这项已完成。

## 当前工作区重现入口

先按工程既有脚本生成capture RAM IP，再执行 `python tools/snapshot_v06_fine_inputs.py` 冻结输入。保持源码不变，运行 `python tools/run_regression.py` 和 `python tools/build_ps_common.py`。

Vivado2025.2使用batch分别执行 `hw/tcl/v06_fine_engine_fast.tcl`、`hw/tcl/v06_fine_service.tcl`、`hw/tcl/v06_fine_transport.tcl`、`hw/tcl/v06_fine_engine_tb.tcl` 和 `hw/tcl/instrument_v06_fine.tcl`；日志名须对应证据收集工具中的路径。原工程先备份后通过 `update_project_2025_2.tcl` 更新，再执行 `verify_project.tcl`。最后 `python tools/verify_v06_fine_integration.py` 检查实际报告和输入哈希；该命令不会再触发综合。

历史单个候选/缓存阶段报告仅证明当时的源码，不用于替代本批完整引擎验收。
