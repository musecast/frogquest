shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture;

void fragment() {
	vec4 player_color = texture(TEXTURE, UV);
	vec4 bg_color = texture(SCREEN_TEXTURE, SCREEN_UV);
	vec3 negative_color = vec3(1.0 - bg_color.r, 1.0 - bg_color.g, 1.0 - bg_color.b);
	float luminance = dot(negative_color, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(vec3(luminance), player_color.a);
}
