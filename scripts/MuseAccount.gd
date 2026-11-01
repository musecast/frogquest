extends Node
## Your Muse account, the same one Muse Shelf and the other Muse apps use. Sign in with the code Muse
## emails you; if the account has Muse Pro, this is Frog Quest+: the + on the logo, no ads, and Lil
## Froggy can come out on your computer.
##
## Sign-in only: Frog Quest never makes accounts (you make yours in a Muse app, which is also where you
## delete it). It talks to the Muse account's Supabase project directly with the public publishable
## key, the one every Muse app ships with: an email code to sign in, then muse_has_pro() now and then.
## The session lives in user://, encrypted to this device. A Pro that's been seen stays on offline for
## PRO_OFFLINE_DAYS, so a flight doesn't take the + away.
##
## Only the game refreshes the session; Lil Froggy's copy (--desktop-frog) just reads it. Supabase
## refresh tokens are single use, so two copies refreshing at once would sign you out.

signal changed  # signed in or out, or Pro came or went
signal _check_finished(answered: bool)

const SUPABASE_URL := "https://rdafaxpamctnqbevgnxd.supabase.co"
const PUBLISHABLE_KEY := "sb_publishable_4Ju-f7ORTQHkarTeqyUFEQ_Bccg9qKy"  # public by design (RLS guards the data)
const SAVE_PATH := "user://muse_account.save"
const PRO_OFFLINE_DAYS := 30
const RECHECK_AFTER := 6 * 3600  # seconds: an older Pro check is redone when you come back to the game
const TIMEOUT := 10.0
const FIRST_CHECK_DELAY := 4.0  # after launch, once the world's up (never during the launch itself)
const LOGO := "res://assets/frogquesttitle.png"
const LOGO_PLUS := "res://assets/frogquesttitle_plus.png"  # (the same, with the +)

var email := ""
var save_path := SAVE_PATH  # (the tests point this somewhere else, so they never touch your sign-in)
var transport := Callable()  # (and swap the network for a fake: (path, body, bearer) -> {code, data})

var _pro := false
var _pro_checked_at := 0.0
var _refresh_token := ""
var _access_token := ""
var _access_expires_at := 0.0
var _loaded := false
var _checking := false


func _ready() -> void:
	_ensure_loaded()
	_show_title()
	changed.connect(_show_title)
	if _is_froggy() or not is_signed_in():
		return
	get_tree().create_timer(FIRST_CHECK_DELAY).timeout.connect(check_pro)


func _notification(what: int) -> void:
	if what != NOTIFICATION_APPLICATION_RESUMED and what != NOTIFICATION_APPLICATION_FOCUS_IN:
		return
	if Time.get_ticks_msec() < FIRST_CHECK_DELAY * 1000.0:
		return  # (the launch has its own check, once the world's up)
	if is_signed_in() and not _is_froggy() and _now() - _pro_checked_at > RECHECK_AFTER:
		check_pro()


func is_signed_in() -> bool:
	_ensure_loaded()
	return _refresh_token != ""


## Muse Pro, as last checked (and recent enough to trust offline).
func has_pro() -> bool:
	_ensure_loaded()
	return _refresh_token != "" and _pro and _now() - _pro_checked_at < PRO_OFFLINE_DAYS * 86400.0


## The FROG QUEST logo, with its + when you've got Muse Pro.
func logo_path() -> String:
	return LOGO_PLUS if has_pro() else LOGO


## Emails a sign-in code. "" when it's on its way, otherwise what went wrong (to show).
func send_code(address: String) -> String:
	var r: Dictionary = await _call("/auth/v1/otp", {"email": address.strip_edges(), "create_user": false})
	return "" if r.code == 200 else _problem(r, "send")


## Signs in with the code from that email, then checks for Pro. "" when signed in, otherwise what
## went wrong.
func verify_code(address: String, code: String) -> String:
	var r: Dictionary = await _call("/auth/v1/verify",
		{"type": "email", "email": address.strip_edges(), "token": code.strip_edges()})
	if r.code != 200 or not (r.data is Dictionary) or str(r.data.get("refresh_token", "")) == "":
		return _problem(r, "verify")
	email = address.strip_edges()
	_take_session(r.data)
	_pro = false
	_pro_checked_at = 0.0
	_save()
	changed.emit()
	await check_pro()
	return ""


## Asks the account whether it has Muse Pro, refreshing the session first if it's old. True if it
## got an answer (offline, or signed out meanwhile, it didn't). Asked again mid-check, it waits for
## that one.
func check_pro() -> bool:
	if not is_signed_in():
		return false
	if _checking:
		return await _check_finished
	_checking = true
	var answered := false
	for _attempt in 2:
		var token: String = await _access()
		if token == "":
			break
		var r: Dictionary = await _call("/rest/v1/rpc/muse_has_pro", {}, token)
		if r.code == 200:
			_set_pro(r.data == true)
			answered = true
			break
		if r.code != 401:
			break
		_access_token = ""  # (turned down: get a fresh one and ask once more)
	_checking = false
	_check_finished.emit(answered)
	return answered


## Signs out here (only here: the Muse apps stay signed in).
func sign_out() -> void:
	var refresh := _refresh_token
	var access := _access_token if _now() < _access_expires_at - 30.0 else ""
	_clear()
	changed.emit()
	_end_session(refresh, access)


