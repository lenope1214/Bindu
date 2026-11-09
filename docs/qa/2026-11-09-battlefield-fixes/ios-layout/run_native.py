#!/usr/bin/env python3
"""Measure actual iOS skill controls; only isolated owned QA simulators."""
from pathlib import Path
import argparse,json,subprocess,time,uuid,itertools,re,hashlib,shutil
BUNDLE='dev.bindu.usabilityqa.lifecycle'
MAESTRO=str(Path.home()/'.maestro/bin/maestro')

def run(cmd,log=None):
    if log:
        with log.open('w') as output:subprocess.run(cmd,stdout=output,stderr=subprocess.STDOUT,check=True)
    else:subprocess.run(cmd,stdout=subprocess.DEVNULL,check=True)

def encloses(a,b):
    return a[0]<=b[0] and a[1]<=b[1] and a[0]+a[2]>=b[0]+b[2] and a[1]+a[3]>=b[1]+b[3]

def intersects(a,b):
    return a[0]<b[0]+b[2] and b[0]<a[0]+a[2] and a[1]<b[1]+b[3] and b[1]<a[1]+a[3]

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--devices',type=Path,required=True);parser.add_argument('--app',type=Path,required=True);parser.add_argument('--output',type=Path,required=True);parser.add_argument('--scales',nargs='+',type=float,default=[.7,.85,1.,1.15,1.3]);args=parser.parse_args()
    out=args.output.resolve();out.mkdir(parents=True,exist_ok=True);assert not any(out.iterdir())
    shutil.copy2(args.app.resolve().parents[4]/'build.json',out/'source-build.json')
    devices=json.loads(args.devices.read_text());inventory=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','--json'],text=True));owned={d['udid']:d for ds in inventory['devices'].values() for d in ds};result={'cases':{},'scope':'Actual custom ARM64 debug iOS Simulator; frozen valid single-player combat. No physical-device, accessibility, performance or full-app visual verdict.'}
    try:
        for device in devices:
            udid=device['udid'];profile=device['profile'];assert owned[udid]['name'].startswith('BinduUsabilityQA-Layout-')
            folder=out/profile;folder.mkdir();run(['xcrun','simctl','bootstatus',udid,'-b'],folder/'boot.log')
            # 이 작업의 QA bundle만 제거해 이전 관찰 코드·저장 설정이 남지 않게 한다.
            removed=subprocess.run(['xcrun','simctl','uninstall',udid,BUNDLE],capture_output=True,text=True)
            (folder/'uninstall.json').write_text(json.dumps({'returncode':removed.returncode,'stderr':removed.stderr})+'\n')
            run(['xcrun','simctl','install',udid,str(args.app)]);run(['xcrun','simctl','launch',udid,BUNDLE])
            flow=folder/'foreground.yaml';flow.write_text('appId: '+BUNDLE+'\n---\n- launchApp:\n    stopApp: false\n- setOrientation: LANDSCAPE_RIGHT\n- waitForAnimationToEnd:\n    timeout: 2000\n')
            run([MAESTRO,'--device',udid,'test',str(flow)],folder/'foreground.log')
            container=Path(subprocess.check_output(['xcrun','simctl','get_app_container',udid,BUNDLE,'data'],text=True).strip());status=container/'Documents/ios-qa-status.json'
            combinations=[(None,0,'ready','closed')]+list(itertools.product(args.scales,range(3),['ready','cooldown','armed0','armed1','inspected'],['closed','open']))
            for scale,set_id,state,bar in combinations:
                label=str(round(scale*100)) if scale is not None else 'native';name=f'{label}-set{set_id}-{state}-{bar}';stage=f'{scale if scale is not None else "native"}|{set_id}|{state}|{bar}';case=folder/name;case.mkdir();identity=uuid.uuid4().hex;temp=status.with_name('ios-qa-command.tmp');temp.write_text(json.dumps({'id':identity,'op':'prepare','stage':stage}));temp.replace(status.with_name('ios-qa-command.json'))
                deadline=time.monotonic()+20
                while time.monotonic()<deadline:
                    d=json.loads(status.read_text())
                    if d['command']==identity and d['stage']==stage and d.get('layout',{}).get('settled'):break
                    time.sleep(.05)
                else:raise AssertionError(('state timeout',stage,d))
                assert d['ios'] and d['mobile'] and d['template'] and d['debug_build'] and not d['editor']
                assert d['runtime_log'] and all(r['type']==1 and r['code']=='BinduIOSQA logger probe' for r in d['runtime_log']),d['runtime_log']
                assert d['phase_name']=='WAVE' and len(d['towers'])==2 and d['skill_used']==0
                layout=d['layout'];violations=[]
                for button_index,button in enumerate(layout['buttons']):
                    assert button['visible']
                    if not encloses(layout['safe_ui_rect'],button['rect']):violations.append({'type':'outside_safe_ui','text':button['text'],'rect':button['rect']})
                    textsize=[float(v) for v in re.findall(r'-?\d+(?:\.\d+)?',button['text_size'])];padding=[float(v) for v in re.findall(r'-?\d+(?:\.\d+)?',button['style_minimum'])]
                    if textsize[0]+padding[0]>button['local_rect'][2]+.01:violations.append({'type':'text_width','text':button['text'],'required':textsize[0]+padding[0],'width':button['local_rect'][2]})
                    if layout['inspector']['visible'] and intersects(layout['inspector']['rect'],button['rect']):violations.append({'type':'inspector_control_overlap','text':button['text'],'inspector':layout['inspector']['rect'],'rect':button['rect']})
                    if layout['hint_visible'] and intersects(layout['hint_rect'],button['rect']):violations.append({'type':'hint_control_overlap','text':button['text'],'hint':layout['hint_rect'],'rect':button['rect']})
                    if button_index<2 and 'normal_border' in button:
                        wanted=3 if state==f'armed{button_index}' else 2
                        if button['normal_border']!=[wanted]*4:violations.append({'type':'missing_skill_surface','text':button['text'],'actual':button['normal_border'],'wanted':wanted})
                for left,right in itertools.combinations(layout['buttons'],2):
                    if intersects(left['rect'],right['rect']):violations.append({'type':'control_overlap','texts':[left['text'],right['text']]})
                (case/'state.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');run(['xcrun','simctl','io',udid,'screenshot',str(case/'screen.png')],case/'capture.log')
                result['cases'][profile+'/'+name]={'violations':violations,'safe_ui_rect':layout['safe_ui_rect'],'camera':layout['camera'],'state_sha256':hashlib.sha256((case/'state.json').read_bytes()).hexdigest()}
                if violations:print(profile,name,'violations',violations,flush=True)
            print(profile,'completed',sum(k.startswith(profile+'/') for k in result['cases']),'cases',flush=True)
            # 마지막 상태는 set2(붙잡기/낙인) 정보창이다. 적이 없어 자동 사용은 발동하지 않는다.
            controls=layout['buttons'];flow=folder/'native-controls.yaml'
            text='appId: '+BUNDLE+'\n---\n- launchApp:\n    stopApp: false\n- setOrientation: LANDSCAPE_RIGHT\n'
            for i in [0,1,1,2,2]:
                x,y=[round(v*100) for v in controls[i]['center']];text+=f'- tapOn:\n    point: "{x}%,{y}%"\n'
            flow.write_text(text);run([MAESTRO,'--device',udid,'test','--format','JUNIT','--output',str(folder/'native-controls-junit.xml'),str(flow)],folder/'native-controls.log')
            actual=json.loads(status.read_text());actions=actual['layout']['control_actions'];assert [a['index'] for a in actions]==[0,1,1,2,2],actions
            assert [a['skill_arm'] for a in actions[:3]]==['hold','brand',''],actions
            assert [a['skill_auto'] for a in actions[-2:]]==[True,False],actions
            assert actual['skill_used']==0 and actual['picks']==d['picks'] and actual['towers']==d['towers'] and actual['phase_name']=='WAVE'
            assert len([e for e in actual['input_events'] if not e['qa_fixture']])>=10
            assert all(r['type']==1 and r['code']=='BinduIOSQA logger probe' for r in actual['runtime_log'])
            (folder/'native-controls-state.json').write_text(json.dumps(actual,ensure_ascii=False,indent=2)+'\n');run(['xcrun','simctl','io',udid,'screenshot',str(folder/'native-controls.png')],folder/'native-controls-capture.log')
            result.setdefault('native_control_checks',{})[profile]=6
    finally:(out/'run.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')

if __name__=='__main__':main()
