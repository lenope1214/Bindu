#!/usr/bin/env python3
"""Frozen legacy/current source, actual native3-peer WebRTC; no packet/result injection."""
from pathlib import Path
import argparse, hashlib, importlib.util, json, os, re, shutil, socket, subprocess, tarfile, tempfile, time, uuid

ROOT=Path(__file__).resolve().parents[5]
GODOT=os.environ.get('GODOT','/Applications/Godot.app/Contents/MacOS/Godot')
ACTORS=['host','peer_a','peer_b']
COHORTS={'legacy_host':['legacy','current','current'],'current_host':['current','legacy','current'],'all_current':['current']*3}


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,required=True);parser.add_argument('--legacy-ref',default='8704b78688ee9be638e0ddd24eb91d54f3f56194');parser.add_argument('--current-ref');parser.add_argument('--verify-copy',action='store_true');parser.add_argument('--profile',choices=['pc100','phone130'],default='pc100');parser.add_argument('--cohorts',nargs='+',choices=COHORTS,default=list(COHORTS));args=parser.parse_args()
    out=args.output.resolve();out.mkdir(parents=True,exist_ok=True);assert not any(out.iterdir())
    spec=importlib.util.spec_from_file_location('export_helpers',ROOT/'docs/qa/2026-11-09-battlefield-fixes/performance/export-runtime/run_export.py');helper=importlib.util.module_from_spec(spec);spec.loader.exec_module(helper)
    record={'scope':'Same-computer native source cohorts, not shipped legacy binary or physical device/Internet proof','legacy_ref':args.legacy_ref,'current_ref':args.current_ref or subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'current_working_tree':args.current_ref is None,'profile':args.profile,'sources':{},'cohorts':{}}
    saves=[]
    try:
        with tempfile.TemporaryDirectory(prefix='bindu-mixed-version-') as directory:
            base=Path(directory)
            for version in ['legacy','current']:
                project=base/version;project.mkdir()
                names=['scripts','tools','addons','icons','docs/features.md','main.tscn','project.godot','icon.svg']
                if version=='legacy' or args.current_ref:
                    ref=args.legacy_ref if version=='legacy' else args.current_ref
                    names=[p for p in names if subprocess.run(['git','cat-file','-e',ref+':'+p],cwd=ROOT,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode==0]
                    archive=base/(version+'.tar');archive.write_bytes(subprocess.check_output(['git','archive',ref,*names],cwd=ROOT))
                    with tarfile.open(archive) as stream:
                        # Fixed local Git revision; still reject archive paths outside the owned snapshot.
                        assert all(project.resolve() in (project/m.name).resolve().parents for m in stream.getmembers())
                        stream.extractall(project)
                else:
                    for name in names:
                        source=ROOT/name;target=project/name
                        if not source.exists():continue
                        target.parent.mkdir(parents=True,exist_ok=True)
                        if source.is_dir():shutil.copytree(source,target)
                        else:shutil.copy2(source,target)
                shutil.copy2(ROOT/'tools/battlefield_mixed_version_check.gd',project/'tools/battlefield_mixed_version_check.gd')
                original={str(p.relative_to(project)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (project/'scripts').rglob('*.gd')}
                online=project/'scripts/online_config.gd';online.write_text(re.sub(r'const (SERVER_URL|MP_URL) := "[^"]*"',r'const \1 := ""',online.read_text()))
                (project/'override.cfg').write_text('[display]\nwindow/size/no_focus=true\nwindow/size/mode=1\n')
                name='BinduToolsMixedImport'+uuid.uuid4().hex;saves.append(Path.home()/'Library/Application Support/Godot/app_userdata'/name)
                cfg=project/'project.godot';cfg.write_text(re.sub(r'^config/name=.*$',f'config/name="{name}"',cfg.read_text(),flags=re.M))
                helper.run([GODOT,'--headless','--path',str(project),'--import'],out/(version+'-import.log'))
                helper.run([GODOT,'--headless','--path',str(project),'--check-only','-s','tools/battlefield_mixed_version_check.gd'],out/(version+'-parser.log'))
                record['sources'][version]={'original_script_hashes':original,'qa_sha256':hashlib.sha256((project/'tools/battlefield_mixed_version_check.gd').read_bytes()).hexdigest(),'virtual_input_sha256':hashlib.sha256((project/'tools/virtual_input.gd').read_bytes()).hexdigest(),'product_changes':'Only blank operational URLs; original source scripts otherwise unchanged'}
            for cohort in args.cohorts:
                folder=out/cohort;folder.mkdir();shared=base/(cohort+'-coord');shared.mkdir()
                with socket.socket() as listener:listener.bind(('127.0.0.1',0));port=listener.getsockname()[1]
                env={**os.environ,'BINDU_MP_URL':f'http://127.0.0.1:{port}','MIXED_PROFILE':args.profile}
                logs={};processes={};results={}
                try:
                    logs['signal']=(folder/'signal.log').open('w')
                    processes['signal']=subprocess.Popen([GODOT,'--headless','--path',str(base/'current'),'-s','tools/mp_signal.gd','--',str(port)],stdout=logs['signal'],stderr=subprocess.STDOUT,env=env)
                    deadline=time.monotonic()+10
                    while 'MPSIG listening ' not in (folder/'signal.log').read_text():
                        assert processes['signal'].poll() is None and time.monotonic()<deadline,'signaler unavailable'
                        time.sleep(.05)
                    for actor,version in zip(ACTORS,COHORTS[cohort]):
                        project=base/(cohort+'-'+actor);shutil.copytree(base/version,project)
                        name='BinduToolsMixed'+uuid.uuid4().hex;saves.append(Path.home()/'Library/Application Support/Godot/app_userdata'/name)
                        cfg=project/'project.godot';cfg.write_text(re.sub(r'^config/name=.*$',f'config/name="{name}"',cfg.read_text(),flags=re.M))
                        evidence=folder/actor;evidence.mkdir();logs[actor]=(folder/(actor+'.log')).open('w')
                        processes[actor]=subprocess.Popen([GODOT,'--audio-driver','Dummy','--path',str(project),'--resolution','852x393' if args.profile=='phone130' else '1280x720','-s','tools/battlefield_mixed_version_check.gd','--',actor,str(shared),str(evidence),cohort,version,'after' if args.verify_copy else 'before'],stdout=logs[actor],stderr=subprocess.STDOUT,env=env)
                    deadline=time.monotonic()+145
                    while any(processes[actor].poll() is None for actor in ACTORS):
                        assert time.monotonic()<deadline,'native cohort deadline'
                        time.sleep(.1)
                    for actor in ACTORS:
                        logs[actor].flush();text=(folder/(actor+'.log')).read_text();path=folder/actor/'result.json'
                        results[actor]={'exit':processes[actor].returncode,'errors':re.findall(r'^(?:SCRIPT ERROR|ERROR:).*$',text,re.M),'warnings':re.findall(r'^WARNING:.*$',text,re.M),'report':json.loads(path.read_text()) if path.exists() else None}
                    record['cohorts'][cohort]=results
                    (folder/'process-results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n')
                    assert all(r['exit']==0 and not r['errors'] and r['report'] and r['report']['failures']==0 for r in results.values()),cohort
                    print('MIXED',cohort,'pass',flush=True)
                finally:
                    for process in processes.values():
                        if process.poll() is None:
                            process.terminate()
                            try:process.wait(timeout=5)
                            except subprocess.TimeoutExpired:process.kill();process.wait()
                    for log in logs.values():log.close()
    finally:
        for save in saves:shutil.rmtree(save,ignore_errors=True)
        record['isolated_saves_removed']=all(not p.exists() for p in saves)
        if 'base' in locals():record['temporary_projects_removed']=not base.exists()
        (out/'run.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')


if __name__=='__main__':main()
