#!/usr/bin/env python3
"""Frozen full-hit and apply references for effective/fallback/extra boundaries."""
from pathlib import Path
import argparse,hashlib,importlib.util,json,shutil,tempfile,uuid
from candidate import ROOT,BASELINE,frozen,transform

def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--product',action='store_true');a=p.parse_args()
    out=a.output.resolve();out.mkdir(parents=True,exist_ok=True);assert not any(out.iterdir())
    spec=importlib.util.spec_from_file_location('copy_helper',Path(__file__).resolve().parent.parent/'guard-range/run_replay.py');h=importlib.util.module_from_spec(spec);spec.loader.exec_module(h)
    name='BinduToolsInertDirect'+uuid.uuid4().hex;userdata=Path.home()/'Library/Application Support/Godot/app_userdata'/name
    record={'baseline':BASELINE,'contract':'Actual direct hit and Share.apply, same live eff/base/extra dictionaries, zero/high levels and0/.2/1.2strength. Exact selected raw fields/source and nextRNG comparison; no normalization.','source_sha256':{}}
    with tempfile.TemporaryDirectory(prefix='bindu-inert-direct-') as directory:
        project=Path(directory);h.copy_project(project,name)
        for path in ['scripts/tower.gd','scripts/share.gd']:
            source=(ROOT/path).read_text() if a.product else transform(path,frozen(path));(project/path).write_text(source);record['source_sha256'][path]=hashlib.sha256(source.encode()).hexdigest()
        tower=frozen('scripts/tower.gd');start=tower.index('func hit(o: Orb,');stop=tower.index('\n\n\n# ----------',start);(project/'tools/qa_reference_tower.gd').write_text('extends Tower\n'+tower[start:stop]+'\n')
        share=frozen('scripts/share.gd');start=share.index('static func apply(');stop=share.index('\n\n## ',start);reference=share[start:stop].replace('static func apply(','static func qa_reference_apply(',1);file=project/'scripts/share.gd';file.write_text(file.read_text()+'\n'+reference+'\n')
        try:
            h.checked([h.GODOT,'--headless','--import','--path',directory],out/'import.log')
            command=[h.GODOT,'--headless','--audio-driver','Dummy','--path',directory,'-s','tools/battlefield_inert_effect_check.gd','--',str(out)];record['command']=command
            h.checked(command,out/'check.log');record['result']=json.loads((out/'results.json').read_text());assert record['result']['cases']==48 and record['result']['failures']==0;record['exit']=0
        finally:shutil.rmtree(userdata,ignore_errors=True)
    record['temporary_project_removed']=not project.exists();record['isolated_save_removed']=not userdata.exists();(out/'run.json').write_text(json.dumps(record,indent=2)+'\n');print('INERT DIRECT48 cases equal')

if __name__=='__main__':main()
