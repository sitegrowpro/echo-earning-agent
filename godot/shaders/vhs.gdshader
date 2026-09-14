shader_type canvas_item;
// VHS overlay: scanlines + animated grain + vignette + rolling tracking bar.
// Pure overlay (no screen sampling): darkens the view and adds camcorder noise.
// `dread` (0..1) is driven by gameplay: calm 0.3 -> hiding 0.8 -> chase 1.0.
uniform float scan_strength : hint_range(0.0, 0.5) = 0.16;
uniform float grain_amount : hint_range(0.0, 0.3) = 0.07;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.78;
uniform float track_strength : hint_range(0.0, 1.0) = 0.6;
uniform float dread : hint_range(0.0, 1.0) = 0.3;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 uv = UV;
	// Scanlines with a slow roll.
	float scan = sin((uv.y + fract(TIME * 0.11) * 0.02) * 700.0) * 0.5 + 0.5;
	// Animated grain, angrier when dread is high.
	float gseed = fract(TIME * 13.0) * 91.0;
	float g = hash(uv * vec2(1280.0, 720.0) + vec2(gseed, gseed * 0.63));
	float grain = grain_amount * (0.55 + dread * 1.8);
	// Vignette that closes in with dread.
	vec2 d = uv - vec2(0.5);
	float vig = smoothstep(0.92 - dread * 0.18, 0.28, length(d));
	// Rolling tracking bar: tears through for a moment every few seconds.
	float band_at = fract(TIME * 0.14) * 1.3 - 0.15;
	float band = smoothstep(0.035, 0.0, abs(uv.y - band_at));
	float gate = step(0.55, hash(vec2(floor(TIME * 0.14), 3.7)));
	float track = band * gate * track_strength;
	float track_noise = hash(vec2(floor(uv.x * 160.0), floor(TIME * 24.0)));
	// Compose: darkness + grain + tracking interference + lamp flicker.
	float dark = scan * scan_strength + (1.0 - vig) * vignette_strength;
	float flick = 0.965 + 0.035 * sin(TIME * 57.0) + dread * 0.03 * sin(TIME * 3.1);
	vec3 col = vec3(g - 0.5) * grain * 2.0;
	col += vec3(0.75, 0.9, 0.8) * track * (0.35 + 0.65 * track_noise);
	float a = clamp((dark + grain * 0.5) * flick + track * 0.55, 0.0, 0.94);
	COLOR = vec4(col, a);
}
