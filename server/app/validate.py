"""판 기록 검증: 게임 공식(main.gd)을 그대로 옮겨 넉넉한 상한을 잡고, 넘으면 리더보드에서 뺀다.
게임 공식이 바뀌면 여기도 맞춘다 (wave_size, spawn_count, hp_growth, _spawn_orb, 처치 점수)."""
import math

MAPS = ["plain", "spiral", "cross", "storm", "line"]
MAP_ORBS = {"cross": 1.5, "line": 1.6}  # main.gd spawn_count 맵 배율
MAP_HP = {"cross": 1.6, "line": 2.4}  # main.gd _roll_orb 맵 체력 배율
RULES = list(range(1, 10))  # 새 규칙 버전이 늘어도 받는다 (기본값은 버전 1)
# 규칙 버전별 기본값 (rules.gd Rules.apply)
RULE_DEFAULTS = {
    1: {"orb_mul": 1.0, "hp_growth": 1.05},
    2: {"orb_mul": 1.0, "hp_growth": 1.05},
    3: {"orb_mul": 1.0, "hp_growth": 1.05},
    4: {"orb_mul": 1.4, "hp_growth": 1.08},
    5: {"orb_mul": 1.0, "hp_growth": 1.05},  # 폐기(2026-10-30). 예전 판 기록 검증용으로만 남김
}
# 모드 (modes.gd Modes.LIST): 점수 배율, 어렵게/쉽게, 반대 쌍. 배율은 패치 data.modes.<id>로 바뀐다.
# 처치 점수는 모드 전 체력·수 기준으로 매기므로(Modes.kill_k) 점수 상한은 모드 배율만 곱한다.
# 쉽게 모드를 하나라도 쓴 판은 기록은 받되(통계) 리더보드에서는 뺀다 (main.py submit_run).
MODES = {
    "rush": {"score": 1.30, "hard": True, "vs": "stroll"},
    "swarm": {"score": 1.30, "hard": True, "vs": ""},
    "steel": {"score": 1.30, "hard": True, "vs": "soft"},
    "glass": {"score": 1.25, "hard": True, "vs": "fort"},
    "narrow": {"score": 1.15, "hard": True, "vs": "ease"},
    "early": {"score": 1.15, "hard": True, "vs": ""},
    "angry": {"score": 1.25, "hard": True, "vs": ""},
    "stroll": {"score": 0.70, "hard": False, "vs": "rush"},
    "fort": {"score": 0.70, "hard": False, "vs": "glass"},
    "three": {"score": 0.50, "hard": False, "vs": ""},
    "soft": {"score": 0.70, "hard": False, "vs": "steel"},
    "ease": {"score": 0.85, "hard": False, "vs": "narrow"},
    # 씨앗 나무(정원)를 쓴 판: 점수 배율 없음. 리더보드는 '성장'으로 따로 (Run.grow)
    "grow": {"score": 1.0, "hard": True, "vs": ""},
}
MODE_SWARM = 1.25  # 물량: 웨이브 구체 수 (Modes.SWARM)
MODE_MUL_MIN, MODE_MUL_MAX = 0.2, 2.5
MAX_SPEED = 8.0  # 게임 최고 배속
TIME_CHECK_WAVE = 20  # 기록 등록 시간 기준: 이 웨이브까지의 최소 시간 (2026-10-31 사용자 결정, 예전엔 도달 웨이브 전체)
SLACK = 2.0  # 분열 조각·보스 부하·운까지 덮는 여유


def vtuple(v: str) -> tuple:
    out = []
    for p in str(v).split("."):
        digits = "".join(ch for ch in p if ch.isdigit())
        out.append(int(digits) if digits else 0)
    while len(out) < 3:
        out.append(0)
    return tuple(out[:3])


def rule_values(rules: int, patch_data: dict | None) -> dict:
    """규칙 버전 기본값에 패치 덮어쓰기까지 반영한 값."""
    vals = dict(RULE_DEFAULTS.get(rules, RULE_DEFAULTS[1]))
    vals["orb_hp"] = 1.0
    if patch_data:
        r = patch_data.get("rules", {}) or {}
        for src in (r.get("all", {}), r.get(str(rules), {})):
            for k in ("orb_mul", "hp_growth", "orb_hp"):
                if isinstance(src.get(k), (int, float)):
                    vals[k] = float(src[k])
    return vals


def modes_error(modes: list) -> str:
    """모르는 모드, 겹친 것, 반대 쌍이 함께 있으면 이유."""
    if len(set(modes)) != len(modes):
        return "bad modes"
    for m in modes:
        if m not in MODES:
            return "unknown modes"
        if MODES[m]["vs"] in modes:
            return "bad modes"
    return ""


