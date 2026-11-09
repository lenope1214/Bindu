#!/usr/bin/env python3
"""Existing card-reading and pause/use controls after moving the preview action."""
from pathlib import Path
import argparse,hashlib,importlib.util,json,re,shutil,tempfile,uuid
ROOT=Path(__file__).resolve().parents[4]
source=ROOT/'docs/qa/2026-11-09-battlefield-fixes/performance/guard-range/run_replay.py'
spec=importlib.util.spec_from_file_location('helper',source);h=importlib.util.module_from_spec(spec);spec.loader.exec_module(h)
parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,required=True);args=parser.parse_args();out=args.output.resolve();out.mkdir(parents=True,exist_ok=True);assert not any(out.iterdir());record={'scope':'macOS GUI virtual input; phone profile simulated; actual iOS separate','runs':{}}
with tempfile.TemporaryDirectory(prefix='bindu-reading-card-') as d:
 project=Path(d);name='BinduToolsReadingCard'+uuid.uuid4().hex;data=Path.home()/'Library/Application Support/Godot/app_userdata'/name;h.copy_project(project,name);(project/'override.cfg').write_text('[display]\nwindow/size/no_focus=true\nwindow/size/mode=1\n');record['source_sha256']={str(p.relative_to(project)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (project/'scripts').rglob('*.gd')}
 try:
  h.checked([h.GODOT,'--headless','--import','--path',d],out/'import.log')
  for kind in ['pc','phone']:
   case=out/kind;case.mkdir();text=h.checked([h.GODOT,'--audio-driver','Dummy','--path',d,'--resolution','852x393' if kind=='phone' else '1280x720','-s','tools/battlefield_preview_check.gd','--',str(case),'1.3',kind],case/'run.log');assert re.search(r'^BATTLEFIELD PREVIEW failures=0 ui=0$',text,re.M);record['runs'][kind]={'passed':True,'warnings':re.findall(r'^WARNING:[^\n]+',text,re.M)};print(kind,'PREVIEW passed',flush=True)
 finally:shutil.rmtree(data,ignore_errors=True)
record['project_removed']=not project.exists();record['isolated_save_removed']=not data.exists();(out/'run.json').write_text(json.dumps(record,indent=2)+'\n')
