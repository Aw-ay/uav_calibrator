from pathlib import Path
inputs=[('rst',1),('mode_request',1),('safe_boundary',1),('rf_permit',1),('hard_fault',1),('single_antenna_ota',1),('config_commit',1),('requested_mode',3),('route_select',8),('route_enable',8),('cal_valid',8),('dc_i',128),('dc_q',128),('gain_i',144),('gain_q',144),('config_id',32),('live_data',64),('drfm_data',64),('dds_data',64),('awg_data',64),('live_valid',1),('drfm_valid',1),('dds_valid',1),('awg_valid',1)]
outputs=[('active_mode',3),('mode_accepted',1),('mode_rejected',1),('pipeline_ready',1),('config_accepted',1),('config_rejected',1),('active_config_id',32),('calibrated_i',128),('calibrated_q',128),('calibrated_valid',8),('calibration_saturated',8),('tx_saturated',8),('native_dac_valid',8),('native_dac_data',1024)]
ni=sum(w for _,w in inputs);no=sum(w for _,w in outputs)
s=[f'// All eight DAC lanes preserved; every input launched and every output captured.',f'module timing_tx_processing_chain(input wire timing_clk,input wire [{ni-1}:0] stimulus,output wire [{no-1}:0] observed);',f'(* DONT_TOUCH="true" *) reg [{ni-1}:0] launch;',f'(* DONT_TOUCH="true" *) reg [{no-1}:0] capture;',f'wire [{no-1}:0] result;','always @(posedge timing_clk)begin launch<=stimulus;capture<=result;end','assign observed=capture;']
ports=['.clk_rf(timing_clk)'];off=0
for n,w in inputs:ports.append(f'.{n}(launch[{off}+:{w}])');off+=w
off=0
for n,w in outputs:ports.append(f'.{n}(result[{off}+:{w}])');off+=w
s.append('tx_processing_chain dut('+','.join(ports)+');\nendmodule')
Path('tb/timing/timing_tx_processing_chain.sv').write_text('\n'.join(s)+'\n')
