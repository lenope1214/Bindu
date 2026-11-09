#!/usr/bin/env python3
"""Freeze product scripts, then exercise actual GUI key press/release journeys."""
from pathlib import Path
import argparse,hashlib,importlib.util,io,json,re,shutil,subprocess,tarfile,tempfile,uuid

ROOT=Path(__file__).resolve().parents[4]

def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--source-ref');p.add_argument('--expect-failure',action='store_true');p.add_argument('--profile',choices=['pc100','pc130','phone130']);a=p.parse_args()
    out=a.output.resolve();out.mkdir(parents=True,exist_ok=True);assert not any(out.iterdir())
    spec=importlib.util.spec_from_file_location('qa_copy',ROOT/'docs/qa/2026-11-09-battlefield-fixes/performance/guard-range/run_replay.py');h=importlib.util.module_from_spec(spec);spec.loader.exec_module(h)
    record={'scope':'macOS native SubViewport GUI, OS cursor/focus untouched; phone simulated; no assistive-technology claim','source_ref':a.source_ref or 'working-tree','runs':{}}
    with tempfile.TemporaryDirectory(prefix='bindu-keyboard-check-') as directory:
        project=Path(directory);name='BinduToolsKeyboard'+uuid.uuid4().hex;data=Path.home()/'Library/Application Support/Godot/app_userdata'/name
        h.copy_project(project,name)
        if a.source_ref:
            raw=subprocess.check_output(['git','archive',a.source_ref,'scripts'],cwd=ROOT)
            with tarfile.open(fileobj=io.BytesIO(raw)) as archive:archive.extractall(project)
        else:shutil.copy2(ROOT/'scripts/online_config.gd',project/'scripts/online_config.gd')
        record['product_sha256']={str(p.relative_to(project)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (project/'scripts').rglob('*.gd')}
        online=project/'scripts/online_config.gd';online.write_text(re.sub(r'const (SERVER_URL|MP_URL) := "[^"]*"',r'const \1 := ""',online.read_text()))
        (project/'override.cfg').write_text('[display]\nwindow/size/no_focus=true\nwindow/size/mode=1\n')
        try:
            h.checked([h.GODOT,'--headless','--import','--path',directory],out/'import.log')
            for profile,kind,size,scale in [('pc100','pc','1280x720','1.0'),('pc130','pc','1280x720','1.3'),('phone130','phone','852x393','1.3')]:
                if a.profile and a.profile!=profile:continue
                case=out/profile;case.mkdir()
                command=[h.GODOT,'--audio-driver','Dummy','--path',directory,'--resolution',size,'-s','tools/battlefield_keyboard_check.gd','--',str(case),scale,kind]
                with (case/'run.log').open('w') as stream:result=subprocess.run(command,stdout=stream,stderr=subprocess.STDOUT,timeout=180)
                text=(case/'run.log').read_text();assert not re.search(r'^(?:SCRIPT ERROR|ERROR:)',text,re.M),text[-3000:]
                summary=re.findall(r'^BATTLEFIELD KEYBOARD failures=(\d+) ui=(\d+)$',text,re.M);assert len(summary)==1,text[-3000:]
                if a.expect_failure:assert result.returncode==1 and int(summary[0][0])>0,(profile,text[-3000:])
                else:assert result.returncode==0 and summary==[('0','0')],(profile,text[-6000:])
                record['runs'][profile]={'exit':result.returncode,'summary':summary[0],'assertions':len(re.findall(r'^(?:ok   |FAIL )',text,re.M)),'warnings':re.findall(r'^WARNING:[^\n]+',text,re.M),'command':command}
                print(profile,summary[0],flush=True)
        finally:shutil.rmtree(data,ignore_errors=True)
    record['temporary_project_removed']=not project.exists();record['isolated_save_removed']=not data.exists()
    (out/'run.json').write_text(json.dumps(record,indent=2)+'\n')

if __name__=='__main__':main()
