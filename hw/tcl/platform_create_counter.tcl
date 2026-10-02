set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Requires Vivado 2025.2"}

set build_dir [file join $root build platform_counter_stage26_r4]
set xpr [file join $build_dir platform_counter.xpr]
if {[file exists $xpr]} {error "Candidate exists; refusing overwrite: $xpr"}

create_project platform_counter $build_dir -part xczu27dr-fsve1156-2-i
add_files -norecurse [file join $root rtl platform platform_counter_source.sv]
add_files -norecurse [file join $root rtl platform platform_counter_bd.v]
create_bd_design platform_counter
source [file join $root hw tcl platform_ps_preset.tcl]

set ps [create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:* ps_0]
apply_platform_ps_config $ps

set rst_ctrl [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:* rst_ctrl]
set rst_mem [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:* rst_mem]
set const_one [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:* const_one]
set_property CONFIG.CONST_VAL {1} $const_one
set const_zero [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:* const_zero]
set_property CONFIG.CONST_VAL {0} $const_zero
set sc_ctrl [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:* sc_ctrl]
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {2} CONFIG.NUM_CLKS {1}] $sc_ctrl
set sc_mem [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:* sc_mem]
set_property -dict [list CONFIG.NUM_SI {2} CONFIG.NUM_MI {1} CONFIG.NUM_CLKS {1}] $sc_mem

set dma [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:* axi_dma_s2mm]
set_property -dict [list \
  CONFIG.c_include_mm2s {0} \
  CONFIG.c_include_sg {1} \
  CONFIG.c_include_s2mm {1} \
  CONFIG.c_micro_dma {0} \
  CONFIG.c_m_axi_s2mm_data_width {128} \
  CONFIG.c_s_axis_s2mm_tdata_width {128} \
  CONFIG.c_include_s2mm_dre {0} \
  CONFIG.c_s2mm_burst_size {64} \
  CONFIG.c_sg_length_width {23} \
  CONFIG.c_addr_width {40} \
  CONFIG.c_sg_include_stscntrl_strm {0}] $dma

connect_bd_intf_net [get_bd_intf_pins $ps/M_AXI_HPM0_FPD] [get_bd_intf_pins $sc_ctrl/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins $sc_ctrl/M00_AXI] [get_bd_intf_pins $dma/S_AXI_LITE]
connect_bd_intf_net [get_bd_intf_pins $dma/M_AXI_S2MM] [get_bd_intf_pins $sc_mem/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins $dma/M_AXI_SG] [get_bd_intf_pins $sc_mem/S01_AXI]
connect_bd_intf_net [get_bd_intf_pins $sc_mem/M00_AXI] [get_bd_intf_pins $ps/S_AXI_HP0_FPD]
set gpio [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:* counter_control]
set_property -dict [list CONFIG.C_IS_DUAL {1} CONFIG.C_GPIO_WIDTH {32} CONFIG.C_GPIO2_WIDTH {32} CONFIG.C_ALL_OUTPUTS {1} CONFIG.C_ALL_INPUTS_2 {1} CONFIG.C_DOUT_DEFAULT {0x00000002}] $gpio
set counter [create_bd_cell -type module -reference platform_counter_bd counter_source]
set bridge [create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:* counter_cdc]
set_property -dict [list CONFIG.TDATA_NUM_BYTES {16} CONFIG.HAS_TKEEP {1} CONFIG.HAS_TLAST {1} CONFIG.SYNCHRONIZATION_STAGES {3}] $bridge
connect_bd_intf_net [get_bd_intf_pins $sc_ctrl/M01_AXI] [get_bd_intf_pins $gpio/S_AXI]
connect_bd_net [get_bd_pins $gpio/gpio_io_o] [get_bd_pins $counter/control]
connect_bd_net [get_bd_pins $counter/status] [get_bd_pins $gpio/gpio2_io_i]
connect_bd_intf_net [get_bd_intf_pins $counter/m_axis] [get_bd_intf_pins $bridge/S_AXIS]
connect_bd_intf_net [get_bd_intf_pins $bridge/M_AXIS] [get_bd_intf_pins $dma/S_AXIS_S2MM]
connect_bd_net [get_bd_pins $ps/pl_clk0] [get_bd_pins $gpio/s_axi_aclk] [get_bd_pins $counter/clk] [get_bd_pins $bridge/s_axis_aclk]
connect_bd_net [get_bd_pins $ps/pl_clk1] [get_bd_pins $bridge/m_axis_aclk]
connect_bd_net [get_bd_pins $rst_ctrl/peripheral_aresetn] [get_bd_pins $gpio/s_axi_aresetn] [get_bd_pins $counter/rst_n] [get_bd_pins $bridge/s_axis_aresetn]
connect_bd_net [get_bd_pins $rst_mem/peripheral_aresetn] [get_bd_pins $bridge/m_axis_aresetn]
connect_bd_net [get_bd_pins $ps/pl_clk0] \
  [get_bd_pins $ps/maxihpm0_fpd_aclk] \
  [get_bd_pins $sc_ctrl/aclk] \
  [get_bd_pins $dma/s_axi_lite_aclk] \
  [get_bd_pins $rst_ctrl/slowest_sync_clk]
