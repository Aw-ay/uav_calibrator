from pathlib import Path
import subprocess,tempfile,sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from frame_codec import encode_frame,pack_header
cases=[]
for g in range(1,5):
 for count in [1,7,16384]:
  md=dict(format_id=7,stream_group_id=g,physical_adc_mask=0x11<<(g-1),channel_mask=3,range_id=g,source_role=1,config_id=91,pulse_id=456,record_sequence=123,epoch_id=9,gsc_first=40000+60*4,scale_id=8,rx_cal_id=19,source_epoch=10,rf_center_hz=9500000000,nco_frequency_hz=-10000000,quality_flags=512)
  expected=bytearray(encode_frame(md,[(0,0,0,0)]*count,trailer=True)[:128]);expected[112:116]=bytes(4)
  template=pack_header(md);template[68:72]=(516).to_bytes(4,'little')
  cases.append((template.hex(),expected.hex(),count))
with tempfile.TemporaryDirectory() as tmp:
 tb=Path(tmp)/'tb.sv'
 checks=[]
 for template,expected,count in cases:
  checks.append(f"template_header=1024'h{bytes.fromhex(template)[::-1].hex()};sample_count=15'd{count};request_valid=1;tick();request_valid=0;if(!result_valid||rejected||header_data!==1024'h{bytes.fromhex(expected)[::-1].hex()})$fatal(1,\"header bytes\");tick();if(header_data!==1024'h{bytes.fromhex(expected)[::-1].hex()})$fatal(1,\"stall stability\");result_ready=1;tick();result_ready=0;")
 tb.write_text("""`timescale 1ns/1ps
module tb_frame_header_builder;
reg clk=0;always #4 clk=~clk;reg rst=1,request_valid=0,result_ready=0;
reg [1023:0] template_header=0;reg [14:0] sample_count=0;
reg [63:0] window_start_seq=1060,time_origin_seq=1000,time_origin_gsc=40000;
wire request_ready,result_valid,rejected;wire [1023:0] header_data;
frame_header_builder dut(.*);
task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
initial begin tick();rst=0;
"""+'\n'.join(checks)+"""
sample_count=0;request_valid=1;tick();if(!rejected||result_valid)$fatal(1,"zero count");
sample_count=1;window_start_seq=999;tick();if(rejected||!result_valid||header_data[320+:64]!=39996)$fatal(1,"pretrigger time mapping");
request_valid=0;result_ready=1;tick();result_ready=0;request_valid=1;time_origin_gsc=3;tick();if(!rejected||result_valid)$fatal(1,"GSC underflow");
window_start_seq=1060;time_origin_gsc=64'hfffffffffffffff0;tick();if(!rejected||result_valid)$fatal(1,"GSC overflow");
$display("PASS frame header builder independent ABI bytes bounds stall");$finish;end
initial begin #10000;$fatal(1,"watchdog");end
endmodule""")
 sim=str(Path(tmp)/'sim')
 p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-s','tb_frame_header_builder','-o',sim,'rtl/generated/calibrator_contract_pkg.sv','rtl/capture/frame_header_builder.sv',str(tb)],cwd=ROOT,capture_output=True,text=True)
 assert p.returncode==0,p.stdout+p.stderr
 p=subprocess.run(['C:/iverilog/bin/vvp.exe',sim],cwd=ROOT,capture_output=True,text=True)
 (ROOT/'reports/frame_header_builder.log').write_text(p.stdout+p.stderr)
 assert p.returncode==0 and 'PASS frame header builder' in p.stdout,p.stdout+p.stderr
 print(p.stdout)
