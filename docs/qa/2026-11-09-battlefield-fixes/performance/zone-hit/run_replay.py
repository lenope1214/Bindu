#!/usr/bin/env python3
"""Compare frozen full combat, delayed state and RNG with an inert-helper candidate."""
from pathlib import Path
import argparse,hashlib,importlib.util,json,os,shutil,tempfile,uuid
from candidate import ROOT,BASELINE,frozen,transform

def module(name,path):
    spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m

def main():
    p=argparse.ArgumentParser();p.add_argument('--output',required=True,type=Path);p.add_argument('--mutant',action='store_true');p.add_argument('--product',action='store_true');a=p.parse_args()
    out=a.output.resolve();out.mkdir(parents=True,exist_ok=True);assert not any(out.iterdir())
    old=module('hit_replay',Path(__file__).resolve().parent.parent/'hit-factors/run_replay.py');h=old.helper
    result={'baseline':BASELINE,'scope':'Actual full combat parity and extended delayed/mark/mirror state at 1e-5 plus subsequent global RNG. Not every field/bitwise proof.','variants':{}}
    suites=['basic','hit_traits','deaths','triples']
    for variant in ['baseline','candidate']+(['mutant'] if a.mutant else []):
        name='BinduToolsInertReplay'+uuid.uuid4().hex;data=Path.home()/'Library/Application Support/Godot/app_userdata'/name
        case=out/variant;case.mkdir();record={'suites':{},'product_source_sha256':{}}
        with tempfile.TemporaryDirectory(prefix='bindu-inert-replay-') as directory:
            project=Path(directory);h.copy_project(project,name)
            for path in ['scripts/tower.gd','scripts/share.gd']:
                source=frozen(path) if not a.product or variant=='baseline' else (ROOT/path).read_text()
                if variant!='baseline' and not a.product:source=transform(path,source,variant=='mutant')
                record['product_source_sha256'][path]=hashlib.sha256(source.encode()).hexdigest();(project/path).write_text(source)
            try:
                for suite in (['hit_traits'] if variant=='mutant' else suites):
                    harness=project/'tools/preview_parity_check.gd';harness.write_text(old.instrument((ROOT/'tools/preview_parity_check.gd').read_text(),suite=='triples'))
                    h.checked([h.GODOT,'--headless','--import','--path',directory],case/(suite+'-import.log'))
                    trace=case/(suite+'-traces.json');command=[h.GODOT,'--headless','--audio-driver','Dummy','--path',directory,'-s','tools/preview_parity_check.gd','--','unused','1.0','pc','hit_traits' if suite=='triples' else suite]
                    h.checked(command,case/(suite+'.log'),env={**os.environ,'BINDU_HIT_TRACE':str(trace)})
                    rows=json.loads(trace.read_text());expected={'basic':300,'hit_traits':450,'deaths':45,'triples':90}[suite];assert len(rows)==expected
                    record['suites'][suite]={'cases':len(rows),'samples':sum(len(row['states']) for row in rows),'trace_sha256':hashlib.sha256(trace.read_bytes()).hexdigest(),'command':command};print(variant,suite,len(rows),flush=True)
            finally:shutil.rmtree(data,ignore_errors=True)
        record['temporary_project_removed']=not project.exists();record['isolated_save_removed']=not data.exists();result['variants'][variant]=record
    for suite in suites:
        before=json.loads((out/'baseline'/(suite+'-traces.json')).read_text());after=json.loads((out/'candidate'/(suite+'-traces.json')).read_text());assert before==after,suite+' differs'
    result['equal_cases']=885;result['equal_samples']=10620
    if a.mutant:
        baseline=json.loads((out/'baseline/hit_traits-traces.json').read_text());mutant=json.loads((out/'mutant/hit_traits-traces.json').read_text());result['mutant_detected_cases']=[x['pattern']+'/'+x['label'] for x,y in zip(baseline,mutant) if x!=y];assert result['mutant_detected_cases']
    (out/'run.json').write_text(json.dumps(result,indent=2)+'\n');print('INERT REPLAY 885cases 10620samples equal; mutants',len(result.get('mutant_detected_cases',[])))

if __name__=='__main__':main()
