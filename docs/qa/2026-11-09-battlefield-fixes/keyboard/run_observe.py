#!/usr/bin/env python3
"""Record actual virtual GUI key dispatch in an isolated native macOS window."""
from pathlib import Path
import argparse,hashlib,importlib.util,json,shutil,tempfile,uuid

ROOT=Path(__file__).resolve().parents[4]

def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    out=a.output.resolve();out.mkdir(parents=True,exist_ok=True);assert not any(out.iterdir())
    spec=importlib.util.spec_from_file_location('qa_copy',ROOT/'docs/qa/2026-11-09-battlefield-fixes/performance/guard-range/run_replay.py');h=importlib.util.module_from_spec(spec);spec.loader.exec_module(h)
    result={'scope':'macOS native SubViewport GUI key events; no OS focus assignment; phone is simulated','runs':{}}
    with tempfile.TemporaryDirectory(prefix='bindu-keyboard-observe-') as directory:
        project=Path(directory);name='BinduToolsKeyboard'+uuid.uuid4().hex;data=Path.home()/'Library/Application Support/Godot/app_userdata'/name
        h.copy_project(project,name);shutil.copy2(Path(__file__).with_name('observe.gd'),project/'tools/keyboard_observe.gd')
        (project/'override.cfg').write_text('[display]\nwindow/size/no_focus=true\nwindow/size/mode=1\n')
        result['source_sha256']={str(p.relative_to(project)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (project/'scripts').rglob('*.gd')}
        try:
            h.checked([h.GODOT,'--headless','--import','--path',directory],out/'import.log')
            for profile,kind,size in [('pc100','pc','1280x720'),('phone130','phone','852x393')]:
                case=out/profile;case.mkdir()
                h.checked([h.GODOT,'--audio-driver','Dummy','--path',directory,'--resolution',size,'-s','tools/keyboard_observe.gd','--',str(case),'1.3' if kind=='phone' else '1.0',kind],case/'run.log')
                result['runs'][profile]=json.loads((case/'trace.json').read_text())
                print(profile,len(result['runs'][profile]),flush=True)
        finally:shutil.rmtree(data,ignore_errors=True)
    result['temporary_project_removed']=not project.exists();result['isolated_save_removed']=not data.exists()
    (out/'run.json').write_text(json.dumps(result,indent=2)+'\n')

if __name__=='__main__':main()
