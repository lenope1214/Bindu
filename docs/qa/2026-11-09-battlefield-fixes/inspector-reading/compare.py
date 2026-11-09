#!/usr/bin/env python3
from pathlib import Path
import argparse,hashlib,json,subprocess
ROOT=Path(__file__).resolve().parents[4]

def main():
 p=argparse.ArgumentParser();p.add_argument('--baseline',type=Path,required=True);p.add_argument('--product',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 b=json.loads((a.baseline/'run.json').read_text());c=json.loads((a.product/'run.json').read_text());assert b['observed_cases']==16 and c['observed_cases']==152
 assert b['violating_cases']>0 and c['violating_cases']==0
 changed=[];mismatches=[];checks=0
 for key,before in b['cases'].items():
  after=c['cases'][key]
  for field in ['metrics','camera','field','picks','towers']:
   checks+=1
   if before[field]!=after[field]:mismatches.append([key,field])
 assert not mismatches,mismatches
 for path,sha in json.loads((a.product/'source-build.json').read_text())['original_scripts'].items():assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==sha,path
 old=json.loads((a.baseline/'source-build.json').read_text());new=json.loads((a.product/'source-build.json').read_text())
 assert old['qa_sources']==new['qa_sources'] and old['template_sha256']==new['template_sha256']
 for path,sha in old['original_scripts'].items():
  assert hashlib.sha256(subprocess.check_output(['git','show',old['source_ref']+':'+path],cwd=ROOT)).hexdigest()==sha,path
  if sha!=new['original_scripts'][path]:changed.append(path)
 assert sorted(changed)==['scripts/card_dock.gd','scripts/features/frame.gd','scripts/info_panel.gd'],changed
 assert set(c['native_actions'])=={'phone','tablet'}
 record={'baseline_cases':16,'baseline_violating_cases':b['violating_cases'],'product_cases':152,'product_violating_cases':0,'paired_cases':16,'paired_state_comparisons':checks,'mismatches':mismatches,'actual_drawn_metrics_per_case':4,'matched_qa_and_engine':True,'baseline_ref':old['source_ref'],'changed_product_scripts':changed,'checked_current_product_scripts':len(new['original_scripts']),'native_actions':c['native_actions'],'scope':c['scope']}
 a.output.write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n');print(json.dumps({k:v for k,v in record.items() if k!='native_actions'},ensure_ascii=False))

if __name__=='__main__':main()
