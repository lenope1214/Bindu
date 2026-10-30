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
MAX_SPEED = 8.0  # 게임 최고 배속
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
    cap = max_score(wave, run["map"], run["rules"], patch_data)
    if score > cap:
        return f"score {score} > cap {cap}"
    v = rule_values(run["rules"], patch_data)
    spawned = sum(spawn_count(w, run["map"], v["orb_mul"]) for w in range(1, wave + 1))
    if run.get("kills", 0) > spawned * 3 + 200 * (wave // 5 + 1):
        return "too many kills"
    need = min_game_secs(wave, run["map"], run["rules"], patch_data)
    if run.get("game_secs", 0.0) < need:
        return f"too fast (game {run.get('game_secs', 0.0):.0f}s < {need:.0f}s)"
    if run.get("real_secs", 0.0) < need / MAX_SPEED:
        return "too fast (real time)"
    return ""
