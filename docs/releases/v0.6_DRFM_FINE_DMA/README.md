# 无人机有源标定仪 Vivado / PL+PS 框架设计包 v0.6 — DRFM / Fine / DMA

**状态：设计变更基线候选，不是已实现、已综合或已上板工程。**

本包沿用用户提供的 `Vivado_PLPS_标定仪框架设计包_v0.5` 的目录、合同和 Codex 实施方式，并针对当前 GitHub 工程 `feature/module-first-validation` / `e428b1fc196ba05701cb367560a0b181c3065ae1` 收敛 DRFM、Fine 精测、RingBuffer B口和 DMA 链路。未受影响的 ADC/FIR/RF 安全/PS 基础框架继续继承 v0.5；受影响内容在本版中重新写定，禁止同时引用旧结论造成双重基线。

## 本版最重要的冻结决策

| 项目 | v0.6 决策 |
|---|---|
| GSC | 继续 2 ns/tick；125 MHz core 每拍 +4 tick |
| DRFM整数延时 | 可执行步进 4 GSC tick = 8 ns；off-grid/too-late 严格拒绝，不自动round |
| 分数波形延时 | 从活动 DRFM 数据路径删除；`fraction_q32` 暂保 ABI，但只允许 0 |
| A口 | 只承担 capture write 或 frozen deterministic replay；Fine/DMA不得占A口 |
| B口 | 128 bit @200 MHz，自然word满速流水；Fine与DMA共享物理B口体系 |
| 奇数start | 不在Fine前跨word重排；`start_ptr>>1`自然读，`start_ptr[0]`生成首mask；仅DMA packer做紧凑化 |
| Fine数量 | 1套全局Fine Engine；内部H/V并行；主HIGH/MID/LOW三档均做Fine |
| Fine扫描 | 正常模式1遍B口RAM；局部16–32 sample delay buffer解决边沿结果与PDW统计因果关系 |
| H/V | H、V分别定义功率、半功率边沿和PW；量程选择仍H/V共同 |
| 半功率 | 噪声感知 -3 dB：`P50 = N + 0.5*(TOP-N)`；旧 `max(p)/4` 明确为 HALF_AMPLITUDE_LEGACY |
| RAW DMA | Fine不裁剪RAW；RAW继续上传冻结 capture window，Fine为独立sidecar |
| B口并发 | 同bank Fine/DMA互斥；不同bank Fine与DMA可并行；A replay与同bank B Fine/DMA可并行 |
| bank引用 | 拆成 `analysis_ref` / `upload_ref` / `replay_ref`；全部归零且无在途响应才rearm |

## 目录

```text
Vivado_PLPS_标定仪框架设计包_v0.6_DRFM_FINE_DMA/
├── README.md
├── CHANGELOG_v0.6.md
├── GITHUB_BASELINE.json
├── SHA256SUMS.json
├── 设计包检查记录.json
├── specs/
│   ├── 00_总体设计.md ... 14_合并决策与兼容性.md
│   └── 15_Fine精测设计.md
├── contracts/
│   ├── v0.5继承合同（按本版必要项修订）
│   ├── b_port_reader.json
│   ├── fine_measurement.json
│   ├── fine_pdw_format.json
│   ├── fine_result_transport.json
│   ├── replay_processing_chain.json
│   └── calibrator_replay_system.json
└── codex/
    ├── AGENTS.md
    └── 任务顺序.md
```

## 阅读顺序

1. `CHANGELOG_v0.6.md`：先看本次为什么改、哪些旧结论失效。
2. `specs/00_总体设计.md`、`10_RingBuffer设计.md`、`12_RingBuffer到DMA.md`、`13_RingBuffer到DAC与DRFM.md`、`15_Fine精测设计.md`。
3. `specs/06_验证计划.md` 和 `contracts/verification_matrix.json`。
4. `codex/AGENTS.md`、`codex/任务顺序.md`。
5. 实施时回到 `GITHUB_BASELINE.json` 指定的 commit 对照实际 RTL；本包不允许用“规格写了”替代真实测试。

## 不变的基础主线

- RFDC DDC后每物理ADC 500 MS/s complex，4复SPC @125 MHz。
- PL RX：HB19 D2 → FIR75 D2，最终125 MS/s H/V。
- 四组×四bank，每bank 16384×64 bit；A64@125 MHz，B128@200 MHz。
- RAW frame ABI v5 每样点 `H_I/H_Q/V_I/V_Q` 共8 bytes，本版不因Fine升级RAW header ABI。
- AXI DMA S2MM 128 bit @200 MHz，普通SG，cyclic默认关闭。
- ZU27DR仍只是数字设计目标；真实板卡、RFDC映射、SYSREF、模拟增益、RF联锁等未确认项不能猜。

## 证据边界

本包生成动作只做文档/JSON结构与一致性检查。历史回归、历史综合 WNS、旧 BMG 延迟都不是 v0.6 修改后的新证据。尤其 `B_READ_LATENCY`、新DRFM数字流水延迟、200 MHz Fine 时序、DMA/DDR持续吞吐都必须重新测量并回填。
