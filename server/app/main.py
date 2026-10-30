"""빈두 온라인 서버: JSON 데이터 패치, 새 버전 알림, 리더보드(시즌), 선택 통계."""
import hashlib
import json
import urllib.request
from contextlib import asynccontextmanager
import re
from datetime import timedelta
from pathlib import Path

from fastapi import Depends, FastAPI, Header, HTTPException, Query, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, PlainTextResponse
from pydantic import BaseModel, Field
from sqlalchemy import delete, func, select, update
from sqlalchemy.orm import Session

from . import config, signing, stats, validate
from .db import Ban, ClientLog, Final, Patch, Pick, Release, Run, Season, SrcShare, get_db, init_db, now

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
PATCH_KEYS = {"rules", "rules_desc", "perks", "perk_desc", "cards", "elem_dmg", "pat_dmg", "modes", "message"}


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
        if r.sha256 and r.url:
            # 게임 안 업데이트: 받은 파일이 이 해시와 맞을 때만 바꿔 끼운다 (서명은 패치와 같은 키)
            latest.update(sha256=r.sha256, size=r.size, sig=signing.sign(release_payload(r.platform, r.version, r.url, r.sha256, r.size)))
    s = current_season(db)
    # snap: 진행 중 판 기록(run·ended)을 받아 한 줄로 고칠 수 있는 서버. 게임은 이게 있을 때만 5웨이브마다 보낸다
    return {"patch": patch_out, "latest": latest, "season": {"id": s.id, "name": s.name} if s else None, "snap": True}


class TowerIn(BaseModel):
    els: dict[str, int] = {}
    pat: str = "shot"
    plv: int = 1
    mods: dict[str, int] = {}
    prism: int = 0
    reso: int = 0
    links: int = 0  # 예전 연결선 (v0.4.45부터 없음)
    pincer: int = 0
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
    modes: list[str] = Field([], max_length=16)  # 고른 모드 (validate.MODES)
    wave: int
    score: int
    kills: int = 0
    best_combo: int = 0
    game_secs: float = 0.0
    real_secs: float = 0.0
    perks: dict[str, int] = {}
    towers: list[TowerIn] = []
    src: dict[str, float] = {}  # 피해 출처 몫 {키: 0~1} (피해 출처를 보내는 버전부터)
    log: list[LogIn] = []
    run: str = Field("", pattern=r"^[A-Za-z0-9-]{0,40}$")  # 판 번호: 같은 판의 진행 기록을 한 줄로 (0.5.1부터)
    ended: bool = True  # False: 5웨이브마다 보내는 진행 중 기록


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
    # 진행 중 판을 다시 보낸 것: 같은 줄을 고친다 (웨이브가 올라갔거나 판이 끝났을 때만)
    row = db.scalars(select(Run).where(Run.device_id == run.device, Run.run_key == run.run).limit(1)).first() if run.run else None
    if row is not None and (row.ended or (not run.ended and run.wave <= row.wave)):
        return {"id": row.id, "accepted": row.valid, "season": row.season, "rank": None, "ignored": True}
    if row is None:
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
    if not reason and row is not None and not row.valid:
        reason = row.reason  # 한 번 검증에 걸린 판은 계속 뺀다
    nick = clean_nick(run.nick, run.device)
    season = season_for(db, run.game, run.patch)
    vals = dict(device_id=run.device, nickname=nick, ip_hash=ip, platform=run.platform, game_version=run.game,
                patch_id=run.patch, season=season, map=run.map, rules=run.rules, wave=run.wave, score=run.score,
                kills=run.kills, best_combo=run.best_combo, game_secs=run.game_secs, real_secs=run.real_secs,
                detail={"perks": run.perks, "modes": run.modes, "towers": [x.model_dump() for x in run.towers], "src": run.src, "log": [x.model_dump() for x in run.log]},
                valid=reason == "", reason=reason, run_key=run.run, ended=run.ended, updated_at=now())
    if row is None:
        row = Run(hidden=validate.easy(run.modes), **vals)  # 쉽게 모드 판은 통계에만 (리더보드 제외)
        db.add(row)
        db.flush()
    else:
        for k, v in vals.items():
            setattr(row, k, v)
        # 선택·구성·피해 출처는 지금까지 전체를 다시 받았으니 갈아 끼운다 (두 번 세지 않게)
        for tbl in (Pick, Final, SrcShare):
            db.execute(delete(tbl).where(tbl.run_id == row.id))
    for e in run.log[:2000]:
        kind = "perk" if e.k == "perk" else "card"
        for key in dict.fromkeys(k for k in e.o[:6] if KEY_RE.match(k)):  # 같은 선택지가 두 번 들어 있어도 한 번
            db.add(Pick(run_id=row.id, kind=kind, key=key[:48], picked=key == e.p, wave=e.w))
    # 모드: 통계에서 모드별 평균 웨이브를 보려고 선택처럼 적는다 (모드 없는 판은 mode:none)
    for m in dict.fromkeys(run.modes or ["none"]):
        if KEY_RE.match(f"mode:{m}"):
            db.add(Pick(run_id=row.id, kind="mode", key=f"mode:{m}", picked=True, wave=0))
    for key, (amount, share) in stats.finals_of(run.towers).items():
        if not KEY_RE.match(key):
            continue
        db.add(Final(run_id=row.id, key=key, amount=amount, share=share))
    for key, share in list(run.src.items())[:150]:
        if KEY_RE.match(key) and 0.0 < share <= 1.0:
            db.add(SrcShare(run_id=row.id, key=key[:48], share=share))
    # 닉네임을 바꾸면 예전 기록에도 새 이름이 보이게
    db.execute(update(Run).where(Run.device_id == run.device, Run.nickname != nick).values(nickname=nick))
    db.commit()
    rank = None
    if row.valid and season:
        rank = board_rank(db, run.map, run.rules, season, None, run.device)
    return {"id": row.id, "accepted": row.valid, "season": season, "rank": rank}


