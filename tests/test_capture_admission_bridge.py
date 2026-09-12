from pathlib import Path
import subprocess,tempfile,sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from frame_codec import pack_header,encode_frame
metadata=dict(format_id=7,pulse_id=321,config_id=91,source_role=1,quality_flags=4)
template=pack_header(metadata)
expected=[]
for g in range(3):
 m=dict(metadata,stream_group_id=g+1,physical_adc_mask=0x11<<g,range_id=g+1,channel_mask=3,gsc_first=3960)
 h=bytearray(encode_frame(m,[(0,0,0,0)]*7,trailer=True)[:128]);h[112:116]=bytes(4);expected.append(h)
with tempfile.TemporaryDirectory() as tmp:
 tb=Path(tmp)/'tb.sv'
 tb.write_text("""`timescale 1ns/1ps
module tb_capture_admission_bridge;
reg clk=0;always #4 clk=~clk;reg rst=1,in_valid=0,out_ready=0;
wire in_ready,out_valid;reg [255:0] in_key=256'h123,in_noise=256'h234;
reg [1023:0] in_config=1024'h345,in_metadata;
reg [5:0] in_bank_ids=6'h24,in_bad_channels=0;reg [191:0] in_generations=192'h456;
reg [191:0] in_start_seq={64'd990,64'd990,64'd990};reg [44:0] in_sample_count={15'd7,15'd7,15'd7};
reg [63:0] in_onset_seq=1000,in_onset_gsc=4000;reg in_want_replay=1;
wire [255:0] out_key,out_noise;wire [1023:0] out_config;wire [3071:0] out_headers;
wire [5:0] out_bank_ids,out_bad_channels;wire [191:0] out_generations;
wire out_want_replay,header_error;wire idle;
capture_admission_bridge dut(.*);
task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
initial begin in_metadata=1024'h"""+template[::-1].hex()+""";tick();rst=0;in_valid=1;tick();in_valid=0;in_config=0;in_noise=0;
while(!out_valid)tick();
if(out_config!=1024'h345||out_noise!=256'h234||out_key!=256'h123||out_bank_ids!=6'h24||!out_want_replay||header_error)$fatal(1,"frozen context");
if(out_headers!==3072'h"""+b''.join(expected)[::-1].hex()+""")$fatal(1,"header byte mismatch");
repeat(3)begin tick();if(!out_valid||idle||in_ready)$fatal(1,"backpressure ownership");end
out_ready=1;tick();out_ready=0;if(!idle)$fatal(1,"drain");
in_sample_count=0;in_valid=1;tick();in_valid=0;while(!out_valid)tick();
if(!header_error||out_bad_channels!=63)$fatal(1,"bad header must force qualification discard");
out_ready=1;tick();if(!idle)$fatal(1,"error drain");
$display("PASS capture admission bridge frozen metadata actual headers error drain");$finish;end
initial begin #10000;$fatal(1,"watchdog");end
endmodule""")
 sim=str(Path(tmp)/'sim')
 p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_capture_admission_bridge','-o',sim,'rtl/generated/calibrator_contract_pkg.sv','rtl/capture/frame_header_builder.sv','rtl/capture/capture_admission_bridge.sv',str(tb)],cwd=ROOT,capture_output=True,text=True)
 assert p.returncode==0,p.stdout+p.stderr
 p=subprocess.run(['C:/iverilog/bin/vvp.exe',sim],cwd=ROOT,capture_output=True,text=True)
 (ROOT/'reports/capture_admission_bridge.log').write_text(p.stdout+p.stderr)
 assert p.returncode==0 and 'PASS capture admission bridge' in p.stdout,p.stdout+p.stderr
 print(p.stdout)
