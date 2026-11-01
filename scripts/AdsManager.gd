extends Node

const BANNER_ID := "ca-app-pub-3776793413956253/3241038986"
const INTERSTITIAL_ID := "ca-app-pub-3776793413956253/1504317887"
const IAP_ID := "com.muse.frogquest.removeads"
const SECRET_CODE := "3125"
const ADS_ENABLED := true
const DEBUG_DISABLE_ADS := false
const INTERSTITIAL_EVERY := 3
const TEST_BANNER_ID := "ca-app-pub-3940256099942544/2934735716"
const TEST_INTERSTITIAL_ID := "ca-app-pub-3940256099942544/4411468910"
## Rewarded unit for the Endless "keep going" revive (AdMob: Frog Quest+ > FQrewarded, 1 Revive).
const REWARDED_ID := "ca-app-pub-3776793413956253/4063431642"
const TEST_REWARDED_ID := "ca-app-pub-3940256099942544/1712485313"
const REWARDED_REQUEST_TIMEOUT_SECONDS := 10.0  # video ads take longer to arrive than display ads
const ADS_ENABLED_SETTING := "frogquest/ads/enabled"
const DEBUG_DISABLE_ADS_SETTING := "frogquest/ads/debug_disable_ads"

const PLACEHOLDER_HEIGHT := 58.0
const PLACEHOLDER_HEIGHT_LANDSCAPE_SCALE := 0.42
const PLACEHOLDER_LANDSCAPE_MIN_STRIP_HEIGHT := 22.0
const BANNER_BACKING_COLOR := Color(0.0, 0.0, 0.0, 1.0)
const AD_START_DELAY_SECONDS := 2.0
const CONSENT_TIMEOUT_SECONDS := 4.0
const MOBILE_ADS_INIT_TIMEOUT_SECONDS := 5.0
const AD_REQUEST_TIMEOUT_SECONDS := 5.0

# In landscape, request a narrow adaptive width (shorter banners). If adaptive is still tall, we
# fall back to standard Banner (320x50 dp)—see _resolve_banner_ad_size().
const LANDSCAPE_BANNER_WIDTH_FRAC := 0.34
const LANDSCAPE_BANNER_MAX_DP := 300
const LANDSCAPE_BANNER_MIN_DP := 260
const LANDSCAPE_ADAPTIVE_MAX_HEIGHT_DP := 54
const AD_POSITION_TOP := 0
const AD_POSITION_BOTTOM := 1
const AD_SIZE_FULL_WIDTH := -1
const AD_SIZE_BANNER_WIDTH := 320
const AD_SIZE_BANNER_HEIGHT := 50
const ADMOB_REQUEST_AGENT := "Godot-PoingStudios-4.3.1"
const ADMOB_SINGLETON := "PoingGodotAdMob"
const ADMOB_AD_SIZE_SINGLETON := "PoingGodotAdMobAdSize"
const ADMOB_AD_VIEW_SINGLETON := "PoingGodotAdMobAdView"
const ADMOB_INTERSTITIAL_SINGLETON := "PoingGodotAdMobInterstitialAd"
const ADMOB_REWARDED_SINGLETON := "PoingGodotAdMobRewardedAd"
const ADMOB_CONSENT_INFO_SINGLETON := "PoingGodotAdMobConsentInformation"
const ADMOB_UMP_SINGLETON := "PoingGodotAdMobUserMessagingPlatform"


class NativeAdRequest:
	var keywords: Array = []
	var extras: Dictionary = {}

	func convert_to_dictionary() -> Dictionary:
		return {
			"mediation_extras": {},
			"extras": extras,
			"google_request_agent": ADMOB_REQUEST_AGENT,
		}


class NativeAdSize:
	var width: int
	var height: int

	func _init(p_width: int, p_height: int) -> void:
		width = p_width
		height = p_height


class NativeAdListener:
	var on_ad_clicked: Callable = func() -> void: pass
	var on_ad_closed: Callable = func() -> void: pass
	var on_ad_failed_to_load: Callable = func(_load_ad_error) -> void: pass
	var on_ad_impression: Callable = func() -> void: pass
	var on_ad_loaded: Callable = func() -> void: pass
	var on_ad_opened: Callable = func() -> void: pass


class NativeFullScreenContentCallback:
	var on_ad_clicked: Callable = func() -> void: pass
	var on_ad_dismissed_full_screen_content: Callable = func() -> void: pass
	var on_ad_failed_to_show_full_screen_content: Callable = func(_ad_error) -> void: pass
	var on_ad_impression: Callable = func() -> void: pass
	var on_ad_showed_full_screen_content: Callable = func() -> void: pass


class NativeInterstitialAdLoadCallback:
	var on_ad_failed_to_load: Callable = func(_ad_error) -> void: pass
	var on_ad_loaded: Callable = func(_interstitial_ad) -> void: pass


class NativeBannerView:
	var ad_listener := NativeAdListener.new()
	var _plugin: Object
	var _uid: int = -1

	func _init(plugin: Object, ad_unit_id: String, ad_size, ad_position: int) -> void:
		_plugin = plugin
		if not _plugin:
			return
		_uid = _plugin.create({
			"ad_unit_id": ad_unit_id,
			"ad_position": ad_position,
			"ad_size": {
				"width": ad_size.width,
				"height": ad_size.height,
			},
		})
		_safe_connect("on_ad_clicked", _on_ad_clicked)
		_safe_connect("on_ad_closed", _on_ad_closed)
		_safe_connect("on_ad_failed_to_load", _on_ad_failed_to_load)
		_safe_connect("on_ad_impression", _on_ad_impression)
		_safe_connect("on_ad_loaded", _on_ad_loaded)
		_safe_connect("on_ad_opened", _on_ad_opened)

	func load_ad(ad_request) -> void:
		if _plugin and ad_request:
			_plugin.load_ad(_uid, ad_request.convert_to_dictionary(), ad_request.keywords)

	func destroy() -> void:
		if _plugin:
			_plugin.destroy(_uid)

	func hide() -> void:
		if _plugin:
			_plugin.hide(_uid)

	func show() -> void:
		if _plugin:
			_plugin.show(_uid)

	func get_height_in_pixels() -> int:
		if _plugin and _plugin.has_method("get_height_in_pixels"):
			return int(_plugin.get_height_in_pixels(_uid))
		return -1

	func _safe_connect(signal_name: String, callable: Callable, flags := 0) -> void:
		if _plugin and _plugin.has_signal(signal_name) and not _plugin.is_connected(signal_name, callable):
			_plugin.connect(signal_name, callable, flags)

	func _on_ad_clicked(uid: int) -> void:
		if uid == _uid:
			ad_listener.on_ad_clicked.call_deferred()

	func _on_ad_closed(uid: int) -> void:
		if uid == _uid:
			ad_listener.on_ad_closed.call_deferred()

	func _on_ad_failed_to_load(uid: int, load_ad_error_dictionary: Dictionary) -> void:
		if uid == _uid:
			ad_listener.on_ad_failed_to_load.call_deferred(load_ad_error_dictionary)

	func _on_ad_impression(uid: int) -> void:
		if uid == _uid:
			ad_listener.on_ad_impression.call_deferred()

	func _on_ad_loaded(uid: int) -> void:
		if uid == _uid:
			ad_listener.on_ad_loaded.call_deferred()

	func _on_ad_opened(uid: int) -> void:
		if uid == _uid:
			ad_listener.on_ad_opened.call_deferred()


