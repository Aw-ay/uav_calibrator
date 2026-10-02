set root [file normalize [file join [file dirname [info script]] ../..]]
set build_dir [file join $root build platform_counter_stage26_r4]
open_project [file join $build_dir platform_counter.xpr]
open_bd_design [get_files */platform_counter.bd]
validate_bd_design
set wrappers [make_wrapper -files [get_files */platform_counter.bd] -top]
add_files -norecurse $wrappers
set_property top platform_counter_wrapper [current_fileset]
update_compile_order -fileset sources_1
generate_target all [get_files */platform_counter.bd]
write_hw_platform -fixed -force -file [file join $build_dir platform_counter.xsa]
puts PLATFORM_COUNTER_XSA_CREATED_NOT_HARDWARE_TESTED
close_project
exit
