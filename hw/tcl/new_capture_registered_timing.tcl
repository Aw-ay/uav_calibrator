set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Requires Vivado 2025.2"}
foreach top {pulse_range_statistics noise_snapshot noise_window_energy range_qualification} {
 set out [file join $root reports new_capture_registered_timing $top]
 file mkdir $out
 create_project -in_memory -part xczu27dr-fsve1156-2-i
 if {$top eq "range_qualification"} {read_verilog -sv [file join $root rtl capture capture_range_select.sv]}
 read_verilog -sv [file join $root rtl capture $top.sv]
 read_verilog -sv [file join $root tb timing timing_$top.sv]
 synth_design -top timing_$top -mode out_of_context -part xczu27dr-fsve1156-2-i
 create_clock -name clk_rf -period 8.000 [get_ports timing_clk]
 # Fixture external ports intentionally excluded. Every DUT input is launched
 # by a real clocked register and every output captured by a real register.
 # No false paths, multicycle paths or reduced clock frequency.
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
 puts "REGISTERED_TIMING_COMPLETE $top"
 close_project
}
exit
