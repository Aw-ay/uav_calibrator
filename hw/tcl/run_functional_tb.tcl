# Independent simulation project: never changes the implementation top.
set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Requires Vivado 2025.2"}
if {[llength $argv] != 1} {error "Expected testbench top"}
set top [lindex $argv 0]
set sources [dict create \
 tb_event_mailbox {rtl/control/cdc_mailbox.sv rtl/control/event_mailbox.sv tb/unit/tb_event_mailbox.sv} \
 tb_capture_pdw_writer {rtl/generated/capture_event_pkg.sv rtl/capture/capture_pdw_writer.sv tb/unit/tb_capture_pdw_writer.sv} \
 tb_rf_control {rtl/control/rf_safety_interlock.sv rtl/control/aux_source_controller.sv tb/unit/tb_rf_control.sv} \
 tb_replay_control {rtl/replay/replay_control_layout_pkg.sv rtl/replay/replay_descriptor_queue.sv rtl/replay/replay_legality_checker.sv tb/unit/tb_replay_control.sv} \
 tb_waveform_sources {rtl/source/dds_burst_control.sv rtl/source/dds_nco_wrapper.sv rtl/source/awg_reader.sv rtl/source/tx_source_mux.sv tb/unit/tb_waveform_sources.sv} \
 tb_awg_reader {rtl/source/awg_reader.sv tb/unit/tb_awg_reader.sv} \
 tb_tx_processing_chain {rtl/source/tx_source_mux.sv rtl/backend/tx_channel_router.sv rtl/arithmetic/fixed_round_sat.sv rtl/arithmetic/complex_cal_core.sv rtl/arithmetic/tx_cal_executor.sv rtl/frontend/fir_quantize.sv rtl/backend/fir_tx_fir75.sv rtl/backend/fir_tx_hb19.sv rtl/backend/fir_tx_lane.sv rtl/backend/dac_stream_adapter.sv rtl/backend/tx_processing_chain.sv tb/system/tb_tx_processing_chain.sv} \
 tb_capture_reset_coordinator {rtl/capture/capture_reset_coordinator.sv tb/unit/tb_capture_reset_coordinator.sv} \
 tb_qualification_record_source {rtl/capture/qualification_record_source.sv tb/unit/tb_qualification_record_source.sv} \
 tb_qualified_record_upload {rtl/generated/calibrator_contract_pkg.sv rtl/control/cdc_mailbox.sv rtl/capture/capture_bank_manager.sv rtl/capture/capture_ram.sv rtl/capture/capture_bank_array.sv rtl/capture/frozen_record_reader.sv rtl/capture/record_formatter.sv rtl/capture/record_dma_bridge.sv rtl/capture/capture_record_system.sv rtl/capture/pulse_context_join.sv rtl/capture/pulse_context_pool.sv rtl/capture/noise_window_energy.sv rtl/capture/range_linearity.sv rtl/capture/capture_range_select.sv rtl/capture/range_qualification.sv rtl/capture/pulse_qualification_engine.sv rtl/capture/qualification_bank_commit.sv rtl/capture/qualification_publish_bridge.sv rtl/capture/qualification_record_source.sv rtl/data/axis_record_fifo.sv rtl/data/record_upload_path.sv rtl/data/record_descriptor_arbiter.sv rtl/data/record_upload_groups.sv tb/system/tb_qualified_record_upload.sv} \
 tb_qualification_publish_bridge {rtl/capture/capture_bank_manager.sv rtl/capture/pulse_context_join.sv rtl/capture/pulse_context_pool.sv rtl/capture/noise_window_energy.sv rtl/capture/range_linearity.sv rtl/capture/capture_range_select.sv rtl/capture/range_qualification.sv rtl/capture/pulse_qualification_engine.sv rtl/capture/qualification_bank_commit.sv rtl/capture/qualification_publish_bridge.sv tb/system/tb_qualification_publish_bridge.sv} \
 tb_qualification_bank_commit {rtl/capture/capture_bank_manager.sv rtl/capture/qualification_bank_commit.sv tb/system/tb_qualification_bank_commit.sv} \
 tb_pulse_qualification_engine {rtl/capture/pulse_context_join.sv rtl/capture/pulse_context_pool.sv rtl/capture/noise_window_energy.sv rtl/capture/range_linearity.sv rtl/capture/capture_range_select.sv rtl/capture/range_qualification.sv rtl/capture/pulse_qualification_engine.sv tb/system/tb_pulse_qualification_engine.sv} \
 tb_pulse_context_pool {rtl/capture/pulse_context_join.sv rtl/capture/pulse_context_pool.sv tb/unit/tb_pulse_context_pool.sv} \
 tb_pulse_context_join {rtl/capture/pulse_context_join.sv tb/unit/tb_pulse_context_join.sv} \
 tb_range_linearity {rtl/capture/range_linearity.sv tb/unit/tb_range_linearity.sv} \
 tb_noise_snapshot {rtl/capture/noise_snapshot.sv rtl/capture/noise_window_energy.sv tb/unit/tb_noise_snapshot.sv} \
 tb_range_qualification {rtl/capture/capture_range_select.sv rtl/capture/range_qualification.sv tb/unit/tb_range_qualification.sv} \
 tb_range_statistics {rtl/capture/pulse_range_statistics.sv tb/unit/tb_range_statistics.sv} \
 tb_detector_scoreboard {rtl/capture/pulse_detector.sv tb/system/tb_detector_scoreboard.sv} \
 tb_pulse_detector {rtl/capture/pulse_detector.sv tb/unit/tb_pulse_detector.sv} \
 tb_frozen_replay_reader {rtl/replay/frozen_replay_reader.sv tb/unit/tb_frozen_replay_reader.sv} \
 tb_control {rtl/generated/calibrator_contract_pkg.sv rtl/control/cdc_mailbox.sv rtl/control/event_mailbox.sv rtl/time/gsc_timebase.sv rtl/control/csr_control_axi.sv tb/unit/tb_control.sv}]
