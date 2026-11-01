extends SceneTree
## Headless test for the Muse account (MuseAccount.gd): sending and checking the code, Pro, the session
## refresh, being signed out from Muse's side, staying Pro offline for a while (and no longer), and
## signing out. The network is a fake and the session file a scratch one, so it never talks to Muse and
## never touches a real sign-in.
##   Godot --headless --path . --script res://tools/validate_muse_account.gd

const SCRATCH := "user://test_muse_account.save"
const DAY := 86400.0

var _failures: Array[String] = []
var _calls: Array = []
var _replies: Dictionary = {}  # path start -> replies ({code, data}) to hand out in turn


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var acct: Node = root.get_node("MuseAccount")
	var real_path: String = acct.save_path
	acct.save_path = SCRATCH
	acct._clear()
	acct.transport = _fake
	var changes := [0]
	acct.changed.connect(func() -> void: changes[0] += 1)
	var link: GDScript = load("res://scripts/DesktopFrogLink.gd")

	_expect(not acct.is_signed_in() and not acct.has_pro() and acct.logo_path() == acct.LOGO,
		"signed out to start: no Pro, the plain logo")

	# Sending the code.
	_reply("/auth/v1/otp", 200, {})
	_expect(await acct.send_code(" jay@example.com ") == "", "a code goes out for a Muse account's email")
	var sent: Dictionary = _calls[-1]
	_expect(sent.body.get("create_user") == false and sent.body.get("email") == "jay@example.com" and sent.bearer == "",
		"it never makes an account (create_user false), and trims the email")
	_reply("/auth/v1/otp", 422, {"code": 422, "error_code": "otp_disabled", "msg": "Signups not allowed for otp"})
	_expect((await acct.send_code("nobody@example.com")).contains("No Muse account"), "an email with no account says so")
	_reply("/auth/v1/otp", 429, {"error_code": "over_email_send_rate_limit"})
	_expect((await acct.send_code("jay@example.com")).contains("tries"), "too many codes says wait")
	_expect((await acct.send_code("jay@example.com")).contains("Couldn't reach Muse"), "offline says so")

	# Checking the code: wrong, then right (with Pro).
	_reply("/auth/v1/verify", 403, {"error_code": "otp_expired", "msg": "Token has expired or is invalid"})
	_expect((await acct.verify_code("jay@example.com", "000000")).contains("didn't work"), "a wrong code says so")
	_expect(not acct.is_signed_in(), "a wrong code doesn't sign you in")
	changes[0] = 0
	_reply("/auth/v1/verify", 200, _session("access-1", "refresh-1"))
	_reply("/rest/v1/rpc/muse_has_pro", 200, true)
	_expect(await acct.verify_code("jay@example.com", "123456") == "", "the right code signs you in")
	_expect(acct.is_signed_in() and acct.has_pro() and acct.email == "jay@example.com", "and finds Muse Pro")
	_expect(_calls[-1].bearer == "access-1", "the Pro check goes with your sign-in")
	_expect(acct.logo_path() == acct.LOGO_PLUS and link.has_muse_pro(), "Pro brings the + and lets Lil Froggy out")
	_expect(changes[0] >= 2, "the screens hear about it (signed in, then Pro)")
	var raw := FileAccess.get_file_as_bytes(SCRATCH).get_string_from_ascii()
	_expect(FileAccess.file_exists(SCRATCH) and not raw.contains("refresh-1"), "the session is saved, encrypted")

	# It's all still there next launch.
	_forget(acct)
	_expect(acct.is_signed_in() and acct.has_pro() and acct.email == "jay@example.com", "the sign-in survives a restart")

	# Offline, Pro lasts a while, then doesn't.
	acct._pro_checked_at = acct._now() - 29.0 * DAY
	_expect(acct.has_pro(), "Pro stays on offline for a few weeks")
	acct._pro_checked_at = acct._now() - 31.0 * DAY
	_expect(not acct.has_pro(), "but not forever")
	acct._pro_checked_at = acct._now()

	# A stale session gets refreshed first; Pro can go away.
	acct._access_expires_at = acct._now() - 10.0
	changes[0] = 0
	_reply("/auth/v1/token", 200, _session("access-2", "refresh-2"))
	_reply("/rest/v1/rpc/muse_has_pro", 200, false)
	_expect(await acct.check_pro(), "a Pro check gets an answer")
	_expect(_calls[-2].path.begins_with("/auth/v1/token?grant_type=refresh_token") and _calls[-2].body.refresh_token == "refresh-1",
		"an old session is refreshed first")
	_expect(acct._refresh_token == "refresh-2" and _calls[-1].bearer == "access-2", "with the new tokens kept and used")
	_expect(not acct.has_pro() and acct.is_signed_in() and changes[0] == 1, "Pro ending takes the + away (still signed in)")

	# Turned down mid-session: refresh once and ask again.
	_reply("/rest/v1/rpc/muse_has_pro", 401, {"message": "JWT expired"})
	_reply("/auth/v1/token", 200, _session("access-3", "refresh-3"))
	_reply("/rest/v1/rpc/muse_has_pro", 200, true)
	_expect(await acct.check_pro() and acct.has_pro() and _calls[-1].bearer == "access-3", "a turned-down check refreshes and asks again")

	# Offline: nothing changes.
	acct._access_expires_at = acct._now() - 10.0
	_expect(not await acct.check_pro() and acct.is_signed_in() and acct.has_pro(), "offline, you stay signed in with Pro")

	# Signed out from Muse's side (signed out everywhere, account deleted): signed out here too.
	changes[0] = 0
	_reply("/auth/v1/token", 400, {"error_code": "refresh_token_not_found"})
	_expect(not await acct.check_pro(), "no answer once the session's gone")
	_expect(not acct.is_signed_in() and not acct.has_pro() and not FileAccess.file_exists(SCRATCH) and changes[0] == 1,
		"a session Muse ended signs you out here, file and all")
	_expect(not link.has_muse_pro() and acct.logo_path() == acct.LOGO, "and the + and Lil Froggy's pass go with it")

	# Signing out: here at once, and on Muse's side (this session only).
	_reply("/auth/v1/verify", 200, _session("access-4", "refresh-4"))
	_reply("/rest/v1/rpc/muse_has_pro", 200, true)
	await acct.verify_code("jay@example.com", "654321")
	_calls.clear()
	_reply("/auth/v1/logout", 204, null)
	acct.sign_out()
	for _i in 3:
		await process_frame
	_expect(not acct.is_signed_in() and not FileAccess.file_exists(SCRATCH), "signing out forgets the session")
	_expect(_calls.size() == 1 and _calls[0].path == "/auth/v1/logout?scope=local" and _calls[0].bearer == "access-4",
		"and ends it on Muse's side, for this device only (the Muse apps stay signed in)")

	acct.transport = Callable()
	acct._clear()
	acct.save_path = real_path
	_forget(acct)
	if _failures.is_empty():
		print("Muse account test passed.")
	else:
		for failure in _failures:
			push_warning("FAIL: " + failure)
		printerr("Muse account test failed (%d)." % _failures.size())
	quit(1 if not _failures.is_empty() else 0)


## As if the game had just started: what's in memory goes, and it's read back from the file.
func _forget(acct: Node) -> void:
	acct.email = ""
	acct._refresh_token = ""
	acct._access_token = ""
	acct._access_expires_at = 0.0
	acct._pro = false
	acct._pro_checked_at = 0.0
	acct._loaded = false
	acct._ensure_loaded()


func _session(access: String, refresh: String) -> Dictionary:
	return {"access_token": access, "refresh_token": refresh, "expires_in": 3600, "token_type": "bearer",
		"user": {"email": "jay@example.com"}}


func _reply(path_start: String, code: int, data: Variant) -> void:
	if not _replies.has(path_start):
		_replies[path_start] = []
	_replies[path_start].append({"code": code, "data": data})


func _fake(path: String, body: Dictionary, bearer: String) -> Dictionary:
	_calls.append({"path": path, "body": body, "bearer": bearer})
	for start in _replies:
		if path.begins_with(start) and not _replies[start].is_empty():
			return _replies[start].pop_front()
	return {"code": 0, "data": null}  # (nothing queued: offline)


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
