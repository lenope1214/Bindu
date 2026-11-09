#!/usr/bin/env python3
"""Reuse release feedback checks with a pre-export source hash manifest."""
from pathlib import Path
import argparse,hashlib,json,subprocess
from run_cache import ROOT,module

driver=module('feedback_release',Path(__file__).resolve().parent.parent/'feedback-density/run_release.py')


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    prepare_original=driver.helper.prepare
    def prepare(project,name,stack):
        prepare_original(project,name,stack)
        hashes={str(p.relative_to(project)):hashlib.sha256(p.read_bytes()).hexdigest()for p in (project/'scripts').rglob('*.gd')}
        assert hashes['scripts/share.gd']==hashlib.sha256((ROOT/'scripts/share.gd').read_bytes()).hexdigest()
        (args.output.resolve()/'source-before-export.json').write_text(json.dumps({'scope':'Product scripts copied unchanged except empty operational URLs; captured inside prepare before import/export. Runtime original res source SHA is not claimed.','head_before_task_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'source_hashes':hashes},indent=2)+'\n')
    driver.helper.prepare=prepare
    driver.main()


if __name__=='__main__':main()
