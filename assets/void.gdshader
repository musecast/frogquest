shader_type canvas_item;
// The place between the stars where the frog god speaks (CreatorIntro): a dark, slow fog, mirrored left
// to right, drifting and rippling, drawn on chunky pixels like the rest of the game, darker at the edges,
// with a few soft stars far behind.

uniform vec2 pixels = vec2(240.0, 400.0);  // (how many of its chunky pixels across and down)
uniform float speed = 0.12;
uniform vec3 deep : source_color = vec3(0.025, 0.022, 0.07);
uniform vec3 mid : source_color = vec3(0.12, 0.11, 0.27);
uniform vec3 high : source_color = vec3(0.32, 0.29, 0.55);
uniform float glow = 0.0;  // (the flash, as he wakes: 0 to 1)

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 cell = floor(UV * pixels) / pixels;
	vec2 p = cell - 0.5;
	p.x = abs(p.x);  // (mirrored)
	float t = TIME * speed;
	vec2 q = p * vec2(3.2, 4.6);
	q.y += sin(q.x * 2.4 + t * 2.6) * 0.35;
	q.x += sin(q.y * 1.7 - t * 1.9) * 0.25;
	float n = fbm(q + vec2(t, -t * 0.6));
	n = mix(n, fbm(q * 1.9 - vec2(t * 0.7, t)), 0.45);
	vec3 col = mix(deep, mid, smoothstep(0.38, 0.72, n));
	col = mix(col, high, smoothstep(0.70, 0.92, n) * 0.55);
	float star = step(0.9965, hash(floor(UV * pixels))) * (0.55 + 0.45 * sin(TIME * 2.0 + hash(floor(UV * pixels) + 3.1) * 6.28));
	col += vec3(0.85, 0.82, 1.0) * star * 0.7;
	float edge = smoothstep(0.92, 0.25, length((UV - 0.5) * vec2(1.0, 1.25)));
	col *= mix(0.35, 1.0, edge);
	col = mix(col, vec3(1.0), glow);
	COLOR = vec4(col, 1.0);
}
