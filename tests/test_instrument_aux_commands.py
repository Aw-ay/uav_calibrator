from pathlib import Path
import subprocess,tempfile,sys,re
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tests'));sys.path.insert(0,str(ROOT/'tools'))
from test_calibrator_dataplane_system import sources,vectors
from frame_codec import decode_frame
directory=vectors()
tb=(ROOT/'tb/system/tb_calibrator_instrument_core.sv').read_text()
start=tb.index('  payload=saved_config;command(CMD_CONFIG,CONFIG_WORDS,3);')
stop=tb.index('\n end\n initial begin #100000',start)
tb=tb[:start]+'''
  payload=0;payload[31:0]=8;payload[95:32]=64'hfedcba9876543210;
  command(CMD_AUX_CAPTURE,3,4); // Unbound AUX must reject.
  aux_source_qualified=1;aux_context={32'd12,32'd11,32'd7,32'd2};
  repeat(100)@(negedge rf_clk);
  command(CMD_AUX_CAPTURE,3,0);command(CMD_AUX_CAPTURE,3,4);
  command(CMD_AUX_META_PEEK,0,0);
  begin : check_aux
   reg [767:0] meta,again;
   read_word(GW_RESULT);if(!value[0])$fatal(1,"missing AUX metadata");
   for(integer w=0;w<24;w=w+1)begin read_word(GW_RESULT+4+w*4);meta[w*32+:32]=value;end
   if(meta[84*8+:32]!=8||meta[40*8+:64]!=64'hfedcba9876543210||meta[88*8+:8]!=2)$fatal(1,"AUX sidecar fields");
   if(dut.d_replay_leased!=0)$fatal(1,"AUX acquired replay lease");
   m_axis_tready=1;command(CMD_RESET,0,0);
   command(CMD_AUX_META_PEEK,0,0);
   for(integer w=0;w<24;w=w+1)begin read_word(GW_RESULT+4+w*4);again[w*32+:32]=value;end
   if(again!==meta||frames!=1||completions!=1||dut.d_frozen!=0||dut.d_pending!=0)$fatal(1,"reset/metadata/RAW return");
   payload=0;payload[63:0]=meta[64+:64]+1;command(CMD_AUX_META_POP,2,4);
   payload[63:0]=meta[64+:64];command(CMD_AUX_META_POP,2,0);
   command(CMD_AUX_META_PEEK,0,0);read_word(GW_RESULT);if(value[0])$fatal(1,"AUX metadata POP");
  end
  $fclose(frame_file);$fclose(sample_file);
  $display("PASS instrument AUX PS commands actual native ADC FIR RAW reset metadata");$finish;
'''+tb[stop:]
tb=tb.replace('dut.group_data[63:0]','dut.group_data[255:192]')
permuted='--permuted' in sys.argv
if permuted:
    # Swap logical0/3 physical assignments: AUX H moves from physical3 to1.
    tb=tb.replace("24'hfa5681","24'hfa5283")
with tempfile.TemporaryDirectory() as tmp:
    path=Path(tmp)/'aux.sv';path.write_text(tb);sim=str(Path(tmp)/'sim')
    p=subprocess.run(['C:/iverilog/bin/iverilog.exe','-g2012','-Wall','-s','tb_calibrator_instrument_core','-o',sim,*sources,str(path)],cwd=ROOT,capture_output=True,text=True,timeout=120)
    assert p.returncode==0 and not any(x in p.stderr for x in ['implicit definition','dangling input','expects']),p.stdout+p.stderr
    p=subprocess.run(['C:/iverilog/bin/vvp.exe',sim,f'+ROOT={directory.as_posix()}'],cwd=ROOT,capture_output=True,text=True,timeout=240)
    (ROOT/'reports/instrument_aux_commands.log').write_text(p.stdout+p.stderr)
    assert p.returncode==0 and 'PASS instrument AUX PS commands' in p.stdout,p.stdout+p.stderr
    frame=bytes.fromhex((directory/'instrument_frame.hex').read_text());header,samples=decode_frame(frame)
    observed={int(seq):int(word,16).to_bytes(8,'little') for seq,gsc,word in (l.split() for l in (directory/'instrument_samples.txt').read_text().splitlines())}
    import struct
    start_seq=header['gsc_first']//4
    assert header['stream_group_id']==4 and header['source_role']==2 and len(samples)==8 and header['physical_adc_mask']==(0x82 if permuted else 0x88),header
    assert samples==[struct.unpack('<hhhh',observed[start_seq+n]) for n in range(8)]
    print(p.stdout)
    print('PASS independent AUX frame CRC, real FIR samples, metadata and actual upload return')
