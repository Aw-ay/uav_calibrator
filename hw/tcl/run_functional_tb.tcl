# Independent simulation project: never changes the implementation top.
set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Requires Vivado 2025.2"}
if {[llength $argv] != 1} {error "Expected testbench top"}
set top [lindex $argv 0]
set sources [dict create \
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
 tb_control {rtl/generated/calibrator_contract_pkg.sv rtl/control/cdc_mailbox.sv rtl/time/gsc_timebase.sv rtl/control/csr_control_axi.sv tb/unit/tb_control.sv}]
dict set sources tb_qualified_reset_drain [concat [lrange [dict get $sources tb_qualified_record_upload] 0 end-1] {rtl/capture/capture_reset_coordinator.sv tb/system/tb_qualified_reset_drain.sv}]
if {![dict exists $sources $top]} {error "Unsupported top: $top"}
create_project -force functional_$top [file join $root build functional_tb $top] -part xczu27dr-fsve1156-2-i
foreach rel [dict get $sources $top] {add_files -fileset sim_1 -norecurse [file join $root $rel]}
set_property top $top [get_filesets sim_1]
set_property xsim.simulate.runtime 0ns [get_filesets sim_1]
if {$top eq "tb_qualified_record_upload" || $top eq "tb_qualified_reset_drain"} {
 set vectors [file join $root build qualified_upload_vectors]
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
