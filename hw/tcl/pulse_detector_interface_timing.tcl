set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Requires Vivado 2025.2"}
set out [file join $root reports pulse_detector_ooc]
open_checkpoint [file join $out route.dcp]
# Diagnostic assumption: all input/output signals connect to clk_rf registers
# with zero external logic budget. This covers the otherwise unconstrained IQ
# power computation, but does not replace integrated route/interface timing.
set_input_delay 0.000 -clock clk_rf [get_ports -filter {DIRECTION == IN && NAME != clk}]
set_output_delay 0.000 -clock clk_rf [get_ports -filter {DIRECTION == OUT}]
report_timing_summary -file [file join $out timing_interface.rpt]
report_timing -from [get_ports {iq[*]}] -max_paths 10 -file [file join $out timing_iq_paths.rpt]
close_design
puts PULSE_DETECTOR_INTERFACE_TIMING_COMPLETE
exit
