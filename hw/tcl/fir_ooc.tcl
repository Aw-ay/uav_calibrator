set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Requires Vivado 2025.2"}
if {[llength $argv] != 1} {error "Expected RX or TX"}
set direction [string tolower [lindex $argv 0]]
if {$direction ni {rx tx}} {error "Expected RX or TX"}
set out [file join $root reports fir_ooc_$direction]
file mkdir $out
create_project -in_memory -part xczu27dr-fsve1156-2-i
read_verilog -sv [file join $root rtl frontend fir_quantize.sv]
if {$direction eq "rx"} {
  foreach f {fir_rx_hb19 fir_rx_fir75 fir_rx_lane} {read_verilog -sv [file join $root rtl frontend $f.sv]}
} else {
  foreach f {fir_tx_fir75 fir_tx_hb19 fir_tx_lane} {read_verilog -sv [file join $root rtl backend $f.sv]}
}
synth_design -mode out_of_context -top fir_${direction}_lane -part xczu27dr-fsve1156-2-i
create_clock -period 8.000 -name clk_rf [get_ports clk]
report_utilization -file [file join $out utilization_synth.rpt]
report_timing_summary -file [file join $out timing_synth.rpt]
write_checkpoint -force [file join $out synth.dcp]
opt_design
place_design
route_design
report_utilization -file [file join $out utilization_route.rpt]
report_timing_summary -file [file join $out timing_route.rpt]
report_drc -file [file join $out drc.rpt]
write_checkpoint -force [file join $out route.dcp]
puts "FIR_OOC_DONE $direction VERSION=[version -short]"
exit
