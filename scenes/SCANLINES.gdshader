//---CRT Shader---
shader_type canvas_item;


uniform float scanline_count : hint_range(0, 1800) = 50.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform float center_transparency : hint_range(0.0, 1.0) = 1.0; // how transparent the center is
uniform float edge_opacity : hint_range(0.0, 1.0) = 1.0; // how opaque the edges are
uniform float gradient_radius : hint_range(0.0, 2.0) = 1.0; // size of the gradient falloff
uniform sampler2D SCREEN_TEXTURE: hint_screen_texture, filter_linear_mipmap;

vec2 uv_curve(vec2 uv)
{
	uv = (uv - 0.5) * 2.0;
	
	//You can modify the numbers and try different values
	uv.x *= 1.0 + pow(abs(uv.y) / 3.0, 3.0);
	uv.y *= 1.0 + pow(abs(uv.x) / 3.0, 3.0);
	
	//The scale part (you can delete it when you want)
	uv /= 1.0;
	
	uv = (uv/2.0) + 0.5;
	return uv;
}


void fragment()
{	
	
	//You can modify the *3.0, *-3.0 for a bigger or smaller 
	float r = texture(SCREEN_TEXTURE, uv_curve(SCREEN_UV) + vec2(SCREEN_PIXEL_SIZE.x*0.0), 0.0).r;
	float g = texture(SCREEN_TEXTURE, uv_curve(SCREEN_UV) + vec2(SCREEN_PIXEL_SIZE.x*0.0), 0.0).g;
	float b = texture(SCREEN_TEXTURE, uv_curve(SCREEN_UV) + vec2(SCREEN_PIXEL_SIZE.x*-0.0), 0.0).b;
	
	
	//If you dont want scanlines you can just delete this part
	float s = sin(uv_curve(SCREEN_UV).y * scanline_count * PI * 2.0);
	s = (s * 0.5 + 0.5) * 0.9 + 0.1;
	vec4 scan_line = vec4(vec3(pow(s, 0.25)), 0.3);
	
	
	float dist = length((uv_curve(SCREEN_UV) - 0.5) * 2.0) / gradient_radius;
	float radial_opacity = mix(1.0 - center_transparency, edge_opacity, clamp(dist, 0.0, 1.0));
	COLOR = vec4(r, g, b, opacity * radial_opacity) * scan_line;
}
