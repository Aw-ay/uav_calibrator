"""The control-switch enum is not the data-record source enum."""
from pathlib import Path
import json
import unittest
R = Path(__file__).resolve().parents[1]
class SourceRoleMapping(unittest.TestCase):
    def test_aux_control_has_explicit_wire_mapping(self):
        c=json.loads((R/'contracts/channel_roles.json').read_text(encoding='utf-8'))
        m=c.get('source_role_encoding', {})
        self.assertEqual(m.get('aux_control_to_frame'), {'0':0,'1':2,'2':3})
        self.assertEqual(m.get('primary_external_frame_value'),1)
        f=json.loads((R/'contracts/frame_format.json').read_text(encoding='utf-8'))
        self.assertEqual(f.get('source_role_values'), {'0':'SAFE_UNKNOWN','1':'EXTERNAL_MEASUREMENT','2':'EXTERNAL_REDUNDANT','3':'RF_LOOPBACK'})
if __name__=='__main__': unittest.main()
