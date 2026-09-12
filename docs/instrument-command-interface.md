# 第三阶段数字核心接口

`calibrator_instrument_core` 接收 AXI-Lite 命令、RFDC 原生 ADC 总线，输出 RAW AXIS、原生 DAC 总线和规范化 RF 控制请求。PS/RFDC IP 实例及板级绑定在此核心之外。原有低地址 CSR/PDW 队列尚未接入本顶层；不能将旧 CSR 软件直接指向本接口。

## 事务

地址与布局唯一来源为 `contracts/command_gateway.json`、`contracts/instrument_control.json`，生成 SV 包和 C 头。地址为外围 AXI aperture 内偏移，不是 PS 固定物理地址。0x4000 可读到独立标识；0x4400 是 256 个 shadow word，0x4800 是结果窗口。其他地址和未对齐访问返回 SLVERR。

软件必须跨线程、跨 CPU 串行拥有网关。先检查 BUSY，再清 DONE、写 payload/OP_LENGTH/SEQUENCE/CRC，最后写 SUBMIT=1。CRC 覆盖 OP_LENGTH、SEQUENCE 和长度指定的 payload，全部按小端 word。只处理有效长度内的内容。SUBMIT 冻结请求，随后修改 shadow 不影响在途事务。CRC 错误不进入 RF 域。DONE 表示 RF 执行结果已返回，不表示 CDC 请求已接收，也不表示已发射射频。

`sw/common/command_control.c` 提供非阻塞 begin/poll 接口。MMIO 回调负责设备内存顺序和平台屏障，调用者管理轮询预算和超时。SUBMIT 写失败返回 SUBMIT_UNKNOWN，禁止自动重发；先按 sequence 和状态核对。结果读取不清 DONE，容量不足可扩大缓冲后重读；开始新事务前应保存旧结果。所有域协调复位会丢弃在途事务，不能在复位后盲目重试可能有副作用的命令。

## 配置和执行

CONFIG 是 122 word 原子配置。仅在采集未 ARM、RF 未 ARM、生产上下文和消费者已排空、无 FROZEN/PENDING bank 时替换。定义字段之外的配置 padding 必须为零；物理绑定有效性不能通过 payload 声明。ARM 还检查实际接收链的时钟、MTS、映射、过载/阈值质量。STOP 关闭新采集和 RF 请求，已有采集仍按真实 EOP/POST 收尾；RESET 等待实际数据面复位完成后返回。

RX_PROFILE/TX_PROFILE、MODE、DDS、AWG 由实际模块的 accepted/rejected/done 返回结果。RX_PROFILE 沿用回放模块的安全条件：RF 未就绪时返回 REJECTED，需要安全条件满足后装载。RF_REQUEST 仅更新请求，不承诺 RF permit：先 arm=1/request=0 进入 RX，再 request=1；真实反馈、保护/切换/PA 等待和看门狗继续由 RF 联锁执行。MODE=DRFM 后才能满足回放 RF-safe 条件。FD profile version 必须匹配不可变系数 ROM 的版本。

REPLAY 成功仅表示任务入队。后续合法性拒绝从 REJECT_POP 获取；其中 reason 占一个 word，后跟原 48-word 任务。STATUS 返回同一个 RF 时刻的 116 word 快照：GSC、owner epoch、配置 ID、RF/模式状态、16 bank 状态和完整 generation/start/pulse/count，末尾为错误计数。PRODUCER_ERROR_POP 返回上下文键和绑定身份。软件必须保留完整身份，不能用 bank 索引代替所有权。

DDS 9-word payload 依次为 start GSC64、PW32、PRI32、count32、pinc48、chirp48、reset_each bit256，其余最后一个 word 位为零。AWG_LOAD 5 word 为 op32（仅低2位）、length32、CRC32C32、sample64；AWG_PLAY 无 payload。AWG 适配器的控制端在此顶层属于 RF 域，PS 到 RF 的跨域事务已由网关承担。

## 实际 ADC 生产

八路 500MS/s 复数 4SPC 经 HB19/FIR75 D4，形成 125MS/s 四组 H/V。接收 FIR 数据延迟和序号/GSC 使用同样的 15 级寄存器对齐。ADC 不能背压，缺失样点用零保持时轴，同时将受影响 FIR 窗口标为质量无效。映射必须唯一，MTS、时钟、过载已知性和近饱和阈值共同决定质量。

物理 ADC 掩码从实际逻辑到物理映射生成，并与 onset 元数据一起冻结。内部模板的 reserved 低三字节仅在 `PHYSICAL_MASKS_IN_TEMPLATE=1` 时承载三个组的掩码，出帧前由 header builder 清零，线上 ABI5 保持不变。旧归一化数据顶层默认参数为 0，继续使用既有默认通道布局；本数字核心显式打开冻结掩码模式。FIR/来源角色等语义 ID 由 PS 元数据模板提供，软件须与当前配置和实际来源保持一致。

检测器使用实际选定 H/V 组功率，onset 两个 RF 周期内送采集入口。噪声估计仅使用因果、合格、连续静默的前置数据，onset 冻结噪声和配置。四个上下文分别保留 POST 窗口，可重叠；入口拒绝计数而不延迟重试。质量传播采用保守窗口，异常可额外降低边缘样本资格，但不会将受影响样本标为合格。64 位序号/GSC 回绕前必须停机协调复位。

外部 clock/time/MTS、通道映射及 source epoch 应由板级适配器协调更新；更新期间撤销有效性并排空旧上下文。所有 trusted evidence、相位和 RF 反馈输入都必须已同步至 RF 域。时序参数在 ARM 期间稳定。测试中的模拟绑定与反馈只用于仿真，不是生产硬件配置。

## 本阶段不代表的验收

尚未连接真实 PS AXI/DDR/DMA/RFDC IP 板级顶层，也未连接旧 CSR 的完整 PDW 读取通路、AUX 独立生产路径和实物时钟初始化。综合估计不能替代布局布线的 setup/hold、CDC/约束覆盖、IO timing 和上板验收；最终 RF GPIO、极性、实测增益和联锁等待仍保持板级合同绑定。
