set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Requires Vivado 2025.2"}
set out [file join $root reports v06_modules fine_cordic]
file mkdir $out
create_project -in_memory -part xczu27dr-fsve1156-2-i
read_verilog -sv [file join $root rtl/fine/fine_cordic.sv]
synth_design -top fine_cordic -mode out_of_context -part xczu27dr-fsve1156-2-i
create_clock -name clk -period 5.000 [get_ports clk]
report_utilization -file [file join $out utilization.rpt]
report_timing_summary -report_unconstrained -file [file join $out timing_synth.rpt]
check_timing -verbose -file [file join $out check_timing.rpt]
write_checkpoint -force [file join $out synth.dcp]
puts V06_FINE_CORDIC_SYNTH_COMPLETE
close_project
exit
