extends RefCounted
## Endless mode's climb, from Froggy's pond up to space: each zone's name, where it starts (in world
## units above the first lily pad; 10 to a metre), its sky, its platforms and what they get up to.
## Everything ramps from a zone's "from" value at its start to its "to" value at its end (space goes on
## ramping for SPACE_RAMP more units). EndlessMode.gd builds the climb from this; EndlessSky.gd paints it.

const SPACE_RAMP := 5000.0
const BLEND := 300.0  # the skies of two zones blend over this much height either side of the line

const ZONES := [
	{
		"name": "MUSHROOM SWAMP", "from": 0.0,
		"sky": [Color(0.66, 0.88, 0.78), Color(0.25, 0.52, 0.45)],  # top, bottom
		"kinds": [["mushroom", 1.0]],
		"spring_kind": "mushroom_red", "crumble_kind": "",
		"spring": [0.0, 0.14], "crumble": [0.0, 0.0], "moving": [0.0, 0.0], "tilt": [0.0, 0.0],
		"width": [[100.0, 124.0], [90.0, 112.0]], "gap": [[52.0, 70.0], [58.0, 80.0]],
		"speed": [0.6, 0.8], "range": [30.0, 40.0], "bob": 0.0,
		"flies": 0.45, "gravity": 1.0, "dust": Color(0.78, 0.92, 0.62),
	},
	{
		"name": "THE TREETOPS", "from": 1200.0,
		"sky": [Color(0.31, 0.50, 0.30), Color(0.10, 0.20, 0.12)],
		"kinds": [["canopy", 1.0]],
		"spring_kind": "", "crumble_kind": "twig",
		"spring": [0.06, 0.10], "crumble": [0.05, 0.16], "moving": [0.08, 0.22], "tilt": [0.0, 0.0],
		"width": [[88.0, 112.0], [80.0, 104.0]], "gap": [[58.0, 80.0], [62.0, 86.0]],
		"speed": [0.6, 1.2], "range": [30.0, 60.0], "bob": 0.0,
		"flies": 0.35, "gravity": 1.0, "dust": Color(0.45, 0.80, 0.42),
	},
	{
		"name": "THE CLOUDS", "from": 3200.0,
		"sky": [Color(0.27, 0.56, 0.95), Color(0.68, 0.87, 1.0)],
		"kinds": [["cloud", 1.0]],
		"spring_kind": "", "crumble_kind": "puff",
		"spring": [0.08, 0.12], "crumble": [0.12, 0.25], "moving": [0.15, 0.30], "tilt": [0.0, 0.0],
		"width": [[84.0, 108.0], [76.0, 100.0]], "gap": [[62.0, 84.0], [66.0, 90.0]],
		"speed": [0.8, 1.6], "range": [40.0, 90.0], "bob": 0.0,
		"flies": 0.30, "gravity": 1.0, "dust": Color(1.0, 1.0, 1.0),
	},
	{
		"name": "SUNSET SKY", "from": 5600.0,
		"sky": [Color(0.20, 0.13, 0.40), Color(1.0, 0.62, 0.38)],
		"kinds": [["island", 1.0]],
		"spring_kind": "", "crumble_kind": "island_crack",
		"spring": [0.10, 0.14], "crumble": [0.10, 0.20], "moving": [0.25, 0.40], "tilt": [0.0, 0.0],
		"width": [[76.0, 100.0], [68.0, 92.0]], "gap": [[64.0, 86.0], [68.0, 92.0]],
		"speed": [0.9, 1.8], "range": [40.0, 100.0], "bob": 0.45,
		"flies": 0.30, "gravity": 1.0, "dust": Color(0.86, 0.56, 0.38),
	},
	{
		"name": "OUTER SPACE", "from": 8400.0,
		"sky": [Color(0.02, 0.015, 0.06), Color(0.11, 0.07, 0.24)],
		"kinds": [["asteroid", 0.7], ["satellite", 0.3]],
		"spring_kind": "", "crumble_kind": "asteroid_crack",
		"spring": [0.08, 0.10], "crumble": [0.15, 0.25], "moving": [0.30, 0.45], "tilt": [0.0, 0.33],
		"width": [[66.0, 96.0], [58.0, 88.0]], "gap": [[90.0, 130.0], [100.0, 140.0]],
		"speed": [0.9, 2.0], "range": [40.0, 110.0], "bob": 0.5,
		"flies": 0.25, "gravity": 0.6, "dust": Color(0.75, 0.72, 0.85),
	},
]


## Which zone a height is in.
static func index_at(height: float) -> int:
	var i := 0
	for z in ZONES.size():
		if height >= ZONES[z]["from"]:
			i = z
	return i


## How far through its zone a height is, 0 to 1 (space: over SPACE_RAMP).
static func progress_at(height: float) -> float:
	var i := index_at(height)
	var start: float = ZONES[i]["from"]
	var end: float = ZONES[i + 1]["from"] if i + 1 < ZONES.size() else start + SPACE_RAMP
	return clampf((height - start) / (end - start), 0.0, 1.0)


## A zone value ramped to a height: value is [from, to] (numbers, or [min, max] pairs).
static func ramp(value: Array, t: float):
	if value[0] is Array:
		return [lerpf(value[0][0], value[1][0], t), lerpf(value[0][1], value[1][1], t)]
	return lerpf(value[0], value[1], t)


## Each zone's share of the sky at a height (they blend across each line), summing to 1.
static func weights_at(height: float) -> PackedFloat32Array:
	var w := PackedFloat32Array()
	w.resize(ZONES.size())
	var i := index_at(height)
	w[i] = 1.0
	# toward the next zone up
	if i + 1 < ZONES.size():
		var line: float = ZONES[i + 1]["from"]
		var k := clampf((height - (line - BLEND)) / (BLEND * 2.0), 0.0, 1.0)
		if k > 0.0:
			w[i] = 1.0 - k
			w[i + 1] = k
	# from the zone below
	if i > 0:
		var line: float = ZONES[i]["from"]
		var k := clampf((height - (line - BLEND)) / (BLEND * 2.0), 0.0, 1.0)
		if k < 1.0:
			w[i - 1] = 1.0 - k
			w[i] = k
	return w


## Gravity's share at a height (space is floatier), blended across space's line like the sky.
static func gravity_at(height: float) -> float:
	var w := weights_at(height)
	var g := 0.0
	for z in ZONES.size():
		g += w[z] * float(ZONES[z]["gravity"])
	return g


## The sky's top and bottom colours at a height.
static func sky_at(height: float) -> Array:
	var w := weights_at(height)
	var top := Color(0, 0, 0, 0)
	var bottom := Color(0, 0, 0, 0)
	for z in ZONES.size():
		if w[z] > 0.0:
			top += ZONES[z]["sky"][0] * w[z]
			bottom += ZONES[z]["sky"][1] * w[z]
	top.a = 1.0
	bottom.a = 1.0
	return [top, bottom]
