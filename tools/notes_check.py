#!/usr/bin/env python3
"""CHANGELOG.md(게임 안 패치노트 원본)에 개발용 값이 섞였는지 검사한다.
규칙: docs/changelog-rules.md. 걸리면 줄 번호와 이유를 찍고 끝 코드 1.
사용: python3 tools/notes_check.py [CHANGELOG.md]"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
path = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "CHANGELOG.md"

RULES = [
    ("패치 키", re.compile(r"패치 키|온라인 패치 (키|rules|perks|cards)|\b(rules|perks|cards|modes)\.[a-z]")),
    ("코드 이름(snake_case)", re.compile(r"\b[a-z][a-z0-9]*_[a-z0-9_]+\b|\b[a-z]+_\*")),
    ("코드 이름(Class.member)", re.compile(r"\b[A-Z][A-Za-z]+\.[A-Za-z_]+")),
    ("파일·폴더 경로", re.compile(r"\.(gd|md|py|sh|command|json|tscn|godot)\b|\b(scripts|tools|server|docs|plans|icons)/")),
    ("서버 API 경로", re.compile(r"/v1/|/admin\b|\?[a-z]+=")),
    ("커밋 해시", re.compile(r"\b(?=[0-9a-f]*[0-9])(?=[0-9a-f]*[a-f])[0-9a-f]{7,40}\b")),
    ("코드 표시(`)", re.compile(r"`")),
    ("요청·제보 인용", re.compile(r"사용자 (요청|제보|선택|결정)|(요청|제보|결정)\s*:?\s*\"")),
]

bad = 0
for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
    for why, rx in RULES:
        m = rx.search(line)
        if m:
            bad += 1
            print(f"FAIL {path.name}:{n} {why}: …{line[max(0, m.start() - 20):m.end() + 20]}…")
if bad:
    print(f"NOTES 실패 {bad}곳 (docs/changelog-rules.md 참고)")
    sys.exit(1)
print("NOTES ok")
