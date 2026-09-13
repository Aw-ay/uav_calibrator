# UAV Calibrator / ZU27DR

SystemVerilog + Vivado 2025.2 标定仪工程，设计基线 v0.5。

**数字核心开发版本，尚未完成真实 PS/RFDC 板级集成、布局布线和实物验收。**

请优先审查 `feature/module-first-validation`。`main` 保存初始基线，`feature/complete-new-modules` 保存第一开发分支。公开版历史已移除报告和构建产物，因此提交号与本机原始工程不同。

|目录/入口|内容|
|---|---|
|[docs/STATUS.md](docs/STATUS.md)|当前进度与未完成范围|
|[docs/REVIEW_GUIDE.md](docs/REVIEW_GUIDE.md)|ChatGPT / 人工 review 指引|
|[vivado/uav_calibrator.xpr](vivado/uav_calibrator.xpr)|可打开的数字核心源码工程|
|[docs/BUILD.md](docs/BUILD.md)|工程重建和测试入口|
|rtl/|SystemVerilog 核心、采集、回放、发送和控制|
|contracts/|活动 JSON 合同和接口定义|
|tb/、tests/|定向和集成 TB、数值/软件测试|
|hw/|约束、系数、IP 配置源和 Vivado Tcl|
|sw/|PS 通用 C 库、生成头文件和 MATLAB 解析定义|
|tools/|合同生成、回归及本地证据生成脚本|
|docs/releases/|活动 v0.5 框架设计包，展开以便 review|
|docs/reference/|主设计包文本源码参考，见来源清单|

原有历史文档和合同中的 DESIGN_ONLY、旧顶层名称及 reports/ 链接可能反映早期状态；以当前 RTL、测试和 STATUS 为准。发行包内合同供溯源，根目录 contracts/ 为实施输入。

仅上传源码、工程配置、测试和设计文档。不上传综合报告、DCP、仿真输出、缓存、BIT/XSA/ELF 或备份压缩包。测试在本机重新生成 build/ 和 reports/。

未绑定 RF 控制保持安全状态。200 MHz 是 PL 存储时钟目标，不是已确认的射频相干参考。八路 TX 处理不代表八套独立任意波形发生器。
