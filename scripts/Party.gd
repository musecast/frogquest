extends Node
## Playing together: a party of up to MAX_PLAYERS frogs climbing the same Endless tower (one seed, so the
## same platforms; one clock, so the moving ones swing together), each on their own phone. One hosts and
## gets a party code; the others type it in. On the same Wi-Fi it's phone to phone over ENet (Godot's own
## networking), no server in between. Everyone's frog shows on everyone's screen in its own hat, skin and
## colour, with its name over it (name tags can be turned off).
##
## Online, anywhere, it goes through Muse instead (with a Muse @handle): a room in Muse's database (made
## by the host, joined by a friend's Join or an invite, or picked by Play with Anyone), and a relay that
## passes each frog on to the room (one WebSocket each; seats 1 to 16 stand in for the Wi-Fi's peer ids).
## Online, names are the room's own @handles, which Muse's word filter has passed, never typed ones.
##
## The code is the host's address on the Wi-Fi, its last two numbers (a home network's first two are
## the same for everyone on it): 192.168.1.37 is 1 and 37, written "0137" in base 36 as four letters
## and digits. A whole address (with dots) works too.
##
## A party climbs Endless or the story's World Tree (mode): the host picks when they start. On the World
## Tree everyone's in their own world (their own gate, talks, finale and ending: StoryParty.gd) and sees
## the others' frogs in it; whoever joins appears beside whoever they joined (beside). Signed in to Muse,
## a climb up the World Tree is with everyone online, without asking (climb_with_everyone: a public room
## Muse picks, friends first), unless with_everyone's turned off.

signal players_changed  # someone joined or left, or changed their look
signal started  # the climb starts (EndlessMode reads run_seed and the clock)
signal ended(why: String)  # the party's over for you: why, in words ("" when you left yourself)
signal frog_moved(peer: int, state: Array)  # a friend's frog: [x, y, animation, frame, flip, turn, score, metres]
signal relay_full  # Muse's relay turned a ticket away: its daily allowance is used up (back at 00:00 UTC)
signal race_said(peer: int, what: Dictionary)  # a racer's news, in a race: out, won, done (PartyRace)

const PORT := 47850
const MAX_PLAYERS := 16
const SEND_EVERY := 1.0 / 15.0  # seconds between your frog's updates to the others
const STILL_EVERY := 1.0  # (on the World Tree, a frog that hasn't moved is only sent this often, and a
                          # moving one every SEND_EVERY_BIG: it's online with everyone, through Muse's relay,
                          # which counts what it's sent against a daily allowance)
const SEND_EVERY_BIG := 1.0 / 10.0  # (in a big party, a bit less often: the host passes every frog on to
                                     # everyone, so its load grows with the square of the party)
const BIG_PARTY := 9
const SETTINGS_PATH := "user://party.cfg"
## Party colours, to tell frogs apart (0: his own green).
const COLORS := [Color(0, 0, 0, 0), Color(1.0, 0.42, 0.42), Color(1.0, 0.66, 0.28), Color(1.0, 0.9, 0.3),
	Color(0.42, 0.62, 1.0), Color(0.72, 0.48, 1.0), Color(1.0, 0.52, 0.84), Color(0.3, 0.9, 0.9)]

var players := {}  # peer id -> {name, hat, skin, color}: everyone in the party, you too
var run_seed := 0
var in_run := false  # climbing (or between climbs) with the party
var run_started_ms := 0  # when the party's climb started, on this phone's clock
const NAME := "lil froggy"  # (everyone's lil froggy: there's no name to give, only a Muse @handle to go by)
var my_name := NAME
var color := 0  # your party colour (COLORS)
var name_tags := true
var tethers := true  # a stretchy band to your nearest friend, that catches you falling
var with_everyone := true  # signed in, climbing the World Tree online with everyone (climb_with_everyone)
var told_names := false  # (been told a tap on a name adds, blocks or reports them: StoryParty, once)
var full_told_on := ""  # (the UTC day he was last told online's full: RoomFullPopup, once a day)
var settings_path := SETTINGS_PATH  # (the tests point it elsewhere)
var on_start := Callable()  # (what starting does; the tests swap it so the scene stays put)

