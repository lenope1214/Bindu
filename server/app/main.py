"""빈두 온라인 서버: JSON 데이터 패치, 새 버전 알림, 리더보드(시즌), 선택 통계."""
import json
from contextlib import asynccontextmanager
import re
from datetime import timedelta
from pathlib import Path

from fastapi import Depends, FastAPI, Header, HTTPException, Query, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, PlainTextResponse
from pydantic import BaseModel, Field
from sqlalchemy import func, select, update
from sqlalchemy.orm import Session

from . import config, signing, stats, validate
from .db import Ban, Final, Patch, Pick, Release, Run, Season, get_db, init_db, now

@asynccontextmanager
async def lifespan(_app):
    init_db()
    db = next(get_db())
    if db.scalar(select(func.count()).select_from(Season)) == 0:
        db.add(Season(name="시즌 1"))
        db.commit()
    db.close()
    yield


app = FastAPI(title="Bindu server", version="1.0", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["GET", "POST", "PUT"], allow_headers=["*"])

PLATFORMS = ["windows", "macos", "linux", "android", "ios"]
# 패치 data에서 게임이 읽는 최상위 키 (scripts/patch.gd)
PATCH_KEYS = {"rules", "rules_desc", "perks", "perk_desc", "cards", "elem_dmg", "pat_dmg", "message"}


@app.get("/health")
def health():
    return {"ok": True}


# ---------- 공통 ----------

def current_season(db: Session) -> Season:
    return db.scalars(select(Season).order_by(Season.id.desc()).limit(1)).first()


def season_for(db: Session, game: str, patch_id: int) -> int:
    s = current_season(db)
    if s and validate.vtuple(game) >= validate.vtuple(s.min_game) and patch_id >= s.min_patch:
        return s.id
    return 0


def patch_for(db: Session, game: str) -> Patch | None:
    gv = validate.vtuple(game)
    for p in db.scalars(select(Patch).where(Patch.active.is_(True)).order_by(Patch.id.desc())):
        if validate.vtuple(p.min_game) <= gv and (not p.max_game or gv <= validate.vtuple(p.max_game)):
            return p
    return None


def require_admin(authorization: str = Header(default="")) -> None:
    if not config.ADMIN_TOKEN or authorization != f"Bearer {config.ADMIN_TOKEN}":
        raise HTTPException(401, "admin token required")


def clean_nick(nick: str, device: str) -> str:
    nick = re.sub(r"[\x00-\x1f\x7f<>]", "", nick or "").strip()[:12]
    return nick or f"익명-{device[:4]}"


# ---------- 게임용 ----------

@app.get("/v1/boot")
def boot(game: str, platform: str = "", patch: int = -1, db: Session = Depends(get_db)):
    """게임을 켤 때 한 번: 맞는 패치, 새 버전, 지금 시즌."""
    p = patch_for(db, game)
    if p is None:
        patch_out = {"id": 0}  # 내장 값으로 되돌림
    elif p.id == patch:
        patch_out = {"id": p.id, "same": True}
    else:
        patch_out = {"id": p.id, "payload": p.payload, "sig": p.sig}
    latest = None
    r = db.get(Release, platform.lower()) if platform else None
    if r and validate.vtuple(r.version) > validate.vtuple(game):
        latest = {"version": r.version, "url": r.url, "notes": r.notes}
    s = current_season(db)
    return {"patch": patch_out, "latest": latest, "season": {"id": s.id, "name": s.name} if s else None}


class TowerIn(BaseModel):
    els: dict[str, int] = {}
    pat: str = "shot"
    plv: int = 1
    mods: dict[str, int] = {}
    prism: int = 0
    reso: int = 0
    links: int = 0
    share: float = 0.0


class LogIn(BaseModel):
    w: int = 0
    k: str = "card"  # card | perk
    o: list[str] = []  # 나온 선택지
    p: str = ""  # 고른 것 (빈 글자: 새로고침으로 넘김)


KEY_RE = re.compile(r"^[a-z]+:[a-z0-9_]{1,40}$")


