extends Node
## Your Muse friends in Frog Quest (Muse Social, the same friends as Muse Shelf and the other Muse apps):
## who they are and what they're up to (playing Frog Quest, in another Muse app, away, do not disturb or
## offline), adding friends and answering their requests, blocking and reporting, your own status
## (online, away, do not disturb or invisible), and the friends and everyone leaderboards.
##
## It all lives in the Muse account's Supabase project, reached as you through MuseAccount.call_rpc:
## Muse Social's functions (muse_social_*), and presence and leaderboards on top (muse_presence_*,
## muse_game_*). Muse Social needs an @handle, picked in Muse Shelf.
## Until those functions answer on the live project, `available` stays false and none of it shows.

signal changed  # you, your friends, or whether Muse Social is there
signal invited(invite: Dictionary)  # a friend asks you into their online party: {id, room, from (a card), players...}
signal run_posted(result: Dictionary)  # an Endless run went to the leaderboards: submit_run's answer, {} if it couldn't

const APP := "frog-quest"
const GAME := "frog-quest"
const BOARD := "endless"
const PING_EVERY := 60.0  # seconds between "still here"s while the game's in front
const FRIENDS_EVERY := 30.0  # and between looks at what your friends are up to, while you're looking
const INVITES_EVERY := 15.0  # and between looks for invites into friends' parties
const STATUSES := ["online", "away", "dnd", "invisible"]
const STATE_ORDER := ["online", "away", "dnd", "offline"]  # (how friends are listed: who's on first)
const REPORT_REASONS := ["spam", "harassment", "hate", "sexual", "impersonation", "other"]
const COMMUNITY_RULES := "https://musemedia.app/community"

var available := false  # Muse Social answers (it isn't live everywhere yet)
var me := {}  # you as Muse Social has you (handle, displayName, avatar...), empty with no @handle yet
var my_status := "online"  # online, away, dnd or invisible: what Muse said the last time we pinged or set it
var on_global := false  # you chose to show on the global leaderboard (muse_game_set_global)
var friends: Array = []  # [{handle, displayName, avatar, avatarColor, state, app, activity, seenAt}]
var incoming: Array = []  # friend requests waiting on you: cards
var outgoing: Array = []  # ones you sent
var presence_live := false  # (friends' states come from muse_presence_friends; without it, just the list)
var rooms_live := false  # Muse's online party rooms answer (muse_game_invites): online parties show then
var activity := "title"  # what you're doing here: title, story or endless (set by those scenes)
var watching := 0  # screens showing your friends right now (they're looked at more often then)
var last_post := {}  # the last run posted, as the server answered (run_posted)

var _ping_timer: Timer
var _invites_timer: Timer
var _seen_invites := {}
var _friends_timer: Timer
var _refreshing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # (still on, and still pinging, while a climb's paused)
	MuseAccount.changed.connect(_on_account_changed)
	_ping_timer = _timer(PING_EVERY, ping)
	_friends_timer = _timer(FRIENDS_EVERY, func() -> void:
		if watching > 0:
			refresh())
	_invites_timer = _timer(INVITES_EVERY, _check_invites)
	invited.connect(_show_invite)
	if MuseAccount.is_signed_in() and not MuseAccount._is_froggy():
		get_tree().create_timer(MuseAccount.FIRST_CHECK_DELAY + 1.0).timeout.connect(refresh)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		if available and Time.get_ticks_msec() > (MuseAccount.FIRST_CHECK_DELAY + 1.0) * 1000.0:
			refresh()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_ping_timer.stop()  # (no "still here" while something's over the game)
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_ping_timer.stop()
		if is_member() and presence_live:
			MuseAccount.call_rpc("muse_presence_leave", {"p_app": APP})  # (friends see you go at once)


func is_member() -> bool:
	return available and MuseAccount.is_signed_in() and not me.is_empty()


func handle() -> String:
	return str(me.get("handle", ""))


func status() -> String:
	return my_status if my_status in STATUSES else "online"


## Looks again: whether Muse Social is there, you, your friends and what they're up to.
func refresh() -> void:
	if _refreshing:
		return
	if not MuseAccount.is_signed_in():
		_apply(false, {}, [], [], [])
		return
	_refreshing = true
	var r: Dictionary = await MuseAccount.call_rpc("muse_social_me")
	if r.code == 404:  # (not live yet)
		_refreshing = false
		_apply(false, {}, [], [], [])
		return
	if r.code != 200:
		_refreshing = false
		return  # offline or a hiccup: keep what there was
	var who: Dictionary = r.data if r.data is Dictionary else {}
	var list: Array = []
	var ins: Array = []
	var outs: Array = []
	if not who.is_empty():
		var f: Dictionary = await MuseAccount.call_rpc("muse_social_friends_list")
		if f.code == 200 and f.data is Dictionary:
			list = _cards(f.data.get("friends"))
			ins = _cards(f.data.get("incoming"))
			outs = _cards(f.data.get("outgoing"))
		var p: Dictionary = await MuseAccount.call_rpc("muse_presence_friends")
		presence_live = p.code == 200 and p.data is Array
		if presence_live:
			var states := {}
			for each in p.data:
				if each is Dictionary:
					states[str(each.get("handle", ""))] = each
			for card in list:
				card.merge(states.get(card.handle, {}), true)
			list.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
				return STATE_ORDER.find(str(x.get("state", "offline"))) < STATE_ORDER.find(str(y.get("state", "offline"))))
	_refreshing = false
	_apply(true, who, list, ins, outs)
	if is_member() and _ping_timer.is_stopped():
		ping()
		_ping_timer.start()
	if is_member():
		_check_invites()  # (and finds out whether online parties are open)


