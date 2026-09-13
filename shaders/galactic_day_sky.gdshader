// Galactic DAY sky for the post-apocalyptic desert world.
// A bright daytime sky with an intergalactic look: soft nebula wisps and a
// galaxy band in pink/teal/violet, a warm hazy horizon that matches the fog,
// and a proper sun disk. Deliberately NO star field — this is day, not night.
shader_type sky;

uniform vec3 horizon_color : source_color = vec3(0.97, 0.80, 0.68);
uniform vec3 sky_color : source_color = vec3(0.34, 0.55, 0.85);
uniform vec3 zenith_color : source_color = vec3(0.16, 0.28, 0.58);
uniform vec3 nebula_pink : source_color = vec3(0.95, 0.45, 0.72);
uniform vec3 nebula_teal : source_color = vec3(0.30, 0.82, 0.88);
uniform vec3 nebula_violet : source_color = vec3(0.60, 0.42, 0.95);
uniform vec3 ground_color : source_color = vec3(0.42, 0.33, 0.22);
uniform float nebula_intensity : hint_range(0.0, 2.0) = 0.75;
uniform float sun_disk_size : hint_range(0.001, 0.2) = 0.03;
uniform float sun_glow : hint_range(0.0, 2.0) = 0.4;

float vhash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(vhash(i + vec3(0.0, 0.0, 0.0)), vhash(i + vec3(1.0, 0.0, 0.0)), f.x),
			mix(vhash(i + vec3(0.0, 1.0, 0.0)), vhash(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(vhash(i + vec3(0.0, 0.0, 1.0)), vhash(i + vec3(1.0, 0.0, 1.0)), f.x),
			mix(vhash(i + vec3(0.0, 1.0, 1.0)), vhash(i + vec3(1.0, 1.0, 1.0)), f.x), f.y),
		f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = p * 2.13 + vec3(7.7);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = EYEDIR;
	float h = clamp(dir.y, -1.0, 1.0);

	// Bright daytime base gradient: warm haze at the horizon, deep blue overhead.
	float horizon_mix = pow(1.0 - clamp(h, 0.0, 1.0), 3.0);
	vec3 col = mix(mix(sky_color, zenith_color, clamp(h * 1.4, 0.0, 1.0)), horizon_color, horizon_mix);

	// Galaxy band: a broad tilted plane across the sky dome.
	vec3 band_normal = normalize(vec3(0.45, 0.35, 0.82));
	float band_dist = abs(dot(dir, band_normal));
	float band = exp(-band_dist * band_dist * 14.0);

	// Nebula wisps in three hues, concentrated along the band, fading at the horizon
	// so the desert haze stays warm.
	float n1 = fbm(dir * 3.0);
	float n2 = fbm(dir * 6.5 + vec3(11.3));
	float n3 = fbm(dir * 2.2 + vec3(4.7));
	vec3 nebula = nebula_pink * smoothstep(0.45, 0.85, n1)
			+ nebula_teal * smoothstep(0.50, 0.90, n2) * 0.7
			+ nebula_violet * smoothstep(0.40, 0.80, n3) * 0.8;
	float sky_mask = smoothstep(0.0, 0.12, h);
	col += nebula * (band * 0.85 + 0.15) * nebula_intensity * sky_mask;

	// Warm galaxy-core glow sitting on the band, opposite the sun.
	vec3 core_dir = normalize(vec3(-0.55, 0.55, -0.35));
	float core = pow(clamp(dot(dir, core_dir), 0.0, 1.0), 24.0);
	col += vec3(1.0, 0.88, 0.78) * core * 0.9 * sky_mask;

	// Sun disk + glow driven by the scene's DirectionalLight.
	if (LIGHT0_ENABLED) {
		float sun_amount = clamp(dot(dir, LIGHT0_DIRECTION), 0.0, 1.0);
		float disk = smoothstep(1.0 - sun_disk_size, 1.0 - sun_disk_size * 0.4, sun_amount);
		col += LIGHT0_COLOR * disk * LIGHT0_ENERGY;
		col += LIGHT0_COLOR * pow(sun_amount, 9.0) * sun_glow;
	}

	// Dusty ground below the horizon line (keeps reflections/radiance sane).
	col = mix(col, ground_color, smoothstep(0.02, -0.08, h));

	COLOR = col;
}