class RunIn(BaseModel):
    device: str = Field(pattern=r"^[A-Za-z0-9-]{8,64}$")
    nick: str = Field("", max_length=64)
    platform: str = Field("", pattern=r"^[a-z]{0,16}$")
    game: str = Field(pattern=r"^[0-9.]{1,16}$")
    patch: int = 0
    map: str = Field(pattern=r"^[a-z]{1,16}$")
    rules: int
    wave: int
    score: int
    kills: int = 0
    best_combo: int = 0
    game_secs: float = 0.0
    real_secs: float = 0.0
    perks: dict[str, int] = {}
    towers: list[TowerIn] = []
    log: list[LogIn] = []


@app.post("/v1/runs")
async def submit_run(request: Request, x_bindu_mac: str = Header(default=""), db: Session = Depends(get_db)):
    body = await request.body()
    if len(body) > 256_000:
        raise HTTPException(413, "too large")
    if not signing.check_run_mac(body, x_bindu_mac):
        raise HTTPException(403, "bad signature")
    try:
        run = RunIn.model_validate_json(body)
    except Exception as e:
        raise HTTPException(422, str(e)[:300])
    ip = signing.ip_hash(request.client.host if request.client else "")
    t = now()
    last = db.scalar(select(func.max(Run.created_at)).where(Run.device_id == run.device))
    if last and (t - last).total_seconds() < config.RUN_MIN_INTERVAL:
        raise HTTPException(429, "too soon")
    n_ip = db.scalar(select(func.count()).select_from(Run).where(Run.ip_hash == ip, Run.created_at > t - timedelta(hours=1)))
    if n_ip >= config.RUN_PER_IP_HOUR:
        raise HTTPException(429, "too many")

    p = db.get(Patch, run.patch) if run.patch > 0 else None
    reason = validate.check(run.model_dump(), p.data if p else None)
    if not reason and db.get(Ban, run.device):
        reason = "banned"
    nick = clean_nick(run.nick, run.device)
    season = season_for(db, run.game, run.patch)
    row = Run(device_id=run.device, nickname=nick, ip_hash=ip, platform=run.platform, game_version=run.game,
              patch_id=run.patch, season=season, map=run.map, rules=run.rules, wave=run.wave, score=run.score,
              kills=run.kills, best_combo=run.best_combo, game_secs=run.game_secs, real_secs=run.real_secs,
              detail={"perks": run.perks, "towers": [x.model_dump() for x in run.towers], "log": [x.model_dump() for x in run.log]},
              valid=reason == "", reason=reason)
    db.add(row)
    db.flush()
    for e in run.log[:2000]:
        kind = "perk" if e.k == "perk" else "card"
        for key in dict.fromkeys(k for k in e.o[:6] if KEY_RE.match(k)):  # 같은 선택지가 두 번 들어 있어도 한 번
            db.add(Pick(run_id=row.id, kind=kind, key=key[:48], picked=key == e.p, wave=e.w))
    for key, (amount, share) in stats.finals_of(run.towers).items():
        if not KEY_RE.match(key):
            continue
        db.add(Final(run_id=row.id, key=key, amount=amount, share=share))
    # 닉네임을 바꾸면 예전 기록에도 새 이름이 보이게
    db.execute(update(Run).where(Run.device_id == run.device, Run.nickname != nick).values(nickname=nick))
    db.commit()
    rank = None
    if row.valid and season:
        rank = board_rank(db, run.map, run.rules, season, None, run.device)
    return {"id": row.id, "accepted": row.valid, "season": season, "rank": rank}


def _board(db: Session, map_id: str, rules: int, season: int, since):
    """기기마다 최고 기록 하나씩."""
    conds = [Run.map == map_id, Run.rules == rules, Run.season == season, Run.valid.is_(True), Run.hidden.is_(False)]
    if since is not None:
        conds.append(Run.created_at >= since)
    rn = func.row_number().over(partition_by=Run.device_id, order_by=(Run.score.desc(), Run.wave.desc(), Run.id)).label("rn")
    sub = select(Run.id, Run.device_id, Run.nickname, Run.wave, Run.score, Run.game_version, Run.created_at, rn).where(*conds).subquery()
    return sub