connect_bd_net [get_bd_pins $ps/pl_clk1] \
  [get_bd_pins $ps/saxihp0_fpd_aclk] \
  [get_bd_pins $sc_mem/aclk] \
  [get_bd_pins $dma/m_axi_s2mm_aclk] \
  [get_bd_pins $dma/m_axi_sg_aclk] \
  [get_bd_pins $rst_mem/slowest_sync_clk]
connect_bd_net [get_bd_pins $ps/pl_resetn0] [get_bd_pins $rst_ctrl/ext_reset_in] [get_bd_pins $rst_mem/ext_reset_in]
connect_bd_net [get_bd_pins $const_one/dout] [get_bd_pins $rst_ctrl/dcm_locked] [get_bd_pins $rst_mem/dcm_locked]
connect_bd_net [get_bd_pins $const_zero/dout] [get_bd_pins $rst_ctrl/aux_reset_in] [get_bd_pins $rst_ctrl/mb_debug_sys_rst] [get_bd_pins $rst_mem/aux_reset_in] [get_bd_pins $rst_mem/mb_debug_sys_rst]
connect_bd_net [get_bd_pins $rst_ctrl/interconnect_aresetn] [get_bd_pins $sc_ctrl/aresetn]
connect_bd_net [get_bd_pins $rst_ctrl/peripheral_aresetn] [get_bd_pins $dma/axi_resetn]
connect_bd_net [get_bd_pins $rst_mem/interconnect_aresetn] [get_bd_pins $sc_mem/aresetn]
connect_bd_net [get_bd_pins $dma/s2mm_introut] [get_bd_pins $ps/pl_ps_irq0]

assign_bd_address
set dma_ctrl_seg [get_bd_addr_segs -of_objects [get_bd_addr_spaces $ps/Data] -filter {NAME =~ "*axi_dma_s2mm*Reg*"}]
if {[llength $dma_ctrl_seg] != 1} {error "Cannot resolve DMA control address segment"}
set_property offset 0xA0040000 $dma_ctrl_seg
set gpio_seg [get_bd_addr_segs -of_objects [get_bd_addr_spaces $ps/Data] -filter {NAME =~ "*counter_control*Reg*"}]
if {[llength $gpio_seg]!=1} {error "Cannot resolve counter GPIO segment"}
set_property offset 0xA0050000 $gpio_seg
validate_bd_design
if {[get_property CONFIG.FREQ_HZ [get_bd_pins $ps/pl_clk0]] != 96968727} {error "Counter wrapper clock metadata must follow changed PS preset"}
save_bd_design
set wrappers [make_wrapper -files [get_files */platform_counter.bd] -top]
add_files -norecurse $wrappers
set_property top platform_counter_wrapper [current_fileset]
update_compile_order -fileset sources_1
generate_target all [get_files */platform_counter.bd]
write_hw_platform -fixed -force -file [file join $build_dir platform_counter.xsa]
puts PLATFORM_COUNTER_XSA_CREATED_NOT_HARDWARE_TESTED
close_project
exit
