set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Requires Vivado 2025.2"}
set tops $argv
if {![llength $tops]} {set tops {task_doppler_phase aux_capture_path}}
foreach top $tops {
 if {$top ni {task_doppler_phase aux_capture_path}} {error "Unsupported module"}
 set out [file join $root reports module_stage27 $top]
 file mkdir $out
 create_project -in_memory -part xczu27dr-fsve1156-2-i
 if {$top eq "task_doppler_phase"} {
  read_verilog -sv [file join $root rtl/replay/task_doppler_phase.sv]
 } else {
  foreach f {rtl/generated/calibrator_contract_pkg.sv rtl/generated/aux_metadata_pkg.sv rtl/capture/frame_header_builder.sv rtl/capture/aux_window_tracker.sv rtl/capture/aux_record_metadata.sv rtl/capture/aux_record_admission.sv rtl/capture/aux_capture_path.sv} {read_verilog -sv [file join $root $f]}
 }
 if {$top eq "aux_capture_path"} {
  synth_design -top $top -mode out_of_context -part xczu27dr-fsve1156-2-i -generic PHYSICAL_MASKS_IN_TEMPLATE=1
 } else {
  synth_design -top $top -mode out_of_context -part xczu27dr-fsve1156-2-i
 }
 create_clock -name clk -period 8.000 [get_ports clk]
 if {[llength [get_cells -quiet -hier -filter {IS_BLACKBOX == 1}]]} {error "Unresolved blackboxes"}
 report_utilization -file [file join $out utilization.rpt]
 report_timing_summary -report_unconstrained -file [file join $out timing_synth.rpt]
 check_timing -verbose -file [file join $out check_timing.rpt]
 report_cdc -details -file [file join $out cdc.rpt]
 write_checkpoint -force [file join $out synth.dcp]
 puts "STAGE27_MODULE_COMPLETE $top"
 close_project
}
exit
