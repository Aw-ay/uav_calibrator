# 04 Block Design集成方法

本包为语义连接计划，不提供假想可运行Tcl。以contracts/bd_connections.json和amd_ip_targets.json为输入，先锁定完整part、工具/IP版本、板卡preset和时钟原理图，再生成BD。

## 外层BD

PS控制HPM→控制SmartConnect→RFDC/DMA/自研CSR/AWG/系数孔径。冻结记录M_AXIS128@200MHz→AXIS FIFO→DMA S2MM；DMA的S2MM与SG两个master→memory SmartConnect→PS HP0。所有中断核对实际域后锁存/同步再接GIC。不可漏连SG或假定HP0具备一致性。

## 内部PL

ADC原生adapter→epoch/过载旁路→RX D4 SSR→舍入→检测/资格/四组bank并行。三档冻结且统计完成后选档，记录策略发布descriptor经CDC至200MHz reader。Reader解环/奇数重排，formatter负责完整记录字节/TLAST，归还token回125MHz。

A口回放不经过DMA：合法任务→绝对时刻预取→RXCAL→分数延迟→目标矩阵/多普勒→sourceMUX→8DAC路由→逐DAC TXCAL→TX L4→DAC adapter。idle真实零，fault走物理联锁。

## 域划分与管线

FIR全部clk_rf125MHz，无125↔250 gearbox；每方向SSR自然4/2/1或1/2/4。clk_rf与clk_mem的数据并非先跨一条4GB/s FIFO，而由双时钟冻结RAM读出，描述符/返回事件跨FIFO。ARM/commit/event用正确稳定总线握手，不逐位同步多字段。

RAM输出同步读延迟必须定义credit/预取；TREADY低时已有请求仍会返回。各域reset和XPM busy按匹配版本规则处理。不得用false_path掩盖未设计的跨域，不得让VIO绕过RF安全。

## 输出门

保存XCI或可复现生成脚本、IP配置导出、端口表、时钟/复位报告、每FIR和RAM OOC、address assignment、report_cdc、DRC、WNS/TNS和利用率。真正通过后才更新实际latency/capability，设计文档不能提前填成功。
