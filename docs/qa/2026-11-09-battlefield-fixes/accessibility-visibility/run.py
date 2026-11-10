#!/usr/bin/env python3
"""Probe hidden controls in an owned native macOS Window without activation."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import io
import json
import os
import re
import shutil
import subprocess
import tarfile
import tempfile
import time
import uuid

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
LABELS = ['visible', 'hidden', 'shown', 'visible_again', 'hidden_again', 'ready', 'wave']


def wait_for(path, process, log):
    deadline = time.monotonic() + 25
    while not path.exists():
        raw = log.read_text()
        assert process.poll() is None, raw[-2000:]
        assert not re.search(r'^(?:SCRIPT ERROR|ERROR:)', raw, re.M), raw[-2000:]
        assert time.monotonic() < deadline, str(path)
        time.sleep(.05)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--source-ref')
    parser.add_argument('--cached', action='store_true')
    parser.add_argument('--require-fresh', action='store_true')
    parser.add_argument('--diagnose', action='store_true')
    parser.add_argument('--refresh-parent', action='store_true')
    parser.add_argument('--tree', choices=['AXChildren', 'AXChildrenInNavigationOrder', 'AXContents'], default='AXChildren')
    parser.add_argument('--minimal', action='store_true')
    parser.add_argument('--minimal-bridge', action='store_true')
    parser.add_argument('--start-hidden', action='store_true')
    parser.add_argument('--accessibility-focus', action='store_true')
    parser.add_argument('--journey', choices=['ready-only', 'choose-ready', 'ready-with-key', 'ready-with-inspector', 'native-journey', 'native-close', 'native-resume', 'native-resume-live'])
    parser.add_argument('--native-engine', type=Path, help='Diagnostic engine for the native launch only; stock engine still imports/checks the QA script.')
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    assert not any(out.iterdir())
    spec = importlib.util.spec_from_file_location('ax_visibility_copy', HERE.parent/'performance/guard-range/run_replay.py')
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    name = 'BinduToolsAXVisibility' + uuid.uuid4().hex
    data = Path.home()/'Library/Application Support/Godot/app_userdata'/name
    record = {'scope':'Owned native Window PID; actual macOS AX reads/presses; no activation, physical input, VoiceOver, or whole-accessibility pass.',
              'source_ref':args.source_ref or 'working-tree', 'states':{}}
    try:
        with tempfile.TemporaryDirectory(prefix='bindu-ax-visibility-') as directory:
            project = Path(directory)
            helper.copy_project(project, name)
            if args.source_ref:
                raw = subprocess.check_output(['git', 'archive', args.source_ref, 'scripts'], cwd=ROOT)
                with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
                    archive.extractall(project)
            else:
                shutil.copy2(ROOT/'scripts/online_config.gd', project/'scripts/online_config.gd')
            record['product_sha256'] = {str(p.relative_to(project)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (project/'scripts').rglob('*.gd')}
            online = project/'scripts/online_config.gd'
            online.write_text(re.sub(r'const (SERVER_URL|MP_URL) := "[^\"]*"', r'const \1 := ""', online.read_text()))
            observer_name = 'ready_journey.gd' if args.journey else ('minimal.gd' if args.minimal else 'observe.gd')
            shutil.copy2(HERE/observer_name, project/'tools/ax_visibility_check.gd')
            if args.journey:
                assert not any([args.minimal, args.cached, args.diagnose, args.refresh_parent, args.accessibility_focus])
                shutil.copy2(HERE/'observe.gd', project/'tools/ax_visibility_base.gd')
                record['journey'] = args.journey
                record['snapshot_protocol'] = {'timeout_seconds':120 if args.journey == 'native-resume-live' else 30,
                                                'timeout_fatal':True}
                record['observer_dependencies'] = {name:hashlib.sha256((project/name).read_bytes()).hexdigest()
                                                   for name in ['tools/ax_visibility_base.gd', 'tools/carry_check.gd', 'tools/spec_check.gd', 'tools/virtual_input.gd']}
            if args.minimal:
                record['scope'] = 'Engine-only isolated Button visibility/AXPress; game UI and frame systems not instantiated. No product behavior conclusion.'
            if args.accessibility_focus:
                assert not args.minimal
                observer = project/'tools/ax_visibility_check.gd'
                text = observer.read_text()
                old = '\tmain.sfx.muted = true'
                assert text.count(old) == 1
                observer.write_text(text.replace(old, old+'\n\tmain.start_btn.focus_mode = Control.FOCUS_ACCESSIBILITY', 1))
                record['accessibility_focus_prototype_only'] = 'READY start uses FOCUS_ACCESSIBILITY instead of FOCUS_NONE; no repository product edit.'
            if args.diagnose:
                shutil.copy2(HERE/'trace_control.gd', project/'tools/ax_trace_control.gd')
                observer = project/'tools/ax_visibility_check.gd'
                text = observer.read_text()
                text = text.replace('\tmain.sfx.muted = true', '\tmain.sfx.muted = true\n\tfor control in [main.start_btn, main.reroll_btn, main.ui_root]:\n\t\tcontrol.set_script(preload("res://tools/ax_trace_control.gd"))', 1)
                text = text.replace('\tvar before := state()', '\tvar traces := {}\n\tfor control in [main.start_btn, main.reroll_btn, main.ui_root]:\n\t\ttraces[str(control.name)] = {"notifications":control.qa_ax_notifications.duplicate(true), "queued":control.get_meta("qa_visibility_queues", []).duplicate(true)}\n\tFileAccess.open(output.path_join(label + "-notifications.json"), FileAccess.WRITE).store_string(JSON.stringify(traces, "\\t"))\n\tvar before := state()', 1)
                observer.write_text(text)
                ui = project/'scripts/features/ui_shell.gd'
                text = ui.read_text()
                old = '\t\tcontrol.queue_accessibility_update()'
                assert text.count(old) == 1
                ui.write_text(text.replace(old, '\t\tvar traces: Array = control.get_meta("qa_visibility_queues", [])\n\t\ttraces.append({"frame":Engine.get_process_frames(), "time_usec":Time.get_ticks_usec(), "visible":control.visible})\n\t\tcontrol.set_meta("qa_visibility_queues", traces)\n' + old, 1))
                record['diagnostic_ui_sha256'] = hashlib.sha256(ui.read_bytes()).hexdigest()
            if args.refresh_parent:
                ui = project/'scripts/features/ui_shell.gd'
                text = ui.read_text()
                old = '\t\tcontrol.queue_accessibility_update()'
                assert text.count(old) == 1
                ui.write_text(text.replace(old, old+'\n\t\tif control.get_parent() != null:\n\t\t\tcontrol.get_parent().queue_accessibility_update()', 1))
                record['parent_refresh_prototype_only'] = True
                record['prototype_ui_sha256'] = hashlib.sha256(ui.read_bytes()).hexdigest()
            record['observer_sha256'] = hashlib.sha256((project/'tools/ax_visibility_check.gd').read_bytes()).hexdigest()
            record['reader_sha256'] = hashlib.sha256((HERE/'read_ax.swift').read_bytes()).hexdigest()
            (project/'override.cfg').write_text('[display]\nwindow/size/no_focus=true\n')
            binary = project/'read-ax'
            reader = HERE/('cached_ax.swift' if args.cached else 'read_ax.swift')
            record['reader_sha256'] = hashlib.sha256(reader.read_bytes()).hexdigest()
            shutil.copy2(project/'tools/ax_visibility_check.gd', out/'observer-used.gd')
            helper.checked(['swiftc', str(reader), '-o', str(binary)], out/'swift-build.log')
            helper.checked([helper.GODOT, '--headless', '--import', '--path', directory], out/'import.log')
            helper.checked([helper.GODOT, '--headless', '--path', directory, '--check-only', '--script', 'tools/ax_visibility_check.gd'], out/'parse.log')
            engine = str(args.native_engine.resolve()) if args.native_engine else helper.GODOT
            assert Path(engine).is_file()
            record['native_engine'] = {'path':engine, 'sha256':hashlib.sha256(Path(engine).read_bytes()).hexdigest(),
                                       'version':subprocess.check_output([engine, '--version'], text=True).strip(),
                                       'outgoing_node_trace':os.environ.get('BINDU_AX_TRACE') == '1'}
            if args.native_engine:
                checks = ['tools/spec_check.gd', 'tools/carry_check.gd'] if args.journey else []
                if args.journey:
                    checks.append('tools/ax_visibility_base.gd')
                checks.append('tools/ax_visibility_check.gd')
                for index, script in enumerate(checks):
                    helper.checked([engine, '--headless', '--path', directory, '--check-only', '--script', script],
                                   out/('native-parse-'+str(index)+'.log'))
            command = [engine, '--audio-driver', 'Dummy', '--accessibility', 'always', '--accessibility-driver', 'accesskit',
                       '--path', directory, '--resolution', '1280x720', '-s', 'tools/ax_visibility_check.gd', '--', str(out)]
            if args.cached:
                command.append('cached')
            if args.minimal_bridge:
                assert args.minimal
                command.append('bridge')
            if args.start_hidden:
                assert args.minimal
                command.append('start-hidden')
            if args.journey:
                command.append(args.journey)
            record['command'] = command
            log = out/'native.log'
            with log.open('w') as stream:
                process = subprocess.Popen(command, stdout=stream, stderr=subprocess.STDOUT)
                try:
                    if args.cached:
                        wait_for(out/'visible-ready.json', process, log)
                        state = json.loads((out/'visible-ready.json').read_text())
                        assert state['pid'] == process.pid and state['supported'] and state['card_name']
                        helper.checked([str(binary), str(process.pid), str(out), state['card_name']], out/'cached-reader.log')
                        for label in ['visible', 'hidden']:
                            wait_for(out/(label+'-result.json'), process, log)
                            record['states'][label] = json.loads((out/(label+'-result.json')).read_text())
                        record['cached_action'] = json.loads((out/'hidden-ax.json').read_text())
                    labels = {'ready-only':['ready', 'wave'], 'ready-with-key':['ready', 'wave'], 'ready-with-inspector':['ready', 'wave'],
                              'choose-ready':['visible', 'ready', 'wave'], 'native-journey':['pick_one', 'pick_two', 'ready', 'wave'],
                              'native-close':['pick_one', 'pick_two', 'ready_open', 'ready_closed', 'ready', 'wave'],
                              'native-resume-live':['pick_one', 'pick_two', 'saved_ready', 'pause', 'leave', 'continue'],
                              'native-resume':['pick_one', 'pick_two', 'saved_ready', 'pause', 'leave', 'continue', 'ready', 'wave']}.get(args.journey, LABELS)
                    for label in ([] if args.cached else labels):
                        wait_for(out/(label+'-ready.json'), process, log)
                        state = json.loads((out/(label+'-ready.json')).read_text())
                        assert state['pid'] == process.pid and state['supported']
                        marker = 'Bindu QA '+label
                        probes = []
                        for attempt in range(5):
                            probe = out/(label+'-warm-'+str(attempt)+'.json')
                            helper.checked([str(binary), str(process.pid), str(probe)], out/(label+'-warm-'+str(attempt)+'.log'),
                                           env={**os.environ, 'BINDU_AX_CHILDREN':args.tree})
                            warm = json.loads(probe.read_text())
                            names = [row.get('AXTitle') for row in warm['rows'] if row.get('AXRole') == 'AXButton']
                            mismatches = [{'name':s['name'], 'expected':int(s['visible']), 'actual':names.count(s['name'])}
                                          for s in state['sentinels'] if names.count(s['name']) != int(s['visible'])]
                            has_marker = any(marker in str(row.get('AXTitle', '')) for row in warm['rows'])
                            probes.append({'attempt':attempt, 'marker':has_marker, 'mismatches':mismatches})
                            if has_marker and not mismatches:
                                break
                            time.sleep(.2)
                        assert has_marker, (label, 'state marker absent')
                        command = [str(binary), str(process.pid), str(out/(label+'-ax.json'))]
                        if label in ['hidden', 'hidden_again', 'shown']:
                            assert state['card_name']
                            command.append(state['card_name'])
                        if args.journey and args.journey.startswith('native-'):
                            if label in ['pick_one', 'pick_two', 'leave', 'continue']:
                                assert state['card_name']
                                command.append(state['card_name'])
                            if label == 'ready':
                                commands = [s['name'] for s in state['sentinels'] if '웨이브 시작' in s['name'] and s['visible']]
                                assert len(commands) == 1
                                command.append(commands[0])
                        helper.checked(command, out/(label+'-ax.log'), env={**os.environ, 'BINDU_AX_CHILDREN':args.tree})
                        ax = json.loads((out/(label+'-ax.json')).read_text())
                        assert not ax['limit_reached']
                        names = [row.get('AXTitle') for row in ax['rows'] if row.get('AXRole') == 'AXButton']
                        mismatches = [{'name':s['name'], 'expected':int(s['visible']), 'actual':names.count(s['name'])}
                                      for s in state['sentinels'] if names.count(s['name']) != int(s['visible'])]
                        record['states'][label] = {'rows':len(ax['rows']), 'press_matches':ax.get('press_matches'), 'press_error':ax.get('press_error'),
                                                  'freshness_probes':probes, 'sentinel_mismatches':mismatches}
                        (out/(label+'-done.json')).write_text('{}\n')
                        wait_for(out/(label+'-result.json'), process, log)
                        result = json.loads((out/(label+'-result.json')).read_text())
                        record['states'][label].update({'before':result['before'], 'after':result['after']})
                        print('AX VISIBILITY', label, record['states'][label]['press_matches'],
                              'phase', result['before']['phase'], '->', result['after']['phase'], flush=True)
                        if args.journey in ['native-resume', 'native-resume-live'] and label in ['leave', 'continue']:
                            assert ax.get('press_matches') == 1 and ax.get('press_error') == 0, (label, 'native action not discoverable or rejected')
                    process.wait(timeout=15)
                    raw = log.read_text()
                    assert process.returncode == 0 and not re.search(r'^(?:SCRIPT ERROR|ERROR:)', raw, re.M), raw[-2000:]
                    record['exit'] = process.returncode
                    if args.require_fresh:
                        assert all(not state['sentinel_mismatches'] for state in record['states'].values())
                finally:
                    if process.poll() is None:
                        process.terminate()
                        try:
                            process.wait(timeout=5)
                        except subprocess.TimeoutExpired:
                            process.kill(); process.wait()
                    record['owned_process_terminal'] = process.poll() is not None
    except BaseException as error:
        record['failure'] = repr(error)
        raise
    finally:
        shutil.rmtree(data, ignore_errors=True)
        record['temporary_project_removed'] = not project.exists()
        record['isolated_save_removed'] = not data.exists()
        (out/'run.json').write_text(json.dumps(record, indent=2)+'\n')


if __name__ == '__main__':
    main()
