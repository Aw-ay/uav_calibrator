set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Requires Vivado 2025.2"}
set out [file join $root reports range_statistics_ooc]
file mkdir $out
read_verilog -sv [file join $root rtl capture pulse_range_statistics.sv]
synth_design -top pulse_range_statistics -part xczu27dr-fsve1156-2-i -mode out_of_context
create_clock -name clk_rf -period 8.0 [get_ports clk]
write_checkpoint -force [file join $out synth.dcp]
report_utilization -file [file join $out utilization.rpt]
puts RANGE_STATISTICS_SYNTH_OK
exit