class NativeInterstitialAd:
	var full_screen_content_callback := NativeFullScreenContentCallback.new()
	var _plugin: Object
	var _uid: int = -1

	func _init(plugin: Object, uid: int) -> void:
		_plugin = plugin
		_uid = uid
		if not _plugin:
			return
		_safe_connect("on_interstitial_ad_clicked", _on_interstitial_ad_clicked)
		_safe_connect("on_interstitial_ad_dismissed_full_screen_content", _on_interstitial_ad_dismissed_full_screen_content)
		_safe_connect("on_interstitial_ad_failed_to_show_full_screen_content", _on_interstitial_ad_failed_to_show_full_screen_content)
		_safe_connect("on_interstitial_ad_impression", _on_interstitial_ad_impression)
		_safe_connect("on_interstitial_ad_showed_full_screen_content", _on_interstitial_ad_showed_full_screen_content)

	func show() -> void:
		if _plugin:
			_plugin.show(_uid)

	func destroy() -> void:
		if _plugin:
			_plugin.destroy(_uid)

	func _safe_connect(signal_name: String, callable: Callable, flags := 0) -> void:
		if _plugin and _plugin.has_signal(signal_name) and not _plugin.is_connected(signal_name, callable):
			_plugin.connect(signal_name, callable, flags)

	func _on_interstitial_ad_clicked(uid: int) -> void:
		if uid == _uid:
			full_screen_content_callback.on_ad_clicked.call_deferred()

	func _on_interstitial_ad_dismissed_full_screen_content(uid: int) -> void:
		if uid == _uid:
			full_screen_content_callback.on_ad_dismissed_full_screen_content.call_deferred()

	func _on_interstitial_ad_failed_to_show_full_screen_content(uid: int, ad_error_dictionary: Dictionary) -> void:
		if uid == _uid:
			full_screen_content_callback.on_ad_failed_to_show_full_screen_content.call_deferred(ad_error_dictionary)

	func _on_interstitial_ad_impression(uid: int) -> void:
		if uid == _uid:
			full_screen_content_callback.on_ad_impression.call_deferred()

	func _on_interstitial_ad_showed_full_screen_content(uid: int) -> void:
		if uid == _uid:
			full_screen_content_callback.on_ad_showed_full_screen_content.call_deferred()


class NativeRewardedAd:
	var full_screen_content_callback := NativeFullScreenContentCallback.new()
	var on_user_earned_reward: Callable = func(_rewarded_item: Dictionary) -> void: pass
	var _plugin: Object
	var _uid: int = -1

	func _init(plugin: Object, uid: int) -> void:
		_plugin = plugin
		_uid = uid
		if not _plugin:
			return
		_safe_connect("on_rewarded_ad_clicked", _on_rewarded_ad_clicked)
		_safe_connect("on_rewarded_ad_dismissed_full_screen_content", _on_rewarded_ad_dismissed_full_screen_content)
		_safe_connect("on_rewarded_ad_failed_to_show_full_screen_content", _on_rewarded_ad_failed_to_show_full_screen_content)
		_safe_connect("on_rewarded_ad_impression", _on_rewarded_ad_impression)
		_safe_connect("on_rewarded_ad_showed_full_screen_content", _on_rewarded_ad_showed_full_screen_content)
		_safe_connect("on_rewarded_ad_user_earned_reward", _on_rewarded_ad_user_earned_reward)

	func show() -> void:
		if _plugin:
			_plugin.show(_uid)

	func destroy() -> void:
		if _plugin:
			_plugin.destroy(_uid)

	func _safe_connect(signal_name: String, callable: Callable, flags := 0) -> void:
		if _plugin and _plugin.has_signal(signal_name) and not _plugin.is_connected(signal_name, callable):
			_plugin.connect(signal_name, callable, flags)

	func _on_rewarded_ad_clicked(uid: int) -> void:
		if uid == _uid:
			full_screen_content_callback.on_ad_clicked.call_deferred()

	func _on_rewarded_ad_dismissed_full_screen_content(uid: int) -> void:
		if uid == _uid:
			full_screen_content_callback.on_ad_dismissed_full_screen_content.call_deferred()

	func _on_rewarded_ad_failed_to_show_full_screen_content(uid: int, ad_error_dictionary: Dictionary) -> void:
		if uid == _uid:
			full_screen_content_callback.on_ad_failed_to_show_full_screen_content.call_deferred(ad_error_dictionary)

	func _on_rewarded_ad_impression(uid: int) -> void:
		if uid == _uid:
			full_screen_content_callback.on_ad_impression.call_deferred()

	func _on_rewarded_ad_showed_full_screen_content(uid: int) -> void:
		if uid == _uid:
			full_screen_content_callback.on_ad_showed_full_screen_content.call_deferred()

	func _on_rewarded_ad_user_earned_reward(uid: int, rewarded_item_dictionary: Dictionary) -> void:
		if uid == _uid:
			on_user_earned_reward.call_deferred(rewarded_item_dictionary)


class NativeConsentForm:
	var _plugin: Object
	var _uid: int = -1
	var _on_consent_form_dismissed_callback: Callable = func(_error) -> void: pass

	func _init(plugin: Object, uid: int) -> void:
		_plugin = plugin
		_uid = uid

	func show(on_consent_form_dismissed := func(_form_error) -> void: pass) -> void:
		if not _plugin:
			return
		_on_consent_form_dismissed_callback = on_consent_form_dismissed
		_plugin.show(_uid)
		_safe_connect("on_consent_form_dismissed", _on_consent_form_dismissed)

	func _safe_connect(signal_name: String, callable: Callable, flags := 0) -> void:
		if _plugin and _plugin.has_signal(signal_name) and not _plugin.is_connected(signal_name, callable):
			_plugin.connect(signal_name, callable, flags)

	func _on_consent_form_dismissed(uid: int, form_error_dictionary: Dictionary) -> void:
		if uid == _uid:
			var error = null if form_error_dictionary.is_empty() else form_error_dictionary
			_on_consent_form_dismissed_callback.call_deferred(error)

## Godot canvas layer for the bottom/top banner placeholder strip (keep UI above this).
const BANNER_PLACEHOLDER_CANVAS_LAYER := 50

## Which banner stripes are requested (supports bottom-only, top-only, or both for Endless game over).
var _banner_show_bottom := false
var _banner_show_top := false

var _iap
var _iap_backend_name := ""
var _iap_uses_pending_events := false
var _gameover_count := 0
var _ads_active := false
var _mobile_ads_ready := false
var _banner_view_bottom
var _banner_view_top
var _native_bottom_banner_loaded := false
var _native_top_banner_loaded := false
var _banner_listener_bottom
var _banner_listener_top
var _interstitial_ready := false
var _interstitial_loading := false
var _interstitial_ad
var _interstitial_load_callback
var _interstitial_content_callback
var _interstitial_load_uid := -1
var _pending_banner_refresh := false
var _pending_interstitial_preload := false
var _ad_callbacks_configured := false
var _ad_services_start_requested := false
var _ad_services_start_scheduled := false
var _iap_start_requested := false
var _consent_setup_hint_printed := false
var _consent_flow_active := false
var _mobile_ads_initializing := false
var _consent_flow_token := 0
var _mobile_ads_init_token := 0
var _banner_request_token := 0
var _interstitial_request_token := 0
var _rewarded_ready := false
var _rewarded_loading := false
var _rewarded_ad
var _rewarded_load_uid := -1
var _rewarded_request_token := 0
var _pending_rewarded_preload := false
var _rewarded_done := Callable()
var _rewarded_earned := false
var _consent_form_showing := false

var _placeholder_layer: CanvasLayer
var _placeholder_root: Control
var _top_backing: ColorRect
var _bottom_backing: ColorRect
var _top_placeholder: Control
var _bottom_placeholder: Control

signal ads_removed_changed


## Layer for title / HUD that must draw above the in-engine banner placeholder.
func canvas_layer_above_banner_placeholder() -> int:
	return BANNER_PLACEHOLDER_CANVAS_LAYER + 8


## Ads only exist where the AdMob plugin does (iPhone/Android). Desktop and web builds have none.
func platform_has_ads() -> bool:
	var platform := OS.get_name()
	return platform == "iOS" or platform == "Android"


## True when this player never sees ads: they bought Remove Ads, or this platform has no ads.
## Ad-gated things (Remove Ads buttons, "watch an ad" offers) key off this.
func is_ad_free() -> bool:
	return MusicManager.ads_removed or not platform_has_ads()


