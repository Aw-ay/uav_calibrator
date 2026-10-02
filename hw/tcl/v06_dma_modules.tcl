set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Requires Vivado 2025.2"}
foreach top {b_port_reader_128 dma_payload_packer record_formatter_128} {
 set out [file join $root reports v06_modules $top]
 file mkdir $out
 create_project -in_memory -part xczu27dr-fsve1156-2-i
 read_verilog -sv [file join $root rtl/generated/calibrator_contract_pkg.sv]
 read_verilog -sv [file join $root rtl/generated/crc32c_parallel_pkg.sv]
 read_verilog -sv [file join $root rtl/capture $top.sv]
 synth_design -top $top -mode out_of_context -part xczu27dr-fsve1156-2-i
 create_clock -name clk -period 5.000 [get_ports clk]
 if {[llength [get_cells -quiet -hier -filter {IS_BLACKBOX == 1}]]} {error "Unresolved blackboxes"}
 report_utilization -file [file join $out utilization.rpt]
 report_timing_summary -report_unconstrained -file [file join $out timing_synth.rpt]
 check_timing -verbose -file [file join $out check_timing.rpt]
 write_checkpoint -force [file join $out synth.dcp]
 puts "V06_MODULE_COMPLETE $top"
 close_project
}
exit
