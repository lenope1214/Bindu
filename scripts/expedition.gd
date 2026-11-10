class_name Expedition
## 원정 목표 (시험, test/expedition): 혼자 하는 판은 50웨이브가 '끝판'. 50웨이브 보스는 체력 x3 끝판 보스이고,
## 잡으면 '원정 완료' 뒤 그대로 무한으로 이어간다. 끝이 1.05^w 수치 벽뿐이던 문제에 중간 목표를 준다.
## 기획: 2026-10-31 디펜스 한계 개선안 D(원정 목표).

const GOAL := 50
const FINAL_HP := 3.0


static func on(session) -> bool:
	return session.mp_mode == "" and not TutPlay.on and not session.tutor


## 다음 웨이브 보스 계획에 끝판 표시·체력 (spawning._plan_boss 뒤).
static func plan(session) -> void:
	if not on(session) or session.boss_plan.is_empty() or int(session.boss_plan.get("wave", -1)) != GOAL:
		return
	session.boss_plan["hp"] = roundf(float(session.boss_plan["hp"]) * FINAL_HP)
	session.boss_plan["final"] = true


## 웨이브를 끝냈다: 끝판이면 원정 완료 알림. 완료했으면 true.
static func wave_done(session) -> bool:
	if not on(session) or session.wave != GOAL:
		return false
	session.hud_system.big_banner("원정 완료! 이제 끝없는 원정", Color(1, 0.85, 0.4))
	session.hud_system._show_toast("%d웨이브 끝판을 넘었어요. 여기서부터는 기록 도전이에요" % GOAL)
	return true


## 점수 줄 칩 글: 원정 중이면 "원정 n/50", 넘었으면 "끝없는 원정 +n".
static func chip(session) -> String:
	if not on(session):
		return ""
	return "원정 %d/%d" % [session.wave, GOAL] if session.wave < GOAL else "끝없는 원정 +%d" % (session.wave - GOAL)
