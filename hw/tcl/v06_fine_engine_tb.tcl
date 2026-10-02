set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Requires Vivado 2025.2"}
set info [exec python -X utf8 [file join $root tests test_fine_engine.py] --vectors [file join $root build v06_fine_engine_vectors]]
puts $info
if {![regexp {\(([0-9]+),} $info -> jobs]} {error "Missing vector count"}
set f [open [file join $root build v06_fine_engine_vectors samples.hex] r]
set count [llength [split [string trim [read $f]] "\n"]]
close $f
create_project -force v06_fine_engine_tb [file join $root build v06_fine_engine_tb] -part xczu27dr-fsve1156-2-i
foreach f {rtl/generated/calibrator_contract_pkg.sv rtl/generated/fine_edge_program_pkg.sv rtl/capture/b_port_reader_128.sv rtl/fine/fine_wide_math.sv rtl/fine/fine_fast_math.sv rtl/fine/fine_signed_math.sv rtl/fine/fine_cordic.sv rtl/fine/fine_finalize.sv rtl/fine/fine_edge_solver.sv rtl/fine/fine_sample_cache_2.sv rtl/fine/fine_segment_accumulator_2.sv rtl/fine/fine_engine.sv tb/unit/tb_fine_engine.sv} {
 add_files -fileset sim_1 [file join $root $f]
}
set_property top tb_fine_engine [get_filesets sim_1]
set_property xsim.simulate.runtime 0ns [get_filesets sim_1]
set_property -name xsim.simulate.xsim.more_options -value "-testplusarg ROOT=[file join $root build v06_fine_engine_vectors] -testplusarg COUNT=$count -testplusarg JOBS=$jobs" -objects [get_filesets sim_1]
update_compile_order -fileset sim_1
launch_simulation -mode behavioral
run all
close_sim
close_project
exit
