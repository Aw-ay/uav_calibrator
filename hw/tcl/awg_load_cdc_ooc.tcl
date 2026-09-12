set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Requires Vivado 2025.2"}
set out [file join $root reports awg_load_cdc_ooc]
file mkdir $out
create_project -in_memory -part xczu27dr-fsve1156-2-i
read_verilog -sv [file join $root rtl/source/awg_reader.sv]
read_verilog -sv [file join $root rtl/source/awg_load_cdc_wrapper.sv]
synth_design -top awg_load_cdc_wrapper -mode out_of_context -part xczu27dr-fsve1156-2-i
create_clock -name clk_rf -period 8.000 [get_ports clk_rf]
create_clock -name clk_ctrl -period 10.000 [get_ports clk_ctrl]
report_utilization -file [file join $out utilization.rpt]
report_cdc -details -file [file join $out cdc.rpt]
puts AWG_LOAD_CDC_OOC_SYNTH_COMPLETE
exit
