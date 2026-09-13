"""Current baseline assertions. No Vivado/RTL/hardware claims."""
from pathlib import Path
import json, unittest
ROOT=Path(__file__).resolve().parents[1]
def load(n): return json.loads((ROOT/'contracts'/f'{n}.json').read_text(encoding='utf-8'))
class MergeContract(unittest.TestCase):
    def test_revision(self): self.assertTrue(load('system_contract')['schema_version'].startswith('0.5'))
    def test_rates(self):
        r=load('system_contract')['rates']
        self.assertEqual([r[k] for k in ['clk_rf_hz','core_complex_hz','pl_decimation','canonical_input_complex_spc','gsc_increment_per_rf_clock']], [125000000,125000000,4,4,4])
        self.assertEqual(r['rfdc_decimation'],8)
        self.assertEqual(r['usable_total_bandwidth_hz'],100000000)
    def test_fir_clock(self):
        self.assertEqual(load('fir_plan')['clock_domain']['interface_hz'],125000000)
        self.assertEqual(load('fir_plan')['clock_domain'].get('compute_hz'),125000000)
    def test_capture_dimensions(self):
        c=load('system_contract')['capture']
        self.assertEqual((c['samples_per_bank'],c['initial_bank_count'],c['raw_bytes_initial']),(16384,4,2097152))
        self.assertEqual(c['continuous_filtered_bytes_per_second'],4000000000)
    def test_DMA_not_changed_to125(self):
        ip=next(i for i in load('amd_ip_targets')['ips'] if i['id']=='DMA')['configuration']
        self.assertEqual(ip['data_clock_hz'],200000000)
        self.assertEqual(ip['c_include_mm2s'],0)
        self.assertEqual(ip['c_m_axi_s2mm_data_width'],128)
    def test_frame(self):
        f=load('frame_format')
        self.assertEqual(f['payload']['max_samples'],16384)
        self.assertEqual(f['max_record_bytes_with_trailer'],131216)
        self.assertEqual(f['dma_slot_bytes_proposed'],262144)
    def test_filter_modules(self):
        mods=load('module_catalog')['modules'];names={m['name'] for m in mods}
        self.assertIn('rx_decim4_wrapper',names);self.assertIn('tx_interp4_wrapper',names)
        self.assertNotIn('sample_rate_gearbox',names)
        self.assertTrue(all('clk_fir' not in m['clocks'] for m in mods))
    def test_no_fixed_bank_roles(self):
        p=ROOT/'contracts/bank_contract.json';self.assertTrue(p.exists(),'bank contract must be merged')
        if p.exists():
            b=load('bank_contract');self.assertFalse(b['fixed_roles_by_bank_id']);self.assertTrue(b['pretrigger']['broadcast_to_all_mutable_available_banks'])
    def test_board_safety(self):
        s=load('system_contract');self.assertEqual(s['board'].get('design_target_silicon'),'ZU27DR');self.assertIsNone(s['board']['vivado_part_string'])
        self.assertFalse(s['implementation_authorized']);self.assertIsNone(s['board']['selected'])
    def test_unique_verification_ids(self):
        ids=[t['id'] for t in load('verification_matrix')['tests']];self.assertEqual(len(ids),len(set(ids)))
    def test_aux_flush_and_independence(self):
        c=load('channel_roles');sw=c['aux_input_switch'];self.assertFalse(sw['pause_primary_capture']);self.assertFalse(sw['stop_adc_ddc_fir'])
        self.assertEqual(sw.get('pl_flush_samples_min'),42)
    def test_resource_scope(self):
        p=ROOT/'contracts/resource_budget.json';self.assertTrue(p.exists(),'budget must be active, not only prose')
        if p.exists():
            r=load('resource_budget');self.assertEqual(r['fir_dsp_optimized'],1536);self.assertEqual(r['simultaneous_target_engines'],1)
    def test_record_policy(self):
        p=ROOT/'contracts/record_policy.json';self.assertTrue(p.exists())
        if p.exists():
            d=load('record_policy');self.assertEqual(d['default_mode'],'SELECTED_HV');self.assertEqual(d['dma']['cyclic_mode'],False)
if __name__=='__main__': unittest.main()
