#!/usr/bin/env python3
"""Isolated native ABBA experiment. Product remains frozen at524286d."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import os
import shutil
import tempfile
import uuid
from candidate import ROOT, BASELINE, frozen, transform


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--variants', nargs='+', default=['baseline', 'candidate', 'candidate', 'baseline'], choices=['baseline', 'candidate'])
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    assert not any(out.iterdir()), 'Use a fresh output directory'
    helper = module('copy_helper', Path(__file__).resolve().parent.parent / 'guard-range/run_replay.py')
    runner = module('runner', Path(__file__).resolve().parent.parent / 'export-runtime/run_export.py')
    record = {'baseline': BASELINE, 'contract': 'No-input state/RNG and requested game-time/steps equal. Synthetic buffered P/O/Space can stop remaining old batch; no debt. Reentrant/free callbacks safe. CPU is observed delta, no numeric tolerance or CI budget declared. Not UIKit/physical OS input or display proof.', 'runs': []}
    try:
        for trial, variant in enumerate(args.variants):
            case = out / (str(trial) + '-' + variant)
            case.mkdir()
            name = 'BinduToolsInputService' + uuid.uuid4().hex
            userdata = Path.home() / 'Library/Application Support/Godot/app_userdata' / name
            run_record = {'trial': trial, 'variant': variant}
            record['runs'].append(run_record)
            try:
                with tempfile.TemporaryDirectory(prefix='bindu-input-service-') as directory:
                    project = Path(directory)
                    helper.copy_project(project, name)
                    (project / 'override.cfg').write_text('[display]\nwindow/size/no_focus=true\nwindow/size/mode=1\n')
                    frame = project / 'scripts/features/frame.gd'
                    frame.write_text(frozen('scripts/features/frame.gd') if variant == 'baseline' else transform(frozen('scripts/features/frame.gd')))
                    run_record['product_hashes'] = {str(p.relative_to(project)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((project / 'scripts').rglob('*.gd'))}
                    virtual = project / 'tools/virtual_input.gd'
                    text = virtual.read_text()
                    assert text.count('if sending:') == 1
                    virtual.write_text(text.replace('if sending:', 'if sending or event.device == 0xB1D0:', 1))
                    harness = project / 'tools/battlefield_input_service_check.gd'
                    text = harness.read_text()
                    fixture = (ROOT / 'tools/battlefield_feedback_check.gd').read_text()
                    text += '\n' + fixture[fixture.index('func fill_orbs()'):fixture.index('\nfunc verify(')]
                    harness.write_text(text)
                    run_record['harness_sha256'] = hashlib.sha256(harness.read_bytes()).hexdigest()
                    runner.run([helper.GODOT, '--headless', '--import', '--path', directory], case / 'import.log')
                    command = [helper.GODOT, '--audio-driver', 'Dummy', '--path', directory, '--resolution', '1280x720', '-s', 'tools/battlefield_input_service_check.gd', '--', str(case)]
                    run_record['command'] = command
                    runner.run(command, case / 'native.log')
                    data = json.loads((case / 'measurements.json').read_text())
                    run_record['measurements'] = data
                    assert data['failures'] == 0 and data['ui'] == 0 and len(data['no_input']) == 2 and len(data['probes']) == 7
                    for row in data['probes']:
                        assert row['posted_during_compute'], (variant, row['label'], 'not actually buffered during compute')
                        if variant == 'candidate' and row['label'] in ['pause', 'settings', 'speed']:
                            assert row['at_compute_return']['steps'] < 8, (row['label'], 'old batch not cancelled')
                        if variant == 'candidate' and row['label'] == 'reentrant':
                            assert row['event']['reentrant_extra_steps'] == 0 and row['at_compute_return']['steps'] == 8
                        if variant == 'candidate' and row['label'] == 'free':
                            assert not row['at_compute_return']['session_valid']
                        if variant == 'baseline':
                            assert row['at_compute_return']['session_valid'] and row['at_compute_return']['steps'] == 8
                    run_record['exit'] = 0
            finally:
                shutil.rmtree(userdata, ignore_errors=True)
                run_record['temporary_project_removed'] = not project.exists()
                run_record['isolated_save_removed'] = not userdata.exists()
            print('INPUT SERVICE', trial, variant, '2conditions/7probes exit0', flush=True)
        for condition in [False, True]:
            rows = [next(r for r in run['measurements']['no_input'] if r['fx_low'] == condition) for run in record['runs']]
            for key in ['population', 'traces', 'next_rng', 'steps', 'game_seconds']:
                assert all(row[key] == rows[0][key] for row in rows), (condition, key + ' differs')
        first = record['runs'][0]['measurements']['probes']
        for run in record['runs'][1:]:
            for before, after in zip(first, run['measurements']['probes']):
                assert before['pre_state'] == after['pre_state'] and before['pre_next_rng'] == after['pre_next_rng'], (run['variant'], after['label'], 'probe start differs')
        record['no_input_state_rng_population_time_equal'] = True
        record['all_probe_start_states_and_rng_equal'] = True
        record['comparisons'] = []
        for reduced in [False, True]:
            values = {v: [next(row for row in run['measurements']['no_input'] if row['fx_low'] == reduced)['main_cpu_ms']['mean'] for run in record['runs'] if run['variant'] == v] for v in ['baseline', 'candidate']}
            before = sum(values['baseline']) / len(values['baseline'])
            after = sum(values['candidate']) / len(values['candidate'])
            record['comparisons'].append({'fx_low': reduced, **values, 'delta_percent': (after / before - 1) * 100})
    except BaseException as error:
        record['failure'] = repr(error)
        raise
    finally:
        (out / 'run.json').write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps(record['comparisons'], indent=2))


if __name__ == '__main__':
    main()
