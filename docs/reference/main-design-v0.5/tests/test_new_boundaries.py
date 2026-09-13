from pathlib import Path
import json, unittest, hashlib, csv, math
import numpy as np
from scipy import signal
from models import numeric_model as m
from models.ring_model import Bank, select_range
R=Path(__file__).resolve().parents[1]

class Boundaries(unittest.TestCase):
    def test_queue_rejects_200us_bank_overflow_even_large_ddr_slot(self):
        with self.assertRaisesRegex(ValueError,'bank'):
            m.packet_queue(duration=.02,fs_out=125e6,prf=1000,window=200e-6,groups=4,banks=4,dma_rate=2.4e9,storage_rate=2e9,slots=512)
    def test_complete_tx_tail_is_available(self):
        self.assertTrue(hasattr(m,'run_fixed_tx_complete'),'TX tail wrapper must be present')
        if not hasattr(m,'run_fixed_tx_complete'):return
        st=m.recommended_stages();x=np.zeros((256,4),np.int64);x[-1,0]=10000
        y,stat=m.run_fixed_tx_complete(x,st)
        self.assertEqual(len(y),(256+42)*4)
        padded=np.pad(x,((0,42),(0,0)))
        want,_=m.run_fixed_tx(padded,st);np.testing.assert_array_equal(y,want)
        self.assertGreater(np.count_nonzero(y[1024:,0]),0)
        self.assertEqual(stat['pl_tail_zero_inputs'],42)
    def test_coefficients_loaded_from_frozen_files(self):
        for k,st in enumerate(m.recommended_stages(),1):
            with (R/'filters'/f'RX_STAGE{k}.csv').open() as f:q=[int(r['integer']) for r in csv.DictReader(f)]
            np.testing.assert_array_equal(st['q'],q)
    def test_four_banks_broadcast_reserve_freeze_and_reuse(self):
        bs=[Bank(64,4,2,group=1,bank=i) for i in range(4)]
        def feed(stop):
            for s in range(bs[0].latest+1,stop):
                for b in bs:b.tick(s,s+1000)
        feed(31)
        for b in bs:self.assertEqual(b.state,'ARMED')
        token0=bs[0].reserve(29);bs[0].set_end(45);feed(45);bs[0].finalize(['record','replay'])
        old=bs[0].words().copy()
        feed(71);bs[1].reserve(69);bs[1].set_end(82);feed(82);bs[1].finalize(['record'])
        feed(101);bs[2].reserve(99);bs[2].set_end(112)
        self.assertEqual([b.state for b in bs],['FROZEN','FROZEN','CAPTURE','ARMED'])
        self.assertEqual(bs[0].words(),old)
        self.assertEqual(bs[2].data[100%64],1100);self.assertEqual(bs[3].data[100%64],1100)
        self.assertTrue(bs[0].ack(token0,'record'));self.assertEqual(bs[0].state,'FROZEN')
        self.assertTrue(bs[0].ack(token0,'replay'));self.assertEqual(bs[0].state,'ARMING')
        feed(110);self.assertEqual(bs[0].state,'ARMED')
        newtoken=bs[0].reserve(108);self.assertNotEqual(newtoken,token0)
        self.assertFalse(bs[0].ack(token0,'record'))
    def test_bank_role_permutation_has_same_results(self):
        for chosen in range(4):
            bs=[Bank(64,4,1,group=0,bank=i) for i in range(4)]
            for s in range(30):
                for b in bs:b.tick(s,s)
            bs[chosen].reserve(28);bs[chosen].set_end(40)
            for s in range(30,40):
                for b in bs:b.tick(s,s)
            bs[chosen].finalize(['record'])
            self.assertEqual(bs[chosen].words(),list(range(24,40)))
            self.assertTrue(all(b.state=='ARMED' for i,b in enumerate(bs) if i!=chosen))
    def test_unselected_captures_rearm_and_selected_holds(self):
        bs=[Bank(64,4,2,group=g,bank=0) for g in range(3)]
        for s in range(30):
            for b in bs:b.tick(s,s+1000*b.group)
        for b in bs:b.reserve(28);b.set_end(40)
        for s in range(30,40):
            for b in bs:b.tick(s,s+1000*b.group)
        choice=select_range([(False,True),(True,True),(True,True)])
        self.assertEqual(choice,1)
        for g,b in enumerate(bs):b.finalize(['record','replay'] if g==choice else [])
        self.assertEqual([b.state for b in bs],['ARMING','FROZEN','ARMING'])
    def test_dma_services_after_window_not_onset(self):
        r=m.packet_queue(duration=.0001,fs_out=125e6,prf=1000,window=120e-6,groups=4,banks=4,dma_rate=2.4e9,storage_rate=20e9,slots=512)
        self.assertEqual(r['accepted_records'],4)
        # Four records, each120144bytes; 3 intervening2us gaps; first ready at120us.
        expected=.00012+4*120144/2.4e9+3*2e-6
        self.assertAlmostEqual(r['max_dma_wait_and_transfer_s']+.00012,expected,places=12)

