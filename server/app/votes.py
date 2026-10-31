"""다음 패치 투표: 플레이어가 강해졌으면(up)·약해졌으면(down)·개선됐으면(fix) 하는 항목에 표를 넣는다.

- 회차제: 가장 최근 회차가 열린 회차. 관리자가 새 회차를 열면 앞 회차는 닫히고 그 결과가 게임에 '지난 회차 결과'로 보인다.
- 계정 단위(기기를 바꿔도 같은 표), 회차마다 표 VOTE_MAX장, 한 항목엔 방향 하나.
- 자격: VOTE_MIN_WAVE 웨이브 이상 간 판을 한 번 이상 보낸 계정. 차단 계정·기기는 못 넣고 집계에서도 빠진다.
"""
import csv
import io
import re

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session

from . import accounts, stats
from .db import Account, Ban, Run, Vote, VoteRound, get_db, now

router = APIRouter()

VOTE_MAX = 5
VOTE_MIN_WAVE = 5
NOTE_MAX = 60
DIRS = ("up", "down", "fix")
KEY_RE = re.compile(r"^(elem|pat|mod|link|trig|react|perk):[a-z0-9_]{1,40}$")
LINK_RE = re.compile(r"(https?://|www\.|\.(com|net|kr|io|gg|me|org)\b)", re.I)


def open_round(db: Session) -> VoteRound | None:
    r = db.scalars(select(VoteRound).order_by(VoteRound.id.desc()).limit(1)).first()
    return r if r and r.closed_at is None else None


def ensure_round(db: Session) -> None:
    """서버를 처음 켜면 1회차를 연다 (관리자가 열기 전에도 투표할 수 있게)."""
    if db.scalar(select(func.count()).select_from(VoteRound)) == 0:
        db.add(VoteRound(name="1회차"))
        db.commit()


def clean_note(note: str) -> str:
    t = re.sub(r"[\x00-\x1f\x7f<>]", "", note or "").strip()
    t = re.sub(r"\s+", " ", t)
    if LINK_RE.search(t):
        return ""
    t = re.sub(r"(.)\1{4,}", r"\1\1\1", t)  # 같은 글자 반복은 셋까지
    return t[:NOTE_MAX]


def eligible(db: Session, a: Account, device: str) -> str:
    """투표할 수 없는 까닭. 빈 글자면 됨."""
    if a.banned or db.get(Ban, device) is not None:
        return "banned"
    ok = db.scalar(select(Run.id).where(Run.account_id == a.id, Run.wave >= VOTE_MIN_WAVE).limit(1))
    if ok is None:
        # 계정이 생기기 전에 이 기기로 보낸 판도 친다
        ok = db.scalar(select(Run.id).where(Run.device_id == device, Run.wave >= VOTE_MIN_WAVE).limit(1))
    return "" if ok is not None else "play"


def tally(db: Session, round_id: int) -> list[dict]:
    """항목별 표 수 (차단 계정·기기 제외). 순(up−down)·전체 수 큰 것부터."""
    q = (select(Vote.key, Vote.dir, func.count(Vote.id)).join(Account, Account.id == Vote.account_id)
         .where(Vote.round_id == round_id, Account.banned.is_(False), Vote.device_id.not_in(select(Ban.device_id)))
         .group_by(Vote.key, Vote.dir))
    rows: dict[str, dict] = {}
    for key, d, n in db.execute(q).all():
        r = rows.setdefault(key, {"key": key, "up": 0, "down": 0, "fix": 0})
        r[d] = n
    out = list(rows.values())
    for r in out:
        r["net"] = r["up"] - r["down"]
        r["total"] = r["up"] + r["down"] + r["fix"]
    out.sort(key=lambda r: (-r["total"], -r["net"], r["key"]))
    return out


def voters(db: Session, round_id: int) -> int:
    return db.scalar(select(func.count(func.distinct(Vote.account_id))).join(Account, Account.id == Vote.account_id)
                     .where(Vote.round_id == round_id, Account.banned.is_(False))) or 0


def last_result(db: Session) -> dict | None:
    """가장 최근에 닫힌 회차의 방향별 상위 3개."""
    r = db.scalars(select(VoteRound).where(VoteRound.closed_at.is_not(None)).order_by(VoteRound.id.desc()).limit(1)).first()
    if r is None:
        return None
    t = tally(db, r.id)
    top = {d: [{"key": x["key"], "n": x[d]} for x in sorted(t, key=lambda x: (-x[d], x["key"])) if x[d] > 0][:3] for d in DIRS}
    return {"id": r.id, "name": r.name, "voters": voters(db, r.id), **top}


@router.get("/v1/vote")
def get_vote(authorization: str = Header(default=""), db: Session = Depends(get_db)):
    """지금 회차·내 표·자격·지난 회차 결과. 토큰이 없으면 내 표 없이."""
    r = open_round(db)
    me = accounts.optional(db, authorization)
    mine, why = [], "auth"
    if me is not None:
        a, device = me
        why = eligible(db, a, device)
        if r is not None:
            mine = [{"key": v.key, "dir": v.dir, "note": v.note}
                    for v in db.scalars(select(Vote).where(Vote.round_id == r.id, Vote.account_id == a.id).order_by(Vote.id))]
    return {"round": {"id": r.id, "name": r.name} if r else None, "max": VOTE_MAX, "min_wave": VOTE_MIN_WAVE,
            "mine": mine, "eligible": why == "", "reason": why, "last": last_result(db)}