## A current access token: the one we have, or a fresh one from the refresh token. "" when there's
## no getting one right now (offline), or the session has ended (then you're signed out here too).
func _access() -> String:
	if _access_token != "" and _now() < _access_expires_at - 60.0:
		return _access_token
	var r: Dictionary = await _call("/auth/v1/token?grant_type=refresh_token", {"refresh_token": _refresh_token})
	if r.code == 200 and r.data is Dictionary and str(r.data.get("refresh_token", "")) != "":
		_take_session(r.data)
		_save()
		return _access_token
	if r.code >= 400 and r.code < 500 and r.code != 429:
		_clear()  # (signed out everywhere, or the account's gone)
		changed.emit()
	return ""


## Ends the session on Muse's side too, once you've signed out here (best effort, in the background).
func _end_session(refresh: String, access: String) -> void:
	if access == "" and refresh != "":
		var r: Dictionary = await _call("/auth/v1/token?grant_type=refresh_token", {"refresh_token": refresh})
		if r.code == 200 and r.data is Dictionary:
			access = str(r.data.get("access_token", ""))
	if access != "":
		await _call("/auth/v1/logout?scope=local", {}, access)


func _take_session(d: Dictionary) -> void:
	_access_token = str(d.get("access_token", ""))
	_refresh_token = str(d.get("refresh_token", ""))
	_access_expires_at = _now() + float(d.get("expires_in", 3600))
	var user = d.get("user")
	if user is Dictionary and str(user.get("email", "")) != "":
		email = str(user.email)


func _set_pro(on: bool) -> void:
	var before := has_pro()
	_pro = on
	_pro_checked_at = _now()
	_save()
	if has_pro() != before:
		changed.emit()


## One request to the account service: {code, data}, code 0 when it couldn't be reached.
func _call(path: String, body: Dictionary, bearer := "") -> Dictionary:
	if transport.is_valid():
		return transport.call(path, body, bearer)
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT
	add_child(http)
	var headers := PackedStringArray(["apikey: " + PUBLISHABLE_KEY, "Content-Type: application/json"])
	if bearer != "":
		headers.append("Authorization: Bearer " + bearer)
	if http.request(SUPABASE_URL + path, headers, HTTPClient.METHOD_POST, JSON.stringify(body)) != OK:
		http.queue_free()
		return {"code": 0, "data": null}
	var res: Array = await http.request_completed
	http.queue_free()
	if res[0] != HTTPRequest.RESULT_SUCCESS:
		return {"code": 0, "data": null}
	var json := JSON.new()
	var text := (res[3] as PackedByteArray).get_string_from_utf8()
	return {"code": res[1], "data": json.data if json.parse(text) == OK else null}


## What went wrong, in words for the account screen.
func _problem(r: Dictionary, step: String) -> String:
	if r.code == 0:
		return "Couldn't reach Muse. Check your connection and try again."
	var d: Dictionary = r.data if r.data is Dictionary else {}
	var kind := str(d.get("error_code", ""))
	if kind in ["otp_disabled", "signup_disabled", "user_not_found"]:
		return "No Muse account uses that email. You can make one in Muse Shelf."
	if r.code == 429 or kind.begins_with("over_"):
		return "That's a lot of tries. Wait a minute, then try again."
	if step == "verify":
		return "That code didn't work. Check it, or send a new one."
	if kind in ["email_address_invalid", "validation_failed"]:
		return "That doesn't look like an email address."
	return "Something went wrong (%d). Try again in a bit." % r.code


func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(save_path):
		return
	var f := FileAccess.open_encrypted_with_pass(save_path, FileAccess.READ, _device_key())
	if f == null:
		return  # (from another device, or damaged: signed out)
	var d = f.get_var()
	if not (d is Dictionary):
		return
	email = str(d.get("email", ""))
	_refresh_token = str(d.get("refresh_token", ""))
	_access_token = str(d.get("access_token", ""))
	_access_expires_at = float(d.get("access_expires_at", 0.0))
	_pro = bool(d.get("pro", false))
	_pro_checked_at = float(d.get("pro_checked_at", 0.0))


func _save() -> void:
	var f := FileAccess.open_encrypted_with_pass(save_path, FileAccess.WRITE, _device_key())
	if f == null:
		push_warning("MuseAccount: couldn't save the sign-in (%s)." % error_string(FileAccess.get_open_error()))
		return
	f.store_var({
		"email": email,
		"refresh_token": _refresh_token,
		"access_token": _access_token,
		"access_expires_at": _access_expires_at,
		"pro": _pro,
		"pro_checked_at": _pro_checked_at,
	})


func _clear() -> void:
	email = ""
	_refresh_token = ""
	_access_token = ""
	_access_expires_at = 0.0
	_pro = false
	_pro_checked_at = 0.0
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)


## The key the session file is encrypted with: this device's own ID (so a copied file is no use).
func _device_key() -> String:
	return "frogquest-muse-" + ("" if OS.has_feature("web") else OS.get_unique_id())


## On a computer the window says which one this is: Frog Quest, or Frog Quest+ with Pro.
func _show_title() -> void:
	if OS.has_feature("pc") and not _is_froggy():
		get_window().title = "Frog Quest+" if has_pro() else str(ProjectSettings.get_setting("application/config/name"))


func _is_froggy() -> bool:
	return "--desktop-frog" in OS.get_cmdline_user_args()  # (DesktopFrogLink.LAUNCH_FLAG)


func _now() -> float:
	return Time.get_unix_time_from_system()
