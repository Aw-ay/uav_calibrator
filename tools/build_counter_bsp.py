"""Run with Vitis 2025.2 -s; generates BSP from counter candidate, no hardware."""
from pathlib import Path
import vitis
import os
r=Path(__file__).resolve().parents[1]
xsa=r/'build/platform_counter_stage26_r4/platform_counter.xsa'
assert xsa.is_file(),xsa
client=vitis.create_client(port=int(os.environ["CAL_VITIS_PORT"]) if "CAL_VITIS_PORT" in os.environ else None)
try:
 workspace=r/('build/counter_application_2025_2' if (r/'build/counter_vitis_2025_2/counter_platform/export/counter_platform/counter_platform.xpfm').exists() else 'build/counter_vitis_2025_2')
 client.set_workspace(str(workspace))
 if not (r/'build/counter_vitis_2025_2/counter_platform/export/counter_platform/counter_platform.xpfm').exists():
  p=client.create_platform_component(name='counter_platform',hw_design=str(xsa),os='standalone',cpu='psu_cortexa53_0',domain_name='counter_domain',no_boot_bsp=True)
  p.build()
 assert (r/'build/counter_vitis_2025_2/counter_platform/export/counter_platform/counter_platform.xpfm').is_file(), 'BSP export missing'
 print('COUNTER_BSP_BUILD_FINISHED_NO_HARDWARE_TEST')
 workspace=r/'build/counter_application_2025_2'
 client.set_workspace(str(workspace))
 xpfm=r/'build/counter_vitis_2025_2/counter_platform/export/counter_platform/counter_platform.xpfm'
 client.add_platform_repos(str(xpfm.parent))
 app=client.get_component('counter_receive') if (workspace/'counter_receive').exists() else client.create_app_component(name='counter_receive',platform=str(xpfm),domain='counter_domain',template='empty_application')
 app.import_files(from_loc=str(r/'sw/baremetal'),files=['sg_counter_rx.c','sg_counter_rx.h','counter_main.c'],dest_dir_in_cmp='src/baremetal')
 app.import_files(from_loc=str(r/'sw/common'),files=['dma_slots.c','dma_slots.h'],dest_dir_in_cmp='src/common')
 status=app.build()
 elfs=list((workspace/"counter_receive").rglob("counter_receive.elf"))
 assert elfs and max(p.stat().st_mtime for p in elfs)>=max(p.stat().st_mtime for p in (workspace/"counter_receive/src").rglob("*.c")),f"No fresh ELF; build status={status}"
 print('COUNTER_ELF_BUILD_FINISHED_NO_HARDWARE_TEST')
finally:vitis.dispose()
