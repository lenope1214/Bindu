"""계정: 로그인 수단(기기·소셜)과 플레이어를 나눠, 어느 기기에서든 같은 진행을 이어 간다.

- 처음 켜면 기기 id + 기기 비밀값으로 익명 계정 (POST /v1/auth/device). 비밀값은 해시만 둔다.
- 소셜 연결(POST /v1/auth/link): 처음 보는 소셜이면 지금 계정에 붙이고, 다른 계정에 이미 붙어 있으면 두 계정을 합친다.
- 진행(saves)은 progress.merge로 합쳐서 덮어쓰지 않는다. 진행 중 판(run_saves)은 한 판을 한 기기만 이어 한다.
"""
import base64
import hashlib
import hmac
import json
import re
import secrets
import time
import urllib.request
from datetime import timedelta

from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import padding, rsa
from fastapi import APIRouter, Depends, Header, HTTPException, Request
from pydantic import BaseModel, Field
from sqlalchemy import delete, func, select, update
from sqlalchemy.orm import Session

from . import config, progress, signing
from .db import Account, Ban, Identity, Pick, Run, RunSave, Save, Vote, get_db, now

router = APIRouter()

DEVICE_RE = r"^[A-Za-z0-9-]{8,64}$"
RUN_SAVE_MAX = 5  # 계정 하나에 남겨 둘 진행 중 판 수
RUN_SAVE_BYTES = 400_000
RUN_SAVE_DAYS = 30

_secret: bytes | None = None


def _key() -> bytes:
    global _secret
    if _secret is None:
        if config.AUTH_SECRET:
            _secret = config.AUTH_SECRET.encode()
        elif config.ADMIN_TOKEN:
            _secret = hmac.new(config.ADMIN_TOKEN.encode(), b"bindu-auth", hashlib.sha256).digest()
        else:
            _secret = secrets.token_bytes(32)  # 개발용: 서버를 다시 켜면 토큰이 무효 (게임은 기기 인증으로 다시 받음)
    return _secret


# ---------- 토큰 ----------

def make_token(account: str, device: str) -> tuple[str, int]:
    exp = int(time.time()) + config.AUTH_TOKEN_DAYS * 86400
    body = f"{account}.{device}.{exp}"
    return body + "." + hmac.new(_key(), body.encode(), hashlib.sha256).hexdigest(), exp


def read_token(token: str) -> tuple[str, str] | None:
    """(계정, 기기) 또는 None (틀렸거나 만료)."""
    parts = token.split(".")
    if len(parts) != 4:
        return None
    body = ".".join(parts[:3])
    if not hmac.compare_digest(hmac.new(_key(), body.encode(), hashlib.sha256).hexdigest(), parts[3]):
        return None
    try:
        if int(parts[2]) < time.time():
            return None
    except ValueError:
        return None
    return parts[0], parts[1]


def resolve(db: Session, account_id: str) -> Account | None:
    """합쳐진 계정이면 남은 계정까지 따라간다."""
    a = db.get(Account, account_id)
    for _ in range(8):
        if a is None or not a.merged_into:
            return a
        a = db.get(Account, a.merged_into)
    return None


def optional(db: Session, authorization: str) -> tuple[Account, str] | None:
    if not authorization.startswith("Bearer "):
        return None
    t = read_token(authorization[7:].strip())
    if t is None:
        return None
    a = resolve(db, t[0])
    return (a, t[1]) if a else None


def current(authorization: str = Header(default=""), db: Session = Depends(get_db)) -> tuple[Account, str]:
    me = optional(db, authorization)
    if me is None:
        raise HTTPException(401, "token")
    return me


def _out(db: Session, a: Account, device: str, **extra) -> dict:
    token, exp = make_token(a.id, device)
    linked = sorted({i.provider for i in db.scalars(select(Identity).where(Identity.account_id == a.id)) if i.provider != "device"})
    return {"token": token, "expires": exp, "account": a.id, "nick": a.nickname, "linked": linked, **extra}


def _sha(s: str) -> str:
    return hashlib.sha256(s.encode()).hexdigest()


