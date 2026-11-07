class_name Ads
extends RefCounted
## 광고 (Google AdMob, 폰만). 판이 끝난 결과 화면에서만 쓴다:
## - 보상형 [광고 보고 한 번 더]: 누른 사람만 보고, 다 보면 그 웨이브 앞 쉬는 시간부터 다시 (판마다 1번)
## - 결과 화면 아래 배너: 처음 3판은 없음, 결과 화면을 나가면 지움
## 웨이브·카드·특성·앱 켤 때·멀티·튜토리얼에는 광고가 없다.
## PC이거나 플러그인(addons/admob 네이티브)이 없으면 모두 꺼지고 아무것도 뜨지 않는다.
## 맞춤형 광고는 쓰지 않는다(npa=1, ATT 팝업 없음), 광고 내용 등급은 G.

## 실제 광고 단위 id (AdMob 콘솔에서 만든 뒤 채운다). 비어 있으면 디버그 빌드는 구글 테스트 광고, 배포 빌드는 광고 끔.
const UNITS := {
	"Android": {"rewarded": "", "banner": ""},
	"iOS": {"rewarded": "", "banner": ""},
}
const TEST_UNITS := {
	"Android": {"rewarded": "ca-app-pub-3940256099942544/5224354917", "banner": "ca-app-pub-3940256099942544/6300978111"},
	"iOS": {"rewarded": "ca-app-pub-3940256099942544/1712485313", "banner": "ca-app-pub-3940256099942544/2934735716"},
}
const BANNER_FROM_GAME := 4  # 끝난 판 수(Meta.games)가 이 이상일 때만 배너 (처음 3판은 없음)
const REVIVE_HP := 5  # 한 번 더: 중앙 체력

static var started := false
static var sim := false  # 스크린샷·검사용: 광고가 되는 폰처럼 (실제 광고는 부르지 않음)
static var sim_ready := true  # sim일 때 보상형 광고가 준비됐다고 칠지
static var sdk: Object = null  # ads_admob.gd (폰에서 start() 뒤에만)
static var banner_on := false  # 지금 결과 화면 배너를 보이는 중 (sim도)


## 이 기기에서 광고를 쓸 수 있는지 (폰 + 플러그인 + 광고 단위 id).
static func enabled() -> bool:
	if sim:
		return true
	if not OS.get_name() in ["Android", "iOS"] or not Engine.has_singleton("PoingGodotAdMob"):
		return false
	return _unit("rewarded") != ""


static func _unit(kind: String) -> String:
	var os := OS.get_name()
	var id: String = UNITS.get(os, {}).get(kind, "")
	if id == "" and OS.is_debug_build():
		id = TEST_UNITS.get(os, {}).get(kind, "")
	return id


## 처음 한 번: 동의(유럽·영국만 창이 뜸) → 초기화 → 보상형 미리 받기.
## 앱을 켤 때가 아니라 첫 판을 마친 뒤 시작 화면에서 부른다 (첫 화면에 동의 창이 막지 않게).
## AdMob 스크립트(addons/admob)는 폰에서 여기서만 불러온다: PC·검사에선 아예 읽지 않음.
static func start() -> void:
	if started or sim or not enabled():
		return
	started = true
	sdk = load("res://scripts/ads_admob.gd").new()
	sdk.start()


## 보상형 광고를 지금 바로 보여 줄 수 있는지.
static func rewarded_ready() -> bool:
	if sim:
		return sim_ready
	return sdk != null and sdk.rewarded_ready()


## 보상형 광고를 보여 준다. 끝까지 보면 on_done(true), 중간에 닫거나 실패하면 on_done(false).
static func show_rewarded(on_done: Callable) -> void:
	if sim:
		on_done.call(sim_ready)
	elif not rewarded_ready():
		on_done.call(false)
	else:
		sdk.show_rewarded(on_done)


## 결과 화면 배너 (화면 아래 가운데). 처음 3판·멀티·튜토리얼은 부르는 쪽에서 거른다.
static func show_banner() -> void:
	banner_on = true
	if sdk != null and _unit("banner") != "":
		sdk.show_banner(_unit("banner"))


## 결과 화면을 나갈 때 (시작 화면·한 번 더): 배너를 지운다.
static func hide_banner() -> void:
	banner_on = false
	if sdk != null:
		sdk.hide_banner()


## 배너가 가리는 화면 아래 몫 (창 높이에 대한 비율, 0~1). 버튼을 그 위에 둔다.
static func banner_frac() -> float:
	if not banner_on:
		return 0.0
	var wh := float(DisplayServer.window_get_size().y)
	var px: int = sdk.banner_px() if sdk != null else 0
	if px > 0 and wh > 0.0:
		return float(px) / wh
	return 0.12  # 아직 안 받았거나 sim: 가로 폰에서 50dp 쯤 (1080 높이에 약 130px)
