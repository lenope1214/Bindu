#!/usr/bin/env python3
from pathlib import Path
import argparse,hashlib,json,os,re,shutil,subprocess,tempfile,uuid
from run_replay import BASELINE_REF, baseline_guard, replace_guard
ROOT=Path(__file__).resolve().parents[5]
GODOT='/Applications/Godot.app/Contents/MacOS/Godot'

def main():
 parser=argparse.ArgumentParser();parser.add_argument('--benchmark',action='store_true');parser.add_argument('--output',type=Path,required=True);args=parser.parse_args();out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
 record={'contract':'0 ordered-target/RNG mismatches against frozen pre-change guard. Timing is observational; no user-approved numerical frame budget or CI threshold declared.','baseline_ref':BASELINE_REF,'benchmark':args.benchmark,'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'candidate_sha256':hashlib.sha256((ROOT/'tools/battlefield_guard_range_check.gd').read_bytes()).hexdigest()}
 with tempfile.TemporaryDirectory(prefix='bindu-guard-candidate-') as directory:
  project=Path(directory)
  for name in ['scripts','tools']:shutil.copytree(ROOT/name,project/name)
  (project/'docs').mkdir();shutil.copy2(ROOT/'docs/features.md',project/'docs/features.md')
  for name in ['project.godot','main.tscn','icon.svg']:shutil.copy2(ROOT/name,project/name)
  isolated='BinduToolsGuardCandidate'+uuid.uuid4().hex;userdata=Path.home()/'Library/Application Support/Godot/app_userdata'/isolated
  config=project/'project.godot';config.write_text(re.sub(r'^config/name=.*$',f'config/name="{isolated}"',config.read_text(),flags=re.M))
  online=project/'scripts/online_config.gd';online.write_text(re.sub(r'const (SERVER_URL|MP_URL) := "[^"]*"',r'const \1 := ""',online.read_text()))
  tower=project/'scripts/tower.gd';tower.write_text(replace_guard(tower.read_text(),baseline_guard()))
  try:
   with (out/'import.log').open('w') as log:r=subprocess.run([GODOT,'--headless','--import','--path',str(project)],stdout=log,stderr=subprocess.STDOUT,timeout=150)
   assert r.returncode==0 and not re.search(r'SCRIPT ERROR|Parse Error|Compile Error',(out/'import.log').read_text())
   command=[GODOT,'--headless','--audio-driver','Dummy','--path',str(project),'-s','tools/battlefield_guard_range_check.gd','--',str(out),'both' if args.benchmark else 'check'];record['command']=command
   with (out/'check.log').open('w') as log:r=subprocess.run(command,stdout=log,stderr=subprocess.STDOUT,timeout=180)
   text=(out/'check.log').read_text();record['exit']=r.returncode;record['runtime_errors']=re.findall(r'^(?:SCRIPT ERROR|ERROR:).*$',text,re.M)
   assert r.returncode==0 and not record['runtime_errors']
   data=json.loads((out/'results.json').read_text());assert data['comparisons']==41564 and data['mismatch_count']==0
   assert set(data['exercised_pattern_levels'])=={pattern+':'+str(level) for pattern in data['patterns'] for level in [1,3,8]}
   record['comparisons']=data['comparisons'];record['mismatch_count']=data['mismatch_count']
  finally:
   shutil.rmtree(userdata,ignore_errors=True);record['isolated_save_removed']=not userdata.exists()
 record['temporary_project_removed']=not project.exists();(out/'run.json').write_text(json.dumps(record,indent=2)+'\n');print('CANDIDATE comparisons=41564 mismatches=0 exit=0')
if __name__=='__main__':main()
