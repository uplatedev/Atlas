shader_type spatial;
render_mode cull_disabled;

uniform vec4 eye_color : source_color;
uniform vec4 skin_color : source_color;
uniform float eye_roughness = 0.0;
uniform float skin_roughness = 0.9;
uniform float blink_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// Opaque eyelids keep the existing face intact; no transparent holes.
	float aperture = mix(0.52, 0.018, clamp(blink_amount, 0.0, 1.0));
	float crease_y = mix(0.5, 0.42, blink_amount);
	float skin = smoothstep(aperture - 0.008, aperture + 0.008, abs(UV.y - crease_y));
	ALBEDO = mix(eye_color.rgb, skin_color.rgb, skin);
	ROUGHNESS = mix(eye_roughness, skin_roughness, skin);
}