# ---------- 기기 인증 ----------

class DeviceIn(BaseModel):
    device: str = Field(pattern=DEVICE_RE)
    secret: str = Field(pattern=r"^[0-9a-f]{64}$")
    nick: str = Field("", max_length=64)


@router.post("/v1/auth/device")
def auth_device(body: DeviceIn, request: Request, db: Session = Depends(get_db)):
    idt = db.scalars(select(Identity).where(Identity.provider == "device", Identity.subject == body.device)).first()
    if idt is not None:
        if not hmac.compare_digest(idt.secret_hash, _sha(body.secret)):
            # 저장 파일을 다른 기기로 복사한 경우 등: 게임은 새 기기 id를 만들어 다시 온다
            raise HTTPException(403, "device_taken")
        a = resolve(db, idt.account_id)
        if a is None:
            raise HTTPException(403, "device_taken")
        idt.account_id = a.id
        idt.last_seen = now()
        db.commit()
        return _out(db, a, body.device, new=False)
    ip = signing.ip_hash(request.client.host if request.client else "")
    n = db.scalar(select(func.count()).select_from(Identity).where(
        Identity.provider == "device", Identity.ip_hash == ip, Identity.created_at > now() - timedelta(hours=1)))
    if n >= config.AUTH_NEW_PER_IP_HOUR:
        raise HTTPException(429, "too many")
    from .main import clean_nick  # 순환 import 피함
    a = Account(id=secrets.token_hex(16), nickname=clean_nick(body.nick, body.device))
    db.add(a)
    db.add(Identity(provider="device", subject=body.device, account_id=a.id, secret_hash=_sha(body.secret), ip_hash=ip))
    db.flush()
    # 이 기기가 예전에 남긴 판 기록을 이 계정으로 묶는다 (처음 인증한 기기만)
    db.execute(update(Run).where(Run.device_id == body.device, Run.account_id.is_(None)).values(account_id=a.id))
    if db.get(Ban, body.device):
        a.banned = True
    db.commit()
    return _out(db, a, body.device, new=True)


@router.get("/v1/me")
def me(cur=Depends(current), db: Session = Depends(get_db)):
    a, device = cur
    return _out(db, a, device)


# ---------- 진행 ----------

class SaveIn(BaseModel):
    data: dict
    base_rev: int = -1


def _save_of(db: Session, account_id: str) -> Save:
    s = db.get(Save, account_id)
    if s is None:
        s = Save(account_id=account_id, format=progress.FORMAT, rev=0, data=progress.empty())
        db.add(s)
    return s


@router.get("/v1/save")
def get_save(cur=Depends(current), db: Session = Depends(get_db)):
    a, _ = cur
    s = db.get(Save, a.id)
    return {"rev": s.rev if s else 0, "data": s.data if s else progress.empty()}


@router.put("/v1/save")
def put_save(body: SaveIn, cur=Depends(current), db: Session = Depends(get_db)):
    """올린 진행을 서버 것과 합쳐 저장하고 합친 결과를 돌려준다 (게임은 그걸 그대로 쓴다)."""
    a, device = cur
    try:
        mine = progress.clean(body.data)
    except (ValueError, TypeError) as e:
        raise HTTPException(422, f"progress: {e}")
    s = _save_of(db, a.id)
    old = progress.clean(s.data) if s.data else progress.empty()
    merged = progress.merge(old, mine)
    past = "past-" + device[:59]
    if past not in merged["tally"]:
        merged["tally"][past] = past_picks(db, device)
    if merged != old:
        s.data, s.rev, s.device = merged, s.rev + 1, device
    n = progress.nick(merged)
    if n:
        from .main import clean_nick
        a.nickname = clean_nick(n, device)
    db.commit()
    return {"rev": s.rev, "data": merged}


BACKFILL_BEFORE = (0, 5, 5)  # 이 버전부터는 게임이 카드 고른 횟수를 직접 센다


def _ver(v: str) -> tuple:
    try:
        return tuple(int(x) for x in v.split("."))
    except ValueError:
        return (0,)


