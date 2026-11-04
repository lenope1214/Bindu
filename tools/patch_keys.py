#!/usr/bin/env python3
"""관리자 페이지 [패치] 탭의 하위 탭과 rules 밖 패치 칸(특성·카드·모드·정원·속성/공격방식 배율) 목록을 만든다.

- 결과: server/app/patch_sections.json (GET /admin/patch_sections). rules 키 목록은 따로 rule_keys.json(tools/rule_keys.gd).
- 기본값은 게임 코드에서 읽는다. 설명은 아래 표에 적는다. 코드에 없는 키를 적거나, 코드가 읽는 키가 표에 없으면 실패.
- 사용: python3 tools/patch_keys.py         (다시 만듦)
        python3 tools/patch_keys.py --check (같은지만, tools/run.sh check에 포함)
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "server/app/patch_sections.json"
RULE_KEYS = ROOT / "server/app/rule_keys.json"

# 하위 탭: [id, 이름, 게임 코드 클래스, rules 묶음(rule_keys.json의 g), rules 밖 패치 칸]
TABS = [
    ["obj", "오브젝트", "Tower · Pat · Elem",
     ["오브젝트 상한", "오브젝트 피해·성장", "공격방식 수치", "공격방식 피해 배율", "공격방식 공격 속도 배율", "공격방식 사거리 배율",
      "강화", "속성 부가효과", "연계", "발동", "별·행성", "공격방식 기본 피해", "공격방식 기본 간격", "공격방식 모양", "탄",
      "오브젝트 코드 수치"], ["elem_dmg", "pat_dmg"]],
    ["rx", "특징 공유", "Share · Elem.TRAIT", ["특징 공유", "특징 코드 수치"], []],
    ["card", "카드", "선택지 (main.offer · _roll_card)", ["카드 수"], ["cards"]],
    ["orb", "구체", "Orb", ["구체 기본", "진입 시간 맞추기", "후반 난이도", "후반 구체", "방해 구체", "구체 종류", "구체 상태 수치", "저항·굳센 구체"], []],
    ["perk", "특성", "main.PERKS", [], ["perks", "perk_desc"]],
    ["skill", "중앙 기술", "Skill", ["중앙 기술", "중앙 기술 코드 수치"], []],
    ["map", "맵", "MapRule · Main", ["맵별 규칙·친화 카드", "기맥", "맵 규칙 코드 수치", "맵·중앙 코드 수치"], []],
    ["vary", "판 흐름", "Vary", ["판마다 다른 흐름"], []],
    ["mode", "모드", "Modes", ["모드 코드 수치"], ["modes"]],
    ["mp", "멀티", "Mp", ["협동 짧은 판", "멀티 기다리기·대결 보낸 구체", "멀티 난이도"], []],
    ["garden", "정원", "Garden · Grow", [], ["garden"]],
    ["text", "글", "시작 화면·알림", [], ["rules_desc", "message"]],
]

# 칸마다: 이름, 값 종류(num/text), 설명 표 {키: 설명}
PERKS = {
    "power": "화력: 모든 피해 + (고를 때마다)",
    "haste": "속사: 모든 공격 속도 + (고를 때마다)",
    "reach": "원거리: 모든 사거리 + (고를 때마다)",
    "core": "단단한 중앙: 중앙 최대 체력 + (모두 회복)",
    "reroll": "넉넉한 선택: 쉬는 시간마다 새로고침 + (고른 수 x 값)",
    "luck": "행운: 속성 카드가 Lv2로 나올 확률 + (고른 수 x 값)",
    "regen": "회복: 웨이브를 마칠 때마다 중앙 체력 + (처음 고른 것, 소수는 다음 웨이브로)",
    "regen_more": "회복: 겹쳐 고른 것 하나당 웨이브마다 체력 +",
    "slow": "끈적한 공간: 모든 구체 이동 속도 - (곱)",
    "harmony": "조화: 속성 여러 종류로 생기는 공격 속도 감소 x 값 (한 번만)",
    "harmony_cap": "조화: 줄여 준 몫으로 오르는 공격 속도 상한",
    "coin": "운명의 동전: 뒷면일 때 이번 쉬는 시간 새로고침 +",
    "shield": "실드: 웨이브를 시작할 때마다 채우는 실드 (고른 수 x 값)",
    "shield_max": "실드: 웨이브마다 채우는 실드 최대",
    "shield_all": "실드: 넘친 회복 실드까지 합친 최대",
    "rampart": "성벽: 고른 수마다 벽 조각 + (벽 오브젝트 레벨 합에 더함)",
    "rampart_max": "성벽: 벽 조각 최대 (다 차면 선택지에 안 나옴)",
    "rampart_push": "성벽: 구체를 밀어내는 거리(px, 보스 절반)",
    "riposte": "반격 파동: 피해 (보통 구체 체력 대비)",
    "riposte_more": "반격 파동: 겹쳐 고른 것 하나당 피해 +",
    "riposte_r": "반격 파동: 퍼지는 반지름(px)",
    "overflow": "넘친 회복: 실드로 남길 수 있는 최대",
}
CARDS = {
    "elem": "속성 카드 비중 (합으로 나눔)",
    "pat": "공격방식 카드 비중",
    "mod": "강화 카드 비중",
    "trig": "발동 카드 비중",
    "link": "연계 카드 비중",
    "lv2_base": "속성 카드가 Lv2로 나올 확률 기본",
    "lv2_wave": "웨이브마다 Lv2 확률 +",
    "lv2_max": "Lv2 확률 최대 (행운 특성 전)",
}
GARDEN = {
    "plant": "씨앗 나무: 새 칸 심는 값 (심은 칸마다 x plant_mul)",
    "plant_mul": "씨앗 나무: 심은 칸 하나마다 심는 값 배율",
    "grow_base": "씨앗 나무: Lv1 → Lv2 키우는 값",
    "grow_mul": "씨앗 나무: 레벨마다 키우는 값 배율",
    "hero_disc": "씨앗 나무: 영웅 속성 칸 키우는 값 할인 배율",
    "stem_per": "씨앗 나무 줄기: 레벨마다 일반 판 모든 피해 +",
    "hero_xp": "영웅: Lv1 → Lv2 경험치 (레벨마다 x1.5)",
    "hero_garden": "영웅: 정원에서 레벨마다 영웅 속성 피해 + (속성 종류 수로 나눔)",
    "hero_norm": "영웅: 일반 판(씨앗 나무 켬)에서 레벨마다 영웅 속성 피해 +",
    "hero_card_lv": "영웅: 이 레벨부터 일반 판 첫 쉬는 시간에 영웅 속성 카드",
    "mastery_per": "속성 숙련: 단계마다 일반 판 그 속성 피해 +",
    "dew_kill": "이슬: 구체 하나 처치 (웨이브마다 x dew_growth, 보스 10배)",
    "dew_growth": "이슬: 웨이브마다 처치 이슬 배율",
    "offline": "이슬: 꺼 둔 동안 받는 비율 (최근 초당 이슬 대비)",
    "hp_early": "정원 구체 체력: 첫 웨이브 배율 (12웨이브에 1이 됨)",
    "hp_growth": "정원 구체 체력: 8웨이브 뒤 웨이브마다 배율",
    "next_delay": "키우기형: 단계 사이 쉬는 시간(초)",
    "cost_new": "상점: 새 오브젝트 값 (오브젝트마다 x1.25)",
    "cost_level": "상점: 공격방식 레벨 올리기 값 (레벨마다 x1.5)",
    "cost_elem": "상점: 속성 더하기 값 (속성마다 x2)",
    "cost_pat": "상점: 공격방식 바꾸기 값",
    "cost_mod": "상점: 강화 값 (같은 강화마다 x1.8)",
    "cost_trig": "상점: 발동 값 (같은 발동마다 x1.8)",
    "cost_link": "상점: 연계 값 (연계마다 x2)",
}


def read(p: str) -> str:
    return (ROOT / p).read_text(encoding="utf-8")


def num(s: str):
    f = float(s)
    return int(f) if f == int(f) and abs(f) < 1e9 else round(f, 4)


def const(src: str, name: str) -> str:
    m = re.search(r"(?:const|static var) %s := ([0-9.]+)" % name, src)
    if not m:
        raise SystemExit("FAIL 상수 %s를 못 찾음" % name)
    return m.group(1)


def defaults_from(srcs: dict, pattern: str) -> dict:
    """pattern에 (키, 기본값) 두 묶음. 기본값이 상수 이름이면 같은 파일 또는 다른 파일에서 찾는다."""
    out = {}
    all_src = "\n".join(srcs.values())
    for src in srcs.values():
        for k, d in re.findall(pattern, src):
            d = d.strip()
            if not re.fullmatch(r"[0-9.]+", d):
                d = const(all_src, d.split(".")[-1])
            out.setdefault(k, num(d))
    return out


def check_same(name: str, table: dict, found: dict) -> list:
    errs = []
    for k in found:
        if k not in table:
            errs.append("%s: 코드가 읽는 키 %s의 설명이 없음 (tools/patch_keys.py)" % (name, k))
    for k in table:
        if k not in found:
            errs.append("%s: 표의 키 %s를 코드가 읽지 않음" % (name, k))
    return errs


def build() -> dict:
    main = read("scripts/main.gd")
    errs = []
    # 특성: main.PERK_VALS + 이름은 PERKS
    pv = re.search(r"const PERK_VALS := \{(.*?)\}", main, re.S).group(1)
    perk_vals = {k: num(v) for k, v in re.findall(r'"([a-z_]+)": ([0-9.]+)', pv)}
    errs += check_same("perks", PERKS, perk_vals)
    perk_list = re.findall(r'\{"id": "([a-z_]+)", "name": "([^"]+)", "desc": "([^"]*)"\}', main[main.index("const PERKS"):])
    # 카드: main.gd의 Patch.num("cards", 키, 기본)
    cards = defaults_from({"main": main, "pat": read("scripts/pattern.gd")}, r'Patch\.num\("cards", "([a-z0-9_]+)", ([A-Za-z0-9_.]+)\)')
    errs += check_same("cards", CARDS, cards)
    # 정원: Garden.k(키, 기본) / garden.gd 안 k(키, 기본)
    gsrc = {"garden": read("scripts/garden.gd"), "grow": read("scripts/grow.gd"), "main": main}
    garden = defaults_from(gsrc, r'(?:Garden\.|[^A-Za-z_.])k\("([a-z0-9_]+)", ([A-Za-z0-9_.]+)\)')
    errs += check_same("garden", GARDEN, garden)
    # 모드: Modes.LIST의 score
    modes_src = read("scripts/modes.gd")
    modes = re.findall(r'"([a-z]+)": \{"name": "([^"]+)", "hard": (true|false), "desc": "([^"]*)", "score": ([0-9.]+)', modes_src)
    # 속성·공격방식 피해 배율 키
    elem_keys = re.search(r"const ELEM_KEYS := \[(.*?)\]", read("scripts/patch.gd")).group(1)
    elem_keys = re.findall(r'"([a-z]+)"', elem_keys)
    elem_src = read("scripts/elem.gd")
    names = re.search(r"const NAMES := \{(.*?)\}", elem_src, re.S).group(1)
    elem_names = re.findall(r'[A-Z]+: "([^"]+)"', names)
    pat_src = read("scripts/pattern.gd")
    pat_ids = re.findall(r'"([a-z]+)"', re.search(r"const PATTERN_IDS := \[(.*?)\]", pat_src).group(1))
    pat_names = dict(re.findall(r'^\t"([a-z]+)": \{"name": "([^"]+)"', pat_src[pat_src.index("const PATTERNS"):], re.M))
    # 규칙 이름
    rules_src = read("scripts/rules.gd")
    rule_ids = re.findall(r"\d+", re.search(r"const IDS := \[(.*?)\]", rules_src).group(1))
    rule_names = dict(re.findall(r'(\d+): "([^"]+)"', re.search(r"const NAMES := \{(.*?)\}", rules_src).group(1)))
    descs = re.search(r"const DESCS := \{(.*?)\n\}", rules_src, re.S).group(1)
    rule_descs = dict(re.findall(r'\t(\d+): "([^"]*)"', descs))

    if len(elem_keys) != len(elem_names):
        errs.append("elem_dmg: Patch.ELEM_KEYS(%d)와 Elem.NAMES(%d) 수가 다름" % (len(elem_keys), len(elem_names)))
    # rules 묶음이 모두 탭에 들어가는지
    groups = list(dict.fromkeys(e["g"] for e in json.loads(RULE_KEYS.read_text(encoding="utf-8"))))
    tabbed = [g for t in TABS for g in t[3]]
    for g in groups:
        if g not in tabbed:
            errs.append("rules 묶음 '%s'가 어느 탭에도 없음 (tools/patch_keys.py TABS)" % g)
    for g in tabbed:
        if g not in groups:
            errs.append("TABS의 묶음 '%s'가 rule_keys.json에 없음" % g)
    if errs:
        for e in errs:
            print("FAIL " + e)
        raise SystemExit(1)

    perk_name = {i: n for i, n, _ in perk_list}

    def perk_of(k: str) -> str:
        base = k.split("_")[0]
        return perk_name.get(k, perk_name.get(base, ""))

    sections = {
        "perks": {"name": "특성 수치", "type": "num", "keys": [{"k": k, "g": perk_of(k), "d": PERKS[k], "v": v} for k, v in perk_vals.items()]},
        "perk_desc": {"name": "특성 카드 설명", "type": "text", "note": "수치를 바꾸면 설명도 같이 바꾸기",
                      "keys": [{"k": i, "g": n, "d": "%s 카드에 보이는 설명" % n, "v": d} for i, n, d in perk_list]},
        "cards": {"name": "카드 종류 비율·Lv2 확률", "type": "num", "keys": [{"k": k, "g": "", "d": CARDS[k], "v": cards[k]} for k in CARDS]},
        "elem_dmg": {"name": "속성별 피해 배율", "type": "num", "note": "오브젝트에 넣은 속성마다 곱함",
                     "keys": [{"k": k, "g": "", "d": "%s 피해 배율 (1 = 그대로)" % n, "v": 1} for k, n in zip(elem_keys, elem_names)]},
        "pat_dmg": {"name": "공격방식별 피해 배율 (예전 칸)", "type": "num", "note": "rules의 dmg_<공격방식>과 곱해짐. 새로 바꿀 땐 [공격방식 피해 배율] 묶음을 쓰기",
                    "keys": [{"k": k, "g": "", "d": "%s 피해 배율 (1 = 그대로, 반응 포함)" % pat_names.get(k, k), "v": 1} for k in pat_ids]},
        "modes": {"name": "모드 점수 배율", "type": "num", "note": "서버 점수 상한(server/app/validate.py MODES)도 같은 값을 씀",
                  "keys": [{"k": k, "g": "어렵게" if h == "true" else "쉽게", "d": "%s: %s" % (n, d), "v": num(s)} for k, n, h, d, s in modes]},
        "garden": {"name": "정원 수치", "type": "num", "keys": [{"k": k, "g": GARDEN[k].split(":")[0], "d": GARDEN[k], "v": garden[k]} for k in GARDEN]},
        "rules_desc": {"name": "시작 화면 규칙 설명", "type": "text",
                       "keys": [{"k": i, "g": "", "d": "%s 설명" % rule_names.get(i, i), "v": rule_descs.get(i, "")} for i in rule_ids]},
        "message": {"name": "시작 화면 알림", "type": "text", "single": True,
                    "keys": [{"k": "message", "g": "", "d": "시작 화면에 띄우는 한 줄 (비우면 없음)", "v": ""}]},
    }
    tabs = [{"id": i, "name": n, "cls": c, "groups": g, "sections": s} for i, n, c, g, s in TABS]
    return {"tabs": tabs, "sections": sections}


def dump(d: dict) -> str:
    return json.dumps(d, ensure_ascii=False, indent=1) + "\n"


if __name__ == "__main__":
    text = dump(build())
    if "--check" in sys.argv:
        if OUT.exists() and OUT.read_text(encoding="utf-8") == text:
            print("patch sections 통과")
            sys.exit(0)
        print("FAIL patch sections: server/app/patch_sections.json이 오래됨 (python3 tools/patch_keys.py)")
        sys.exit(1)
    OUT.write_text(text, encoding="utf-8")
    print("PATCHSECTIONS ok")
