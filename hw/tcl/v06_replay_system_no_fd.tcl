set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Requires Vivado 2025.2"}
set out [file join $root reports v06_modules replay_system_no_fd]
file mkdir $out
create_project -in_memory -part xczu27dr-fsve1156-2-i
foreach f {rtl/replay/replay_control_layout_pkg.sv rtl/replay/replay_descriptor_queue.sv rtl/replay/replay_legality_checker.sv rtl/replay/frozen_replay_reader.sv rtl/replay/replay_task_dispatcher.sv rtl/arithmetic/fixed_round_sat.sv rtl/arithmetic/complex_cal_core.sv rtl/arithmetic/rx_cal_executor.sv rtl/arithmetic/target_complex_operator.sv rtl/replay/replay_processing_chain.sv rtl/replay/task_doppler_phase.sv rtl/replay/calibrator_replay_system.sv} {read_verilog -sv [file join $root $f]}
synth_design -top calibrator_replay_system -mode out_of_context -part xczu27dr-fsve1156-2-i
create_clock -name clk_rf -period 8.000 [get_ports clk]
report_utilization -file [file join $out utilization.rpt]
report_timing_summary -report_unconstrained -file [file join $out timing_synth.rpt]
check_timing -verbose -file [file join $out check_timing.rpt]
puts V06_REPLAY_SYSTEM_NO_FD_SYNTH_COMPLETE
exit
