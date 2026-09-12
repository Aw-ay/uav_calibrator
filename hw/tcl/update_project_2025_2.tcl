# Update the existing project after an external directory backup. Never upgrade IP.
set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Requires Vivado 2025.2"}
open_project [file join $root build calibrator_zu27dr calibrator_zu27dr.xpr]
if {[get_property PART [current_project]] ne "xczu27dr-fsve1156-2-i"} {error "Existing project part changed: review board evidence"}
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
proc sv_files {directory} {
 set result [glob -nocomplain -directory $directory *.sv]
 foreach child [glob -nocomplain -types d -directory $directory *] {set result [concat $result [sv_files $child]]}
 return $result
}
foreach f [sv_files [file join $root rtl]] {
 if {![llength [get_files -quiet $f]]} {add_files -norecurse $f}
 set_property file_type SystemVerilog [get_files $f]
}
# These generated 2025.2 IPs are independently tested modules, not a complete BD.
foreach name {capture_ram_probe dma_probe rfdc_probe} {
 set path [file join $root build ip_probe_2025_2 calibrator_ip_probe.srcs sources_1 ip $name $name.xci]
 if {![file exists $path]} {error "Missing generated IP $name: run create_probe_ips/configure_rfdc_probe first"}
 if {![llength [get_files -quiet $path]]} {add_files -norecurse $path}
}
# Keep the validated PS/DMA candidate available in the original project for
# review. It is not yet a replacement for a fully connected RF platform top.
set candidate [file join $root build platform_candidate_2025_2 platform_candidate.srcs sources_1 bd platform_candidate platform_candidate.bd]
set candidate_test [file join $root reports platform_candidate_test.txt]
if {[file exists $candidate] && [file exists $candidate_test]} {
 if {![llength [get_files -quiet $candidate]]} {add_files -norecurse $candidate}
}
foreach f [sv_files [file join $root tb]] {
 if {![llength [get_files -quiet $f]]} {add_files -fileset sim_1 -norecurse $f}
}
# Stage 2 integration target exposes normalized producers and configuration transactions.
# PS/RFDC board wrapper remains a separate pending integration stage.
set_property top calibrator_dataplane_system [get_filesets sources_1]
set_property top tb_native_adapters [get_filesets sim_1]
# Retain the user's existing BD contents; board clock/preset and logical analog
# assignments remain unresolved. This BD was already excluded from synthesis.
foreach bd [get_files -quiet *.bd] {
 set_property USED_IN_SYNTHESIS false $bd
 set_property USED_IN_SIMULATION false $bd
}
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
report_ip_status -file [file join $root reports project_2025_2_ip_status.rpt]
set f [open [file join $root reports project_2025_2_sources.txt] w]
puts $f "VERSION=[version -short] PART=[get_property PART [current_project]] TOP=[get_property TOP [get_filesets sources_1]]"
foreach source [get_files -compile_order sources -used_in synthesis] {puts $f $source}
close $f
close_project
puts PROJECT_UPDATED_2025_2
exit