## Viewport pixels hidden behind the bottom of the screen (iPhone home indicator); 0 off mobile.
func get_viewport_bottom_safe_inset() -> float:
	return _viewport_safe_insets().w


## Viewport pixels to leave clear above the bottom edge when a bottom banner is active.
func get_viewport_bottom_banner_clearance() -> float:
	if not _ads_active or not _banner_show_bottom or not _native_bottom_banner_loaded:
		return 0.0
	return _bottom_banner_reserved_height() + 6.0


## Viewport pixels to reserve below the top edge when a top banner is active (e.g. game over dual ads).
func get_viewport_top_banner_clearance() -> float:
	if not _ads_active or not _banner_show_top or not _native_top_banner_loaded:
		return 0.0
	return _top_banner_reserved_height() + 6.0


func _wants_banner() -> bool:
	return _banner_show_bottom or _banner_show_top


func _should_show_top_banner_placeholder() -> bool:
	return false


func _should_show_bottom_banner_placeholder() -> bool:
	return false


func _should_show_top_banner_backing() -> bool:
	return false


func _should_show_bottom_banner_backing() -> bool:
	return false


func _notify_banner_dependent_ui() -> void:
	if not is_inside_tree():
		return
	get_tree().call_group_flags(
		SceneTree.GROUP_CALL_DEFERRED,
		&"banner_reserve_ui",
		&"_apply_ui_layout",
	)


func _ready() -> void:
	_trace("AdsManager ready start")
	_ads_active = _ads_runtime_enabled() and not MusicManager.ads_removed
	if not _ads_active:
		print("AdsManager: ads disabled or already removed; native ad SDK calls will be skipped.")
	if not Engine.is_editor_hint():
		get_viewport().size_changed.connect(_on_viewport_for_banner_resize)
	_trace("AdsManager ready end")
	print("StartupTrace: AdsManager ready at %d ms" % Time.get_ticks_msec())


func _trace(label: String) -> void:
	print("StartupTrace: %s at %d ms" % [label, Time.get_ticks_msec()])


func _ads_runtime_enabled() -> bool:
	if not ADS_ENABLED or DEBUG_DISABLE_ADS:
		return false
	if not platform_has_ads():
		return false
	var env_disable := OS.get_environment("FROGQUEST_DISABLE_ADS").to_lower()
	if env_disable in ["1", "true", "yes", "on"]:
		return false
	if ProjectSettings.has_setting(ADS_ENABLED_SETTING) and not bool(ProjectSettings.get_setting(ADS_ENABLED_SETTING)):
		return false
	if ProjectSettings.has_setting(DEBUG_DISABLE_ADS_SETTING) and bool(ProjectSettings.get_setting(DEBUG_DISABLE_ADS_SETTING)):
		return false
	return true


func show_banner_bottom() -> void:
	if not _ads_active:
		hide_banner()
		return
	_banner_show_bottom = true
	_banner_show_top = false
	_banner_refresh_flow()


func show_banner_top() -> void:
	if not _ads_active:
		hide_banner()
		return
	_banner_show_bottom = false
	_banner_show_top = true
	_banner_refresh_flow()


## Endless game over: keep the gameplay bottom stripe and add a second banner along the top.
func show_banners_top_and_bottom() -> void:
	if not _ads_active:
		hide_banner()
		return
	_banner_show_bottom = true
	_banner_show_top = true
	_banner_refresh_flow()


func hide_banner() -> void:
	_banner_show_bottom = false
	_banner_show_top = false
	_pending_banner_refresh = false
	_hide_placeholders()
	if _banner_view_bottom:
		_banner_view_bottom.destroy()
		_banner_view_bottom = null
	if _banner_view_top:
		_banner_view_top.destroy()
		_banner_view_top = null
	_native_bottom_banner_loaded = false
	_native_top_banner_loaded = false
	_notify_banner_dependent_ui()


func _banner_refresh_flow() -> void:
	if not _ads_active:
		return
	_ensure_lightweight_ad_ui()
	_refresh_placeholder_visibility()
	if not _mobile_ads_ready:
		_pending_banner_refresh = true
		_ensure_ad_services_started()
		_notify_banner_dependent_ui()
		return
	call_deferred("_request_banners_deferred")


## Recompute placeholder layout and reload the banner for the current window size/orientation
## (narrower landscape width, etc.). Use when a scene changes display scale or orientation.
func sync_banner_with_viewport() -> void:
	if not _ads_active:
		return
	if not _wants_banner():
		return
	_refresh_placeholder_visibility()
	if _mobile_ads_ready:
		call_deferred("_request_banners_deferred")
	else:
		_pending_banner_refresh = true


func _on_viewport_for_banner_resize() -> void:
	sync_banner_with_viewport()


func preload_interstitial() -> void:
	if not _ads_active:
		return
	if _interstitial_ready or _interstitial_loading:
		return
	if not _mobile_ads_ready:
		_pending_interstitial_preload = true
		_ensure_ad_services_started()
		return
	call_deferred("_preload_interstitial_now")


func _preload_interstitial_now() -> void:
	if not _ads_active or not _mobile_ads_ready:
		return
	if _interstitial_ready or _interstitial_loading:
		return

	_ensure_lightweight_ad_ui()
	_interstitial_loading = true
	_pending_interstitial_preload = false
	_interstitial_request_token += 1
	var request_token := _interstitial_request_token
	_trace("AdsManager interstitial request start")
	var plugin = _native_singleton(ADMOB_INTERSTITIAL_SINGLETON)
	if plugin == null:
		_interstitial_loading = false
		_trace("AdsManager interstitial request fail no native singleton")
		return
	_interstitial_load_uid = plugin.create()
	_safe_connect_native(plugin, "on_interstitial_ad_loaded", _on_native_interstitial_ad_loaded, CONNECT_DEFERRED)
	_safe_connect_native(plugin, "on_interstitial_ad_failed_to_load", _on_native_interstitial_ad_failed_to_load, CONNECT_DEFERRED)
	var request = _make_ad_request()
	plugin.load(INTERSTITIAL_ID, request.convert_to_dictionary(), request.keywords, _interstitial_load_uid)
	_trace("AdsManager interstitial load call returned")
	_start_interstitial_request_timeout(request_token, _interstitial_load_uid)


func on_game_over() -> void:
	_gameover_count += 1
	if not _ads_active:
		return
	if _interstitial_ready and (_gameover_count % INTERSTITIAL_EVERY == 0):
		_interstitial_ready = false
		if _interstitial_ad:
			_interstitial_ad.show()
		return
	preload_interstitial()


## Loads a rewarded video ahead of time so a "keep going" offer can play one straight away.
func preload_rewarded() -> void:
	if not _ads_active:
		return
	if _rewarded_ready or _rewarded_loading:
		return
	if not _mobile_ads_ready:
		_pending_rewarded_preload = true
		_ensure_ad_services_started()
		return
	call_deferred("_preload_rewarded_now")


func _preload_rewarded_now() -> void:
	if not _ads_active or not _mobile_ads_ready:
		return
	if _rewarded_ready or _rewarded_loading:
		return

	_rewarded_loading = true
	_pending_rewarded_preload = false
	_rewarded_request_token += 1
	var request_token := _rewarded_request_token
	_trace("AdsManager rewarded request start")
	var plugin = _native_singleton(ADMOB_REWARDED_SINGLETON)
	if plugin == null:
		_rewarded_loading = false
		_trace("AdsManager rewarded request fail no native singleton")
		return
	_rewarded_load_uid = plugin.create()
	_safe_connect_native(plugin, "on_rewarded_ad_loaded", _on_native_rewarded_ad_loaded, CONNECT_DEFERRED)
	_safe_connect_native(plugin, "on_rewarded_ad_failed_to_load", _on_native_rewarded_ad_failed_to_load, CONNECT_DEFERRED)
	var request = _make_ad_request()
	plugin.load(REWARDED_ID, request.convert_to_dictionary(), request.keywords, _rewarded_load_uid)
	_trace("AdsManager rewarded load call returned")
	_start_rewarded_request_timeout(request_token, _rewarded_load_uid)


