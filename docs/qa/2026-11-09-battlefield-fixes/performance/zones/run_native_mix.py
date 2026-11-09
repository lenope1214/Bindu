#!/usr/bin/env python3
"""One instrumented native x8 workload: characterize zone costs, not a speedup claim."""
from pathlib import Path
import hashlib,json,os,re,shutil,subprocess,tempfile,time,uuid
ROOT=Path(__file__).resolve().parents[5]
OUT=Path(__file__).resolve().parent/'native-mix'
GODOT='/Applications/Godot.app/Contents/MacOS/Godot'

def main():
 OUT.mkdir(exist_ok=True)
 record={'scope':'Native x8/full effects only, fixed delta1/60, 30warmup+60samples. Per-zone wrappers preserve original body/call order. Geometry aggregation outside individual timers adds overhead; not an uninstrumented FPS measurement.','started':time.time()}
 with tempfile.TemporaryDirectory(prefix='bindu-zone-mix-') as directory:
  project=Path(directory)
  for name in ['scripts','tools']:shutil.copytree(ROOT/name,project/name)
  (project/'docs').mkdir();shutil.copy2(ROOT/'docs/features.md',project/'docs/features.md')
  for name in ['project.godot','main.tscn','icon.svg']:shutil.copy2(ROOT/name,project/name)
  record['source_hashes']={str(p.relative_to(project)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (project/'scripts').rglob('*.gd')}
  config=project/'project.godot';isolated='BinduToolsZoneMix'+uuid.uuid4().hex
  config.write_text(re.sub(r'^config/name=.*$',f'config/name="{isolated}"',config.read_text(),flags=re.M))
  userdata=Path.home()/'Library/Application Support/Godot/app_userdata'/isolated
  online=project/'scripts/online_config.gd';online.write_text(re.sub(r'const (SERVER_URL|MP_URL) := "[^"]*"',r'const \1 := ""',online.read_text()))
  (project/'override.cfg').write_text('[display]\nwindow/size/no_focus=true\nwindow/size/mode=1\n')
  zone=project/'scripts/zone.gd';source=zone.read_text();source+='\nstatic var qa_zone_stats := {}\n'
  signatures={
   'trail_orbs':('main','Array','return _qa_trail_orbs(main)'),
   'path_orbs':('main','Array','return _qa_path_orbs(main)'),
   'affect':('orbs: Array, delta: float','void','_qa_affect(orbs, delta)'),
   'step':('delta: float','void','_qa_step(delta)')}
  for name,(args,result,call) in signatures.items():
   old=f'func {name}({args}) -> {result}:';assert source.count(old)==1,name
   source=source.replace(old,f'func _qa_{name}({args}) -> {result}:')
   if result=='Array':
    body=f'\tvar started := Time.get_ticks_usec()\n\tvar selected := _qa_{name}(main)\n\tvar elapsed := Time.get_ticks_usec() - started\n\t_qa_record("{name}", elapsed, selected.size())\n\treturn selected\n'
   else:
    body=f'\tvar started := Time.get_ticks_usec()\n\t{call}\n\tvar elapsed := Time.get_ticks_usec() - started\n\t_qa_record("{name}", elapsed, '+('orbs.size()' if name=='affect' else '0')+')\n'
   source+=f'\n{old}\n{body}'
  source+='''
func _qa_record(method: String, elapsed: int, targets: int) -> void:
 var extent := Rect2()
 if not pts.is_empty():
  extent = Rect2(pts[0], Vector2.ZERO)
  for point in pts: extent = extent.expand(point)
 var span := maxf(extent.size.x, extent.size.y)
 var count_bin := "0" if pts.is_empty() else "1-4" if pts.size() <= 4 else "5-16" if pts.size() <= 16 else "17-80" if pts.size() <= 80 else "81+"
 var shape := "compact" if span <= radius * 2.0 else "spread"
 var key := kind + "/" + method + "/" + count_bin + "/" + shape
 if not qa_zone_stats.has(key): qa_zone_stats[key] = {"calls":0, "us":0, "targets":0, "points":0, "max_points":0}
 var row: Dictionary = qa_zone_stats[key]
 row.calls += 1
 row.us += elapsed
 row.targets += targets
 row.points += pts.size()
 row.max_points = maxi(row.max_points, pts.size())
'''
  source = '\n'.join(re.sub(r'^ +', lambda match: '\t' * len(match[0]), line) for line in source.split('\n'))
  zone.write_text(source);(OUT/'instrumented-zone.txt').write_text(source);record['instrumented_zone_sha256']=hashlib.sha256(zone.read_bytes()).hexdigest()
  tool=project/'tools/battlefield_load_check.gd';text=tool.read_text()
  assert text.count('for speed in [1.0, 4.0, 8.0]:')==1 and text.count('for reduced in [false, true]:')==1
  text=text.replace('for speed in [1.0, 4.0, 8.0]:','for speed in [8.0]:').replace('for reduced in [false, true]:','for reduced in [false]:')
  marker='\tvar data := {';assert text.count(marker)==1
  text=text.replace(marker,'\tFileAccess.open(output.path_join("zone-breakdown.json"), FileAccess.WRITE).store_string(JSON.stringify(Zone.qa_zone_stats, "\\t"))\n'+marker)
  tool.write_text(text);record['instrumented_harness_sha256']=hashlib.sha256(tool.read_bytes()).hexdigest()
  try:
   with (OUT/'import.log').open('w') as log: imported=subprocess.run([GODOT,'--headless','--import','--path',str(project)],stdout=log,stderr=subprocess.STDOUT,timeout=150)
   import_text=(OUT/'import.log').read_text();assert imported.returncode==0 and not re.search(r'SCRIPT ERROR|Parse Error|Compile Error',import_text),'import failed'
   command=[GODOT,'--audio-driver','Dummy','--path',str(project),'--resolution','1280x720','-s','tools/battlefield_load_check.gd','--',str(OUT),'1.0','pc','load','60']
   record['command']=command
   with (OUT/'native.log').open('w') as log: run=subprocess.run(command,stdout=log,stderr=subprocess.STDOUT,timeout=180,env={**os.environ,'BINDU_PROFILE_CPU':'1','BINDU_LOAD_SOURCE_STATE':'current isolated zone timing instrumentation, no product edits'})
   text=(OUT/'native.log').read_text();record['exit']=run.returncode;record['runtime_errors']=re.findall(r'^(?:SCRIPT ERROR|ERROR:).*$',text,re.M)
   assert run.returncode==0 and not record['runtime_errors'] and 'failures=0 ui=0' in text,'native gate failed'
   rows=json.loads((OUT/'zone-breakdown.json').read_text());totals={}
   for key,row in rows.items():
    kind,method,*_=key.split('/');total=totals.setdefault(kind+'/'+method,{'calls':0,'us':0})
    total['calls']+=row['calls'];total['us']+=row['us']
   record['zone_method_totals']=dict(sorted(totals.items(),key=lambda x:x[1]['us'],reverse=True))
  finally:
   shutil.rmtree(userdata,ignore_errors=True);record['isolated_save_removed']=not userdata.exists()
 record['temporary_project_removed']=not project.exists();record['finished']=time.time()
 (OUT/'run.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
 print(json.dumps({'exit':record['exit'],'totals':record['zone_method_totals'],'runtime_errors':record['runtime_errors']},indent=2))
if __name__=='__main__':main()
