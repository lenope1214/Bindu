#!/usr/bin/env python3
"""Compare actual combat traces in two immutable, save-isolated projects."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import tempfile
import uuid

ROOT = Path(__file__).resolve().parents[5]
GODOT = os.environ.get('GODOT', '/Applications/Godot.app/Contents/MacOS/Godot')
BASELINE_REF = '602e3447d4527d69c6a281b0e51030c94974b7e8'


def baseline_guard():
    source = subprocess.check_output(['git', 'show', BASELINE_REF + ':scripts/tower.gd'], cwd=ROOT, text=True)
    start = source.index('func _guard_pick(')
    return source[start:source.index('\n\n\n## ', start)]


def proposed_guard():
    source = (ROOT / 'tools/battlefield_guard_range_check.gd').read_text()
    body = source[source.index('func candidate('):source.index('\nfunc compare(')]
    return body.replace('func candidate(tower: Tower, orbs: Array)', 'func _guard_pick(orbs: Array)', 1).replace('tower.', '')


def replace_guard(source, replacement):
    start = source.index('func _guard_pick(')
    end = source.index('\n\n\n## ', start)
    return source[:start] + replacement.rstrip() + source[end:]


def copy_project(destination, name):
    for folder in ['scripts', 'tools']:
        shutil.copytree(ROOT / folder, destination / folder)
    (destination / 'docs').mkdir()
    shutil.copy2(ROOT / 'docs/features.md', destination / 'docs/features.md')
    for file in ['project.godot', 'main.tscn', 'icon.svg']:
        shutil.copy2(ROOT / file, destination / file)
    config = destination / 'project.godot'
    config.write_text(re.sub(r'^config/name=.*$', f'config/name="{name}"', config.read_text(), flags=re.M))
    online = destination / 'scripts/online_config.gd'
    online.write_text(re.sub(r'const (SERVER_URL|MP_URL) := "[^"]*"', r'const \1 := ""', online.read_text()))


def checked(command, log, **kwargs):
    with log.open('w') as stream:
        result = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT, timeout=300, **kwargs)
    text = log.read_text()
    assert result.returncode == 0, (command, result.returncode, text[-2000:])
    assert not re.search(r'^(?:SCRIPT ERROR|ERROR:)', text, re.M), text[-2000:]
    return text


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    record = {'contract': 'Identical normalized real-combat state and final global RNG against frozen pre-change guard; not physical gameplay proof.', 'baseline_ref': BASELINE_REF, 'variants': {}}
    for variant in ['baseline', 'candidate']:
        case_out = out / variant
        case_out.mkdir(exist_ok=True)
        name = 'BinduToolsGuardReplay' + uuid.uuid4().hex
        userdata = Path.home() / 'Library/Application Support/Godot/app_userdata' / name
        with tempfile.TemporaryDirectory(prefix='bindu-guard-replay-') as tmp:
            project = Path(tmp)
            copy_project(project, name)
            tower = project / 'scripts/tower.gd'
            tower.write_text(replace_guard(tower.read_text(), proposed_guard() if variant == 'candidate' else baseline_guard()))
            instrument = project / 'tools/preview_parity_check.gd'
            source = instrument.read_text()
            source = source.replace('var preview: AttackPreview', 'var preview: AttackPreview\nvar qa_traces := []', 1)
            old = '\tseed(419)\n\tvar index := 0'
            assert source.count(old) == 1
            source = source.replace(old, '\tqa_traces.append({"pattern":pat, "label":label, "context":str(context), "states":expected, "next_rng":randi()})\n' + old)
            old = '\tquit(1 if fails > 0 else 0)'
            assert source.count(old) == 1
            source = source.replace(old, '\tFileAccess.open(OS.get_environment("BINDU_GUARD_TRACE"), FileAccess.WRITE).store_string(JSON.stringify(qa_traces))\n' + old)
            instrument.write_text(source)
            checked([GODOT, '--headless', '--import', '--path', tmp], case_out / 'import.log')
            variant_record = {'tower_sha256': hashlib.sha256(tower.read_bytes()).hexdigest(), 'suites': {}}
            try:
                for suite in ['basic', 'context', 'deaths']:
                    trace = case_out / (suite + '-traces.json')
                    command = [GODOT, '--headless', '--audio-driver', 'Dummy', '--path', tmp, '-s', 'tools/preview_parity_check.gd', '--', 'unused', '1.0', 'pc', suite]
                    text = checked(command, case_out / (suite + '.log'), env={**os.environ, 'BINDU_GUARD_TRACE': str(trace)})
                    data = json.loads(trace.read_text())
                    variant_record['suites'][suite] = {'cases': len(data), 'samples': sum(len(row['states']) for row in data), 'trace_sha256': hashlib.sha256(trace.read_bytes()).hexdigest(), 'result': re.findall(r'^PARITY suite=.*$', text, re.M), 'command': command}
                    print(variant, suite, len(data), flush=True)
            finally:
                shutil.rmtree(userdata, ignore_errors=True)
                variant_record['isolated_save_removed'] = not userdata.exists()
        variant_record['temporary_project_removed'] = not project.exists()
        record['variants'][variant] = variant_record
    for suite in ['basic', 'context', 'deaths']:
        before = json.loads((out / 'baseline' / (suite + '-traces.json')).read_text())
        after = json.loads((out / 'candidate' / (suite + '-traces.json')).read_text())
        assert before == after, suite + ': state/RNG differs'
    record['equal_suites'] = ['basic', 'context', 'deaths']
    record['cases'] = sum(r['cases'] for r in record['variants']['baseline']['suites'].values())
    record['samples'] = sum(r['samples'] for r in record['variants']['baseline']['suites'].values())
    record['precision'] = 'Existing parity schema: floats/positions snapped to 1e-5; ordered entities, damage/status/projectile/zone fields and final next RNG; not every runtime field.'
    (out / 'run.json').write_text(json.dumps(record, indent=2) + '\n')
    print('REPLAY', record['cases'], record['samples'], 'state/RNG equal')


if __name__ == '__main__':
    main()
