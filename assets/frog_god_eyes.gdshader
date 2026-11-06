shader_type canvas_item;
// A frog god's eyes, glowing up out of his shadow (the finale's FROG KINGs: Main._frog_gods). Only the dark
// middles of his eyes, pale as the intro's frog god's (froggy_look's SHADOW_EYE), and a little violet just
// round them, breathing slowly; the rest left to his shadow, under this. All of it by glow: 0 none, 1 all.

uniform float glow : hint_range(0.0, 1.0) = 0.0;
uniform float phase = 0.0;  // (his own breath, not in step with the others')

const vec3 EYE = vec3(0.94, 0.88, 1.0);
const vec3 ROUND = vec3(0.52, 0.38, 0.95);

// Whether this pixel of his is the dark middle of one of his eyes.
float eye_px(vec4 c) {
	return (c.a > 0.5 && max(c.r, max(c.g, c.b)) < 0.12) ? 1.0 : 0.0;
}

void fragment() {
	vec4 px = texture(TEXTURE, UV);
	vec2 t = TEXTURE_PIXEL_SIZE;
	float eye = eye_px(px);
	float by_eye = max(max(eye_px(texture(TEXTURE, UV + vec2(t.x, 0.0))), eye_px(texture(TEXTURE, UV - vec2(t.x, 0.0)))),
		max(eye_px(texture(TEXTURE, UV + vec2(0.0, t.y))), eye_px(texture(TEXTURE, UV - vec2(0.0, t.y)))));
	float round_it = (1.0 - eye) * by_eye * step(0.5, px.a) * 0.28;
	float breath = 0.82 + 0.18 * sin(TIME * 1.4 + phase);
	COLOR = vec4(mix(ROUND, EYE, eye), glow * breath * max(eye, round_it));
}
