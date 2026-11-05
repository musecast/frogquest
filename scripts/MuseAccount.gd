extends Node
## Your Muse account, the same one Muse Shelf and the other Muse apps use. Sign in through Muse Shelf
## (the game shows a code; you type it into Muse Shelf, where you're signed in with Google, Apple or
## email), or with the code Muse emails you. If the account has Muse Pro, this is Frog Quest+: the +
## on the logo, no ads, and Lil Froggy can come out on your computer.
##
## Sign-in only: Frog Quest never makes accounts (you make yours in a Muse app, which is also where you
## delete it). It talks to the Muse account's Supabase project directly with the public publishable
## key, the one every Muse app ships with: an email code to sign in, then muse_has_pro() now and then.
## Signing in through Muse Shelf goes by way of the Muse API (MUSE_API): it hands out the code, Muse
## Shelf approves it there for whoever's signed in, and the game, checking back with a secret only it
## knows, gets a one-time sign-in to trade with Supabase for a session of its own.
## The session lives in user://, encrypted to this device. A Pro that's been seen stays on offline for
## PRO_OFFLINE_DAYS, so a flight doesn't take the + away.
## With Pro, you can see the game the way free players do (see_as_free) and switch back any time.
## Testers get Pro from Muse itself (an "internal-test" grant, which can end on a set day), never from
## a switch in here: the App Store's copy is the very same build.
##
## Only the game refreshes the session; Lil Froggy's copy (--desktop-frog) just reads it. Supabase
## refresh tokens are single use, so two copies refreshing at once would sign you out.

signal changed  # signed in or out, or Pro came or went
signal link_ended(result: String)  # signing in through Muse Shelf stopped: "" signed in, "expired", or what went wrong
signal _check_finished(answered: bool)
signal _access_done(token: String)  # (a refresh finished: _access)

const SUPABASE_URL := "https://rdafaxpamctnqbevgnxd.supabase.co"
const PUBLISHABLE_KEY := "sb_publishable_4Ju-f7ORTQHkarTeqyUFEQ_Bccg9qKy"  # public by design (RLS guards the data)
const SAVE_PATH := "user://muse_account.save"
const PRO_OFFLINE_DAYS := 30
const RECHECK_AFTER := 6 * 3600  # seconds: an older Pro check is redone when you come back to the game
const TIMEOUT := 10.0
const FIRST_CHECK_DELAY := 4.0  # after launch, once the world's up (never during the launch itself)
const LOGO := "res://assets/frogquesttitle.png"
const LOGO_PLUS := "res://assets/frogquesttitle_plus.png"  # (the same, with the +)
const MUSE_API := "https://muse-tracker-api.jasonmuse.workers.dev"

var email := ""
var member_since := ""  # (when the account was made, as Muse has it: an ISO date; "" until a sign-in or refresh says)
var save_path := SAVE_PATH  # (the tests point this somewhere else, so they never touch your sign-in)
var transport := Callable()  # (and swap the network for a fake: (path, body, bearer) -> {code, data})

var _pro := false
var _pro_checked_at := 0.0
var _as_free := false  # (you've got Pro, and you're seeing the game as free players do: see_as_free)
var _refresh_token := ""
var _access_token := ""
var _access_expires_at := 0.0
var _loaded := false
var _checking := false
var _refreshing := false  # (a refresh is on its way: _access)
var linking := {}  # while waiting on Muse Shelf: the code to type there, its secret, links to open it
var _link_token := 0


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


## Muse Pro, as last checked (and recent enough to trust offline): what the game goes by. Not while
## you're seeing it as free players do (see_as_free).
func has_pro() -> bool:
	return owns_pro() and not _as_free


## The account's own Muse Pro, whichever way you're seeing the game.
func owns_pro() -> bool:
	_ensure_loaded()
	return _refresh_token != "" and _pro and _now() - _pro_checked_at < PRO_OFFLINE_DAYS * 86400.0


## You've got Muse Pro, and you're seeing the game just as free players do: no +, no Pro modes, and
## the ads from its next launch (Remove Ads still counts, as it does for them).
func is_seeing_as_free() -> bool:
	return owns_pro() and _as_free


## Sees the game as free players do (on), or with your Pro again (off). Kept till you switch back,
## sign out, or Pro ends (when it comes back, it comes back as Pro).
func see_as_free(on: bool) -> void:
	_ensure_loaded()
	if _as_free == on:
		return
	_as_free = on
	_save()
	changed.emit()


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
	_signed_in(address.strip_edges(), r.data)
	await check_pro()
	return ""


