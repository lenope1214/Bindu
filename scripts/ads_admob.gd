extends RefCounted
## Ads(scripts/ads.gd)의 AdMob 연결 (Poing Studios godot-admob-plugin, addons/admob).
## 폰에서 Ads.start()가 load()로만 불러온다: PC·검사에서는 이 파일과 addons/admob을 읽지 않는다.

var rewarded: RewardedAd = null
var loading := false
var inited := false
var banner: AdView = null
var _earned := false


func start() -> void:
	UserMessagingPlatform.consent_information.update(ConsentRequestParameters.new(), _after_consent, func(_e): _init_ads())


func _after_consent() -> void:
	var ci := UserMessagingPlatform.consent_information
	if ci.get_consent_status() == ConsentInformation.ConsentStatus.REQUIRED and ci.get_is_consent_form_available():
		UserMessagingPlatform.load_consent_form(func(form: ConsentForm): form.show(func(_e): _init_ads()), func(_e): _init_ads())
	else:
		_init_ads()


func _init_ads() -> void:
	if inited:
		return
	inited = true
	var rc := RequestConfiguration.new()
	rc.max_ad_content_rating = RequestConfiguration.MAX_AD_CONTENT_RATING_G
	MobileAds.set_request_configuration(rc)
	MobileAds.initialize()
	load_rewarded()


func _request() -> AdRequest:
	var r := AdRequest.new()
	r.extras = {"npa": "1"}  # 맞춤형이 아닌 광고만
	return r


func load_rewarded() -> void:
	if not inited or loading or rewarded != null:
		return
	loading = true
	var cb := RewardedAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: RewardedAd) -> void:
		loading = false
		rewarded = ad
	cb.on_ad_failed_to_load = func(_e: LoadAdError) -> void:
		loading = false
	RewardedAdLoader.new().load(Ads._unit("rewarded"), _request(), cb)


func rewarded_ready() -> bool:
	return rewarded != null and rewarded.can_show_ad()


func show_rewarded(on_done: Callable) -> void:
	_earned = false
	var ad := rewarded
	rewarded = null
	var fs := FullScreenContentCallback.new()
	fs.on_ad_dismissed_full_screen_content = func() -> void:
		ad.destroy()
		on_done.call(_earned)
		load_rewarded()
	fs.on_ad_failed_to_show_full_screen_content = func(_e: AdError) -> void:
		ad.destroy()
		on_done.call(false)
		load_rewarded()
	ad.full_screen_content_callback = fs
	var earn := OnUserEarnedRewardListener.new()
	earn.on_user_earned_reward = func(_item: RewardedItem) -> void:
		_earned = true
	ad.show(earn)


func show_banner(unit: String) -> void:
	if not inited:
		return
	if banner == null:
		banner = AdView.new(unit, AdSize.BANNER, AdPosition.BOTTOM)
		banner.load_ad(_request())
	else:
		banner.show()


func hide_banner() -> void:
	if banner != null:
		banner.destroy()
		banner = null


func banner_px() -> int:
	return banner.get_height_in_pixels() if banner != null else 0
