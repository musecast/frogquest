shader_type canvas_item;

// independent checker size
uniform float size_x : hint_range(1.0, 200.0) = 25.0;
uniform float size_y : hint_range(1.0, 200.0) = 25.0;

uniform vec4 color1 : source_color = vec4(1.0);
uniform vec4 color2 : source_color = vec4(0.7, 0.7, 0.7, 1.0);

// movement
uniform float speed : hint_range(0.0, 10.0) = 1.0;
uniform vec2 direction = vec2(1.0, 1.0);
uniform bool animate = true;

// rotation
uniform float rotation_deg : hint_range(-180.0, 180.0) = 0.0;

// screen vs world
uniform bool lock_to_screen = false;

// pivot (pixels in whichever space you're using)
uniform vec2 pivot_pixels = vec2(0.0, 0.0);

// waviness controls
uniform float wave_strength : hint_range(0.0, 50.0) = 0.0;      // amplitude in pixels
uniform float wave_frequency : hint_range(0.0, 2.0) = 0.10;     // cycles per pixel (smaller = bigger waves)
uniform float wave_speed : hint_range(0.0, 10.0) = 1.0;         // how fast the waves animate
uniform float wave_mod : hint_range(0.0, 2.0) = 1.0;            // modulation amount of waviness
uniform float wave_mod_frequency : hint_range(0.0, 2.0) = 0.03; // modulation frequency

varying vec2 canvas_pos_px;

void vertex() {
    vec4 p = MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0);
    canvas_pos_px = p.xy;
}

void fragment() {
    // choose coordinate space
    vec2 pos = lock_to_screen ? FRAGCOORD.xy : canvas_pos_px;

    // ---- rotation ----
    float a = radians(rotation_deg);
    float c = cos(a);
    float s = sin(a);
    mat2 rot = mat2(vec2(c, s), vec2(-s, c));

    pos -= pivot_pixels;
    pos = rot * pos;
    pos += pivot_pixels;

    // ---- scrolling ----
    vec2 dir = direction;
    float len = length(dir);
    if (animate && speed > 0.0 && len > 0.0001) {
        dir /= len;
        pos -= dir * (TIME * speed * vec2(size_x, size_y));
    }

    // ---- WAVY WARP (distort sampling position before computing the grid) ----
    // A gentle, controllable sine-based displacement in both axes.
    float t = TIME * wave_speed;

    // Modulate the wave amplitude over space (lets you "dial" variation up/down)
    float amp_mod = 1.0 + wave_mod * sin((pos.x + pos.y) * wave_mod_frequency + t);

    float amp = wave_strength * amp_mod;

    vec2 warp;
    warp.x = sin(pos.y * wave_frequency + t) * amp;
    warp.y = sin(pos.x * wave_frequency + t * 0.9) * amp;

    pos += warp;

    // ---- checker sampling with independent scale ----
    vec2 grid = floor(pos / vec2(size_x, size_y));
    float mask = mod(grid.x + mod(grid.y, 2.0), 2.0);

    COLOR = mix(color1, color2, mask);
}
