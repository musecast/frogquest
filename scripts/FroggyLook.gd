extends RefCounted
## Your froggy (MusicManager.look), made in the intro (CreatorIntro) and changed in the wardrobe: his
## body's colour, his belly's, a pattern over his body and its colour, his eyes', and his stretchy band's
## (the tether, when you climb with friends). Froggy's own frames are never redrawn: a shader recolours
## his mint body, cream belly and black eyes, keeping their shading and soft edges (FroggyLook.material).
## Friends online see your froggy as you made him (Party sends the look). Each list's first is Froggy's own.

## [name, colour]: the light tone of his body (his own mint is the first); its shade follows.
const BODY := [["Mint", Color(0.627, 1.0, 0.671)], ["Lime", Color(0.80, 1.0, 0.45)], ["Forest", Color(0.40, 0.80, 0.42)],
	["Teal", Color(0.42, 0.96, 0.88)], ["Sky", Color(0.58, 0.83, 1.0)], ["Ocean", Color(0.38, 0.58, 1.0)],
	["Lilac", Color(0.80, 0.68, 1.0)], ["Grape", Color(0.64, 0.45, 0.96)], ["Bubblegum", Color(1.0, 0.64, 0.86)],
	["Cherry", Color(1.0, 0.45, 0.48)], ["Tangerine", Color(1.0, 0.68, 0.36)], ["Lemon", Color(1.0, 0.95, 0.46)],
	["Cocoa", Color(0.74, 0.54, 0.40)], ["Stone", Color(0.74, 0.76, 0.80)], ["Snow", Color(0.97, 0.98, 1.0)],
	["Midnight", Color(0.36, 0.37, 0.50)]]
const BELLY := [["Cream", Color(0.988, 1.0, 0.804)], ["Snow", Color(1.0, 1.0, 1.0)], ["Peach", Color(1.0, 0.86, 0.73)],
	["Sunny", Color(1.0, 0.93, 0.52)], ["Pink", Color(1.0, 0.83, 0.91)], ["Mint", Color(0.82, 1.0, 0.87)],
	["Sky", Color(0.83, 0.92, 1.0)], ["Lavender", Color(0.91, 0.85, 1.0)]]
const EYES := [["Black", Color(0.0, 0.0, 0.0)], ["Brown", Color(0.36, 0.21, 0.10)], ["Blue", Color(0.10, 0.27, 0.62)],
	["Green", Color(0.08, 0.40, 0.16)], ["Purple", Color(0.34, 0.13, 0.52)], ["Red", Color(0.56, 0.08, 0.10)]]
const PATTERNS := ["None", "Spots", "Stripes", "Freckles", "Two-Tone", "Hearts", "Stars"]
const BANDS := [["Sunny", Color(1.0, 0.82, 0.30)], ["Sky", Color(0.45, 0.76, 1.0)], ["Mint", Color(0.50, 1.0, 0.76)],
	["Lilac", Color(0.76, 0.62, 1.0)], ["Coral", Color(1.0, 0.58, 0.46)], ["Snow", Color(0.95, 0.97, 1.0)],
	["Lime", Color(0.72, 1.0, 0.36)], ["Ocean", Color(0.28, 0.56, 1.0)], ["Berry", Color(0.86, 0.32, 0.62)],
	["Orange", Color(1.0, 0.62, 0.22)], ["Teal", Color(0.26, 0.86, 0.80)]]


## Froggy's own look (and what anyone who hasn't made theirs is).
static func defaults() -> Dictionary:
	return {"body": 0, "belly": 0, "pattern": 0, "pattern_colour": 2, "eyes": 0, "band": 0}


