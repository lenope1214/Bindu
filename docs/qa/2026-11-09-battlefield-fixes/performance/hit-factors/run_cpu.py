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
from run_replay import BASELINE_REF, helper, variant_tower


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    assert not any(out.iterdir()), 'Use a fresh output directory'
    record = {'baseline_hit_ref': BASELINE_REF, 'scope': 'Headless actual simulation CPU, x8 full/reduced effects, warm30/sample60. ABBA order. Two runs per variant/workload. Headless rendering and snapshots omitted; not native FPS.', 'runs': []}
    for workload in ['mixed', 'all_active']:
        for trial, variant in enumerate(['baseline', 'candidate', 'candidate', 'baseline']):
            case_out = out / workload / (str(trial) + '-' + variant)
            case_out.mkdir(parents=True)
            name = 'BinduToolsHitCPU' + uuid.uuid4().hex
            userdata = Path.home() / 'Library/Application Support/Godot/app_userdata' / name
            with tempfile.TemporaryDirectory(prefix='bindu-hit-cpu-') as tmp:
                project = Path(tmp)
                helper.copy_project(project, name)
                tower = project / 'scripts/tower.gd'
                tower.write_text(variant_tower(tower.read_text(), variant))
                harness = project / 'tools/battlefield_load_check.gd'
                source = harness.read_text()
                marker = ' or DisplayServer.get_name() == "headless"'
                assert source.count(marker) == 1
                source = source.replace(marker, '').replace('for speed in [1.0, 4.0, 8.0]:', 'for speed in [8.0]:').replace('await snap(label)', 'print("HEADLESS snapshot omitted ", label)')
                if workload == 'all_active':
                    old = 'var elements: Array = Elem.ALL.filter(func(e): return e != Elem.STAR)'
                    assert source.count(old) == 1
                    source = source.replace(old, 'var elements: Array = [Elem.METAL, Elem.EARTH, Elem.BLOOD]')
                harness.write_text(source)
                try:
                    helper.checked([helper.GODOT, '--headless', '--import', '--path', tmp], case_out / 'import.log')
                    command = [helper.GODOT, '--headless', '--audio-driver', 'Dummy', '--path', tmp, '--resolution', '1280x720', '-s', 'tools/battlefield_load_check.gd', '--', str(case_out), '1.0', 'pc', 'load', '60']
                    text = helper.checked(command, case_out / 'cpu.log', env={**os.environ, 'BINDU_PROFILE_CPU': '1'})
                    assert 'conditions=2 failures=0 ui=0' in text
                    data = json.loads((case_out / 'measurements.json').read_text())
                    record['runs'].append({'workload':workload,'trial':trial,'variant':variant,'tower_sha256':hashlib.sha256(tower.read_bytes()).hexdigest(),'harness_sha256':hashlib.sha256(harness.read_bytes()).hexdigest(),'command':command,'measurements':data['measurements']})
                finally:
                    shutil.rmtree(userdata, ignore_errors=True)
            assert not project.exists() and not userdata.exists()
            print('CPU',workload,trial,variant,'exit0',flush=True)
    record['comparisons'] = []
    for workload in ['mixed', 'all_active']:
        for condition in ['x8-fx-full', 'x8-fx-reduced']:
            row = {'workload':workload,'condition':condition}
            for metric in ['main_frame_cpu_ms','attack']:
                pairs = {}
                for variant in ['baseline','candidate']:
                    values = []
                    for run in record['runs']:
                        if run['workload'] != workload or run['variant'] != variant: continue
                        measurement = next(r for r in run['measurements'] if r['condition'] == condition)
                        values.append(measurement['profiled_parts_ms_per_sample']['오브젝트 공격'] if metric == 'attack' else measurement[metric]['mean'])
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
