#!/usr/bin/env python3
"""Isolated before/after native popup geometry and actual400-orb captures."""
from pathlib import Path
import argparse
import importlib.util
import json
import os
import shutil
import subprocess
import tempfile
import uuid

ROOT=Path(__file__).resolve().parents[5]
BASELINE='ec266a6ec5d8ec09e100c60c14536537add96d83'
path=Path(__file__).resolve().parent.parent/'guard-range/run_replay.py'
spec=importlib.util.spec_from_file_location('guard_helpers',path)
helper=importlib.util.module_from_spec(spec);spec.loader.exec_module(helper)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--variant',choices=['before','after'],default='after')
    parser.add_argument('--profiles',nargs='+',choices=['pc100','pc130','phone100','phone130'],default=['pc100','pc130','phone100','phone130'])
    args=parser.parse_args();out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
    assert not any(out.iterdir()),'Use a fresh output directory'
    record={'variant':args.variant,'baseline':BASELINE,'scope':'Native SubViewport geometry and pointer behavior,16towers/~400orbs x8 fixed1/60delta. No CPU/FPS improvement claim.','profiles':{}}
    name='BinduToolsFeedback'+uuid.uuid4().hex
    userdata=Path.home()/'Library/Application Support/Godot/app_userdata'/name
    try:
        with tempfile.TemporaryDirectory(prefix='bindu-feedback-') as directory:
            project=Path(directory);helper.copy_project(project,name)
            (project/'override.cfg').write_text('[display]\nwindow/size/no_focus=true\nwindow/size/mode=1\n')
            if args.variant=='before':
                source=subprocess.check_output(['git','show',BASELINE+':scripts/features/field_view.gd'],cwd=ROOT,text=True)
                (project/'scripts/features/field_view.gd').write_text(source)
            helper.checked([helper.GODOT,'--headless','--import','--path',directory],out/'import.log')
            for profile in args.profiles:
                folder=out/profile;folder.mkdir()
                phone=profile.startswith('phone');scale='1.3' if profile.endswith('130') else '1.0'
                command=[helper.GODOT,'--audio-driver','Dummy','--path',directory,'--resolution','852x393' if phone else '1280x720','-s','tools/battlefield_feedback_check.gd','--',str(folder),scale,'phone' if phone else 'pc',args.variant]
                text=helper.checked(command,folder/'native.log')
                assert 'failures=0 ui=0' in text
                data=json.loads((folder/'feedback.json').read_text())
                assert data['failures']==0 and data['ui_errors']==0
                if args.variant=='after':assert data['same_status_overlap_pairs_after']==0 and data['checks']>=70
                record['profiles'][profile]={'command':command,**{key:data[key] for key in ['checks','failures','ui_errors','raw_popup_count','draw_popup_count','same_status_overlap_pairs_before','same_status_overlap_pairs_after','field_view_sha256']}}
                shutil.rmtree(userdata,ignore_errors=True)
                print('FEEDBACK',args.variant,profile,data['raw_popup_count'],'->',data['draw_popup_count'],'checks',data['checks'],flush=True)
    finally:
        shutil.rmtree(userdata,ignore_errors=True)
        record['isolated_save_removed']=not userdata.exists()
        if 'project' in locals():record['temporary_project_removed']=not project.exists()
        (out/'run.json').write_text(json.dumps(record,indent=2)+'\n')


if __name__=='__main__':main()
