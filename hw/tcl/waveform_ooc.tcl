set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Requires Vivado 2025.2"}
set tops {dds_burst_control dds_nco_wrapper tx_source_mux awg_reader}
if {[llength $argv] > 0} {set tops $argv}
foreach top $tops {
 set out [file join $root reports waveform_ooc $top]
 file mkdir $out
 create_project -in_memory -part xczu27dr-fsve1156-2-i
 read_verilog -sv [file join $root rtl source ${top}.sv]
 synth_design -top $top -mode out_of_context -part xczu27dr-fsve1156-2-i
 create_clock -name clk_rf -period 8.000 [get_ports clk]
 report_utilization -file [file join $out utilization.rpt]
 report_timing_summary -file [file join $out timing.rpt]
 close_project
}
puts WAVEFORM_OOC_SYNTH_COMPLETE
exit
