from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as tmp:
    out=str(Path(tmp)/'sim')
    cmd=['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_command_gateway','-o',out,'rtl/generated/calibrator_contract_pkg.sv','rtl/generated/command_gateway_pkg.sv','rtl/control/cdc_mailbox.sv','rtl/control/command_gateway_axi.sv','tb/system/tb_command_gateway.sv']
    p=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True);assert p.returncode==0,p.stdout+p.stderr
    p=subprocess.run(['C:/iverilog/bin/vvp.exe',out],cwd=ROOT,capture_output=True,text=True,timeout=30)
    assert p.returncode==0 and 'PASS' in p.stdout,p.stdout+p.stderr
    print(p.stdout)