var mode := "endless"  # what the party climbs: "endless" (one tower, one seed) or "story" (the World Tree)
var race := ""  # in Endless, what it races (PartyRace.ORDER: minute, sprint, flies, knockout), "" climbing together
var online_room := ""  # the Muse room you're in, online ("" on Wi-Fi or alone)
var everyone := false  # (that room's a public one, everyone online: climb_with_everyone)
var beside := ""  # whose side you appear at once their frog's seen (a name in players: "@avery"), "" for nobody
var ws_ticket_path := "/api/rooms/ticket"  # (on MuseAccount.MUSE_API)

var _send_left := 0.0
var _since_sent := 0.0
var _last_state := []
var _ws: WebSocketPeer  # online: the relay
var _seat := 0  # your seat in the room (0 until the relay's welcome)
var _host_seat := 0  # whoever's been in the room longest: they start the climb
var _ping_left := 0.0
var _tries := 0  # (a ticket that wouldn't open is tried once more)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # (the party carries on while your Endless is paused)
	_load()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(func() -> void: _end("The party ended: the host left, or the Wi-Fi dropped."))


func is_on() -> bool:
	if _ws != null:
		return _seat > 0 and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN
	var peer := multiplayer.multiplayer_peer
	return peer != null and not (peer is OfflineMultiplayerPeer) \
		and peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED


func is_online() -> bool:
	return _ws != null


func is_host() -> bool:
	if _ws != null:
		return is_on() and _seat == _host_seat
	return is_on() and multiplayer.is_server()


func me() -> int:
	if _ws != null:
		return _seat
	return multiplayer.get_unique_id() if is_on() else 0


## What friends see to join you by (Muse presence), online: {mode, room}; null otherwise.
func joinable():
	return {"mode": mode, "room": online_room} if online_room != "" else null


## Who's at a seat (or peer id), by their name in players: "@avery". "" for nobody.
func name_of(peer: int) -> String:
	return str(players.get(peer, {}).get("name", ""))


## The seat (or peer id) of whoever goes by this name in the party, 0 if they're not in it.
func peer_named(who: String) -> int:
	for peer in players:
		if str(players[peer].get("name", "")) == who and peer != me():
			return peer
	return 0


## The name others see over your frog: your Muse @handle, or the name you typed.
func display_name() -> String:
	if MuseSocial.is_member():
		return "@" + MuseSocial.handle()
	return NAME


func my_info() -> Dictionary:
	return {"name": display_name(), "hat": str(MusicManager.equipped_hat), "skin": str(MusicManager.equipped_skin), "color": color,
		"look": load("res://scripts/FroggyLook.gd").clean(MusicManager.look)}  # (your froggy as you made him, band and all)


## Starts a party here. "" when it's up (code() is what the others type), else what went wrong.
func host() -> String:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS)  # (one spare place, to tell a latecomer it's full)
	if err != OK:
		return "Couldn't start a party on this Wi-Fi (%s)." % error_string(err)
	multiplayer.multiplayer_peer = peer
	players = {1: my_info()}
	players_changed.emit()
	return ""


## Joins the party with that code. "" when it's on its way (players_changed once you're in, or ended).
func join(code: String) -> String:
	var ip := ip_for(code)
	if ip == "":
		return "That code doesn't look right: it's four letters and numbers."
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	if err != OK:
		return "Couldn't look for that party (%s)." % error_string(err)
	multiplayer.multiplayer_peer = peer
	return ""


## Leaves the party (ends it, for the host). Quietly: no ended signal, you know.
func leave() -> void:
	if _ws != null:
		var ws := _ws
		_ws = null  # (first, so its closing isn't taken for the party ending)
		ws.close()
	if online_room != "":
		MuseAccount.call_rpc("muse_game_room_leave", {"p_room": online_room})
		online_room = ""
		MuseSocial.ping()
	_seat = 0
	_host_seat = 0
	var peer := multiplayer.multiplayer_peer
	if peer != null and not (peer is OfflineMultiplayerPeer):
		peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players = {}
	in_run = false
	mode = "endless"
	race = ""
	everyone = false
	beside = ""
	players_changed.emit()


## The host starts everyone climbing: up the World Tree ("story"), or a new Endless tower (a new seed),
## climbing together or racing up it (`race_kind`: PartyRace.ORDER).
func start(what := "endless", race_kind := "") -> void:
	if not is_host():
		return
	var the_seed := randi()
	var r := race_kind if what == "endless" else ""
	if _ws != null:
		_relay({"data": {"t": "start", "seed": the_seed, "ago": 0, "mode": what, "race": r}})
		_begin(the_seed, 0, what, r)
	else:
		_start.rpc(the_seed, 0, what, r)


