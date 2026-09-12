set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Requires Vivado2025.2"}
set work [file join $root build fd_portable_xsim]
create_project -force fd_portable $work -part xczu27dr-fsve1156-2-i
foreach src {rtl/arithmetic/fixed_round_sat.sv rtl/arithmetic/fractional_delay_pipelined.sv rtl/generated/fractional_delay_coeff_rom.sv rtl/arithmetic/fractional_delay_profile.sv tb/unit/tb_fractional_delay_profile.sv} {
 add_files -fileset sim_1 -norecurse [file join $root $src]
}
# Deliberately DO NOT add/stage the coefficient .mem file. Compiled ROM must be portable.
set_property top tb_fractional_delay_profile [get_filesets sim_1]
set_property xsim.simulate.runtime 0ns [get_filesets sim_1]
set_property -dict [list xsim.simulate.xsim.more_options "-testplusarg VECTORS=[file join $root build fd_profile_vectors.mem]"] [get_filesets sim_1]
update_compile_order -fileset sim_1
launch_simulation -simset sim_1 -mode behavioral
run all
close_sim
close_project
puts "FD_PORTABLE_XSIM_FINISHED; caller must require integer oracle PASS and reject Fatal"
exit