## A look with every field there and in range (from a save, or a friend's phone).
static func clean(look) -> Dictionary:
	var d: Dictionary = look if look is Dictionary else {}
	var out := defaults()
	for key in out:
		out[key] = int(d.get(key, out[key]))
	out.body = clampi(out.body, 0, BODY.size() - 1)
	out.belly = clampi(out.belly, 0, BELLY.size() - 1)
	out.pattern = clampi(out.pattern, 0, PATTERNS.size() - 1)
	out.pattern_colour = clampi(out.pattern_colour, 0, BODY.size() - 1)
	out.eyes = clampi(out.eyes, 0, EYES.size() - 1)
	out.band = clampi(out.band, 0, BANDS.size() - 1)
	return out


static func band_colour(look) -> Color:
	return BANDS[clean(look).band][1]


# ── his look, on him ────────────────────────────────────────────────────────────────────────────

## The skins (effects) over your froggy, by what MusicManager.equipped_skin holds: the shader's number.
const EFFECTS := {"": 0, "shiny": 1, "rainbow": 2, "glow": 3, "ghost": 4, "starry": 5, "holo": 6, "shadow": 7,
	"golden_skin": 8, "grayscale_skin": 9}  # (the Negative skin keeps its own shader: see material())


## His body's material: your look, with a skin's effect over it ("" for none), and how much of him is
## still the frog god's shadow (the intro fills him in from 1 to 0).
static func material(look, skin := "", shadow := 0.0) -> ShaderMaterial:
	if skin == "negative_skin" and shadow <= 0.0:
		# (the Negative skin is a window: the screen behind him, turned over, through his shape, as it always
		# was; so it's its own shader, and his colours don't show through it)
		var negative := ShaderMaterial.new()
		negative.shader = load("res://assets/negative.gdshader")
		return negative
	var l := clean(look)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/froggy_look.gdshader")
	mat.set_shader_parameter("body_colour", BODY[l.body][1])
	mat.set_shader_parameter("belly_colour", BELLY[l.belly][1])
	mat.set_shader_parameter("eye_colour", EYES[l.eyes][1])
	mat.set_shader_parameter("pattern", l.pattern)
	mat.set_shader_parameter("pattern_colour", BODY[l.pattern_colour][1])
	mat.set_shader_parameter("effect", int(EFFECTS.get(skin, 0)))
	mat.set_shader_parameter("effect_colour", BANDS[l.band][1])
	mat.set_shader_parameter("shadow_amount", shadow)
	return mat


## Your look, in words: "Mint, spots".
static func describe(look) -> String:
	var l := clean(look)
	return "%s%s" % [BODY[l.body][0], "" if l.pattern == 0 else ", " + PATTERNS[l.pattern].to_lower()]


# ── hats drawn here, on his own pixel grid ──────────────────────────────────────────────────────

