set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Requires Vivado 2025.2"}
exec python -X utf8 [file join $root tests test_fine_edge_solver.py] --vectors [file join $root build v06_fine_edge_vectors]
create_project -force v06_fine_edge_tb [file join $root build v06_fine_edge_tb] -part xczu27dr-fsve1156-2-i
foreach f {rtl/generated/fine_edge_program_pkg.sv rtl/fine/fine_wide_math.sv rtl/fine/fine_edge_solver.sv tb/unit/tb_fine_edge_solver.sv} {
 add_files -fileset sim_1 [file join $root $f]
}
set_property top tb_fine_edge_solver [get_filesets sim_1]
set_property xsim.simulate.runtime 0ns [get_filesets sim_1]
set_property -name xsim.simulate.xsim.more_options -value "-testplusarg ROOT=[file join $root build v06_fine_edge_vectors] -testplusarg COUNT=320" -objects [get_filesets sim_1]
update_compile_order -fileset sim_1
launch_simulation -mode behavioral
run all
close_sim
close_project
exit
