#!/usr/bin/env python3
"""Crop observed inspector rectangles for visual review; leave originals unchanged."""
from pathlib import Path
import argparse,json,re,struct,subprocess,tempfile
p=argparse.ArgumentParser();p.add_argument('--native-root',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--profile',choices=['phone','tablet']);a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True);assert not any(a.output.iterdir())
groups={}
for f in sorted(a.native_root.glob((a.profile or '*')+'/*/state.json')):
 d=json.loads(f.read_text());r=d['reading']['inspector'];w,h=map(float,re.findall(r'-?\d+(?:\.\d+)?',d['viewport'])[-2:]);png=f.with_name('screen.png');pw,ph=struct.unpack('>II',png.read_bytes()[16:24]);profile=f.parent.parent.name;parts=d['stage'].split('|');group=profile+'-'+(parts[0] if parts[2]=='wave' else 'ready-choose')
 groups.setdefault(group,[]).append({'label':f.parent.name,'path':str(png.resolve()),'crop':[max(0,(r[0]-4)/w*pw),max(0,(r[1]-4)/h*ph),(r[2]+8)/w*pw,(r[3]+8)/h*ph]})
with tempfile.TemporaryDirectory(prefix='bindu-contact-compiler-') as t:
 exe=str(Path(t)/'contact');subprocess.run(['swiftc',str(Path(__file__).with_name('contact_sheet.swift')),'-o',exe],check=True)
 for name,rows in groups.items():
  source=a.output/(name+'.json');source.write_text(json.dumps(rows,indent=2)+'\n');subprocess.run([exe,str(source),str(a.output/(name+'.png'))],check=True)
print('Contact sheets',len(groups),'observed inspectors',sum(map(len,groups.values())))
