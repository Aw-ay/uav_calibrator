set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Requires Vivado 2025.2"}
foreach {top source} {channel_epoch_aligner rtl/frontend/channel_epoch_aligner.sv tx_reference_analyzer rtl/monitor/tx_reference_analyzer.sv} {
 set out [file join $root reports channel_monitor_ooc $top]
 file mkdir $out
 create_project -in_memory -part xczu27dr-fsve1156-2-i
 read_verilog -sv [file join $root $source]
 synth_design -top $top -mode out_of_context -part xczu27dr-fsve1156-2-i
 create_clock -name clk_rf -period 8.000 [get_ports clk]
 report_utilization -file [file join $out utilization.rpt]
 report_timing_summary -file [file join $out timing.rpt]
 close_project
}
puts CHANNEL_MONITOR_OOC_SYNTH_COMPLETE
exit
