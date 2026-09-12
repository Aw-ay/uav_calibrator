"""Summarize actual routed DSP OOC evidence without elevating fixture I/O to a board claim."""
from pathlib import Path
import hashlib,json,re
ROOT=Path(__file__).resolve().parents[1]
rows=[]
for top in ['rx_cal_executor','target_complex_operator','fractional_delay_profile','tx_channel_router','tx_processing_chain']:
    folder=ROOT/'reports/calibration_timing'/top if top!='tx_processing_chain' else ROOT/'reports/tx_chain_registered_timing'
    record={'module':top,'vivado':'2025.2','part':'xczu27dr-fsve1156-2-i','period_ns':8.0,'scope':'real registered launch/capture OOC; external fixture ports unconstrained; not board or full-system timing'}
    timing=folder/'timing.rpt'
    if not timing.exists():record['status']='NOT_RUN'
    else:
        data=timing.read_text()
        match=re.search(r'WNS\(ns\).*?\n\s*-+[^\n]*\n\s*([-\d.]+)\s+([-\d.]+)\s+(\d+)\s+(\d+)\s+([-\d.]+)\s+([-\d.]+)',data,re.S)
        if match:
            record.update(dict(zip(['wns_ns','tns_ns','setup_failing_endpoints','setup_total_endpoints','whs_ns','ths_ns'],[float(v) for v in match.groups()])))
            record['status']='ROUTED_INTERNAL_TIMING_PASS' if record['wns_ns']>=0 and record['whs_ns']>=0 else 'ROUTED_TIMING_FAIL'
        else:record['status']='REPORT_PARSE_REQUIRES_REVIEW'
        check=(folder/'check_timing.rpt').read_text() if (folder/'check_timing.rpt').exists() else ''
        for key in ['no_clock','unconstrained_internal_endpoints','no_input_delay','no_output_delay']:
            cm=re.search(r'checking '+key+r' \((\d+)\)',check)
            record[key]=int(cm.group(1)) if cm else None
        if record['no_clock']!=0 or record['unconstrained_internal_endpoints']!=0:
            record['status']='TIMING_COVERAGE_REQUIRES_REVIEW'
        route=(folder/'route_status.rpt').read_text() if (folder/'route_status.rpt').exists() else ''
        rm=re.search(r'nets with routing errors\.*\s*:\s*(\d+)',route)
        record['routing_errors']=int(rm.group(1)) if rm else None
        if record['routing_errors']!=0:record['status']='ROUTING_REQUIRES_REVIEW'
        util=(folder/'utilization.rpt').read_text() if (folder/'utilization.rpt').exists() else ''
        record['fixture_inclusive_resources']={}
        for resource in ['CLB LUTs','CLB Registers','Block RAM Tile','DSPs']:
            um=re.search(r'\| '+resource+r'\s*\|\s*(\d+)',util)
            if um:record['fixture_inclusive_resources'][resource]=int(um.group(1))
        dcp=folder/'route.dcp'  
        if dcp.exists():record['dcp_sha256']=hashlib.sha256(dcp.read_bytes()).hexdigest()
        record['reports']={f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in folder.glob('*.rpt')}
    rows.append(record)
(ROOT/'reports/calibration_timing_summary.json').write_text(json.dumps(rows,indent=2)+'\n')
for row in rows:print(row['module'],row['status'],row.get('wns_ns'),row.get('whs_ns'))