class ErrIn(BaseModel):
    kind: str = Field("error", max_length=16)
    msg: str = Field("", max_length=1000)
    file: str = Field("", max_length=200)
    line: int = 0
    fn: str = Field("", max_length=100)
    bt: str = Field("", max_length=4000)
    n: int = Field(1, ge=1, le=1_000_000)
    map: str = Field("", max_length=32)
    rules: int = 0
    modes: str = Field("", max_length=200)
    skin: str = Field("", max_length=32)
    wave: int = 0


class LogsIn(BaseModel):
    device: str = Field(min_length=8, max_length=64)
    platform: str = Field("", max_length=16)
    os: str = Field("", max_length=64)
    game: str = Field(max_length=32)
    patch: int = 0
    entries: list[ErrIn] = Field(max_length=20)


def log_fp(kind: str, file: str, line: int, msg: str, bt: str) -> str:
    # 엔진 위치 + 스크립트 쪽 첫 줄로 묶는다 (글에 숫자·이름이 섞여도 같은 오류). 둘 다 없으면 글로. scripts/errlog.gd와 같은 규칙
    m = re.search(r"\[0\]([^\n]*)", bt)
    top = m.group(1).strip() if m else ""
    key = f"{kind}|{file}|{line}|{top}|{msg[:200] if not top and not file else ''}"
    return hashlib.sha1(key.encode()).hexdigest()


@app.post("/v1/logs")
async def submit_logs(request: Request, x_bindu_mac: str = Header(default=""), db: Session = Depends(get_db)):
    body = await request.body()
    if len(body) > 128_000:
        raise HTTPException(413, "too large")
    if not signing.check_run_mac(body, x_bindu_mac):
        raise HTTPException(403, "bad signature")
    try:
        req = LogsIn.model_validate_json(body)
    except Exception as e:
        raise HTTPException(422, str(e)[:300])
    ip = signing.ip_hash(request.client.host if request.client else "")
    t = now()
    hour = t - timedelta(hours=1)
    n_dev = db.scalar(select(func.count()).select_from(ClientLog).where(ClientLog.device_id == req.device, ClientLog.created_at > hour))
    n_ip = db.scalar(select(func.count()).select_from(ClientLog).where(ClientLog.ip_hash == ip, ClientLog.created_at > hour))
    if n_dev + len(req.entries) > config.LOG_PER_DEVICE_HOUR or n_ip + len(req.entries) > config.LOG_PER_IP_HOUR:
        raise HTTPException(429, "too many")
    for e in req.entries:
        db.add(ClientLog(fp=log_fp(e.kind, e.file, e.line, e.msg, e.bt), device_id=req.device, ip_hash=ip, platform=req.platform, os=req.os,
                         game_version=req.game, patch_id=req.patch, map=e.map, rules=e.rules, modes=e.modes, skin=e.skin, wave=e.wave,
                         kind=e.kind, message=e.msg, file=e.file, line=e.line, func=e.fn, backtrace=e.bt, count=e.n))
    db.execute(delete(ClientLog).where(ClientLog.created_at < t - timedelta(days=config.LOG_KEEP_DAYS)))
    db.commit()
    return {"ok": True, "saved": len(req.entries)}