dict set sources tb_qualified_reset_drain [concat [lrange [dict get $sources tb_qualified_record_upload] 0 end-1] {rtl/capture/capture_reset_coordinator.sv tb/system/tb_qualified_reset_drain.sv}]
dict set sources tb_calibrator_capture_pipeline [concat [lrange [dict get $sources tb_qualified_record_upload] 0 end-1] {rtl/capture/capture_reset_coordinator.sv rtl/capture/capture_statistics_reader.sv rtl/capture/calibrator_capture_pipeline.sv tb/system/tb_calibrator_capture_pipeline.sv}]
dict set sources tb_capture_statistics_reader {rtl/capture/capture_bank_manager.sv rtl/capture/capture_ram.sv rtl/capture/capture_statistics_reader.sv tb/system/tb_capture_statistics_reader.sv}
dict set sources tb_awg_load_cdc {rtl/source/awg_reader.sv rtl/source/awg_load_cdc_wrapper.sv tb/unit/tb_awg_load_cdc.sv}
dict set sources tb_channel_epoch_aligner {rtl/frontend/channel_epoch_aligner.sv tb/unit/tb_channel_epoch_aligner.sv}
dict set sources tb_tx_reference_analyzer {rtl/monitor/tx_reference_analyzer.sv tb/unit/tb_tx_reference_analyzer.sv}
dict set sources tb_pdw_mailbox_integration {rtl/generated/capture_event_pkg.sv rtl/control/cdc_mailbox.sv rtl/control/event_mailbox.sv rtl/capture/capture_pdw_writer.sv tb/system/tb_pdw_mailbox_integration.sv}
dict set sources tb_coeff_reload {rtl/control/coeff_reload_bridge.sv tb/unit/tb_coeff_reload.sv}
dict set sources tb_calibrator_capture_system [concat [lrange [dict get $sources tb_calibrator_capture_pipeline] 0 end-1] {rtl/capture/frame_header_builder.sv rtl/capture/capture_admission_bridge.sv rtl/capture/capture_producer_tracker.sv rtl/capture/calibrator_capture_system.sv tb/system/tb_calibrator_capture_system.sv}]
dict set sources tb_capture_producer_tracker {rtl/generated/calibrator_contract_pkg.sv rtl/capture/capture_bank_manager.sv rtl/capture/capture_producer_tracker.sv tb/system/tb_capture_producer_tracker.sv}
dict set sources tb_generated_tx_sources {rtl/source/dds_burst_control.sv rtl/source/dds_nco_wrapper.sv rtl/source/awg_reader.sv rtl/source/awg_load_cdc_wrapper.sv rtl/source/generated_tx_sources.sv tb/unit/tb_generated_tx_sources.sv}
dict set sources tb_replay_processing_chain {rtl/arithmetic/fixed_round_sat.sv rtl/arithmetic/complex_cal_core.sv rtl/arithmetic/rx_cal_executor.sv rtl/arithmetic/fractional_delay_pipelined.sv rtl/arithmetic/fractional_delay_profile.sv rtl/generated/fractional_delay_coeff_rom.sv rtl/arithmetic/target_complex_operator.sv rtl/replay/replay_processing_chain.sv tb/system/tb_replay_processing_chain.sv}
dict set sources tb_capture_replay_binding {rtl/replay/replay_control_layout_pkg.sv rtl/top/capture_replay_binding.sv tb/system/tb_capture_replay_binding.sv}
dict set sources tb_calibrator_dataplane_system {rtl/generated/calibrator_contract_pkg.sv rtl/generated/capture_event_pkg.sv rtl/replay/replay_control_layout_pkg.sv rtl/calibrator_top.sv rtl/arithmetic/complex_cal_core.sv rtl/arithmetic/fixed_round_sat.sv rtl/arithmetic/fractional_delay.sv rtl/arithmetic/fractional_delay_pipelined.sv rtl/arithmetic/fractional_delay_profile.sv rtl/arithmetic/rx_cal_executor.sv rtl/arithmetic/target_complex_operator.sv rtl/arithmetic/tx_cal_executor.sv rtl/backend/dac_stream_adapter.sv rtl/backend/fir_tx_fir75.sv rtl/backend/fir_tx_hb19.sv rtl/backend/fir_tx_lane.sv rtl/backend/tx_channel_router.sv rtl/backend/tx_processing_chain.sv rtl/capture/calibrator_capture_pipeline.sv rtl/capture/calibrator_capture_system.sv rtl/capture/capture_admission_bridge.sv rtl/capture/capture_bank_array.sv rtl/capture/capture_bank_manager.sv rtl/capture/capture_pdw_writer.sv rtl/capture/capture_producer_tracker.sv rtl/capture/capture_ram.sv rtl/capture/capture_range_select.sv rtl/capture/capture_record_system.sv rtl/capture/capture_reset_coordinator.sv rtl/capture/capture_statistics_reader.sv rtl/capture/frame_header_builder.sv rtl/capture/frozen_record_reader.sv rtl/capture/noise_snapshot.sv rtl/capture/noise_window_energy.sv rtl/capture/pulse_context_join.sv rtl/capture/pulse_context_pool.sv rtl/capture/pulse_detector.sv rtl/capture/pulse_qualification_engine.sv rtl/capture/pulse_range_statistics.sv rtl/capture/qualification_bank_commit.sv rtl/capture/qualification_publish_bridge.sv rtl/capture/qualification_record_source.sv rtl/capture/range_linearity.sv rtl/capture/range_qualification.sv rtl/capture/record_dma_bridge.sv rtl/capture/record_formatter.sv rtl/control/aux_source_controller.sv rtl/control/cdc_mailbox.sv rtl/control/coeff_reload_bridge.sv rtl/control/csr_control_axi.sv rtl/control/event_mailbox.sv rtl/control/rf_safety_interlock.sv rtl/data/axis_record_fifo.sv rtl/data/record_descriptor_arbiter.sv rtl/data/record_upload_groups.sv rtl/data/record_upload_path.sv rtl/frontend/channel_epoch_aligner.sv rtl/frontend/fir_quantize.sv rtl/frontend/fir_rx_fir75.sv rtl/frontend/fir_rx_hb19.sv rtl/frontend/fir_rx_lane.sv rtl/frontend/native_overload_monitor.sv rtl/frontend/rfdc_stream_adapter.sv rtl/generated/fractional_delay_coeff_rom.sv rtl/monitor/tx_reference_analyzer.sv rtl/replay/calibrator_replay_system.sv rtl/replay/frozen_replay_reader.sv rtl/replay/replay_descriptor_queue.sv rtl/replay/replay_legality_checker.sv rtl/replay/replay_processing_chain.sv rtl/replay/replay_task_dispatcher.sv rtl/source/awg_load_cdc_wrapper.sv rtl/source/awg_reader.sv rtl/source/dds_burst_control.sv rtl/source/dds_nco_wrapper.sv rtl/source/generated_tx_sources.sv rtl/source/tx_source_mux.sv rtl/time/gsc_timebase.sv rtl/top/calibrator_dataplane_system.sv rtl/top/calibrator_transmit_system.sv rtl/top/capture_replay_binding.sv tb/system/tb_calibrator_dataplane_system.sv}
dict set sources tb_calibrator_dataplane_cancel [dict get $sources tb_calibrator_dataplane_system]
if {![dict exists $sources $top]} {error "Unsupported top: $top"}
create_project -force functional_$top [file join $root build functional_tb $top] -part xczu27dr-fsve1156-2-i
foreach rel [dict get $sources $top] {add_files -fileset sim_1 -norecurse [file join $root $rel]}
set_property top $top [get_filesets sim_1]
set_property xsim.simulate.runtime 0ns [get_filesets sim_1]
if {$top eq "tb_qualified_record_upload" || $top eq "tb_qualified_reset_drain" || $top eq "tb_calibrator_capture_pipeline" || $top eq "tb_calibrator_capture_system" || $top eq "tb_calibrator_dataplane_system" || $top eq "tb_calibrator_dataplane_cancel"} {
 set vectors [file join $root build qualified_upload_vectors]
 if {$top eq "tb_calibrator_capture_system" || $top eq "tb_calibrator_dataplane_system" || $top eq "tb_calibrator_dataplane_cancel"} {set vectors [file join $root build capture_system_vectors]}
 if {![file exists [file join $vectors expected.hex]]} {error "Run tests/test_qualified_record_upload.py to generate independent vectors first"}
 set_property -dict [list xsim.simulate.xsim.more_options "-testplusarg ROOT=$vectors"] [get_filesets sim_1]
}
update_compile_order -fileset sim_1
launch_simulation -simset sim_1 -mode behavioral
log_wave -r /*
run all
close_sim
close_project
puts "XSIM_RUN_FINISHED $top; caller must also require the testbench PASS marker"
exit
