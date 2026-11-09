#!/usr/bin/env python3
"""Record bounded fuzz inputs/layout notifications in an isolated QA copy only."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import os
import re
import selectors
import shutil
import subprocess
import tempfile
import time
import uuid

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def observe_process(command, log, environment):
    """Drain and cap output; terminate only this owned child on an observed fault."""
    started = time.monotonic()
    reason = None
    stop_at = None
    total = 0
    retained = 0
    overlap = b''
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=environment)
    selector = selectors.DefaultSelector()
    selector.register(process.stdout, selectors.EVENT_READ)
    try:
        with log.open('wb') as stream:
            while selector.get_map():
                if time.monotonic() - started > 180 and process.poll() is None:
                    reason = reason or 'deadline180s'
                    stop_at = stop_at or time.monotonic()
                    process.terminate()
                for key, _ in selector.select(.05):
                    chunk = os.read(key.fileobj.fileno(), 65536)
                    if not chunk:
                        selector.unregister(key.fileobj)
                        continue
                    total += len(chunk)
                    prefix = chunk[:max(0, 1024 * 1024 - retained)]
                    stream.write(prefix)
                    retained += len(prefix)
                    if b'Message queue out of memory' in overlap + chunk:
                        reason = reason or 'observed_queue_failure_stop_before_statistics_flood'
                        stop_at = stop_at or time.monotonic()
                        if process.poll() is None:
                            process.terminate()
                    overlap = chunk[-64:]
                if stop_at and time.monotonic() - stop_at > 5 and process.poll() is None:
                    process.kill()
        code = process.wait(timeout=5)
    finally:
        selector.close()
        process.stdout.close()
        if process.poll() is None:
            process.kill()
            process.wait()
    return {'pid':process.pid, 'exit':code, 'stop_reason':reason,
            'output_bytes':total, 'retained_bytes':retained,
            'owned_process_terminal':process.poll() is not None,
            'elapsed_seconds':time.monotonic() - started}


def summarize_trace(path):
    counts = {}
    types = {}
    last = None
    first = None
    peak = 0
    order_ok = True
    last_input = 0
    first_samples = []
    with path.open() as stream:
        for line in stream:
            row = json.loads(line)
            kind = row['kind']
            counts[kind] = counts.get(kind, 0) + 1
            peak = max(peak, row.get('state', {}).get('queue_peak_bytes', 0))
            if kind == 'start':
                first = row
            if kind == 'done':
                last = row
            if kind == 'input':
                order_ok &= row['sequence'] == last_input + 1
                last_input = row['sequence']
                types[row['type']] = types.get(row['type'], 0) + 1
                if len(first_samples) < 8:
                    first_samples.append(row)
    return {'counts':counts, 'input_types':types, 'input_sequence_contiguous':order_ok,
            'peak_message_buffer_bytes':peak, 'start':first, 'done':last,
            'first_input_samples':first_samples, 'bytes':path.stat().st_size, 'sha256':sha(path)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--seeds', type=int, nargs='+', default=[2, 4])
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    assert not any(out.iterdir())
    spec = importlib.util.spec_from_file_location('queue_trace_copy', HERE.parent / 'performance/guard-range/run_replay.py')
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    record = {'scope':'QA-copy-only hooks; product scripts unchanged except blank server URLs in copied online_config. Observer changes timing. Recorded logical inputs/layout notifications are not exact gameplay replay.',
              'product_sha256':{str(p.relative_to(ROOT)):sha(p) for p in (ROOT/'scripts').rglob('*.gd')},
              'runs':[]}
    try:
        for seed in args.seeds:
            case = out / str(seed)
            case.mkdir()
            name = 'BinduToolsMessageQueueTrace' + uuid.uuid4().hex
            data = Path.home() / 'Library/Application Support/Godot/app_userdata' / name
            row = {'seed':seed}
            record['runs'].append(row)
            try:
                with tempfile.TemporaryDirectory(prefix='bindu-message-trace-') as directory:
                    project = Path(directory)
                    helper.copy_project(project, name)
                    virtual = project / 'tools/virtual_input.gd'
                    fuzz = project / 'tools/fuzz.gd'
                    row['original_virtual_input_sha256'] = sha(virtual)
                    row['original_fuzz_sha256'] = sha(fuzz)
                    text = virtual.read_text()
                    old = 'static func send(event: InputEvent) -> void:\n'
                    assert text.count(old) == 1
                    virtual.write_text(text.replace(old, 'static var qa_trace: Callable\n\n' + old + '\tif qa_trace.is_valid(): qa_trace.call(event)\n'))
                    text = fuzz.read_text()
                    old = '\t\tmain.cancel_btn.emit_signal("pressed")'
                    assert text.count(old) == 1
                    fuzz.write_text(text.replace('var main\n', 'var main\nvar qa_cancel: Callable\n', 1).replace(old, '\t\tif qa_cancel.is_valid(): qa_cancel.call()\n' + old))
                    shutil.copy2(HERE/'trace.gd', project/'tools/message_queue_trace.gd')
                    shutil.copy2(HERE/'fuzz_trace.gd', project/'tools/fuzz_trace.gd')
                    row['instrumented_sources'] = {str(p.relative_to(project)):sha(p) for p in [virtual, fuzz, project/'tools/message_queue_trace.gd', project/'tools/fuzz_trace.gd']}
                    helper.checked([helper.GODOT, '--headless', '--import', '--path', directory], case/'import.log')
                    trace = case/'trace.jsonl'
                    command = [helper.GODOT, '--headless', '--fixed-fps', '60', '--path', directory, '-s', 'tools/fuzz_trace.gd', '--', str(seed), '3000']
                    row['command'] = command
                    row.update(observe_process(command, case/'raw.log', {**os.environ, 'BINDU_QUEUE_TRACE':str(trace)}))
                    raw = (case/'raw.log').read_text(errors='replace')
                    row['frames_done'] = 'FUZZ DONE frames=3000' in raw
                    row['queue_failure'] = 'Message queue out of memory' in raw
                    row['runtime_errors'] = re.findall(r'^(?:SCRIPT ERROR|ERROR:).*$', raw, re.M)[:6]
                    if trace.exists():
                        row['trace'] = summarize_trace(trace)
                    row['success'] = row['exit'] == 0 and row['frames_done'] and not row['queue_failure'] and not row['runtime_errors']
                    if row['success']:
                        observed = row['trace']
                        assert observed['counts']['frame_before'] == observed['counts']['frame_after'] == 3000
                        assert observed['counts']['input'] == observed['done']['events'] > 0
                        assert observed['input_sequence_contiguous']
                        assert observed['counts'].get('direct_cancel', 0) == observed['done']['direct_cancels']
                        assert 'trace_limit' not in observed['counts']
                    print('TRACE', seed, 'exit', row['exit'], 'done', row['frames_done'], 'queue', row['queue_failure'], flush=True)
            finally:
                shutil.rmtree(data, ignore_errors=True)
                row['isolated_save_removed'] = not data.exists()
                row['temporary_project_removed'] = not project.exists()
                (case/'result.json').write_text(json.dumps(row, indent=2) + '\n')
            assert row['success'], (seed, row.get('runtime_errors'), row.get('stop_reason'))
    finally:
        (out/'run.json').write_text(json.dumps(record, indent=2) + '\n')


if __name__ == '__main__':
    main()