## Your news in a race, to the others (PartyRace): you're out, you've won, you're done.
func say_race(what: Dictionary) -> void:
	if not is_on() or players.size() < 2:
		return
	if _ws != null:
		_relay({"data": {"t": "r", "r": what}})
	else:
		_race.rpc(what)


# ── online ──────────────────────────────────────────────────────────────────────────────────────

## Hosts an online party: friends join from their Friends list, or by your invite. "" or what went wrong.
func host_online() -> String:
	return await _into_room("muse_game_room_create", {"p_app": MuseSocial.APP, "p_mode": "endless"})


## Joins a friend's online party (their Join), appearing beside them on the World Tree (who: "@avery").
## "" or what went wrong.
func join_room(room: String, who := "") -> String:
	var problem: String = await _into_room("muse_game_room_join", {"p_room": room})
	if problem == "":
		beside = who
	return problem


## Play with Anyone: Muse puts you in an open public party, or starts one. "" or what went wrong.
func play_with_anyone() -> String:
	return await _into_room("muse_game_quick_join", {"p_app": MuseSocial.APP, "p_mode": "endless"})


## Up the World Tree with everyone online: Muse puts you in a public room of climbers (friends' first),
## or starts one. Quietly, as a climb starts (StoryParty.gd). "" or what went wrong.
func climb_with_everyone() -> String:
	var problem: String = await _into_room("muse_game_quick_join", {"p_app": MuseSocial.APP, "p_mode": "story"})
	if problem == "":
		everyone = true
	return problem


## Into a room you're already in (an invite you said yes to): straight to its relay, beside whoever
## asked you.
func enter_room(room: Dictionary) -> String:
	var problem: String = await _connect_room(str(room.get("room", "")))
	if problem == "":
		mode = _mode_of(room)
		everyone = bool(room.get("public", false))
		if room.get("from") is Dictionary:
			beside = "@" + str(room.from.get("handle", ""))
	return problem


func _into_room(fn_name: String, args: Dictionary) -> String:
	if not MuseSocial.is_member():
		return "Sign in to your Muse account and pick an @handle to play online."
	var r: Dictionary = await MuseAccount.call_rpc(fn_name, args)
	if r.code == 404 and fn_name == "muse_game_quick_join":
		return "Play with Anyone isn't open yet."
	if r.code == 404:
		return "Online parties aren't open yet."
	if r.code != 200 or not (r.data is Dictionary):
		return MuseSocial._problem(r)
	var problem: String = await _connect_room(str(r.data.get("room", "")))
	if problem == "":
		mode = _mode_of(r.data)
		everyone = bool(r.data.get("public", false))  # (a public room: everyone online, strangers too)
	return problem


## What a room climbs, from Muse's summary of it: "story" or "endless".
static func _mode_of(room: Dictionary) -> String:
	return "story" if str(room.get("mode", "")) == "story" else "endless"


## A ticket from Muse's relay for the room, then its WebSocket. The welcome that follows seats you.
func _connect_room(room: String) -> String:
	if room == "":
		return "That party isn't there any more."
	if online_room != room:
		leave()
	online_room = room
	var t: Dictionary = await MuseAccount.call_api(ws_ticket_path, {"room": room})
	if t.code != 200 or not (t.data is Dictionary) or str(t.data.get("url", "")) == "":
		_let_go(room)
		if t.code == 429 or t.code >= 500:
			_tell_full()  # (its daily allowance used up, or Cloudflare's own: 429 or 5xx)
			return "Playing online is full for today: it's back at %s." % load("res://scenes/RoomFullPopup.gd").reset_words()
		return "Couldn't reach the party (%s)." % ("you're not in it" if t.code == 403 else "the relay said %d" % t.code)
	_ws = WebSocketPeer.new()
	if _ws.connect_to_url(str(t.data.url)) != OK:
		_ws = null
		_let_go(room)
		return "Couldn't reach the party."
	_ping_left = 25.0
	players = {}
	players_changed.emit()
	return ""


## Online's full for today (Muse's relay turned a ticket away): RoomFullPopup says so, and when it's
## back, at most once a UTC day.
func _tell_full() -> void:
	relay_full.emit()
	var today := Time.get_date_string_from_system(true)
	if full_told_on == today or not is_inside_tree():
		return
	full_told_on = today
	_save()
	get_tree().root.add_child(load("res://scenes/RoomFullPopup.gd").new())


