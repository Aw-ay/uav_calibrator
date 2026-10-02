set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Requires Vivado 2025.2"}
foreach top {fine_wide_math fine_edge_solver} {
 set out [file join $root reports v06_modules $top]
 file mkdir $out
 create_project -in_memory -part xczu27dr-fsve1156-2-i
 read_verilog -sv [file join $root rtl generated fine_edge_program_pkg.sv]
 read_verilog -sv [file join $root rtl fine fine_wide_math.sv]
 if {$top eq "fine_edge_solver"} {read_verilog -sv [file join $root rtl fine fine_edge_solver.sv]}
 synth_design -top $top -mode out_of_context -part xczu27dr-fsve1156-2-i
 create_clock -name clk -period 5.000 [get_ports clk]
 report_utilization -file [file join $out utilization.rpt]
 report_timing_summary -report_unconstrained -file [file join $out timing_synth.rpt]
 check_timing -verbose -file [file join $out check_timing.rpt]
 write_checkpoint -force [file join $out synth.dcp]
 puts V06_${top}_SYNTH_COMPLETE
 close_project
}
exit
