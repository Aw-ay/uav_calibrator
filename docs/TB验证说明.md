# 功能 TB 验证

本验证针对当前已实现数字模块。模拟输入由 TB 驱动；模拟射频、实际板卡时钟、SYSREF、完整 PS 驱动和整机时序不在本次功能仿真范围。缺失的整机功能不能由模块 PASS 替代。

2026-09-11 实测结果：17/17 组回归通过，4/4 个 Vivado 2025.2 XSim TB 通过。新增计分板完成 256 场景、6,339 次能量比较；三种临时 RTL 错误全部被断言检出。四个 XSim 仿真的 WDB 波形均已生成。

## 运行

在工程根目录运行：

```powershell
python tools/run_regression.py
python tools/run_functional_xsim.py
```

第一项运行 17 组软件/RTL 回归，结果写入 `reports/regression_latest.json`。RTL 使用实际 Icarus 仿真；Python 用于产生激励、独立参考计算及结果比对。

第二项固定使用本机 Vivado 2025.2，运行四个自检 SystemVerilog TB：新增随机检测计分板、原检测边界 TB、定时回放 TB、AXI/CDC 控制 TB。每个 TB 建立独立仿真工程，不修改实现工程顶层。结果写入 `reports/functional_xsim.json`；只有工具正常退出并出现对应 PASS 标记才通过。仿真工程与波形位于 `build/functional_tb/<TB名>/`，可在 Vivado 打开对应 XPR 查看。

## 覆盖范围

| 范围 | 验证方法与主要场景 |
|---|---|
| 合同与帧格式 | 地址/长度边界、CRC、损坏字段、符号 IQ |
| FIR 与八通道核心 | 独立整数卷积，舍入饱和、丢拍、重新采集、零码静音 |
| 控制 | AXI AW/W 分离、写掩码、配置跨域、快照、复位与故障 |
| 采集与 RAM | 四组广播、原子准入、预触发、环绕、bank 所有权、过期 ACK |
| 帧生成与上传 | 帧字节比对、满容量、背压、跨域、FIFO、四组仲裁 |
| 采集上传集成 | 实际管理器与 RAM/上传 RTL 连接、软复位排空、epoch/generation 拒绝旧描述符 |
| 原生过载 | 四样点逐路幅值、负满量程、未知阈值、缺失数据 |
| 定时回放 | 单样点/环绕/满 bank、时刻与相位、拒绝非法任务、故障排空与零码 |
| PS 接收核心 | 严格 C 编译、帧解析、槽状态、重叠缓冲区与大小溢出 |
| 脉冲检测 | 原定向边界 TB，加新增 256 场景与独立 64-bit 能量参考 |

新增 `tb/system/tb_detector_scoreboard.sv` 使用固定种子的 xorshift 激励，可重复运行。场景计数必须达到正常结束 128 次、源失效 64 次、复位 64 次。逐拍比较四个 signed 16-bit 分量的平方和；事件起点、排除 EOP hold 的独占终点、事件到达时刻使用脉冲长度直接计算。自检失败调用 `$fatal`，另设 watchdog 防止无响应被当作通过。

`tests/test_detector_scoreboard.py` 还在临时副本中注入三种错误：起始阈值 `>=` 改为 `>`、终点少加一、移除源失效检查。三者必须分别触发指定断言，原生产 RTL 不作修改。此项证明关键断言能发现错误，不代表代码覆盖率或全部故障覆盖率。

新增 TB 在 Icarus 下可加 `+waves` 导出 VCD；XSim 入口直接记录波形。旧系统 TB 中的行为 RAM 验证不代替厂商 BMG 的独立仿真，已有 BMG 验证日志单独保留。

2026-09-12 更新：新增 tb_range_statistics，完整回归 18/18、XSim 5/5 通过。此前 17/17 与 4/4 为历史检查点。新 TB 覆盖六路能量、峰值、满窗口、溢出、迟到质量与结果所有权。

2026-09-12 后续更新：新增三档资格和共同选档 TB，完整回归为 19/19。新 TB 已单独通过 Vivado 2025.2 XSim；functional_xsim.json 保留此前五项运行记录，本轮独立证据为 xsim_functional_tb_range_qualification.log。统一 XSim 入口现包含六项，未将历史报告伪改为本轮六项重跑结果。

2026-09-12 更新：完整回归 20/20；新增 tb_noise_snapshot 单独通过 XSim，覆盖噪声估计、起点快照和实际窗口能量换算。详见 reports/noise_snapshot_progress.md。

2026-09-12 更新：完整回归 21/21；新增 tb_range_linearity 单独通过 XSim，并通过 160 组 Python 大整数参考向量。详见 reports/range_linearity_progress.md。

2026-09-12 更新：完整回归 22/22，新增脉冲上下文关联 TB 单独通过 XSim。详见 reports/pulse_context_join_progress.md。

2026-09-12 更新：完整回归 23/23；新增四槽上下文池 TB 单独通过 XSim。详见 reports/pulse_context_pool_progress.md。

2026-09-12 更新：完整回归 24/24；tb_pulse_qualification_engine 单独通过 XSim。测试使用实际上下文池、噪声能量换算、线性比较和选档模块，详见 reports/pulse_qualification_engine_progress.md。

2026-09-12 更新：完整回归 25/25；tb_qualification_bank_commit 单独通过 XSim，使用实际 capture_bank_manager 验证资格先于发布及三档身份校验。详见 reports/qualification_bank_commit_progress.md。

2026-09-12 更新：完整回归 26/26；tb_qualification_publish_bridge 单独通过 Vivado 2025.2 XSim。真实资格引擎到 bank 管理器的联测覆盖冻结映射/记录头、四笔并发、过期拒绝和事件阻塞。此层尚未布局布线，详见 reports/qualification_publish_bridge_progress.md。

2026-09-12 更新：完整回归 27/27；新增 tb_qualified_record_upload 和 tb_qualification_record_source 均通过 Vivado 2025.2 XSim。联测验证选档后的真实 RAM 行为数据经组帧/CRC/CDC/FIFO 输出与独立 Python 200-byte 帧逐字节一致，并校验回放引用释放。详见 reports/qualified_record_upload_progress.md；主顶层集成及整机时序仍未完成。

2026-09-12 更新：完整回归 28/28；复位协调器单位 TB 和真实资格/记录链排空 TB 通过 Vivado 2025.2 XSim。Icarus 另运行短脉冲请求系统场景，确认迟到统计、满 FIFO、回放尚未结束时不会提前更新 epoch。详见 reports/qualified_reset_drain_progress.md；生产端排空证明来源及主顶层实际连接仍待集成。
