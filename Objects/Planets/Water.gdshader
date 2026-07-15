shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 water_color : source_color = vec4(0.05, 0.35, 0.5, 0.55);
uniform vec4 deep_color : source_color = vec4(0.0, 0.1, 0.2, 0.85);

uniform float metallic_val : hint_range(0.0, 1.0) = 0.6;
uniform float roughness_val : hint_range(0.0, 1.0) = 0.05;

uniform float wave_speed : hint_range(0.0, 5.0) = 0.6;
uniform float wave_height : hint_range(0.0, 2.0) = 0.08;
uniform float wave_frequency : hint_range(0.1, 20.0) = 4.0;

uniform float fresnel_power : hint_range(0.1, 8.0) = 3.0;

uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float foam_distance : hint_range(0.01, 5.0) = 0.4;
uniform float foam_noise_scale : hint_range(0.1, 20.0) = 8.0;

uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;

varying vec3 world_pos;
varying vec3 world_normal;

float wave_noise(vec3 p, float t) {
	vec3 q = p * wave_frequency + vec3(t * wave_speed, t * wave_speed * 0.7, t * wave_speed * 0.5);
	float n = sin(q.x + sin(q.z * 1.3)) * cos(q.y + sin(q.x * 0.7));
	return n;
}

// cheap 3D value noise for breaking up the foam edge so it isn't a clean ring
// smooth 3D value noise (trilinear interpolation between grid corners)
float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 45.164))) * 43758.5453);
}

float smooth_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f); // smoothstep interpolation curve

	float n000 = hash3(i + vec3(0.0, 0.0, 0.0));
	float n100 = hash3(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash3(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash3(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash3(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash3(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash3(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash3(i + vec3(1.0, 1.0, 1.0));

	float nx00 = mix(n000, n100, f.x);
	float nx10 = mix(n010, n110, f.x);
	float nx01 = mix(n001, n101, f.x);
	float nx11 = mix(n011, n111, f.x);

	float nxy0 = mix(nx00, nx10, f.y);
	float nxy1 = mix(nx01, nx11, f.y);

	return mix(nxy0, nxy1, f.z);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);

	float n = wave_noise(world_pos, TIME);
	VERTEX += NORMAL * n * wave_height;
}

void fragment() {
	vec3 view_dir = normalize(VIEW);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, view_dir), 0.0, 1.0), fresnel_power);

	vec3 base_col = mix(water_color.rgb, deep_color.rgb, fresnel * 0.5);

	// --- foam via depth intersection ---
	float raw_depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw_depth);
	vec4 view_pos = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view_pos.xyz /= view_pos.w;

	float scene_depth = -view_pos.z;
	float frag_depth = -VERTEX.z;
	float depth_diff = scene_depth - frag_depth;

	float foam_mask = 1.0 - clamp(depth_diff / foam_distance, 0.0, 1.0);
	foam_mask = smoothstep(0.0, 1.0, foam_mask);
	float edge_noise = smooth_noise(world_pos * foam_noise_scale + vec3(0.0, 0.0, TIME * 0.5));
	foam_mask *= mix(0.6, 1.0, edge_noise);

	vec3 final_col = mix(base_col, foam_color.rgb, foam_mask);

	ALBEDO = mix(final_col, base_col, fresnel * 0.4) + base_col * fresnel * 0.4;
	METALLIC = metallic_val * (1.0 - foam_mask);
	ROUGHNESS = mix(roughness_val, 0.9, foam_mask);
	SPECULAR = 0.6;

	ALPHA = clamp(max(water_color.a, foam_mask) + fresnel * 0.4, 0.0, 1.0);

	NORMAL = normalize(NORMAL + vec3(
		wave_noise(world_pos + vec3(0.1, 0.0, 0.0), TIME) - wave_noise(world_pos, TIME),
		0.0,
		wave_noise(world_pos + vec3(0.0, 0.0, 0.1), TIME) - wave_noise(world_pos, TIME)
	) * wave_height * 4.0);
}