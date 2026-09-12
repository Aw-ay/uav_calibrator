set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Requires Vivado 2025.2"}
create_project -in_memory -part xczu27dr-fsve1156-2-i
read_verilog -sv [file join $root rtl frontend fir_quantize.sv]
foreach f {fir_rx_hb19 fir_rx_fir75 fir_rx_lane rfdc_stream_adapter} {read_verilog -sv [file join $root rtl frontend $f.sv]}
foreach f {fir_tx_fir75 fir_tx_hb19 fir_tx_lane dac_stream_adapter} {read_verilog -sv [file join $root rtl backend $f.sv]}
read_verilog -sv [file join $root rtl calibrator_top.sv]
synth_design -mode out_of_context -top calibrator_top -part xczu27dr-fsve1156-2-i
create_clock -name clk_rf -period 8.000 [get_ports clk_rf]
report_utilization -file [file join $root reports digital_core_utilization.rpt]
write_checkpoint -force [file join $root reports digital_core_synth.dcp]
# This entry checks aggregate synthesis/resources. Integrated timing is a
# separate gate; single-lane routed evidence is in fir_ooc_rx / fir_ooc_tx.
close_project
puts DIGITAL_CORE_OOC_SYNTH_COMPLETE
exit
