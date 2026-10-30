"""DB 테이블. PostgreSQL(운영)과 SQLite(테스트) 모두 동작."""
from datetime import datetime, timedelta, timezone

from sqlalchemy import (JSON, Boolean, DateTime, Float, ForeignKey, Integer, String, Text, create_engine, inspect, text)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, sessionmaker

from . import config


def now() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


KST = timezone(timedelta(hours=9))


def kst_date(t: datetime) -> str:
    """저장은 UTC(tz 없음), 사람에게 보이는 날짜는 한국 시간."""
    return t.replace(tzinfo=timezone.utc).astimezone(KST).strftime("%Y-%m-%d")


class Base(DeclarativeBase):
    pass


class Patch(Base):
    """JSON 데이터 패치. 활성화된 것 중 게임 버전 범위가 맞는 가장 최신 것을 내려 준다."""
    __tablename__ = "patches"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now)
    notes: Mapped[str] = mapped_column(Text, default="")
    min_game: Mapped[str] = mapped_column(String(32), default="0.0.0")
    max_game: Mapped[str] = mapped_column(String(32), default="")  # 빈 값: 상한 없음
    data: Mapped[dict] = mapped_column(JSON)
    payload: Mapped[str] = mapped_column(Text)  # 서명한 그대로의 JSON 글자
    sig: Mapped[str] = mapped_column(Text)
    active: Mapped[bool] = mapped_column(Boolean, default=True)
    season: Mapped[int] = mapped_column(Integer, default=0)  # 이 패치를 올릴 때의 시즌


class Season(Base):
    """리더보드 시즌. 판도가 바뀌는 패치·빌드마다 새로 연다.
    판 기록은 지금 시즌의 최소 게임 버전·패치를 맞춘 경우에만 그 시즌 리더보드에 들어간다."""
    __tablename__ = "seasons"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(64), default="")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now)
    min_game: Mapped[str] = mapped_column(String(32), default="0.0.0")
    min_patch: Mapped[int] = mapped_column(Integer, default=0)


class Release(Base):
    """플랫폼별 최신 빌드 (새 버전 알림)."""
    __tablename__ = "releases"
    platform: Mapped[str] = mapped_column(String(16), primary_key=True)
    version: Mapped[str] = mapped_column(String(32))
    url: Mapped[str] = mapped_column(Text, default="")
    notes: Mapped[str] = mapped_column(Text, default="")
    sha256: Mapped[str] = mapped_column(String(64), default="")  # 받을 파일(zip) 해시: 게임 안 업데이트가 확인
    size: Mapped[int] = mapped_column(Integer, default=0)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=now, onupdate=now)


class Run(Base):
    """끝난 판 하나. 리더보드와 통계가 같은 기록을 쓴다."""
    __tablename__ = "runs"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now, index=True)
    device_id: Mapped[str] = mapped_column(String(64), index=True)
    nickname: Mapped[str] = mapped_column(String(32), default="")
    ip_hash: Mapped[str] = mapped_column(String(64), default="", index=True)
    platform: Mapped[str] = mapped_column(String(16), default="")
    game_version: Mapped[str] = mapped_column(String(32), index=True)
    patch_id: Mapped[int] = mapped_column(Integer, default=0, index=True)
    season: Mapped[int] = mapped_column(Integer, default=0, index=True)  # 0: 지난 버전으로 한 판 (리더보드 제외)
    map: Mapped[str] = mapped_column(String(32), index=True)
    rules: Mapped[int] = mapped_column(Integer, index=True)
    wave: Mapped[int] = mapped_column(Integer)
    score: Mapped[int] = mapped_column(Integer)
    kills: Mapped[int] = mapped_column(Integer, default=0)
    best_combo: Mapped[int] = mapped_column(Integer, default=0)
    game_secs: Mapped[float] = mapped_column(Float, default=0.0)
    real_secs: Mapped[float] = mapped_column(Float, default=0.0)
    detail: Mapped[dict] = mapped_column(JSON, default=dict)  # 특성·오브젝트 구성·선택 기록 원본
    valid: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    reason: Mapped[str] = mapped_column(Text, default="")  # 검증에 걸린 이유
    hidden: Mapped[bool] = mapped_column(Boolean, default=False)  # 관리자가 리더보드에서 뺀 기록
    # 진행 중 판: 게임이 5웨이브마다 같은 run_key로 다시 보내면 이 줄을 고친다. 예전 버전 기록은 run_key 없이 끝난 판
    run_key: Mapped[str] = mapped_column(String(40), default="", index=True)
    ended: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=now, onupdate=now)


