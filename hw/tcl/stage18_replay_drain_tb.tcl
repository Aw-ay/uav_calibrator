set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Requires Vivado 2025.2"}
set top [lindex $argv 0]
if {$top ni {tb_replay_drain_observer tb_replay_drain_system}} {error "Unsupported top"}
proc sv_files {dir} {
 set result [glob -nocomplain -directory $dir *.sv]
 foreach child [glob -nocomplain -types d -directory $dir *] {set result [concat $result [sv_files $child]]}
 return $result
}
create_project -force sim_$top [file join $root build stage18 $top] -part xczu27dr-fsve1156-2-i
add_files -fileset sim_1 -norecurse [sv_files [file join $root rtl]]
set folder [expr {$top eq "tb_replay_drain_observer" ? "unit" : "system"}]
add_files -fileset sim_1 -norecurse [file join $root tb $folder $top.sv]
set_property top $top [get_filesets sim_1]
set_property xsim.simulate.runtime 0ns [get_filesets sim_1]
update_compile_order -fileset sim_1
launch_simulation -simset sim_1 -mode behavioral
run all
close_sim
close_project
puts "STAGE18_XSIM_FINISHED $top; require TB PASS separately"
exit
