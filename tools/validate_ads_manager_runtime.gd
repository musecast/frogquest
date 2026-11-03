extends SceneTree


## Stands in for one of the ad plugin's singletons (banners, interstitials, rewarded videos or sizes),
## noting each call in `calls`.
class FakeAdPlugin extends Object:
	signal on_ad_clicked(uid: int)
	signal on_ad_closed(uid: int)
	signal on_ad_failed_to_load(uid: int, error: Dictionary)
	signal on_ad_impression(uid: int)
	signal on_ad_loaded(uid: int)
	signal on_ad_opened(uid: int)
	signal on_interstitial_ad_loaded(uid: int)
	signal on_interstitial_ad_failed_to_load(uid: int, error: Dictionary)
	signal on_interstitial_ad_clicked(uid: int)
	signal on_interstitial_ad_dismissed_full_screen_content(uid: int)
	signal on_interstitial_ad_failed_to_show_full_screen_content(uid: int, error: Dictionary)
	signal on_interstitial_ad_impression(uid: int)
	signal on_interstitial_ad_showed_full_screen_content(uid: int)
	signal on_rewarded_ad_loaded(uid: int)
	signal on_rewarded_ad_failed_to_load(uid: int, error: Dictionary)
	signal on_rewarded_ad_clicked(uid: int)
	signal on_rewarded_ad_dismissed_full_screen_content(uid: int)
	signal on_rewarded_ad_failed_to_show_full_screen_content(uid: int, error: Dictionary)
	signal on_rewarded_ad_impression(uid: int)
	signal on_rewarded_ad_showed_full_screen_content(uid: int)
	signal on_rewarded_ad_user_earned_reward(uid: int, item: Dictionary)

	var calls: Array[String] = []
	var _next_uid := 0

	func create(options: Dictionary = {}) -> int:
		_next_uid += 1
		var where := ""
		if options.has("ad_position"):
			where = " top" if int(options.ad_position) == 0 else " bottom"
		calls.append("create%s %d" % [where, _next_uid])
		return _next_uid

	func load(_ad_unit_id: String, _request: Dictionary, _keywords: Array, uid: int) -> void:
		calls.append("load %d" % uid)

	func load_ad(uid: int, _request: Dictionary, _keywords: Array) -> void:
		calls.append("load %d" % uid)

	func show(uid: int) -> void:
		calls.append("show %d" % uid)

	func hide(uid: int) -> void:
		calls.append("hide %d" % uid)

	func destroy(uid: int) -> void:
		calls.append("destroy %d" % uid)

	func get_height_in_pixels(_uid: int) -> int:
		return -1

	func getCurrentOrientationAnchoredAdaptiveBannerAdSize(_width: int) -> Dictionary:
		return {"width": 382, "height": 60}

	func getLandscapeAnchoredAdaptiveBannerAdSize(_width: int) -> Dictionary:
		return {"width": 300, "height": 50}

	## The calls made since the first `since` of them, those starting with `prefix`.
	func made(prefix: String, since := 0) -> Array[String]:
		var found: Array[String] = []
		for call in calls.slice(since):
			if call.begins_with(prefix):
				found.append(call)
		return found


var _failed := false


func _initialize() -> void:
	if not Engine.has_singleton("PoingGodotAdMob"):
		print("Ads runtime smoke: native AdMob singleton absent in headless run; testing direct-native fallback path only.")

	var ads_manager := root.get_node_or_null("AdsManager")
	if ads_manager == null:
		push_error("Ads runtime smoke failed: /root/AdsManager autoload is missing.")
		quit(1)
		return

	ads_manager._mobile_ads_ready = true
	var request = ads_manager._make_ad_request()
	var request_dict: Dictionary = request.convert_to_dictionary()
	if not request_dict.has("google_request_agent"):
		_fail("ad request dictionary is missing google_request_agent.")
	var fixed_size = ads_manager._fixed_banner_ad_size()
	if fixed_size.width != 320 or fixed_size.height != 50:
		_fail("fixed banner size is wrong.")

	ads_manager.show_banner_bottom()
	ads_manager.preload_interstitial()
	ads_manager.hide_banner()

	await _check_full_screen_ads(ads_manager)

	if not _failed:
		print("Ads runtime smoke passed.")
	quit(1 if _failed else 0)


