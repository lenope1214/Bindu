#!/usr/bin/env python3
"""Localize residual hit cost; wrappers affect timing, not product source."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import os
import re
import shutil
import subprocess
import tempfile
import uuid

ROOT = Path(__file__).resolve().parents[5]
helper_path = Path(__file__).resolve().parent.parent / 'guard-range/run_replay.py'
spec = importlib.util.spec_from_file_location('guard_helpers', helper_path)
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--attribution', action='store_true')
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    assert not (out / 'run.json').exists(), 'Use a fresh output directory'
    name = 'BinduToolsHitProfile' + uuid.uuid4().hex
    userdata = Path.home() / 'Library/Application Support/Godot/app_userdata' / name
    record = {'scope': 'Native x8/full effects. Warm30/sample30. Inclusive static-function wrappers; nested times must not be added. Instrumentation is not a before/after FPS measurement.', 'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()}
    with tempfile.TemporaryDirectory(prefix='bindu-hit-profile-') as tmp:
        project = Path(tmp)
        helper.copy_project(project, name)
        (project / 'override.cfg').write_text('[display]\nwindow/size/no_focus=true\nwindow/size/mode=1\n')
        share = project / 'scripts/share.gd'
        record['original_share_sha256'] = hashlib.sha256(share.read_bytes()).hexdigest()
        source = share.read_text() + '\nstatic var qa_share_times := {}\n'
        for method, arguments, result in [('aff', 'tw', 'Dictionary'), ('k', 'tw, e', 'float'), ('am', 'tw, e', 'float')]:
            match = re.search(r'^static func ' + method + r'\([^\n]+\) -> ' + result + ':', source, re.M)
            assert match, method
            signature = match[0]
            renamed = signature.replace('func ' + method + '(', 'func _qa_body_' + method + '(', 1)
            source = source[:match.start()] + renamed + source[match.end():]
            source += '\n' + signature + '\n\tvar start := Time.get_ticks_usec()\n\tvar selected := _qa_body_' + method + '(' + arguments + ')\n\tvar elapsed := Time.get_ticks_usec() - start\n\tif not qa_share_times.has("' + method + '"): qa_share_times["' + method + '"] = {"calls":0, "us":0}\n\tqa_share_times["' + method + '"].calls += 1\n\tqa_share_times["' + method + '"].us += elapsed\n\treturn selected\n'
        share.write_text(source)
        (out / 'instrumented-share.txt').write_text(source)
        if args.attribution:
            tower = project / 'scripts/tower.gd'
            source = tower.read_text()
            record['original_tower_sha256'] = hashlib.sha256(tower.read_bytes()).hexdigest()
            start = '\tfor bk in [[fb, fire_key], [fm, "trig:finish"], [vm, "trig:vanguard"]]:'
            end = '\tif lit:\n'
            assert source.count(start) == 1
            begin = source.index(start)
            finish = source.index(end, begin)
            source = source[:begin] + '\tvar qa_attribution_start := Time.get_ticks_usec()\n' + source[begin:finish] + '\tqa_attribution_times.us += Time.get_ticks_usec() - qa_attribution_start\n\tqa_attribution_times.calls += 1\n' + source[finish:]
            source += '\nstatic var qa_attribution_times := {"calls":0, "us":0}\n'
            tower.write_text(source)
            (out / 'instrumented-tower.txt').write_text(source)
        harness = project / 'tools/battlefield_load_check.gd'
        source = harness.read_text().replace('for speed in [1.0, 4.0, 8.0]:', 'for speed in [8.0]:').replace('for reduced in [false, true]:', 'for reduced in [false]:')
        marker = '\tvar data := {'
        assert source.count(marker) == 1
        source = source.replace(marker, '\tFileAccess.open(output.path_join("share-times.json"), FileAccess.WRITE).store_string(JSON.stringify(Share.qa_share_times, "\\t"))\n' + marker)
        if args.attribution:
            source = source.replace(marker, '\tFileAccess.open(output.path_join("attribution-times.json"), FileAccess.WRITE).store_string(JSON.stringify(Tower.qa_attribution_times, "\\t"))\n' + marker)
        harness.write_text(source)
        try:
            helper.checked([helper.GODOT, '--headless', '--import', '--path', tmp], out / 'import.log')
            command = [helper.GODOT, '--audio-driver', 'Dummy', '--path', tmp, '--resolution', '1280x720', '-s', 'tools/battlefield_load_check.gd', '--', str(out), '1.0', 'pc', 'load', '30']
            text = helper.checked(command, out / 'native.log', env={**os.environ, 'BINDU_PROFILE_CPU': '1'})
            assert 'failures=0 ui=0' in text
            record['command'] = command
            record['exit'] = 0
            record['inclusive_totals'] = json.loads((out / 'share-times.json').read_text())
            if args.attribution:
                record['attribution_loop'] = json.loads((out / 'attribution-times.json').read_text())
        finally:
            shutil.rmtree(userdata, ignore_errors=True)
            record['isolated_save_removed'] = not userdata.exists()
    record['temporary_project_removed'] = not project.exists()
    (out / 'run.json').write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps(record['inclusive_totals'], indent=2))


if __name__ == '__main__':
    main()
