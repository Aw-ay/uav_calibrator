from pathlib import Path
import subprocess
ROOT=Path(__file__).resolve().parents[1]
SOURCES=['rtl/control/rf_safety_interlock.sv','rtl/source/dds_burst_control.sv','rtl/source/dds_nco_wrapper.sv','rtl/source/awg_reader.sv','rtl/source/awg_load_cdc_wrapper.sv','rtl/source/generated_tx_sources.sv','rtl/source/tx_source_mux.sv','rtl/backend/tx_channel_router.sv','rtl/arithmetic/fixed_round_sat.sv','rtl/arithmetic/complex_cal_core.sv','rtl/arithmetic/tx_cal_executor.sv','rtl/frontend/fir_quantize.sv','rtl/backend/fir_tx_fir75.sv','rtl/backend/fir_tx_hb19.sv','rtl/backend/fir_tx_lane.sv','rtl/backend/dac_stream_adapter.sv','rtl/backend/tx_processing_chain.sv','rtl/top/calibrator_transmit_system.sv']
def run():
    assert (ROOT/SOURCES[-1]).exists(),'NOT_IMPLEMENTED calibrator_transmit_system'
    out=ROOT/'reports/tb_calibrator_transmit_system.vvp'
    p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_calibrator_transmit_system','-o',str(out),*[str(ROOT/f) for f in SOURCES],str(ROOT/'tb/system/tb_calibrator_transmit_system.sv')],capture_output=True,text=True,timeout=120)
    assert p.returncode==0,p.stdout+p.stderr
    p=subprocess.run(['C:/iverilog/bin/vvp.exe',str(out)],capture_output=True,text=True,timeout=120)
    (ROOT/'reports/tb_calibrator_transmit_system.log').write_text(p.stdout+p.stderr)
    assert p.returncode==0 and 'PASS' in p.stdout,p.stdout+p.stderr
    print(p.stdout)
if __name__=='__main__':run()
