set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Requires Vivado 2025.2"}
set out [file join $root reports v06_modules fine_transport]
file mkdir $out
create_project -in_memory -part xczu27dr-fsve1156-2-i
read_verilog -sv [file join $root rtl control cdc_mailbox.sv]
read_verilog -sv [file join $root rtl fine fine_result_transport.sv]
synth_design -top fine_result_transport -mode out_of_context -part xczu27dr-fsve1156-2-i
create_clock -name clk_rf -period 8.000 [get_ports clk_rf]
create_clock -name clk_mem -period 5.000 [get_ports clk_mem]
report_utilization -file [file join $out utilization.rpt]
report_timing_summary -report_unconstrained -file [file join $out timing_synth.rpt]
report_timing -max_paths 20 -file [file join $out setup_paths.rpt]
report_cdc -details -file [file join $out cdc.rpt]
puts V06_FINE_TRANSPORT_SYNTH_COMPLETE
exit
