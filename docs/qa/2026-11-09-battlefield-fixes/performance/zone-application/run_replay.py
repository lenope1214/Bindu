#!/usr/bin/env python3
"""Real combat parity/RNG traces for only the affinity mask memo candidate."""
from pathlib import Path
import argparse,hashlib,json,os,shutil,tempfile,uuid
from run_cache import BASELINE,ROOT,helper,candidate_share,frozen,module
instrument=module('hit_trace_helpers',Path(__file__).resolve().parent.parent/'hit-factors/run_replay.py').instrument

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--mutant', action='store_true')
    parser.add_argument('--triples-only', action='store_true')
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    assert not (out / 'run.json').exists(), 'Use a fresh output directory'
    record = {'baseline_ref': BASELINE, 'precision': 'Existing parity fields plus delayed timers, repeat cooldown, gore source validity and mirror state; floats/positions normalized1e-5. Not every runtime field.', 'variants': {}}
    suites = ['hit_traits'] if args.triples_only else ['basic', 'context', 'hit_traits', 'deaths']
    expected_cases = {'basic':300,'context':225, 'hit_traits':90 if args.triples_only else 450, 'deaths':45}
    for variant in ['baseline', 'candidate'] + (['mutant'] if args.mutant else []):
        case_out = out / variant
        case_out.mkdir(exist_ok=True)
        name = 'BinduToolsHitReplay' + uuid.uuid4().hex
        userdata = Path.home() / 'Library/Application Support/Godot/app_userdata' / name
        with tempfile.TemporaryDirectory(prefix='bindu-hit-replay-') as tmp:
            project = Path(tmp)
            helper.copy_project(project, name)
            share = project / 'scripts/share.gd'
            old = frozen('scripts/share.gd')
            share.write_text(old if variant == 'baseline' else candidate_share(old, variant == 'mutant'))
            harness = project / 'tools/preview_parity_check.gd'
            harness.write_text(instrument(harness.read_text(), args.triples_only))
            helper.checked([helper.GODOT, '--headless', '--import', '--path', tmp], case_out / 'import.log')
            variant_record = {'share_sha256': hashlib.sha256(share.read_bytes()).hexdigest(), 'suites': {}}
            try:
                for suite in (['hit_traits'] if variant == 'mutant' else suites):
                    trace = case_out / (suite + '-traces.json')
                    command = [helper.GODOT, '--headless', '--audio-driver', 'Dummy', '--path', tmp, '-s', 'tools/preview_parity_check.gd', '--', 'unused', '1.0', 'pc', suite]
                    helper.checked(command, case_out / (suite + '.log'), env={**os.environ, 'BINDU_HIT_TRACE': str(trace)})
                    data = json.loads(trace.read_text())
                    expected = expected_cases[suite]
                    assert len(data) == expected
                    variant_record['suites'][suite] = {'cases':len(data),'samples':sum(len(row['states']) for row in data),'trace_sha256':hashlib.sha256(trace.read_bytes()).hexdigest(),'command':command}
                    print(variant, suite, len(data), flush=True)
            finally:
                shutil.rmtree(userdata, ignore_errors=True)
                variant_record['isolated_save_removed'] = not userdata.exists()
        variant_record['temporary_project_removed'] = not project.exists()
        record['variants'][variant] = variant_record
    for suite in suites:
        before = json.loads((out / 'baseline' / (suite + '-traces.json')).read_text())
        after = json.loads((out / 'candidate' / (suite + '-traces.json')).read_text())
        assert before == after, suite + ': state/RNG differs'
    record['equal_suites'] = suites
    record['cases'] = sum(expected_cases[suite] for suite in suites)
    record['samples'] = record['cases'] * 12
    if args.mutant:
        baseline = json.loads((out / 'baseline/hit_traits-traces.json').read_text())
        mutant = json.loads((out / 'mutant/hit_traits-traces.json').read_text())
        differences = [a['pattern'] + '/' + a['label'] for a, b in zip(baseline, mutant) if a != b]
        assert differences, 'Mutant not detected'
        record['mutant_detected_cases'] = differences
    (out / 'run.json').write_text(json.dumps(record, indent=2) + '\n')
    print('REPLAY',record['cases'],'cases',record['samples'],'samples equal; mutant cases',len(record.get('mutant_detected_cases',[])))


if __name__ == '__main__':
    main()
