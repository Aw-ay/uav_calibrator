# 当前源码状态

2026-10-02上传，来源为本机feature/module-first-validation提交1440e1f，设计目标v0.6。公开仓库保留已有三个分支历史，当前分支更新到本阶段源码。

数字侧已接入自然128位B口/DMA记录上传、在线body统计、三档Fine精测及三引用/64项PS结果队列（PEEK25/POP26/IRQ5）、AUX独立捕获和任务/GSC Doppler。活动回放为RAW→RXCAL→Target；FD63、表版本依赖及62点补零已退出。非零fraction在RAM读取前拒绝；RAW到Target数字参考延迟12GSC tick。安全控制与内部算术载荷分离，公共RAW/Target仍故障立即静音。

本机交付来源记录133/133回归、640整数向量、13最早/相邻任务相位用例通过；完整数字核心综合WNS+.629ns/WHS+.033ns，失败端点0；209094LUT/245540FF/553.5BRAM/2414DSP，比此前Fine核心减少252DSP。CDC0Critical/17760Warning/25Info未豁免。报告与检查点未上传。这些数值属于本机验证工作区，包含6个受保护外部RTL修改；本次仅同步已提交源码并保留公开库原有对应文件，不能将本机网表结果直接视为公开checkout的综合验收。

公开源码交付入口：docs/v06_replay_no_fd.md、docs/v06_fine_integration.md、docs/superpowers/plans/2026-09-29-v06-migration.md。根目录contracts是实施合同，docs/releases/v0.6_DRFM_FINE_DMA保存设计包文本。

待完成：真实PS/RFDC平台完整绑定、时钟/MTS/SYSREF及RF GPIO/极性/实测校准合同；裸机DDR/cache/IRQ/SG及台架实测；Linux驱动/服务、完整校准版本生命周期、板级CDC/约束与布局布线验收。1697输入/1345输出尚无真实板级I/O延迟。当前仍是数字核心源码工程，不是可直接上板的完整固件。

本次公开目录另外通过8项合同单元检查、640个无FD定点向量及13个任务相位边界用例；这些定向检查不替代公开checkout的完整回归与综合。
Vivado2025.2原公开工程已加入新增模块并更新编译顺序、排除退役源，更新与重新打开检查均通过。
