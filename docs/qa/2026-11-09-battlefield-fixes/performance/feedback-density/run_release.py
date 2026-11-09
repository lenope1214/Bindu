#!/usr/bin/env python3
"""Run exact product popup drawing in an isolated local macOS release QA app."""
from pathlib import Path
import argparse,fcntl,hashlib,importlib.util,json,os,shutil,tempfile,uuid
from run_native import ROOT

path=Path(__file__).resolve().parent.parent/'export-runtime/run_export.py'
spec=importlib.util.spec_from_file_location('export_helpers',path)
helper=importlib.util.module_from_spec(spec);spec.loader.exec_module(helper)


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    guard=(Path(tempfile.gettempdir())/'bindu-export-runtime.lock').open('w')
    fcntl.flock(guard,fcntl.LOCK_EX|fcntl.LOCK_NB)
    out=args.output.resolve();out.mkdir(parents=True,exist_ok=True);assert not any(out.iterdir())
    name='BinduToolsFeedbackRelease'+uuid.uuid4().hex
    userdata=Path.home()/'Library/Application Support/Godot/app_userdata'/name
    record={'scope':'Local ad-hoc macOS release QA MainLoop; exact product FieldView. Phone is a simulated layout, not an iPhone. No production upload.','profiles':{}}
    try:
        with tempfile.TemporaryDirectory(prefix='bindu-feedback-release-') as directory:
            project=Path(directory);helper.prepare(project,name,'keep')
            source=(ROOT/'tools/battlefield_feedback_check.gd').read_text()
            qa_source='class_name ExportFeedbackLoop\n'+source.replace('res://tools/','res://qa/')
            (project/'qa/battlefield_feedback_check.gd').write_text(qa_source)
            config=project/'project.godot'
            config.write_text(config.read_text().replace('run/main_loop_type="ExportLoadLoop"','run/main_loop_type="ExportFeedbackLoop"'))
            record['field_view_sha256']=hashlib.sha256((project/'scripts/features/field_view.gd').read_bytes()).hexdigest()
            assert record['field_view_sha256']==hashlib.sha256((ROOT/'scripts/features/field_view.gd').read_bytes()).hexdigest()
            record['qa_mainloop_sha256']=hashlib.sha256(qa_source.encode()).hexdigest()
            helper.run([helper.GODOT,'--headless','--import','--path',directory],out/'import.log')
            app=project/'build/BinduFeedbackQA.app';app.parent.mkdir()
            helper.run([helper.GODOT,'--headless','--path',directory,'--export-release','macOS',str(app)],out/'export.log')
            binaries=list((app/'Contents/MacOS').iterdir());assert len(binaries)==1
            binary=binaries[0];record['binary_sha256']=hashlib.sha256(binary.read_bytes()).hexdigest()
            packs=list((app/'Contents/Resources').glob('*.pck'));assert len(packs)==1
            record['pack_sha256']=hashlib.sha256(packs[0].read_bytes()).hexdigest()
            for profile in ['pc100','phone130']:
                folder=out/profile;folder.mkdir();phone=profile.startswith('phone')
                command=[str(binary),'--audio-driver','Dummy','--resolution','852x393' if phone else '1280x720','--',str(folder),'1.3' if phone else '1.0','phone' if phone else 'pc','after']
                text=helper.run(command,folder/'native.log',env=os.environ.copy());assert 'failures=0 ui=0' in text
                data=json.loads((folder/'feedback.json').read_text())
                assert data['runtime_features']=={'template':True,'debug_build':False,'editor':False}
                assert data['same_status_overlap_pairs_after']==0
                record['runtime_source_hash_note']='Export remaps scripts; exact product source verified before packing, not via FileAccess original source path.'
                record['runtime_fileaccess_field_view_sha256']=data['field_view_sha256']
                record['profiles'][profile]={key:data[key] for key in ['checks','failures','ui_errors','raw_popup_count','draw_popup_count','same_status_overlap_pairs_before','same_status_overlap_pairs_after','runtime_features']}
                record['profiles'][profile]['command']=command
                shutil.rmtree(userdata,ignore_errors=True)
                print('RELEASE FEEDBACK',profile,'exit0',data['raw_popup_count'],'->',data['draw_popup_count'],flush=True)
    finally:
        shutil.rmtree(userdata,ignore_errors=True);record['isolated_save_removed']=not userdata.exists()
        if 'project' in locals():record['temporary_project_removed']=not project.exists()
        (out/'run.json').write_text(json.dumps(record,indent=2)+'\n')


if __name__=='__main__':main()
