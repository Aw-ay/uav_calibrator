"""Offline stage26 proof; deliberately does not claim hardware acceptance."""
from pathlib import Path
import subprocess,json,hashlib,re,sys
r=Path(__file__).resolve().parents[1];out=r/'reports/module_stage26';out.mkdir(exist_ok=True)
results=[]
def run(args):
 p=subprocess.run([str(a) for a in args],cwd=r,capture_output=True,text=True,timeout=90)
 results.append(dict(command=[str(a) for a in args],exit_code=p.returncode,stdout=p.stdout,stderr=p.stderr));assert p.returncode==0,p.stdout+p.stderr;return p.stdout
for test in ['test_platform_counter_source.py','test_sg_counter_rx.py','test_platform_counter_xsa.py','test_ps_receive_core.py']:
 run([sys.executable,'tests/'+test])
run([sys.executable,'-m','unittest','discover','-s','tests','-p','test_contracts.py','-v'])
bin=Path('C:/AMDDesignTools/2025.2/gnu/aarch64/nt/aarch64-none/bin')
bsp=r/'build/counter_vitis_2025_2/counter_platform/export/counter_platform/sw/counter_domain'
app=r/'build/counter_application_2025_2/counter_receive'
obj=r/'build/sg_service_a53';obj.mkdir(exist_ok=True)
for f in ['baremetal/counter_main.c','baremetal/sg_counter_rx.c','common/dma_slots.c']:
 source=r/'sw'/f
 assert source.read_bytes().replace(b'\r\n',b'\n')==(app/'src'/f).read_bytes().replace(b'\r\n',b'\n'),f
 run([bin/'aarch64-none-elf-gcc.exe','-mcpu=cortex-a53','-DSDT','-std=c11','-ffreestanding','-O2','-Wall','-Wextra','-Werror','-isystem',bsp/'include','-c',source,'-o',obj/(source.stem+'.o')])
elf=app/'build/counter_receive.elf'
s=run([bin/'aarch64-none-elf-gdb.exe','-batch','-ex','file '+elf.as_posix(),'-ex','p/x &receiver.descriptors','-ex','p/x &receiver.buffers[0]','-ex','p/x &receiver.buffers[1]','-ex','p sizeof(receiver.descriptors)'])
values=re.findall(r'\$\d+ = (0x[0-9a-f]+|[0-9]+)',s);d,b0,b1,size=[int(v,0) for v in values]
assert d%0x200000==0 and size==0x200000 and d+size<=b0 and b1-b0==262144 and b1+262144<1<<40
assert 'COUNTER_ELF_BUILD_FINISHED_NO_HARDWARE_TEST' in (r/'reports/counter_repro_build_latest.log').read_text()
files=list((r/'rtl/platform').glob('*'))+list((r/'sw/baremetal').glob('*'))+[r/'sw/common/dma_slots.c',r/'sw/common/dma_slots.h',r/'hw/tcl/platform_create_counter.tcl',r/'hw/tcl/platform_export_counter.tcl',r/'hw/tcl/platform_ps_preset.tcl',r/'hw/tcl/stage26_counter_source.tcl',r/'hw/tcl/stage26_counter_tb.tcl',r/'tools/build_counter_bsp.py',r/'tools/build_counter_bsp.ps1',r/'contracts/counter_platform.json',r/'tb/system/tb_platform_counter_source.sv',elf,r/'build/platform_counter_stage26_r4/platform_counter.xsa']
files+=list((r/'tests/mocks/sg_dma').glob('*.h'))+[r/'tests/c/test_sg_counter_rx.c',bsp/'include/xparameters.h',bsp/'include/xaxidma.h',r/'build/counter_vitis_2025_2/counter_platform/psu_cortexa53_0/counter_domain/bsp/libsrc/axidma/src/xaxidma_g.c']
(out/'inputs.json').write_text(json.dumps({p.relative_to(r).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in files},indent=2))
(out/'offline_verification.json').write_text(json.dumps(dict(status='PASS_OFFLINE_ONLY',results=results,descriptor_base=d,descriptor_bytes=size,payload_bases=[b0,b1],hardware_connected=False),indent=2))
print('PASS stage26 offline RTL, SG service mocks, XSA, strict A53 BSP compile and linked ELF cache-region isolation')
