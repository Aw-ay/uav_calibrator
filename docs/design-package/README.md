# 无人机有源标定仪 Vivado / PL+PS 框架设计包

**状态：设计评审稿，不是已编译的 FPGA 工程。**

目标：把前述 A（仪器本体）、B（机载适配）、C（上位机处理）方案转为可由 Codex 分阶段实现的硬件/软件设计边界。没有改动 MATLAB 仓库。本包没有 `.sv/.xci/.bd/.xpr/.bit/.xsa/.elf` 实现工件，不能直接上板。

## 阅读顺序

1. `specs/00_总体设计.md`：分工、速率、框架和边界。
2. `specs/01_模块清单.md`：自研 RTL、wrapper 与 AMD IP。
3. `specs/02_AMD_IP配置.md`：参数目标、不能直接照抄的配置。
4. `specs/03_时钟缓存与数据契约.md`：确定性时间、RAM端口、DMA与格式。
5. `specs/04_BlockDesign方法.md`：BD层次、连接、地址、复位和构建方法。
6. `specs/05_PS软件.md`：裸机 bring-up、Linux驱动与上位机接口。
7. `specs/06_验证计划.md`：模块、系统、软件和板级门禁。
8. `codex/AGENTS.md` 与 `codex/任务顺序.md`：后续开发约束与任务拆分。
9. `specs/09_来源与待确认项.md`：已核实来源与必须确认的选择。
10. `contracts/*.json`：机器可读的设计提案。不是已生成的 XCI/设备树/寄存器实现。

## 固定主线

`4GS/s实ADC → RFDC DDC/8 → 500MS/s复IQ → 8复样点/62.5MHz → PL FIR/8 → 62.5MS/s H/V×三档`

保持无FASTSEL、整脉冲在线资格统计、H/V共同EOP选档、RAW记录、独立本地回放、统一TX源选择和硬件安全门。

## 两项不能隐含的板级事实

- AXRF47资料指向ZU47DR Gen3；前面曾讨论ZU27DR Gen1。具体实施板和版本尚需确认。
- RX输出62.5MS/s不等于DAC可以直接接入；TX必须闭合插值与真实DAC采样率。Gen3 8GS/s方案仅为候选。

## 交付后的下一步

先确认板卡、工具/BSP和TX速率方案，再由Codex建立最小平台壳层与自动测试。按任务顺序填充，每一步必须有实际日志；不能把本设计包称作已完成PL/PS代码。