def modes_mul(modes: list, patch_data: dict | None = None) -> float:
    """Modes.mul: 고른 모드 배율의 곱 (패치 값이 있으면 그것)."""
    pm = (patch_data or {}).get("modes") or {}
    m = 1.0
    for x in modes:
        v = pm.get(x)
        m *= float(v) if isinstance(v, (int, float)) else MODES[x]["score"]
    return min(max(m, MODE_MUL_MIN), MODE_MUL_MAX)


def easy(modes: list) -> bool:
    """쉽게 모드를 하나라도 썼는지 (리더보드 제외)."""
    return any(not MODES.get(m, {"hard": True})["hard"] for m in modes)


def _roundi(x: float) -> int:
    """Godot roundi (0.5는 0에서 멀어지는 쪽으로)."""
    return int(math.floor(x + 0.5)) if x >= 0 else -int(math.floor(-x + 0.5))


def lanes_for(w: int) -> int:
    """main.gd lanes_for: 웨이브 w의 진입 방향 수."""
    return min(min(1 + w // 3, 4 + max(0, (w - 12) // 6)), 6)


def wave_size(w: int) -> int:
    """main.gd wave_size: 3 + 2w, 첫 웨이브 70%에서 10웨이브 100%로."""
    k = 0.7 + 0.3 * min(max((w - 1) / 9.0, 0.0), 1.0)
    return _roundi((3 + w * 2) * k)


def spawn_count(w: int, map_id: str, orb_mul: float) -> int:
    """main.gd spawn_count: 새 진입 방향이 열리는 웨이브는 80%(십자로·회랑 제외), 십자로 1.5배, 회랑 1.4배."""
    n = _roundi(wave_size(w) * orb_mul)
    if map_id not in MAP_ORBS and lanes_for(w) > lanes_for(w - 1):
        n = _roundi(n * 0.8)
    return _roundi(n * MAP_ORBS[map_id]) if map_id in MAP_ORBS else n


def max_score(wave: int, map_id: str, rules: int, patch_data: dict | None = None) -> int:
    v = rule_values(rules, patch_data)
    hp_map = MAP_HP.get(map_id, 1.0)
    total = 0.0
    for w in range(1, wave + 1):
        g = 1.0 if w <= 10 else v["hp_growth"] ** (w - 10)
        hp = (2.0 + math.floor(w * 0.7)) * g * v["orb_hp"] * hp_map + 1.0
        n = spawn_count(w, map_id, v["orb_mul"])
        kill = n * hp * 2.5  # 전부 단단한 구체라고 쳐도
        if w % 5 == 0:
            kill += hp * 12.0
        total += kill * 10 * 3.0 * SLACK + w * 20  # 처치 점수 최대 콤보 x3, 웨이브 클리어 보너스
    return int(total) + 1000


def min_game_secs(wave: int, map_id: str, rules: int, patch_data: dict | None = None) -> float:
    """지난 웨이브들의 구체가 모두 나오는 데만 걸리는 게임 시간 (절반만 요구)."""
    v = rule_values(rules, patch_data)
    s = 0.0
    for w in range(1, wave):
        n = spawn_count(w, map_id, v["orb_mul"])
        s += max(0, n - 1) * max(0.35, 1.2 - w * 0.06)
    return s * 0.5


def check(run: dict, patch_data: dict | None = None) -> str:
    """문제가 없으면 빈 글자, 있으면 이유."""
    wave, score = run["wave"], run["score"]
    if run["map"] not in MAPS:
        return "unknown map"
    if run["rules"] not in RULES:
        return "unknown rules"
    if not 0 <= wave <= 1000 or score < 0:
        return "out of range"
    modes = run.get("modes") or []
    err = modes_error(modes)
    if err:
        return err
    cap = int(max_score(wave, run["map"], run["rules"], patch_data) * max(1.0, modes_mul(modes, patch_data)))
    if score > cap:
        return f"score {score} > cap {cap}"
    v = rule_values(run["rules"], patch_data)
    orb_mul = v["orb_mul"] * (MODE_SWARM if "swarm" in modes else 1.0)
    spawned = sum(spawn_count(w, run["map"], orb_mul) for w in range(1, wave + 1))
    minions = 400 if "angry" in modes else 200  # 성난 보스는 부하를 2배 자주 부른다
    if run.get("kills", 0) > spawned * 3 + minions * (wave // 5 + 1):
        return "too many kills"
    # 시간 검사는 TIME_CHECK_WAVE(20)웨이브까지 걸리는 시간만 요구한다 (더 간 판에 더 긴 시간을 요구하지 않음)
    need = min_game_secs(min(wave, TIME_CHECK_WAVE), run["map"], run["rules"], patch_data)
    if run.get("game_secs", 0.0) < need:
        return f"too fast (game {run.get('game_secs', 0.0):.0f}s < {need:.0f}s)"
    if run.get("real_secs", 0.0) < need / MAX_SPEED:
        return "too fast (real time)"
    return ""
