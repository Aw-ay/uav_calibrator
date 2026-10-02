set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Requires Vivado 2025.2"}
create_project -force v06_replay_no_fd_tb [file join $root build v06_replay_no_fd_tb] -part xczu27dr-fsve1156-2-i
foreach f {rtl/arithmetic/fixed_round_sat.sv rtl/arithmetic/complex_cal_core.sv rtl/arithmetic/rx_cal_executor.sv rtl/arithmetic/target_complex_operator.sv rtl/replay/replay_processing_chain.sv tb/system/tb_replay_processing_chain.sv} {add_files -fileset sim_1 [file join $root $f]}
set_property top tb_replay_processing_chain [get_filesets sim_1]
set_property xsim.simulate.runtime 0ns [get_filesets sim_1]
update_compile_order -fileset sim_1
launch_simulation -mode behavioral
run all
close_sim
close_project
exit