## Signs in through Muse Shelf: gets a code to show (in linking) and checks back every few seconds
## until Muse Shelf approves it (link_ended("") once signed in), it runs out (link_ended("expired")) or
## it's cancelled. "" when there's a code to show, otherwise what went wrong.
func start_link() -> String:
	cancel_link()
	var r: Dictionary = await _call("/api/link/start", {"app": "frog-quest", "device": _device_name()}, "", MUSE_API)
	var d: Dictionary = r.data if r.data is Dictionary else {}
	if r.code == 200 and str(d.get("code", "")) != "" and str(d.get("secret", "")) != "":
		linking = d
		_link_token += 1
		_wait_for_link(_link_token)
		return ""
	if r.code == 404 or r.code == 503:  # (no such route yet, or the Muse API's not set up for it)
		return "Signing in through Muse Shelf isn't ready yet. Use your email for now."
	return _problem(r, "link")


## Stops waiting on Muse Shelf.
func cancel_link() -> void:
	linking = {}
	_link_token += 1


## Opens Muse Shelf at its Link a Game page with the code filled in: the app if it's on this phone,
## otherwise the website. Once the app's been opened (linking.opened_app), the website: a Muse Shelf
## from before Link a Game opens on its home screen without the code, and the website works with any.
func open_muse_shelf() -> void:
	if linking.is_empty():
		return
	var app := str(linking.get("app_url", ""))
	var web := str(linking.get("approve_url", ""))
	var mobile := OS.get_name() in ["iOS", "Android"]
	if mobile and app != "" and not linking.get("opened_app", false) and OS.shell_open(app) == OK:
		linking.opened_app = true
		return
	if web != "":
		OS.shell_open(web)


## Asks once whether Muse Shelf has approved the code. "pending" until it has; "" once it has and
## we're signed in (Pro checked too); "expired" if the code's run out or gone; or what went wrong.
func poll_link(code: String, secret: String) -> String:
	var r: Dictionary = await _call("/api/link/poll", {"code": code, "secret": secret}, "", MUSE_API)
	var d: Dictionary = r.data if r.data is Dictionary else {}
	if r.code == 0:
		return "pending"  # (a blip offline: keep waiting)
	if r.code == 410 or r.code == 404:
		return "expired"
	if r.code != 200:
		var said := str(d.get("error", ""))  # (the Muse API's own words, when it has them)
		return said if said != "" and r.code != 429 else _problem(r, "link")
	if str(d.get("status", "")) != "approved":
		return "pending"
	var v: Dictionary = await _call("/auth/v1/verify", {"type": "email", "token_hash": str(d.get("token_hash", ""))})
	if v.code != 200 or not (v.data is Dictionary) or str(v.data.get("refresh_token", "")) == "":
		return _problem(v, "link")
	var who := str(d.get("email", ""))
	if who == "" and v.data.get("user") is Dictionary:
		who = str(v.data.user.get("email", ""))
	_signed_in(who, v.data)
	await check_pro()
	return ""


func _wait_for_link(token: int) -> void:
	var code := str(linking.get("code", ""))
	var secret := str(linking.get("secret", ""))
	var every := maxf(2.0, float(linking.get("interval", 3)))
	var until := _now() + float(linking.get("expires_in", 600))
	while token == _link_token:
		await get_tree().create_timer(every, true, false, true).timeout
		if token != _link_token:
			return
		if _now() > until:
			_end_link(token, "expired")
			return
		var result: String = await poll_link(code, secret)
		if token != _link_token:
			return
		if result != "pending":
			_end_link(token, result)
			return


func _end_link(token: int, result: String) -> void:
	if token != _link_token:
		return
	linking = {}
	_link_token += 1
	link_ended.emit(result)


## What Muse Shelf shows for this device when it asks to be let in: the kind of device only, nothing
## that identifies it (the privacy policy says so).
static func _device_name() -> String:
	match OS.get_name():
		"iOS":
			return "iPhone or iPad"
		"Android":
			return "Android"
		"macOS":
			return "Mac"
		"Windows":
			return "Windows PC"
		"Linux":
			return "Linux PC"
	return "Computer"


func _signed_in(address: String, d: Dictionary) -> void:
	email = address
	_take_session(d)
	_pro = false
	_pro_checked_at = 0.0
	_as_free = false
	_save()
	changed.emit()


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


## Calls one of the Muse account's functions (rpc/<fn_name>) as you: {code, data}. Code 0 when Muse
## couldn't be reached, -1 when you're not signed in, 404 when there's no such function (yet). A
## turned-down session gets a fresh token and one more try, as check_pro does.
func call_rpc(fn_name: String, args := {}) -> Dictionary:
	if not is_signed_in():
		return {"code": -1, "data": null}
	var r := {"code": 0, "data": null}
	for _attempt in 2:
		var token: String = await _access()
		if token == "":
			return {"code": 0 if is_signed_in() else -1, "data": null}
		r = await _call("/rest/v1/rpc/" + fn_name, args, token)
		if r.code != 401:
			return r
		_access_token = ""  # (turned down: get a fresh one and ask once more)
	return r


