set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Requires Vivado 2025.2"}
if {[llength $argv] != 1} {error "Expected testbench top"}
set top [lindex $argv 0]
if {$top ni {tb_native_adapters tb_capture_bmg}} {error "Unsupported testbench"}
open_project [file join $root build calibrator_zu27dr calibrator_zu27dr.xpr]
set source [file join $root tb unit $top.sv]
if {![llength [get_files -quiet $source]]} {add_files -fileset sim_1 -norecurse $source}
set_property top $top [get_filesets sim_1]
set_property xsim.simulate.runtime 0ns [get_filesets sim_1]
update_compile_order -fileset sim_1
launch_simulation -simset sim_1 -mode behavioral
run all
close_sim
close_project
puts "XSIM_RUN_FINISHED $top (verify PASS marker in simulator log)"
exit
