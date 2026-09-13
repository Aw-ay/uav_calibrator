# 当前源码状态

截至2026-09-13，原始工程第二十一阶段，原提交9e27227。

已集成到 `rtl/top/calibrator_instrument_core.sv`：主六路RX/FIR/检测、三档H/V共同选档、RAW所有权与上传数字路径、RAW回放/RXCAL/FD63/Target、DDS/AWG/TXCAL/TX FIR、命令网关及统一PDW/故障/TX/回放身份EVENT。回放接受、RAW归还、数字尾部与接收确认具有独立语义。

尚未完成：AUX独立采集及TX关联；主FIR运行时重载和版本pin/释放；真实PS/DDR/DMA/RFDC平台及BSP、裸机/Linux驱动与服务；物理RF绑定、MTS/SYSREF、布局布线和上板验收。现有PS通用C库不等于板级软件栈。模块存在不代表其全部验收条款满足。

本地第二十一阶段曾运行85项回归、2项核心XSim和提前停止/延迟接收确认变体；数字核心综合WNS +0.318ns、WHS +0.037ns，失败端点0。CDC Critical 0，但仍有15355条Warning，未豁免。按发布范围不上传原报告，这些数字仅是来源摘要；修改后应重跑适用测试，不作为新checkout已验证的声明。

上传版包含原工作区complex_cal_core.sv的实际内容。它原先未提交，但包含在上述本地运行输入中；原始仓库未改变。公开版工程组织和XPR的检查只覆盖打开、源文件解析和编译顺序，未为目录整理重跑综合。
