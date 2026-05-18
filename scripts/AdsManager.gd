extends Node

const BANNER_ID := "ca-app-pub-3776793413956253/3241038986"
const INTERSTITIAL_ID := "ca-app-pub-3776793413956253/1504317887"
const IAP_ID := "com.muse.frogquest.removeads"
const SECRET_CODE := "3125"
const INTERSTITIAL_EVERY := 3
const TEST_BANNER_ID := "ca-app-pub-3940256099942544/2934735716"
const TEST_INTERSTITIAL_ID := "ca-app-pub-3940256099942544/4411468910"

const PLACEHOLDER_HEIGHT := 58.0
const PLACEHOLDER_HEIGHT_LANDSCAPE_SCALE := 0.42
const PLACEHOLDER_LANDSCAPE_MIN_STRIP_HEIGHT := 22.0

# In landscape, request a narrow adaptive width (shorter banners). If adaptive is still tall, we
# fall back to standard Banner (320x50 dp)—see _resolve_banner_ad_size().
const LANDSCAPE_BANNER_WIDTH_FRAC := 0.34
const LANDSCAPE_BANNER_MAX_DP := 300
const LANDSCAPE_BANNER_MIN_DP := 260
const LANDSCAPE_ADAPTIVE_MAX_HEIGHT_DP := 54

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
var _banner_view_bottom: AdView
var _banner_view_top: AdView
var _banner_listener_bottom := AdListener.new()
var _banner_listener_top := AdListener.new()
var _interstitial_ready := false
var _interstitial_loading := false
var _interstitial_ad: InterstitialAd
var _interstitial_load_callback := InterstitialAdLoadCallback.new()
var _interstitial_content_callback := FullScreenContentCallback.new()
var _pending_banner_refresh := false
var _pending_interstitial_preload := false

var _placeholder_layer: CanvasLayer
var _placeholder_root: Control
var _top_placeholder: Control
var _bottom_placeholder: Control

signal ads_removed_changed


## Layer for title / HUD that must draw above the in-engine banner placeholder.
func canvas_layer_above_banner_placeholder() -> int:
	return BANNER_PLACEHOLDER_CANVAS_LAYER + 8


## Viewport pixels to leave clear above the bottom edge when a bottom banner is active.
func get_viewport_bottom_banner_clearance() -> float:
	if not _ads_active or not _banner_show_bottom:
		return 0.0
	return _banner_placeholder_strip_height() + 6.0


## Viewport pixels to reserve below the top edge when a top banner is active (e.g. game over dual ads).
func get_viewport_top_banner_clearance() -> float:
	if not _ads_active or not _banner_show_top:
		return 0.0
	return _banner_placeholder_strip_height() + 6.0


func _wants_banner() -> bool:
	return _banner_show_bottom or _banner_show_top


func _notify_banner_dependent_ui() -> void:
	if not is_inside_tree():
		return
	get_tree().call_group_flags(
		SceneTree.GROUP_CALL_DEFERRED,
		&"banner_reserve_ui",
		&"_apply_ui_layout",
	)


func _ready() -> void:
	_ads_active = not MusicManager.ads_removed
	_configure_banner_callbacks()
	_configure_interstitial_callbacks()
	_setup_placeholder_ui()
	_initialize_iap_backend()
	_start_mobile_ads_flow()
	if not Engine.is_editor_hint():
		get_viewport().size_changed.connect(_on_viewport_for_banner_resize)


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
	_notify_banner_dependent_ui()


func _banner_refresh_flow() -> void:
	if not _ads_active:
		return
	_refresh_placeholder_visibility()
	if not _mobile_ads_ready:
		_pending_banner_refresh = true
		_notify_banner_dependent_ui()
		return
	_request_banners()


## Recompute placeholder layout and reload the banner for the current window size/orientation
## (narrower landscape width, etc.). Use when a scene changes display scale or orientation.
func sync_banner_with_viewport() -> void:
	if not _ads_active:
		return
	if not _wants_banner():
		return
	_refresh_placeholder_visibility()
	if _mobile_ads_ready:
		_request_banners()
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
		return

	_interstitial_loading = true
	_pending_interstitial_preload = false
	InterstitialAdLoader.new().load(INTERSTITIAL_ID, _make_ad_request(), _interstitial_load_callback)


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


func try_code(input: String) -> bool:
	if input.strip_edges() == SECRET_CODE:
		_apply_remove_ads()
		return true
	return false


func purchase_remove_ads() -> void:
	if not _iap:
		push_warning("Remove Ads purchase requested, but no purchase backend is configured yet.")
		return
	_iap.purchase({"product_id": IAP_ID})


func restore_purchases() -> void:
	if not _iap:
		push_warning("Restore purchases requested, but no purchase backend is configured yet.")
		return
	_iap.restore_purchases()


