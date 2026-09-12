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


## 第四阶段：DDS/AWG 软件提交与换表边界

`sw/common/include/waveform_control.h` 提供 `cal_dds_begin`、
`cal_awg_load_begin`、`cal_awg_write`、`cal_awg_commit`、`cal_awg_play`。
每次只提交一条命令；随后使用相同 sequence 调用 `cal_command_poll`，同时检查
传输状态与 `result.code`。提交成功不表示已开始输出或实际 RF 发射。
`SUBMIT_UNKNOWN` 必须查询原 sequence，禁止自动重发。

DDS 的 PW/PRI/count 以 125 MHz 样点计，GSC 以 2 ns tick 计且需 4 tick 对齐。
C API 检查非零长度、PRI>=PW、48 bit 相位字段及完整脉冲列的 GSC 溢出。
调用者须给 MMIO/CDC 留足提前量，PL 最终判断时间是否仍在未来。

AWG 流程为 BEGIN(length, CRC) → 逐样点 WRITE → COMMIT → MODE=4 → PLAY。
每个 64 bit 样点从低到高为 HI/HQ/VI/VQ，各 16 bit；CRC32C 按小端字节顺序，
初值及最终 XOR 为 0xffffffff。长度上限由实际 AWG_DEPTH 决定并由 PL 检查。
CRC 错误返回 REJECTED，当前活动表保持不变。

已加载表的 COMMIT 仅在采集停止、MUTE、回放及生成源排空、检测器不活动时下发。
否则立即返回 BUSY，保留待提交表，避免单事务网关等待后续 STOP 造成死锁。
软件应先 STOP 并等待完成，确认排空后用新 sequence 重试 COMMIT。
没有合格待提交表时由 AWG 核返回 REJECTED；BEGIN/WRITE 仍可在活动表播放时
写入独立的非活动 bank。AWG_LOAD 返回低四位为活动表有效、已加载、最近完成操作号；
被网关拒绝的操作未到 AWG 核，因此最近完成操作号不代表本次操作。

正常主动关闭 PA 时不把预期的 PA 反馈下降当故障；TX 请求仍有效时的 PA 丢失、
TR 与接收保护反馈异常仍受联锁检查。此逻辑不规定物理引脚、极性或板级等待参数。


## 第五阶段：最终资格 PDW 队列

现有 `CAPTURE_PDW` 64 字节 ABI 通过两条新增命令读取：

| 命令 | opcode | 请求 | 结果 |
|---|---:|---|---|
| PDW_PEEK | 16 | 无 | 20 word：队列数量、累计丢弃数、64 bit 队首令牌、64 byte PDW |
| PDW_POP | 17 | 64 bit 队首令牌，低 word 在前 | 精确匹配且非空才返回 OK，否则 REJECTED |

队列深度 16，全部位于 RF 域，PS 跨域快照由现有命令网关完成。PEEK 不删除记录；
重复读取返回同一队首及令牌，后台新记录不修改该队首。POP 的令牌与命令的 sequence
属于不同身份，不能互换。空队列的令牌和 PDW 全零，但累计丢弃数保留。

只有通过最终资格、实际被 RAW 描述符入口接收的 selected H/V 窗口才产生 PDW。
复用扫描器真实峰值和能量，并按完整 context key 在资格映射中冻结；没有新增 bank
读端口。队列满时丢弃新 PDW 并饱和累计 dropped，不阻塞 RAW、不释放任何 bank 引用。
令牌从 1 递增且不会回绕，耗尽后丢弃新事件直到协调硬复位。

ToA 为真实 GSC_FIRST + PRE×4；脉宽为 (sample_count−PRE−POST)×4，单位均为
500 MHz GSC tick。PRE 由 bank owner 确定；CONFIG 在生产端/待判定/冻结 bank 存在时
不能更新，因此生成 PDW 的边界上 POST 和 config_id 保持对应脉冲的值。队列入队前
数据已冻结，后续配置或软复位不会改变历史记录。峰值为所选 H/V 窗口功率的较大值，
能量为该对 H/V 的 PRE/body/POST 完整窗口能量和；它们不是减噪或物理增益校正结果。
算术溢出、身份或统计不一致不设置对应有效位。

捕获软 RESET 保留队列和历史 owner_epoch；协调硬复位清空队列、令牌及计数。
未通过资格或生产端入口拒绝的记录继续走既有错误/丢弃通路，不伪造成功 PDW。
PDW 不表示 DMA 字节已到 DDR，也不表示实际 RF 发射完成。

C 接口 `pdw_control.h/.c` 提供 PEEK/POP 提交和结构化快照解码，复用现有
`cal_event_decode` 检查 ABI/保留字/有效位。单一软件所有者完成 begin → poll → decode
→ 处理事件 → POP → poll；提交不确定时按原 sequence 查询，禁止自动重发。
这些 API 已加入 A53 静态库，仍需板级 BSP 提供有序 MMIO 实现。
