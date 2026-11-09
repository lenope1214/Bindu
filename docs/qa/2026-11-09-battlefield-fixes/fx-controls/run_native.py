#!/usr/bin/env python3
"""Isolated native effects settings via real Viewport mouse/touch/key events."""
from pathlib import Path
import argparse, hashlib, importlib.util, json, shutil, subprocess, tempfile, uuid

ROOT = Path(__file__).resolve().parents[4]
PERF = Path(__file__).resolve().parent.parent / 'performance'


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--baseline-ref')
    parser.add_argument('--profiles', nargs='+', default=['pc100', 'pc130', 'phone100', 'phone130'])
    args = parser.parse_args()
    helper = module('replay', PERF / 'guard-range/run_replay.py')
    runner = module('export', PERF / 'export-runtime/run_export.py')
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    assert not any(out.iterdir())
    name = 'BinduToolsFXControls' + uuid.uuid4().hex
    userdata = Path.home() / 'Library/Application Support/Godot/app_userdata' / name
    record = {'baseline_ref': args.baseline_ref, 'scope': 'Native synthetic Viewport input, not physical device usability', 'profiles': {}}
    try:
        with tempfile.TemporaryDirectory(prefix='bindu-fx-controls-') as directory:
            project = Path(directory)
            helper.copy_project(project, name)
            (project / 'override.cfg').write_text('[display]\nwindow/size/no_focus=true\nwindow/size/mode=1\n')
            if args.baseline_ref:
                for path in ['scripts/app/session.gd', 'scripts/features/menu.gd', 'scripts/features/ui_shell.gd', 'scripts/card_dock.gd']:
                    (project / path).write_bytes(subprocess.check_output(['git', 'show', args.baseline_ref + ':' + path], cwd=ROOT))
            record['source_sha256'] = {str(p.relative_to(project)): hashlib.sha256(p.read_bytes()).hexdigest() for p in (project / 'scripts').rglob('*.gd')}
            record['qa_sha256'] = {p: hashlib.sha256((project / p).read_bytes()).hexdigest() for p in ['tools/battlefield_fx_controls_check.gd', 'tools/carry_check.gd', 'tools/virtual_input.gd']}
            runner.run([helper.GODOT, '--headless', '--import', '--path', directory], out / 'import.log')
            for profile in args.profiles:
                phone = profile.startswith('phone')
                folder = out / profile
                folder.mkdir()
                command = [helper.GODOT, '--audio-driver', 'Dummy', '--path', directory, '--resolution', '852x393' if phone else '1280x720', '-s', 'tools/battlefield_fx_controls_check.gd', '--', str(folder), '1.3' if profile.endswith('130') else '1.0', 'phone' if phone else 'pc', 'before' if args.baseline_ref else 'after']
                result = runner.run(command, folder / 'native.log')
                assert 'FX CONTROLS failures=0 ui=0' in result, result[-2000:]
                record['profiles'][profile] = json.loads((folder / 'results.json').read_text())
                shutil.rmtree(userdata, ignore_errors=True)
                print('FX CONTROLS', profile, 'pass', flush=True)
    finally:
        shutil.rmtree(userdata, ignore_errors=True)
        record['isolated_save_removed'] = not userdata.exists()
        if 'project' in locals(): record['temporary_project_removed'] = not project.exists()
        (out / 'run.json').write_text(json.dumps(record, indent=2) + '\n')


if __name__ == '__main__':
    main()
