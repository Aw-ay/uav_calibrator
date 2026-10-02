set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Requires Vivado 2025.2"}
set out [file join $root reports record_upload_ooc]
file mkdir $out
create_project -in_memory -part xczu27dr-fsve1156-2-i
foreach f {rtl/generated/calibrator_contract_pkg.sv rtl/generated/crc32c_parallel_pkg.sv rtl/control/cdc_mailbox.sv rtl/capture/b_port_reader_128.sv rtl/capture/dma_payload_packer.sv rtl/capture/record_formatter_128.sv rtl/capture/record_dma_bridge.sv rtl/data/axis_record_fifo.sv rtl/data/record_descriptor_arbiter.sv rtl/data/record_upload_path.sv rtl/data/record_upload_groups.sv} {
 read_verilog -sv [file join $root $f]
}
synth_design -top record_upload_groups -mode out_of_context -part xczu27dr-fsve1156-2-i
create_clock -name clk_rf -period 8.000 [get_ports clk_rf]
create_clock -name clk_mem -period 5.000 [get_ports clk_mem]
# Resource and CDC diagnostic only. No timing exceptions or CDC waivers are
# inferred here; bundled-data physical constraints need the integrated endpoints.
report_utilization -file [file join $out utilization.rpt]
report_cdc -details -file [file join $out cdc.rpt]
write_checkpoint -force [file join $out synth.dcp]
close_project
puts RECORD_UPLOAD_OOC_SYNTH_COMPLETE
exit