## "Still here, doing this" (every PING_EVERY while the game's in front, and when what you're doing
## changes), so your friends see you're on.
func ping() -> void:
	if not is_member() or not presence_live:
		return
	var r: Dictionary = await MuseAccount.call_rpc("muse_presence_ping", {"p_app": APP, "p_activity": activity, "p_joinable": Party.joinable()})
	if r.code == 200 and str(r.data) in STATUSES and str(r.data) != my_status:
		my_status = str(r.data)
		changed.emit()


func set_activity(what: String) -> void:
	if what == activity:
		return
	activity = what
	ping()


## Makes your Muse Social profile with this @handle, once you've agreed to the community rules
## (COMMUNITY_RULES): the same handle in every Muse app. Free accounts get the standard avatar and colour.
## "" when it's made, else what went wrong (a handle taken or not allowed, in Muse's words).
func save_profile(new_handle: String, accept_rules: bool) -> String:
	var bare := _bare(new_handle)
	var r: Dictionary = await MuseAccount.call_rpc("muse_social_save_profile", {"p_handle": bare, "p_display_name": bare,
		"p_bio": null, "p_avatar": null, "p_avatar_color": null, "p_profile_visibility": null,
		"p_library_visibility": null, "p_accept_rules": accept_rules})
	if r.code != 200:
		return _problem(r)
	await refresh()
	return ""


## Your status, for every Muse app: online, away, dnd or invisible. "" when it's set, else what went wrong.
func set_status(what: String) -> String:
	if not what in STATUSES:
		return "That isn't a status."
	var r: Dictionary = await MuseAccount.call_rpc("muse_presence_set_status", {"p_status": what})
	if r.code != 200:
		return _problem(r)
	my_status = str(r.data) if str(r.data) in STATUSES else what
	changed.emit()
	return ""


## Asks someone to be friends (by @handle). "requested", "friends", or what went wrong.
func add_friend(who: String) -> String:
	var r: Dictionary = await MuseAccount.call_rpc("muse_social_request_friend", {"p_handle": _bare(who)})
	if r.code == 200 and str(r.data) in ["requested", "friends"]:
		refresh()
		return str(r.data)
	return _problem(r)


func answer_request(who: String, accept: bool) -> String:
	return await _act("muse_social_respond_friend", {"p_handle": _bare(who), "p_accept": accept})


func unfriend(who: String) -> String:
	return await _act("muse_social_unfriend", {"p_handle": _bare(who)})


## Blocks someone: neither of you sees the other anywhere in Muse after, and any friendship ends.
func block(who: String) -> String:
	return await _act("muse_social_block", {"p_handle": _bare(who)})


## Reports someone's profile to the Muse team, for one of REPORT_REASONS.
func report(who: String, reason: String) -> String:
	return await _act("muse_social_report", {"p_kind": "profile", "p_handle": _bare(who), "p_collection": null,
		"p_reason": reason if reason in REPORT_REASONS else "other", "p_details": null})


# ── leaderboards ────────────────────────────────────────────────────────────────────────────────

## A ticket for one Endless run, asked for as it starts (the server times the run from here). "" when
## there's none to be had (signed out, no handle, offline, or not live).
func start_run() -> String:
	if not is_member():
		return ""
	var r: Dictionary = await MuseAccount.call_rpc("muse_game_start_run", {"p_game": GAME, "p_board": BOARD})
	if r.code == 200 and r.data is Dictionary:
		return str(r.data.get("run", ""))
	return ""


## Posts a finished run's log ({v, landings, flies, end_ms}). The server works the score out from it
## and checks it could have happened: {status: posted, held (too quick to believe till the Muse team
## looks) or rejected, score, height, reason, best: {score, height, isNew}, rankFriends, rankGlobal}, or
## {} when it couldn't be posted at all.
func submit_run(run: String, log: Dictionary) -> Dictionary:
	if run == "" or not is_member():
		return {}
	var r: Dictionary = await MuseAccount.call_rpc("muse_game_submit_run", {"p_run": run, "p_log": log})
	return r.data if r.code == 200 and r.data is Dictionary else {}


