#!/usr/bin/env python3
"""Worker-buffer path canary after centralizing parse_input_event."""
from pathlib import Path
import argparse,importlib.util,json,shutil,tempfile,uuid
ROOT=Path(__file__).resolve().parents[4]
def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=True);assert not any(out.iterdir())
    spec=importlib.util.spec_from_file_location('enqueue_copy',ROOT/'docs/qa/2026-11-09-battlefield-fixes/performance/guard-range/run_replay.py');h=importlib.util.module_from_spec(spec);spec.loader.exec_module(h)
    name='BinduToolsEnqueue'+uuid.uuid4().hex;data=Path.home()/'Library/Application Support/Godot/app_userdata'/name
    record={}
    try:
        with tempfile.TemporaryDirectory(prefix='bindu-enqueue-') as directory:
            project=Path(directory);h.copy_project(project,name);(project/'override.cfg').write_text('[display]\nwindow/size/no_focus=true\nwindow/size/mode=1\n')
            h.checked([h.GODOT,'--headless','--import','--path',directory],out/'import.log')
            command=[h.GODOT,'--audio-driver','Dummy','--path',directory,'-s','tools/battlefield_enqueue_check.gd','--',str(out/'results.json')]
            h.checked(command,out/'run.log');record={'command':command,'exit':0,'assertions':3}
    finally:
        shutil.rmtree(data,ignore_errors=True);record.update({'temporary_project_removed':not project.exists(),'isolated_save_removed':not data.exists()});(out/'run.json').write_text(json.dumps(record,indent=2)+'\n')
if __name__=='__main__':main()
