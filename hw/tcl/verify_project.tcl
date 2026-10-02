set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Requires Vivado 2025.2"}
open_project [file join $root build calibrator_zu27dr calibrator_zu27dr.xpr]
set part [get_property PART [current_project]]
if {![string match "xczu27dr-*" $part]} {error "Wrong device"}
if {[get_property TOP [current_fileset]] ne "calibrator_instrument_core"} {error "Wrong top"}
set bd [get_files -quiet */calibrator_bd.bd]
if {[llength $bd] > 1} {error "Duplicate legacy BD"}
set legacy_cells ABSENT
if {[llength $bd]} {
 if {[get_property USED_IN_SYNTHESIS $bd]} {error "Unverified legacy BD must remain excluded"}
 set legacy_cells NOT_OPENED_LEGACY
}
if {[llength [get_files -quiet */calibrator_instrument_core.sv]] != 1} {error "Missing top"}
if {[llength [get_files -quiet */fir_rx_lane.sv]] != 1 || [llength [get_files -quiet */fir_tx_lane.sv]] != 1} {error "Missing FIR sources"}
foreach source {aux_capture_path.sv aux_window_tracker.sv aux_record_admission.sv aux_record_metadata.sv aux_metadata_pkg.sv task_doppler_phase.sv replay_control_layout_pkg.sv} {
 set files [get_files -quiet */$source]
 if {[llength $files] != 1 || ![get_property USED_IN_SYNTHESIS $files]} {error "Missing or excluded stage27 source $source"}
}
foreach source {record_dma_bridge.sv axis_record_fifo.sv record_descriptor_arbiter.sv record_upload_path.sv record_upload_groups.sv pulse_detector.sv capture_record_system.sv native_overload_monitor.sv frozen_replay_reader.sv} {
 if {[llength [get_files -quiet */$source]] != 1} {error "Missing continuation source $source"}
}
foreach source {online_body_statistics.sv receive_power_pipeline.sv capture_online_statistics.sv b_port_reader_128.sv dma_payload_packer.sv record_formatter_128.sv crc32c_parallel_pkg.sv} {
 set files [get_files -quiet */$source]
 if {[llength $files] != 1 || ![get_property USED_IN_SYNTHESIS $files]} {error "Missing or excluded v0.6 DMA source $source"}
}
foreach legacy {fractional_delay.sv fractional_delay_pipelined.sv fractional_delay_profile.sv fractional_delay_coeff_rom.sv frozen_record_reader.sv record_formatter.sv} {
 foreach f [get_files -quiet */$legacy] {
  if {[get_property USED_IN_SYNTHESIS $f]} {error "Legacy FD still active: $legacy"}
 }
}
set candidate [get_files -quiet */platform_candidate.bd]
foreach source {fine_fast_math.sv fine_signed_math.sv fine_finalize.sv fine_engine.sv fine_bank_service.sv fine_result_transport.sv fine_sample_cache_2.sv fine_segment_accumulator_2.sv fine_cordic.sv fine_sample_cache.sv fine_segment_accumulator.sv fine_wide_math.sv fine_edge_solver.sv fine_edge_program_pkg.sv} {
 set files [get_files -quiet */$source]
 if {[llength $files] != 1 || ![get_property USED_IN_SYNTHESIS $files]} {error "Missing or excluded Fine source $source"}
}
if {[llength $candidate] != 1} {error "Missing PS/DMA candidate reference"}
if {[get_property USED_IN_SYNTHESIS $candidate]} {error "Incomplete candidate must remain excluded from core synthesis"}
puts "DIGITAL_PROJECT_REOPEN_OK VERSION=[version -short] PART=$part TOP=calibrator_instrument_core LEGACY_BD_CELLS=$legacy_cells"
close_project
exit
