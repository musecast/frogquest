shader_type canvas_item;
// Your froggy (FroggyLook.gd) over Froggy's own frames, never redrawn: his mint body, cream belly and
// black eyes recoloured by their hue, keeping their shading and soft edges; a pattern on his body, on
// his own pixel grid; an effect over him (the ones you unlock); in the intro, how much of him is still
// the frog god's shadow; and, asleep, his eyes shut.

uniform vec3 body_colour : source_color = vec3(0.627, 1.0, 0.671);
uniform vec3 belly_colour : source_color = vec3(0.988, 1.0, 0.804);
uniform vec3 eye_colour : source_color = vec3(0.0);
uniform int pattern = 0;  // 0 none, 1 spots, 2 stripes, 3 freckles, 4 two-tone, 5 hearts, 6 stars
uniform vec3 pattern_colour : source_color = vec3(0.40, 0.80, 0.42);
// 0 none, 1 shiny, 2 rainbow, 3 glow, 4 ghost, 5 starry, 6 holo, 7 shadow (the frog god's), 8 golden,
// 9 grayscale (the Negative skin has its own shader, negative.gdshader: it shows the screen behind him)
uniform int effect = 0;
uniform vec3 effect_colour : source_color = vec3(1.0, 0.82, 0.30);  // (the glow's: your band's colour)
uniform float shadow_amount : hint_range(0.0, 1.0) = 0.0;  // (how much of him is the frog god's shadow)
uniform vec2 tex_px = vec2(32.0, 32.0);  // (his frame, in its own pixels)
uniform bool eyes_shut = false;  // (asleep, in his beanbag)

varying vec4 tint;  // (his node's modulate: kept, e.g. the frog god's glimpses up the climb start as a plain shadow)

const vec3 BODY_BASE = vec3(0.627, 1.0, 0.671);
const vec3 BELLY_BASE = vec3(0.988, 1.0, 0.804);
const vec3 MOUTH = vec3(1.0, 0.647, 0.647);  // (his mouth's pink, as drawn)
const vec3 SHADOW = vec3(0.035, 0.025, 0.075);
const vec3 SHADOW_RIM = vec3(0.52, 0.38, 0.95);
const vec3 SHADOW_EYE = vec3(0.94, 0.88, 1.0);

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1.0e-10)), d / (q.x + 1.0e-10), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

