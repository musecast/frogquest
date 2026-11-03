extends Node
## Playing together: a party of up to MAX_PLAYERS frogs climbing the same Endless tower (one seed, so the
## same platforms; one clock, so the moving ones swing together), each on their own phone. One hosts and
## gets a party code; the others type it in. On the same Wi-Fi it's phone to phone over ENet (Godot's own
## networking), no server in between. Everyone's frog shows on everyone's screen in its own hat, skin and
## colour, with its name over it (name tags can be turned off). Online parties, through Muse's relay, are
## to connect here too, as a second way in.
##
## The code is the host's address on the Wi-Fi, its last two numbers (a home network's first two are
## the same for everyone on it): 192.168.1.37 is 1 and 37, written "0137" in base 36 as four letters
## and digits. A whole address (with dots) works too.

signal players_changed  # someone joined or left, or changed their look
signal started  # the climb starts (EndlessMode reads run_seed and the clock)
signal ended(why: String)  # the party's over for you: why, in words ("" when you left yourself)
signal frog_moved(peer: int, state: Array)  # a friend's frog: [x, y, animation, frame, flip, turn, score, metres]

const PORT := 47850
const MAX_PLAYERS := 8
const SEND_EVERY := 1.0 / 15.0  # seconds between your frog's updates to the others
const SETTINGS_PATH := "user://party.cfg"
## Party colours, to tell frogs apart (0: his own green).
const COLORS := [Color(0, 0, 0, 0), Color(1.0, 0.42, 0.42), Color(1.0, 0.66, 0.28), Color(1.0, 0.9, 0.3),
	Color(0.42, 0.62, 1.0), Color(0.72, 0.48, 1.0), Color(1.0, 0.52, 0.84), Color(0.3, 0.9, 0.9)]

var players := {}  # peer id -> {name, hat, skin, color}: everyone in the party, you too
var run_seed := 0
var in_run := false  # climbing (or between climbs) with the party
var run_started_ms := 0  # when the party's climb started, on this phone's clock
var my_name := "Froggy"  # (when there's no Muse @handle to go by)
var color := 0  # your party colour (COLORS)
var name_tags := true
var settings_path := SETTINGS_PATH  # (the tests point it elsewhere)
var on_start := Callable()  # (what starting does; the tests swap it so the scene stays put)

var _send_left := 0.0
var _last_state := []


func _ready() -> void:
	_load()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(func() -> void: _end("The party ended: the host left, or the Wi-Fi dropped."))


func is_on() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer != null and not (peer is OfflineMultiplayerPeer) \
		and peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED


func is_host() -> bool:
	return is_on() and multiplayer.is_server()


func me() -> int:
	return multiplayer.get_unique_id() if is_on() else 0


## The name others see over your frog: your Muse @handle, or the name you typed.
func display_name() -> String:
	if MuseSocial.is_member():
		return "@" + MuseSocial.handle()
	return my_name


func my_info() -> Dictionary:
	return {"name": display_name(), "hat": str(MusicManager.equipped_hat), "skin": str(MusicManager.equipped_skin), "color": color}


## Starts a party here. "" when it's up (code() is what the others type), else what went wrong.
func host() -> String:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS - 1)
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
	var peer := multiplayer.multiplayer_peer
	if peer != null and not (peer is OfflineMultiplayerPeer):
		peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players = {}
	in_run = false
	players_changed.emit()


## The host starts everyone climbing: a new tower (a new seed) for all.
func start() -> void:
	if is_host():
		_start.rpc(randi(), 0)


## Seconds since the party's climb started, on the clock everyone shares (moving platforms swing by it).
func run_seconds() -> float:
	return float(Time.get_ticks_msec() - run_started_ms) / 1000.0


## Your frog, sent to the others every SEND_EVERY while you climb (EndlessMode calls this each frame).
func send_frog(state: Array, delta: float) -> void:
	if not is_on() or players.size() < 2:
		return
	_send_left -= delta
	if _send_left > 0.0 and state == _last_state:
		return
	if _send_left > 0.0:
		return
	_send_left = SEND_EVERY
	_last_state = state
	_frog.rpc(state)


## Changes your look for the others (a new hat or colour in the party screen or the wardrobe).
func share_look() -> void:
	if not is_on():
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


func set_name_tags(on: bool) -> void:
	name_tags = on
	_save()
	players_changed.emit()


func set_my_name(typed: String) -> void:
	var clean := ""
	for ch in typed.strip_edges():
		if ch.unicode_at(0) >= 32 and ch.unicode_at(0) < 127:
			clean += ch
	my_name = clean.substr(0, 16) if clean != "" else "Froggy"
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
	players[who] = _clean(info)
	_roster.rpc(players)
	if new and in_run:
		_start.rpc_id(who, run_seed, Time.get_ticks_msec() - run_started_ms)


@rpc("authority", "call_local", "reliable")
func _roster(all: Dictionary) -> void:
	players = {}
	for id in all:
		players[int(id)] = _clean(all[id])
	players_changed.emit()


@rpc("authority", "call_local", "reliable")
func _start(the_seed: int, ago_ms: int) -> void:
	run_seed = the_seed
	run_started_ms = Time.get_ticks_msec() - ago_ms
	in_run = true
	started.emit()
	if on_start.is_valid():
		on_start.call()
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
	return {"name": str(d.get("name", "Froggy")).substr(0, 21), "hat": str(d.get("hat", "")),
		"skin": str(d.get("skin", "")), "color": clampi(int(d.get("color", 0)), 0, COLORS.size() - 1)}


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) != OK:
		return
	my_name = str(cfg.get_value("party", "name", my_name))
	color = clampi(int(cfg.get_value("party", "color", color)), 0, COLORS.size() - 1)
	name_tags = bool(cfg.get_value("party", "name_tags", name_tags))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("party", "name", my_name)
	cfg.set_value("party", "color", color)
	cfg.set_value("party", "name_tags", name_tags)
	cfg.save(settings_path)