## Calls the Muse API (MUSE_API, Muse's Worker) as you, like call_rpc: {code, data}, -1 signed out.
func call_api(path: String, body := {}) -> Dictionary:
	if not is_signed_in():
		return {"code": -1, "data": null}
	var r := {"code": 0, "data": null}
	for _attempt in 2:
		var token: String = await _access()
		if token == "":
			return {"code": 0 if is_signed_in() else -1, "data": null}
		r = await _call(path, body, token, MUSE_API)
		if r.code != 401:
			return r
		_access_token = ""
	return r


## Signs out here (only here: the Muse apps stay signed in).
func sign_out() -> void:
	var refresh := _refresh_token
	var access := _access_token if _now() < _access_expires_at - 30.0 else ""
	_clear()
	changed.emit()
	_end_session(refresh, access)


## A current access token: the one we have, or a fresh one from the refresh token. "" when there's
## no getting one right now (offline), or the session has ended (then you're signed out here too).
## One refresh at a time: refresh tokens are single use, so a second caller (the Pro check and Muse
## Social together) waits for the first one's answer rather than spending the same token again.
func _access() -> String:
	if _access_token != "" and _now() < _access_expires_at - 60.0:
		return _access_token
	if _refreshing:
		return await _access_done
	_refreshing = true
	var token := ""
	var r: Dictionary = await _call("/auth/v1/token?grant_type=refresh_token", {"refresh_token": _refresh_token})
	if r.code == 200 and r.data is Dictionary and str(r.data.get("refresh_token", "")) != "":
		_take_session(r.data)
		_save()
		token = _access_token
	elif r.code >= 400 and r.code < 500 and r.code != 429:
		_clear()  # (signed out everywhere, or the account's gone)
		changed.emit()
	_refreshing = false
	_access_done.emit(token)
	return token


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
	if user is Dictionary and str(user.get("created_at", "")) != "":
		member_since = str(user.created_at)


## When the account was made, for people: "Nov 2, 2026" ("" if Muse hasn't said yet).
func member_since_text() -> String:
	if member_since.length() < 10:
		return ""
	var when := Time.get_datetime_dict_from_datetime_string(member_since.substr(0, 10), false)
	if int(when.get("month", 0)) < 1 or int(when.get("month", 0)) > 12:
		return ""
	const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%s %d, %d" % [MONTHS[int(when.month) - 1], int(when.day), int(when.year)]


func _set_pro(on: bool) -> void:
	var before := [has_pro(), owns_pro()]
	_pro = on
	_pro_checked_at = _now()
	if not on:
		_as_free = false
	_save()
	if [has_pro(), owns_pro()] != before:
		changed.emit()


## One request to the account service: {code, data}, code 0 when it couldn't be reached.
func _call(path: String, body: Dictionary, bearer := "", base := SUPABASE_URL) -> Dictionary:
	if transport.is_valid():
		return await transport.call(path, body, bearer)  # (a test's fake may take its time)
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT
	add_child(http)
	var headers := PackedStringArray(["apikey: " + PUBLISHABLE_KEY, "Content-Type: application/json"])
	if bearer != "":
		headers.append("Authorization: Bearer " + bearer)
	if http.request(base + path, headers, HTTPClient.METHOD_POST, JSON.stringify(body)) != OK:
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
	if step == "link":
		return "Muse Shelf couldn't sign you in (%d). Try again in a bit." % r.code
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
	member_since = str(d.get("member_since", ""))
	_refresh_token = str(d.get("refresh_token", ""))
	_access_token = str(d.get("access_token", ""))
	_access_expires_at = float(d.get("access_expires_at", 0.0))
	_pro = bool(d.get("pro", false))
	_pro_checked_at = float(d.get("pro_checked_at", 0.0))
	_as_free = bool(d.get("as_free", false))


func _save() -> void:
	var f := FileAccess.open_encrypted_with_pass(save_path, FileAccess.WRITE, _device_key())
	if f == null:
		push_warning("MuseAccount: couldn't save the sign-in (%s)." % error_string(FileAccess.get_open_error()))
		return
	f.store_var({
		"email": email,
		"member_since": member_since,
		"refresh_token": _refresh_token,
		"access_token": _access_token,
		"access_expires_at": _access_expires_at,
		"pro": _pro,
		"pro_checked_at": _pro_checked_at,
		"as_free": _as_free,
	})


func _clear() -> void:
	email = ""
	member_since = ""
	_refresh_token = ""
	_access_token = ""
	_access_expires_at = 0.0
	_pro = false
	_pro_checked_at = 0.0
	_as_free = false
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
