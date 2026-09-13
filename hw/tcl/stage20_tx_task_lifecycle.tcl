# Standalone module synthesis only; does not open or rebuild the instrument core.
set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Requires Vivado 2025.2"}
set out [file join $root reports module_stage20]
file mkdir $out
create_project -in_memory -part xczu27dr-fsve1156-2-i
foreach source {rtl/replay/replay_control_layout_pkg.sv rtl/generated/replay_identity_event_pkg.sv rtl/generated/tx_lifecycle_event_pkg.sv rtl/replay/replay_identity_event.sv rtl/replay/replay_drain_observer.sv rtl/control/tx_lifecycle_tracker.sv rtl/control/event_priority_arbiter.sv rtl/control/tx_task_lifecycle.sv} {read_verilog -sv [file join $root $source]}
synth_design -top tx_task_lifecycle -mode out_of_context -part xczu27dr-fsve1156-2-i
create_clock -name clk_rf -period 8.000 [get_ports clk]
set bb [get_cells -quiet -hier -filter {IS_BLACKBOX == 1}]
if {[llength $bb]} {error "Unresolved blackboxes: $bb"}
report_utilization -file [file join $out utilization.rpt]
report_timing_summary -report_unconstrained -file [file join $out timing_synth.rpt]
check_timing -verbose -file [file join $out check_timing.rpt]
report_cdc -details -file [file join $out cdc.rpt]
write_checkpoint -force [file join $out synth.dcp]
puts STAGE20_MODULE_SYNTH_COMPLETE
close_project
exit
