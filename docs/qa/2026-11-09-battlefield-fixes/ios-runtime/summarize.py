#!/usr/bin/env python3
"""Validate the complete observed cohort and additional bank/skill invariants."""
from pathlib import Path
import argparse
import hashlib
import json


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--run', type=Path, nargs='+', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    records = {run: json.loads((run / 'run.json').read_text()) for run in args.run}
    stages = ['choose', 'place', 'aim', 'ready', 'wave', 'skill', 'continuous']
    sources = {}
    for run, record in records.items():
        for stage in record['cases']:
            assert stage not in sources, ('Duplicate adopted stage', stage)
            sources[stage] = run
    assert set(sources) == set(stages), 'Incomplete native cohort'
    details = {}
    for stage in stages:
        case = records[sources[stage]]['cases'][stage]
        assert case['passed'] and case['notification_types'] == [2014, 2015, 2016, 2017]
        folder = sources[stage] / stage
        states = {name: json.loads((folder / (name + '.json')).read_text())
                  for name in ['before', 'returned', 'resumed', 'restarted', 'restored']}
        first, returned, resumed, restored = (states[n] for n in ['before', 'returned', 'resumed', 'restored'])
        assert returned['bank_picks'] == first['bank_picks'] and returned['skip_left'] == first['skip_left']
        assert resumed['bank_picks'] == first['bank_picks'] and resumed['skip_left'] == first['skip_left']
        assert restored['bank_picks'] == resumed['saved']['bank_picks']
        assert restored['skip_left'] == resumed['saved']['skip_left']
        # 명시적으로 고른 조준 모드는 유지한다. 재개 버튼은 기술 사용으로 새지 않아야 한다.
        assert returned['skill_arm'] == first['skill_arm'] and resumed['skill_arm'] == first['skill_arm']
        for snapshot in states.values():
            assert snapshot['runtime_log'] and all(
                row['type'] == 1 and (row['code'] == 'BinduIOSQA logger probe' or row['rationale'] == 'BinduIOSQA logger probe')
                for row in snapshot['runtime_log'])
        details[stage] = {'native_driver_checks': case['checks'], 'passed': True,
                          'bank_and_skill_checks': 5, 'initial_phase': first['phase_name'],
                          'restored_phase': restored.get('restoration_events', [restored])[-1]['phase_name'], 'skip_left': first['skip_left'],
                          'bank_picks': first['bank_picks']}
    assert details['continuous']['initial_phase'] == 'WAVE' and details['continuous']['skip_left'] > 0
    result = {'scope': next(iter(records.values()))['scope'], 'cases': details,
              'native_driver_checks': sum(c['native_driver_checks'] for c in details.values()),
              'additional_record_checks': 35, 'runtime_errors': 0, 'unexpected_runtime_warnings': 0,
              'known_warning': 'One intentional BinduIOSQA logger probe per process, not zero warnings',
              'raw_runs': {str(run): hashlib.sha256((run / 'run.json').read_bytes()).hexdigest() for run in records},
              'adoption': 'First six observed cases plus continuous rerun with post-continue READY observer. Product scripts unchanged; QA observer hashes recorded per build.'}
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print('Native cohort:', len(details), 'cases;', result['native_driver_checks'], '+35 checks')


if __name__ == '__main__':
    main()
