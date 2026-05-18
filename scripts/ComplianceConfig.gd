extends Node

const _LEGAL_POPUP := preload("res://scripts/PrivacyTermsPopup.gd")

## Apple App Store Connect still expects a public HTTPS “Privacy Policy URL”. Host a copy of
## `res://legal/privacy_policy.txt` (same wording) on any static site, then paste that link here.
## The game always shows the bundled in-app version via Privacy Policy / Terms buttons.
const APP_STORE_PRIVACY_POLICY_URL := "https://musecast.github.io/frogquest/privacy_policy.html"


func open_privacy_policy() -> void:
	_LEGAL_POPUP.present(get_tree(), _LEGAL_POPUP.Doc.PRIVACY)


func open_terms_of_use() -> void:
	_LEGAL_POPUP.present(get_tree(), _LEGAL_POPUP.Doc.TERMS)


func open_privacy_policy_in_browser_for_store_listing() -> void:
	var u := APP_STORE_PRIVACY_POLICY_URL.strip_edges()
	if not (u.begins_with("http://") or u.begins_with("https://")):
		push_warning(
			"ComplianceConfig: Host legal/privacy_policy.txt on HTTPS and set APP_STORE_PRIVACY_POLICY_URL for App Store Connect."
		)
		return
	OS.shell_open(u)