def _board(db: Session, map_id: str, rules: int, season: int, since):
    """기기마다 최고 기록 하나씩."""
    conds = [Run.map == map_id, Run.rules == rules, Run.season == season, Run.valid.is_(True), Run.hidden.is_(False)]
    if since is not None:
        conds.append(Run.created_at >= since)
    rn = func.row_number().over(partition_by=Run.device_id, order_by=(Run.score.desc(), Run.wave.desc(), Run.id)).label("rn")
    sub = select(Run.id, Run.device_id, Run.nickname, Run.wave, Run.score, Run.game_version, Run.created_at, Run.ended, rn).where(*conds).subquery()
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
                "date": r.created_at.strftime("%Y-%m-%d"), "me": r.device_id == device, "ended": r.ended} for i, r in enumerate(rows)]
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
    url: str = ""  # 비우면 지난번 주소 그대로
    notes: str = ""
    sha256: str = ""  # 비우면 서버가 url 파일을 받아 직접 계산
    size: int = 0


RELEASE_MAX_BYTES = 400 * 1024 * 1024


def release_payload(platform: str, version: str, url: str, sha256: str, size: int) -> str:
    """게임(scripts/updater.gd)이 서명을 확인하는 문자열. 둘이 같아야 한다."""
    return f"bindu-release|{platform}|{version}|{url}|{sha256}|{size}"


def fetch_hash(url: str) -> tuple[str, int]:
    h, n = hashlib.sha256(), 0
    req = urllib.request.Request(url, headers={"User-Agent": "bindu-server"})
    with urllib.request.urlopen(req, timeout=60) as f:
        while chunk := f.read(1 << 20):
            n += len(chunk)
            if n > RELEASE_MAX_BYTES:
                raise ValueError("파일이 너무 큼")
            h.update(chunk)
    return h.hexdigest(), n


@app.put("/admin/releases/{platform}", dependencies=[Depends(require_admin)])
def set_release(platform: str, body: ReleaseIn, db: Session = Depends(get_db)):
    platform = platform.lower()
    if platform not in PLATFORMS:
        raise HTTPException(422, f"platform: {PLATFORMS}")
    r = db.get(Release, platform) or Release(platform=platform)
    url = body.url.strip() or (r.url or "")
    sha, size = body.sha256.strip().lower(), body.size
    if sha and not re.fullmatch(r"[0-9a-f]{64}", sha):
        raise HTTPException(422, "sha256: 16진수 64자")
    if not sha and url and platform == "windows":
        try:
            sha, size = fetch_hash(url)
        except Exception as e:
            raise HTTPException(422, f"url 파일을 받지 못함: {e}")
    r.version, r.url, r.notes, r.sha256, r.size = body.version, url, body.notes, sha, size
    db.add(r)
    db.commit()
    return {"platform": platform, "version": r.version, "url": r.url, "sha256": r.sha256, "size": r.size}


@app.get("/admin/releases", dependencies=[Depends(require_admin)])
def list_releases(db: Session = Depends(get_db)):
    return [{"platform": r.platform, "version": r.version, "url": r.url, "notes": r.notes, "sha256": r.sha256, "size": r.size}
            for r in db.scalars(select(Release))]


