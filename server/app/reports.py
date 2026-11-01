"""닉네임 신고·거르기 (App Store 1.2: 사용자 생성 콘텐츠 = 리더보드·멀티 방에 보이는 닉네임).

- 닉네임 거르기: bad_nick()이 참이면 clean_nick이 익명 이름으로 바꾼다. 같은 목록이 게임 scripts/nick_filter.gd에도 있다(둘 다 고칠 것).
- pid: 리더보드 줄·멀티 방 사람의 공개 id. 계정(없으면 기기) id를 서버 비밀로 HMAC한 앞 16자라 원래 id는 안 보인다.
  게임은 이 값으로 '차단'(이 기기에서 그 사람 이름 숨김)하고 '신고'를 보낸다.
- 신고: POST /v1/reports → 관리 페이지 '신고' 탭에서 이름 지우기·차단·넘기기.
"""
import hashlib
import hmac
import re

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import func, select, update
from sqlalchemy.orm import Session

from . import accounts
from .db import Account, Ban, Identity, Report, Run, get_db, now

router = APIRouter()

REPORTS_PER_DAY = 20
REASONS = ("nick", "cheat", "other")

# 정규화(소문자, 글자·숫자 외 지움, 숫자 지움) 뒤 '포함'으로 본다. 짧고 흔한 말과 겹치는 것은 넣지 않는다.
BAD_WORDS = [
    # 한국어
    "시발", "씨발", "씨팔", "시팔", "씨바", "ㅅㅂ", "ㅆㅂ", "ㅅㅃ", "병신", "븅신", "빙신", "ㅂㅅ", "좆", "존나", "졸라", "ㅈㄴ",
    "개새", "개색", "새끼", "ㅅㄲ", "니미", "느금", "느그애미", "니애미", "애미", "애비", "엠창", "보지", "자지", "섹스", "썅",
    "꺼져", "닥쳐", "지랄", "ㅈㄹ", "미친놈", "미친년", "또라이", "쓰레기", "창녀", "걸레", "등신", "찐따", "한남", "김치녀",
    "일베", "메갈", "노무현", "운지", "장애인", "틀딱", "흑형", "짱깨", "쪽바리", "강간", "자살", "살인", "마약",
    # 영어
    "fuck", "fuk", "fck", "shit", "bitch", "cunt", "dick", "pussy", "asshole", "bastard", "slut", "whore",
    "nigger", "nigga", "faggot", "retard", "rapist", "porn", "nazi", "hitler", "suicide",
    # 운영자 사칭
    "운영자", "관리자", "admin",
]
_NORM = re.compile(r"[^0-9a-z가-힣ㄱ-ㅎㅏ-ㅣ]")


def norm(s: str) -> str:
    return re.sub(r"[0-9]", "", _NORM.sub("", (s or "").lower()))


def bad_nick(nick: str) -> bool:
    n = norm(nick)
    return any(w in n for w in BAD_WORDS) if n else False


def pid(who: str) -> str:
    return hmac.new(accounts._key(), b"pid:" + (who or "").encode(), hashlib.sha256).hexdigest()[:16] if who else ""


def find_who(db: Session, p: str) -> str:
    """pid → 계정 id(없으면 기기 id). 신고가 들어올 때만 부르니 전부 훑어도 된다."""
    for (aid,) in db.execute(select(Account.id).where(Account.merged_into.is_(None))):
        if pid(aid) == p:
            return aid
    for (dev,) in db.execute(select(Run.device_id).where(Run.account_id.is_(None)).distinct()):
        if pid(dev) == p:
            return dev
    return ""


class ReportIn(BaseModel):
    pid: str = Field(pattern=r"^[0-9a-f]{16}$")
    nick: str = Field("", max_length=64)
    where: str = Field("board", pattern=r"^(board|mp)$")
    reason: str = Field("nick", pattern=r"^(nick|cheat|other)$")
    device: str = Field("", max_length=64)


@router.post("/v1/reports")
def post_report(body: ReportIn, authorization: str = Header(default=""), db: Session = Depends(get_db)):
    me = accounts.optional(db, authorization)
    reporter = me[0].id if me else body.device
    if not reporter:
        raise HTTPException(401, "token")
    day = now().replace(hour=0, minute=0, second=0, microsecond=0)
    n = db.scalar(select(func.count()).select_from(Report).where(Report.reporter == reporter, Report.created_at >= day))
    if n >= REPORTS_PER_DAY:
        raise HTTPException(429, "too many")
    if pid(reporter) == body.pid:
        raise HTTPException(422, "self")
    dup = db.scalar(select(Report.id).where(Report.reporter == reporter, Report.pid == body.pid, Report.status == "open").limit(1))
    if dup is None:
        db.add(Report(reporter=reporter, pid=body.pid, target=find_who(db, body.pid), nick=(body.nick or "")[:32],
                      where=body.where, reason=body.reason))
        db.commit()
    return {"ok": True}


# ---------- 관리자 (main.py에서 require_admin으로 붙임) ----------

def admin_list(db: Session, status: str = "open") -> list[dict]:
    q = select(Report).order_by(Report.id.desc()).limit(300)
    if status:
        q = q.where(Report.status == status)
    rows = db.scalars(q).all()
    out = []
    for r in rows:
        a = accounts.resolve(db, r.target) if r.target else None
        cur = a.nickname if a else (db.scalar(select(Run.nickname).where(Run.device_id == r.target).order_by(Run.id.desc()).limit(1)) or "")
        times = db.scalar(select(func.count(func.distinct(Report.reporter))).where(Report.pid == r.pid)) or 0
        out.append({"id": r.id, "created": r.created_at.isoformat(), "nick": r.nick, "now": cur, "where": r.where, "reason": r.reason,
                    "target": r.target, "reporters": times, "status": r.status, "banned": bool(a and a.banned)})
    return out


def _devices(db: Session, who: str) -> list[str]:
    devs = [i.subject for i in db.scalars(select(Identity).where(Identity.account_id == who, Identity.provider == "device"))]
    return devs or [who]


def admin_act(db: Session, rid: int, action: str) -> dict:
    """rename: 닉네임을 익명으로 / ban: 이름 지우고 기기·계정 차단(기록 숨김) / dismiss: 넘김. 같은 사람에 걸린 열린 신고를 같이 닫는다."""
    r = db.get(Report, rid)
    if r is None:
        raise HTTPException(404, "report")
    if action not in ("rename", "ban", "dismiss"):
        raise HTTPException(422, "action")
    if action != "dismiss" and r.target:
        a = accounts.resolve(db, r.target)
        anon = "익명-" + (_devices(db, r.target)[0][:4])
        if a:
            a.nickname = anon
            db.execute(update(Run).where(Run.account_id == a.id).values(nickname=anon))
        db.execute(update(Run).where(Run.device_id.in_(_devices(db, r.target))).values(nickname=anon))
        if action == "ban":
            for d in _devices(db, r.target):
                db.merge(Ban(device_id=d, reason="신고: " + r.nick))
            db.execute(update(Run).where(Run.device_id.in_(_devices(db, r.target))).values(hidden=True))
            if a:
                a.banned = True
                db.execute(update(Run).where(Run.account_id == a.id).values(hidden=True))
    st = {"rename": "renamed", "ban": "banned", "dismiss": "dismissed"}[action]
    db.execute(update(Report).where(Report.pid == r.pid, Report.status == "open").values(status=st, done_at=now()))
    db.commit()
    return {"id": rid, "status": st}
