shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform float seed = 0.0;
uniform float noise_scale : hint_range(0.5, 10.0) = 2.5;
uniform int octaves : hint_range(1, 8) = 5;
uniform float persistence : hint_range(0.1, 0.9) = 0.5;
uniform int noise_type : hint_enum("Value", "Perlin", "Cellular", "Ridged") = 1;

uniform vec4 color_deep : source_color = vec4(0.05, 0.1, 0.3, 1.0);
uniform vec4 color_low : source_color = vec4(0.1, 0.4, 0.15, 1.0);
uniform vec4 color_mid : source_color = vec4(0.5, 0.4, 0.2, 1.0);
uniform vec4 color_high : source_color = vec4(0.8, 0.8, 0.8, 1.0);

uniform float ice_caps : hint_range(0.0, 1.0) = 0.5;
uniform vec4 ice_color : source_color = vec4(0.9, 0.95, 1.0, 1.0);

uniform float roughness_val : hint_range(0.0, 1.0) = 0.85;
uniform float rim_power : hint_range(0.5, 8.0) = 2.0;
uniform vec4 atmosphere_color : source_color = vec4(0.4, 0.6, 1.0, 1.0);
uniform float atmosphere_strength : hint_range(0.0, 1.0) = 0.3;

// --- Hashing ---
vec3 hash3(vec3 p) {
	p = vec3(
		dot(p, vec3(127.1, 311.7, 74.7)) + seed,
		dot(p, vec3(269.5, 183.3, 246.1)) + seed,
		dot(p, vec3(113.5, 271.9, 124.6)) + seed
	);
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float hash1(vec3 p) {
	return hash3(p).x * 0.5 + 0.5; // 0..1
}

// --- Perlin / gradient noise (classic, smooth continents) ---
float perlinNoise3d(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);

	float n000 = dot(hash3(i + vec3(0,0,0)), f - vec3(0,0,0));
	float n100 = dot(hash3(i + vec3(1,0,0)), f - vec3(1,0,0));
	float n010 = dot(hash3(i + vec3(0,1,0)), f - vec3(0,1,0));
	float n110 = dot(hash3(i + vec3(1,1,0)), f - vec3(1,1,0));
	float n001 = dot(hash3(i + vec3(0,0,1)), f - vec3(0,0,1));
	float n101 = dot(hash3(i + vec3(1,0,1)), f - vec3(1,0,1));
	float n011 = dot(hash3(i + vec3(0,1,1)), f - vec3(0,1,1));
	float n111 = dot(hash3(i + vec3(1,1,1)), f - vec3(1,1,1));

	float nx00 = mix(n000, n100, u.x);
	float nx10 = mix(n010, n110, u.x);
	float nx01 = mix(n001, n101, u.x);
	float nx11 = mix(n011, n111, u.x);

	float nxy0 = mix(nx00, nx10, u.y);
	float nxy1 = mix(nx01, nx11, u.y);

	return mix(nxy0, nxy1, u.z); // -1..1
}

// --- Value noise (blockier, no gradient dot — good for alien/patchy looks) ---
float valueNoise3d(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);

	float n000 = hash1(i + vec3(0,0,0));
	float n100 = hash1(i + vec3(1,0,0));
	float n010 = hash1(i + vec3(0,1,0));
	float n110 = hash1(i + vec3(1,1,0));
	float n001 = hash1(i + vec3(0,0,1));
	float n101 = hash1(i + vec3(1,0,1));
	float n011 = hash1(i + vec3(0,1,1));
	float n111 = hash1(i + vec3(1,1,1));

	float nx00 = mix(n000, n100, u.x);
	float nx10 = mix(n010, n110, u.x);
	float nx01 = mix(n001, n101, u.x);
	float nx11 = mix(n011, n111, u.x);

	float nxy0 = mix(nx00, nx10, u.y);
	float nxy1 = mix(nx01, nx11, u.y);

	return mix(nxy0, nxy1, u.z) * 2.0 - 1.0; // -1..1
}

// --- Cellular / Voronoi noise (cracked terrain, cell-like continents) ---
float cellularNoise3d(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float min_dist = 10.0;

	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 neighbor = vec3(float(x), float(y), float(z));
				vec3 point = hash3(i + neighbor) * 0.5 + 0.5;
				vec3 diff = neighbor + point - f;
				min_dist = min(min_dist, length(diff));
			}
		}
	}
	return min_dist; // roughly 0..1.5
}

// --- Single noise sample, dispatches by type ---
float sampleNoise(vec3 p) {
	if (noise_type == 0) {
		return valueNoise3d(p);
	} else if (noise_type == 1) {
		return perlinNoise3d(p);
	} else if (noise_type == 2) {
		float c = cellularNoise3d(p);
		return (1.0 - c) * 2.0 - 1.0; // invert so cell centers read as "high"
	} else {
		float n = perlinNoise3d(p);
		return abs(n) * 2.0 - 1.0; // ridged
	}
}

float fbm(vec3 p) {
	float value = 0.0;
	float amplitude = 0.5;
	float freq = 1.0;
	for (int i = 0; i < octaves; i++) {
		value += amplitude * sampleNoise(p * freq);
		freq *= 2.0;
		amplitude *= persistence;
	}
	return value;
}

varying vec3 local_pos;
varying vec3 local_normal;

void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
}

void fragment() {
	vec3 p = normalize(local_pos) * noise_scale;

	float n = fbm(p);
	n = (n + 1.0) * 0.5;

	float detail = fbm(p * 3.0 + 100.0);
	n = clamp(n + detail * 0.15, 0.0, 1.0);

	vec3 col;
	if (n < 0.35) {
		col = mix(color_deep.rgb, color_low.rgb, n / 0.35);
	} else if (n < 0.65) {
		col = mix(color_low.rgb, color_mid.rgb, (n - 0.35) / 0.3);
	} else {
		col = mix(color_mid.rgb, color_high.rgb, (n - 0.65) / 0.35);
	}

	float latitude = abs(normalize(local_pos).y);
	float ice_threshold = 1.0 - ice_caps * 0.6;
	float ice_blend = smoothstep(ice_threshold, ice_threshold + 0.15, latitude);
	col = mix(col, ice_color.rgb, ice_blend);

	ALBEDO = col;
	ROUGHNESS = roughness_val;
	METALLIC = 0.0;

	float rim = 1.0 - abs(dot(normalize(local_normal), normalize(VIEW)));
	rim = pow(rim, rim_power);
	EMISSION = atmosphere_color.rgb * rim * atmosphere_strength;
}