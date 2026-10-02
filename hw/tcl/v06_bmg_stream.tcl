set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Requires Vivado 2025.2"}
exec python [file join $root tools generate_v06_bmg_vectors.py]
create_project -force v06_bmg_stream [file join $root build v06_bmg_stream] -part xczu27dr-fsve1156-2-i
read_ip [file join $root build ip_probe_2025_2 calibrator_ip_probe.srcs sources_1 ip capture_ram_probe capture_ram_probe.xci]
foreach f {rtl/generated/calibrator_contract_pkg.sv rtl/generated/crc32c_parallel_pkg.sv rtl/capture/b_port_reader_128.sv rtl/capture/dma_payload_packer.sv rtl/capture/record_formatter_128.sv tb/system/tb_v06_bmg_stream.sv} {
 add_files -fileset sim_1 [file join $root $f]
}
set_property top tb_v06_bmg_stream [get_filesets sim_1]
set_property xsim.simulate.runtime 0ns [get_filesets sim_1]
set_property -name xsim.simulate.xsim.more_options -value "-testplusarg ROOT=[file join $root reports v06_bmg_stream_vectors] -testplusarg START=16383 -testplusarg COUNT=16384 -testplusarg BYTES=131216 -testplusarg ALWAYS_READY=1" -objects [get_filesets sim_1]
update_compile_order -fileset sim_1
launch_simulation -mode behavioral
run all
close_sim
close_project
exit