## The ad plugin lays each banner it makes over everything, a full-screen ad included, so while one's up
## no banner may be made or shown (a see-through one at the top swallowed taps on "Skip to playable").
## Plays it through with stand-in plugins: an Endless game over's interstitial, then a "keep going" video.
func _check_full_screen_ads(ads_manager: Node) -> void:
	await _frames()  # (AdsManager comes into the tree, and is ready, after _initialize)
	var banners := FakeAdPlugin.new()
	var interstitials := FakeAdPlugin.new()
	var rewarded := FakeAdPlugin.new()
	var stand_ins := {
		ads_manager.ADMOB_AD_VIEW_SINGLETON: banners,
		ads_manager.ADMOB_AD_SIZE_SINGLETON: FakeAdPlugin.new(),
		ads_manager.ADMOB_INTERSTITIAL_SINGLETON: interstitials,
		ads_manager.ADMOB_REWARDED_SINGLETON: rewarded,
	}
	for singleton_name in stand_ins:
		Engine.register_singleton(singleton_name, stand_ins[singleton_name])
	ads_manager._ads_active = true
	ads_manager._mobile_ads_ready = true

	# Playing: a bottom banner, filled, and an interstitial and a video ready.
	ads_manager.show_banner_bottom()
	ads_manager.preload_interstitial()
	ads_manager.preload_rewarded()
	await _frames()
	var bottom: Array[String] = banners.made("create bottom")
	if bottom.size() != 1:
		_fail("playing, one bottom banner should be made, not %s." % [banners.calls])
		await _put_back(ads_manager, stand_ins)
		return
	var playing_banner := int(bottom[0].get_slice(" ", 2))
	banners.on_ad_loaded.emit(playing_banner)
	interstitials.on_interstitial_ad_loaded.emit(ads_manager._interstitial_load_uid)
	rewarded.on_rewarded_ad_loaded.emit(ads_manager._rewarded_load_uid)
	await _frames()
	if not ads_manager._interstitial_ready or not ads_manager.is_rewarded_ready():
		_fail("the stand-in interstitial and video didn't load.")
		await _put_back(ads_manager, stand_ins)
		return

	# The third game over: the interstitial goes up, then the game over screen asks for its two banners,
	# a turn of the phone asks again, and the next ads are asked for.
	var interstitial_uid: int = ads_manager._interstitial_ad._uid
	var mark := banners.calls.size()
	var loads_before: int = interstitials.made("load").size() + rewarded.made("load").size()
	ads_manager._gameover_count = ads_manager.INTERSTITIAL_EVERY - 1
	ads_manager.on_game_over()
	ads_manager.show_banners_top_and_bottom()
	ads_manager.sync_banner_with_viewport()
	ads_manager.preload_interstitial()
	ads_manager.preload_rewarded()
	await _frames()
	if interstitials.made("show %d" % interstitial_uid).is_empty():
		_fail("the third game over didn't show the interstitial.")
	if not banners.made("create", mark).is_empty():
		_fail("banners were made while the interstitial was up: %s." % [banners.made("create", mark)])
	if banners.made("hide %d" % playing_banner, mark).is_empty():
		_fail("the bottom banner wasn't hidden while the interstitial was up.")
	banners.on_ad_loaded.emit(playing_banner)  # (a fill arriving late mustn't show it either)
	await _frames()
	if not banners.made("show", mark).is_empty():
		_fail("a banner was shown while the interstitial was up: %s." % [banners.made("show", mark)])
	if interstitials.made("load").size() + rewarded.made("load").size() != loads_before:
		_fail("another full-screen ad loaded while the interstitial was up (it would replace the one up).")

	# It closes: the game over screen's banners come, and the next ads load.
	mark = banners.calls.size()
	interstitials.on_interstitial_ad_dismissed_full_screen_content.emit(interstitial_uid)
	await _frames()
	if banners.made("create bottom", mark).size() != 1 or banners.made("create top", mark).size() != 1:
		_fail("after the interstitial closed, a top and a bottom banner should be made, not %s." % [banners.calls.slice(mark)])
	if interstitials.made("load").size() + rewarded.made("load").size() != loads_before + 1:
		_fail("after the interstitial closed, the next interstitial should load.")

	# "Keep going": the video goes up, and coming back asks for the playing banner early.
	var top_banner := int(banners.made("create top", mark)[-1].get_slice(" ", 2)) if not banners.made("create top", mark).is_empty() else -1
	var earned: Array[bool] = []
	mark = banners.calls.size()
	var video_uid: int = ads_manager._rewarded_ad._uid
	if not ads_manager.show_rewarded(func(got: bool) -> void: earned.append(got)):
		_fail("the stand-in video wasn't ready to show.")
	ads_manager.show_banner_bottom()
	await _frames()
	if top_banner >= 0 and banners.made("hide %d" % top_banner, mark).is_empty():
		_fail("the top banner wasn't hidden while the video was up.")
	if not banners.made("create", mark).is_empty():
		_fail("a banner was made while the video was up: %s." % [banners.made("create", mark)])
	rewarded.on_rewarded_ad_user_earned_reward.emit(video_uid, {})
	rewarded.on_rewarded_ad_dismissed_full_screen_content.emit(video_uid)
	await create_timer(0.6).timeout
	if earned.size() != 1 or not earned[0]:
		_fail("the video's reward didn't come through: %s." % [earned])
	if banners.made("create bottom", mark).size() != 1 or not banners.made("create top", mark).is_empty():
		_fail("after the video closed, just the bottom banner should be made, not %s." % [banners.calls.slice(mark)])

	# Nothing asked for while one's up: the banners there show again as it closes, not made anew.
	var filled := int(banners.made("create bottom", mark)[-1].get_slice(" ", 2)) if not banners.made("create bottom", mark).is_empty() else -1
	banners.on_ad_loaded.emit(filled)
	await _frames()
	mark = banners.calls.size()
	ads_manager._full_screen_ad_opening()
	ads_manager._full_screen_ad_closed()
	await _frames()
	if ", ".join(banners.calls.slice(mark)) != "hide %d, show %d" % [filled, filled]:
		_fail("with nothing asked for meanwhile, the banner should hide and show again, not %s." % [banners.calls.slice(mark)])

	await _put_back(ads_manager, stand_ins)
	if not _failed:
		print("Full-screen ads: no banner made or shown while one was up; banners back once it closed.")


func _put_back(ads_manager: Node, stand_ins: Dictionary) -> void:
	ads_manager.hide_banner()
	ads_manager._ads_active = false
	ads_manager._full_screen_ad_up = false
	await _frames()
	for singleton_name in stand_ins:
		Engine.unregister_singleton(singleton_name)
		stand_ins[singleton_name].free()


func _frames() -> void:
	for _i in 3:
		await process_frame


func _fail(message: String) -> void:
	push_error("Ads runtime smoke failed: " + message)
	_failed = true
