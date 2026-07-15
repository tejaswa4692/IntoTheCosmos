shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float aberration_strength : hint_range(0.0, 0.1) = 0.004;
uniform float vignette_influence : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	vec2 center = vec2(0.5, 0.5);
	vec2 dir = SCREEN_UV - center;
	float dist = length(dir);

	float strength = aberration_strength * pow(dist * 2.0, vignette_influence);
	vec2 offset = normalize(dir) * strength;

	float r = texture(screen_texture, SCREEN_UV - offset).r;
	float g = texture(screen_texture, SCREEN_UV).g;
	float b = texture(screen_texture, SCREEN_UV + offset).b;

	COLOR = vec4(r, g, b, 1.0);
}