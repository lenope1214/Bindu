"""선택 통계: 어떤 특성·카드가 얼마나 나오고 골라졌는지, 고른 판은 몇 웨이브까지 갔는지."""
import csv
import io
from dataclasses import dataclass
from datetime import timedelta

from sqlalchemy import and_, case, distinct, func, select
from sqlalchemy.orm import Session

from . import config
from .db import Final, Pick, Run, SrcShare, now

ELEM_IDS = ["fire", "wood", "water", "electric", "wind", "ice", "earth", "dark", "light", "poison", "metal", "sound", "time", "soul", "star"]


def finals_of(towers) -> dict:
    """마지막 오브젝트 구성 → {키: (레벨 합, 피해 몫 합)}."""
    out: dict = {}

    def add(key, n, share):
        a, s = out.get(key, (0, 0.0))
        out[key] = (a + max(0, int(n)), s + max(0.0, float(share)))

    for t in towers:
        for e, lv in t.els.items():
            add(f"elem:{e}", lv, t.share)
        add(f"pat:{t.pat}", t.plv, t.share)
        for m, n in t.mods.items():
            add(f"mod:{m}", n, t.share)
        if t.prism:
            add("link:prism", t.prism, t.share)
        if t.reso:
            add("link:reso", t.reso, t.share)
        if t.links:
            add("link:link", t.links, t.share)
        if t.pincer:
            add("link:pincer", t.pincer, t.share)
        for g, n in t.trigs.items():
            add(f"trig:{g}", n, t.share)
    return {k[:48]: v for k, v in out.items()}


@dataclass
class Filter:
    rules: int = 0
    map: str = ""
    game: str = ""
    patch: int = -1
    days: int = 0
    valid_only: bool = True
    ended_only: bool = False  # 진행 중 판(5웨이브마다 온 기록)은 빼고
    min_wave: int = -1  # 밸런스 통계에 넣을 최소 도달 웨이브. -1이면 config.STATS_MIN_WAVE

    def cut(self) -> int:
        return config.STATS_MIN_WAVE if self.min_wave < 0 else self.min_wave

    def conds(self):
        c = []
        if self.rules:
            c.append(Run.rules == self.rules)
        if self.map:
            c.append(Run.map == self.map)
        if self.game:
            c.append(Run.game_version == self.game)
        if self.patch >= 0:
            c.append(Run.patch_id == self.patch)
        if self.days:
            c.append(Run.created_at >= now() - timedelta(days=self.days))
        if self.valid_only:
            c.append(Run.valid.is_(True))
        if self.ended_only:
            c.append(Run.ended.is_(True))
        return c


