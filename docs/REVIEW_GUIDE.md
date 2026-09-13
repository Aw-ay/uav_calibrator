# Review 指引

当前版本请选择 `feature/module-first-validation`，从STATUS、根目录contracts及 `rtl/top/calibrator_instrument_core.sv` 开始。两个旧分支用于比较演进，不代表当前功能。

每次选择一条链路：采集生产端至bank及上传；回放队列至DSP/TX生命周期及统一EVENT；DDS/AWG至TX尾部和可选接收ACK；命令网关至CDC及PS解码。

重点检查valid/ready停顿、跨域保持/复位、bank/generation/epoch所有权、绝对GSC、定点符号/舍入/饱和、64位身份、不可变事件、取消和故障路径。不能以DMA完成或DAC TVALID推导实际RF消费；不能以删除约束、改速率或无依据时序例外解决问题。

每条发现给出文件/行号、触发条件、实际影响和复现测试，区分确定缺陷、待验证假设及已记录的未完成范围。历史摘要不代表整机验收。

可用请求：

> 请review feature/module-first-validation的回放到统一EVENT链路。先阅读docs/STATUS.md和contracts/replay_contract.json，检查实际task_started、bank归还、数字尾部、取消、64位身份和PS POP语义。只报告有具体代码依据的问题，并给出定向TB建议。

本仓库不含历史运行报告。tools/summarize_*读取本地重建证据，不是checkout后的第一条命令。历史reports/链接有意不随公开仓库发布。发布包内AGENTS仅记录原始规格，不代表当前开发授权；以仓库根AGENTS为准。