## Out of a room we couldn't get into the relay for (its ticket refused: the relay's daily allowance
## used up, say): Muse lets the seat go at once, rather than holding it for nobody till it tidies up.
func _let_go(room: String) -> void:
	if online_room == room:
		online_room = ""
	MuseAccount.call_rpc("muse_game_room_leave", {"p_room": room})


func _process(delta: float) -> void:
	if _ws == null:
		return
	_ws.poll()
	match _ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			while _ws != null and _ws.get_available_packet_count() > 0:
				_on_relay(_ws.get_packet().get_string_from_utf8())
			_ping_left -= delta
			if _ws != null and _ping_left <= 0.0:
				_ping_left = 25.0
				_ws.send_text("ping")  # (keeps it open; free)
		WebSocketPeer.STATE_CLOSED:
			var code := _ws.get_close_code()
			var was_seated := _seat > 0
			var room := online_room
			_ws = null
			if not was_seated and _tries < 1 and room != "":
				_tries += 1  # (the ticket didn't take: once more, with a fresh one)
				_connect_room(room)
				return
			_tries = 0
			_end("You joined this party somewhere else." if code == 4000 else "Lost the online party.")


func _on_relay(text: String) -> void:
	if text == "pong":
		return
	var msg = JSON.parse_string(text)
	if not (msg is Dictionary):
		return
	if msg.has("sys"):
		match str(msg.sys):
			"welcome":
				_tries = 0
				_seat = int(msg.get("you", 0))
				_host_seat = int(msg.get("host", 0))
				players = {}
				for card in msg.get("players", []):
					if card is Dictionary:
						players[int(card.get("slot", 0))] = _look_of(card)
				var mine := my_info()
				mine.name = str(players.get(_seat, {}).get("name", mine.name))
				players[_seat] = mine
				_relay({"data": {"t": "look", "i": my_info()}})
				players_changed.emit()
				MuseSocial.ping()  # (friends see they can join)
				if mode == "story" and not in_run:
					_begin(0, 0, "story")  # (the World Tree has no start: you're climbing with them now)
			"join":
				var card: Dictionary = msg.get("player", {}) if msg.get("player") is Dictionary else {}
				var slot := int(card.get("slot", 0))
				_host_seat = int(msg.get("host", _host_seat))
				if slot > 0 and slot != _seat:
					players[slot] = _look_of(card, players.get(slot, {}))
					_relay({"to": slot, "data": {"t": "look", "i": my_info()}})
					if is_host() and in_run and mode == "endless":
						_relay({"to": slot, "data": {"t": "start", "seed": run_seed, "ago": Time.get_ticks_msec() - run_started_ms, "mode": mode, "race": race}})
					elif is_host() and in_run and not everyone:
						_relay({"to": slot, "data": {"t": "start", "seed": 0, "ago": 0, "mode": mode}})  # (up the World Tree with you)
				players_changed.emit()
			"leave":
				players.erase(int(msg.get("slot", 0)))
				_host_seat = int(msg.get("host", _host_seat))
				players_changed.emit()
		return
	var from := int(msg.get("from", 0))
	var d = msg.get("data")
	if from <= 0 or not (d is Dictionary):
		return
	match str(d.get("t", "")):
		"f":
			if d.get("s") is Array and d.s.size() >= 8:
				frog_moved.emit(from, d.s)
		"look":
			if d.get("i") is Dictionary:
				var look := _clean(d.i)
				look.name = str(players.get(from, {}).get("name", NAME))  # (the room's own @handle, not a typed name)
				players[from] = look
				players_changed.emit()
		"start":
			if from == _host_seat:
				_begin(int(d.get("seed", 0)), int(d.get("ago", 0)), "story" if str(d.get("mode", "")) == "story" else "endless",
					str(d.get("race", "")))
		"r":
			if d.get("r") is Dictionary:
				race_said.emit(from, d.r)


## A seat's look from the relay's card: their @handle (passed by Muse's filter), keeping any hat and
## colour they've shared.
func _look_of(card: Dictionary, before := {}) -> Dictionary:
	var look := _clean(before)
	var handle := str(card.get("handle", ""))
	look.name = "@" + handle if handle != "" else NAME
	return look


func _relay(msg: Dictionary) -> void:
	if _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(JSON.stringify(msg))


## Seconds since the party's climb started, on the clock everyone shares (moving platforms swing by it).
func run_seconds() -> float:
	return float(Time.get_ticks_msec() - run_started_ms) / 1000.0


