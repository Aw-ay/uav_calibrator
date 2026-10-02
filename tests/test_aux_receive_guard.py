from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
sources=['rtl/frontend/'+n+'.sv' for n in ['rfdc_stream_adapter','native_overload_monitor','fir_quantize','fir_rx_hb19','fir_rx_fir75','fir_rx_lane','calibrator_receive_frontend']]
sources+=['rtl/control/aux_source_controller.sv','rtl/frontend/aux_receive_guard.sv','tb/system/tb_aux_receive_guard.sv']
with tempfile.TemporaryDirectory() as tmp:
    out=str(Path(tmp)/'sim')
    p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_aux_receive_guard','-o',out,*sources],cwd=ROOT,capture_output=True,text=True)
    assert p.returncode==0,p.stdout+p.stderr
    p=subprocess.run(['C:/iverilog/bin/vvp.exe',out],cwd=ROOT,capture_output=True,text=True,timeout=60)
    (ROOT/'reports/aux_receive_guard.log').write_text(p.stdout+p.stderr)
    assert p.returncode==0 and 'PASS AUX_RECEIVE_GUARD' in p.stdout,p.stdout+p.stderr
    print(p.stdout)
