#!/usr/bin/env python3
"""Reconstruct outgoing AccessKit nodes at the native-query completion marker."""
import argparse
import hashlib
import json
from collections import deque
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('run', type=Path)
    parser.add_argument('--target', default='웨이브 시작 (Space)')
    args = parser.parse_args()
    source = args.run/'native.log'
    nodes = {}
    records = []
    snapshots = []
    root = None
    with source.open() as stream:
        for line_number, line in enumerate(stream, 1):
            if line.startswith('BINDU_AX_NODE '):
                node = json.loads(line.removeprefix('BINDU_AX_NODE '))
                root = node['root_id']
                nodes[node['id']] = node
                records.append({'source_line':line_number, **node})
            elif line.startswith('BINDU_AX_OBSERVED '):
                marker = json.loads(line.removeprefix('BINDU_AX_OBSERVED '))
                paths = {root:[]}
                pending = deque([root])
                missing = set()
                while pending:
                    current = pending.popleft()
                    if current not in nodes:
                        missing.add(current)
                        continue
                    path = paths[current] + [current]
                    for child in nodes[current]['children']:
                        if child not in paths:
                            paths[child] = path
                            pending.append(child)
                targets = []
                parents = {}
                for key in paths:
                    for child in nodes.get(key, {}).get('children', []):
                        parents.setdefault(child, []).append(key)
                for node in nodes.values():
                    label = (node['name']+' '+node['extra']).strip()
                    if args.target not in [node['name'], label]:
                        continue
                    chain = paths[node['id']] + [node['id']] if node['id'] in paths else []
                    targets.append({'node':node, 'reachable':bool(chain),
                                    'ancestors':[nodes[key] for key in chain[:-1]],
                                    'hidden_chain':[key for key in chain if nodes[key]['hidden']]})
                snapshots.append({'marker':marker, 'source_line':line_number, 'root_id':root,
                                  'known_nodes':len(nodes), 'reachable_nodes':len(paths),
                                  'missing_references':sorted(missing),
                                  'multiple_parent_references':{key:value for key,value in parents.items() if len(value) > 1},
                                  'root_is_child':root in parents, 'targets':targets})
    assert records and snapshots, 'No outgoing nodes or completed native observations'
    provenance = {'path':str(source), 'bytes':source.stat().st_size,
                  'sha256':hashlib.sha256(source.read_bytes()).hexdigest()}
    (args.run/'outgoing-nodes.jsonl').write_text(''.join(json.dumps(row, ensure_ascii=False, separators=(',', ':'))+'\n' for row in records))
    result = {'schema':'outgoing_accesskit_observation/v1', 'source':provenance,
              'target':args.target, 'records':len(records), 'snapshots':snapshots,
              'limit':'Engine submission data only; does not observe the AccessKit consumer internal tree or prove native platform inclusion.'}
    (args.run/'outgoing-summary.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')
    print(json.dumps({'records':len(records), 'snapshots':[(row['marker']['label'], len(row['targets'])) for row in snapshots]}))


if __name__ == '__main__':
    main()