def summary(db: Session, f: Filter) -> dict:
    base = f.conds()
    cut = f.cut()
    every = and_(*base) if base else True
    # 밸런스 통계는 cut 웨이브 이상 간 판만, 그 아래는 이탈 통계로만
    where = and_(*base, Run.wave >= cut)
    runs = db.execute(select(func.count(Run.id), func.avg(Run.wave), func.max(Run.wave), func.avg(Run.score)).where(where)).one()

    # 선택지: 나온 횟수, 고른 횟수, 고른 판들의 평균 도달 웨이브
    picked_n = func.sum(case((Pick.picked, 1), else_=0))
    rows = db.execute(
        select(Pick.kind, Pick.key, func.count(Pick.id), picked_n)
        .join(Run, Run.id == Pick.run_id).where(where).group_by(Pick.kind, Pick.key)).all()
    # 같은 판이 같은 카드를 여러 번 골라도 평균 웨이브에는 한 번만: 판 단위로 다시 계산
    pr = dict(db.execute(
        select(Pick.key, func.count(distinct(Pick.run_id))).join(Run, Run.id == Pick.run_id)
        .where(where, Pick.picked.is_(True)).group_by(Pick.key)).all())
    sub = (select(Pick.key.label("key"), Pick.run_id.label("rid")).join(Run, Run.id == Pick.run_id)
           .where(where, Pick.picked.is_(True)).group_by(Pick.key, Pick.run_id).subquery())
    pw_run = dict(db.execute(select(sub.c.key, func.avg(Run.wave)).join(Run, Run.id == sub.c.rid).group_by(sub.c.key)).all())
    picks = []
    for kind, key, offered, picked in rows:
        picks.append({"kind": kind, "key": key, "offered": offered, "picked": int(picked or 0),
                      "rate": round((picked or 0) / offered, 4) if offered else 0.0,
                      "runs_picked": pr.get(key, 0),
                      "avg_wave_picked": round(float(pw_run.get(key) or 0.0), 2)})
    picks.sort(key=lambda x: (x["kind"], -x["rate"]))

    # 마지막 구성: 몇 판에 들어 있었는지, 평균 레벨·피해 몫, 그 판들의 평균 웨이브
    frows = db.execute(
        select(Final.key, func.count(distinct(Final.run_id)), func.avg(Final.amount), func.avg(Final.share), func.avg(Run.wave))
        .join(Run, Run.id == Final.run_id).where(where).group_by(Final.key)).all()
    n_runs = runs[0] or 0
    finals = [{"key": k, "runs": n, "presence": round(n / n_runs, 4) if n_runs else 0.0, "avg_amount": round(float(a or 0), 2),
               "avg_share": round(float(s or 0), 4), "avg_wave": round(float(w or 0), 2)} for k, n, a, s, w in frows]
    finals.sort(key=lambda x: -x["presence"])

    # 피해 출처: 출처를 보낸 판들 기준 평균 몫 (없는 판은 0으로), 있던 판만의 평균 몫
    n_src = db.scalar(select(func.count(distinct(SrcShare.run_id))).join(Run, Run.id == SrcShare.run_id).where(where)) or 0
    srows = db.execute(
        select(SrcShare.key, func.count(distinct(SrcShare.run_id)), func.sum(SrcShare.share), func.avg(SrcShare.share), func.avg(Run.wave))
        .join(Run, Run.id == SrcShare.run_id).where(where).group_by(SrcShare.key)).all()
    srcs = [{"key": k, "runs": n, "avg_share_all": round(float(s or 0) / n_src, 4) if n_src else 0.0,
             "avg_share": round(float(a or 0), 4), "avg_wave": round(float(w or 0), 2)} for k, n, s, a, w in srows]
    srcs.sort(key=lambda x: -x["avg_share_all"])

    by_rules = [{"rules": r, "runs": n, "avg_wave": round(float(w or 0), 2), "max_wave": mx}
                for r, n, w, mx in db.execute(select(Run.rules, func.count(Run.id), func.avg(Run.wave), func.max(Run.wave))
                                              .where(where).group_by(Run.rules).order_by(Run.rules)).all()]
    # 웨이브 분포는 이탈까지 보려고 모든 판
    waves = [{"wave": w, "runs": n} for w, n in db.execute(
        select(Run.wave, func.count(Run.id)).where(every).group_by(Run.wave).order_by(Run.wave)).all()]
    total = sum(w["runs"] for w in waves)
    early = [w for w in waves if w["wave"] < cut]
    n_early = sum(w["runs"] for w in early)
    dropout = {"min_wave": cut, "runs_all": total, "runs": n_early, "rate": round(n_early / total, 4) if total else 0.0,
               "players": db.scalar(select(func.count(distinct(Run.device_id))).where(every, Run.wave < cut)) or 0,
               "waves": [{**w, "rate": round(w["runs"] / n_early, 4)} for w in early]}
    return {"runs": n_runs, "avg_wave": round(float(runs[1] or 0), 2), "max_wave": runs[2] or 0,
            "avg_score": round(float(runs[3] or 0), 1), "by_rules": by_rules, "waves": waves, "picks": picks, "finals": finals,
            "src_runs": n_src, "srcs": srcs, "dropout": dropout}


def to_csv(data: dict, kind: str) -> str:
    if kind == "dropout":
        data = {"dropout": data["dropout"]["waves"]}
    rows = data.get(kind if kind in ("picks", "finals", "srcs", "by_rules", "waves", "dropout") else "picks", [])
    buf = io.StringIO()
    buf.write("﻿")  # 엑셀에서 한글이 깨지지 않게
    if rows:
        w = csv.DictWriter(buf, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)
    return buf.getvalue()
