class_name Daily
## 오늘의 맵 (시험, test/daily-map): 한국 날짜로 매일 맵 하나를 정하고, 그 맵으로 혼자 하는 판은 업적 누적 진행이 2배.
## 점수 배율은 없다. 이틀 연속 같은 맵이 나오지 않는다. 시험 맵(Meta.TRIAL_MAPS)은 빠진다.
## 기획: 2026-11-05 맵별 규칙 2차 기획안의 '오늘의 맵'.

const ACH_K := 2  # 업적 누적 진행 배율
static var run_on := false  # 이번 판이 오늘의 맵 판인지 (판 시작 때 정해 자정을 넘겨도 그대로)


static func pool() -> Array:
	return Meta.MAP_IDS.filter(func(id): return not id in Meta.TRIAL_MAPS)


## 한국 시간(UTC+9) 날짜 번호.
static func day_now() -> int:
	return int(floor((Time.get_unix_time_from_system() + 9.0 * 3600.0) / 86400.0))


## 블록(맵 수만큼의 날)마다 맵 순서를 섞는다. 블록 안은 겹치지 않고, 블록 경계에서 겹치면 첫 두 날을 바꾼다.
static func _perm(b: int) -> Array:
	var p := pool()
	var r := RandomNumberGenerator.new()
	r.seed = hash("bindu-daily-%d" % b)
	for i in range(p.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var tmp = p[i]
		p[i] = p[j]
		p[j] = tmp
	return p


static func map_of(day: int) -> String:
	var p := pool()
	var n := p.size()
	if n == 0:
		return "plain"
	var b := int(floor(float(day) / n))
	var cur := _perm(b)
	if n > 1 and cur[0] == _perm(b - 1)[n - 1]:
		var tmp = cur[0]
		cur[0] = cur[1]
		cur[1] = tmp
	return cur[posmod(day, n)]


static func today() -> String:
	return map_of(day_now())


## 새 판 시작: 혼자 하는 판이고 고른 맵이 오늘의 맵이면 켠다.
static func new_run(session) -> void:
	run_on = session.mp_mode == "" and not TutPlay.on and Meta.map_id == today()


static func ach_k() -> int:
	return ACH_K if run_on else 1
