shader_type canvas_item;
render_mode blend_add;
// A frog god's eyes, glowing up out of his shadow (the finale's FROG KINGs: Main._frog_gods): the dark middles
// of his eyes lit white, and a soft white glow round each, spilling past them over his shadow and whatever's
// behind him, pulsing slowly; the rest left to his shadow, under this. Added on, as light is. All of it by
// glow: 0 none, 1 all. (Its sprite is bigger than his all round, for the glow to spill into: Main.GOD_EYES_ROOM.)

uniform float glow : hint_range(0.0, 1.0) = 0.0;
uniform float phase = 0.0;  // (his own pulse, not in step with the others')
uniform vec2 left_eye = vec2(6.0, 8.0);  // (the middle of each of his eyes, in his pixels: Main._eye_middles)
uniform vec2 right_eye = vec2(25.0, 8.0);

const float PULSE = 2.3;  // (how fast it pulses: about every 2.7 s)
const float NEAR = 1.6;  // (how far the glow's bright middle reaches from an eye, in his pixels)
const float FAR = 4.6;  // (and its faint edge, at the height of a pulse)

// Whether this pixel of his is the dark middle of one of his eyes.
float eye_px(vec4 c) {
	return (c.a > 0.5 && max(c.r, max(c.g, c.b)) < 0.12) ? 1.0 : 0.0;
}

void fragment() {
	float eye = eye_px(texture(TEXTURE, UV));
	vec2 at = UV / TEXTURE_PIXEL_SIZE;  // (where this is, in his pixels)
	float pulse = 0.5 + 0.5 * sin(TIME * PULSE + phase);  // (0 to 1 and back, easing both ways)
	float d = min(distance(at, left_eye), distance(at, right_eye));
	float far = FAR * mix(0.75, 1.0, pulse);
	float halo = 0.55 * exp(-(d * d) / (NEAR * NEAR)) + 0.45 * exp(-(d * d) / (far * far));
	float light = max(eye * mix(0.85, 1.0, pulse), halo * mix(0.4, 0.8, pulse));  // (the eyes themselves brightest)
	COLOR = vec4(vec3(1.0), glow * light);
}