func has_purchase_backend() -> bool:
	return _iap != null


func get_purchase_backend_name() -> String:
	return _iap_backend_name


func get_remove_ads_product_id() -> String:
	return IAP_ID


func _configure_banner_callbacks() -> void:
	_banner_listener_bottom.on_ad_loaded = func() -> void:
		if _banner_view_bottom:
			_banner_view_bottom.show()
		print("AdsManager: bottom banner loaded")
	_banner_listener_bottom.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		print("AdsManager: bottom banner failed to load: %s" % error.message)
	_banner_listener_bottom.on_ad_impression = func() -> void:
		print("AdsManager: bottom banner impression recorded")
	_banner_listener_bottom.on_ad_opened = func() -> void:
		print("AdsManager: bottom banner opened")
	_banner_listener_bottom.on_ad_closed = func() -> void:
		print("AdsManager: bottom banner closed")

	_banner_listener_top.on_ad_loaded = func() -> void:
		if _banner_view_top:
			_banner_view_top.show()
		print("AdsManager: top banner loaded")
	_banner_listener_top.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		print("AdsManager: top banner failed to load: %s" % error.message)
	_banner_listener_top.on_ad_impression = func() -> void:
		print("AdsManager: top banner impression recorded")
	_banner_listener_top.on_ad_opened = func() -> void:
		print("AdsManager: top banner opened")
	_banner_listener_top.on_ad_closed = func() -> void:
		print("AdsManager: top banner closed")


func _configure_interstitial_callbacks() -> void:
	_interstitial_load_callback.on_ad_loaded = func(ad: InterstitialAd) -> void:
		_interstitial_loading = false
		_interstitial_ready = true
		if _interstitial_ad:
			_interstitial_ad.destroy()
		ad.full_screen_content_callback = _interstitial_content_callback
		_interstitial_ad = ad
		print("AdsManager: interstitial loaded")
	_interstitial_load_callback.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		_interstitial_loading = false
		_interstitial_ready = false
		print("AdsManager: interstitial failed to load: %s" % error.message)

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
	_interstitial_content_callback.on_ad_failed_to_show_full_screen_content = func(error: AdError) -> void:
		print("AdsManager: interstitial failed to show: %s" % error.message)
		_destroy_interstitial()
		preload_interstitial()


func _start_mobile_ads_flow() -> void:
	if not Engine.has_singleton("PoingGodotAdMob"):
		print("AdsManager: mobile ad singleton not available, showing placeholders only.")
		return
	_warn_if_test_ids_are_still_enabled()
	if Engine.has_singleton("PoingGodotAdMobConsentInformation") and Engine.has_singleton("PoingGodotAdMobUserMessagingPlatform"):
		_request_ad_consent()
		return
	_initialize_mobile_ads()


func _request_ad_consent() -> void:
	var request := ConsentRequestParameters.new()
	# IAB TCF / Google UMP: false for typical general‑audience games; set true if you target minors.
	request.tag_for_under_age_of_consent = false
	request.consent_debug_settings = null
	UserMessagingPlatform.consent_information.update(
		request,
		_on_consent_update_success,
		_on_consent_update_failure
	)


func _on_consent_update_success() -> void:
	if UserMessagingPlatform.consent_information.get_is_consent_form_available():
		UserMessagingPlatform.load_consent_form(_on_consent_form_loaded, _on_consent_update_failure)
		return
	_initialize_mobile_ads()


func _on_consent_form_loaded(form: ConsentForm) -> void:
	var status := UserMessagingPlatform.consent_information.get_consent_status()
	if status == ConsentInformation.ConsentStatus.REQUIRED:
		form.show(_on_consent_form_dismissed)
		return
	_initialize_mobile_ads()


func _on_consent_form_dismissed(error: FormError) -> void:
	if error:
		print("AdsManager: consent form dismissed with error: %s" % error.message)
	_initialize_mobile_ads()


func _on_consent_update_failure(error: FormError) -> void:
	print("AdsManager: consent update failed: %s" % error.message)
	_initialize_mobile_ads()


func _initialize_mobile_ads() -> void:
	if _mobile_ads_ready:
		return
	var on_init_listener := OnInitializationCompleteListener.new()
	on_init_listener.on_initialization_complete = _on_mobile_ads_initialized

	var request_config := RequestConfiguration.new()
	request_config.max_ad_content_rating = RequestConfiguration.MAX_AD_CONTENT_RATING_G
	request_config.test_device_ids = []
	request_config.tag_for_child_directed_treatment = RequestConfiguration.TagForChildDirectedTreatment.FALSE
	request_config.tag_for_under_age_of_consent = RequestConfiguration.TagForUnderAgeOfConsent.FALSE

	MobileAds.set_request_configuration(request_config)
	MobileAds.initialize(on_init_listener)


