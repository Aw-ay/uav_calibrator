# v0.6 DRFM / Fine / DMA Codex实施约束

实现基线：GitHub `feature/module-first-validation` / `e428b1fc196ba05701cb367560a0b181c3065ae1`，设计目标：本包v0.6。先读`GITHUB_BASELINE.json`和`CHANGELOG_v0.6.md`。

## 禁止项

1. 不把GSC改成8ns；保持2ns tick、core每拍4tick。
2. 不用`fraction=0`假装完成FD bypass；活动DRFM中不实例化FD63，不保留62点FD flush。
3. 不把Fine放A口，不让Fine/DMA影响已接受Replay的A口时间。
4. 不复制4套/3套Fine来回避吞吐设计；第一版`FINE_ENGINE_COUNT=1`。
5. 不把H+V合成功率当H/V共同半功率门限。
6. 不让Fine裁剪RAW或更改frame ABI5。
7. 不假设BMG一拍延迟；C02先量实际`READ_LATENCY_B`。
8. 不把128-bit reader又立即串行成64-bit后再拼回128-bit。
9. 不把3.2GB/s理论B口当DDR实测吞吐。
10. 不为200MHz闭时序加未经批准的false/multicycle。
11. 不让reset只清计数器而放任旧RAM response进入下一代bank。
12. 不改MATLAB/测试期望来迁就RTL错误；golden和RTL独立实现。

## 单一语义源

- RAW ABI：现有`frame_format.json` version 5。
- Fine：`fine_measurement.json` + `fine_pdw_format.json`。
- B reader：`b_port_reader.json`。
- Replay：`replay_contract.json` + `latency_contract.json`。
- 验证：`verification_matrix.json`。

每次只完成一个纵向任务：先失败测试→实现→定向TB→相关回归→diff审查。未运行工具就保持NOT_RUN。
