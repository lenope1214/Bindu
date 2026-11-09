#!/usr/bin/env python3
"""Match raw/selected renders in the same immutable combat snapshot."""
from pathlib import Path
import argparse,hashlib,json,shutil,tempfile,uuid
from run_native import ROOT,helper


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,required=True);parser.add_argument('--profiles',nargs='+',choices=['pc100','phone130'],default=['pc100','phone130']);args=parser.parse_args()
    out=args.output.resolve();out.mkdir(parents=True,exist_ok=True);assert not any(out.iterdir())
    name='BinduToolsFeedbackDraw'+uuid.uuid4().hex;userdata=Path.home()/'Library/Application Support/Godot/app_userdata'/name
    record={'scope':'Same frozen scene raw/selected draws. Temporary FieldView passthrough and actual popup draw counter/timing/RNG probe; no product switch introduced.','profiles':{}}
    try:
        with tempfile.TemporaryDirectory(prefix='bindu-feedback-draw-') as directory:
            project=Path(directory);helper.copy_project(project,name)
            (project/'override.cfg').write_text('[display]\nwindow/size/no_focus=true\nwindow/size/mode=1\n')
            field=project/'scripts/features/field_view.gd';source=field.read_text();record['product_field_view_sha256']=hashlib.sha256(source.encode()).hexdigest()
            marker='func _popup_draw_rows() -> Array:\n';guard='\tif qa_popup_passthrough:\n\t\treturn session.popups\n'
            extra='\nvar qa_popup_passthrough := false\nvar qa_draw_count := 0\nvar qa_popup_us := 0\nvar qa_next_rng := 0\n'
            start='\tfor p in _popup_draw_rows():\n';start_extra='\tvar qa_popup_start := Time.get_ticks_usec()\n'
            stop='\tif preview:\n\t\treturn\n';stop_extra='\tqa_popup_us = Time.get_ticks_usec()-qa_popup_start\n\tqa_draw_count += 1\n\tqa_next_rng = randi()\n'
            assert source.count(marker)==1 and source.count(start)==1 and source.count(stop)==1
            instrumented=source.replace(marker,marker+guard).replace(start,start_extra+start).replace(stop,stop_extra+stop)+extra
            assert instrumented.replace(marker+guard,marker).replace(start_extra+start,start).replace(stop_extra+stop,stop).removesuffix(extra)==source
            field.write_text(instrumented);record['instrumented_field_view_sha256']=hashlib.sha256(field.read_bytes()).hexdigest();record['only_patch']='raw-row guard, four QA fields and timing/counter/next-RNG instrumentation around actual popup draw block; false uses unchanged product helper'
            helper.checked([helper.GODOT,'--headless','--import','--path',directory],out/'import.log')
            for profile in args.profiles:
                folder=out/profile;folder.mkdir();phone=profile.startswith('phone')
                command=[helper.GODOT,'--audio-driver','Dummy','--path',directory,'--resolution','852x393' if phone else '1280x720','-s','tools/battlefield_feedback_draw_check.gd','--',str(folder),'1.3' if phone else '1.0','phone' if phone else 'pc','after']
                text=helper.checked(command,folder/'native.log');assert 'failures=0 ui=0' in text
                data=json.loads((folder/'feedback.json').read_text());record['profiles'][profile]={'command':command,'checks':data['checks'],'failures':data['failures'],'ui_errors':data['ui_errors']}
                shutil.rmtree(userdata,ignore_errors=True);print('MATCHED DRAW',profile,'exit0',flush=True)
    finally:
        shutil.rmtree(userdata,ignore_errors=True);record['isolated_save_removed']=not userdata.exists()
        if 'project' in locals():record['temporary_project_removed']=not project.exists()
        (out/'run.json').write_text(json.dumps(record,indent=2)+'\n')


if __name__=='__main__':main()
