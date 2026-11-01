extends Node

## Apple App Store Connect still expects a public HTTPS “Privacy Policy URL”. Host a copy of
## `res://legal/privacy_policy.txt` (same wording) on any static site, then paste that link here.
## The game always shows the bundled in-app version via Privacy Policy / Terms buttons.
const APP_STORE_PRIVACY_POLICY_URL := "https://jasonmuse.github.io/frog-quest-support/privacy_policy.html"


func open_privacy_policy() -> void:
	var legal_popup := load("res://scripts/PrivacyTermsPopup.gd")
	if legal_popup:
		legal_popup.present(get_tree(), legal_popup.Doc.PRIVACY)


func open_terms_of_use() -> void:
	var legal_popup := load("res://scripts/PrivacyTermsPopup.gd")
	if legal_popup:
		legal_popup.present(get_tree(), legal_popup.Doc.TERMS)


func open_privacy_policy_in_browser_for_store_listing() -> void:
	var u := APP_STORE_PRIVACY_POLICY_URL.strip_edges()
	if not (u.begins_with("http://") or u.begins_with("https://")):
		push_warning(
			"ComplianceConfig: Host legal/privacy_policy.txt on HTTPS and set APP_STORE_PRIVACY_POLICY_URL for App Store Connect."
		)
		return
	OS.shell_open(u)
