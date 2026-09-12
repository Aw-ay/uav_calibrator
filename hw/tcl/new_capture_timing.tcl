# Interface timing diagnostic at 125 MHz. All non-clock ports use a
# same-clock zero external delay budget, applied BEFORE place/route.
# Combinational blocks use a virtual clock; no fake internal clock port.
# This does not replace actual producer/consumer-register integration.
set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Requires Vivado 2025.2"}
foreach top {pulse_range_statistics noise_snapshot noise_window_energy range_qualification} {
 set out [file join $root reports new_capture_timing $top]
 file mkdir $out
 create_project -in_memory -part xczu27dr-fsve1156-2-i
 if {$top eq "range_qualification"} {read_verilog -sv [file join $root rtl capture capture_range_select.sv]}
 read_verilog -sv [file join $root rtl capture $top.sv]
 synth_design -top $top -mode out_of_context -part xczu27dr-fsve1156-2-i
 if {[llength [get_ports -quiet clk]]} {
  create_clock -name clk_rf -period 8.000 [get_ports clk]
 } else {create_clock -name clk_rf -period 8.000}
 set_input_delay -clock clk_rf -max 0.000 [get_ports -filter {DIRECTION == IN && NAME != clk}]
 set_input_delay -clock clk_rf -min 0.000 [get_ports -filter {DIRECTION == IN && NAME != clk}]
 set_output_delay -clock clk_rf -max 0.000 [get_ports -filter {DIRECTION == OUT}]
 set_output_delay -clock clk_rf -min 0.000 [get_ports -filter {DIRECTION == OUT}]
 opt_design
 place_design
 route_design
 report_timing_summary -report_unconstrained -file [file join $out timing.rpt]
 report_timing -delay_type min_max -max_paths 10 -file [file join $out paths.rpt]
 check_timing -verbose -file [file join $out check_timing.rpt]
 report_route_status -file [file join $out route_status.rpt]
 report_drc -file [file join $out drc.rpt]
 report_utilization -file [file join $out utilization.rpt]
 write_checkpoint -force [file join $out route.dcp]
 puts "CAPTURE_TIMING_DIAGNOSTIC_COMPLETE $top"
 close_project
}
exit
