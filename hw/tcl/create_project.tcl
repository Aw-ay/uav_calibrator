set root [file normalize [file join [file dirname [info script]] ../..]]
set part xczu27dr-fsve1156-2-i
if {[llength $argv] > 0} {set part [lindex $argv 0]}
if {[version -short] ne "2025.2"} {error "Requires Vivado 2025.2"}
if {![string match "xczu27dr-*" $part] || [llength [get_parts -quiet $part]] != 1} {error "Unsupported ZU27DR part"}
set project_dir [file join $root build calibrator_zu27dr]
if {[file exists [file join $project_dir calibrator_zu27dr.xpr]]} {error "Project exists; refusing overwrite"}
create_project calibrator_zu27dr $project_dir -part $part
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
add_files -norecurse [file join $root rtl calibrator_top.sv]
set_property top calibrator_top [current_fileset]
add_files -fileset constrs_1 -norecurse [file join $root hw constraints board_pending.xdc]
create_bd_design calibrator_bd
save_bd_design
set bd [get_files -quiet */calibrator_bd.bd]
set_property USED_IN_SYNTHESIS false $bd
set_property USED_IN_SIMULATION false $bd
update_compile_order -fileset sources_1
close_project
source [file join $root hw tcl update_project_2025_2.tcl]

