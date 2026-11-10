#!/usr/bin/env python3
"""Native unactivated Window layout matrix; phone/safe area are simulated."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import io
import json
import re
import shutil
import subprocess
import tarfile
import tempfile
import uuid

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--source-ref')
    parser.add_argument('--profiles', nargs='+', default=['pc100'])
    parser.add_argument('--require-fit', action='store_true')
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    assert not any(out.iterdir())
    spec = importlib.util.spec_from_file_location('tile_copy', HERE.parent/'performance/guard-range/run_replay.py')
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    record = {'scope':'Native macOS layout, normal main loop, virtual Enter, unique save, offline URLs. Phone and multiplayer-availability UI branches are simulated; no physical/AT/real multiplayer evidence.',
              'source_ref':args.source_ref or 'working-tree', 'profiles':{}, 'observer_sha256':hashlib.sha256((HERE/'measure.gd').read_bytes()).hexdigest()}
    try:
        with tempfile.TemporaryDirectory(prefix='bindu-continue-tile-') as directory:
            project = Path(directory)
            name = 'BinduToolsContinueTile'+uuid.uuid4().hex
            data = Path.home()/'Library/Application Support/Godot/app_userdata'/name
            helper.copy_project(project, name)
            if args.source_ref:
                raw = subprocess.check_output(['git', 'archive', args.source_ref, 'scripts'], cwd=ROOT)
                with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
                    for member in archive.getmembers():
                        assert not Path(member.name).is_absolute() and '..' not in Path(member.name).parts and not member.issym() and not member.islnk()
                    archive.extractall(project)
            else:
                shutil.copy2(ROOT/'scripts/online_config.gd', project/'scripts/online_config.gd')
            record['product_sha256'] = {str(p.relative_to(project)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (project/'scripts').rglob('*.gd')}
            online = project/'scripts/online_config.gd'
            online.write_text(re.sub(r'const (SERVER_URL|MP_URL) := "[^\"]*"', r'const \1 := ""', online.read_text()))
            shutil.copy2(HERE/'measure.gd', project/'tools/continue_tile_check.gd')
            (project/'override.cfg').write_text('[display]\nwindow/size/no_focus=true\nwindow/size/mode=1\n')
            shutil.copy2(HERE/'measure.gd', out/'observer-used.gd')
            try:
                helper.checked([helper.GODOT, '--headless', '--import', '--path', directory], out/'import.log')
                helper.checked([helper.GODOT, '--headless', '--path', directory, '--check-only', '--script', 'tools/continue_tile_check.gd'], out/'parse.log')
                for profile in args.profiles:
                    match = re.fullmatch(r'(pc|phone)(70|85|100|115|130)', profile)
                    assert match, profile
                    kind, percent = match.groups()
                    case = out/profile
                    case.mkdir()
                    shutil.rmtree(data, ignore_errors=True)
                    command = [helper.GODOT, '--audio-driver', 'Dummy', '--path', directory, '--resolution', '852x393' if kind == 'phone' else '1280x720',
                               '-s', 'tools/continue_tile_check.gd', '--', str(case), profile, kind, str(int(percent)/100)]
                    helper.checked(command, case/'native.log')
                    result = json.loads((case/'measurements.json').read_text())
                    assert result['protocol_failures'] == 0 and len(result['rows']) == 60
                    record['profiles'][profile] = {'rows':len(result['rows']), 'layout_failures':result['layout_failures'],
                                                   'clipped_rows':sum(row['clipped'] for row in result['rows']), 'protocol_failures':0,
                                                   'warnings':re.findall(r'^WARNING:[^\n]+', (case/'native.log').read_text(), re.M)}
                    print(profile, record['profiles'][profile], flush=True)
            finally:
                shutil.rmtree(data, ignore_errors=True)
            if args.require_fit:
                assert all(profile['layout_failures'] == 0 for profile in record['profiles'].values()), 'Continue content does not fit'
    except BaseException as error:
        record['failure'] = repr(error)
        raise
    finally:
        record['temporary_project_removed'] = not project.exists()
        record['isolated_save_removed'] = not data.exists()
        (out/'run.json').write_text(json.dumps(record, ensure_ascii=False, indent=2)+'\n')


if __name__ == '__main__':
    main()
