set root [file normalize [file join [file dirname [info script]] ../..]]
cd $root
if {[version -short] ne "2025.2"} {error "Requires Vivado2025.2"}
set out [file join $root reports tx_chain_registered_timing]
file mkdir $out
create_project -in_memory -part xczu27dr-fsve1156-2-i
foreach src {
 rtl/source/tx_source_mux.sv rtl/backend/tx_channel_router.sv
 rtl/arithmetic/fixed_round_sat.sv rtl/arithmetic/complex_cal_core.sv rtl/arithmetic/tx_cal_executor.sv
 rtl/frontend/fir_quantize.sv rtl/backend/fir_tx_fir75.sv rtl/backend/fir_tx_hb19.sv
 rtl/backend/fir_tx_lane.sv rtl/backend/dac_stream_adapter.sv rtl/backend/tx_processing_chain.sv
 tb/timing/timing_tx_processing_chain.sv
} {read_verilog -sv [file join $root $src]}
synth_design -top timing_tx_processing_chain -mode out_of_context -part xczu27dr-fsve1156-2-i
report_utilization -hierarchical -file [file join $out synthesis_utilization.rpt]
create_clock -name clk_rf -period 8.000 [get_ports timing_clk]
# Actual launch/capture registers preserve all8lanes and control/data paths.
# No false paths or multicycle exceptions. Fixture external ports have no boardIO delays.
opt_design
place_design
route_design
report_timing_summary -report_unconstrained -file [file join $out timing.rpt]
report_timing -delay_type min_max -max_paths 20 -file [file join $out paths.rpt]
check_timing -verbose -file [file join $out check_timing.rpt]
report_route_status -file [file join $out route_status.rpt]
report_drc -file [file join $out drc.rpt]
report_utilization -hierarchical -file [file join $out hierarchy.rpt]
report_utilization -file [file join $out utilization.rpt]
write_checkpoint -force [file join $out route.dcp]
puts "TX_CHAIN_REGISTERED_TIMING_COMPLETE"
exit
