# 工程与验证入口

使用Vivado2025.2并安装ZU27DR器件支持，打开 `vivado/uav_calibrator.xpr`。顶层为calibrator_instrument_core，是数字核心源码工程，不是完整板级BD。

hw/ip保存三个现有probe的XCI配置，无检查点。RFDC probe仅用于接口研究，不代表真实物理时钟或通道绑定。IP输出应在本机按需要生成，禁止无声升级IP。

重建XPR（已存在时拒绝覆盖）：

```powershell
vivado -mode batch -source hw/tcl/create_review_project.tcl
```

该命令仅组织源码及配置，不综合或布局布线。原create_project/create_probe_ips为历史流程；probe脚本会综合RAM/DMA，不是轻量打开命令。

轻量合同检查：

```powershell
python -m unittest discover -s tests -p test_contracts.py -v
```

完整回归入口为 `python tools/run_regression.py`，需要Icarus Verilog及C编译器。部分脚本使用本机Windows工具路径，迁移时检查tests及tools/build_ps_common.py。XSim入口为hw/tcl/run_functional_tb.tcl。

首次运行创建本地build/和reports/，均被Git忽略。整核心测试需要先生成RAW/系数向量，应使用对应Python入口。历史报告汇总脚本需要本地生成的报告；本仓库不附已有运行产物。

单模块改动做定向TB、相关回归和模块综合；关联模块完成后再全核心综合；真实板级顶层/约束齐备后进行布局布线和时序验收。
