set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Requires Vivado 2025.2"}
set out [file join $root reports pulse_detector_registered_timing]
file mkdir $out
create_project -in_memory -part xczu27dr-fsve1156-2-i
read_verilog -sv [file join $root rtl capture pulse_detector.sv]
read_verilog -sv [file join $root tb timing timing_pulse_detector.sv]
synth_design -top timing_pulse_detector -mode out_of_context -part xczu27dr-fsve1156-2-i
create_clock -name clk_rf -period 8.000 [get_ports timing_clk]
# All DUT inputs and outputs have real launch/capture registers. External
# fixture ports do not model board I/O. No false or multicycle exceptions.
opt_design
place_design
route_design
report_timing_summary -report_unconstrained -file [file join $out timing.rpt]
report_timing -delay_type min_max -max_paths 10 -file [file join $out paths.rpt]
check_timing -verbose -file [file join $out check_timing.rpt]
report_route_status -file [file join $out route_status.rpt]
report_utilization -file [file join $out utilization.rpt]
write_checkpoint -force [file join $out route.dcp]
close_project
puts PULSE_REGISTERED_TIMING_COMPLETE
exit
