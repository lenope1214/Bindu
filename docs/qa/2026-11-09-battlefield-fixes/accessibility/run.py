#!/usr/bin/env python3
"""Read macOS AX from an isolated native process; never activates a window."""
from pathlib import Path
import argparse,hashlib,importlib.util,io,json,re,shutil,subprocess,tarfile,tempfile,time,uuid

ROOT=Path(__file__).resolve().parents[4]

def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--source-ref');p.add_argument('--press-card',action='store_true');a=p.parse_args()
    out=a.output.resolve();out.mkdir(parents=True,exist_ok=True);assert not any(out.iterdir())
    spec=importlib.util.spec_from_file_location('ax_copy',ROOT/'docs/qa/2026-11-09-battlefield-fixes/performance/guard-range/run_replay.py');h=importlib.util.module_from_spec(spec);spec.loader.exec_module(h)
    name='BinduToolsAccessibility'+uuid.uuid4().hex;data=Path.home()/'Library/Application Support/Godot/app_userdata'/name
    record={'scope':'macOS OS accessibility tree, owned unfocusable native Window QA PID only. No VoiceOver speech or iOS claim.','source_ref':a.source_ref or 'working-tree','states':{}}
    try:
        with tempfile.TemporaryDirectory(prefix='bindu-accessibility-') as directory:
            project=Path(directory);h.copy_project(project,name)
            if a.source_ref:
                raw=subprocess.check_output(['git','archive',a.source_ref,'scripts'],cwd=ROOT)
                with tarfile.open(fileobj=io.BytesIO(raw)) as archive:archive.extractall(project)
            else:shutil.copy2(ROOT/'scripts/online_config.gd',project/'scripts/online_config.gd')
            record['product_sha256']={str(f.relative_to(project)):hashlib.sha256(f.read_bytes()).hexdigest() for f in (project/'scripts').rglob('*.gd')}
            record['observer_sha256']={f:hashlib.sha256((project/f).read_bytes()).hexdigest() for f in ['tools/battlefield_accessibility_check.gd','tools/carry_check.gd','tools/spec_check.gd']}
            record['reader_sha256']=hashlib.sha256(Path(__file__).with_name('read_ax.swift').read_bytes()).hexdigest()
            config=project/'scripts/online_config.gd';config.write_text(re.sub(r'const (SERVER_URL|MP_URL) := "[^"]*"',r'const \1 := ""',config.read_text()))
            (project/'override.cfg').write_text('[display]\nwindow/size/no_focus=true\n')
            binary=project/'read-ax'
            h.checked(['swiftc',str(Path(__file__).with_name('read_ax.swift')),'-o',str(binary)],out/'swift-build.log')
            h.checked([h.GODOT,'--headless','--import','--path',directory],out/'import.log')
            command=[h.GODOT,'--audio-driver','Dummy','--accessibility','always','--accessibility-driver','accesskit','--path',directory,'--resolution','1280x720','-s','tools/battlefield_accessibility_check.gd','--',str(out)]
            if a.press_card:command.append('action')
            record['command']=command
            with (out/'native.log').open('w') as log:
                process=subprocess.Popen(command,stdout=log,stderr=subprocess.STDOUT)
                try:
                    for label in (['title','choose'] if a.press_card else ['title','choose','inspector','ready','wave','pause','settings','perk']):
                        ready=out/(label+'-ready.json');deadline=time.monotonic()+25
                        while not ready.exists():
                            assert process.poll() is None, (label,(out/'native.log').read_text()[-2000:])
                            assert time.monotonic()<deadline,(label,'handshake timeout')
                            assert not re.search(r'^(?:SCRIPT ERROR|ERROR:)',(out/'native.log').read_text(),re.M),(out/'native.log').read_text()[-2000:]
                            time.sleep(.05)
                        state=json.loads(ready.read_text());assert state['pid']==process.pid and state['supported']
                        ax=out/(label+'-ax.json')
                        request=[str(binary),str(process.pid),str(ax)]
                        if a.press_card and label=='choose':
                            cards=[c for c in state['controls'] if c['name'].startswith('카드 1.')]
                            assert len(cards)==1, cards
                            request.append(cards[0]['name'])
                        marker='Bindu QA '+label
                        for attempt in range(12):
                            # First query can activate AccessKit asynchronously. Read, then verify our QA marker.
                            probe=out/(label+'-ax-warm-'+str(attempt)+'.json')
                            h.checked([str(binary),str(process.pid),str(probe)],out/(label+'-ax-warm-'+str(attempt)+'.log'))
                            warm=json.loads(probe.read_text())
                            if any(any(marker in str(r.get(k,'')) for k in ['AXTitle','AXDescription','AXValue']) for r in warm['rows']):break
                            time.sleep(.1)
                        else:raise AssertionError((label,'AX state marker missing'))
                        h.checked(request,out/(label+'-ax.log'))
                        snapshot=json.loads(ax.read_text());assert not snapshot['limit_reached']
                        assert any(any(marker in str(r.get(k,'')) for k in ['AXTitle','AXDescription','AXValue']) for r in snapshot['rows'])
                        record['states'][label]={'rows':len(snapshot['rows']),'buttons':sum(r.get('AXRole')=='AXButton' for r in snapshot['rows']),'press_matches':snapshot.get('press_matches'),'press_error':snapshot.get('press_error')}
                        (out/(label+'-done.json')).write_text('{}\n')
                        print('AX',label,record['states'][label],flush=True)
                    process.wait(timeout=15)
                    assert process.returncode==0 and not re.search(r'^(?:SCRIPT ERROR|ERROR:)',(out/'native.log').read_text(),re.M),(out/'native.log').read_text()[-2000:]
                    record['exit']=0
                    if a.press_card:
                        action=json.loads((out/'choose-result.json').read_text());assert action['after']['held'] and action['after']['picks']==action['before']['picks']==2
                        assert action['before']['camera']==action['after']['camera'] and action['before']['tower_positions']==action['after']['tower_positions']
                        record['AXPress_card_held_without_consumption']=True
                finally:
                    if process.poll() is None:
                        process.terminate()
                        try:process.wait(timeout=5)
                        except subprocess.TimeoutExpired:process.kill();process.wait()
                    record['owned_process_terminal']=process.poll() is not None
    except BaseException as error:
        record['failure']=repr(error);raise
    finally:
        shutil.rmtree(data,ignore_errors=True)
        record['temporary_project_removed']=not project.exists();record['isolated_save_removed']=not data.exists()
        (out/'run.json').write_text(json.dumps(record,indent=2)+'\n')

if __name__=='__main__':main()