## [name, rows (a letter per pixel: "." nothing), colours, lift (pixels above his head), starter]. The
## first five are yours from the start (the intro offers them); the rest you unlock (UNLOCKS). The
## crown, wiz hat and cake hat are his old ones, drawn as art (player.tscn), not here.
const K := Color(0.13, 0.08, 0.07)
const HATS := {
	"bow": ["Bow", [".KKK.....KKK.", "KPPPK...KPPPK", "KPPPPKKKPPPPK", "KPPPPKpKPPPPK", "KPPPPKKKPPPPK", "KPPPK...KPPPK",
		".KKK.....KKK."], {"P": Color(1.0, 0.47, 0.68), "p": Color(0.78, 0.26, 0.46)}, 0, true],
	"beanie": ["Beanie", ["..........KK..........", ".........KWWK.........", ".......KKKWWKKK.......", ".....KKBBBBBBBBKK.....",
		"...KKBBBBBBBBBBBBKK...", "..KBBBBBBBBBBBBBBBBK..", ".KBBBBBBBBBBBBBBBBBBK.", "KBbBBbBBbBBbBBbBBbBBbK",
		"KbbbbbbbbbbbbbbbbbbbbK", "KKKKKKKKKKKKKKKKKKKKKK"],
		{"B": Color(0.33, 0.53, 0.95), "b": Color(0.22, 0.36, 0.72), "W": Color(0.97, 0.97, 1.0)}, 0, true],
	"leaf": ["Leaf", ["....KK..", "...KGGK.", "..KGGGgK", ".KGGGgGK", ".KGGgGGK", "..KgGGK.", "...KgK..", "....K...", "....K..."],
		{"G": Color(0.46, 0.86, 0.36), "g": Color(0.28, 0.60, 0.22)}, 0, true],
	"flower": ["Flower", ["....KKK....", "..KKWWWKK..", ".KWWKWKWWK.", "KWWKYYYKWWK", "KWKYYYYYKWK", "KWWKYYYKWWK",
		".KWWKWKWWK.", "..KKWWWKK..", "....KgK....", ".....K....."],
		{"W": Color(0.98, 0.98, 1.0), "Y": Color(1.0, 0.84, 0.25), "g": Color(0.30, 0.62, 0.24)}, 0, true],
	"cap": ["Cap", [".....KKKKKKKK.........", "...KKRRRRRRRRKK.......", "..KRRRRRRRRRRRRK......", ".KRRRRRRWRRRRRRRK.....",
		".KRRRRRRRRRRRRRRRKKKKK", ".KrrrrrrrrrrrrrrrrrrrK", "..KKKKKKKKKKKKKKKKKKK."],
		{"R": Color(0.92, 0.27, 0.25), "r": Color(0.68, 0.16, 0.16), "W": Color(1.0, 1.0, 1.0)}, 0, true],
	"tophat": ["Top Hat", ["...KKKKKKKKKK...", "...KDdDDDDDDK...", "...KDdDDDDDDK...", "...KDdDDDDDDK...", "...KDdDDDDDDK...",
		"...KDdDDDDDDK...", "...KRRRRRRRRK...", "...KRRRRRRRRK...", "KKKKKKKKKKKKKKKK", "KDDDDDDDDDDDDDDK", "KKKKKKKKKKKKKKKK"],
		{"D": Color(0.17, 0.15, 0.21), "d": Color(0.30, 0.27, 0.36), "R": Color(0.86, 0.22, 0.27)}, 0, false],
	"partyhat": ["Party Hat", [".....W.....", "....WWW....", ".....K.....", "....KPK....", "....KYK....", "...KPPPK...",
		"...KYYYK...", "..KPPPPPK..", "..KYYYYYK..", ".KPPPPPPPK.", ".KYYYYYYYK.", "KPPPPPPPPPK", "KKKKKKKKKKK"],
		{"P": Color(0.36, 0.62, 1.0), "Y": Color(1.0, 0.86, 0.30), "W": Color(1.0, 0.55, 0.75)}, 0, false],
	"halo": ["Halo", ["...KKKKKKKKKKKK...", ".KKYyyyyyyyyyyYKK.", "KYYK..........KYYK", ".KKYYYYYYYYYYYYKK.", "...KKKKKKKKKKKK..."],
		{"Y": Color(1.0, 0.86, 0.34), "y": Color(1.0, 0.97, 0.72)}, 5, false],
	"lilypad": ["Lily Pad", [".........KKK..........", "........KFFFK.........", "...KKKKKKFyFKKKKKKK...", ".KKGGGGGGKFKGGGGGGGKK.",
		"KGGGgGGGGGGGGGGGgGGGGK", "KGGGGGGGGgGGGGGGGGGGGK", ".KKKKKKKKKKKKKKKKKKKK."],
		{"G": Color(0.42, 0.78, 0.36), "g": Color(0.30, 0.60, 0.26), "F": Color(1.0, 0.70, 0.86), "y": Color(1.0, 0.90, 0.40)}, 0, false],
	"mushroom": ["Mushroom", [".......KKKKKKKK.......", "....KKKRRRRWWRRKKK....", "...KRRWWRRRRRRRRRRK...", "..KRRRWWRRRRRRWWRRRK..",
		".KRRRRRRRRRRRRWWRRRRK.", "KRRWWRRRRRRWWRRRRRRRRK", "KRRWWRRRRRRWWRRRRRWWRK", "KrrrrrrrrrrrrrrrrrrrrK", ".KKKKKKKKKKKKKKKKKKKK."],
		{"R": Color(0.92, 0.25, 0.24), "r": Color(0.68, 0.16, 0.16), "W": Color(1.0, 0.97, 0.94)}, 0, false],
}
static var _hat_cache := {}