float lum(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Whether this pixel of his is the dark middle of one of his eyes.
float eye_px(vec4 c) {
	return (c.a > 0.5 && max(c.r, max(c.g, c.b)) < 0.12) ? 1.0 : 0.0;
}

// Whether a pixel of his is one of his eyes (up on his head: not his body's green, his belly, his mouth's
// pink or where it meets his green; its white, its grey rim, its dark middle).
bool in_eye(vec4 c) {
	vec3 h = rgb2hsv(c.rgb);
	vec3 across = BODY_BASE - MOUTH;
	float toward = clamp(dot(c.rgb - MOUTH, across) / dot(across, across), 0.0, 1.0);
	bool mouth = distance(c.rgb, MOUTH + across * toward) < 0.04 && toward < 0.97;
	bool body = h.x > 0.25 && h.x < 0.48 && h.y > 0.12;
	bool belly = !body && h.x > 0.10 && h.x <= 0.25 && h.y > 0.08 && h.z > 0.6;
	bool pink = (h.x < 0.1 || h.x > 0.9) && h.y > 0.15 && h.z > 0.5;
	return !mouth && !body && !belly && !pink;
}

// The frog god's shadow over him, by amount: dark all through (a little of his shape left in it), a
// violet rim round him, breathing, and the middles of his eyes glowing, softly round them too. (near:
// the most of his 8 neighbours' alpha; by_eye: whether one of his 4 is an eye's middle. His texture's
// read in fragment(), as functions can't be handed it.)
void shadowed(inout vec3 col, inout float alpha, vec4 px, bool eye, float near, float by_eye, float amount) {
	if (px.a < 0.5) {
		if (near > 0.5) {
			col = mix(col, SHADOW_RIM, amount);
			alpha = max(alpha, amount * (0.62 + 0.22 * sin(TIME * 2.0)));
		}
		return;
	}
	vec3 dark = SHADOW + SHADOW_RIM * 0.10 * lum(px.rgb);
	if (eye) {
		dark = SHADOW_EYE * (0.86 + 0.14 * sin(TIME * 3.0));
	} else {
		dark = mix(dark, SHADOW_RIM, by_eye * 0.5);
	}
	col = mix(col, dark, amount);
}

// Whether his pixel `cell` is under the pattern.
float pattern_at(vec2 cell) {
	if (pattern == 1) {  // spots: round, scattered
		vec2 g = floor(cell / 7.0);
		vec2 c = g * 7.0 + 2.0 + floor(vec2(hash(g), hash(g + 9.1)) * 3.0);
		return step(distance(cell, c), 1.6);
	} else if (pattern == 2) {  // stripes: across, slanting
		return step(0.5, fract((cell.x * 0.5 + cell.y) / 6.0));
	} else if (pattern == 3) {  // freckles: lone pixels
		return step(0.88, hash(cell));
	} else if (pattern == 4) {  // two-tone: his top half, then the other colour
		return step(17.0, cell.y);
	} else if (pattern == 5) {  // hearts: little ones, on a grid
		vec2 g = mod(cell + vec2(1.0, 2.0), 8.0);
		bool row0 = g.y == 0.0 && (g.x == 1.0 || g.x == 3.0);
		bool row1 = g.y == 1.0 && g.x >= 0.0 && g.x <= 4.0;
		bool row2 = g.y == 2.0 && g.x >= 1.0 && g.x <= 3.0;
		bool row3 = g.y == 3.0 && g.x == 2.0;
		return (row0 || row1 || row2 || row3) ? 1.0 : 0.0;
	} else if (pattern == 6) {  // stars: little crosses, on a grid
		vec2 g = mod(cell + vec2(3.0, 1.0), 9.0);
		bool mid = g.x == 2.0 && g.y == 2.0;
		bool arm = (g.x == 2.0 && (g.y == 1.0 || g.y == 3.0)) || (g.y == 2.0 && (g.x == 1.0 || g.x == 3.0));
		return (mid || arm) ? 1.0 : 0.0;
	}
	return 0.0;
}

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec2 uv = UV;
	if (effect == 4) {  // ghost: a gentle waver
		uv.x += sin(uv.y * 18.0 + TIME * 4.0) * 0.012;
	}
	vec4 px = texture(TEXTURE, uv);
	vec2 cell = floor(uv * tex_px);
	vec3 hsv = rgb2hsv(px.rgb);
	bool eye = hsv.z < 0.12;
	// (where his pink mouth meets his green, the art blends the two: those pixels are that mix of the
	// pink and his own colour, not left green, nor taken for his belly. Only up on his face, where his
	// mouth is: the deepest of his belly's shading, down at its bottom, is near that mix too)
	vec3 across = BODY_BASE - MOUTH;
	float toward = clamp(dot(px.rgb - MOUTH, across) / dot(across, across), 0.0, 1.0);
	bool mouth = !eye && uv.y < 0.45 && toward > 0.05 && toward < 0.97 && distance(px.rgb, MOUTH + across * toward) < 0.04;
	bool body = !mouth && hsv.x > 0.25 && hsv.x < 0.48 && hsv.y > 0.12;
	bool belly = !mouth && !body && hsv.x > 0.10 && hsv.x <= 0.25 && hsv.y > 0.08 && hsv.z > 0.6;
	// (and the faint green in the greys and whites round his eyes, where his green meets them: his tint)
	bool tinted = !mouth && !body && !belly && !eye && hsv.x > 0.2 && hsv.x < 0.5 && hsv.y > 0.015;
	vec3 col = px.rgb;
	vec3 skin = body_colour;
	if (effect == 2) {  // rainbow: his colour runs round the rainbow, down him
		skin = hsv2rgb(vec3(fract(TIME * 0.18 + cell.y / 40.0), 0.42, 1.0));
	}
	vec3 base = mix(skin, pattern_colour, pattern_at(cell));
	if (body) {
		col = base * (lum(px.rgb) / lum(BODY_BASE));
	} else if (mouth) {
		col = mix(MOUTH, base, toward);
	} else if (belly) {
		col = belly_colour * (lum(px.rgb) / lum(BELLY_BASE));
	} else if (eye) {
		col = eye_colour + px.rgb;
	} else if (tinted) {
		col = mix(vec3(lum(px.rgb)), base * (lum(px.rgb) / lum(BODY_BASE)), clamp(hsv.y / 0.12, 0.0, 1.0));
	}
	// (asleep: each eye shut, from his own frames. All of it, its white, its grey rim and its dark middle,
	// is his skin, but for the lowest of the dark in each column of it: a line, the shut eye)
	if (eyes_shut && px.a > 0.5 && uv.y < 0.36 && in_eye(px)) {
		vec4 below = texture(TEXTURE, uv + vec2(0.0, 1.0 / tex_px.y));
		bool lowest = hsv.z < 0.5 && !(below.a > 0.5 && in_eye(below) && rgb2hsv(below.rgb).z < 0.5);
		col = lowest ? mix(base, vec3(0.06, 0.04, 0.08), 0.8) : base * 0.95;
	}
	float alpha = px.a;

	// (his neighbours, for the rings round him and the shadow's eyes: read only when they're wanted)
	float near = 0.0;
	float by_eye = 0.0;
	if (effect == 3 || effect == 7 || effect == 11 || shadow_amount > 0.0) {
		vec2 t = 1.0 / tex_px;
		vec4 r = texture(TEXTURE, uv + vec2(t.x, 0.0));
		vec4 l = texture(TEXTURE, uv - vec2(t.x, 0.0));
		vec4 d = texture(TEXTURE, uv + vec2(0.0, t.y));
		vec4 u = texture(TEXTURE, uv - vec2(0.0, t.y));
		near = max(max(r.a, l.a), max(d.a, u.a));
		near = max(near, max(max(texture(TEXTURE, uv + t).a, texture(TEXTURE, uv - t).a),
			max(texture(TEXTURE, uv + vec2(t.x, -t.y)).a, texture(TEXTURE, uv + vec2(-t.x, t.y)).a)));
		by_eye = max(max(eye_px(r), eye_px(l)), max(eye_px(d), eye_px(u)));
	}

	if (effect == 1 && (body || belly)) {  // shiny: a glint sweeping across him
		float sweep = fract(TIME * 0.32) * 1.8 - 0.4;
		float d = abs((uv.x + uv.y) * 0.5 - sweep);
		col = mix(col, vec3(1.0), smoothstep(0.08, 0.0, d) * 0.75);
		col *= 1.08;
	} else if (effect == 3) {  // glow: a ring round him, breathing, in your band's colour
		if (px.a < 0.5 && near > 0.5) {
			col = effect_colour;
			alpha = max(alpha, 0.55 + 0.35 * sin(TIME * 3.0));
		}
	} else if (effect == 4) {  // ghost: pale and see-through
		col = mix(col, vec3(0.80, 0.90, 1.0), 0.45);
		alpha *= 0.55 + 0.08 * sin(TIME * 2.5);
	} else if (effect == 5 && (body || belly)) {  // starry: the night sky inside him, twinkling
		vec3 night = mix(vec3(0.06, 0.06, 0.20), vec3(0.24, 0.10, 0.36), cell.y / tex_px.y);
		float star = step(0.94, hash(cell + floor(TIME * 1.5) * 0.37));
		col = mix(night * (lum(px.rgb) / 0.9 + 0.3), vec3(1.0, 0.97, 0.85), star);
	} else if (effect == 6) {  // holo: see-through cyan, scanlines, a flicker
		col = mix(col, vec3(0.35, 1.0, 0.95), 0.55) * (mod(cell.y, 2.0) < 1.0 ? 1.0 : 0.72);
		alpha *= 0.78 + 0.12 * step(0.92, hash(vec2(floor(TIME * 12.0), 0.0)));
	} else if (effect == 7) {  // the frog god's shadow
		shadowed(col, alpha, px, eye, near, by_eye, 1.0);
	} else if (effect == 8) {  // golden
		col = mix(col, vec3(1.0, 0.75, 0.0), 0.55);
	} else if (effect == 9) {  // grayscale
		col = vec3(lum(col));
	} else if (effect == 10 && (body || belly)) {  // aurora (5 wins): the northern lights, flowing down him
		float wave = sin(cell.y * 0.32 - TIME * 1.1 + sin(cell.x * 0.28 + TIME * 0.6) * 1.6);
		vec3 lights = mix(vec3(0.18, 0.95, 0.58), vec3(0.30, 0.62, 1.0), 0.5 + 0.5 * wave);
		lights = mix(lights, vec3(0.80, 0.42, 1.0), smoothstep(0.6, 1.0, wave));
		col = lights * (lum(px.rgb) / lum(BODY_BASE) * 0.75 + 0.35);
	} else if (effect == 11) {  // legendary (10 wins): molten gold, a glint sweeping him, sparkles, a gold aura
		if (body || belly || mouth || tinted) {
			float shade = clamp((lum(px.rgb) - 0.45) / 0.55, 0.0, 1.0);
			vec3 gold = mix(vec3(0.70, 0.32, 0.04), vec3(1.0, 0.80, 0.22), shade);
			gold = mix(gold, vec3(1.0, 0.97, 0.70), smoothstep(0.75, 1.0, shade));
			float sweep = fract(TIME * 0.28) * 1.8 - 0.4;
			gold = mix(gold, vec3(1.0, 1.0, 0.92), smoothstep(0.07, 0.0, abs((uv.x + uv.y) * 0.5 - sweep)) * 0.85);
			col = mix(gold, vec3(1.0), step(0.975, hash(cell + floor(TIME * 2.5) * 0.61)));
		}
		if (px.a < 0.5 && near > 0.5) {
			col = mix(vec3(1.0, 0.62, 0.12), vec3(1.0, 0.92, 0.45), 0.5 + 0.5 * sin(TIME * 2.2));
			alpha = max(alpha, 0.65 + 0.3 * sin(TIME * 2.2));
		}
	}

	if (shadow_amount > 0.0 && effect != 7) {  // (the intro: the shadow he starts as, his colours filling in)
		shadowed(col, alpha, px, eye, near, by_eye, shadow_amount);
	}
	COLOR = vec4(col, alpha) * tint;
}