class Pick(Base):
    """선택지 한 장: 나왔는지, 골랐는지. 통계용으로 판 정보를 같이 둔다."""
    __tablename__ = "picks"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    run_id: Mapped[int] = mapped_column(ForeignKey("runs.id", ondelete="CASCADE"), index=True)
    kind: Mapped[str] = mapped_column(String(8))  # card | perk
    key: Mapped[str] = mapped_column(String(48), index=True)  # 예: elem:fire, pat:spray, mod:rapid, perk:power
    picked: Mapped[bool] = mapped_column(Boolean)
    wave: Mapped[int] = mapped_column(Integer)


class Final(Base):
    """판이 끝났을 때 오브젝트에 들어 있던 것 (속성·공격방식·강화·연계)."""
    __tablename__ = "finals"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    run_id: Mapped[int] = mapped_column(ForeignKey("runs.id", ondelete="CASCADE"), index=True)
    key: Mapped[str] = mapped_column(String(48), index=True)
    amount: Mapped[int] = mapped_column(Integer, default=1)  # 레벨·겹친 수 합
    share: Mapped[float] = mapped_column(Float, default=0.0)  # 그 오브젝트들이 낸 피해 몫 합


class SrcShare(Base):
    """판 전체 피해 중 출처(속성·공격방식·강화·반응·연계)별 몫. 직접 타격 안의 배율 몫은 게임이 추정한 값."""
    __tablename__ = "src_shares"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    run_id: Mapped[int] = mapped_column(ForeignKey("runs.id", ondelete="CASCADE"), index=True)
    key: Mapped[str] = mapped_column(String(48), index=True)  # 예: elem:fire, pat:spray, mod:rapid, rx:lava, link:pincer, etc:crowd
    share: Mapped[float] = mapped_column(Float, default=0.0)


class ClientLog(Base):
    """게임이 보낸 오류 하나 (scripts/errlog.gd). fp가 같은 것끼리 관리 페이지에서 묶어 보여 준다."""
    __tablename__ = "client_logs"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now, index=True)
    fp: Mapped[str] = mapped_column(String(40), index=True)  # 종류·파일·줄·글 해시
    device_id: Mapped[str] = mapped_column(String(64), index=True)
    ip_hash: Mapped[str] = mapped_column(String(64), default="", index=True)
    platform: Mapped[str] = mapped_column(String(16), default="")
    os: Mapped[str] = mapped_column(String(64), default="")
    game_version: Mapped[str] = mapped_column(String(32), index=True)
    patch_id: Mapped[int] = mapped_column(Integer, default=0)
    map: Mapped[str] = mapped_column(String(32), default="")
    rules: Mapped[int] = mapped_column(Integer, default=0)
    modes: Mapped[str] = mapped_column(String(200), default="")
    skin: Mapped[str] = mapped_column(String(32), default="")
    wave: Mapped[int] = mapped_column(Integer, default=0)
    kind: Mapped[str] = mapped_column(String(16), default="error")  # error | warning | script | shader | printerr
    message: Mapped[str] = mapped_column(Text, default="")
    file: Mapped[str] = mapped_column(String(200), default="")
    line: Mapped[int] = mapped_column(Integer, default=0)
    func: Mapped[str] = mapped_column(String(100), default="")
    backtrace: Mapped[str] = mapped_column(Text, default="")
    count: Mapped[int] = mapped_column(Integer, default=1)  # 보내기 전 같은 오류가 난 횟수


class Ban(Base):
    __tablename__ = "bans"
    device_id: Mapped[str] = mapped_column(String(64), primary_key=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now)
    reason: Mapped[str] = mapped_column(Text, default="")


_kw = {"connect_args": {"check_same_thread": False}} if config.DATABASE_URL.startswith("sqlite") else {"pool_pre_ping": True}
engine = create_engine(config.DATABASE_URL, **_kw)
SessionLocal = sessionmaker(bind=engine, expire_on_commit=False)


def init_db() -> None:
    Base.metadata.create_all(engine)
    # create_all은 이미 있는 표에 열을 더하지 않는다: 나중에 생긴 열은 여기서
    have = {c["name"] for c in inspect(engine).get_columns("releases")}
    have_runs = {c["name"] for c in inspect(engine).get_columns("runs")}
    with engine.begin() as con:
        if "run_key" not in have_runs:
            con.execute(text("ALTER TABLE runs ADD COLUMN run_key VARCHAR(40) DEFAULT ''"))
            con.execute(text("CREATE INDEX IF NOT EXISTS ix_runs_run_key ON runs (run_key)"))
        if "ended" not in have_runs:
            con.execute(text("ALTER TABLE runs ADD COLUMN ended BOOLEAN DEFAULT TRUE"))
        if "updated_at" not in have_runs:
            con.execute(text("ALTER TABLE runs ADD COLUMN updated_at TIMESTAMP"))
        if "sha256" not in have:
            con.execute(text("ALTER TABLE releases ADD COLUMN sha256 VARCHAR(64) DEFAULT ''"))
        if "size" not in have:
            con.execute(text("ALTER TABLE releases ADD COLUMN size INTEGER DEFAULT 0"))


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
