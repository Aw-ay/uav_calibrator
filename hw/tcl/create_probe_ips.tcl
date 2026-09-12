# Reproducible C02 probe; never upgrades vendor IP in place.
set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Requires Vivado 2025.2"}
set directory [file join $root build ip_probe_2025_2]
if {[file exists [file join $directory calibrator_ip_probe.xpr]]} {
  open_project [file join $directory calibrator_ip_probe.xpr]
} else {
  create_project calibrator_ip_probe $directory -part xczu27dr-fsve1156-2-i
}
foreach {name module} {blk_mem_gen capture_ram_probe axi_dma dma_probe usp_rf_data_converter rfdc_probe} {
  if {![llength [get_ips -quiet $module]]} {create_ip -name $name -vendor xilinx.com -library ip -module_name $module}
}
set_property -dict [list CONFIG.Memory_Type {True_Dual_Port_RAM} CONFIG.Write_Width_A {64} CONFIG.Write_Depth_A {16384} CONFIG.Read_Width_A {64} CONFIG.Write_Width_B {128} CONFIG.Read_Width_B {128} CONFIG.Enable_B {Use_ENB_Pin} CONFIG.Register_PortA_Output_of_Memory_Primitives {false} CONFIG.Register_PortB_Output_of_Memory_Primitives {false} CONFIG.Operating_Mode_A {READ_FIRST} CONFIG.Operating_Mode_B {READ_FIRST} CONFIG.Assume_Synchronous_Clk {false} CONFIG.Port_A_Clock {125} CONFIG.Port_B_Clock {200}] [get_ips capture_ram_probe]
set_property -dict [list CONFIG.c_include_mm2s {0} CONFIG.c_include_sg {1} CONFIG.c_include_s2mm {1} CONFIG.c_m_axi_s2mm_data_width {128} CONFIG.c_s_axis_s2mm_tdata_width {128} CONFIG.c_include_s2mm_dre {0} CONFIG.c_s2mm_burst_size {64} CONFIG.c_sg_length_width {23} CONFIG.c_addr_width {40} CONFIG.c_sg_include_stscntrl_strm {0} CONFIG.c_prmry_is_aclk_async {1}] [get_ips dma_probe]
generate_target all [get_ips {capture_ram_probe dma_probe}]
# RFDC remains an explicitly unconfigured probe until physical mapping is checked.
foreach ip [get_ips {capture_ram_probe dma_probe}] {create_ip_run $ip}
launch_runs {capture_ram_probe_synth_1 dma_probe_synth_1} -jobs 2
wait_on_run capture_ram_probe_synth_1
wait_on_run dma_probe_synth_1
foreach name {capture_ram_probe dma_probe} {
  set run [get_runs ${name}_synth_1]
  if {[get_property PROGRESS $run] ne "100%"} {error "$name OOC incomplete"}
  open_run $run
  report_utilization -file [file join $root reports ${name}_utilization.rpt]
  close_design
}
close_project
exit
