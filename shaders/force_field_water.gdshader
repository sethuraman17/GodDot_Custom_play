shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

// Watery translucent dome for the force-field globe: scrolling ripple noise
// over two blue tones with a fresnel rim so the edge reads while the middle
// stays see-through. alpha_boost is driven by the ForceField script (grows in
// during BUILDING, 1.0 while ACTIVE, fades out on dissolve).

uniform vec4 shallow_color : source_color = vec4(0.45, 0.85, 1.0, 0.10);
uniform vec4 deep_color : source_color = vec4(0.10, 0.45, 0.85, 0.30);
uniform float wave_speed = 1.5;
uniform float wave_scale = 7.0;
uniform float alpha_boost = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

void vertex() {
	// Gentle surface slosh so the dome reads as liquid, not glass.
	VERTEX += NORMAL * 0.035 * sin(TIME * 2.2 + VERTEX.x * 4.0 + VERTEX.y * 3.0 + VERTEX.z * 5.0);
}

void fragment() {
	vec2 drift_a = vec2(TIME * wave_speed * 0.31, TIME * wave_speed * 0.17);
	vec2 drift_b = vec2(-TIME * wave_speed * 0.23, TIME * wave_speed * 0.11);
	float ripple = vnoise(UV * wave_scale + drift_a) * 0.6
		+ vnoise(UV * wave_scale * 2.3 + drift_b) * 0.4;

	float fresnel = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
	vec4 water = mix(shallow_color, deep_color, ripple);

	ALBEDO = water.rgb + fresnel * 0.35;
	EMISSION = water.rgb * (0.35 + 0.65 * fresnel);
	ALPHA = clamp((water.a + fresnel * 0.4) * alpha_boost, 0.0, 0.85);
}
