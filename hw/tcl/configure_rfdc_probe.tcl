# Native port/rate probe, not an approved board clock or analog-channel mapping.
# Values checked against 2025.2 RFDC component.xml choice enumerations.
set cfg [list CONFIG.Axiclk_Freq {100}]
for {set t 0} {$t < 4} {incr t} {
 lappend cfg CONFIG.ADC${t}_Enable 1 CONFIG.ADC${t}_PLL_Enable true CONFIG.ADC${t}_Sampling_Rate 4.0 CONFIG.ADC${t}_Refclk_Freq 200.000 CONFIG.ADC${t}_Fabric_Freq 125.000 CONFIG.ADC${t}_Multi_Tile_Sync true
 foreach s {0 2} {lappend cfg CONFIG.ADC_Slice${t}${s}_Enable true CONFIG.ADC_Data_Type${t}${s} 1 CONFIG.ADC_Mixer_Mode${t}${s} 0 CONFIG.ADC_Mixer_Type${t}${s} 2 CONFIG.ADC_Decimation_Mode${t}${s} 8 CONFIG.ADC_Data_Width${t}${s} 4}
}
for {set t 0} {$t < 2} {incr t} {
 lappend cfg CONFIG.DAC${t}_Enable 1 CONFIG.DAC${t}_PLL_Enable true CONFIG.DAC${t}_Sampling_Rate 4.0 CONFIG.DAC${t}_Refclk_Freq 200.000 CONFIG.DAC${t}_Fabric_Freq 125.000 CONFIG.DAC${t}_Multi_Tile_Sync true
 for {set s 0} {$s < 4} {incr s} {lappend cfg CONFIG.DAC_Slice${t}${s}_Enable true CONFIG.DAC_Data_Type${t}${s} 0 CONFIG.DAC_Mixer_Mode${t}${s} 0 CONFIG.DAC_Mixer_Type${t}${s} 2 CONFIG.DAC_Interpolation_Mode${t}${s} 8 CONFIG.DAC_Data_Width${t}${s} 8}
}
# DAC Data_Type describes real output, not the complex PL input.
set_property -dict $cfg [get_ips rfdc_probe]
generate_target all [get_ips rfdc_probe]
