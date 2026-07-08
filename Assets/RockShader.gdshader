shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform float base_roughness : hint_range(0.0, 1.0) = 0.9;
uniform float noise_scale = 6.0;
uniform float noise_contrast : hint_range(0.0, 1.0) = 0.35;

varying vec4 v_custom;
varying vec4 v_instance_color;

// Simple hash + value-noise, fully procedural, no textures sampled.
float hash(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);

	float n000 = hash(i + vec3(0.0, 0.0, 0.0));
	float n100 = hash(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash(i + vec3(1.0, 1.0, 1.0));

	float nx00 = mix(n000, n100, f.x);
	float nx10 = mix(n010, n110, f.x);
	float nx01 = mix(n001, n101, f.x);
	float nx11 = mix(n011, n111, f.x);

	float nxy0 = mix(nx00, nx10, f.y);
	float nxy1 = mix(nx01, nx11, f.y);

	return mix(nxy0, nxy1, f.z);
}

varying vec3 v_world_pos;

void vertex() {
	v_custom = INSTANCE_CUSTOM;
	v_instance_color = COLOR;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	
	// Offset the noise field per-instance using the random seed, so every
	// rock samples a different-looking pattern even though they all share
	// this exact material.
	vec3 seed_offset = v_custom.rgb * 137.0;
	float n1 = value_noise((v_world_pos * noise_scale) + seed_offset);
	float n2 = value_noise((v_world_pos * noise_scale * 2.3) + seed_offset + 50.0);
	float combined_noise = n1 * 0.65 + n2 * 0.35;

	vec3 base = v_instance_color.rgb;
	vec3 shaded = base * mix(1.0 - noise_contrast, 1.0 + noise_contrast * 0.4, combined_noise);

	ALBEDO = shaded;
	ROUGHNESS = clamp(base_roughness + (combined_noise - 0.5) * 0.2, 0.0, 1.0);
	METALLIC = 0.0;
}
