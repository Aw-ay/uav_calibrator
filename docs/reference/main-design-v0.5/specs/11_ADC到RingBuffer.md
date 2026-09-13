# 11 ADC → RingBuffer

1. 八独立物理ADC的RFDC内部DDC后各500MS/s复数。适配成4SPC@125MHz，每lane为同一信号连续样点，原生word/Tile映射不能猜。
2. channel_epoch_aligner核对序号/时间，native_overload_monitor覆盖4lane并结合RFDC硬过载。这里的native是在PL抽取前，不是4GS/s ADC全原码。粘滞硬标志不按高电平拍数当削顶计数；需要清除/事件归属账本。[A03]
3. HB19 D2后2SPC，再FIR75 D2后1SPC，全部clk_rf125MHz。内部位宽24候选，最终舍入饱和到I16/Q16。滤波不断流、不每脉冲reset。
4. 滤后IQ并行送检测、资格、四组bank。检测器产生真onset/end样点标记而非串联开关；主三档同一触发上下文。预触发在ARMED bank已有，不瞬时复制。
5. 窗口末IQ写完先停写，资格流水排完再选档。质量无效时仍保持样点时间序号；无效不能靠删除样点拼接。无可用bank丢新记录不反压ADC。

每H/V组1GB/s写入，四组总4GB/s；DMA在后面的冻结读取阶段按200MHz串行服务，与这个峰值不是一条总线。RAW载荷为PL_FILTERED_RAW而非ADC全速原码；QMC等硬核设置也要记入校准和scale版本。

时间以GSC2ns单位记账，每core拍4tick。FIR群延迟166ns只是一项，不代替RFDC/IPpipeline和检测判决延迟。AUX源切换只使AUX来源代次变化；共享MTS故障才使全域time epoch失效。