def board_rank(db: Session, map_id: str, rules: int, season: int, since, device: str):
    sub = _board(db, map_id, rules, season, since)
    mine = db.execute(select(sub).where(sub.c.rn == 1, sub.c.device_id == device)).first()
    if not mine:
        return None
    ahead = db.scalar(select(func.count()).select_from(sub).where(
        sub.c.rn == 1, (sub.c.score > mine.score) | ((sub.c.score == mine.score) & (sub.c.wave > mine.wave))
        | ((sub.c.score == mine.score) & (sub.c.wave == mine.wave) & (sub.c.id < mine.id))))
    return {"rank": ahead + 1, "score": mine.score, "wave": mine.wave}


@app.get("/v1/leaderboard")
def leaderboard(map: str, rules: int, season: int = 0, period: str = "all", limit: int = Query(20, le=100),
                device: str = "", db: Session = Depends(get_db)):
    s = db.get(Season, season) if season else current_season(db)
    if not s:
        raise HTTPException(404, "no season")
    since = now() - timedelta(days=7) if period == "week" else None
    sub = _board(db, map, rules, s.id, since)
    rows = db.execute(select(sub).where(sub.c.rn == 1).order_by(sub.c.score.desc(), sub.c.wave.desc(), sub.c.id).limit(limit)).all()
    total = db.scalar(select(func.count()).select_from(sub).where(sub.c.rn == 1))
    entries = [{"rank": i + 1, "nick": r.nickname, "wave": r.wave, "score": r.score, "game": r.game_version,
                "date": r.created_at.strftime("%Y-%m-%d"), "me": r.device_id == device} for i, r in enumerate(rows)]
    me = board_rank(db, map, rules, s.id, since, device) if device else None
    return {"season": {"id": s.id, "name": s.name}, "period": period, "total": total, "entries": entries, "me": me}


@app.get("/v1/seasons")
def seasons(db: Session = Depends(get_db)):
    return [{"id": s.id, "name": s.name, "started": s.created_at.strftime("%Y-%m-%d")} for s in db.scalars(select(Season).order_by(Season.id.desc()))]


# ---------- 관리자 ----------

class PatchIn(BaseModel):
    data: dict
    notes: str = ""
    min_game: str = "0.0.0"
    max_game: str = ""
    new_season: bool = False
    season_name: str = ""


