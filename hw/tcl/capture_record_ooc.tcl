set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Requires Vivado 2025.2"}
set out [file join $root reports capture_record_ooc]
file mkdir $out
create_project -in_memory -part xczu27dr-fsve1156-2-i
read_ip [file join $root build ip_probe_2025_2 calibrator_ip_probe.srcs sources_1 ip capture_ram_probe capture_ram_probe.xci]
foreach f {rtl/generated/calibrator_contract_pkg.sv rtl/generated/crc32c_parallel_pkg.sv rtl/control/cdc_mailbox.sv rtl/capture/capture_bank_manager.sv rtl/capture/capture_ram.sv rtl/capture/capture_bank_array.sv rtl/capture/b_port_reader_128.sv rtl/capture/dma_payload_packer.sv rtl/capture/record_formatter_128.sv rtl/capture/record_dma_bridge.sv rtl/data/axis_record_fifo.sv rtl/data/record_descriptor_arbiter.sv rtl/data/record_upload_path.sv rtl/data/record_upload_groups.sv rtl/capture/capture_record_system.sv} {
 read_verilog -sv [file join $root $f]
}
# Exercise reachable capture logic. Production default remains fail-closed zero;
# this one-cycle detector budget is an explicit OOC configuration, not calibration.
synth_design -top capture_record_system -generic DETECTOR_LATENCY=1 -mode out_of_context -part xczu27dr-fsve1156-2-i
create_clock -name clk_rf -period 8.000 [get_ports clk_rf]
create_clock -name clk_mem -period 5.000 [get_ports clk_mem]
set ram_dcp [file join $root build ip_probe_2025_2 calibrator_ip_probe.runs capture_ram_probe_synth_1 capture_ram_probe.dcp]
set unresolved [get_cells -hier -filter {IS_BLACKBOX == 1 && REF_NAME == capture_ram_probe}]
foreach cell $unresolved {read_checkpoint -cell $cell $ram_dcp}
set unresolved [get_cells -hier -filter {IS_BLACKBOX == 1}]
if {[llength $unresolved]} {error "Unresolved cells: $unresolved"}
report_utilization -file [file join $out utilization.rpt]
report_cdc -details -file [file join $out cdc.rpt]
set evidence [open [file join $out configuration.txt] w]
puts $evidence "Vivado=[version -short] DETECTOR_LATENCY=1 PRE_SAMPLES=250 RAM_DEPTH=16384 FIFO_DEPTH=4096"
puts $evidence "BLACKBOX_COUNT=[llength $unresolved]"
close $evidence
write_checkpoint -force [file join $out synth.dcp]
close_project
puts CAPTURE_RECORD_OOC_SYNTH_COMPLETE
exit
