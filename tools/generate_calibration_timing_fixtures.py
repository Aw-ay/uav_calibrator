from pathlib import Path
root=Path('.')
specs={
'rx_cal_executor':([('rst',1),('in_valid',1),('cal_valid',1),('in_i',16),('in_q',16),('dc_i',16),('dc_q',16),('gain_i',18),('gain_q',18)],[('out_valid',1),('out_cal_valid',1),('out_i',16),('out_q',16),('saturated',1)]),
 'target_complex_operator':([('rst',1),('in_valid',1),('model_valid',1),('in_hv',64),('matrix',144),('phase_i',18),('phase_q',18)],[('out_valid',1),('out_model_valid',1),('out_hv',64),('saturated',1)]),
 'fractional_delay_profile':([('rst',1),('in_valid',1),('profile_commit',1),('safe_boundary',1),('shadow_phase',8),('shadow_version',32),('in_i',16),('in_q',16)],[('out_valid',1),('out_coeff_valid',1),('saturated',1),('out_i',16),('out_q',16),('commit_ack',1),('commit_rejected',1),('active_phase',8),('active_version',32),('table_version',32)]),
 'tx_channel_router':([('rst',1),('in_valid',1),('route_commit',1),('safe_boundary',1),('shadow_select',8),('shadow_enable',8),('in_hv',64)],[('out_valid',1),('commit_ack',1),('commit_rejected',1),('lane_valid',8),('out_lanes',256)])}
for module,(inputs,outputs) in specs.items():
    ni=sum(w for _,w in inputs);no=sum(w for _,w in outputs)
    s=[f'module timing_{module}(input wire timing_clk,input wire [{ni-1}:0] stimulus,output wire [{no-1}:0] observed);',f'(* DONT_TOUCH="true" *) reg [{ni-1}:0] launch;',f'(* DONT_TOUCH="true" *) reg [{no-1}:0] capture;',f'wire [{no-1}:0] result;', 'always @(posedge timing_clk) begin launch<=stimulus;capture<=result;end','assign observed=capture;']
    ports=['.clk(timing_clk)'];offset=0
    for name,width in inputs:ports.append(f'.{name}(launch[{offset}+: {width}])');offset+=width
    offset=0
    for name,width in outputs:ports.append(f'.{name}(result[{offset}+: {width}])');offset+=width
    s.append(f'{module} dut('+','.join(ports)+');\nendmodule')
    (root/'tb/timing'/f'timing_{module}.sv').write_text('\n'.join(s)+'\n')
