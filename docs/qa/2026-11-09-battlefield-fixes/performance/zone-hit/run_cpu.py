#!/usr/bin/env python3
"""ABBA simulation CPU and an all-active trait workload; no native/FPS claim."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import tempfile
import uuid
from candidate import BASELINE,ROOT,frozen,transform
import importlib.util
_spec=importlib.util.spec_from_file_location("guard_copy",Path(__file__).resolve().parent.parent/"guard-range/run_replay.py")
helper=importlib.util.module_from_spec(_spec);_spec.loader.exec_module(helper)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--controlled', action='store_true', default=True)
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    assert not any(out.iterdir()), 'Use a fresh output directory'
    record = {'baseline_ref': BASELINE, 'scope': 'Inert-helper guards. Headless actual simulation CPU,16towers/400in-arena moving orb goal, x8 full/reduced effects, warm30/sample60. ABBA order. Two runs per variant/workload. Headless rendering and snapshots omitted; not native FPS.', 'runs': []}
    record['controlled'] = args.controlled
    for workload in ['mixed', 'metal_earth_blood', 'wood_ice_fire']:
        for trial, variant in enumerate(['baseline', 'candidate', 'candidate', 'baseline']):
            case_out = out / workload / (str(trial) + '-' + variant)
            case_out.mkdir(parents=True)
            name = 'BinduToolsInertCPU' + uuid.uuid4().hex
            userdata = Path.home() / 'Library/Application Support/Godot/app_userdata' / name
            with tempfile.TemporaryDirectory(prefix='bindu-inert-cpu-') as tmp:
                project = Path(tmp)
                helper.copy_project(project, name)
                share = project / 'scripts/share.gd'
                old = frozen('scripts/share.gd')
                share.write_text(old if variant == 'baseline' else transform('scripts/share.gd',old))
                tower=project/'scripts/tower.gd';old_tower=frozen('scripts/tower.gd');tower.write_text(old_tower if variant=='baseline' else transform('scripts/tower.gd',old_tower))
                harness = project / 'tools/battlefield_load_check.gd'
                source = harness.read_text().replace('var orb_goal := 300','var orb_goal := 400')
                fixture=(ROOT/'tools/battlefield_feedback_check.gd').read_text();a=fixture.index('func fill_orbs()');b=fixture.index('\nfunc verify(',a)
                start=source.index('func fill_orbs()');stop=source.index('\nfunc measure_case(',start);source=source[:start]+fixture[a:b]+'\n'+source[stop:]
                marker = ' or DisplayServer.get_name() == "headless"'
                assert source.count(marker) == 1
                source = source.replace(marker, '').replace('for speed in [1.0, 4.0, 8.0]:', 'for speed in [8.0]:').replace('await snap(label)', 'print("HEADLESS snapshot omitted ", label)')
                if args.controlled:
                    source=source.replace('main.set_process(false)','main.set_process(false)\n\tmain.sfx.muted=true',1)
                    source=source.replace('"condition":label,','"condition":label,"orb_counts":orbs,"projectile_counts":projectiles,"zone_counts":zones,"end_state":qa_state(main),"next_rng":randi(),',1)
                    parity=(ROOT/'tools/preview_parity_check.gd').read_text()
                    a=parity.index('func state(');b=parity.index('\nfunc difference(',a)
                    source+='\n'+parity[a:b].replace('state(', 'qa_state(').replace('normalize(', 'qa_normalize(')
                if workload == 'metal_earth_blood':
                    old = 'var elements: Array = Elem.ALL.filter(func(e): return e != Elem.STAR)'
                    assert source.count(old) == 1
                    source = source.replace(old, 'var elements: Array = [Elem.METAL, Elem.EARTH, Elem.BLOOD]')
                elif workload=='wood_ice_fire':
                    old='var elements: Array = Elem.ALL.filter(func(e): return e != Elem.STAR)'
                    assert source.count(old)==1
                    source=source.replace(old,'var elements: Array = [Elem.WOOD, Elem.ICE, Elem.FIRE]')
                harness.write_text(source)
                try:
                    helper.checked([helper.GODOT, '--headless', '--import', '--path', tmp], case_out / 'import.log')
                    command = [helper.GODOT, '--headless', '--audio-driver', 'Dummy', '--path', tmp, '--resolution', '1280x720', '-s', 'tools/battlefield_load_check.gd', '--', str(case_out), '1.0', 'pc', 'load', '60']
                    text = helper.checked(command, case_out / 'cpu.log', env={**os.environ, 'BINDU_PROFILE_CPU': '1'})
                    assert 'conditions=2 failures=0 ui=0' in text
                    data = json.loads((case_out / 'measurements.json').read_text())
                    record['runs'].append({'workload':workload,'trial':trial,'variant':variant,'share_sha256':hashlib.sha256(share.read_bytes()).hexdigest(),'tower_sha256':hashlib.sha256(tower.read_bytes()).hexdigest(),'harness_sha256':hashlib.sha256(harness.read_bytes()).hexdigest(),'command':command,'measurements':data['measurements']})
                finally:
                    shutil.rmtree(userdata, ignore_errors=True)
            assert not project.exists() and not userdata.exists()
            print('CPU',workload,trial,variant,'exit0',flush=True)
    record['comparisons'] = []
    if args.controlled:
        for workload in ['mixed','metal_earth_blood','wood_ice_fire']:
            for condition in ['x8-fx-full','x8-fx-reduced']:
                matching=[next(row for row in run['measurements'] if row['condition']==condition) for run in record['runs'] if run['workload']==workload]
                for key in ['orb_counts','projectile_counts','zone_counts','end_state','next_rng']:
                    assert all(row[key]==matching[0][key] for row in matching), (workload,condition,key+' differs')
        record['all_repeated_workloads_and_next_rng_equal']=True
    for workload in ['mixed', 'metal_earth_blood', 'wood_ice_fire']:
        for condition in ['x8-fx-full', 'x8-fx-reduced']:
            row = {'workload':workload,'condition':condition}
            for metric in ['main_frame_cpu_ms','attack','zone']:
                pairs = {}
                for variant in ['baseline','candidate']:
                    values = []
                    for run in record['runs']:
                        if run['workload'] != workload or run['variant'] != variant: continue
                        measurement = next(r for r in run['measurements'] if r['condition'] == condition)
                        values.append(measurement['profiled_parts_ms_per_sample']['오브젝트 공격'] if metric == 'attack' else measurement['profiled_parts_ms_per_sample']['장판'] if metric == 'zone' else measurement[metric]['mean'])
                    assert len(values) == 2
                    pairs[variant] = values
                before = sum(pairs['baseline']) / 2
                after = sum(pairs['candidate']) / 2
                row[metric] = {**pairs,'baseline_mean':before,'candidate_mean':after,'delta_percent':(after/before-1.0)*100.0}
            record['comparisons'].append(row)
    record['isolated_projects_and_saves_removed'] = True
    (out / 'run.json').write_text(json.dumps(record,indent=2)+'\n')
    print(json.dumps(record['comparisons'],indent=2))


if __name__ == '__main__':
    main()
