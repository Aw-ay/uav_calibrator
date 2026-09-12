set root [file normalize [file join [file dirname [info script]] ../..]]
cd $root
if {[version -short] ne "2025.2"} {error "Requires Vivado2025.2"}
set modules {rx_cal_executor target_complex_operator fractional_delay_profile tx_channel_router}
if {$argc>0} {set modules $argv}
foreach top $modules {
 set out [file join $root reports calibration_timing $top]
 file mkdir $out
 create_project -in_memory -part xczu27dr-fsve1156-2-i
 foreach file [glob [file join $root rtl arithmetic *.sv]] {read_verilog -sv $file}
 read_verilog -sv [file join $root rtl generated fractional_delay_coeff_rom.sv]
 read_verilog -sv [file join $root rtl backend tx_channel_router.sv]
 read_verilog -sv [file join $root tb timing timing_$top.sv]
 synth_design -top timing_$top -mode out_of_context -part xczu27dr-fsve1156-2-i
 report_utilization -file [file join $out synthesis_utilization.rpt]
 if {$top eq "fractional_delay_profile"} {
   set dsp_count [llength [get_cells -hier -filter {REF_NAME == DSP48E2}]]
   puts "FD_DSP_COUNT $dsp_count"
   if {$dsp_count > 126} {error "FD DSP count exceeds126per-complex-channel allowance"}
 }
 create_clock -name clk_rf -period 8.000 [get_ports timing_clk]
 # Real launch/capture registers cover all DUT data/control paths.
 # Fixture external stimulus/observed ports have no board interface constraints.
 # No false path, multicycle, frequency reduction or I/O timing claims.
 opt_design
 place_design
 route_design
 report_timing_summary -report_unconstrained -file [file join $out timing.rpt]
 report_timing -delay_type min_max -max_paths 10 -file [file join $out paths.rpt]
 check_timing -verbose -file [file join $out check_timing.rpt]
 report_route_status -file [file join $out route_status.rpt]
 report_drc -file [file join $out drc.rpt]
 report_utilization -file [file join $out utilization.rpt]
 write_checkpoint -force [file join $out route.dcp]
 puts "CALIBRATION_TIMING_COMPLETE $top"
 close_project
}
exit

