#!/usr/bin/env python3
"""Observe initial/default/saved scale through real native application startup."""
from pathlib import Path
import argparse,hashlib,json,os,re,shutil,subprocess,time
BUNDLE='dev.bindu.usabilityqa.lifecycle'
MAESTRO=str(Path.home()/'.maestro/bin/maestro')

def run(cmd,log=None,env=None):
 if log:
  with log.open('w') as f:r=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,env=env,check=True)
 else:r=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,env=env,check=True)
 return r

def main():
 p=argparse.ArgumentParser();p.add_argument('--devices',type=Path,required=True);p.add_argument('--build',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--fresh-scale',type=float,required=True);p.add_argument('--cases',nargs='+');a=p.parse_args()
 out=a.output.resolve();out.mkdir(parents=True,exist_ok=True);assert not any(out.iterdir());build=json.loads(a.build.read_text());shutil.copy2(a.build,out/'source-build.json')
 inventory=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','--json']));owned={d['udid']:d for group in inventory['devices'].values() for d in group}
 cases=a.cases or ['fresh','missing']+['saved:'+str(s) for s in [.7,.85,1.,1.15,1.3,.93]];result={'scope':'Actual ARM64 debug iOS Simulator native cold startup; QA autoload prepares only its isolated save before main._load_best. No manual scale assignment to Meta, physical device or release claims.','cases':{}}
 try:
  for device in json.loads(a.devices.read_text()):
   profile=device['profile'];udid=device['udid'];assert owned[udid]['name'].startswith('BinduUsabilityQA-Reading-')
   folder=out/profile;folder.mkdir();removed=subprocess.run(['xcrun','simctl','uninstall',udid,BUNDLE],capture_output=True,text=True);(folder/'uninstall.json').write_text(json.dumps({'returncode':removed.returncode,'stderr':removed.stderr})+'\n')
   run(['xcrun','simctl','install',udid,build['app']]);last_pid=None
   for ordinal,scenario in enumerate(cases):
    name=scenario.replace(':','-');case=folder/name;case.mkdir()
    stopped=subprocess.run(['xcrun','simctl','terminate',udid,BUNDLE],capture_output=True,text=True);(case/'terminate.json').write_text(json.dumps({'returncode':stopped.returncode,'stderr':stopped.stderr})+'\n')
    launch=run(['xcrun','simctl','launch',udid,BUNDLE],env={**os.environ,'SIMCTL_CHILD_BINDU_QA_SCALE_CASE':scenario});pid=int(launch.stdout.strip().rsplit(' ',1)[-1]);assert pid!=last_pid;last_pid=pid
    if ordinal==0:
     flow=folder/'foreground.yaml';flow.write_text('appId: '+BUNDLE+'\n---\n- launchApp:\n    stopApp: false\n- setOrientation: LANDSCAPE_RIGHT\n- waitForAnimationToEnd:\n    timeout: 2000\n');run([MAESTRO,'--device',udid,'test',str(flow)],folder/'foreground.log')
    container=Path(subprocess.check_output(['xcrun','simctl','get_app_container',udid,BUNDLE,'data'],text=True).strip());status=container/'Documents/ios-qa-status.json';deadline=time.monotonic()+25;d={}
    while time.monotonic()<deadline:
     if status.exists():
      d=json.loads(status.read_text())
      if d['pid']==pid and d.get('startup',{}).get('settled') and d['startup']['scenario']==scenario:break
     time.sleep(.05)
    else:raise AssertionError(('startup timeout',scenario,d))
    assert d['ios'] and d['mobile'] and d['template'] and d['debug_build'] and not d['editor']
    assert d['runtime_log'] and all(r['type']==1 and r['code']=='BinduIOSQA logger probe' for r in d['runtime_log']),d['runtime_log']
    s=d['startup'];expected=a.fresh_scale if scenario=='fresh' else 1.3 if scenario=='missing' else float(scenario.split(':')[1]);expected=1.0 if expected==.93 else expected
    assert s['initial_scale']==a.fresh_scale
    assert s['initial_save_exists']==(scenario!='fresh')
    assert s['loaded_scale']==expected and all(abs(v-expected)<1e-5 for v in s['ui_root_scale']),(scenario,s,expected)
    if scenario!='fresh':assert s['games']==7 and abs(s['volume']-.37)<.0001,s
    (case/'state.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');run(['xcrun','simctl','io',udid,'screenshot',str(case/'screen.png')],case/'capture.log')
    result['cases'][profile+'/'+name]={'passed':True,'pid':pid,'expected':expected,'startup':s,'state_sha256':hashlib.sha256((case/'state.json').read_bytes()).hexdigest(),'capture_sha256':hashlib.sha256((case/'screen.png').read_bytes()).hexdigest()}
    print(profile,scenario,'loaded',s['loaded_scale'],'passed',flush=True)
   installed=Path(subprocess.check_output(['xcrun','simctl','get_app_container',udid,BUNDLE,'app'],text=True).strip());hashes={n:hashlib.sha256((installed/n).read_bytes()).hexdigest() for n in ['BinduIOSQA','BinduIOSQA.pck']};assert hashes['BinduIOSQA']==build['app_binary_sha256'] and hashes['BinduIOSQA.pck']==build['pck_sha256'];(folder/'installed-hashes.json').write_text(json.dumps(hashes,indent=2)+'\n')
 finally:(out/'run.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
 assert len(result['cases'])==len(cases)*len(json.loads(a.devices.read_text()))

if __name__=='__main__':main()
