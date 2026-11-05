shader_type canvas_item;
// Endless's sky and its scenery (everything drawn before this) in square pixels `cell` of the screen's
// across, on the screen's own grid: the story's sky is pixel art at 2.4 of the world's px a pixel
// (Sky.TEXEL), so Endless's is too (EndlessSky sets `cell` to that at the camera's zoom).

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float cell = 2.4;

void fragment() {
	vec2 px = SCREEN_UV / SCREEN_PIXEL_SIZE;
	vec2 at = (floor(px / cell) + 0.5) * cell;
	COLOR = vec4(texture(screen, at * SCREEN_PIXEL_SIZE).rgb, 1.0);
}
