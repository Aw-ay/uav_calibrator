from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]
def render():
    c=json.loads((ROOT/'contracts/calibration_table_format.json').read_text())
    dsp=json.loads((ROOT/'contracts/calibration_dsp_implementation.json').read_text())
    lines=['/* Generated; tools/generate_calibration_table_format.py */','#ifndef CALIBRATION_TABLE_FORMAT_H','#define CALIBRATION_TABLE_FORMAT_H',f"#define CAL_TABLE_BYTES {c['bytes']}u",f"#define CAL_TABLE_MAGIC {c['magic']}u",f"#define CAL_TABLE_VERSION {c['schema_version']}u"]
    for name,offset,width in c['fields']:
        lines += [f'#define CAL_TABLE_{name.upper()}_OFFSET {offset}u',f'#define CAL_TABLE_{name.upper()}_BYTES {width}u']
    for f in dsp['calibration_table']['fields']:
        lines += [f"#define CAL_PAYLOAD_{f['name'].upper()}_BIT {f['lsb']}u",f"#define CAL_PAYLOAD_{f['name'].upper()}_WIDTH {f['width']}u"]
    return '\n'.join(lines+['#endif',''])
if __name__=='__main__': (ROOT/'sw/common/include/calibration_table_format.h').write_text(render())
