# Standalone module synthesis only; does not open or rebuild the instrument core.
set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Requires Vivado 2025.2"}
set out [file join $root reports module_stage18]
file mkdir $out
create_project -in_memory -part xczu27dr-fsve1156-2-i
foreach source {rtl/replay/replay_drain_observer.sv} {read_verilog -sv [file join $root $source]}
synth_design -top replay_drain_observer -mode out_of_context -part xczu27dr-fsve1156-2-i
create_clock -name clk_rf -period 8.000 [get_ports clk]
set bb [get_cells -quiet -hier -filter {IS_BLACKBOX == 1}]
if {[llength $bb]} {error "Unresolved blackboxes: $bb"}
report_utilization -file [file join $out utilization.rpt]
report_timing_summary -report_unconstrained -file [file join $out timing_synth.rpt]
check_timing -verbose -file [file join $out check_timing.rpt]
report_cdc -details -file [file join $out cdc.rpt]
write_checkpoint -force [file join $out synth.dcp]
puts STAGE18_MODULE_SYNTH_COMPLETE
close_project
exit
