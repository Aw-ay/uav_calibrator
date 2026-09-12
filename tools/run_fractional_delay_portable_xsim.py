"""Validate the embedded profile in a real2025.2 XSim project outside repository cwd."""
from pathlib import Path
import subprocess,json,hashlib
ROOT=Path(__file__).resolve().parents[1]
p=subprocess.run(['python',str(ROOT/'tests/test_fractional_delay_profile.py')],cwd=ROOT,capture_output=True,text=True,timeout=180)
assert p.returncode==0,p.stdout+p.stderr
print(p.stdout)
work=ROOT/'build/fd_portable_launcher';work.mkdir(exist_ok=True)
log=ROOT/'reports/fd_portable_xsim_after.log'
p=subprocess.run(['C:/AMDDesignTools/2025.2/Vivado/bin/vivado.bat','-mode','batch','-source',str(ROOT/'hw/tcl/fractional_delay_portable_xsim.tcl'),'-log',str(log),'-journal',str(ROOT/'reports/fd_portable_xsim_after.jou')],cwd=work,capture_output=True,text=True,timeout=600)
output=p.stdout+p.stderr
(ROOT/'reports/fd_portable_xsim_console.log').write_text(output)
passed=p.returncode==0 and 'PASS fractional profile: all256 phases,36352 integer vectors' in output and 'Fatal:' not in output and 'FATAL:' not in output and 'cannot be opened' not in output
profile=json.loads((ROOT/'contracts/fractional_delay_profile.json').read_text())
report={'status':'PASS' if passed else 'FAIL','vivado':'2025.2','exit_code':p.returncode,'launcher_workdir':str(work),'simulation_workdir':str(ROOT/'build/fd_portable_xsim/fd_portable.sim/sim_1/behav/xsim'),'coefficient_mem_added_to_project':False,'coefficients_sha256':profile['coefficient_sha256'],'embedded_rom_source_sha256':hashlib.sha256((ROOT/'rtl/generated/fractional_delay_coeff_rom.sv').read_bytes()).hexdigest(),'vectors':36352,'phases':256,'log':str(log)}
(ROOT/'reports/fd_portable_xsim_result.json').write_text(json.dumps(report,indent=2)+'\n')
assert passed,output
print('PASS realVivado2025.2 XSim portable embeddedROM, all256phases/36352vectors, no staged coefficientmem')