@app.get("/admin/runs", dependencies=[Depends(require_admin)])
def list_runs(invalid: bool = False, limit: int = Query(50, le=500), db: Session = Depends(get_db)):
    q = select(Run).order_by(Run.id.desc()).limit(limit)
    if invalid:
        q = q.where(Run.valid.is_(False))
    return [{"id": r.id, "created": r.created_at.isoformat(), "device": r.device_id, "nick": r.nickname, "game": r.game_version,
             "patch": r.patch_id, "season": r.season, "map": r.map, "rules": r.rules, "wave": r.wave, "score": r.score,
             "valid": r.valid, "reason": r.reason, "hidden": r.hidden, "ended": r.ended} for r in db.scalars(q)]


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
              ended_only: bool = False, db: Session = Depends(get_db)):
    return stats.summary(db, stats.Filter(rules, map, game, patch, days, valid_only, ended_only))


@app.get("/admin/api/stats.csv", dependencies=[Depends(require_admin)], response_class=PlainTextResponse)
def get_stats_csv(kind: str = "picks", rules: int = 0, map: str = "", game: str = "", patch: int = -1, days: int = 0,
                  valid_only: bool = True, ended_only: bool = False, db: Session = Depends(get_db)):
    data = stats.summary(db, stats.Filter(rules, map, game, patch, days, valid_only, ended_only))
    return PlainTextResponse(stats.to_csv(data, kind), media_type="text/csv; charset=utf-8",
                             headers={"Content-Disposition": f'attachment; filename="bindu_{kind}.csv"'})


def _log_filter(q, game: str, platform: str, days: int):
    if game:
        q = q.where(ClientLog.game_version == game)
    if platform:
        q = q.where(ClientLog.platform == platform)
    if days > 0:
        q = q.where(ClientLog.created_at > now() - timedelta(days=days))
    return q


@app.get("/admin/api/logs", dependencies=[Depends(require_admin)])
def list_logs(game: str = "", platform: str = "", days: int = 0, limit: int = Query(100, le=500), db: Session = Depends(get_db)):
    """같은 오류(fp)끼리 묶은 목록. 많이 난 것부터."""
    q = select(ClientLog.fp, func.sum(ClientLog.count).label("times"), func.count(func.distinct(ClientLog.device_id)).label("devices"),
               func.min(ClientLog.created_at).label("first"), func.max(ClientLog.created_at).label("last"), func.max(ClientLog.id).label("sample"))
    q = _log_filter(q, game, platform, days).group_by(ClientLog.fp).order_by(func.sum(ClientLog.count).desc()).limit(limit)
    out = []
    for r in db.execute(q).all():
        s = db.get(ClientLog, r.sample)
        vq = _log_filter(select(ClientLog.game_version).where(ClientLog.fp == r.fp), game, platform, days).distinct()
        pq = _log_filter(select(ClientLog.platform).where(ClientLog.fp == r.fp), game, platform, days).distinct()
        out.append({"fp": r.fp, "times": int(r.times or 0), "devices": r.devices, "first": r.first.isoformat(), "last": r.last.isoformat(),
                    "kind": s.kind, "message": s.message, "file": s.file, "line": s.line, "func": s.func,
                    "versions": sorted(db.scalars(vq).all()), "platforms": sorted(db.scalars(pq).all())})
    return out


@app.get("/admin/api/logs/{fp}", dependencies=[Depends(require_admin)])
def log_detail(fp: str, limit: int = Query(30, le=200), db: Session = Depends(get_db)):
    """한 오류의 최근 기록: 그때의 버전·규칙·맵·모드·웨이브·백트레이스."""
    rows = db.scalars(select(ClientLog).where(ClientLog.fp == fp).order_by(ClientLog.id.desc()).limit(limit)).all()
    return [{"created": r.created_at.isoformat(), "device": r.device_id, "platform": r.platform, "os": r.os, "game": r.game_version,
             "patch": r.patch_id, "map": r.map, "rules": r.rules, "modes": r.modes, "skin": r.skin, "wave": r.wave, "count": r.count,
             "kind": r.kind, "message": r.message, "file": r.file, "line": r.line, "func": r.func, "backtrace": r.backtrace} for r in rows]


@app.get("/admin", response_class=HTMLResponse)
def admin_page():
    return (Path(__file__).parent / "admin.html").read_text(encoding="utf-8")


def _404():
    raise HTTPException(404, "not found")