func _on_mobile_ads_initialized(_status: InitializationStatus) -> void:
	_mobile_ads_ready = true
	print("AdsManager: MobileAds initialized")
	if _pending_banner_refresh and _ads_active:
		_request_banners()
	if _pending_interstitial_preload and _ads_active:
		preload_interstitial()


func _warn_if_test_ids_are_still_enabled() -> void:
	if BANNER_ID == TEST_BANNER_ID:
		push_warning("AdsManager: banner ad unit is still using the Google test ID.")
	if INTERSTITIAL_ID == TEST_INTERSTITIAL_ID:
		push_warning("AdsManager: interstitial ad unit is still using the Google test ID.")


func _initialize_iap_backend() -> void:
	_iap = null
	_iap_backend_name = ""
	_iap_uses_pending_events = false

	if Engine.has_singleton("InAppStore"):
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


func _request_banners() -> void:
	_pending_banner_refresh = false
	if _banner_view_bottom:
		_banner_view_bottom.destroy()
		_banner_view_bottom = null
	if _banner_view_top:
		_banner_view_top.destroy()
		_banner_view_top = null

	if not (_banner_show_bottom or _banner_show_top):
		_notify_banner_dependent_ui()
		return

	var ad_size := _resolve_banner_ad_size()
	if ad_size.width <= 0 or ad_size.height <= 0:
		ad_size = AdSize.BANNER

	if _banner_show_bottom:
		_banner_view_bottom = AdView.new(BANNER_ID, ad_size, AdPosition.Values.BOTTOM)
		_banner_view_bottom.ad_listener = _banner_listener_bottom
		_banner_view_bottom.load_ad(_make_ad_request())
	if _banner_show_top:
		_banner_view_top = AdView.new(BANNER_ID, ad_size, AdPosition.Values.TOP)
		_banner_view_top.ad_listener = _banner_listener_top
		_banner_view_top.load_ad(_make_ad_request())
	_notify_banner_dependent_ui()


func _make_ad_request() -> AdRequest:
	var ad_request := AdRequest.new()
	ad_request.keywords = []
	ad_request.mediation_extras = []
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
	emit_signal("ads_removed_changed")


func _resolve_banner_ad_size() -> AdSize:
	var platform := OS.get_name()
	if platform != "Android" and platform != "iOS":
		return AdSize.get_current_orientation_anchored_adaptive_banner_ad_size(AdSize.FULL_WIDTH)

	var win := DisplayServer.window_get_size()
	if win.x < 1 or win.y < 1:
		return AdSize.get_current_orientation_anchored_adaptive_banner_ad_size(AdSize.FULL_WIDTH)

	if win.y > win.x:
		return AdSize.get_current_orientation_anchored_adaptive_banner_ad_size(AdSize.FULL_WIDTH)

	var dpi := DisplayServer.screen_get_dpi()
	if dpi < 96:
		dpi = 160
	var density: float = dpi / 160.0
	var span_dp: int = maxi(1, int(floor(float(win.x) / density)))
	var raw_narrow := int(round(float(span_dp) * LANDSCAPE_BANNER_WIDTH_FRAC))
	var lo := mini(LANDSCAPE_BANNER_MIN_DP, span_dp)
	var hi := mini(LANDSCAPE_BANNER_MAX_DP, span_dp)
	var narrowed_dp := clampi(raw_narrow, lo, hi)

	var ad_sz := AdSize.get_landscape_anchored_adaptive_banner_ad_size(narrowed_dp)
	if ad_sz.width <= 0 or ad_sz.height <= 0:
		ad_sz = AdSize.get_landscape_anchored_adaptive_banner_ad_size(AdSize.FULL_WIDTH)
	if ad_sz.width <= 0 or ad_sz.height <= 0:
		ad_sz = AdSize.BANNER
	elif ad_sz.height > LANDSCAPE_ADAPTIVE_MAX_HEIGHT_DP:
		ad_sz = AdSize.BANNER
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


func _apply_placeholder_layout() -> void:
	if not _top_placeholder:
		return
	var h_strip := _banner_placeholder_strip_height()
	_top_placeholder.offset_left = 0.0
	_top_placeholder.offset_right = 0.0
	_top_placeholder.offset_top = 0.0
	_top_placeholder.offset_bottom = h_strip

	_bottom_placeholder.offset_left = 0.0
	_bottom_placeholder.offset_right = 0.0
	_bottom_placeholder.offset_top = -h_strip
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
	if _top_placeholder:
		_top_placeholder.visible = _ads_active and _banner_show_top
	if _bottom_placeholder:
		_bottom_placeholder.visible = _ads_active and _banner_show_bottom


func _hide_placeholders() -> void:
	if _top_placeholder:
		_top_placeholder.visible = false
	if _bottom_placeholder:
		_bottom_placeholder.visible = false
