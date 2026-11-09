#!/usr/bin/env python3
"""Compare source dictionary reads in a save/network-isolated QA project."""
from pathlib import Path
import argparse,hashlib,importlib.util,json,shutil,tempfile,uuid

ROOT=Path(__file__).resolve().parents[5]
LOCAL='''
static func qa_local_els(tw: Object) -> Dictionary:
	var effective: Dictionary = tw.eff
	return effective if not effective.is_empty() else tw.elements
'''
TYPED='''
static func qa_typed_els(tw: Object) -> Dictionary:
	var tower := tw as Tower
	if tower != null:
		return tower.eff if not tower.eff.is_empty() else tower.elements
	return tw.eff if not tw.eff.is_empty() else tw.elements
'''

def main():
    p=argparse.ArgumentParser();p.add_argument('--output',required=True,type=Path);a=p.parse_args()
    out=a.output.resolve();out.mkdir(parents=True,exist_ok=True);assert not any(out.iterdir())
    spec=importlib.util.spec_from_file_location('copy_helper',Path(__file__).resolve().parent.parent/'guard-range/run_replay.py');h=importlib.util.module_from_spec(spec);spec.loader.exec_module(h)
    name='BinduToolsEffectRead'+uuid.uuid4().hex;data=Path.home()/'Library/Application Support/Godot/app_userdata'/name
    record={'contract':'Exact effective/fallback selection and returned dictionary alias for current plain Tower/OtherTower fields. Isolated function CPU with common dynamic call overhead; no whole-frame or physical latency claim.','product_edit':False}
    with tempfile.TemporaryDirectory(prefix='bindu-effect-read-') as directory:
        project=Path(directory);h.copy_project(project,name)
        source=project/'scripts/share.gd';record['original_share_sha256']=hashlib.sha256(source.read_bytes()).hexdigest();source.write_text(source.read_text()+LOCAL+TYPED)
        (out/'candidate-functions.txt').write_text(LOCAL+TYPED)
        record['qa_share_sha256']=hashlib.sha256(source.read_bytes()).hexdigest();record['tool_sha256']=hashlib.sha256((project/'tools/battlefield_effect_read_check.gd').read_bytes()).hexdigest()
        try:
            h.checked([h.GODOT,'--headless','--import','--path',directory],out/'import.log')
            command=[h.GODOT,'--headless','--audio-driver','Dummy','--path',directory,'-s','tools/battlefield_effect_read_check.gd','--',str(out)];record['command']=command
            text=h.checked(command,out/'check.log');result=json.loads((out/'results.json').read_text());assert result['failures']==0
            record['result']=result;record['exit']=0
        finally:shutil.rmtree(data,ignore_errors=True)
    record['temporary_project_removed']=not project.exists();record['isolated_save_removed']=not data.exists();(out/'run.json').write_text(json.dumps(record,indent=2)+'\n')
    print(json.dumps(result,indent=2))

if __name__=='__main__':main()
