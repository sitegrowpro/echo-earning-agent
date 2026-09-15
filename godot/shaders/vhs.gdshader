shader_type canvas_item;
// True single-pass VHS post-process (Godot docs: "Custom post-processing").
// CanvasLayer + full-rect ColorRect sampling the rendered frame via
// hint_screen_texture. Layer 0 sits below all UI (layer 1), so the UI
// renders clean on top while the 3D view gets the camcorder treatment.
// `dread` (0..1) is driven by gameplay: calm 0.15 -> chores 0.55 -> chase 1.0.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float scan_strength : hint_range(0.0, 0.5) = 0.14;
uniform float grain_amount : hint_range(0.0, 0.3) = 0.06;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.38;
uniform float track_strength : hint_range(0.0, 1.0) = 0.6;
uniform float dread : hint_range(0.0, 1.0) = 0.3;
uniform float barrel : hint_range(0.0, 0.3) = 0.10;
uniform float chroma : hint_range(0.0, 6.0) = 2.2;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 suv = SCREEN_UV;
	vec2 cc = suv - vec2(0.5);
	float r2 = dot(cc, cc);
	// Barrel distortion (CRT curvature).
	vec2 duv = suv + cc * r2 * barrel;
	// Rolling tracking band tears the image horizontally while passing.
	// Higher dread = more frequent tears.
	float band_at = fract(TIME * 0.14) * 1.3 - 0.15;
	float band = smoothstep(0.032, 0.0, abs(suv.y - band_at));
	float gate = step(0.55 - dread * 0.25, hash(vec2(floor(TIME * 0.14), 3.7)));
	float tear = band * gate * track_strength * (0.4 + dread);
	float tear_row = hash(vec2(floor(suv.y * 240.0), floor(TIME * 24.0))) - 0.5;
	duv.x += tear * tear_row * 0.08;
	duv.y += tear * (hash(vec2(7.3, floor(TIME * 24.0))) - 0.5) * 0.02;
	// Chromatic aberration: 3 taps, separation grows toward the edges.
	vec2 ca = cc * r2 * chroma * SCREEN_PIXEL_SIZE * 8.0 + vec2(SCREEN_PIXEL_SIZE.x * chroma * 0.35, 0.0);
	float r = texture(screen_texture, duv + ca).r;
	float g = texture(screen_texture, duv).g;
	float b = texture(screen_texture, duv - ca).b;
	vec3 col = vec3(r, g, b);
	// Tracking-band interference: washed noise stripe.
	float track_noise = hash(vec2(floor(suv.x * 160.0), floor(TIME * 24.0)));
	col = mix(col, vec3(track_noise * 0.9 + 0.1), tear * 0.25);
	col += vec3(0.75, 0.9, 0.8) * tear * track_noise * 0.12;
	// Scanlines with a slow roll.
	float scan = sin((suv.y + fract(TIME * 0.11) * 0.02) * 700.0) * 0.5 + 0.5;
	col *= 1.0 - scan * scan_strength;
	// Animated grain, angrier with dread.
	float gseed = fract(TIME * 13.0) * 91.0;
	float gr = hash(suv * vec2(1280.0, 720.0) + vec2(gseed, gseed * 0.63)) - 0.5;
	col += gr * grain_amount * (0.55 + dread * 1.8) * 2.0;
	// Slight VHS desaturation.
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(luma), 0.12);
	// Vignette closing in with dread + lamp flicker.
	float vig = smoothstep(1.02 - dread * 0.15, 0.36, length(cc));
	col *= mix(1.0, vig, vignette_strength);
	float flick = 0.965 + 0.035 * sin(TIME * 57.0) + dread * 0.03 * sin(TIME * 3.1);
	// CRT edge mask for overscan pushed outside the frame.
	vec2 eb = abs(duv * 2.0 - 1.0);
	float edge = 1.0 - smoothstep(0.98, 1.04, max(eb.x, eb.y));
	COLOR = vec4(col * flick * edge, 1.0);
}