## Asks a friend into your online party: "sent", "joined" (they're in), "dnd" (they've asked not to be
## disturbed), or what went wrong.
func invite(who: String) -> String:
	if Party.online_room == "":
		return "Host an online party first (Play Together)."
	var r: Dictionary = await MuseAccount.call_rpc("muse_game_invite", {"p_to_handle": _bare(who), "p_room": Party.online_room})
	if r.code == 200 and r.data is Dictionary:
		return str(r.data.get("status", "sent"))
	return _problem(r)


## Yes or no to an invite. Yes goes into their party (Party.enter_room). "" or what went wrong.
func answer_invite(inv: Dictionary, accept: bool) -> String:
	var r: Dictionary = await MuseAccount.call_rpc("muse_game_invite_respond", {"p_id": inv.get("id"), "p_accept": accept})
	if r.code != 200:
		return _problem(r)
	if not accept:
		return ""
	if not (r.data is Dictionary):
		return "That invite ran out."
	return await Party.enter_room(r.data)


## New invites into friends' parties (each shown once), while you're not in one already.
func _check_invites() -> void:
	if not is_member() or Party.is_on():
		return
	var r: Dictionary = await MuseAccount.call_rpc("muse_game_invites", {"p_app": APP})
	if (r.code == 200) != rooms_live and (r.code == 200 or r.code == 404):
		rooms_live = r.code == 200
		changed.emit()
	if r.code != 200 or not (r.data is Array):
		return
	for inv in r.data:
		if inv is Dictionary and not _seen_invites.has(str(inv.get("id", ""))):
			_seen_invites[str(inv.get("id", ""))] = true
			invited.emit(inv)


func _show_invite(inv: Dictionary) -> void:
	if get_tree().root.has_node("InvitePopup"):
		return  # (one at a time; a later one waits for the next look)
	var popup := CanvasLayer.new()
	popup.name = "InvitePopup"
	popup.set_script(load("res://scenes/InvitePopup.gd"))
	popup.invite = inv
	get_tree().root.add_child(popup)


## Posts a finished run in the background (the scene that ran it may be gone by the answer): run_posted.
func post_run(run: String, log: Dictionary) -> void:
	last_post = await submit_run(run, log)
	run_posted.emit(last_post)


## The leaderboard, "friends" or "global": {rows: [{rank, card, score, height, me}], me: {rank, score,
## height} or null, onGlobal}, or {} when it couldn't be fetched. Global lists only those who chose to
## show there (set_global).
func leaderboard(scope: String, limit := 50) -> Dictionary:
	if not is_member():
		return {}
	var r: Dictionary = await MuseAccount.call_rpc("muse_game_leaderboard",
		{"p_game": GAME, "p_scope": scope, "p_limit": limit, "p_board": BOARD})
	if r.code != 200 or not (r.data is Dictionary):
		return {}
	on_global = r.data.get("onGlobal") == true
	return r.data


## Shows you on the global leaderboard, or stops. "" when it's done, else what went wrong.
func set_global(show: bool) -> String:
	var r: Dictionary = await MuseAccount.call_rpc("muse_game_set_global", {"p_show": show})
	if r.code != 200:
		return _problem(r)
	on_global = r.data == true
	changed.emit()
	return ""


# ── inside ──────────────────────────────────────────────────────────────────────────────────────

func _act(fn_name: String, args: Dictionary) -> String:
	var r: Dictionary = await MuseAccount.call_rpc(fn_name, args)
	if r.code == 200 or r.code == 204:
		refresh()
		return ""
	return _problem(r)


func _apply(is_there: bool, who: Dictionary, list: Array, ins: Array, outs: Array) -> void:
	available = is_there
	me = who
	friends = list
	incoming = ins
	outgoing = outs
	if not is_member():
		_ping_timer.stop()
		_invites_timer.stop()
	elif _invites_timer.is_stopped():
		_invites_timer.start()
	changed.emit()


func _on_account_changed() -> void:
	if MuseAccount.is_signed_in():
		refresh()
	else:
		_apply(false, {}, [], [], [])


static func _cards(value) -> Array:
	var out: Array = []
	if value is Array:
		for each in value:
			if each is Dictionary and str(each.get("handle", "")) != "":
				out.append(each.duplicate())
	return out


static func _bare(who: String) -> String:
	return who.strip_edges().trim_prefix("@").to_lower()


## What went wrong, in words: Muse Social's own message when it gave one.
static func _problem(r: Dictionary) -> String:
	if r.code == 0:
		return "Couldn't reach Muse. Check your connection and try again."
	if r.code == -1:
		return "Sign in to your Muse account first."
	var d: Dictionary = r.data if r.data is Dictionary else {}
	var said := str(d.get("message", ""))
	if said != "" and said.length() <= 120:
		return said
	return "Something went wrong (%d). Try again in a bit." % r.code


func _timer(every: float, then: Callable) -> Timer:
	var t := Timer.new()
	t.wait_time = every
	t.timeout.connect(then)
	add_child(t)
	return t
