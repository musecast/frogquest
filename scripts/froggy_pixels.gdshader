// The game's pixel look, for Lil Froggy out on the desktop.
//
// The game draws everything into a small 480 px wide view and blows it up with big square pixels; at
// its usual widescreen zoom one of those pixels covers two of froggy's art pixels each way, which is
// what puts his body and his hat on the same chunky grid. Out here he's drawn at screen resolution,
// so this CanvasGroup material redraws him (and his hearts, flies and aim line) in blocks that size.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float block = 4.0;  // screen pixels per game pixel (DesktopFroggy sets it)

void fragment() {
	// One screen pixel from inside each block, sampled dead centre so nothing gets blended in.
	vec2 pixel = floor(SCREEN_UV / SCREEN_PIXEL_SIZE);
	vec2 pick = floor(pixel / block) * block + floor(block * 0.5) + 0.5;
	vec4 c = textureLod(screen_texture, pick * SCREEN_PIXEL_SIZE, 0.0);
	if (c.a > 0.0001) {
		c.rgb /= c.a;  // the back buffer is premultiplied
	}
	COLOR = vec4(c.rgb, step(0.5, c.a)) * COLOR;  // hard pixel edges, like the game's
}
