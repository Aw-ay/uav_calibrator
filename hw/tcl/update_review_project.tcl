set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Requires Vivado2025.2"}
open_project [file join $root vivado uav_calibrator.xpr]
proc source_files {directory} {
 set result [glob -nocomplain -directory $directory *.sv]
 foreach child [glob -nocomplain -types d -directory $directory *] {set result [concat $result [source_files $child]]}
 return $result
}
add_files -norecurse [source_files [file join $root rtl]]
add_files -fileset sim_1 -norecurse [source_files [file join $root tb]]
foreach legacy {fractional_delay.sv fractional_delay_pipelined.sv fractional_delay_profile.sv fractional_delay_coeff_rom.sv frozen_record_reader.sv record_formatter.sv} {
 foreach f [get_files -quiet */$legacy] {set_property USED_IN_SYNTHESIS false $f}
}
set_property top calibrator_instrument_core [get_filesets sources_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
foreach name {fine_engine.sv fine_bank_service.sv fine_result_transport.sv online_body_statistics.sv b_port_reader_128.sv dma_payload_packer.sv record_formatter_128.sv} {
 set files [get_files -quiet */$name]
 if {[llength $files]!=1 || ![get_property USED_IN_SYNTHESIS $files]} {error "Missing active v0.6 source $name"}
}
puts REVIEW_V06_PROJECT_UPDATED
close_project
exit
