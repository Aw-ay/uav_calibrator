set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Requires Vivado 2025.2"}
create_project -force v06_bmg_latency [file join $root build v06_bmg_latency] -part xczu27dr-fsve1156-2-i
read_ip [file join $root build ip_probe_2025_2 calibrator_ip_probe.srcs sources_1 ip capture_ram_probe capture_ram_probe.xci]
add_files -fileset sim_1 [file join $root tb unit tb_v06_bmg_latency.sv]
set_property top tb_v06_bmg_latency [get_filesets sim_1]
set_property xsim.simulate.runtime 0ns [get_filesets sim_1]
update_compile_order -fileset sim_1
launch_simulation -mode behavioral
run all
close_sim
close_project
exit