class ContractDetails(unittest.TestCase):
    def load(self,n):return json.loads((R/'contracts'/f'{n}.json').read_text())
    def test_bank_ports_and_no_movable_roles(self):
        b=self.load('bank_contract')
        self.assertEqual(b['ports']['A']['width']*b['ports']['A']['depth'],b['ports']['B']['width']*b['ports']['B']['depth'])
        self.assertFalse(b['fixed_roles_by_bank_id']);self.assertFalse(b['bank_to_bank_iq_copy'])
        self.assertIn('FROZEN_PENDING',b['states']);self.assertEqual(b['sample_count_bits'],15)
    def test_frame_offsets_and_size(self):
        f=self.load('frame_format');used=set()
        for x in f['header']:
            b=set(range(x['offset_bytes'],x['offset_bytes']+x['size_bytes']))
            self.assertFalse(used&b,x['name']);used|=b
        self.assertEqual(used,set(range(128)))
        self.assertEqual(f['abi_version'],5)
    def test_descriptor_offsets_and_bounds(self):
        d=self.load('replay_contract')
        for key in ['capture_descriptor','replay_task','return_token']:
            used=set()
            for x in d[key]['fields']:
                b=set(range(x['offset_bytes'],x['offset_bytes']+x['size_bytes']))
                self.assertFalse(used&b);self.assertLessEqual(max(b)+1,d[key]['size_bytes']);used|=b
    def test_register_overlap_and_snapshot_bounds(self):
        r=self.load('register_map');used=set()
        for x in r['registers']:
            a=int(x['offset_hex'],16);b=set(range(a,a+4));self.assertEqual(a%4,0);self.assertFalse(used&b);used|=b
        t=r['bank_snapshot_table'];a=int(t['base_hex'],16);b=set(range(a,a+t['stride_bytes']*t['rows']))
        self.assertFalse(used&b);self.assertLessEqual(max(b),65535)
    def test_core_gsc_module_updated(self):
        g=next(x for x in self.load('module_catalog')['modules'] if x['name']=='global_sample_time')
        self.assertNotIn('加8',g['responsibility']);self.assertIn('加4',g['responsibility'])
    def test_gen1_tx_not_gen3(self):
        p=self.load('system_contract')['tx_profile'];self.assertEqual(p['rfdc_interpolation'],8);self.assertEqual(p['dac_real_sample_hz'],4000000000)
        self.assertEqual(p['native_iq_words_per_beat_target'],8);self.assertEqual(p['native_bits_per_dac_stream_target'],128)
    def test_rates_all_four_stages(self):
        f=self.load('fir_plan')
        for st in f['rx_stages']+f['tx_stages']:
            self.assertEqual(st['clock_hz']*st['input_complex_spc'],st['input_sample_hz'])
            self.assertEqual(st['clock_hz']*st['output_complex_spc'],st['output_sample_hz'])
        self.assertEqual([x['taps'] for x in f['rx_stages']],[19,75]);self.assertEqual([x['taps'] for x in f['tx_stages']],[75,19])
    def test_ABI_constant_field_meanings(self):
        h={f['name']:f['meaning'] for f in self.load('frame_format')['header']}
        self.assertIn('125000000',h['sample_rate_num']);self.assertIn('4',h['sample_stride_ticks']);self.assertIn('16384',h['sample_count'])
    def test_two_phase_bank_read_and_release(self):
        b=self.load('bank_contract');self.assertTrue(b['ownership']['reserve_before_descriptor_publish']);self.assertEqual(b['ownership']['generation_bits'],64)
        self.assertEqual(b['primary_admission']['atomic_all_or_none'],True)
    def test_gain_order_is_not_fabricated(self):
        self.assertIsNone(self.load('range_selection')['gain_order_descending'])
        self.assertIsNone(self.load('bank_contract')['pretrigger']['max_detector_latency_samples'])
    def test_resource_sum_and_scenarios(self):
        r=self.load('resource_budget');self.assertEqual(sum(i['dsp'] for i in r['dsp_rows']),1932)
        self.assertEqual([i['with_25pct_allowance'] for i in r['fir_sensitivity']],[2415,2815,4295,5015])
    def test_memory_slot_not_bank_capacity(self):
        d=self.load('record_policy')['dma'];self.assertEqual(d['slot_bytes']*d['slots'],d['pool_bytes']);self.assertGreater(d['slot_bytes'],d['max_actual_record_bytes'])
    def test_hardware_acceptance_not_claimed(self):
        self.assertTrue(all(t['status']=='NOT_RUN' for t in self.load('verification_matrix')['tests']))
        self.assertTrue(all(t['status']=='DESIGN_ONLY' for t in self.load('module_catalog')['modules']))
if __name__=='__main__':unittest.main()
