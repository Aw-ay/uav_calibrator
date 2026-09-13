from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
SOURCES=['rtl/source/tx_source_mux.sv','rtl/backend/tx_channel_router.sv','rtl/arithmetic/fixed_round_sat.sv','rtl/arithmetic/complex_cal_core.sv','rtl/arithmetic/tx_cal_executor.sv','rtl/frontend/fir_quantize.sv','rtl/backend/fir_tx_fir75.sv','rtl/backend/fir_tx_hb19.sv','rtl/backend/fir_tx_lane.sv','rtl/backend/dac_stream_adapter.sv','rtl/backend/tx_processing_chain.sv','tb/system/tb_tx_tail_status.sv']
with tempfile.TemporaryDirectory() as tmp:
    sim=str(Path(tmp)/'sim')
    p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_tx_tail_status','-o',sim,*SOURCES],cwd=ROOT,capture_output=True,text=True,timeout=60)
    assert p.returncode==0,p.stdout+p.stderr
    p=subprocess.run(['C:/iverilog/bin/vvp.exe',sim],cwd=ROOT,capture_output=True,text=True,timeout=60)
    (ROOT/'reports/tx_tail_status.log').write_text(p.stdout+p.stderr)
    assert p.returncode==0 and 'PASS TX tail status' in p.stdout,p.stdout+p.stderr
    print(p.stdout)