## A hat drawn here (HATS), as a picture to wear (nearest filtered, on his grid): null for his old
## hats, which are art, and for none.
static func hat_texture(id: String) -> Texture2D:
	if not HATS.has(id):
		return null
	if _hat_cache.has(id):
		return _hat_cache[id]
	var rows: Array = HATS[id][1]
	var colours: Dictionary = HATS[id][2]
	var w := 0
	for r in rows:
		w = maxi(w, str(r).length())
	var img := Image.create(w, rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		var r := str(rows[y])
		for x in r.length():
			var ch := r[x]
			if ch == "K":
				img.set_pixel(x, y, K)
			elif colours.has(ch):
				img.set_pixel(x, y, colours[ch])
	var tex := ImageTexture.create_from_image(img)
	_hat_cache[id] = tex
	return tex


## Where a hat drawn here goes on his head (lift: higher; the halo floats). These are drawn in front of
## him, their bottom edge over the top of his head, so they're worn; the crowns and the wizard's and
## the cake hats (his own art) sit behind it, as they always have.
static func hat_offset(id: String) -> Vector2:
	var tex := hat_texture(id)
	if tex == null:
		return Vector2.ZERO
	return Vector2(0.0, -tex.get_height() * 0.5 - float(HATS[id][3]))


## The hats that are yours from the start (the intro's): none, then the starters.
static func starter_hats() -> Array:
	var out := [""]
	for id in HATS:
		if HATS[id][4]:
			out.append(id)
	return out


# ── what you can unlock, and how ────────────────────────────────────────────────────────────────

## [type, name, how]: the hats and skins found by playing, new and old (the wardrobe's list, and its
## "Still to find"). Each is unlocked where it happens (MusicManager.unlock).
const UNLOCKS := {
	"froggycrown": ["hat", "Froggy Crown", "Beat Frog Quest"],
	"blackcrown": ["hat", "Black Crown", "Score 100 in Endless"],
	"wizhat": ["hat", "Wiz Hat", "Find the wizard frog in the World Tree"],
	"cakehat": ["hat", "Cake Hat", "Find the cake in the World Tree"],
	"tophat": ["hat", "Top Hat", "Score 150 in Endless"],
	"partyhat": ["hat", "Party Hat", "Climb with a friend (Play Together)"],
	"halo": ["hat", "Halo", "Beat Frog Quest in under an hour"],
	"lilypad": ["hat", "Lily Pad", "Catch 5 of the flies hiding in the World Tree"],
	"mushroom": ["hat", "Mushroom", "Bounce off 25 mushrooms in the World Tree"],
	"golden_skin": ["skin", "Golden Frog", "Catch every fly hiding in the World Tree"],
	"grayscale_skin": ["skin", "Grayscale", "Score 25 in Endless"],
	"negative_skin": ["skin", "Negative", "Score 50 in Endless"],
	"shiny": ["skin", "Shiny", "Score 75 in Endless"],
	"rainbow": ["skin", "Rainbow", "Score 200 in Endless"],
	"glow": ["skin", "Glow", "Get pulled up by a friend's band"],
	"ghost": ["skin", "Ghost", "Take a really big fall in the World Tree"],
	"starry": ["skin", "Starry", "Climb all the way to space in Endless"],
	"holo": ["skin", "Holo", "Climb with 3 friends at once"],
	"shadow": ["skin", "Frog God's Shadow", "Beat Frog Quest"],
}
