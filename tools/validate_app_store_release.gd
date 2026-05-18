extends SceneTree

const SAMPLE_ADMOB_APP_ID := "ca-app-pub-3940256099942544~1458002511"
const SAMPLE_BANNER_ID := "ca-app-pub-3940256099942544/2934735716"
const SAMPLE_INTERSTITIAL_ID := "ca-app-pub-3940256099942544/4411468910"
const EXPECTED_BUNDLE_ID := "com.muse.frogquest"
const EXPECTED_IAP_ID := "com.muse.frogquest.removeads"


func _initialize() -> void:
	var failed := false
	failed = _check_project_settings() or failed
	failed = _check_export_preset() or failed
	failed = _check_ads_manager() or failed
	failed = _check_legal_docs() or failed

	if failed:
		push_error("App Store release validation failed. Fix the blocker(s) above before uploading.")
	else:
		print("App Store release validation passed.")
	quit(1 if failed else 0)


func _check_project_settings() -> bool:
	var failed := false
	var cfg := ConfigFile.new()
	var err := cfg.load("res://project.godot")
	if err != OK:
		_blocker("Could not read project.godot.")
		return true

	_expect_equal(cfg.get_value("application", "run/main_scene", ""), "res://scenes/BootLoader.tscn", "project main scene", true)
	if cfg.get_value("application", "run/main_scene", "") != "res://scenes/BootLoader.tscn":
		failed = true

	for autoload_name in ["AdsManager", "ComplianceConfig"]:
		var value := str(cfg.get_value("autoload", autoload_name, ""))
		if value.is_empty():
			_blocker("Missing autoload: %s." % autoload_name)
			failed = true

	return failed


func _check_export_preset() -> bool:
	var failed := false
	var cfg := ConfigFile.new()
	var err := cfg.load("res://export_presets.cfg")
	if err != OK:
		_blocker("Could not read export_presets.cfg.")
		return true

	if str(cfg.get_value("preset.0", "platform", "")) != "iOS":
		_blocker("First export preset is not iOS.")
		failed = true

	var options := "preset.0.options"
	var bundle_id := str(cfg.get_value(options, "application/bundle_identifier", ""))
	if bundle_id != EXPECTED_BUNDLE_ID:
		_blocker("Bundle identifier is '%s'; expected '%s'." % [bundle_id, EXPECTED_BUNDLE_ID])
		failed = true

	for key in ["application/short_version", "application/version"]:
		if str(cfg.get_value(options, key, "")).strip_edges().is_empty():
			_blocker("iOS export preset is missing %s." % key)
			failed = true

	var admob_app_id := str(cfg.get_value(options, "plugins_plist/GADApplicationIdentifier", ""))
	if admob_app_id.is_empty() or admob_app_id == SAMPLE_ADMOB_APP_ID:
		_blocker("iOS GADApplicationIdentifier is still blank or using Google's sample AdMob app ID.")
		failed = true

	var plist := str(cfg.get_value(options, "application/additional_plist_content", ""))
	if not plist.contains("NSUserTrackingUsageDescription"):
		_blocker("iOS export preset is missing NSUserTrackingUsageDescription.")
		failed = true

	if str(cfg.get_value(options, "privacy/collected_data/advertising_data/collected", "false")) != "true":
		_warn("Godot export privacy currently says advertising data is not collected. Recheck this against AdMob before upload.")
	if str(cfg.get_value(options, "privacy/collected_data/device_id/collected", "false")) != "true":
		_warn("Godot export privacy currently says device ID is not collected. Recheck this against AdMob before upload.")

	return failed


func _check_ads_manager() -> bool:
	var failed := false
	var text := _read_text("res://scripts/AdsManager.gd")
	if text.is_empty():
		_blocker("Could not read scripts/AdsManager.gd.")
		return true

	var banner_id := _read_const(text, "BANNER_ID")
	if banner_id.is_empty() or banner_id == SAMPLE_BANNER_ID:
		_blocker("BANNER_ID is still blank or using Google's sample banner ad unit.")
		failed = true

	var interstitial_id := _read_const(text, "INTERSTITIAL_ID")
	if interstitial_id.is_empty() or interstitial_id == SAMPLE_INTERSTITIAL_ID:
		_blocker("INTERSTITIAL_ID is still blank or using Google's sample interstitial ad unit.")
		failed = true

	var iap_id := _read_const(text, "IAP_ID")
	if iap_id != EXPECTED_IAP_ID:
		_blocker("IAP_ID is '%s'; expected '%s'." % [iap_id, EXPECTED_IAP_ID])
		failed = true

	if not text.contains("Engine.has_singleton(\"InAppStore\")") and not text.contains("Engine.has_singleton(\"InAppPurchase\")"):
		_blocker("AdsManager has no detectable iOS purchase backend check.")
		failed = true

	return failed


func _check_legal_docs() -> bool:
	var failed := false
	for path in ["res://legal/privacy_policy.txt", "res://legal/terms_of_use.txt"]:
		var text := _read_text(path)
		if text.strip_edges().length() < 300:
			_blocker("Missing or too-short legal document: %s." % path)
			failed = true

	var compliance := _read_text("res://scripts/ComplianceConfig.gd")
	if not compliance.contains("APP_STORE_PRIVACY_POLICY_URL"):
		_blocker("ComplianceConfig is missing APP_STORE_PRIVACY_POLICY_URL.")
		failed = true
	elif compliance.contains("const APP_STORE_PRIVACY_POLICY_URL := \"\""):
		_warn("APP_STORE_PRIVACY_POLICY_URL is blank. App Store Connect still needs your hosted HTTPS privacy policy URL.")

	return failed


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _read_const(text: String, const_name: String) -> String:
	var prefix := "const %s := " % const_name
	for line in text.split("\n"):
		var trimmed := line.strip_edges()
		if not trimmed.begins_with(prefix):
			continue
		var value := trimmed.trim_prefix(prefix).strip_edges()
		if value.begins_with("\"") and value.ends_with("\""):
			return value.substr(1, value.length() - 2)
		return value
	return ""


func _expect_equal(actual: Variant, expected: Variant, label: String, required: bool) -> void:
	if actual == expected:
		print("OK: %s = %s" % [label, str(expected)])
	elif required:
		_blocker("%s is '%s'; expected '%s'." % [label, str(actual), str(expected)])
	else:
		_warn("%s is '%s'; expected '%s'." % [label, str(actual), str(expected)])


func _blocker(message: String) -> void:
	push_error("BLOCKER: %s" % message)


func _warn(message: String) -> void:
	push_warning("WARN: %s" % message)
