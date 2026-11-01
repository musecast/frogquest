extends SceneTree

const SAMPLE_ADMOB_APP_ID := "ca-app-pub-3940256099942544~1458002511"
const SAMPLE_BANNER_ID := "ca-app-pub-3940256099942544/2934735716"
const SAMPLE_INTERSTITIAL_ID := "ca-app-pub-3940256099942544/4411468910"
const SAMPLE_REWARDED_ID := "ca-app-pub-3940256099942544/1712485313"
const EXPECTED_BUNDLE_ID := "com.muse.frogquest"
const EXPECTED_IAP_ID := "com.muse.frogquest.removeads"


func _initialize() -> void:
	var failed := false
	failed = _check_project_settings() or failed
	failed = _check_export_preset() or failed
	failed = _check_ads_manager() or failed
	failed = _check_admob_ios_exporter() or failed
	failed = _check_legal_docs() or failed
	failed = _check_no_direct_import_cache_references() or failed
	failed = _check_startup_lightweight_project_scripts() or failed

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

	if bool(cfg.get_value("application", "boot_splash/show_image", true)):
		_blocker("Project boot splash still shows a static image before the loading UI.")
		failed = true

	if int(cfg.get_value("application", "boot_splash/minimum_display_time", 0)) > 0:
		_blocker("Project boot splash has a forced minimum display time before BootLoader can appear.")
		failed = true

	if str(cfg.get_value("rendering", "renderer/rendering_method.mobile", "")) != "gl_compatibility":
		_blocker("Mobile rendering method is not explicitly gl_compatibility; iOS should not waste startup time trying another renderer first.")
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

	var include_filter := str(cfg.get_value("preset.0", "include_filter", ""))
	if not (include_filter.contains("legal/*.txt") or include_filter.contains("legal/*")):
		_blocker("iOS export preset does not explicitly include bundled legal text files.")
		failed = true

	var exclude_filter := str(cfg.get_value("preset.0", "exclude_filter", ""))
	for path in [
		"addons/admob/android/*",
		"addons/admob/assets/*",
		"addons/admob/csharp/*",
		"addons/admob/gdscript/*",
		"addons/admob/internal/*",
	]:
		if not exclude_filter.contains(path):
			_blocker("iOS export preset does not exclude AdMob addon resource path from the shipped pack: %s." % path)
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

	if not bool(cfg.get_value(options, "application/delete_old_export_files_unconditionally", false)):
		_blocker("iOS export preset keeps old exported files. Enable delete_old_export_files_unconditionally before device/App Store testing.")
		failed = true

	if not bool(cfg.get_value(options, "shader_baker/enabled", false)):
		_blocker("iOS export preset has shader_baker disabled. Enable it so first launch does less shader work before the loading UI appears.")
		failed = true

	var admob_app_id := str(cfg.get_value(options, "plugins_plist/GADApplicationIdentifier", ""))
	if admob_app_id.is_empty() or admob_app_id == SAMPLE_ADMOB_APP_ID:
		_blocker("iOS GADApplicationIdentifier is still blank or using Google's sample AdMob app ID.")
		failed = true

	if str(cfg.get_value(options, "plugins/IOSInAppPurchase", "false")) != "true":
		_blocker("iOS Remove Ads purchase plugin is not enabled in the export preset.")
		failed = true

	# Frog Quest+ asks for tracking (ATT) through Google's consent flow, which shows Apple's prompt
	# after the IDFA explainer message published in AdMob (see release/APP_STORE_RELEASE_CHECKLIST.md).
	var plist := str(cfg.get_value(options, "application/additional_plist_content", ""))
	if not plist.contains("NSUserTrackingUsageDescription"):
		_blocker("iOS export preset is missing NSUserTrackingUsageDescription. Without it the tracking prompt can't appear and iOS stops the app when it's requested.")
		failed = true
	else:
		_warn("Tracking prompt: before uploading, confirm the AdMob IDFA explainer message is published and that a fresh install shows Apple's tracking prompt. App Review rejects builds with NSUserTrackingUsageDescription but no prompt.")

	for key in ["storyboard/custom_image@2x", "storyboard/custom_image@3x"]:
		if not str(cfg.get_value(options, key, "")).strip_edges().is_empty():
			_blocker("iOS launch storyboard uses %s. Keep the launch screen image-free so BootLoader can appear sooner." % key)
			failed = true

	if not bool(cfg.get_value(options, "privacy/tracking_enabled", false)):
		_blocker("iOS export privacy does not declare tracking, but Frog Quest+ asks for ATT so ads can be targeted. Enable privacy/tracking_enabled.")
		failed = true

	for data_type in ["device_id", "advertising_data"]:
		if not bool(cfg.get_value(options, "privacy/collected_data/%s/used_for_tracking" % data_type, false)):
			_blocker("iOS export privacy does not mark %s as used for tracking. With ATT allowed, AdMob uses it for targeted ads." % data_type)
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

	var rewarded_id := _read_const(text, "REWARDED_ID")
	if rewarded_id.is_empty() or rewarded_id == SAMPLE_REWARDED_ID:
		_blocker("REWARDED_ID is still blank or using Google's sample rewarded ad unit. Create a Rewarded ad unit for this app in AdMob and paste its ID into AdsManager.gd.")
		failed = true

	if text.contains("\"max_ad_content_rating\": \"T\"") or text.contains("\"max_ad_content_rating\": \"MA\""):
		_warn("Ads can be rated above G. Apple requires ads to fit the app's age rating, so set the App Store age rating to at least 13+ (T) before submitting.")

	var iap_id := _read_const(text, "IAP_ID")
	if iap_id != EXPECTED_IAP_ID:
		_blocker("IAP_ID is '%s'; expected '%s'." % [iap_id, EXPECTED_IAP_ID])
		failed = true

	if not text.contains("Engine.has_singleton(\"IOSInAppPurchase\")"):
		_blocker("AdsManager has no detectable StoreKit 2 iOS purchase backend check.")
		failed = true

	if not text.contains("Engine.has_singleton(\"InAppStore\")") and not text.contains("Engine.has_singleton(\"InAppPurchase\")"):
		_blocker("AdsManager has no detectable iOS purchase backend check.")
		failed = true

	if not FileAccess.file_exists("res://ios/plugins/ios-in-app-purchase/ios-in-app-purchase.gdip"):
		_blocker("Missing iOS In-App Purchase plugin gdip under ios/plugins.")
		failed = true

	for forbidden in ["res://addons/admob/gdscript", "_ad_class(", "_new_ad("]:
		if text.contains(forbidden):
			_blocker("AdsManager still depends on exported AdMob GDScript wrappers: %s." % forbidden)
			failed = true

	return failed


