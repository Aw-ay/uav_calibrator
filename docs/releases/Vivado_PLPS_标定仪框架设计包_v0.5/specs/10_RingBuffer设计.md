# 10 RingBuffer设计：同功能bank轮换

## 1. 先明确四个bank没有固定分工

以一组MID H/V说明。Bank0/1/2/3都是相同的128KiB独立存储区：都能预填、捕获、冻结、A口回放、B口上传、释放。数据不从Bank2复制给Bank0/1/3；流转的是状态和所有权。

| 观察时刻 | Bank0 | Bank1 | Bank2 | Bank3 |
|---|---|---|---|---|
| 所有bank已准备 | 滚动历史 | 滚动历史 | 滚动历史 | 滚动历史 |
| P0到来 | 捕获P0 | 滚动历史 | 滚动历史 | 滚动历史 |
| P0结束 | 冻结P0 | 滚动历史 | 滚动历史 | 滚动历史 |
| P1到来 | P0等回放 | 捕获P1 | 滚动历史 | 滚动历史 |
| P2到来且旧任务未释放 | P0等回放 | P1上传 | 捕获P2 | 滚动历史 |

最后一行仅为状态快照，不是四个固定岗位。此时Bank2与Bank3都写同一组实时IQ；Bank2已经保护P2起点，Bank3可以覆盖旧历史。Bank2窗口结束也停写冻结。Bank0/1是此前已经捕获的旧脉冲，不是现在重新捕获或由Bank2转存。

## 2. 预填/触发/冻结

将同一64bit输入广播到所有ARMING/ARMED及当前CAPTURE bank的写端，独立WE控制。FREE释放后重新预填。ARMING条件为pre250 + measured_detector_delay +1个连续历史，模型32点例子需要283点。触发携带onset_seq，不能使用判决到达时的write_ptr当真正起点。

例：起点100us、PW120us、pre/post各2us，记录[98us,222us)，15500点。98..100us已在被选bank中；触发仅绑定pulse/start/generation。写到222us窗口终点后停写、FROZEN_PENDING，统计完成/选档后发布。其它可用bank继续维护历史，不会为同一触发都生成一条记录。

记录只保存最近131.072us以内的窗口，不是从开机起的全信号。窗口冻结可以跨16383→0，由reader解环，不需要移动到地址0。

## 3. 状态和窗口

`FREE→ARMING→ARMED→CAPTURE→FROZEN_PENDING→FROZEN→RELEASE→ARMING`。每bank有绝对sample_seq、start_seq/start_ptr、stop_seq/sample_count、history_count、epoch、generation。地址14bit，count15bit才能表示16384。窗口左闭右开，满长start=end_ptr也不为空。

CAPTURE写前保护seq<start_seq+16384；不能因等迟到EOP而覆盖起点。超长先冻结已保存段，TRUNCATED/INVALID标记，不批准精密回放。最终记录能放入不等于判决等待期间不会覆盖，两者分别测试。

## 4. 主三档与AUX

主触发要求三档各有fresh ARMED bank再原子提交，同pulse和时间窗，bank编号可不同。一组失败默认三组均不占用，降级是另一个明确模式。全部捕获并完成资格后共同选一档；正常只发布选中H/V，未选且无诊断/回放引用的bank立即重新预填。AUX独立资源/来源/触发，不借用MIDbank，loopback不参与外测选档。

## 5. 冻结双读与归还

A64bit@125MHz本地回放，B128bit@200MHz记录上传，可以同时读同一冻结bank，无需两份波形。发布descriptor前先pin对应引用，队列满则保持冻结或显式取消。token含owner_epoch、group、bank、generation、consumer。拒绝迟到/重复ACK；同拍两个ACK合并计算。一个消费者完成不能释放另一消费者的数据。

RAW最后读出安全移交后可按策略归还；TX尾/coeff任务/BD完成/host确认具有不同寿命。要求错误重传者必须延长RAW保留，不默认存在副本。多次重放用任务集合/计数，参考模型仅一个replay消费者。soft reset先quiesce读者并处理在途事务，再换epoch/rearm；仅清状态不能停止旧reader。

## 6. 读出边界

A每拍一个H/V样点直接按start+n模深度读。B自然128bit包含偶奇两点，奇数起点必须carry拼接；跨环同理。RAM已发请求可能在背压后继续返回，reader要维护在途信用而非只停地址。仲裁锁定整条record直至最后一次握手。

IQ payload_end不是记录TLAST。带CRC且N奇数时最后8IQ+8CRC拼一拍，余8CRC为最后拍。TREADY低时数据/keep/last稳定。CRC/头在formatter中生成，不存入RAW bank。

## 7. 容量与资源

4组×4bank×16384×8=2MiB。窗口120/124/126us分别15000/15500/15750点；200us拒绝。bank数由最大保持时间（包括重放等待、上传、重新预填）与PRI估算，不是固定四个功能需要四块。两个bank在约束充分时可以评估，四bank给缓冲余量，但不承诺任意5ms等待。全部忙时丢新记录并计数，ADC/FIR不停止。

BRAM拼接预算512 RAMB36，仅RAW；quality、AWG、FIFO另算。把一个大RAM按地址分16段不会自动得到16套独立端口。URAM不能直接代替A125/B200双时钟结构。

## 8. 行为模型边界

本三目录框架包不附行为模型源码。实施时建立索引、状态和所有权参考模型：冻结bank不得再写；准备bank继续广播预填；旧消费者归还后重新arm；旧代次和重复ACK不得释放新记录。软件时间tags可用于scoreboard，不要求每IQ存64bit标签；软件quality数组不证明RTL旁存储存在。即使参考测试通过，仍须BMG/RTL/CDC硬件验证。
