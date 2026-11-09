#!/usr/bin/env python3
"""Local release feedback checks with reduced effects enabled and source hashes."""
from pathlib import Path
import argparse,hashlib,json,subprocess,sys
from run_profile import ROOT,module

feedback=Path(__file__).resolve().parent.parent/'feedback-density'
sys.path.insert(0,str(feedback))
driver=module('feedback_release_low_fx',feedback/'run_release.py')
sys.path.remove(str(feedback))


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    original_prepare=driver.helper.prepare
    original_run=driver.helper.run
    def prepare(project,name,stack):
        original_prepare(project,name,stack)
        hashes={str(p.relative_to(project)):hashlib.sha256(p.read_bytes()).hexdigest()for p in (project/'scripts').rglob('*.gd')}
        assert hashes['scripts/features/field_view.gd']==hashlib.sha256((ROOT/'scripts/features/field_view.gd').read_bytes()).hexdigest()
        (args.output.resolve()/'source-before-export.json').write_text(json.dumps({'scope':'Product sources unchanged except blank operational URLs; QA harness enables Meta.fx_low. Captured before import/export, not a runtime res source SHA.','head_before_task_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'source_hashes':hashes},indent=2)+'\n')
    def run(command,log,**kwargs):
        if '--import'in command:
            project=Path(command[command.index('--path')+1]);harness=project/'qa/battlefield_feedback_check.gd';source=harness.read_text()
            marker='Meta.fx_low = false';assert source.count(marker)==1
            source=source.replace(marker,'Meta.fx_low = true',1);harness.write_text(source)
            (args.output.resolve()/'qa-mode.json').write_text(json.dumps({'reduced_effects':True,'scope':'QA setup only; product FX code unchanged.','harness_sha256':hashlib.sha256(source.encode()).hexdigest()},indent=2)+'\n')
        return original_run(command,log,**kwargs)
    driver.helper.prepare=prepare
    driver.helper.run=run
    driver.main()


if __name__=='__main__':main()