def past_picks(db: Session, device: str) -> dict:
    """도감 수집을 처음 맞출 때 한 번: 이 기기가 예전 버전으로 한 판들의 카드·특성 고른 횟수 {"pick:키": 수}."""
    ids = [rid for rid, gv in db.execute(select(Run.id, Run.game_version).where(Run.device_id == device)) if _ver(gv) < BACKFILL_BEFORE]
    out: dict[str, int] = {}
    for i in range(0, len(ids), 500):
        rows = db.execute(select(Pick.key, func.count()).where(Pick.run_id.in_(ids[i:i + 500]), Pick.picked.is_(True),
                                                               Pick.kind.in_(("card", "perk"))).group_by(Pick.key))
        for key, n in rows:
            if not key.startswith("cata:"):
                out["pick:" + key] = out.get("pick:" + key, 0) + int(n)
    return out


# ---------- 진행 중 판 ----------

class RunSaveIn(BaseModel):
    game: str = Field(pattern=r"^[0-9.]{1,16}$")
    platform: str = Field("", pattern=r"^[a-z]{0,16}$")
    map: str = Field(pattern=r"^[a-z]{1,16}$")
    rules: int = 0
    wave: int = 0
    score: int = 0
    data: str = Field(max_length=RUN_SAVE_BYTES)


RUN_KEY_RE = re.compile(r"^[A-Za-z0-9-]{1,40}$")


def _run_row(db: Session, account_id: str, run_key: str) -> RunSave | None:
    if not RUN_KEY_RE.match(run_key):
        raise HTTPException(422, "run")
    return db.scalars(select(RunSave).where(RunSave.account_id == account_id, RunSave.run_key == run_key)).first()


def _run_out(r: RunSave, device: str, with_data=False) -> dict:
    d = {"run": r.run_key, "mine": r.holder == device, "game": r.game_version, "platform": r.platform, "map": r.map,
         "rules": r.rules, "wave": r.wave, "score": r.score, "updated": r.updated_at.isoformat()}
    if with_data:
        d["data"] = r.data
    return d


@router.get("/v1/save/runs")
def list_run_saves(cur=Depends(current), db: Session = Depends(get_db)):
    a, device = cur
    db.execute(delete(RunSave).where(RunSave.account_id == a.id, RunSave.updated_at < now() - timedelta(days=RUN_SAVE_DAYS)))
    db.commit()
    rows = db.scalars(select(RunSave).where(RunSave.account_id == a.id).order_by(RunSave.updated_at.desc()))
    return [_run_out(r, device) for r in rows]


@router.put("/v1/save/runs/{run_key}")
def put_run_save(run_key: str, body: RunSaveIn, cur=Depends(current), db: Session = Depends(get_db)):
    """쉬는 시간마다 올린다. 다른 기기가 이 판을 가져갔으면 409 (이 기기의 이어하기는 지운다)."""
    a, device = cur
    r = _run_row(db, a.id, run_key)
    if r is not None and r.holder and r.holder != device:
        raise HTTPException(409, "moved")
    if r is None:
        r = RunSave(account_id=a.id, run_key=run_key)
        db.add(r)
    r.holder, r.game_version, r.platform, r.map, r.rules = device, body.game, body.platform, body.map, body.rules
    r.wave, r.score, r.data, r.updated_at = max(0, body.wave), max(0, body.score), body.data, now()
    db.flush()
    extra = db.scalars(select(RunSave.id).where(RunSave.account_id == a.id).order_by(RunSave.updated_at.desc()).offset(RUN_SAVE_MAX)).all()
    if extra:
        db.execute(delete(RunSave).where(RunSave.id.in_(extra)))
    db.commit()
    return {"ok": True}


@router.post("/v1/save/runs/{run_key}/claim")
def claim_run_save(run_key: str, cur=Depends(current), db: Session = Depends(get_db)):
    """다른 기기에서 하던 판을 이 기기로 가져온다. 원래 기기는 다음에 올릴 때 409를 받고 그 판을 지운다."""
    a, device = cur
    r = _run_row(db, a.id, run_key) or _404()
    r.holder = device
    r.updated_at = now()
    db.commit()
    return _run_out(r, device, with_data=True)


