import urllib.request,io,zipfile,json,struct,zlib,hashlib,argparse
from pathlib import Path
URL='https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz'
parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
OUT=args.output.resolve();OUT.mkdir(parents=True,exist_ok=True);assert not any(OUT.iterdir())
class Remote(io.RawIOBase):
 def __init__(self):
  r=urllib.request.urlopen(urllib.request.Request(URL,method='HEAD'));self.url=r.url;self.size=int(r.headers['Content-Length']);self.pos=0;self.cache=[]
 def seekable(self):return True
 def readable(self):return True
 def tell(self):return self.pos
 def seek(self,n,whence=0):
  self.pos=n if whence==0 else self.pos+n if whence==1 else self.size+n
  return self.pos
 def read(self,n=-1):
  n=min(n if n>=0 else self.size-self.pos,self.size-self.pos)
  if n<=0:return b''
  start=self.pos;end=start+n
  for a,data in self.cache:
   if a<=start and end<=a+len(data):self.pos=end;return data[start-a:end-a]
  request_end=min(self.size,end+1024*1024)
  req=urllib.request.Request(self.url,headers={'Range':f'bytes={start}-{request_end-1}'})
  with urllib.request.urlopen(req) as r:
   assert r.status==206 and r.headers.get('Content-Range','').startswith(f'bytes {start}-'),(r.status,dict(r.headers))
   data=r.read()
  assert len(data)==request_end-start
  self.cache.append((start,data));self.pos=end;return data[:n]
remote=Remote()
with zipfile.ZipFile(remote) as archive:
 matches=[i for i in archive.infolist() if 'ios' in i.filename.lower()]
 print('iOS template entries',[(m.filename,m.file_size,m.compress_size) for m in matches],flush=True)
 item=next(m for m in matches if m.filename.endswith('ios.zip'))
 remote.seek(item.header_offset);header=remote.read(30);fields=struct.unpack('<IHHHHHIIIHH',header);assert fields[0]==0x04034b50
 start=item.header_offset+30+fields[-2]+fields[-1]
 req=urllib.request.Request(remote.url,headers={'Range':f'bytes={start}-{start+item.compress_size-1}'})
 with urllib.request.urlopen(req) as r:
  assert r.status==206
  compressed=r.read()
 assert len(compressed)==item.compress_size
 data=zlib.decompress(compressed,-15) if item.compress_type==zipfile.ZIP_DEFLATED else compressed
 assert len(data)==item.file_size and zlib.crc32(data)&0xffffffff==item.CRC
 (OUT/'ios.zip').write_bytes(data)
 record={'official_release_url':URL,'outer_size':remote.size,'entry':item.filename,'compressed_bytes':item.compress_size,'bytes':len(data),'entry_crc32':format(item.CRC,'08x'),'ios_zip_sha256':hashlib.sha256(data).hexdigest(),'full_tpz_sha256_verified':False}
 (OUT/'template-source.json').write_text(json.dumps(record,indent=2)+'\n')
 print('Downloaded/CRC verified',record,flush=True)
 with zipfile.ZipFile(io.BytesIO(data)) as inner:print('Simulator slices',[s for s in inner.namelist() if 'simulator' in s][:15],flush=True)
