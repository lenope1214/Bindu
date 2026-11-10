class_name Haptic
## 폰 진동 (시험, test/haptics): 중앙 피격·보스 처치·게임 오버·위험 단계에 짧게 떨림. 설정 '진동'(폰 기본 켬).
## PC는 Input.vibrate_handheld가 아무 것도 안 해서 그대로 둔다. 너무 잦지 않게 MIN_GAP초 안의 진동은 합친다.

const MIN_GAP := 0.12
const MS := {"core": 35, "boss": 70, "danger": 120, "over": 260}
static var last := -1.0
static var log: Array = []  # 점검용: 마지막 진동 [이름, ms] (헤드리스에서도 쌓임, 최근 20개)


static func buzz(kind: String) -> void:
	if not Meta.vibrate_on or not MS.has(kind):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - last < MIN_GAP and kind == "core":
		return
	last = now
	var ms: int = MS[kind]
	log.append([kind, ms])
	if log.size() > 20:
		log.pop_front()
	Input.vibrate_handheld(ms)