@router.delete("/v1/save/runs/{run_key}")
def delete_run_save(run_key: str, cur=Depends(current), db: Session = Depends(get_db)):
    """판이 끝났거나 이 기기에서 새로 시작해 지운 판. 다른 기기가 가져간 판은 지우지 않는다."""
    a, device = cur
    r = _run_row(db, a.id, run_key)
    if r is None:
        return {"ok": True}
    if r.holder and r.holder != device:
        raise HTTPException(409, "moved")
    db.delete(r)
    db.commit()
    return {"ok": True}


# ---------- 소셜 연결 ----------

_jwks: dict[str, tuple[float, dict]] = {}
JWKS_TTL = 3600.0
PROVIDERS = {
    "google": {"jwks": "https://www.googleapis.com/oauth2/v3/certs", "iss": {"https://accounts.google.com", "accounts.google.com"},
               "aud": lambda: config.GOOGLE_CLIENT_IDS},
    "apple": {"jwks": "https://appleid.apple.com/auth/keys", "iss": {"https://appleid.apple.com"}, "aud": lambda: config.APPLE_CLIENT_IDS},
}


def _b64(s: str) -> bytes:
    return base64.urlsafe_b64decode(s + "=" * (-len(s) % 4))


def _keys(url: str) -> dict:
    hit = _jwks.get(url)
    if hit and time.time() - hit[0] < JWKS_TTL:
        return hit[1]
    with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "bindu-server"}), timeout=10) as f:
        keys = {k["kid"]: k for k in json.loads(f.read()).get("keys", []) if k.get("kty") == "RSA"}
    _jwks[url] = (time.time(), keys)
    return keys


def verify_id_token(provider: str, token: str) -> str:
    """Google·Apple ID 토큰(RS256 JWT)을 확인하고 subject를 돌려준다. 틀리면 ValueError."""
    p = PROVIDERS[provider]
    try:
        h64, b64, s64 = token.split(".")
        head, claims = json.loads(_b64(h64)), json.loads(_b64(b64))
    except Exception:
        raise ValueError("형식")
    if head.get("alg") != "RS256":
        raise ValueError("alg")
    jwk = _keys(p["jwks"]).get(head.get("kid", ""))
    if jwk is None:
        _jwks.pop(p["jwks"], None)  # 키를 바꿨을 수 있다: 한 번 다시 받는다
        jwk = _keys(p["jwks"]).get(head.get("kid", ""))
    if jwk is None:
        raise ValueError("kid")
    pub = rsa.RSAPublicNumbers(int.from_bytes(_b64(jwk["e"]), "big"), int.from_bytes(_b64(jwk["n"]), "big")).public_key()
    try:
        pub.verify(_b64(s64), f"{h64}.{b64}".encode(), padding.PKCS1v15(), hashes.SHA256())
    except Exception:
        raise ValueError("서명")
    aud = claims.get("aud")
    auds = aud if isinstance(aud, list) else [aud]
    if claims.get("iss") not in p["iss"] or not set(auds) & set(p["aud"]()):
        raise ValueError("iss/aud")
    if float(claims.get("exp", 0)) < time.time():
        raise ValueError("만료")
    sub = str(claims.get("sub", ""))
    if not sub or len(sub) > 128:
        raise ValueError("sub")
    return sub


def subject_of(provider: str, credential: str) -> str:
    if provider == "test":
        if not config.AUTH_TEST_PROVIDER:
            raise HTTPException(501, "provider_not_configured")
        if not re.fullmatch(r"[A-Za-z0-9_-]{1,64}", credential):
            raise HTTPException(401, "credential")
        return credential
    if provider not in PROVIDERS:
        raise HTTPException(422, "provider")
    if not PROVIDERS[provider]["aud"]():
        raise HTTPException(501, "provider_not_configured")
    try:
        return verify_id_token(provider, credential)
    except ValueError as e:
        raise HTTPException(401, f"credential: {e}")