## Your frog, sent to the others every SEND_EVERY while you climb (EndlessMode calls this each frame).
func send_frog(state: Array, delta: float) -> void:
	if not is_on() or players.size() < 2:
		return
	_send_left -= delta
	_since_sent += delta
	if _send_left > 0.0:
		return
	if mode == "story" and state == _last_state and _since_sent < STILL_EVERY:
		return  # (on the World Tree, still: now and then is enough)
	_send_left = SEND_EVERY if players.size() < BIG_PARTY and mode != "story" else SEND_EVERY_BIG
	_since_sent = 0.0
	_last_state = state
	if _ws != null:
		_relay({"data": {"t": "f", "s": state}})
	else:
		_frog.rpc(state)


## Changes your look for the others (a new hat or colour in the party screen or the wardrobe).
func share_look() -> void:
	if not is_on():
		return
	if _ws != null:
		var mine := my_info()
		mine.name = str(players.get(_seat, {}).get("name", mine.name))
		players[_seat] = mine
		_relay({"data": {"t": "look", "i": my_info()}})
		players_changed.emit()
		return
	if is_host():
		players[1] = my_info()
		_roster.rpc(players)
	else:
		_hello.rpc_id(1, my_info())


func set_color(i: int) -> void:
	color = clampi(i, 0, COLORS.size() - 1)
	_save()
	share_look()


func set_tethers(on: bool) -> void:
	tethers = on
	_save()
	players_changed.emit()


func set_name_tags(on: bool) -> void:
	name_tags = on
	_save()
	players_changed.emit()


## Been told about tapping names (StoryParty says so once).
func set_told_names() -> void:
	told_names = true
	_save()


## Climbing the World Tree with everyone online, or not (off: out of the room you're in, if it's that).
func set_with_everyone(on: bool) -> void:
	with_everyone = on
	_save()
	if not on and everyone:
		leave()
	players_changed.emit()


func set_my_name(typed: String) -> void:
	var clean := ""
	for ch in typed.strip_edges():
		if ch.unicode_at(0) >= 32 and ch.unicode_at(0) < 127:
			clean += ch
	my_name = clean.substr(0, 16) if clean != "" else NAME
	_save()
	share_look()


# ── codes ───────────────────────────────────────────────────────────────────────────────────────

## The code for this phone's party: its Wi-Fi address's last two numbers, as four letters and digits.
func code() -> String:
	var ip := local_ip()
	if ip == "":
		return ""
	var parts := ip.split(".")
	return String.num_int64(int(parts[2]) * 256 + int(parts[3]), 36).to_upper().lpad(4, "0")


## The address a code points at, on this phone's Wi-Fi ("" if it isn't a code). A whole address passes.
func ip_for(typed: String) -> String:
	var c := typed.strip_edges().to_lower().replace(" ", "").replace("-", "")
	if c.count(".") == 3 and c.is_valid_ip_address():
		return c
	if c.length() != 4:
		return ""
	var n := 0
	for ch in c:
		var digit := "0123456789abcdefghijklmnopqrstuvwxyz".find(ch)
		if digit < 0:
			return ""
		n = n * 36 + digit
	if n > 65535:
		return ""
	var mine := local_ip()
	if mine == "":
		return ""
	var parts := mine.split(".")
	return "%s.%s.%d.%d" % [parts[0], parts[1], n / 256, n % 256]


## This phone's address on the Wi-Fi (a private one, 192.168, 10 or 172.16 to 31), Wi-Fi first.
func local_ip() -> String:
	var best := ""
	for iface in IP.get_local_interfaces():
		var name := str(iface.get("name", "")).to_lower()
		for addr in iface.get("addresses", []):
			var a := str(addr)
			if not _private(a):
				continue
			if name in ["en0", "wlan0", "wi-fi", "wifi"] or name.begins_with("wl"):
				return a  # (Wi-Fi itself: never the phone's cellular address)
			if best == "" and not name.begins_with("pdp_ip") and not name.begins_with("rmnet"):
				best = a
	return best


static func _private(a: String) -> bool:
	if a.count(".") != 3:
		return false
	var p := a.split(".")
	var one := int(p[0])
	var two := int(p[1])
	return (one == 192 and two == 168) or one == 10 or (one == 172 and two >= 16 and two <= 31)


# ── over the network ────────────────────────────────────────────────────────────────────────────

func _on_connected() -> void:
	_hello.rpc_id(1, my_info())


