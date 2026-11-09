#!/usr/bin/env python3
"""Observe actual InfoPanel drawing and native scroll clips in owned iOS QA apps."""
from pathlib import Path
import argparse,hashlib,itertools,json,re,shutil,subprocess,time,uuid
BUNDLE='dev.bindu.usabilityqa.lifecycle'
MAESTRO=str(Path.home()/'.maestro/bin/maestro')

def run(cmd,log=None):
    if log:
        with log.open('w') as f:subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,check=True)
    else:subprocess.run(cmd,stdout=subprocess.DEVNULL,check=True)

def encloses(a,b):
    return a[0]-.1<=b[0] and a[1]-.1<=b[1] and a[0]+a[2]+.1>=b[0]+b[2] and a[1]+a[3]+.1>=b[1]+b[3]

def intersects(a,b):
    return a[0]<b[0]+b[2] and b[0]<a[0]+a[2] and a[1]<b[1]+b[3] and b[1]<a[1]+a[3]

def prepare(status,stage):
    identity=uuid.uuid4().hex;temp=status.with_name('ios-qa-command.tmp')
    temp.write_text(json.dumps({'id':identity,'op':'prepare','stage':stage}));temp.replace(status.with_name('ios-qa-command.json'))
    deadline=time.monotonic()+25;d={}
    while time.monotonic()<deadline:
        if status.exists():
            d=json.loads(status.read_text())
            if d['command']==identity and d['stage']==stage and d.get('reading',{}).get('settled'):return d
        time.sleep(.05)
    raise AssertionError(('state timeout',stage,d))

