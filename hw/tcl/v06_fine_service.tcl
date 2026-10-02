set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Requires Vivado 2025.2"}
set out [file join $root reports v06_modules fine_service]
file mkdir $out
create_project -in_memory -part xczu27dr-fsve1156-2-i
read_verilog -sv [file join $root rtl generated calibrator_contract_pkg.sv]
read_verilog -sv [file join $root rtl generated fine_edge_program_pkg.sv]
read_verilog -sv [file join $root rtl capture b_port_reader_128.sv]
read_verilog -sv [file join $root rtl control cdc_mailbox.sv]
foreach f [glob [file join $root rtl fine *.sv]] {read_verilog -sv $f}
synth_design -top fine_bank_service -mode out_of_context -part xczu27dr-fsve1156-2-i
create_clock -name clk_mem -period 5.000 [get_ports clk_mem]
create_clock -name clk_rf -period 8.000 [get_ports clk_rf]
report_utilization -file [file join $out utilization.rpt]
report_timing_summary -report_unconstrained -file [file join $out timing_synth.rpt]
check_timing -verbose -file [file join $out check_timing.rpt]
report_cdc -details -file [file join $out cdc.rpt]
puts V06_FINE_SERVICE_SYNTH_COMPLETE
exit