func _on_failed() -> void:
	_end("Couldn't find that party. Check you're both on the same Wi-Fi, and the code.")


func _on_peer_connected(_id: int) -> void:
	pass  # (they say hello once they're in: _hello)


func _on_peer_disconnected(id: int) -> void:
	if is_host() and players.has(id):
		players.erase(id)
		_roster.rpc(players)


## Someone says who they are (joining, or a new look). The host keeps the list, and catches latecomers
## up with the climb.
@rpc("any_peer", "call_remote", "reliable")
func _hello(info: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var who := multiplayer.get_remote_sender_id()
	var new := not players.has(who)
	if new and players.size() >= MAX_PLAYERS:
		_full.rpc_id(who)
		get_tree().create_timer(0.5).timeout.connect(func() -> void:
			if is_host():
				multiplayer.multiplayer_peer.disconnect_peer(who))
		return
	players[who] = _clean(info)
	_roster.rpc(players)
	if new and in_run:
		_start.rpc_id(who, run_seed, Time.get_ticks_msec() - run_started_ms, mode, race)


@rpc("authority", "call_remote", "reliable")
func _full() -> void:
	_end("That party's full: %d frogs is the most." % MAX_PLAYERS)


@rpc("authority", "call_local", "reliable")
func _roster(all: Dictionary) -> void:
	players = {}
	for id in all:
		players[int(id)] = _clean(all[id])
	players_changed.emit()


@rpc("authority", "call_local", "reliable")
func _start(the_seed: int, ago_ms: int, what := "endless", race_kind := "") -> void:
	_begin(the_seed, ago_ms, "story" if what == "story" else "endless", race_kind)


@rpc("any_peer", "call_remote", "reliable")
func _race(what: Dictionary) -> void:
	race_said.emit(multiplayer.get_remote_sender_id(), what)


## The climb starts (or a latecomer catches up with it): everyone on the same tower and clock, or up
## the World Tree, each in their own world, those who joined appearing beside the host (beside) unless
## they came for someone else.
func _begin(the_seed: int, ago_ms: int, what := "endless", race_kind := "") -> void:
	run_seed = the_seed
	run_started_ms = Time.get_ticks_msec() - ago_ms
	in_run = true
	mode = what
	race = race_kind if what == "endless" and race_kind in load("res://scripts/PartyRace.gd").ORDER else ""
	if what == "story" and beside == "" and not is_host() and not everyone:
		beside = name_of(_host_seat if _ws != null else 1)
	started.emit()
	if on_start.is_valid():
		on_start.call()
	elif what == "story":
		var here := get_tree().current_scene
		if here == null or here.scene_file_path != "res://scenes/Main.tscn":
			get_tree().change_scene_to_file("res://scenes/Main.tscn")  # (StoryParty takes it from there)
	else:
		get_tree().change_scene_to_file("res://scenes/EndlessMode.tscn")


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _frog(state: Array) -> void:
	if state.size() >= 8:
		frog_moved.emit(multiplayer.get_remote_sender_id(), state)


func _end(why: String) -> void:
	leave()
	ended.emit(why)


static func _clean(info) -> Dictionary:
	var d: Dictionary = info if info is Dictionary else {}
	return {"name": str(d.get("name", NAME)).substr(0, 21), "hat": str(d.get("hat", "")),
		"skin": str(d.get("skin", "")), "color": clampi(int(d.get("color", 0)), 0, COLORS.size() - 1),
		"look": load("res://scripts/FroggyLook.gd").clean(d.get("look"))}


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) != OK:
		return
	my_name = str(cfg.get_value("party", "name", my_name))
	color = clampi(int(cfg.get_value("party", "color", color)), 0, COLORS.size() - 1)
	name_tags = bool(cfg.get_value("party", "name_tags", name_tags))
	tethers = bool(cfg.get_value("party", "tethers", tethers))
	with_everyone = bool(cfg.get_value("party", "with_everyone", with_everyone))
	told_names = bool(cfg.get_value("party", "told_names", told_names))
	full_told_on = str(cfg.get_value("party", "full_told_on", full_told_on))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("party", "name", my_name)
	cfg.set_value("party", "color", color)
	cfg.set_value("party", "name_tags", name_tags)
	cfg.set_value("party", "tethers", tethers)
	cfg.set_value("party", "with_everyone", with_everyone)
	cfg.set_value("party", "told_names", told_names)
	cfg.set_value("party", "full_told_on", full_told_on)
	cfg.save(settings_path)
