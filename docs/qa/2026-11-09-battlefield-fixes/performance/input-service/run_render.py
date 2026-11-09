#!/usr/bin/env python3
"""Check actual captured menus after returning through real engine frames."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
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
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    assert not any(out.iterdir())
    helper = module('render_copy_helper', Path(__file__).resolve().parent.parent / 'guard-range/run_replay.py')
    runner = module('render_runner', Path(__file__).resolve().parent.parent / 'export-runtime/run_export.py')
    record = {'baseline': BASELINE, 'scope': 'Separate render observation. Not a member of CPU ABBA. Two engine frame boundaries after paused layout; not first presentation timing.', 'runs': []}
    try:
        for variant in ['baseline', 'candidate']:
            case = out / variant
            case.mkdir()
            name = 'BinduToolsInputRender' + uuid.uuid4().hex
            userdata = Path.home() / 'Library/Application Support/Godot/app_userdata' / name
            row = {'variant': variant}
            record['runs'].append(row)
            try:
                with tempfile.TemporaryDirectory(prefix='bindu-input-render-') as directory:
                    project = Path(directory)
                    helper.copy_project(project, name)
                    (project / 'override.cfg').write_text('[display]\nwindow/size/no_focus=true\nwindow/size/mode=1\n')
                    frame = project / 'scripts/features/frame.gd'
                    frame.write_text(frozen('scripts/features/frame.gd') if variant == 'baseline' else transform(frozen('scripts/features/frame.gd')))
                    virtual = project / 'tools/virtual_input.gd'
                    virtual.write_text(virtual.read_text().replace('if sending:', 'if sending or event.device == 0xB1D0:', 1))
                    harness = project / 'tools/battlefield_input_service_check.gd'
                    fixture = (ROOT / 'tools/battlefield_feedback_check.gd').read_text()
                    harness.write_text(harness.read_text() + '\n' + fixture[fixture.index('func fill_orbs()'):fixture.index('\nfunc verify(')])
                    row['source_hashes'] = {str(p.relative_to(project)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((project / 'scripts').rglob('*.gd'))}
                    row['harness_sha256'] = {p: hashlib.sha256((project / p).read_bytes()).hexdigest() for p in ['tools/battlefield_input_service_check.gd', 'tools/battlefield_input_render_check.gd', 'tools/virtual_input.gd']}
                    runner.run([helper.GODOT, '--headless', '--import', '--path', directory], case / 'import.log')
                    command = [helper.GODOT, '--audio-driver', 'Dummy', '--path', directory, '--resolution', '1280x720', '-s', 'tools/battlefield_input_render_check.gd', '--', str(case)]
                    row['command'] = command
                    runner.run(command, case / 'native.log')
                    data = json.loads((case / 'measurements.json').read_text())
                    assert data['failures'] == 0 and data['ui'] == 0 and data['pause_menu_visible'] and data['pause_label_visible']
                    assert data['post']['after_parse_us'] < data['compute_end_us']
                    row['measurements'] = {k: v for k, v in data.items() if k != 'pre_state'}
                    row['pre_state_sha256'] = hashlib.sha256(json.dumps(data['pre_state'], sort_keys=True, separators=(',', ':')).encode()).hexdigest()
                    row['raw_sha256'] = hashlib.sha256((case / 'measurements.json').read_bytes()).hexdigest()
                    row['capture_sha256'] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in case.glob('*.png')}
                    row['exit'] = 0
            finally:
                shutil.rmtree(userdata, ignore_errors=True)
                row['temporary_project_removed'] = not project.exists()
                row['isolated_save_removed'] = not userdata.exists()
            print('INPUT RENDER', variant, 'exit0', flush=True)
        assert record['runs'][0]['pre_state_sha256'] == record['runs'][1]['pre_state_sha256']
        assert record['runs'][0]['measurements']['pre_next_rng'] == record['runs'][1]['measurements']['pre_next_rng']
        record['pre_state_and_rng_equal'] = True
    except BaseException as error:
        record['failure'] = repr(error)
        raise
    finally:
        (out / 'compact.json').write_text(json.dumps(record, indent=2) + '\n')


if __name__ == '__main__':
    main()
