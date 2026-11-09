"""One candidate: bypass inert duration/growth helpers using current element keys."""
from pathlib import Path
import subprocess

ROOT=Path(__file__).resolve().parents[5]
BASELINE='b2da5e122b167deee1cbeb584de60d92b6883726'

def frozen(path):return subprocess.check_output(['git','show',BASELINE+':'+path],cwd=ROOT,text=True)

def transform(path,source,mutant=False):
    if path=='scripts/tower.gd':
        start=source.index('func hit(o: Orb,');end=source.index('\n\n\n# ----------',start)
        body=source[start:end]
        for old,new in [
            ('\tvar dm := Share.dur(self)','\tvar dm := Share.dur(self) if els.has(Elem.ICE) else 1.0'),
            ('\tvar g := Share.grow(self, o)','\tvar g := Share.grow(self, o) if els.has(Elem.WOOD) else 1.0'),
        ]:
            assert body.count(old)==1;body=body.replace(old,new)
        if mutant:body=body.replace('if els.has(Elem.ICE) else 1.0','if els.has(Elem.FIRE) else 1.0')
        return source[:start]+body+source[end:]
    assert path=='scripts/share.gd'
    start=source.index('static func apply(');end=source.index('\n\n## ',start)
    body=source[start:end]
    for old,new in [
        ('\tvar dm := dur(tw)','\tvar dm := dur(tw) if els.has(Elem.ICE) else 1.0'),
        ('\tf *= grow(tw, o)','\tf *= grow(tw, o) if els.has(Elem.WOOD) else 1.0'),
    ]:
        assert body.count(old)==1;body=body.replace(old,new)
    return source[:start]+body+source[end:]
