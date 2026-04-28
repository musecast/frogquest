extends Node

const BANNER_ID := "ca-app-pub-3940256099942544/2934735716"
const INTERSTITIAL_ID := "ca-app-pub-3940256099942544/4411468910"
const IAP_ID := "com.muse.frogquest.removeads"
const SECRET_CODE := "3125"
const INTERSTITIAL_EVERY := 3
const TEST_BANNER_ID := "ca-app-pub-3940256099942544/2934735716"
const TEST_INTERSTITIAL_ID := "ca-app-pub-3940256099942544/4411468910"

const PLACEHOLDER_HEIGHT := 58.0
const PLACEHOLDER_SIDE_MARGIN := 12
const PLACEHOLDER_EDGE_MARGIN := 8

var _iap
var _iap_backend_name := ""
var _gameover_count := 0
var _ads_active := false
var _mobile_ads_ready := false
var _banner_position := AdPosition.Values.BOTTOM
var _banner_view: AdView
var _banner_listener := AdListener.new()
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


func _ready() -> void:
	_ads_active = not MusicManager.ads_removed
	_configure_banner_callbacks()
	_configure_interstitial_callbacks()
	_setup_placeholder_ui()
	_initialize_iap_backend()
	_start_mobile_ads_flow()


func show_banner_bottom() -> void:
	if not _ads_active:
		hide_banner()
		return
	_banner_position = AdPosition.Values.BOTTOM
	_show_placeholder(_banner_position)
	if not _mobile_ads_ready:
		_pending_banner_refresh = true
		return
	_request_banner()


func show_banner_top() -> void:
	if not _ads_active:
		hide_banner()
		return
	_banner_position = AdPosition.Values.TOP
	_show_placeholder(_banner_position)
	if not _mobile_ads_ready:
		_pending_banner_refresh = true
		return
	_request_banner()


func hide_banner() -> void:
	_pending_banner_refresh = false
	_hide_placeholders()
	if _banner_view:
		_banner_view.destroy()
		_banner_view = null


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
	_banner_listener.on_ad_loaded = func() -> void:
		if _banner_view:
			_banner_view.show()
		print("AdsManager: banner loaded")
	_banner_listener.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		print("AdsManager: banner failed to load: %s" % error.message)
	_banner_listener.on_ad_impression = func() -> void:
		print("AdsManager: banner impression recorded")
	_banner_listener.on_ad_opened = func() -> void:
		print("AdsManager: banner opened")
	_banner_listener.on_ad_closed = func() -> void:
		print("AdsManager: banner closed")


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

	MobileAds.set_request_configuration(request_config)
	MobileAds.initialize(on_init_listener)


func _on_mobile_ads_initialized(_status: InitializationStatus) -> void:
	_mobile_ads_ready = true
	print("AdsManager: MobileAds initialized")
	if _pending_banner_refresh and _ads_active:
		_request_banner()
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

	if Engine.has_singleton("InAppPurchase"):
		_iap = Engine.get_singleton("InAppPurchase")
		_iap_backend_name = "InAppPurchase"
		if not _iap.is_connected("purchase_completed", _on_purchase_completed):
			_iap.connect("purchase_completed", _on_purchase_completed)
		if not _iap.is_connected("restore_purchases_completed", _on_restore_completed):
			_iap.connect("restore_purchases_completed", _on_restore_completed)
		print("AdsManager: purchase backend detected: %s" % _iap_backend_name)
	else:
		print("AdsManager: no purchase backend configured yet for %s" % IAP_ID)


func _request_banner() -> void:
	_pending_banner_refresh = false
	if _banner_view:
		_banner_view.destroy()
		_banner_view = null

	var ad_size := AdSize.get_current_orientation_anchored_adaptive_banner_ad_size(AdSize.FULL_WIDTH)
	if ad_size.width <= 0 or ad_size.height <= 0:
		ad_size = AdSize.BANNER

	_banner_view = AdView.new(BANNER_ID, ad_size, _banner_position)
	_banner_view.ad_listener = _banner_listener
	_banner_view.load_ad(_make_ad_request())


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


func _setup_placeholder_ui() -> void:
	if _placeholder_layer:
		return

	_placeholder_layer = CanvasLayer.new()
	_placeholder_layer.layer = 50
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
	_top_placeholder.offset_left = PLACEHOLDER_SIDE_MARGIN
	_top_placeholder.offset_top = PLACEHOLDER_EDGE_MARGIN
	_top_placeholder.offset_right = -PLACEHOLDER_SIDE_MARGIN
	_top_placeholder.offset_bottom = PLACEHOLDER_EDGE_MARGIN + PLACEHOLDER_HEIGHT
	_placeholder_root.add_child(_top_placeholder)

	_bottom_placeholder = _build_placeholder_slot("BottomBannerPlaceholder", "Banner Ad")
	_bottom_placeholder.anchor_left = 0.0
	_bottom_placeholder.anchor_top = 1.0
	_bottom_placeholder.anchor_right = 1.0
	_bottom_placeholder.anchor_bottom = 1.0
	_bottom_placeholder.offset_left = PLACEHOLDER_SIDE_MARGIN
	_bottom_placeholder.offset_top = -(PLACEHOLDER_EDGE_MARGIN + PLACEHOLDER_HEIGHT)
	_bottom_placeholder.offset_right = -PLACEHOLDER_SIDE_MARGIN
	_bottom_placeholder.offset_bottom = -PLACEHOLDER_EDGE_MARGIN
	_placeholder_root.add_child(_bottom_placeholder)

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
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
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


func _show_placeholder(position: int) -> void:
	if not _placeholder_root:
		return
	_top_placeholder.visible = position == AdPosition.Values.TOP
	_bottom_placeholder.visible = position == AdPosition.Values.BOTTOM


func _hide_placeholders() -> void:
	if _top_placeholder:
		_top_placeholder.visible = false
	if _bottom_placeholder:
		_bottom_placeholder.visible = false