def merge_accounts(db: Session, src: Account, dst: Account) -> None:
    """src를 dst에 합친다: 진행 합치기, 판 기록·진행 중 판·로그인 수단을 dst로. src는 merged_into만 남긴다."""
    s, d = db.get(Save, src.id), _save_of(db, dst.id)
    if s is not None:
        merged = progress.merge(progress.clean(d.data) if d.data else progress.empty(), progress.clean(s.data))
        d.data, d.rev = merged, d.rev + 1
        db.delete(s)
        n = progress.nick(merged)
        if n:
            dst.nickname = n[:32]
    for r in db.scalars(select(RunSave).where(RunSave.account_id == src.id)).all():
        if _run_row(db, dst.id, r.run_key) is None:
            r.account_id = dst.id
        else:
            db.delete(r)
    db.execute(update(Identity).where(Identity.account_id == src.id).values(account_id=dst.id))
    db.execute(update(Run).where(Run.account_id == src.id).values(account_id=dst.id))
    db.execute(update(Account).where(Account.merged_into == src.id).values(merged_into=dst.id))
    from . import votes  # votes가 accounts를 읽으므로 여기서
    votes.move_votes(db, src.id, dst.id)
    dst.banned = dst.banned or src.banned
    src.merged_into = dst.id


class LinkIn(BaseModel):
    provider: str = Field(pattern=r"^[a-z]{1,16}$")
    credential: str = Field(max_length=8000)


@router.post("/v1/auth/link")
def link(body: LinkIn, cur=Depends(current), db: Session = Depends(get_db)):
    a, device = cur
    if body.provider == "device":
        raise HTTPException(422, "provider")
    sub = subject_of(body.provider, body.credential)
    idt = db.scalars(select(Identity).where(Identity.provider == body.provider, Identity.subject == sub)).first()
    merged = False
    if idt is None:
        # 같은 수단의 다른 계정(예: 다른 Google 계정)이 이미 붙어 있으면 바꿔 끼운다
        db.execute(delete(Identity).where(Identity.account_id == a.id, Identity.provider == body.provider))
        db.add(Identity(provider=body.provider, subject=sub, account_id=a.id))
    else:
        dst = resolve(db, idt.account_id)
        if dst is not None and dst.id != a.id:
            # 이 소셜이 먼저 붙은 계정이 남는다 (다른 기기에서 쓰던 계정)
            merge_accounts(db, a, dst)
            a, merged = dst, True
        idt.last_seen = now()
    db.commit()
    return _out(db, a, device, merged=merged)


@router.delete("/v1/auth/link/{provider}")
def unlink(provider: str, cur=Depends(current), db: Session = Depends(get_db)):
    a, device = cur
    if provider == "device":
        raise HTTPException(422, "provider")
    db.execute(delete(Identity).where(Identity.account_id == a.id, Identity.provider == provider))
    db.commit()
    return _out(db, a, device)


@router.delete("/v1/account")
def delete_account(cur=Depends(current), db: Session = Depends(get_db)):
    """계정 지우기: 진행·진행 중 판·로그인 수단을 지우고, 판 기록은 통계로만 남긴다(리더보드에서 빼고 이름 지움).
    이 기기는 다음에 켤 때 새 익명 계정을 받는다."""
    a, _ = cur
    db.execute(delete(Save).where(Save.account_id == a.id))
    db.execute(delete(RunSave).where(RunSave.account_id == a.id))
    devices = [i.subject for i in db.scalars(select(Identity).where(Identity.account_id == a.id, Identity.provider == "device"))]
    db.execute(delete(Identity).where(Identity.account_id == a.id))
    db.execute(delete(Vote).where(Vote.account_id == a.id))
    db.execute(update(Run).where(Run.account_id == a.id).values(account_id=None, nickname="", hidden=True))
    if devices:
        db.execute(update(Run).where(Run.device_id.in_(devices)).values(nickname="", hidden=True))
    db.execute(delete(Account).where((Account.id == a.id) | (Account.merged_into == a.id)))
    db.commit()
    return {"deleted": True}


def _404():
    raise HTTPException(404, "not found")