func _check_admob_ios_exporter() -> bool:
	var failed := false
	var exporter := _read_text("res://addons/admob/internal/exporters/ios/export_plugin.gd")
	var pbxproj_service := _read_text("res://addons/admob/internal/services/pbxproj_service.gd")

	if exporter.is_empty() or pbxproj_service.is_empty():
		_blocker("Could not read the AdMob iOS exporter scripts.")
		return true

	if not exporter.contains('const SPM_PACKAGE_DIR := "PoingGodotAdMobDepsPackage"'):
		_blocker("AdMob iOS exporter should generate its Swift package in PoingGodotAdMobDepsPackage, not at the Xcode project root.")
		failed = true

	if not exporter.contains("PbxprojService.patch(pbxproj_path, SPM_PACKAGE_DIR)"):
		_blocker("AdMob iOS exporter is not passing the package folder to the pbxproj patcher.")
		failed = true

	if not pbxproj_service.contains("package_relative_path"):
		_blocker("AdMob pbxproj patcher still hardcodes the local Swift package path.")
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


func _check_no_direct_import_cache_references() -> bool:
	var failed := false
	for path in [
		"res://scenes/BootLoader.tscn",
		"res://scenes/Main.tscn",
		"res://scenes/EndlessMode.tscn",
		"res://scenes/player.tscn",
		"res://scenes/endlessplayer.tscn",
	]:
		var text := _read_text(path)
		if text.contains("res://.godot/imported"):
			_blocker("%s directly references Godot's import cache. Use the real res:// asset path instead." % path)
			failed = true
	return failed


func _check_startup_lightweight_project_scripts() -> bool:
	var failed := false
	var paths: Array[String] = []
	_collect_gd_files("res://scripts", paths)
	_collect_gd_files("res://scenes", paths)

	for path in paths:
		var text := _read_text(path)
		var line_number := 0
		for line in text.split("\n"):
			line_number += 1
			var trimmed := line.strip_edges()
			if trimmed.begins_with("#"):
				continue
			if trimmed.begins_with("class_name "):
				_blocker("%s:%d uses class_name. Avoid global class registration in game scripts during iOS startup." % [path, line_number])
				failed = true
			if line.contains("preload("):
				_blocker("%s:%d uses preload(). Use lazy load/threaded loading so the iOS launch screen clears sooner." % [path, line_number])
				failed = true
	return failed


func _collect_gd_files(root: String, paths: Array[String]) -> void:
	var dir := DirAccess.open(root)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var path := root.path_join(name)
		if dir.current_is_dir():
			_collect_gd_files(path, paths)
		elif name.ends_with(".gd"):
			paths.append(path)
		name = dir.get_next()
	dir.list_dir_end()


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