func is_rewarded_ready() -> bool:
	return _ads_active and _rewarded_ready and _rewarded_ad != null


## Plays the preloaded rewarded video; on_done(earned: bool) runs once it's closed.
## Returns false (and starts loading one) if there isn't one ready.
func show_rewarded(on_done: Callable) -> bool:
	if not is_rewarded_ready():
		preload_rewarded()
		return false
	_rewarded_ready = false
	_rewarded_done = on_done
	_rewarded_earned = false
	_rewarded_ad.show()
	return true


func try_code(input: String) -> bool:
	if input.strip_edges() == SECRET_CODE:
		_apply_remove_ads()
		return true
	return false


func purchase_remove_ads() -> void:
	_ensure_iap_backend_started()
	if not _iap:
		push_warning("Remove Ads purchase requested, but no purchase backend is configured yet.")
		return
	if _iap_backend_name == "IOSInAppPurchase":
		var result: int = _iap.request("purchase", {"productID": IAP_ID})
		if result != OK:
			push_warning("AdsManager: Remove Ads purchase request failed to start: %s" % result)
		return
	_iap.purchase({"product_id": IAP_ID})


func restore_purchases() -> void:
	_ensure_iap_backend_started()
	if not _iap:
		push_warning("Restore purchases requested, but no purchase backend is configured yet.")
		return
	if _iap_backend_name == "IOSInAppPurchase":
		var sync_result: int = _iap.request("appStoreSync", {})
		if sync_result != OK:
			push_warning("AdsManager: App Store sync request failed to start: %s" % sync_result)
		_request_ios_current_entitlements()
		return
	_iap.restore_purchases()


func has_purchase_backend() -> bool:
	_ensure_iap_backend_started()
	return _iap != null


func get_purchase_backend_name() -> String:
	return _iap_backend_name


func get_remove_ads_product_id() -> String:
	return IAP_ID


func _native_singleton(name: String):
	if Engine.has_singleton(name):
		return Engine.get_singleton(name)
	return null


func _safe_connect_native(plugin: Object, signal_name: String, callable: Callable, flags := 0) -> void:
	if plugin and plugin.has_signal(signal_name) and not plugin.is_connected(signal_name, callable):
		plugin.connect(signal_name, callable, flags)


func _ad_size_from_dictionary(value: Variant):
	if typeof(value) != TYPE_DICTIONARY:
		return NativeAdSize.new(0, 0)
	var dict := value as Dictionary
	return NativeAdSize.new(int(dict.get("width", 0)), int(dict.get("height", 0)))


func _native_ad_size(method_name: String, width: int):
	var plugin = _native_singleton(ADMOB_AD_SIZE_SINGLETON)
	if plugin == null or not plugin.has_method(method_name):
		return NativeAdSize.new(0, 0)
	return _ad_size_from_dictionary(plugin.call(method_name, width))


func _ad_error_message(error) -> String:
	if error == null:
		return "unknown"
	var msg = error.get("message")
	if msg == null:
		return str(error)
	return str(msg)


func _looks_like_admob_consent_setup_issue(message: String) -> bool:
	var lower := message.to_lower()
	return (
		lower.contains("publisher's account configuration")
		or lower.contains("invalid app id")
		or lower.contains("configured form")
	)


func _log_ad_load_failure(slot: String, error) -> void:
	var message := _ad_error_message(error)
	print("AdsManager: %s failed to load: %s" % [slot, message])
	var lower := message.to_lower()
	if lower.contains("server with the specified hostname could not be found") or lower.contains("network"):
		print("AdsManager: %s failure looks like device/network/DNS connectivity, not a scene-code crash." % slot)
	elif lower.contains("no ad to show"):
		print("AdsManager: %s request reached AdMob but returned no fill. This is common before AdMob app review/app-ads.txt verification or when inventory is unavailable." % slot)


func _configure_banner_callbacks() -> void:
	_banner_listener_bottom = NativeAdListener.new()
	_banner_listener_top = NativeAdListener.new()

	_banner_listener_bottom.on_ad_loaded = func() -> void:
		_native_bottom_banner_loaded = true
		if _banner_view_bottom:
			_banner_view_bottom.show()
		_refresh_placeholder_visibility()
		_notify_banner_dependent_ui()
		_trace("AdsManager bottom banner request end loaded")
		print("AdsManager: bottom banner loaded")
	_banner_listener_bottom.on_ad_failed_to_load = func(error) -> void:
		_native_bottom_banner_loaded = false
		_refresh_placeholder_visibility()
		_trace("AdsManager bottom banner request fail")
		_log_ad_load_failure("bottom banner", error)
	_banner_listener_bottom.on_ad_impression = func() -> void:
		print("AdsManager: bottom banner impression recorded")
	_banner_listener_bottom.on_ad_opened = func() -> void:
		print("AdsManager: bottom banner opened")
	_banner_listener_bottom.on_ad_closed = func() -> void:
		print("AdsManager: bottom banner closed")

	_banner_listener_top.on_ad_loaded = func() -> void:
		_native_top_banner_loaded = true
		if _banner_view_top:
			_banner_view_top.show()
		_refresh_placeholder_visibility()
		_notify_banner_dependent_ui()
		_trace("AdsManager top banner request end loaded")
		print("AdsManager: top banner loaded")
	_banner_listener_top.on_ad_failed_to_load = func(error) -> void:
		_native_top_banner_loaded = false
		_refresh_placeholder_visibility()
		_trace("AdsManager top banner request fail")
		_log_ad_load_failure("top banner", error)
	_banner_listener_top.on_ad_impression = func() -> void:
		print("AdsManager: top banner impression recorded")
	_banner_listener_top.on_ad_opened = func() -> void:
		print("AdsManager: top banner opened")
	_banner_listener_top.on_ad_closed = func() -> void:
		print("AdsManager: top banner closed")


func _configure_interstitial_callbacks() -> void:
	_interstitial_load_callback = NativeInterstitialAdLoadCallback.new()
	_interstitial_content_callback = NativeFullScreenContentCallback.new()

	_interstitial_load_callback.on_ad_loaded = func(ad) -> void:
		_interstitial_loading = false
		_interstitial_ready = true
		if _interstitial_ad:
			_interstitial_ad.destroy()
		ad.full_screen_content_callback = _interstitial_content_callback
		_interstitial_ad = ad
		_trace("AdsManager interstitial request end loaded")
		print("AdsManager: interstitial loaded")
	_interstitial_load_callback.on_ad_failed_to_load = func(error) -> void:
		_interstitial_loading = false
		_interstitial_ready = false
		_trace("AdsManager interstitial request fail")
		_log_ad_load_failure("interstitial", error)

	_interstitial_content_callback.on_ad_clicked = func() -> void:
		print("AdsManager: interstitial clicked")
	_interstitial_content_callback.on_ad_impression = func() -> void:
		print("AdsManager: interstitial impression recorded")
	_interstitial_content_callback.on_ad_showed_full_screen_content = func() -> void:
		print("AdsManager: interstitial showed")
	_interstitial_content_callback.on_ad_dismissed_full_screen_content = func() -> void:
		print("AdsManager: interstitial dismissed")
		_destroy_interstitial()
		preload_interstitial()
	_interstitial_content_callback.on_ad_failed_to_show_full_screen_content = func(error) -> void:
		print("AdsManager: interstitial failed to show: %s" % _ad_error_message(error))
		_destroy_interstitial()
		preload_interstitial()


func _on_native_interstitial_ad_loaded(uid: int) -> void:
	if uid != _interstitial_load_uid:
		return
	var plugin = _native_singleton(ADMOB_INTERSTITIAL_SINGLETON)
	if plugin == null:
		_interstitial_load_callback.on_ad_failed_to_load.call({"message": "native interstitial singleton unavailable after load"})
		return
	_interstitial_load_callback.on_ad_loaded.call(NativeInterstitialAd.new(plugin, uid))


