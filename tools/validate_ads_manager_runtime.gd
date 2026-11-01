extends SceneTree


func _initialize() -> void:
	var failed := false

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
		push_error("Ads runtime smoke failed: ad request dictionary is missing google_request_agent.")
		failed = true
	var fixed_size = ads_manager._fixed_banner_ad_size()
	if fixed_size.width != 320 or fixed_size.height != 50:
		push_error("Ads runtime smoke failed: fixed banner size is wrong.")
		failed = true

	ads_manager.show_banner_bottom()
	ads_manager.preload_interstitial()
	ads_manager.hide_banner()

	print("Ads runtime smoke passed.")
	quit(1 if failed else 0)
