shader_type canvas_item;
// VHS overlay: scanlines + film grain + vignette, blended over the 3D view.
// Applied to a full-rect ColorRect on a CanvasLayer below the UI layer.
uniform float scan_strength : hint_range(0.0, 0.5) = 0.16;
uniform float grain_amount : hint_range(0.0, 0.3) = 0.06;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.72;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 uv = UV;
	float scan = sin(uv.y * 700.0) * 0.5 + 0.5;
	float g = hash(uv * vec2(1280.0, 720.0) + vec2(fract(TIME * 13.0) * 91.0, fract(TIME * 7.0) * 57.0));
	vec2 d = uv - vec2(0.5);
	float vig = smoothstep(0.9, 0.3, length(d));
	float dark = scan * scan_strength + (1.0 - vig) * vignette_strength;
	vec3 col = vec3(0.0) + vec3(g - 0.5, g - 0.5, g - 0.5) * grain_amount * 2.0;
	COLOR = vec4(col, clamp(dark + grain_amount * 0.5, 0.0, 0.92));
}
