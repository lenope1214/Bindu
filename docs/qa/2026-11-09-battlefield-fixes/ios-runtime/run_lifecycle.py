#!/usr/bin/env python3
"""Actual iOS Simulator suspend/resume/termination, isolated QA bundle only."""
from pathlib import Path
import argparse,json,subprocess,time,uuid,hashlib

MAESTRO=str(Path.home()/'.maestro/bin/maestro')


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--udid',required=True);parser.add_argument('--bundle',default='dev.bindu.usabilityqa.lifecycle');parser.add_argument('--output',type=Path,required=True);parser.add_argument('--stages',nargs='+',default=['choose','place','aim','ready','wave','skill','continuous']);args=parser.parse_args()
    assert args.bundle.startswith('dev.bindu.usabilityqa.')
    inventory=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','--json'],text=True))
    owned=next(d for ds in inventory['devices'].values() for d in ds if d['udid']==args.udid)
    assert owned['name'].startswith('BinduUsabilityQA') and owned['state']=='Booted'
    out=args.output.resolve();out.mkdir(parents=True,exist_ok=True);assert not any(out.iterdir())
    container=Path(subprocess.check_output(['xcrun','simctl','get_app_container',args.udid,args.bundle,'data'],text=True).strip());status=container/'Documents/ios-qa-status.json'
    record={'scope':'Actual iOS Simulator UIKit notifications and native XCTest touch. Valid state fixtures only, no platform notification injection. Not physical device, phone call/Jetsam, Internet or performance proof.','device':owned,'bundle':args.bundle,'cases':{}}

    def read():return json.loads(status.read_text())
    def wait(predicate,label,seconds=15):
        deadline=time.monotonic()+seconds
        while time.monotonic()<deadline:
            d=read()
            if predicate(d):return d
            time.sleep(.1)
        raise AssertionError((label,read()))
    def save(folder,name,data):(folder/(name+'.json')).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    def command(stage):
        identity=uuid.uuid4().hex;path=status.with_name('ios-qa-command.json');temporary=path.with_suffix('.tmp')
        temporary.write_text(json.dumps({'id':identity,'op':'prepare','stage':stage}));temporary.replace(path)
        return wait(lambda d:d['command']==identity and d['stage']==stage and len(d['towers'])==2,'fixture command')
    def screenshot(folder,name):subprocess.run(['xcrun','simctl','io',args.udid,'screenshot',str(folder/(name+'.png'))],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,check=True)
    def native_tap(folder,name,center=None):
        flow=folder/(name+'.yaml')
        text='appId: '+args.bundle+'\n---\n- launchApp:\n    stopApp: false\n- setOrientation: LANDSCAPE_RIGHT\n'
        if center is not None:
            x,y=(round(center[0]*100),round(center[1]*100));text+='- tapOn:\n    point: "%d%%,%d%%"\n'%(x,y)
        else:text+='- waitForAnimationToEnd:\n    timeout: 2000\n'
        flow.write_text(text)
        with (folder/(name+'-maestro.log')).open('w') as log:
            result=subprocess.run([MAESTRO,'--device',args.udid,'test','--format','JUNIT','--output',str(folder/(name+'-junit.xml')),'--debug-output',str(folder/(name+'-maestro')),str(flow)],stdout=log,stderr=subprocess.STDOUT,timeout=90)
        assert result.returncode==0,(name,(folder/(name+'-maestro.log')).read_text()[-2000:])
    def healthy(d):
        assert d['ios'] and d['mobile'] and d['template'] and d['debug_build'] and not d['editor']
        assert any(r['code']=='BinduIOSQA logger probe' or r['rationale']=='BinduIOSQA logger probe' for r in d['runtime_log']),'in-app logger positive probe'
        assert not [r for r in d['runtime_log'] if r['type']!=1],d['runtime_log']
        assert all(r['code']=='BinduIOSQA logger probe' or r['rationale']=='BinduIOSQA logger probe' for r in d['runtime_log']),d['runtime_log']
    try:
        for stage in args.stages:
            folder=out/stage;folder.mkdir();case={'checks':0}
            def check(condition,label):
                assert condition,(stage,label)
                case['checks']+=1
            before=command(stage);healthy(before);save(folder,'before',before)
            expected_phase={'choose':'CHOOSE','place':'PLACE','aim':'AIM','ready':'READY','wave':'WAVE','skill':'WAVE','continuous':'WAVE'}[stage]
            check(before['phase_name']==expected_phase,'valid actual prepared phase')
            check(not before['paused'] and before['pause_setting'],'fresh single focus policy enabled')
            check(len(before['saved'].get('towers',[]))==2,'real sandbox save exists')
            n=len(before['notifications']);pid=before['pid']
            subprocess.run(['xcrun','simctl','launch',args.udid,'com.apple.Preferences'],stdout=subprocess.DEVNULL,check=True)
            background=wait(lambda d:any(e['what']==2015 for e in d['notifications'][n:]),'UIKit application paused')
            save(folder,'background',background)
            check(any(e['what']==2017 for e in background['notifications'][n:]),'actual focus-out observed')
            subprocess.run(['xcrun','simctl','launch',args.udid,args.bundle],stdout=subprocess.DEVNULL,check=True)
            returned=wait(lambda d:any(e['what']==2014 for e in d['notifications'][n:]) and d['pause_ui_visible'],'UIKit resume and pause UI')
            time.sleep(.5);returned=read();healthy(returned);save(folder,'returned',returned);screenshot(folder,'returned')
            check(returned['pid']==pid,'foregrounding preserves actual process')
            check(returned['paused'] and returned['pause_ui_visible'],'return stays paused until explicit action')
            check(returned['touches_empty'] and returned['press_empty'] and returned['pending_card_empty'] and not returned['pinch_lock'],'no lingering touch/edit reference')
            check(returned['picks']==before['picks'] and returned['towers']==before['towers'],'OS transition does not consume card or move/add object')
            check(returned['wave']==before['wave'] and returned['skill_used']==before['skill_used'],'no automatic progression or skill use')
            if stage in ['wave','skill','continuous']:check(returned['saved']['sha256']==before['saved']['sha256'],'combat suspension does not overwrite resting snapshot')
            inputs=len(returned['input_events']);native_tap(folder,'resume',returned['resume_at'])
            resumed=wait(lambda d:not d['paused'],'native continue touch');healthy(resumed);save(folder,'resumed',resumed)
            check(resumed['pid']==pid and not resumed['paused'],'native continue does not restart app')
            check(any(not e['qa_fixture'] and not e['pressed'] for e in resumed['input_events'][inputs:]),'actual UIKit touch release observed')
            check(resumed['picks']==before['picks'] and resumed['towers']==before['towers'] and resumed['skill_used']==before['skill_used'],'continue touch does not leak into card/aim/skill action')
            expected=resumed['saved']
            subprocess.run(['xcrun','simctl','terminate',args.udid,args.bundle],check=True)
            launch=subprocess.check_output(['xcrun','simctl','launch',args.udid,args.bundle],text=True);(folder/'relaunch.txt').write_text(launch)
            native_tap(folder,'foreground')
            restarted=wait(lambda d:d['pid']!=pid and d['stage']=='startup' and d['title_visible'],'fresh process normal title')
            # attach의 첫 snapshot은 Container sort 이전이다. 두 heartbeat 뒤 실제 배치 좌표를 읽는다.
            time.sleep(.75);restarted=read()
            healthy(restarted);save(folder,'restarted',restarted);screenshot(folder,'restarted')
            check(restarted['pid']!=pid and restarted['continue_visible'],'actual terminated process restarts with continue entry')
            check(restarted['saved']['sha256']==expected['sha256'],'restart preserves last real snapshot on disk')
            inputs=len(restarted['input_events']);native_tap(folder,'continue',restarted['continue_at'])
            restored=wait(lambda d:not d['title_visible'] and (bool(d.get('restoration_events')) or d['phase_name'] in ['CHOOSE','READY']),'native continue and saved restoration');healthy(restored);save(folder,'restored',restored);screenshot(folder,'restored')
            # 연속 진행 READY의1초는 Maestro가 반환하기 전에 끝날 수 있다. 실제 callback 직후 기록을 쓴다.
            observation=restored['restoration_events'][-1] if restored.get('restoration_events') else dict(restored,tower_count=len(restored['towers']))
            check(any(not e['qa_fixture'] and not e['pressed'] for e in restored['input_events'][inputs:]),'continue tile receives actual UIKit touch')
            check(observation['wave']==expected['wave'] and observation['picks']==expected['picks_left'] and observation['tower_count']==len(expected['towers']),'resting wave/picks/object count restored')
            check(observation['offer']==expected['offer'] if expected['state']=='choose' else observation['phase_name']=='READY','same saved choices or ready state restored')
            check(restored['touches_empty'] and restored['press_empty'] and restored['pending_card_empty'],'fresh restoration has no stale input references')
            case.update({'before_pid':pid,'restart_pid':restored['pid'],'notification_types':sorted(set(e['what'] for e in returned['notifications'][n:])),'runtime_log':restored['runtime_log'],'passed':True})
            record['cases'][stage]=case;(out/'run.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n');print('IOS LIFECYCLE',stage,'pass',case['checks'],flush=True)
    finally:
        (out/'run.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')


if __name__=='__main__':main()
