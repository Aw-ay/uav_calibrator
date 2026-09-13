set root [file normalize [file join [file dirname [info script]] ../..]]
cd $root
if {[version -short] ne "2025.2"} {error "Requires Vivado2025.2"}
set out [file join $root reports module_stage15]
file mkdir $out
create_project -in_memory -part xczu27dr-fsve1156-2-i
foreach src {
 rtl/source/tx_source_mux.sv rtl/backend/tx_channel_router.sv
 rtl/arithmetic/fixed_round_sat.sv rtl/arithmetic/complex_cal_core.sv rtl/arithmetic/tx_cal_executor.sv
 rtl/frontend/fir_quantize.sv rtl/backend/fir_tx_fir75.sv rtl/backend/fir_tx_hb19.sv
 rtl/backend/fir_tx_lane.sv rtl/backend/dac_stream_adapter.sv rtl/backend/tx_processing_chain.sv
} {read_verilog -sv [file join $root $src]}
synth_design -top tx_processing_chain -mode out_of_context -part xczu27dr-fsve1156-2-i
report_utilization -hierarchical -file [file join $out synthesis_utilization.rpt]
create_clock -name clk_rf -period 8.000 [get_ports clk_rf]
report_timing_summary -report_unconstrained -file [file join $out timing_synth.rpt]
check_timing -verbose -file [file join $out check_timing.rpt]
report_cdc -details -file [file join $out cdc.rpt]
set bb [get_cells -quiet -hier -filter {IS_BLACKBOX == 1}]
if {[llength $bb]} {error "Unresolved blackboxes: $bb"}
write_checkpoint -force [file join $out synth.dcp]
puts STAGE15_MODULE_SYNTH_COMPLETE
close_project
exit
