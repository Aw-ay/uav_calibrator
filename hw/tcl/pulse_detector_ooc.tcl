set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Requires Vivado 2025.2"}
set out [file join $root reports pulse_detector_ooc]
file mkdir $out
create_project -in_memory -part xczu27dr-fsve1156-2-i
read_verilog -sv [file join $root rtl capture pulse_detector.sv]
synth_design -top pulse_detector -mode out_of_context -part xczu27dr-fsve1156-2-i
create_clock -name clk_rf -period 8.000 [get_ports clk]
opt_design
place_design
route_design
report_utilization -file [file join $out utilization.rpt]
report_timing_summary -file [file join $out timing.rpt]
write_checkpoint -force [file join $out route.dcp]
close_project
puts PULSE_DETECTOR_OOC_COMPLETE
exit
