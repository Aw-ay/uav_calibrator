set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Requires Vivado 2025.2"}
set out [file join $root reports calibrator_transmit_ooc]
file mkdir $out
create_project -in_memory -part xczu27dr-fsve1156-2-i
read_verilog -sv [file join $root rtl/control/rf_safety_interlock.sv]
read_verilog -sv [file join $root rtl/source/dds_burst_control.sv]
read_verilog -sv [file join $root rtl/source/dds_nco_wrapper.sv]
read_verilog -sv [file join $root rtl/source/awg_reader.sv]
read_verilog -sv [file join $root rtl/source/awg_load_cdc_wrapper.sv]
read_verilog -sv [file join $root rtl/source/generated_tx_sources.sv]
read_verilog -sv [file join $root rtl/source/tx_source_mux.sv]
read_verilog -sv [file join $root rtl/backend/tx_channel_router.sv]
read_verilog -sv [file join $root rtl/arithmetic/fixed_round_sat.sv]
read_verilog -sv [file join $root rtl/arithmetic/complex_cal_core.sv]
read_verilog -sv [file join $root rtl/arithmetic/tx_cal_executor.sv]
read_verilog -sv [file join $root rtl/frontend/fir_quantize.sv]
read_verilog -sv [file join $root rtl/backend/fir_tx_fir75.sv]
read_verilog -sv [file join $root rtl/backend/fir_tx_hb19.sv]
read_verilog -sv [file join $root rtl/backend/fir_tx_lane.sv]
read_verilog -sv [file join $root rtl/backend/dac_stream_adapter.sv]
read_verilog -sv [file join $root rtl/backend/tx_processing_chain.sv]
read_verilog -sv [file join $root rtl/top/calibrator_transmit_system.sv]
synth_design -top calibrator_transmit_system -mode out_of_context -part xczu27dr-fsve1156-2-i
create_clock -name clk_rf -period 8.000 [get_ports clk_rf]
create_clock -name clk_ctrl -period 10.000 [get_ports clk_ctrl]
report_utilization -file [file join $out utilization.rpt]
report_cdc -details -file [file join $out cdc.rpt]
puts CALIBRATOR_TRANSMIT_OOC_SYNTH_COMPLETE
exit
