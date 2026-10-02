set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Requires Vivado 2025.2"}
create_project -force v06_online_statistics_tb [file join $root build v06_online_statistics_tb] -part xczu27dr-fsve1156-2-i
add_files -fileset sim_1 [file join $root rtl capture online_body_statistics.sv]
add_files -fileset sim_1 [file join $root tb unit tb_online_body_statistics_errors.sv]
set_property top tb_online_body_statistics_errors [get_filesets sim_1]
set_property xsim.simulate.runtime 0ns [get_filesets sim_1]
update_compile_order -fileset sim_1
launch_simulation -mode behavioral
run all
close_sim
close_project
exit