@app.post("/admin/patches", dependencies=[Depends(require_admin)])
def create_patch(body: PatchIn, db: Session = Depends(get_db)):
    unknown = sorted(set(body.data) - PATCH_KEYS)
    if unknown:
        raise HTTPException(422, f"unknown keys: {unknown} (allowed: {sorted(PATCH_KEYS)})")
    p = Patch(notes=body.notes, min_game=body.min_game, max_game=body.max_game, data=body.data, payload="", sig="")
    db.add(p)
    db.flush()
    # id·버전 범위까지 함께 서명해서 다른 패치로 바꿔치기할 수 없게
    p.payload = json.dumps({"id": p.id, "min_game": p.min_game, "max_game": p.max_game, "data": body.data},
                           ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    p.sig = signing.sign(p.payload)
    if body.new_season:
        cur = current_season(db)
        db.add(Season(name=body.season_name or f"시즌 {(cur.id if cur else 0) + 1}", min_game=body.min_game, min_patch=p.id))
        db.flush()
    p.season = current_season(db).id
    db.commit()
    return {"id": p.id, "season": p.season}


@app.get("/admin/patches", dependencies=[Depends(require_admin)])
def list_patches(db: Session = Depends(get_db)):
    return [{"id": p.id, "created": p.created_at.isoformat(), "notes": p.notes, "min_game": p.min_game, "max_game": p.max_game,
             "active": p.active, "season": p.season, "data": p.data} for p in db.scalars(select(Patch).order_by(Patch.id.desc()))]


class ActiveIn(BaseModel):
    active: bool


@app.post("/admin/patches/{pid}/active", dependencies=[Depends(require_admin)])
def set_patch_active(pid: int, body: ActiveIn, db: Session = Depends(get_db)):
    p = db.get(Patch, pid) or _404()
    p.active = body.active
    db.commit()
    return {"id": p.id, "active": p.active}


class SeasonIn(BaseModel):
    name: str = ""
    min_game: str = "0.0.0"
    min_patch: int = 0


@app.post("/admin/seasons", dependencies=[Depends(require_admin)])
def create_season(body: SeasonIn, db: Session = Depends(get_db)):
    """새 빌드(코드 변경)로 판도가 바뀔 때: 이 게임 버전부터 새 시즌."""
    cur = current_season(db)
    s = Season(name=body.name or f"시즌 {(cur.id if cur else 0) + 1}", min_game=body.min_game, min_patch=body.min_patch)
    db.add(s)
    db.commit()
    return {"id": s.id, "name": s.name}


class ReleaseIn(BaseModel):
    version: str
    url: str = ""
    notes: str = ""


@app.put("/admin/releases/{platform}", dependencies=[Depends(require_admin)])
def set_release(platform: str, body: ReleaseIn, db: Session = Depends(get_db)):
    platform = platform.lower()
    if platform not in PLATFORMS:
        raise HTTPException(422, f"platform: {PLATFORMS}")
    r = db.get(Release, platform) or Release(platform=platform)
    r.version, r.url, r.notes = body.version, body.url, body.notes
    db.add(r)
    db.commit()
    return {"platform": platform, "version": r.version}


@app.get("/admin/releases", dependencies=[Depends(require_admin)])
def list_releases(db: Session = Depends(get_db)):
    return [{"platform": r.platform, "version": r.version, "url": r.url, "notes": r.notes} for r in db.scalars(select(Release))]


@app.get("/admin/runs", dependencies=[Depends(require_admin)])
def list_runs(invalid: bool = False, limit: int = Query(50, le=500), db: Session = Depends(get_db)):
    q = select(Run).order_by(Run.id.desc()).limit(limit)
    if invalid:
        q = q.where(Run.valid.is_(False))
    return [{"id": r.id, "created": r.created_at.isoformat(), "device": r.device_id, "nick": r.nickname, "game": r.game_version,
             "patch": r.patch_id, "season": r.season, "map": r.map, "rules": r.rules, "wave": r.wave, "score": r.score,
             "valid": r.valid, "reason": r.reason, "hidden": r.hidden} for r in db.scalars(q)]


class HiddenIn(BaseModel):
    hidden: bool


@app.post("/admin/runs/{rid}/hidden", dependencies=[Depends(require_admin)])
def hide_run(rid: int, body: HiddenIn, db: Session = Depends(get_db)):
    r = db.get(Run, rid) or _404()
    r.hidden = body.hidden
    db.commit()
    return {"id": r.id, "hidden": r.hidden}


class BanIn(BaseModel):
    device_id: str
    reason: str = ""


@app.post("/admin/bans", dependencies=[Depends(require_admin)])
def ban(body: BanIn, db: Session = Depends(get_db)):
    db.merge(Ban(device_id=body.device_id, reason=body.reason))
    db.execute(update(Run).where(Run.device_id == body.device_id).values(hidden=True))
    db.commit()
    return {"banned": body.device_id}


@app.get("/admin/api/stats", dependencies=[Depends(require_admin)])
def get_stats(rules: int = 0, map: str = "", game: str = "", patch: int = -1, days: int = 0, valid_only: bool = True,
              db: Session = Depends(get_db)):
    return stats.summary(db, stats.Filter(rules, map, game, patch, days, valid_only))


@app.get("/admin/api/stats.csv", dependencies=[Depends(require_admin)], response_class=PlainTextResponse)
def get_stats_csv(kind: str = "picks", rules: int = 0, map: str = "", game: str = "", patch: int = -1, days: int = 0,
                  valid_only: bool = True, db: Session = Depends(get_db)):
    data = stats.summary(db, stats.Filter(rules, map, game, patch, days, valid_only))
    return PlainTextResponse(stats.to_csv(data, kind), media_type="text/csv; charset=utf-8",
                             headers={"Content-Disposition": f'attachment; filename="bindu_{kind}.csv"'})


@app.get("/admin", response_class=HTMLResponse)
def admin_page():
    return (Path(__file__).parent / "admin.html").read_text(encoding="utf-8")


def _404():
    raise HTTPException(404, "not found")
