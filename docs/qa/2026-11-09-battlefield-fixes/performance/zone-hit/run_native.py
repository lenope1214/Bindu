#!/usr/bin/env python3
"""Controlled native ABBA with exact workload checks and queued pause requests."""
from pathlib import Path
import argparse,hashlib,importlib.util,json,os,shutil,tempfile,uuid
from candidate import ROOT,BASELINE,frozen,transform

def module(name,path):
    spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m

def main():
    p=argparse.ArgumentParser();p.add_argument('--output',required=True,type=Path);a=p.parse_args()
    out=a.output.resolve();out.mkdir(parents=True,exist_ok=True);assert not any(out.iterdir())
    h=module('copy_helper',Path(__file__).resolve().parent.parent/'guard-range/run_replay.py')
    export=module('queue_helper',Path(__file__).resolve().parent.parent/'export-runtime/run_export.py')
    result={'baseline':BASELINE,'scope':'Native macOS no-focus/minimized SubViewport;16towers/400orb goal;1/8speed,full/reduced;warm30/sample60;ABBA. QA sound muted for RNG/workload control. Force-draw return/CPU and synthetic deferred queue, not physical FPS/OS input.','runs':[]}
    for trial,variant in enumerate(['baseline','candidate','candidate','baseline']):
        case=out/(str(trial)+'-'+variant);case.mkdir()
        name='BinduToolsInertNative'+uuid.uuid4().hex;data=Path.home()/'Library/Application Support/Godot/app_userdata'/name
        with tempfile.TemporaryDirectory(prefix='bindu-inert-native-') as directory:
            project=Path(directory);h.copy_project(project,name)
            (project/'override.cfg').write_text('[display]\nwindow/size/no_focus=true\nwindow/size/mode=1\n')
            for path in ['scripts/tower.gd','scripts/share.gd']:
                source=frozen(path);(project/path).write_text(source if variant=='baseline' else transform(path,source))
            hashes={str(path.relative_to(project)):hashlib.sha256(path.read_bytes()).hexdigest() for path in (project/'scripts').rglob('*.gd')}
            harness=project/'tools/battlefield_load_check.gd';source=harness.read_text().replace('var orb_goal := 300','var orb_goal := 400')
            fixture=(ROOT/'tools/battlefield_feedback_check.gd').read_text();start=fixture.index('func fill_orbs()');stop=fixture.index('\nfunc verify(',start)
            begin=source.index('func fill_orbs()');end=source.index('\nfunc measure_case(',begin);source=source[:begin]+fixture[start:stop]+'\n'+source[end:]
            source=source.replace('for speed in [1.0, 4.0, 8.0]:','for speed in [1.0, 8.0]:').replace('main.set_process(false)','main.set_process(false)\n\tmain.sfx.muted=true',1)
            source=source.replace('"condition":label,','"condition":label,"orb_counts":orbs,"projectile_counts":projectiles,"zone_counts":zones,"end_state":qa_state(main),"next_rng":randi(),',1)
            source=source.replace('\tvar data := {','\tawait qa_queue_probes()\n\tvar data := {"queue_probes":qa_queue_rows,',1)
            parity=(ROOT/'tools/preview_parity_check.gd').read_text();start=parity.index('func state(');stop=parity.index('\nfunc difference(',start)
            source+='\n'+parity[start:stop].replace('state(','qa_state(').replace('normalize(','qa_normalize(')
            extra=export.EXTRA_GD
            extra=extra.replace('\t\t\tvar worker := Thread.new()','\t\t\tvar camera_before: Transform2D=main.get_canvas_transform()\n\t\t\tvar picks_before: int=main.picks_left\n\t\t\tvar worker := Thread.new()',1)
            extra=extra.replace('\t\t\tqa_queue_rows.append(row)','\t\t\trow["camera_preserved"]=main.get_canvas_transform().is_equal_approx(camera_before)\n\t\t\trow["picks_preserved"]=main.picks_left==picks_before\n\t\t\tqa_queue_rows.append(row)',1)
            harness.write_text(source+extra)
            try:
                export.run([h.GODOT,'--headless','--import','--path',directory],case/'import.log')
                command=[h.GODOT,'--audio-driver','Dummy','--path',directory,'--resolution','1280x720','-s','tools/battlefield_load_check.gd','--',str(case),'1.0','pc','load','60']
                export.run(command,case/'native.log',env={**os.environ,'BINDU_PROFILE_CPU':'1'})
                observed=json.loads((case/'measurements.json').read_text());assert observed['assertion_failures']==0 and observed['ui_checker_messages']==0 and len(observed['measurements'])==4
                assert len(observed['queue_probes'])==6
                for row in observed['queue_probes']:
                    assert row['paused_state_seen'] and row['pause_ui_seen'] and row['camera_preserved'] and row['picks_preserved']
                    if row['speed']==8.0:assert row['posted_during_compute']
                    row['queue_sample_class']='during_compute' if row['posted_during_compute'] else 'outside_compute_not_used_as_compute_queue_evidence'
                for row in observed['measurements']:assert row['mean_orbs']==400 and len(row['pause_probes'])==1
                record={'trial':trial,'variant':variant,'source_sha256':hashes,'harness_sha256':hashlib.sha256(harness.read_bytes()).hexdigest(),'command':command,'exit':0,'measurements':observed['measurements'],'queue_probes':observed['queue_probes']};result['runs'].append(record)
            finally:shutil.rmtree(data,ignore_errors=True)
        record['temporary_project_removed']=not project.exists();record['isolated_save_removed']=not data.exists();print('NATIVE',trial,variant,'4conditions,6queued requests exit0',flush=True)
    for condition in ['x1-fx-full','x1-fx-reduced','x8-fx-full','x8-fx-reduced']:
        matching=[next(row for row in run['measurements'] if row['condition']==condition) for run in result['runs']]
        for key in ['orb_counts','projectile_counts','zone_counts','end_state','next_rng']:assert all(row[key]==matching[0][key] for row in matching),(condition,key+' differs')
    expected={'scripts/tower.gd','scripts/share.gd'}
    assert {k for k,v in result['runs'][0]['source_sha256'].items() if result['runs'][1]['source_sha256'][k]!=v}==expected
    result['all_repeated_workloads_and_next_rng_equal']=True;result['comparisons']=[]
    for condition in ['x1-fx-full','x1-fx-reduced','x8-fx-full','x8-fx-reduced']:
        row={'condition':condition}
        for metric in ['main_frame_cpu_ms','forced_render_interval_ms','simulation_to_force_draw_return_ms']:
            values={v:[next(r for r in run['measurements'] if r['condition']==condition)[metric]['mean'] for run in result['runs'] if run['variant']==v] for v in ['baseline','candidate']}
            before=sum(values['baseline'])/2;after=sum(values['candidate'])/2;row[metric]={**values,'baseline_mean':before,'candidate_mean':after,'delta_percent':(after/before-1)*100}
        result['comparisons'].append(row)
    (out/'run.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result['comparisons'],indent=2))

if __name__=='__main__':main()