func _on_native_interstitial_ad_failed_to_load(uid: int, load_ad_error_dictionary: Dictionary) -> void:
	if uid == _interstitial_load_uid:
		_interstitial_load_callback.on_ad_failed_to_load.call(load_ad_error_dictionary)


func _on_native_rewarded_ad_loaded(uid: int) -> void:
	if uid != _rewarded_load_uid:
		return
	_rewarded_loading = false
	var plugin = _native_singleton(ADMOB_REWARDED_SINGLETON)
	if plugin == null:
		return
	if _rewarded_ad:
		_rewarded_ad.destroy()
	_rewarded_ad = NativeRewardedAd.new(plugin, uid)
	_rewarded_ad.on_user_earned_reward = func(_rewarded_item: Dictionary) -> void:
		_rewarded_earned = true
		print("AdsManager: rewarded ad reward earned")
	_rewarded_ad.full_screen_content_callback.on_ad_showed_full_screen_content = func() -> void:
		print("AdsManager: rewarded ad showed")
	_rewarded_ad.full_screen_content_callback.on_ad_impression = func() -> void:
		print("AdsManager: rewarded ad impression recorded")
	_rewarded_ad.full_screen_content_callback.on_ad_dismissed_full_screen_content = func() -> void:
		print("AdsManager: rewarded ad dismissed")
		_finish_rewarded()
	_rewarded_ad.full_screen_content_callback.on_ad_failed_to_show_full_screen_content = func(error) -> void:
		print("AdsManager: rewarded ad failed to show: %s" % _ad_error_message(error))
		_finish_rewarded()
	_rewarded_ready = true
	_trace("AdsManager rewarded request end loaded")
	print("AdsManager: rewarded ad loaded")


func _on_native_rewarded_ad_failed_to_load(uid: int, load_ad_error_dictionary: Dictionary) -> void:
	if uid != _rewarded_load_uid:
		return
	_rewarded_loading = false
	_rewarded_ready = false
	_trace("AdsManager rewarded request fail")
	_log_ad_load_failure("rewarded ad", load_ad_error_dictionary)


func _finish_rewarded() -> void:
	# The reward callback can trail the dismissal by a moment; give it a beat to land.
	await get_tree().create_timer(0.3, true, false, true).timeout
	var done := _rewarded_done
	_rewarded_done = Callable()
	_destroy_rewarded()
	preload_rewarded()
	if done.is_valid():
		done.call(_rewarded_earned)


func _destroy_rewarded() -> void:
	_rewarded_ready = false
	_rewarded_loading = false
	if _rewarded_ad:
		_rewarded_ad.destroy()
		_rewarded_ad = null


func _start_mobile_ads_flow() -> void:
	if not _ads_active:
		_trace("AdsManager init skipped ads inactive")
		return
	_trace("AdsManager init start")
	if not Engine.has_singleton(ADMOB_SINGLETON):
		print("AdsManager: mobile ad singleton not available, showing placeholders only.")
		_trace("AdsManager init end no mobile ad singleton")
		return
	_warn_if_test_ids_are_still_enabled()
	if Engine.has_singleton(ADMOB_CONSENT_INFO_SINGLETON) and Engine.has_singleton(ADMOB_UMP_SINGLETON):
		_request_ad_consent()
		return
	_initialize_mobile_ads()


func _request_ad_consent() -> void:
	if not _ads_active:
		return
	var consent_info = _native_singleton(ADMOB_CONSENT_INFO_SINGLETON)
	if consent_info == null:
		_trace("AdsManager UMP consent skipped no native singleton")
		_initialize_mobile_ads()
		return
	_consent_flow_active = true
	_consent_flow_token += 1
	var token := _consent_flow_token
	_trace("AdsManager UMP consent start")
	_start_consent_timeout(token)
	# IAB TCF / Google UMP: false for typical general‑audience games; set true if you target minors.
	_safe_connect_native(consent_info, "on_consent_info_updated_success", _on_consent_update_success)
	_safe_connect_native(consent_info, "on_consent_info_updated_failure", _on_consent_update_failure)
	consent_info.update({
		"tag_for_under_age_of_consent": false,
		"consent_debug_settings": null,
	})


func _load_consent_form() -> void:
	var ump = _native_singleton(ADMOB_UMP_SINGLETON)
	if ump == null:
		_trace("AdsManager UMP form skipped no native singleton")
		_initialize_mobile_ads()
		return
	_trace("AdsManager UMP form load start")
	_safe_connect_native(ump, "on_consent_form_load_success_listener", _on_consent_form_load_success, CONNECT_ONE_SHOT)
	_safe_connect_native(ump, "on_consent_form_load_failure_listener", _on_consent_update_failure, CONNECT_ONE_SHOT)
	ump.load_consent_form()


func _on_consent_update_success() -> void:
	_trace("AdsManager UMP consent update success")
	var consent_info = _native_singleton(ADMOB_CONSENT_INFO_SINGLETON)
	if consent_info == null:
		_consent_flow_active = false
		_initialize_mobile_ads()
		return
	if consent_info.get_is_consent_form_available():
		_load_consent_form()
		return
	_consent_flow_active = false
	_initialize_mobile_ads()


func _on_consent_form_load_success(uid: int) -> void:
	_trace("AdsManager UMP form load success")
	var ump = _native_singleton(ADMOB_UMP_SINGLETON)
	if ump == null:
		_consent_flow_active = false
		_initialize_mobile_ads()
		return
	_on_consent_form_loaded(NativeConsentForm.new(ump, uid))


func _on_consent_form_loaded(form) -> void:
	var consent_info = _native_singleton(ADMOB_CONSENT_INFO_SINGLETON)
	if consent_info == null:
		_initialize_mobile_ads()
		return
	var status = consent_info.get_consent_status()
	if status == 2:
		_trace("AdsManager UMP form show start")
		# This is also where the IDFA explainer and Apple's tracking prompt appear when an IDFA
		# message is published in AdMob; while it's up, the consent timeout leaves it alone.
		_consent_form_showing = true
		form.show(_on_consent_form_dismissed)
		return
	_consent_flow_active = false
	_initialize_mobile_ads()


func _on_consent_form_dismissed(error) -> void:
	_consent_form_showing = false
	if error:
		print("AdsManager: consent form dismissed with error: %s" % _ad_error_message(error))
		_trace("AdsManager UMP form dismissed fail")
	else:
		_trace("AdsManager UMP form dismissed")
	_consent_flow_active = false
	_initialize_mobile_ads()


func _on_consent_update_failure(error) -> void:
	var message := _ad_error_message(error)
	_consent_flow_active = false
	_trace("AdsManager UMP consent fail")
	print("AdsManager: consent update failed: %s" % message)
	if _looks_like_admob_consent_setup_issue(message) and not _consent_setup_hint_printed:
		_consent_setup_hint_printed = true
		print("AdsManager: AdMob privacy message setup is missing or incomplete for this app ID. In AdMob, create and publish the app's Privacy & messaging form, then retest.")
	_initialize_mobile_ads()


func _initialize_mobile_ads() -> void:
	if not _ads_active:
		_trace("AdsManager MobileAds.initialize skipped ads inactive")
		return
	if _mobile_ads_ready or _mobile_ads_initializing:
		return
	var mobile_ads = _native_singleton(ADMOB_SINGLETON)
	if mobile_ads == null:
		_trace("AdsManager MobileAds.initialize fail no native singleton")
		return
	_mobile_ads_initializing = true
	_mobile_ads_init_token += 1
	var token := _mobile_ads_init_token
	_trace("AdsManager MobileAds.initialize start")
	_start_mobile_ads_init_timeout(token)
	_safe_connect_native(mobile_ads, "on_initialization_complete", _on_mobile_ads_initialized, CONNECT_ONE_SHOT)
	mobile_ads.set_request_configuration({
		# T (teen) lets far more advertisers bid than G; the App Store age rating must cover it (13+).
		"max_ad_content_rating": "T",
		"tag_for_child_directed_treatment": 0,
		"tag_for_under_age_of_consent": 0,
	}, [])
	mobile_ads.initialize()
	_trace("AdsManager MobileAds.initialize call returned")


