#!/usr/bin/env python3
"""Isolated native profile of attack/targeting; not a product change or FPS promise."""
from pathlib import Path
import argparse,hashlib,json,os,re,shutil,subprocess,tempfile,uuid
ROOT=Path(__file__).resolve().parents[5]
OUT=Path(__file__).resolve().parent/'baseline-profile'
GODOT='/Applications/Godot.app/Contents/MacOS/Godot'

def main():
 global OUT
 parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path);args=parser.parse_args()
 if args.output is not None:OUT=args.output.resolve()
 assert not OUT.exists() or not any(OUT.iterdir()),'Use a fresh --output directory; existing evidence is preserved'
 OUT.parent.mkdir(parents=True,exist_ok=True)
 OUT.mkdir(exist_ok=True)
 record={'scope':'One native x8/full-effects workload. 30 warmup and30 measured frames, fixed1/60 delta. Inclusive wrapper CPU, not physical presentation or uninstrumented FPS.','head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()}
 with tempfile.TemporaryDirectory(prefix='bindu-guard-profile-') as directory:
  project=Path(directory)
  for name in ['scripts','tools']:shutil.copytree(ROOT/name,project/name)
  (project/'docs').mkdir();shutil.copy2(ROOT/'docs/features.md',project/'docs/features.md')
  for name in ['project.godot','main.tscn','icon.svg']:shutil.copy2(ROOT/name,project/name)
  record['source_hashes']={str(p.relative_to(project)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (project/'scripts').rglob('*.gd')}
  config=project/'project.godot';isolated='BinduToolsGuardProfile'+uuid.uuid4().hex
  config.write_text(re.sub(r'^config/name=.*$',f'config/name="{isolated}"',config.read_text(),flags=re.M))
  userdata=Path.home()/'Library/Application Support/Godot/app_userdata'/isolated
  online=project/'scripts/online_config.gd';online.write_text(re.sub(r'const (SERVER_URL|MP_URL) := "[^"]*"',r'const \1 := ""',online.read_text()))
  (project/'override.cfg').write_text('[display]\nwindow/size/no_focus=true\nwindow/size/mode=1\n')
  tower=project/'scripts/tower.gd';text=tower.read_text();text+='\nstatic var qa_attack_times := {}\n'
  for name,call,result in [('attack','delta, orbs','void'),('_guard_pick','orbs','Orb'),('hit','o, dmg, k, extra, can_split, force_crit','void')]:
   match=re.search(r'^func '+re.escape(name)+r'\([^\n]+\) -> '+result+r':',text,re.M);assert match,name
   signature=match[0];replacement=signature.replace('func '+name+'(','func _qa_body_'+name+'(',1);text=text[:match.start()]+replacement+text[match.end():]
   body='\tvar started := Time.get_ticks_usec()\n'
   body+=('\tvar selected := _qa_body_'+name+'('+call+')\n') if result=='Orb' else ('\t_qa_body_'+name+'('+call+')\n')
   body+='\tvar elapsed := Time.get_ticks_usec() - started\n\tvar key := "'+name+'/" + pattern\n\tif not qa_attack_times.has(key): qa_attack_times[key] = {"calls":0, "us":0}\n\tqa_attack_times[key].calls += 1\n\tqa_attack_times[key].us += elapsed\n'
   if result=='Orb':body+='\treturn selected\n'
   text+='\n'+signature+'\n'+body
  tower.write_text(text);(OUT/'instrumented-tower.txt').write_text(text)
  harness=project/'tools/battlefield_load_check.gd';text=harness.read_text();text=text.replace('for speed in [1.0, 4.0, 8.0]:','for speed in [8.0]:').replace('for reduced in [false, true]:','for reduced in [false]:')
  marker='\tvar data := {';assert text.count(marker)==1
  text=text.replace(marker,'\tFileAccess.open(output.path_join("attack-times.json"), FileAccess.WRITE).store_string(JSON.stringify(Tower.qa_attack_times, "\\t"))\n'+marker);harness.write_text(text)
  try:
   with (OUT/'import.log').open('w') as log:r=subprocess.run([GODOT,'--headless','--import','--path',str(project)],stdout=log,stderr=subprocess.STDOUT,timeout=150)
   assert r.returncode==0 and not re.search(r'SCRIPT ERROR|Parse Error|Compile Error',(OUT/'import.log').read_text()),'import failed'
   cmd=[GODOT,'--audio-driver','Dummy','--path',str(project),'--resolution','1280x720','-s','tools/battlefield_load_check.gd','--',str(OUT),'1.0','pc','load','30'];record['command']=cmd
   with (OUT/'native.log').open('w') as log:r=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,timeout=180,env={**os.environ,'BINDU_PROFILE_CPU':'1','BINDU_LOAD_SOURCE_STATE':'current isolated attack wrappers only'})
   text=(OUT/'native.log').read_text();record['exit']=r.returncode;record['errors']=re.findall(r'^(?:SCRIPT ERROR|ERROR:).*$',text,re.M)
   assert r.returncode==0 and not record['errors'] and 'failures=0 ui=0' in text
   rows=json.loads((OUT/'attack-times.json').read_text());totals={}
   for key,row in rows.items():
    method=key.split('/')[0];total=totals.setdefault(method,{'calls':0,'us':0});total['calls']+=row['calls'];total['us']+=row['us']
   record['inclusive_totals']=totals
  finally:
   shutil.rmtree(userdata,ignore_errors=True);record['isolated_save_removed']=not userdata.exists()
 record['temporary_project_removed']=not project.exists();(OUT/'run.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps(record['inclusive_totals'],indent=2))
if __name__=='__main__':main()
