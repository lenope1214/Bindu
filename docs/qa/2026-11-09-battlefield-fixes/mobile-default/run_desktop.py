#!/usr/bin/env python3
from pathlib import Path
import hashlib,importlib.util,json,shutil,tempfile,uuid
ROOT=Path(__file__).resolve().parents[4];HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('helper',ROOT/'docs/qa/2026-11-09-battlefield-fixes/performance/guard-range/run_replay.py');h=importlib.util.module_from_spec(spec);spec.loader.exec_module(h)
out=HERE/'desktop';out.mkdir();record={'scope':'Headless actual macOS initial Meta/default/config reads; no desktop GUI claim'}
with tempfile.TemporaryDirectory(prefix='bindu-mobile-default-desktop-') as d:
 project=Path(d);name='BinduToolsMobileDefault'+uuid.uuid4().hex;data=Path.home()/'Library/Application Support/Godot/app_userdata'/name;h.copy_project(project,name);shutil.copy2(HERE/'desktop_default.gd',project/'qa_default.gd');record['source_hashes']={str(p.relative_to(project)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (project/'scripts').rglob('*.gd')}
 try:
  h.checked([h.GODOT,'--headless','--import','--path',d],out/'import.log');text=h.checked([h.GODOT,'--headless','--path',d,'-s','qa_default.gd','--',str(out/'state.json')],out/'run.log');assert 'DESKTOP DEFAULT assertions=8 failures=0' in text;record['passed']=True
 finally:shutil.rmtree(data,ignore_errors=True)
record['project_removed']=not project.exists();record['isolated_save_removed']=not data.exists();(out/'run.json').write_text(json.dumps(record,indent=2)+'\n');print('desktop default/config8passed')
