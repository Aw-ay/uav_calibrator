set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Requires Vivado 2025.2"}
open_project [file join $root build calibrator_zu27dr calibrator_zu27dr.xpr]
set part [get_property PART [current_project]]
if {![string match "xczu27dr-*" $part]} {error "Wrong device"}
if {[get_property TOP [current_fileset]] ne "calibrator_instrument_core"} {error "Wrong top"}
set bd [get_files -quiet */calibrator_bd.bd]
if {[llength $bd] != 1} {error "Missing BD"}
if {[get_property USED_IN_SYNTHESIS $bd]} {error "Unverified legacy BD must remain excluded"}
set legacy_cells NOT_OPENED_LEGACY
if {[llength [get_files -quiet */calibrator_instrument_core.sv]] != 1} {error "Missing top"}
if {[llength [get_files -quiet */fir_rx_lane.sv]] != 1 || [llength [get_files -quiet */fir_tx_lane.sv]] != 1} {error "Missing FIR sources"}
foreach source {record_dma_bridge.sv axis_record_fifo.sv record_descriptor_arbiter.sv record_upload_path.sv record_upload_groups.sv pulse_detector.sv capture_record_system.sv native_overload_monitor.sv frozen_replay_reader.sv} {
 if {[llength [get_files -quiet */$source]] != 1} {error "Missing continuation source $source"}
}
set candidate [get_files -quiet */platform_candidate.bd]
if {[llength $candidate] != 1} {error "Missing PS/DMA candidate reference"}
if {[get_property USED_IN_SYNTHESIS $candidate]} {error "Incomplete candidate must remain excluded from core synthesis"}
puts "DIGITAL_PROJECT_REOPEN_OK VERSION=[version -short] PART=$part TOP=calibrator_instrument_core LEGACY_BD_CELLS=$legacy_cells"
close_project
exit
