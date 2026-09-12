set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Requires Vivado 2025.2"}
foreach {top source} {native_overload_monitor rtl/frontend/native_overload_monitor.sv frozen_replay_reader rtl/replay/frozen_replay_reader.sv} {
 set out [file join $root reports ${top}_ooc]
 file mkdir $out
 create_project -in_memory -part xczu27dr-fsve1156-2-i
 read_verilog -sv [file join $root $source]
 synth_design -top $top -mode out_of_context -part xczu27dr-fsve1156-2-i
 create_clock -name clk_rf -period 8.000 [get_ports clk]
 report_utilization -file [file join $out utilization.rpt]
 write_checkpoint -force [file join $out synth.dcp]
 close_project
}
puts NATIVE_REPLAY_OOC_SYNTH_COMPLETE
exit