def main():
    p=argparse.ArgumentParser();p.add_argument('--devices',type=Path,required=True);p.add_argument('--build',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--full',action='store_true');p.add_argument('--require-pass',action='store_true');args=p.parse_args()
    out=args.output.resolve();out.mkdir(parents=True,exist_ok=True);assert not any(out.iterdir())
    build=json.loads(args.build.read_text());shutil.copy2(args.build,out/'source-build.json')
    inventory=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','--json']));owned={d['udid']:d for group in inventory['devices'].values() for d in group}
    cases=list(itertools.product([1.3,1.,1.15,.85,.7],['simple','dense'],['wave'],['left','right'],['preview'])) if args.full else list(itertools.product([1.,1.3],['simple','dense'],['wave'],['left','right'],['basic']))

    result={'scope':'Actual ARM64 debug iOS Simulator, frozen single-player fixture; actual _tile draw calls. Physical device, release, accessibility, multiplayer and performance not observed.','cases':{},'case_count_per_device':len(cases)}
    try:
        for device in json.loads(args.devices.read_text()):
            udid=device['udid'];profile=device['profile'];assert owned[udid]['name'].startswith('BinduUsabilityQA-Reading-')
            folder=out/profile;folder.mkdir();run(['xcrun','simctl','bootstatus',udid,'-b'],folder/'boot.log')
            removed=subprocess.run(['xcrun','simctl','uninstall',udid,BUNDLE],capture_output=True,text=True);(folder/'uninstall.json').write_text(json.dumps({'returncode':removed.returncode,'stderr':removed.stderr})+'\n')
            run(['xcrun','simctl','install',udid,build['app']]);run(['xcrun','simctl','launch',udid,BUNDLE])
            flow=folder/'foreground.yaml';flow.write_text('appId: '+BUNDLE+'\n---\n- launchApp:\n    stopApp: false\n- setOrientation: LANDSCAPE_RIGHT\n- waitForAnimationToEnd:\n    timeout: 2000\n');run([MAESTRO,'--device',udid,'test',str(flow)],folder/'foreground.log');time.sleep(.75)
            container=Path(subprocess.check_output(['xcrun','simctl','get_app_container',udid,BUNDLE,'data'],text=True).strip());status=container/'Documents/ios-qa-status.json'
            for ordinal,parts in enumerate(cases,1):
                stage='|'.join(map(str,parts));name='-'.join(map(str,parts));case=folder/name;case.mkdir();d=prepare(status,stage);r=d['reading']
                assert d['ios'] and d['mobile'] and d['template'] and d['debug_build'] and not d['editor']
                assert d['runtime_log'] and all(row['type']==1 and row['code']=='BinduIOSQA logger probe' for row in d['runtime_log']),d['runtime_log']
                assert len(r['tiles'])==4,('actual draw recorder',d)
                assert r['inspector_visible'] and r['scroll_value']==0 and len(d['towers'])==2 and d['skill_used']==0
                assert d['phase_name']==parts[2].upper()
                assert len(r['skill_controls'])==(3 if parts[2]=='wave' else 0)
                violations=[{'type':'primary_metric_clipped','label':row['small'],'rect':row['rect'],'clip':r['scroll']} for row in r['tiles'] if not encloses(r['scroll'],row['rect'])]
                for row in r['tiles']:
                    assert len(row['texts'])==2
                    for text in row['texts']:
                        if text['required']>text['available']+.1:violations.append({'type':'metric_text_clipped',**text})
                if not encloses(r['safe_ui'],r['inspector']):violations.append({'type':'inspector_outside_safe_ui'})
                if r['banner_visible'] and intersects(r['inspector'],r['banner']):violations.append({'type':'banner_inspector_overlap'})
                if r['banner_visible'] and not encloses(r['safe_ui'],r['banner']):violations.append({'type':'banner_outside_safe_ui'})
                if not encloses(r['inspector'],r['preview_button']):violations.append({'type':'preview_action_outside_inspector'})
                if abs(r['preview_rect'][2]*9-r['preview_rect'][3]*16)>.1:violations.append({'type':'preview_aspect_ratio'})
                if not encloses(r['preview_rect'],r['preview_caption']):violations.append({'type':'preview_caption_clipped','preview':r['preview_rect'],'caption':r['preview_caption']})
                for button in r['skill_controls']:
                    if intersects(r['inspector'],button):violations.append({'type':'skill_control_overlap','rect':button})
                (case/'state.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');run(['xcrun','simctl','io',udid,'screenshot',str(case/'screen.png')],case/'capture.log')
                result['cases'][profile+'/'+name]={'violations':violations,'metrics':[{'big':row['big'],'small':row['small']} for row in r['tiles']],'camera':r['camera'],'field':r['field'],'picks':d['picks'],'towers':d['towers'],'state_sha256':hashlib.sha256((case/'state.json').read_bytes()).hexdigest(),'capture_sha256':hashlib.sha256((case/'screen.png').read_bytes()).hexdigest()}
                if violations:print(profile,name,violations,flush=True)
                if ordinal%20==0:print(profile,'observed',ordinal,'cases',flush=True)
            if args.require_pass:
                before=prepare(status,'1.3|dense|wave|left|detail');r=before['reading'];assert encloses(r['safe_ui'],r['preview_button'])
                viewport=[float(n) for n in re.findall(r'-?\d+(?:\.\d+)?',before['viewport'])][-2:]
                def point(rect,ypart=.5):return f'{round((rect[0]+rect[2]/2)/viewport[0]*100)}%,{round((rect[1]+rect[3]*ypart)/viewport[1]*100)}%'
                traces=[]
                actions=[('expand','- tapOn:\n    point: "'+point(r['preview_button'])+'"\n'),('scroll','- swipe:\n    start: "'+point(r['scroll'],.8)+'"\n    end: "'+point(r['scroll'],.2)+'"\n    duration: 800\n'),('collapse','- tapOn:\n    point: "'+point(r['preview_button'])+'"\n')]
                for label,action in actions:
                    flow=folder/('native-'+label+'.yaml');flow.write_text('appId: '+BUNDLE+'\n---\n'+action)
                    run([MAESTRO,'--device',udid,'test',str(flow)],folder/('native-'+label+'.log'));time.sleep(.3)
                    actual=json.loads(status.read_text());(folder/('native-'+label+'-state.json')).write_text(json.dumps(actual,ensure_ascii=False,indent=2)+'\n');run(['xcrun','simctl','io',udid,'screenshot',str(folder/('native-'+label+'.png'))],folder/('native-'+label+'-capture.log'))
                    assert actual['picks']==before['picks'] and actual['towers']==before['towers'] and actual['skill_used']==0 and actual['phase_name']=='WAVE'
                    assert actual['reading']['preview_visible']==(label!='collapse')
                    assert all(row['type']==1 and row['code']=='BinduIOSQA logger probe' for row in actual['runtime_log'])
                    if label in ['expand','scroll']:assert actual['reading']['scroll_value']>0
                    if label=='expand':assert encloses(actual['reading']['scroll'],actual['reading']['preview_rect']),actual['reading']
                    if label=='collapse':
                        assert actual['reading']['scroll_value']==0
                        assert all(encloses(actual['reading']['scroll'],row['rect']) for row in actual['reading']['tiles'])
                    traces.append({'action':label,'preview':actual['reading']['preview_visible'],'scroll':actual['reading']['scroll_value']})
                assert len([e for e in actual['input_events'] if not e['qa_fixture']])>=6
                result.setdefault('native_actions',{})[profile]=traces
            installed=Path(subprocess.check_output(['xcrun','simctl','get_app_container',udid,BUNDLE,'app'],text=True).strip())
            hashes={n:hashlib.sha256((installed/n).read_bytes()).hexdigest() for n in ['BinduIOSQA','BinduIOSQA.pck']}
            assert hashes['BinduIOSQA']==build['app_binary_sha256'] and hashes['BinduIOSQA.pck']==build['pck_sha256']
            (folder/'installed-hashes.json').write_text(json.dumps(hashes,indent=2)+'\n')
            print(profile,'completed',len(cases),'cases',flush=True)
    finally:
        result['violating_cases']=sum(bool(c['violations']) for c in result['cases'].values());result['observed_cases']=len(result['cases']);(out/'run.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    if args.require_pass:assert result['violating_cases']==0,result['violating_cases']

if __name__=='__main__':main()
