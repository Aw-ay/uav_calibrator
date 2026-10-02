# Portable source-only project: no synthesis, implementation, or IP upgrade.
set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Requires Vivado 2025.2"}
set target [file join $root vivado]
if {[file exists [file join $target uav_calibrator.xpr]]} {error "Project exists; refusing overwrite"}
file mkdir [file join $root build]
file mkdir [file join $root reports]
create_project uav_calibrator $target -part xczu27dr-fsve1156-2-i
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
proc source_files {directory} {
 set result [glob -nocomplain -directory $directory *.sv]
 foreach child [glob -nocomplain -types d -directory $directory *] {set result [concat $result [source_files $child]]}
 return $result
}
add_files -norecurse [source_files [file join $root rtl]]
add_files -fileset sim_1 -norecurse [source_files [file join $root tb]]
foreach name {capture_ram_probe dma_probe rfdc_probe} {
 add_files -norecurse [file join $root hw ip $name ${name}.xci]
}
add_files -fileset constrs_1 -norecurse [file join $root hw constraints board_pending.xdc]
set_property top calibrator_instrument_core [get_filesets sources_1]
set_property top tb_calibrator_instrument_core [get_filesets sim_1]
foreach legacy {fractional_delay.sv fractional_delay_pipelined.sv fractional_delay_profile.sv fractional_delay_coeff_rom.sv frozen_record_reader.sv record_formatter.sv} {
 foreach f [get_files -quiet */$legacy] {set_property USED_IN_SYNTHESIS false $f}
}
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
puts "REVIEW_PROJECT_CREATED TOP=[get_property TOP [get_filesets sources_1]]"
close_project
exit
