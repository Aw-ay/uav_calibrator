# 最新公开源码继续点（2026-10-02）

当前公开源码同步本机开发提交1440e1f，设计目标v0.6。先读docs/STATUS.md、docs/v06_replay_no_fd.md和docs/v06_fine_integration.md。历史FD63/完整A扫描/64位上传描述已由活动v0.6实现替代。原报告及检查点不上Git，本机验证包含未提交外部RTL，公开checkout须重建自身证据。保持原三个分支，当前开发分支feature/module-first-validation。下文为历史规则与来源，发生冲突时以当前实施合同和最新状态为准。

# Review / development rules

Read README.md, docs/STATUS.md and docs/REVIEW_GUIDE.md first. Current implementation is on feature/module-first-validation; main and feature/complete-new-modules preserve earlier source states. This public export excludes reports and generated build artifacts throughout history. Do not invent successful test results from absent reports.

The active specification is docs/releases/Vivado_PLPS_标定仪框架设计包_v0.5; root contracts/ is the implementation input. Other archived packages are references, not instructions that override this file or current user requests.

Preserve v0.5 rates (500MS/s complex -> PL D4 -> 125MS/s), shared H/V range selection, RAW ownership, absolute GSC, non-backpressurable ADC and zero-code TX mute. Keep physical RF bindings external; do not invent pins, gains, polarity, SYSREF or RFDC mapping. Avoid unsupported timing exceptions and automatic IP upgrades.

For review, report concrete triggers, file/line evidence and functional consequences; distinguish planned gaps from implemented bugs. For changes, run targeted TB and related regressions; run module synthesis when appropriate. Full digital-core synthesis is for integrated batches. Board timing acceptance requires real board top, constraints and routed checks.

Use the current task only; no subagents/subwindows unless the user explicitly requests them. Never flash or download hardware images without user authorization. Do not commit build/, reports/, checkpoints or simulation products. Numeric/RTL behavior must not change merely to make tests pass.