func _prepare_lightweight_ad_ui_after_first_frames() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_ensure_lightweight_ad_ui()


func _ensure_lightweight_ad_ui() -> void:
	if not _ad_callbacks_configured:
		_configure_banner_callbacks()
		_configure_interstitial_callbacks()
		_ad_callbacks_configured = true
	_setup_placeholder_ui()


func _ensure_ad_services_started() -> void:
	if not _ads_active:
		return
	if _ad_services_start_requested or _ad_services_start_scheduled:
		return
	_ad_services_start_scheduled = true
	_ensure_lightweight_ad_ui()
	call_deferred("_start_ad_services_after_delay")


func _start_ad_services_after_delay() -> void:
	_trace("AdsManager init scheduled")
	await get_tree().process_frame
	await get_tree().process_frame
	if AD_START_DELAY_SECONDS > 0.0:
		await get_tree().create_timer(AD_START_DELAY_SECONDS).timeout
	if not is_inside_tree() or not _ads_active:
		_ad_services_start_scheduled = false
		return
	if _ad_services_start_requested:
		_ad_services_start_scheduled = false
		return
	_ad_services_start_scheduled = false
	_ad_services_start_requested = true
	_start_mobile_ads_flow()


func _ensure_iap_backend_started() -> void:
	if _iap_start_requested:
		return
	_iap_start_requested = true
	_initialize_iap_backend()


func _on_mobile_ads_initialized(_status = null) -> void:
	_mobile_ads_initializing = false
	_mobile_ads_ready = true
	_trace("AdsManager MobileAds.initialize end")
	print("AdsManager: MobileAds initialized")
	_refresh_placeholder_visibility()
	if _pending_banner_refresh and _ads_active:
		_request_banners()
	if _pending_interstitial_preload and _ads_active:
		preload_interstitial()
	if _pending_rewarded_preload and _ads_active:
		preload_rewarded()


func _start_consent_timeout(token: int) -> void:
	_consent_timeout_after_delay.call_deferred(token)


func _consent_timeout_after_delay(token: int) -> void:
	await get_tree().create_timer(CONSENT_TIMEOUT_SECONDS).timeout
	if not is_inside_tree() or not _ads_active:
		return
	if token != _consent_flow_token or not _consent_flow_active or _mobile_ads_ready:
		return
	if _consent_form_showing:
		return  # the player is reading it (or answering Apple's prompt); dismissal starts ads
	_trace("AdsManager UMP consent timeout")
	_consent_flow_active = false
	_initialize_mobile_ads()


func _start_mobile_ads_init_timeout(token: int) -> void:
	_mobile_ads_init_timeout_after_delay.call_deferred(token)


func _mobile_ads_init_timeout_after_delay(token: int) -> void:
	await get_tree().create_timer(MOBILE_ADS_INIT_TIMEOUT_SECONDS).timeout
	if not is_inside_tree() or not _ads_active:
		return
	if token != _mobile_ads_init_token or not _mobile_ads_initializing or _mobile_ads_ready:
		return
	_trace("AdsManager MobileAds.initialize timeout")
	_pending_banner_refresh = false
	_pending_interstitial_preload = false
	_pending_rewarded_preload = false


func _request_banners_deferred() -> void:
	if not is_inside_tree() or not _ads_active or not _mobile_ads_ready:
		return
	_request_banners()


func _start_banner_request_timeout(token: int) -> void:
	_banner_request_timeout_after_delay.call_deferred(token)


func _banner_request_timeout_after_delay(token: int) -> void:
	await get_tree().create_timer(AD_REQUEST_TIMEOUT_SECONDS).timeout
	if not is_inside_tree() or token != _banner_request_token:
		return
	var timed_out := false
	if _banner_view_bottom and _banner_show_bottom and not _native_bottom_banner_loaded:
		_banner_view_bottom.destroy()
		_banner_view_bottom = null
		timed_out = true
	if _banner_view_top and _banner_show_top and not _native_top_banner_loaded:
		_banner_view_top.destroy()
		_banner_view_top = null
		timed_out = true
	if timed_out:
		_trace("AdsManager banner request timeout")
		_refresh_placeholder_visibility()


func _start_interstitial_request_timeout(token: int, load_uid: int) -> void:
	_interstitial_request_timeout_after_delay.call_deferred(token, load_uid)


func _interstitial_request_timeout_after_delay(token: int, load_uid: int) -> void:
	await get_tree().create_timer(AD_REQUEST_TIMEOUT_SECONDS).timeout
	if not is_inside_tree() or token != _interstitial_request_token:
		return
	if not _interstitial_loading or _interstitial_ready:
		return
	var plugin = _native_singleton(ADMOB_INTERSTITIAL_SINGLETON)
	if plugin != null and load_uid >= 0 and plugin.has_method("destroy"):
		plugin.destroy(load_uid)
	_interstitial_loading = false
	_interstitial_load_uid = -1
	_trace("AdsManager interstitial request timeout")


func _start_rewarded_request_timeout(token: int, load_uid: int) -> void:
	_rewarded_request_timeout_after_delay.call_deferred(token, load_uid)


func _rewarded_request_timeout_after_delay(token: int, load_uid: int) -> void:
	await get_tree().create_timer(REWARDED_REQUEST_TIMEOUT_SECONDS).timeout
	if not is_inside_tree() or token != _rewarded_request_token:
		return
	if not _rewarded_loading or _rewarded_ready:
		return
	var plugin = _native_singleton(ADMOB_REWARDED_SINGLETON)
	if plugin != null and load_uid >= 0 and plugin.has_method("destroy"):
		plugin.destroy(load_uid)
	_rewarded_loading = false
	_rewarded_load_uid = -1
	_trace("AdsManager rewarded request timeout")


func _warn_if_test_ids_are_still_enabled() -> void:
	if BANNER_ID == TEST_BANNER_ID:
		push_warning("AdsManager: banner ad unit is still using the Google test ID.")
	if INTERSTITIAL_ID == TEST_INTERSTITIAL_ID:
		push_warning("AdsManager: interstitial ad unit is still using the Google test ID.")
	if REWARDED_ID == TEST_REWARDED_ID:
		push_warning("AdsManager: rewarded ad unit is still using the Google test ID.")


func _initialize_iap_backend() -> void:
	_iap = null
	_iap_backend_name = ""
	_iap_uses_pending_events = false

	if Engine.has_singleton("IOSInAppPurchase"):
		_iap = Engine.get_singleton("IOSInAppPurchase")
		_iap_backend_name = "IOSInAppPurchase"
		if _iap.has_signal("response") and not _iap.is_connected("response", _on_ios_iap_response):
			_iap.connect("response", _on_ios_iap_response)
		_request_ios_iap("startUpdateTask", {})
		_request_ios_iap("proceedUnfinishedTransactions", {})
		_request_ios_iap("products", {"productIDs": [IAP_ID]})
		_request_ios_current_entitlements()
		print("AdsManager: purchase backend detected: %s" % _iap_backend_name)
	elif Engine.has_singleton("InAppStore"):
		_iap = Engine.get_singleton("InAppStore")
		_iap_backend_name = "InAppStore"
		_iap_uses_pending_events = true
		if _iap.has_method("set_auto_finish_transaction"):
			_iap.set_auto_finish_transaction(true)
		set_process(true)
		print("AdsManager: purchase backend detected: %s" % _iap_backend_name)
	elif Engine.has_singleton("InAppPurchase"):
		_iap = Engine.get_singleton("InAppPurchase")
		_iap_backend_name = "InAppPurchase"
		if not _iap.is_connected("purchase_completed", _on_purchase_completed):
			_iap.connect("purchase_completed", _on_purchase_completed)
		if not _iap.is_connected("restore_purchases_completed", _on_restore_completed):
			_iap.connect("restore_purchases_completed", _on_restore_completed)
		print("AdsManager: purchase backend detected: %s" % _iap_backend_name)
	else:
		print("AdsManager: no purchase backend configured yet for %s" % IAP_ID)