class VoteItem(BaseModel):
    key: str = Field(max_length=48)
    dir: str = Field(pattern=r"^(up|down|fix)$")
    note: str = Field("", max_length=200)


class VoteIn(BaseModel):
    round: int
    votes: list[VoteItem] = Field([], max_length=VOTE_MAX)


@router.put("/v1/vote")
def put_vote(body: VoteIn, cur=Depends(accounts.current), db: Session = Depends(get_db)):
    """이번 회차 내 표를 통째로 바꾼다 (빈 목록이면 모두 취소)."""
    a, device = cur
    r = open_round(db)
    if r is None or r.id != body.round:
        raise HTTPException(409, "round closed")
    why = eligible(db, a, device)
    if why:
        raise HTTPException(403, why)
    seen = {}
    for v in body.votes:
        if not KEY_RE.match(v.key):
            raise HTTPException(422, f"bad key {v.key}")
        seen[v.key] = v  # 같은 항목이 두 번이면 뒤의 것
    db.execute(delete(Vote).where(Vote.round_id == r.id, Vote.account_id == a.id))
    for v in seen.values():
        db.add(Vote(round_id=r.id, account_id=a.id, key=v.key, dir=v.dir, note=clean_note(v.note) if v.dir == "fix" else "", device_id=device))
    db.commit()
    return {"round": r.id, "count": len(seen)}


def move_votes(db: Session, src_id: str, dst_id: str) -> None:
    """계정 합치기: 회차마다 dst에 표가 없을 때만 src 표를 옮기고, 아니면 dst 표를 둔다 (표 수가 VOTE_MAX를 넘지 않게)."""
    for rid in db.scalars(select(Vote.round_id).where(Vote.account_id == src_id).distinct()).all():
        has = db.scalar(select(Vote.id).where(Vote.round_id == rid, Vote.account_id == dst_id).limit(1))
        if has is None:
            for v in db.scalars(select(Vote).where(Vote.round_id == rid, Vote.account_id == src_id)).all():
                v.account_id = dst_id
        else:
            db.execute(delete(Vote).where(Vote.round_id == rid, Vote.account_id == src_id))


# ---------- 관리 ----------

def _stat_maps(db: Session) -> tuple[dict, dict]:
    """항목 옆에 붙일 통계: 선택률(카드·특성), 마지막 구성 피해 몫. 기본 거르기(유효·STATS_MIN_WAVE 이상)."""
    s = stats.summary(db, stats.Filter())
    rate = {p["key"]: p["rate"] for p in s["picks"]}
    share = {f["key"]: f["avg_share"] for f in s["finals"]}
    for x in s["srcs"]:
        share.setdefault(x["key"].replace("rx:", "react:"), x["avg_share_all"])
    return rate, share


def admin_summary(db: Session, round_id: int = 0) -> dict:
    rounds = db.scalars(select(VoteRound).order_by(VoteRound.id.desc())).all()
    if not rounds:
        return {"rounds": [], "round": 0, "voters": 0, "rows": []}
    rid = round_id or rounds[0].id
    rate, share = _stat_maps(db)
    rows = tally(db, rid)
    notes = dict(db.execute(select(Vote.key, func.count(Vote.id)).where(Vote.round_id == rid, Vote.dir == "fix", Vote.note != "")
                            .group_by(Vote.key)).all())
    for r in rows:
        r["notes"] = notes.get(r["key"], 0)
        r["pick_rate"] = rate.get(r["key"])
        r["share"] = share.get(r["key"])
    return {"rounds": [{"id": r.id, "name": r.name, "created": r.created_at.isoformat(), "closed": r.closed_at.isoformat() if r.closed_at else None,
                        "voters": voters(db, r.id)} for r in rounds],
            "round": rid, "voters": voters(db, rid), "rows": rows}


def admin_notes(db: Session, round_id: int, key: str) -> list[dict]:
    q = (select(Vote, Account.nickname).join(Account, Account.id == Vote.account_id)
         .where(Vote.round_id == round_id, Vote.key == key, Vote.dir == "fix", Vote.note != "").order_by(Vote.updated_at.desc()))
    return [{"note": v.note, "nick": nick or "", "account": v.account_id, "device": v.device_id, "at": v.updated_at.isoformat()}
            for v, nick in db.execute(q).all()]


def new_round(db: Session, name: str) -> VoteRound:
    for r in db.scalars(select(VoteRound).where(VoteRound.closed_at.is_(None))).all():
        r.closed_at = now()
    n = (db.scalar(select(func.max(VoteRound.id))) or 0) + 1
    r = VoteRound(name=(name or "").strip()[:64] or f"{n}회차")
    db.add(r)
    db.commit()
    return r


def to_csv(data: dict) -> str:
    buf = io.StringIO()
    buf.write("﻿")
    w = csv.DictWriter(buf, fieldnames=["key", "up", "down", "fix", "net", "total", "notes", "pick_rate", "share"])
    w.writeheader()
    w.writerows(data["rows"])
    return buf.getvalue()
