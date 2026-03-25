extends Node

const BANNER_ID          := "ca-app-pub-3776793413956253/3241038986"
const INTERSTITIAL_ID    := "ca-app-pub-3776793413956253/1504317887"
const IAP_ID             := "com.muse.frogquest.removeads"
const SECRET_CODE        := "3125"
const INTERSTITIAL_EVERY := 3

var _admob        # AdMob plugin singleton (nil when plugin absent)
var _iap          # InAppPurchase singleton (nil when plugin absent)
var _gameover_count := 0
var _ads_active: bool = false
var _interstitial_ready: bool = false

signal ads_removed_changed

func _ready() -> void:
	# Ads only active from the 2nd launch onwards, and only if not already removed
	_ads_active = MusicManager.has_launched_before and not MusicManager.ads_removed

	if Engine.has_singleton("AdMob"):
		_admob = Engine.get_singleton("AdMob")
		_admob.initialize()
		_admob.connect("interstitial_closed",  _on_interstitial_closed)
		_admob.connect("interstitial_loaded",  _on_interstitial_loaded)
		_admob.connect("interstitial_failed_to_load", _on_interstitial_failed)

	if Engine.has_singleton("InAppPurchase"):
		_iap = Engine.get_singleton("InAppPurchase")
		_iap.connect("purchase_completed",           _on_purchase_completed)
		_iap.connect("restore_purchases_completed",  _on_restore_completed)

# ── Banner ───────────────────────────────────────────────────────────────────

func show_banner_bottom() -> void:
	if not _ads_active or not _admob:
		return
	_admob.load_banner(BANNER_ID, true, _admob.BANNER_SIZE_BANNER, _admob.BANNER_POSITION_BOTTOM)

func show_banner_top() -> void:
	if not _ads_active or not _admob:
		return
	_admob.load_banner(BANNER_ID, true, _admob.BANNER_SIZE_BANNER, _admob.BANNER_POSITION_TOP)

func hide_banner() -> void:
	if not _admob:
		return
	_admob.destroy_banner()

# ── Interstitial ─────────────────────────────────────────────────────────────

func preload_interstitial() -> void:
	if not _ads_active or not _admob:
		return
	_admob.load_interstitial(INTERSTITIAL_ID)

func on_game_over() -> void:
	_gameover_count += 1
	if _ads_active and _admob and _interstitial_ready and (_gameover_count % INTERSTITIAL_EVERY == 0):
		_interstitial_ready = false
		_admob.show_interstitial()

func _on_interstitial_loaded() -> void:
	_interstitial_ready = true

func _on_interstitial_failed(_error_code) -> void:
	_interstitial_ready = false

func _on_interstitial_closed() -> void:
	_interstitial_ready = false
	preload_interstitial()

# ── Secret code ───────────────────────────────────────────────────────────────

func try_code(input: String) -> bool:
	if input.strip_edges() == SECRET_CODE:
		_apply_remove_ads()
		return true
	return false

# ── IAP ──────────────────────────────────────────────────────────────────────

func purchase_remove_ads() -> void:
	if not _iap:
		return
	_iap.purchase({"product_id": IAP_ID})

func restore_purchases() -> void:
	if not _iap:
		return
	_iap.restore_purchases()

func _on_purchase_completed(product_id: String, _token: String) -> void:
	if product_id == IAP_ID:
		_apply_remove_ads()

func _on_restore_completed(purchases: Array) -> void:
	for p in purchases:
		if p.get("product_id") == IAP_ID:
			_apply_remove_ads()
			return

func _apply_remove_ads() -> void:
	MusicManager.ads_removed = true
	MusicManager.save_wardrobe()
	_ads_active = false
	hide_banner()
	emit_signal("ads_removed_changed")