func _request_ios_iap(request_name: String, data: Dictionary) -> void:
	if not _iap or _iap_backend_name != "IOSInAppPurchase":
		return
	var result: int = _iap.request(request_name, data)
	if result != OK:
		push_warning("AdsManager: IOSInAppPurchase request '%s' failed to start: %s" % [request_name, result])


func _request_ios_current_entitlements() -> void:
	_request_ios_iap("transactionCurrentEntitlements", {})


func _process(_delta: float) -> void:
	if not _iap_uses_pending_events or not _iap:
		return
	if not _iap.has_method("get_pending_event_count") or not _iap.has_method("pop_pending_event"):
		return
	while _iap.get_pending_event_count() > 0:
		_handle_iap_pending_event(_iap.pop_pending_event())


func _handle_iap_pending_event(event: Variant) -> void:
	if typeof(event) != TYPE_DICTIONARY:
		return
	var product_id := str(event.get("product_id", ""))
	if product_id != IAP_ID:
		return
	var event_type := str(event.get("type", ""))
	var result := str(event.get("result", ""))
	if result == "ok" and (event_type == "purchase" or event_type == "restore"):
		_apply_remove_ads()
	elif event_type == "purchase" or event_type == "restore":
		push_warning("AdsManager: %s failed for %s" % [event_type, IAP_ID])


func _on_ios_iap_response(response_name: String, data: Dictionary) -> void:
	print("AdsManager: IOSInAppPurchase response %s: %s" % [response_name, data])
	match response_name:
		"purchase":
			if str(data.get("result", "")) == "success" and str(data.get("productID", "")) == IAP_ID:
				_apply_remove_ads()
				_request_ios_current_entitlements()
			elif str(data.get("productID", "")) == IAP_ID:
				push_warning("AdsManager: Remove Ads purchase did not complete successfully.")
		"purchasedProducts":
			_apply_remove_ads_if_ios_product_list_contains(data.get("productIDs", []))
		"transactionCurrentEntitlements":
			_apply_remove_ads_if_ios_transactions_contain(data.get("transactions", []))
		"appStoreSync", "proceedUnfinishedTransactions":
			_request_ios_current_entitlements()
		"products":
			_warn_if_ios_product_missing(data)


func _apply_remove_ads_if_ios_product_list_contains(product_ids: Variant) -> void:
	if typeof(product_ids) != TYPE_ARRAY:
		return
	for product_id in product_ids:
		if str(product_id) == IAP_ID:
			_apply_remove_ads()
			return


func _apply_remove_ads_if_ios_transactions_contain(transactions: Variant) -> void:
	if typeof(transactions) != TYPE_ARRAY:
		return
	for transaction in transactions:
		if typeof(transaction) == TYPE_DICTIONARY and str(transaction.get("productID", "")) == IAP_ID:
			_apply_remove_ads()
			return


func _warn_if_ios_product_missing(data: Dictionary) -> void:
	if str(data.get("result", "")) != "success":
		push_warning("AdsManager: Remove Ads product lookup failed in App Store.")
		return
	var products: Variant = data.get("products", [])
	if typeof(products) != TYPE_ARRAY:
		return
	for product in products:
		if typeof(product) == TYPE_DICTIONARY and str(product.get("id", "")) == IAP_ID:
			return
	push_warning("AdsManager: Remove Ads product ID was not returned by App Store: %s" % IAP_ID)


func _request_banners() -> void:
	_pending_banner_refresh = false
	_banner_request_token += 1
	var request_token := _banner_request_token
	_trace("AdsManager banner request start")
	if _banner_view_bottom:
		_banner_view_bottom.destroy()
		_banner_view_bottom = null
	if _banner_view_top:
		_banner_view_top.destroy()
		_banner_view_top = null
	_native_bottom_banner_loaded = false
	_native_top_banner_loaded = false

	if not (_banner_show_bottom or _banner_show_top):
		_notify_banner_dependent_ui()
		_trace("AdsManager banner request skipped no placements")
		return

	var ad_size = _resolve_banner_ad_size()
	if ad_size == null:
		_notify_banner_dependent_ui()
		_trace("AdsManager banner request fail no ad size")
		return
	if ad_size.width <= 0 or ad_size.height <= 0:
		ad_size = _fixed_banner_ad_size()
	if ad_size == null:
		_notify_banner_dependent_ui()
		_trace("AdsManager banner request fail no fallback ad size")
		return

	var ad_view_plugin = _native_singleton(ADMOB_AD_VIEW_SINGLETON)
	if ad_view_plugin == null:
		_notify_banner_dependent_ui()
		_trace("AdsManager banner request fail no native singleton")
		return

	if _banner_show_bottom:
		_trace("AdsManager bottom banner load start")
		_banner_view_bottom = NativeBannerView.new(ad_view_plugin, BANNER_ID, ad_size, AD_POSITION_BOTTOM)
		_banner_view_bottom.ad_listener = _banner_listener_bottom
		_banner_view_bottom.load_ad(_make_ad_request())
		_trace("AdsManager bottom banner load call returned")
	if _banner_show_top:
		_trace("AdsManager top banner load start")
		_banner_view_top = NativeBannerView.new(ad_view_plugin, BANNER_ID, ad_size, AD_POSITION_TOP)
		_banner_view_top.ad_listener = _banner_listener_top
		_banner_view_top.load_ad(_make_ad_request())
		_trace("AdsManager top banner load call returned")
	_notify_banner_dependent_ui()
	_start_banner_request_timeout(request_token)


func _make_ad_request():
	var ad_request = NativeAdRequest.new()
	ad_request.keywords = []
	ad_request.extras = {}
	return ad_request


func _destroy_interstitial() -> void:
	_interstitial_ready = false
	_interstitial_loading = false
	if _interstitial_ad:
		_interstitial_ad.destroy()
		_interstitial_ad = null


func _on_purchase_completed(product_id: String, _token: String) -> void:
	if product_id == IAP_ID:
		_apply_remove_ads()


func _on_restore_completed(purchases: Array) -> void:
	for purchase in purchases:
		if purchase.get("product_id") == IAP_ID:
			_apply_remove_ads()
			return


func _apply_remove_ads() -> void:
	MusicManager.ads_removed = true
	MusicManager.save_wardrobe()
	_ads_active = false
	hide_banner()
	_destroy_interstitial()
	_destroy_rewarded()
	emit_signal("ads_removed_changed")


func _fixed_banner_ad_size():
	return NativeAdSize.new(AD_SIZE_BANNER_WIDTH, AD_SIZE_BANNER_HEIGHT)


