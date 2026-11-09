#!/usr/bin/env python3
"""Matched native workload; only last-input affinity mask reuse differs. Run without other Godot QA."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import tempfile
import uuid
from run_cache import BASELINE, helper, candidate_share, frozen
GODOT, checked, copy_project = helper.GODOT, helper.checked, helper.copy_project
ROOT = Path(__file__).resolve().parents[5]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    assert not any(out.iterdir()), 'Use a fresh output directory'
    record = {'scope': 'Sequential native SubViewport, 16 towers/~400 in-arena moving orbs, seed9009, fixed1/60 delta, warmup30/sample60, speeds1/4/8 and full/reduced effects. Observational CPU/draw-return, not physical FPS or a CI timing gate.', 'baseline_share_ref': BASELINE, 'variants': {}}
    for variant in ['baseline', 'candidate']:
        case_out = out / variant
        case_out.mkdir(exist_ok=True)
        name = 'BinduToolsAffinityNative' + uuid.uuid4().hex
        userdata = Path.home() / 'Library/Application Support/Godot/app_userdata' / name
        with tempfile.TemporaryDirectory(prefix='bindu-affinity-native-') as tmp:
            project = Path(tmp)
            copy_project(project, name)
            (project / 'override.cfg').write_text('[display]\nwindow/size/no_focus=true\nwindow/size/mode=1\n')
            import subprocess
            share = project / 'scripts/share.gd'
            old = frozen('scripts/share.gd')
            share.write_text(old if variant == 'baseline' else candidate_share(old))
            harness = project / 'tools/battlefield_load_check.gd'
            text = harness.read_text().replace('var orb_goal := 300','var orb_goal := 400')
            fixture = (ROOT / 'tools/battlefield_feedback_check.gd').read_text()
            start = fixture.index('func fill_orbs()')
            stop = fixture.index('\nfunc verify(',start)
            old_start = text.index('func fill_orbs()')
            old_stop = text.index('\nfunc measure_case(',old_start)
            harness.write_text(text[:old_start] + fixture[start:stop] + '\n' + text[old_stop:])
            checked([GODOT, '--headless', '--import', '--path', tmp], case_out / 'import.log')
            try:
                command = [GODOT, '--audio-driver', 'Dummy', '--path', tmp, '--resolution', '1280x720', '-s', 'tools/battlefield_load_check.gd', '--', str(case_out), '1.0', 'pc', 'load', '60']
                text = checked(command, case_out / 'native.log', env={**os.environ, 'BINDU_PROFILE_CPU': '1', 'BINDU_LOAD_SOURCE_STATE': variant + ': immutable current sources, last-input affinity mask reuse only,400in-arena moving orbs'})
                assert 'failures=0 ui=0' in text
                data = json.loads((case_out / 'measurements.json').read_text())
                assert len(data['measurements']) == 6
                for row in data['measurements']:
                    assert len(row['pause_probes']) == 1
                record['variants'][variant] = {'command': command, 'share_sha256': hashlib.sha256(share.read_bytes()).hexdigest(), 'exit': 0, 'assertion_failures': data['assertion_failures'], 'ui_checker_messages': data['ui_checker_messages']}
            finally:
                shutil.rmtree(userdata, ignore_errors=True)
                record['variants'].setdefault(variant, {})['isolated_save_removed'] = not userdata.exists()
        record['variants'][variant]['temporary_project_removed'] = not project.exists()
        print('NATIVE', variant, '6conditions/360samples/6pause probes exit0', flush=True)
    before = json.loads((out / 'baseline/measurements.json').read_text())
    after = json.loads((out / 'candidate/measurements.json').read_text())
    record['source_differences'] = [key for key in before['source_hashes'] if before['source_hashes'][key] != after['source_hashes'].get(key)]
    assert set(record['source_differences']) == {'res://scripts/share.gd', 'res://project.godot'}
    record['project_setting_difference'] = 'Unique BinduTools config/name per save-isolated variant; other project settings are copied unchanged.'
    record['comparisons'] = []
    for a, b in zip(before['measurements'], after['measurements']):
        assert a['condition'] == b['condition']
        row = {'condition': a['condition']}
        for metric, values in {
            'attack_cpu_ms_per_sample': (a['profiled_parts_ms_per_sample']['오브젝트 공격'], b['profiled_parts_ms_per_sample']['오브젝트 공격']),
            'zone_cpu_mean_ms': (a['profiled_parts_ms_per_sample']['장판'], b['profiled_parts_ms_per_sample']['장판']),
            'render_cpu_mean_ms': (a['viewport_render_cpu_ms']['mean'], b['viewport_render_cpu_ms']['mean']),
            'main_cpu_mean_ms': (a['main_frame_cpu_ms']['mean'], b['main_frame_cpu_ms']['mean']),
            'forced_draw_interval_mean_ms': (a['forced_render_interval_ms']['mean'], b['forced_render_interval_ms']['mean']),
        }.items():
            old, new = values
            row[metric] = {'baseline': old, 'candidate': new, 'delta_percent': (new / old - 1.0) * 100.0}
        record['comparisons'].append(row)
    (out / 'run.json').write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps(record['comparisons'], indent=2))


if __name__ == '__main__':
    main()
