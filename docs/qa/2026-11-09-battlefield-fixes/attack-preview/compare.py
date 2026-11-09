#!/usr/bin/env python3
from pathlib import Path
import argparse,hashlib,json,subprocess
ROOT=Path(__file__).resolve().parents[4]
p=argparse.ArgumentParser();p.add_argument('--baseline',type=Path,required=True);p.add_argument('--product',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
b=json.loads((a.baseline/'run.json').read_text());c=json.loads((a.product/'run.json').read_text());assert len(c['cases'])==40 and c['violating_cases']==0 and set(c['native_actions'])=={'phone','tablet'}
checks=0
for key,after in c['cases'].items():
 before=b['cases'][key]
 for field in ['metrics','camera','field','picks','towers']:
  assert before[field]==after[field],(key,field);checks+=1
old=json.loads((a.baseline/'source-build.json').read_text());new=json.loads((a.product/'source-build.json').read_text());changed=[]
for path,sha in new['original_scripts'].items():
 assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==sha,path
 assert hashlib.sha256(subprocess.check_output(['git','show','1589c4a:'+path],cwd=ROOT)).hexdigest()==old['original_scripts'][path],path
 if sha!=old['original_scripts'][path]:changed.append(path)
assert sorted(changed)==['scripts/attack_preview.gd','scripts/card_dock.gd','scripts/info_panel.gd'],changed
assert old['template_sha256']==new['template_sha256']
prior=(ROOT/'docs/qa/2026-11-09-battlefield-fixes/inspector-reading/observer.gd').read_text();current=(ROOT/'docs/qa/2026-11-09-battlefield-fixes/attack-preview/observer.gd').read_text();extra='"preview_rect":rect_data(main.card_dock.pic.attack_preview.get_global_rect()),"preview_caption":rect_data(main.card_dock.pic.attack_preview.caption.get_global_rect()),"preview_texture_size":str(main.card_dock.pic.attack_preview.viewport.size),';assert current.replace(extra,'')==prior
record={'paired_cases':40,'state_comparisons':checks,'mismatches':0,'geometry_text_ratio_caption_violations':0,'product_script_hashes_checked':len(new['original_scripts']),'changed_scripts':changed,'baseline_commit':'1589c4a','same_engine_template':True,'probe_change':'Only three read-only preview/caption/texture-size fields added; same fixture and actual draw recorder. Byte comparison verified.','native_actions':c['native_actions'],'scope':c['scope']};a.output.write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n');print('PREVIEW comparison40cases200fields,70scripts,0violations')