func _resolve_banner_ad_size():
	var platform := OS.get_name()
	if platform != "Android" and platform != "iOS":
		return _native_ad_size("getCurrentOrientationAnchoredAdaptiveBannerAdSize", AD_SIZE_FULL_WIDTH)

	var win := DisplayServer.window_get_size()
	if win.x < 1 or win.y < 1:
		return _native_ad_size("getCurrentOrientationAnchoredAdaptiveBannerAdSize", AD_SIZE_FULL_WIDTH)

	if win.y > win.x:
		return _native_ad_size("getCurrentOrientationAnchoredAdaptiveBannerAdSize", AD_SIZE_FULL_WIDTH)

	var dpi := DisplayServer.screen_get_dpi()
	if dpi < 96:
		dpi = 160
	var density: float = dpi / 160.0
	var span_dp: int = maxi(1, int(floor(float(win.x) / density)))
	var raw_narrow := int(round(float(span_dp) * LANDSCAPE_BANNER_WIDTH_FRAC))
	var lo := mini(LANDSCAPE_BANNER_MIN_DP, span_dp)
	var hi := mini(LANDSCAPE_BANNER_MAX_DP, span_dp)
	var narrowed_dp := clampi(raw_narrow, lo, hi)

	var ad_sz = _native_ad_size("getLandscapeAnchoredAdaptiveBannerAdSize", narrowed_dp)
	if ad_sz.width <= 0 or ad_sz.height <= 0:
		ad_sz = _native_ad_size("getLandscapeAnchoredAdaptiveBannerAdSize", AD_SIZE_FULL_WIDTH)
	if ad_sz.width <= 0 or ad_sz.height <= 0:
		ad_sz = _fixed_banner_ad_size()
	elif ad_sz.height > LANDSCAPE_ADAPTIVE_MAX_HEIGHT_DP:
		ad_sz = _fixed_banner_ad_size()
	return ad_sz


func _viewport_is_landscape_like() -> bool:
	var vp := get_viewport().get_visible_rect().size
	return vp.x >= vp.y


func _banner_placeholder_strip_height() -> float:
	var h := PLACEHOLDER_HEIGHT
	if _viewport_is_landscape_like():
		h *= PLACEHOLDER_HEIGHT_LANDSCAPE_SCALE
		return maxf(h, PLACEHOLDER_LANDSCAPE_MIN_STRIP_HEIGHT)
	return maxf(h, 36.0)


func _screen_to_viewport_scale_y() -> float:
	var window_size := DisplayServer.window_get_size()
	if window_size.y <= 0:
		return 1.0
	var viewport_size := get_viewport().get_visible_rect().size
	return viewport_size.y / float(window_size.y)


func _viewport_safe_insets() -> Vector4:
	var platform := OS.get_name()
	if platform != "iOS" and platform != "Android":
		return Vector4.ZERO

	var window_size := DisplayServer.window_get_size()
	if window_size.x <= 0 or window_size.y <= 0:
		return Vector4.ZERO

	var safe_area := DisplayServer.get_display_safe_area()
	var viewport_size := get_viewport().get_visible_rect().size
	var scale_x := viewport_size.x / float(window_size.x)
	var scale_y := viewport_size.y / float(window_size.y)
	var left := float(safe_area.position.x) * scale_x
	var top := float(safe_area.position.y) * scale_y
	var right := float(window_size.x - (safe_area.position.x + safe_area.size.x)) * scale_x
	var bottom := float(window_size.y - (safe_area.position.y + safe_area.size.y)) * scale_y
	return Vector4(left, top, right, bottom)


func _native_banner_height_in_viewport(banner_view) -> float:
	if banner_view:
		var px: int = banner_view.get_height_in_pixels()
		if px > 0:
			return float(px) * _screen_to_viewport_scale_y()
	return _banner_placeholder_strip_height()


func _top_banner_reserved_height() -> float:
	var ad_height := _banner_placeholder_strip_height()
	if _native_top_banner_loaded:
		ad_height = maxf(ad_height, _native_banner_height_in_viewport(_banner_view_top))
	return ad_height + _viewport_safe_insets().y


func _bottom_banner_reserved_height() -> float:
	var ad_height := _banner_placeholder_strip_height()
	if _native_bottom_banner_loaded:
		ad_height = maxf(ad_height, _native_banner_height_in_viewport(_banner_view_bottom))
	return ad_height + _viewport_safe_insets().w


func _apply_placeholder_layout() -> void:
	if not _top_placeholder:
		return
	var top_strip := _top_banner_reserved_height()
	var bottom_strip := _bottom_banner_reserved_height()
	_top_backing.offset_left = 0.0
	_top_backing.offset_right = 0.0
	_top_backing.offset_top = 0.0
	_top_backing.offset_bottom = top_strip

	_bottom_backing.offset_left = 0.0
	_bottom_backing.offset_right = 0.0
	_bottom_backing.offset_top = -bottom_strip
	_bottom_backing.offset_bottom = 0.0

	_top_placeholder.offset_left = 0.0
	_top_placeholder.offset_right = 0.0
	_top_placeholder.offset_top = 0.0
	_top_placeholder.offset_bottom = top_strip

	_bottom_placeholder.offset_left = 0.0
	_bottom_placeholder.offset_right = 0.0
	_bottom_placeholder.offset_top = -bottom_strip
	_bottom_placeholder.offset_bottom = 0.0


func _setup_placeholder_ui() -> void:
	if _placeholder_layer:
		return

	_placeholder_layer = CanvasLayer.new()
	_placeholder_layer.layer = BANNER_PLACEHOLDER_CANVAS_LAYER
	add_child(_placeholder_layer)

	_placeholder_root = Control.new()
	_placeholder_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_placeholder_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_placeholder_layer.add_child(_placeholder_root)

	_top_backing = _build_banner_backing("TopBannerBacking")
	_top_backing.anchor_left = 0.0
	_top_backing.anchor_top = 0.0
	_top_backing.anchor_right = 1.0
	_top_backing.anchor_bottom = 0.0
	_placeholder_root.add_child(_top_backing)

	_bottom_backing = _build_banner_backing("BottomBannerBacking")
	_bottom_backing.anchor_left = 0.0
	_bottom_backing.anchor_top = 1.0
	_bottom_backing.anchor_right = 1.0
	_bottom_backing.anchor_bottom = 1.0
	_placeholder_root.add_child(_bottom_backing)

	_top_placeholder = _build_placeholder_slot("TopBannerPlaceholder", "Banner Ad")
	_top_placeholder.anchor_left = 0.0
	_top_placeholder.anchor_top = 0.0
	_top_placeholder.anchor_right = 1.0
	_top_placeholder.anchor_bottom = 0.0
	_placeholder_root.add_child(_top_placeholder)

	_bottom_placeholder = _build_placeholder_slot("BottomBannerPlaceholder", "Banner Ad")
	_bottom_placeholder.anchor_left = 0.0
	_bottom_placeholder.anchor_top = 1.0
	_bottom_placeholder.anchor_right = 1.0
	_bottom_placeholder.anchor_bottom = 1.0
	_placeholder_root.add_child(_bottom_placeholder)

	_apply_placeholder_layout()
	_hide_placeholders()


func _build_banner_backing(node_name: String) -> ColorRect:
	var backing := ColorRect.new()
	backing.name = node_name
	backing.color = BANNER_BACKING_COLOR
	backing.visible = false
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return backing


func _build_placeholder_slot(node_name: String, label_text: String) -> Control:
	var slot := MarginContainer.new()
	slot.name = node_name
	slot.visible = false
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.11, 0.09, 0.78)
	style.border_color = Color(0.65, 0.89, 0.46, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_right = 0
	style.corner_radius_bottom_left = 0
	panel.add_theme_stylebox_override("panel", style)
	slot.add_child(panel)

	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_color_override("font_color", Color(0.92, 0.98, 0.88, 0.95))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.6))
	label.add_theme_constant_override("outline_size", 3)
	panel.add_child(label)

	return slot


func _refresh_placeholder_visibility() -> void:
	if not _placeholder_root:
		return
	_apply_placeholder_layout()
	if _top_backing:
		_top_backing.visible = _should_show_top_banner_backing()
	if _bottom_backing:
		_bottom_backing.visible = _should_show_bottom_banner_backing()
	if _top_placeholder:
		_top_placeholder.visible = _ads_active and _banner_show_top and _should_show_top_banner_placeholder()
	if _bottom_placeholder:
		_bottom_placeholder.visible = _ads_active and _banner_show_bottom and _should_show_bottom_banner_placeholder()


func _hide_placeholders() -> void:
	if _top_backing:
		_top_backing.visible = false
	if _bottom_backing:
		_bottom_backing.visible = false
	if _top_placeholder:
		_top_placeholder.visible = false
	if _bottom_placeholder:
		_bottom_placeholder.visible = false
