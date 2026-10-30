"""계정 진행 저장(클라우드 세이브)의 형식과 합치기. 게임 scripts/progress.gd와 같은 규칙이어야 한다.

형식 1:
  best   {기록 키: [웨이브, 점수]}      키마다 둘 다 큰 값
  ach    [업적 id]  codex [반응 id]  seen [본 안내 id]   합집합
  counts {기기 id: [처치, 판 수]}       기기마다 큰 값 (합계는 보여 줄 때 더함)
  lww    {이름: [고친 시각(초), 값]}    이름마다 늦게 고친 쪽 (같으면 값 글자로 정해 어느 쪽에서 합쳐도 같게)

두 기기에서 따로 해도 순서와 상관없이 같은 결과가 나오므로 충돌을 사람에게 묻지 않는다.
"""
import json
import re

FORMAT = 1
MAX_BYTES = 64_000
MAX_COUNT = 1_000_000_000

# 키에 한글이 들어간다 (선호 표시 elem:불 등): 제어 문자만 막는다
ID_RE = re.compile(r"^[^\x00-\x1f\x7f]{1,64}$")
DEV_RE = re.compile(r"^[A-Za-z0-9-]{8,64}$")
# 기기마다 다른 설정(소리·글자 크기 등)은 넣지 않는다
LWW_RE = re.compile(r"^(map|rules|modes|tower_skin|core_skin|line_flip|tutor|notes_seen|nick|fav:[^\x00-\x1f\x7f]{1,60})$")


class Bad(ValueError):
    pass


def empty() -> dict:
    return {"format": FORMAT, "best": {}, "ach": [], "codex": [], "seen": [], "counts": {}, "lww": {}}


def _int(v) -> int:
    if isinstance(v, bool) or not isinstance(v, (int, float)):
        raise Bad("숫자가 아님")
    return max(0, min(MAX_COUNT, int(v)))


def _ids(v, limit: int) -> list[str]:
    if not isinstance(v, list) or len(v) > limit:
        raise Bad("목록 형식")
    return sorted({x for x in v if isinstance(x, str) and ID_RE.match(x)})


def _lww_val(v):
    if isinstance(v, (bool, str)) and (not isinstance(v, str) or len(v) <= 64):
        return v
    if isinstance(v, (int, float)):
        return int(v)
    if isinstance(v, list) and len(v) <= 16 and all(isinstance(x, str) and len(x) <= 32 for x in v):
        return list(v)
    raise Bad("값 형식")


def clean(d) -> dict:
    """받은 진행을 형식에 맞게 다듬는다. 모르는 키는 버리고 틀린 형식이면 Bad."""
    if not isinstance(d, dict):
        raise Bad("사전이 아님")
    if len(json.dumps(d)) > MAX_BYTES:
        raise Bad("너무 큼")
    if int(d.get("format", 0)) != FORMAT:
        raise Bad("모르는 형식")
    out = empty()
    best = d.get("best", {})
    if not isinstance(best, dict) or len(best) > 200:
        raise Bad("best")
    for k, v in best.items():
        if ID_RE.match(k) and isinstance(v, list) and len(v) >= 2:
            out["best"][k] = [_int(v[0]), _int(v[1])]
    out["ach"] = _ids(d.get("ach", []), 200)
    out["codex"] = _ids(d.get("codex", []), 500)
    out["seen"] = _ids(d.get("seen", []), 500)
    counts = d.get("counts", {})
    if not isinstance(counts, dict) or len(counts) > 64:
        raise Bad("counts")
    for k, v in counts.items():
        if DEV_RE.match(k) and isinstance(v, list) and len(v) >= 2:
            out["counts"][k] = [_int(v[0]), _int(v[1])]
    lww = d.get("lww", {})
    if not isinstance(lww, dict) or len(lww) > 600:
        raise Bad("lww")
    for k, v in lww.items():
        if LWW_RE.match(k) and isinstance(v, list) and len(v) == 2:
            out["lww"][k] = [_int(v[0]), _lww_val(v[1])]
    return out


def _later(a: list, b: list) -> list:
    if a[0] != b[0]:
        return a if a[0] > b[0] else b
    return a if json.dumps(a[1], sort_keys=True) >= json.dumps(b[1], sort_keys=True) else b


def merge(a: dict, b: dict) -> dict:
    """두 진행을 합친다. merge(a, b) == merge(b, a), 같은 것을 다시 합쳐도 그대로."""
    out = empty()
    for k in set(a["best"]) | set(b["best"]):
        x, y = a["best"].get(k, [0, 0]), b["best"].get(k, [0, 0])
        out["best"][k] = [max(x[0], y[0]), max(x[1], y[1])]
    for s in ("ach", "codex", "seen"):
        out[s] = sorted(set(a[s]) | set(b[s]))
    for k in set(a["counts"]) | set(b["counts"]):
        x, y = a["counts"].get(k, [0, 0]), b["counts"].get(k, [0, 0])
        out["counts"][k] = [max(x[0], y[0]), max(x[1], y[1])]
    for k in set(a["lww"]) | set(b["lww"]):
        if k not in a["lww"]:
            out["lww"][k] = b["lww"][k]
        elif k not in b["lww"]:
            out["lww"][k] = a["lww"][k]
        else:
            out["lww"][k] = _later(a["lww"][k], b["lww"][k])
    return out


def nick(d: dict) -> str:
    v = d["lww"].get("nick")
    return v[1] if v and isinstance(v[1], str) else ""
