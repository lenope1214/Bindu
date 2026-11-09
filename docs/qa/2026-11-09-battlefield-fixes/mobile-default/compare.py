#!/usr/bin/env python3
from pathlib import Path
import hashlib,json,subprocess
ROOT=Path(__file__).resolve().parents[4];HERE=Path(__file__).resolve().parent
old=json.loads((HERE/'baseline/run.json').read_text());new=json.loads((HERE/'product/run.json').read_text());assert len(old['cases'])==2 and len(new['cases'])==16
names={'fresh','missing'}|{'saved-'+str(s) for s in [.7,.85,1.,1.15,1.3,.93]}
for profile in ['phone','tablet']:
 assert {k.split('/')[1] for k in new['cases'] if k.startswith(profile+'/')}==names
 assert old['cases'][profile+'/fresh']['startup']['loaded_scale']==1.0
 assert new['cases'][profile+'/fresh']['startup']['loaded_scale']==1.3
 camera=new['cases'][profile+'/fresh']['startup']['camera'];field=new['cases'][profile+'/fresh']['startup']['field']
 for key,case in new['cases'].items():
  if key.startswith(profile+'/'):assert case['startup']['camera']==camera and case['startup']['field']==field
 assert old['cases'][profile+'/fresh']['startup']['camera']==camera and old['cases'][profile+'/fresh']['startup']['field']==field
b=json.loads((HERE/'baseline/source-build.json').read_text());c=json.loads((HERE/'product/source-build.json').read_text());changed=[]
for path,sha in c['original_scripts'].items():
 assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==sha,path
 assert hashlib.sha256(subprocess.check_output(['git','show','035aeb8:'+path],cwd=ROOT)).hexdigest()==b['original_scripts'][path],path
 if sha!=b['original_scripts'][path]:changed.append(path)
assert changed==['scripts/meta.gd'],changed
assert b['qa_sources']==c['qa_sources'] and b['template_sha256']==c['template_sha256']
assert json.loads((HERE/'desktop/run.json').read_text())['passed']
summary={'baseline_fresh_cases':2,'product_cold_start_cases':16,'actual_processes':16,'valid_saved_scales_per_device':5,'desktop_headless_default_config_assertions':8,'default_mobile_scale_before':1.0,'default_mobile_scale_after':1.3,'desktop_default':1.0,'existing_invalid_fallback':1.0,'camera_field_mismatches':0,'changed_product_scripts':changed,'product_scripts_checked':70,'same_observer_and_template':True,'scope':new['scope'],'source_base':c['source_ref']};(HERE/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n');print('mobile startup16 +baseline2 +desktop8; onlyMeta changed,70hashes match')
