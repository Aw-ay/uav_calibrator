set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Requires Vivado 2025.2"}

set build_dir [file join $root build platform_candidate_2025_2]
set xpr [file join $build_dir platform_candidate.xpr]
if {![file exists $xpr]} {error "MISSING_PLATFORM_CANDIDATE: run hw/tcl/platform_create_candidate.tcl"}

open_project $xpr
open_bd_design [get_files */platform_candidate.bd]
validate_bd_design

proc require_equal {object property expected} {
  set actual [get_property $property $object]
  if {$actual ne $expected} {error "$property expected '$expected', got '$actual'"}
}

set ps [get_bd_cells ps_0]
set dma [get_bd_cells axi_dma_s2mm]
set rst_ctrl [get_bd_cells rst_ctrl]
set rst_mem [get_bd_cells rst_mem]
require_equal $ps CONFIG.PSU__DDRC__DEVICE_CAPACITY {8192 MBits}
require_equal $ps CONFIG.PSU__UART0__PERIPHERAL__IO {MIO 42 .. 43}
require_equal $ps CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {100}
require_equal $ps CONFIG.PSU__CRL_APB__PL1_REF_CTRL__FREQMHZ {200}
require_equal $dma CONFIG.c_include_sg {1}
require_equal $dma CONFIG.c_include_mm2s {0}
require_equal $dma CONFIG.c_include_s2mm {1}
require_equal $dma CONFIG.c_m_axi_s2mm_data_width {128}
require_equal $dma CONFIG.c_s_axis_s2mm_tdata_width {128}
require_equal $dma CONFIG.c_addr_width {40}
# Vivado 2025.2 derives 0 when SG and S2MM share clk_mem; AXI-Lite may be
# slower.  The parameter is propagate-only and must not be forced.
require_equal $dma CONFIG.c_prmry_is_aclk_async {0}
require_equal $rst_ctrl CONFIG.C_EXT_RESET_HIGH {0}
require_equal $rst_mem CONFIG.C_EXT_RESET_HIGH {0}

foreach intf {M_AXI_S2MM M_AXI_SG} {
  if {![llength [get_bd_intf_nets -quiet -of_objects [get_bd_intf_pins $dma/$intf]]]} {
    error "$intf is not connected"
  }
}
if {![llength [get_bd_intf_nets -quiet -of_objects [get_bd_intf_pins $ps/S_AXI_HP0_FPD]]]} {
  error "PS S_AXI_HP0_FPD is not connected"
}
set dma_ctrl_seg [get_bd_addr_segs -of_objects [get_bd_addr_spaces $ps/Data] -filter {NAME =~ "*axi_dma_s2mm*Reg*"}]
if {[llength $dma_ctrl_seg] != 1} {error "Cannot resolve DMA control address segment"}
if {[expr {[get_property OFFSET $dma_ctrl_seg] != 0xA0040000}]} {
  error "DMA control offset expected 0xA0040000, got [get_property OFFSET $dma_ctrl_seg]"
}

set out [open [file join $root reports platform_candidate_test.txt] w]
puts $out "PLATFORM_CANDIDATE_TEST_PASS"
puts $out "VIVADO=[version -short]"
puts $out "PART=[get_property PART [current_project]]"
puts $out "DDR_DEVICE_CAPACITY=[get_property CONFIG.PSU__DDRC__DEVICE_CAPACITY $ps]"
puts $out "UART0_IO=[get_property CONFIG.PSU__UART0__PERIPHERAL__IO $ps]"
puts $out "FCLK0_MHZ=[get_property CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ $ps]"
puts $out "FCLK1_MHZ=[get_property CONFIG.PSU__CRL_APB__PL1_REF_CTRL__FREQMHZ $ps]"
puts $out "FCLK1_ACTUAL_MHZ=[get_property CONFIG.PSU__CRL_APB__PL1_REF_CTRL__ACT_FREQMHZ $ps]"
puts $out "DMA_S2MM_WIDTH=[get_property CONFIG.c_m_axi_s2mm_data_width $dma]"
puts $out "DMA_STREAM_WIDTH=[get_property CONFIG.c_s_axis_s2mm_tdata_width $dma]"
puts $out "DMA_ADDR_WIDTH=[get_property CONFIG.c_addr_width $dma]"
puts $out "DMA_ASYNC_CLOCKS=[get_property CONFIG.c_prmry_is_aclk_async $dma]"
puts $out "RESET_EXT_ACTIVE_HIGH=[get_property CONFIG.C_EXT_RESET_HIGH $rst_mem]"
puts $out "DMA_CTRL_OFFSET=[get_property OFFSET $dma_ctrl_seg]"
close $out
close_project
exit
