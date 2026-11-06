#!/usr/bin/env python3
"""Check ownership completeness and unchanged method bodies across the migration.

No Godot, mutable game globals, network, or historical checkout is needed to verify.
Hashes deliberately retain string literals, numeric constants, branch and call order.
"""
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOKENS = re.compile(r'"""[\s\S]*?"""|\'\'\'[\s\S]*?\'\'\'|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|\#[^\n]*|[A-Za-z_]\w*|\s+|.', re.UNICODE)


def functions(source):
    starts = list(re.finditer(r'^(?:static )?(func|var|const) (\w+)', source, re.M))
    return {m[2]: source[m.start():starts[i + 1].start() if i + 1 < len(starts) else len(source)]
            for i, m in enumerate(starts) if m[1] == 'func'}


def digest(body):
    body = re.sub(r"^\tvar session: BinduSession = self\.session\n", "", body, flags=re.M)
    ts = [t for t in TOKENS.findall(body) if t.strip() and not t.startswith('#')]
    out = []
    i = 0
    while i < len(ts):
        token = ts[i]
        if i + 1 < len(ts) and ts[i + 1] == '.' and (token in {'session', 'BinduSession'} or token.endswith('_system')):
            i += 2
            continue
        out.append('self' if token == 'session' else 'boot' if token == '_ready' else token)
        i += 1
    return hashlib.sha256('\0'.join(out).encode()).hexdigest()


def check():
    manifest = json.loads((ROOT / 'docs/architecture/main-boundaries.json').read_text())
    failures = []
    verified = 0
    for name, owner in manifest['function_owners'].items():
        path = ROOT / ('scripts/app/session.gd' if owner == 'session' else 'scripts/features/%s.gd' % owner)
        methods = functions(path.read_text())
        body = methods.get('boot' if name == '_ready' else name)
        if body is None:
            failures.append('missing method %s in %s' % (name, path.name))
        elif name not in manifest['reviewed_changes']:
            if digest(body) != manifest['method_hashes'][name]:
                failures.append('changed method requires explicit review: ' + name)
            else:
                verified += 1
    for path in (ROOT / 'scripts/features').glob('*.gd'):
        source = path.read_text()
        if 'extends BinduFeature' not in source or re.search(r'\.(?:connect|new)\(self\)', source):
            failures.append('controller lifetime contract: ' + path.name)
    for path in (ROOT / 'scripts').rglob('*.gd'):
        for name in re.findall(r'\b(?:main|game)\.(?:call_deferred|call|has_method)\("([a-z_]+)"', path.read_text()):
            if manifest['function_owners'].get(name, 'session') != 'session':
                failures.append('stale dynamic scene method %s in %s' % (name, path.name))
    if failures:
        print('\n'.join('FAIL ' + f for f in failures))
        return 1
    print('ARCHITECTURE AUDIT preserved=%d reviewed=%d features=%d owned_state=%d' % (
        verified, len(manifest['reviewed_changes']), len(manifest['feature_classes']), len(manifest['state_owners'])))
    return 0


if __name__ == '__main__':
    raise SystemExit(check())
