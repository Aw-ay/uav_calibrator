# Standalone module synthesis only; does not open or rebuild the instrument core.
set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Requires Vivado 2025.2"}
set out [file join $root reports module_stage11]
file mkdir $out
create_project -in_memory -part xczu27dr-fsve1156-2-i
foreach source {rtl/generated/fault_event_pkg.sv rtl/control/fault_event_encoder.sv rtl/control/fault_event_retainer.sv rtl/control/event_priority_arbiter.sv rtl/control/cdc_mailbox.sv rtl/control/event_mailbox.sv rtl/control/fault_event_transport.sv} {
 read_verilog -sv [file join $root $source]
}
synth_design -top fault_event_transport -mode out_of_context -part xczu27dr-fsve1156-2-i
create_clock -name clk_rf -period 8.000 [get_ports rf_clk]
create_clock -name clk_ctrl -period 10.000 [get_ports ctrl_clk]
set bb [get_cells -quiet -hier -filter {IS_BLACKBOX == 1}]
if {[llength $bb]} {error "Unresolved blackboxes: $bb"}
report_utilization -file [file join $out utilization.rpt]
report_timing_summary -report_unconstrained -file [file join $out timing_synth.rpt]
check_timing -verbose -file [file join $out check_timing.rpt]
report_cdc -details -file [file join $out cdc.rpt]
write_checkpoint -force [file join $out synth.dcp]
puts STAGE11_MODULE_SYNTH_COMPLETE
close_project
exit
