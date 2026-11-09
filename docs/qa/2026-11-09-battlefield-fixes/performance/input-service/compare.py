#!/usr/bin/env python3
"""Validate four identical-harness ABBA runs and publish compact raw references."""
from pathlib import Path
import argparse
import hashlib
import json
from candidate import ROOT, BASELINE, frozen, transform


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def value_sha(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def reference(path):
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--runs', nargs=2, type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.runs = [p.resolve() for p in args.runs]
    assert not args.output.exists(), 'Do not overwrite a prior result'
    records = [json.loads((p / 'run.json').read_text()) for p in args.runs]
    assert all('failure' not in r and r['baseline'] == BASELINE for r in records)
    runs = [run for record in records for run in record['runs']]
    assert [r['variant'] for r in runs] == ['baseline', 'candidate', 'candidate', 'baseline']
    assert len({r['harness_sha256'] for r in runs}) == 1
    paths = set(runs[0]['product_hashes'])
    assert len(paths) == 70
    before = runs[0]['product_hashes']
    for run in runs:
        assert run['exit'] == 0 and run['temporary_project_removed'] and run['isolated_save_removed']
        expected = set() if run['variant'] == 'baseline' else {'scripts/features/frame.gd'}
        assert {p for p in paths if before[p] != run['product_hashes'][p]} == expected
        if run['variant'] == 'candidate':
            assert run['product_hashes']['scripts/features/frame.gd'] == hashlib.sha256(transform(frozen('scripts/features/frame.gd')).encode()).hexdigest()
        assert run['measurements']['failures'] == 0 and run['measurements']['ui'] == 0
    root_hashes = {p: sha(ROOT / p) for p in paths}
    assert {p for p in paths if before[p] != root_hashes[p]} == {'scripts/online_config.gd'}
    assert all((ROOT / p).read_text() == frozen(p) for p in paths), 'Product checkout drifted from frozen baseline'
    for reduced in [False, True]:
        rows = [next(row for row in r['measurements']['no_input'] if row['fx_low'] == reduced) for r in runs]
        for key in ['population', 'traces', 'next_rng', 'steps', 'game_seconds']:
            assert all(row[key] == rows[0][key] for row in rows), (reduced, key)
    first = runs[0]['measurements']['probes']
    for run in runs:
        for a, b in zip(first, run['measurements']['probes']):
            assert a['pre_state'] == b['pre_state'] and a['pre_next_rng'] == b['pre_next_rng'], (run['variant'], b['label'])
            assert b['posted_during_compute']
            if b['label'] == 'pause':
                assert b['raw_menu_inside_viewport'] and b['raw_pause_label_inside_viewport'] and not b['raw_label_menu_overlap']
                assert b['resume_steps'] == 8
                assert b['event']['dispatch_us'] <= b['event']['paused_us'] <= b['event']['menu_us']
    compact = {'baseline': BASELINE, 'decision': 'prototype_only_not_adopted', 'contract': records[0]['contract'], 'order': 'ABBA across two consecutive commands, same harness/source SHA', 'no_input_equal': True, 'all_probe_start_states_rng_equal': True, 'root_product70_unchanged': root_hashes, 'raw_sources': [], 'runs': [], 'comparisons': []}
    for p in args.runs:
        compact['raw_sources'].append({'path': reference(p), 'run_json_sha256': sha(p / 'run.json')})
    for run in runs:
        result = {k: v for k, v in run.items() if k != 'measurements'}
        data = run['measurements']
        result['environment'] = {k: v for k, v in data.items() if k not in ['probes', 'no_input']}
        result['no_input'] = []
        for row in data['no_input']:
            selected = {k: v for k, v in row.items() if k not in ['traces', 'population']}
            selected.update({'trace_sha256': value_sha(row['traces']), 'population_sha256': value_sha(row['population']), 'live_orb_counts': [x[0] for x in row['population']], 'projectile_counts': [x[1] for x in row['population']], 'zone_counts': [x[2] for x in row['population']]})
            result['no_input'].append(selected)
        result['probes'] = []
        for row in data['probes']:
            selected = {k: v for k, v in row.items() if k != 'pre_state'}
            selected['pre_state_sha256'] = value_sha(row['pre_state'])
            selected['dispatch_steps_after_warmup'] = row['event']['dispatch_sim_id'] - row['pre_state']['sim_id']
            for target in ['paused_us', 'menu_us', 'settings_us']:
                if target in row['event']:
                    selected['queue_to_' + target.removesuffix('_us') + '_ms'] = (row['event'][target] - row['post']['before_parse_us']) / 1000
            result['probes'].append(selected)
        compact['runs'].append(result)
    for reduced in [False, True]:
        values = {v: [next(row for row in run['measurements']['no_input'] if row['fx_low'] == reduced)['main_cpu_ms']['mean'] for run in runs if run['variant'] == v] for v in ['baseline', 'candidate']}
        before = sum(values['baseline']) / 2
        after = sum(values['candidate']) / 2
        compact['comparisons'].append({'fx_low': reduced, **values, 'baseline_mean_ms': before, 'candidate_mean_ms': after, 'delta_percent': (after / before - 1) * 100})
    compact['pause_queue_ranges_ms'] = {v: [min(values), max(values)] for v in ['baseline', 'candidate'] for values in [[p['queue_to_dispatch_ms'] for r in runs if r['variant'] == v for p in r['measurements']['probes'] if p['label'] == 'pause']]}
    args.output.write_text(json.dumps(compact, indent=2) + '\n')
    print(json.dumps({'comparisons': compact['comparisons'], 'pause_queue_ranges_ms': compact['pause_queue_ranges_ms']}, indent=2))


if __name__ == '__main__':
    main()
