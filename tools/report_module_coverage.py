"""Report implementation aliases without treating file presence as acceptance."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]
# Catalog names are responsibilities; an implementation may live in a shared unit.
ALIASES={
'rfadc_stream_adapter':(['rtl/frontend/rfdc_stream_adapter.sv'],['test_eight_channel_rtl.py']),
'rx_decim4_wrapper':(['rtl/frontend/fir_rx_lane.sv','rtl/frontend/fir_rx_hb19.sv','rtl/frontend/fir_rx_fir75.sv'],['test_fir_rtl.py','test_eight_channel_rtl.py']),
'global_sample_time':(['rtl/time/gsc_timebase.sv'],['test_control_rtl.py']),
'range_qualifier':(['rtl/capture/range_qualification.sv','rtl/capture/range_linearity.sv'],['test_range_qualification.py','test_range_linearity.py']),
'range_selector_eop':(['rtl/capture/capture_range_select.sv','rtl/capture/qualification_bank_commit.sv'],['test_qualification_bank_commit.py']),
'pulse_context_latch':(['rtl/capture/pulse_context_join.sv','rtl/capture/pulse_context_pool.sv','rtl/capture/capture_producer_tracker.sv'],['test_pulse_context_join.py','test_pulse_context_pool.py','test_capture_producer_tracker.py']),
'capture_bank_ram':(['rtl/capture/capture_ram.sv','rtl/capture/capture_bank_array.sv'],['test_capture_rtl.py']),
'frozen_frame_reader':(['rtl/capture/frozen_record_reader.sv'],['test_record_rtl.py']),
'iq_frame_formatter':(['rtl/capture/record_formatter.sv'],['test_record_rtl.py']),
'crc32c_stream':(['rtl/capture/record_formatter.sv'],['test_record_rtl.py']),
'replay_reader_scheduler':(['rtl/replay/frozen_replay_reader.sv'],['test_replay_reader_rtl.py']),
'fractional_delay':(['rtl/arithmetic/fractional_delay_profile.sv','rtl/arithmetic/fractional_delay_pipelined.sv','rtl/generated/fractional_delay_coeff_rom.sv'],['test_fractional_delay_profile.py']),
'dds_burst_control':(['rtl/source/dds_burst_control.sv'],['test_waveform_sources.py','test_generated_tx_sources.py']),
'dds_nco_wrapper':(['rtl/source/dds_nco_wrapper.sv'],['test_waveform_sources.py','test_generated_tx_sources.py']),
'awg_reader':(['rtl/source/awg_reader.sv','rtl/source/awg_load_cdc_wrapper.sv'],['test_waveform_sources.py','test_awg_load_cdc.py']),
'config_shadow_commit':(['rtl/control/csr_control_axi.sv','rtl/control/cdc_mailbox.sv'],['test_control_rtl.py']),
'fault_status_registers':(['rtl/control/csr_control_axi.sv'],['test_control_rtl.py']),
'rfdac_stream_adapter':(['rtl/backend/dac_stream_adapter.sv'],['test_eight_channel_rtl.py','test_tx_processing_chain.py']),
 'tx_interp4_wrapper':(['rtl/backend/fir_tx_lane.sv','rtl/backend/fir_tx_fir75.sv','rtl/backend/fir_tx_hb19.sv'],['test_fir_rtl.py','test_tx_processing_chain.py'])}
TESTS={
'native_overload_monitor':['test_native_overload_rtl.py'], 'channel_epoch_aligner':['test_channel_monitor.py'],
'fixed_round_sat':['test_calibration_dsp.py'], 'pulse_detector':['test_pulse_detector_rtl.py','test_detector_scoreboard.py'],
'capture_bank_manager':['test_capture_rtl.py'],'capture_pdw_writer':['test_capture_pdw.py'], 'event_mailbox':['test_event_mailbox.py','test_pdw_mailbox_integration.py'],
'replay_descriptor_queue':['test_replay_control.py'],'replay_legality_checker':['test_replay_control.py'],
'rx_cal_executor':['test_calibration_dsp.py'],'tx_cal_executor':['test_calibration_dsp.py','test_tx_processing_chain.py'],
'target_complex_operator':['test_calibration_dsp.py'],'tx_source_mux':['test_waveform_sources.py','test_tx_processing_chain.py'],
'tx_reference_analyzer':['test_channel_monitor.py'],'rf_safety_interlock':['test_rf_control.py'],'aux_source_controller':['test_rf_control.py'],
'coeff_reload_bridge':['test_coeff_reload.py'],'tx_channel_router':['test_calibration_dsp.py','test_tx_processing_chain.py']}
regression=json.loads((ROOT/'reports/regression_latest.json').read_text())
passed={Path(r['command'][-1]).name for r in regression['results'] if r['exit_code']==0}
rows=[]
for m in json.loads((ROOT/'contracts/module_catalog.json').read_text(encoding='utf-8-sig'))['modules']:
 name=m['name'];files,tests=ALIASES.get(name,([m['proposed_file']],TESTS.get(name,[])))
 exists=all((ROOT/f).is_file() for f in files)
 evidence=bool(tests) and all(t in passed for t in tests)
 status='FUNCTIONAL_BOUNDED' if exists and evidence else 'SOURCE_PRESENT_NEW_TEST_NOT_IN_LAST_REGRESSION' if exists else 'OPTIONAL_NOT_IMPLEMENTED' if m['scope']=='OPTIONAL' else 'NOT_IMPLEMENTED'
 rows.append(dict(name=name,scope=m['scope'],status=status,files=files,tests=tests))
report=dict(status='PARTIAL_SYSTEM_INTEGRATION',regression_utc=regression['utc'],modules=rows,
 caveats=['FUNCTIONAL_BOUNDED means named tests only, never every catalog acceptance clause or system timing.',
 'RX/TX FIRs use actual custom RTL; not silently represented as AMD FIR Compiler IP.',
 'DDS uses generated sine/cosine ROM; no AMD DDS IP claim.',
 'CRC is in the record serializer, not an extra RAM pre-read port.',
 'CSR aliases cover implemented register subset; matrix/calibration/AWG transport integration remains separately tracked.',
 'Coefficients reload bridge is independently implemented; fixed-coefficient primary FIR has no runtime reload endpoint.',
 'Optional PL fine analyzer is absent; physical RF binding and board tests remain uncompleted.'])
(ROOT/'reports/module_coverage.json').write_text(json.dumps(report,indent=2)+'\n')
lines=['# Design catalog implementation coverage','', 'File aliases below avoid counting the same implemented function twice. Functional tests are bounded evidence; this is not complete-system acceptance.','', '| Catalog module | Scope | State | RTL |','|---|---|---|---|']
for r in rows:lines.append('| '+r['name']+' | '+r['scope']+' | '+r['status']+' | '+', '.join(r['files'])+' |')
lines+=['','## Remaining integration boundaries','']+['- '+x for x in report['caveats']]
(ROOT/'reports/module_coverage.md').write_text('\n'.join(lines)+'\n')
print('Catalog report:',len(rows),'responsibilities; system integration remains explicit.')
