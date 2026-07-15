shader_type spatial;
render_mode blend_add, depth_draw_never, cull_front, unshaded, world_vertex_coords;

uniform vec3 planet_center = vec3(0.0, 0.0, 0.0);
uniform float planet_radius = 10.0;
uniform float atmosphere_radius = 11.5;
uniform vec3 rayleigh_coefficients = vec3(5.5, 13.0, 22.4); // scaled by 0.001 below; blue scatters most
uniform float mie_coefficient = 21.0;
uniform float density_falloff = 8.0;
uniform float intensity = 20.0;
uniform vec3 sun_direction = vec3(1.0, 0.0, 0.0);
uniform sampler2D depth_texture : hint_depth_texture, filter_linear;

const int IN_SCATTER_POINTS = 10;
const int OPTICAL_DEPTH_POINTS = 6;

varying vec3 world_pos;

void vertex() {
	world_pos = VERTEX; // world_vertex_coords makes this world-space already
}

vec2 ray_sphere(vec3 center, float radius, vec3 ro, vec3 rd) {
	vec3 offset = ro - center;
	float b = 2.0 * dot(offset, rd);
	float c = dot(offset, offset) - radius * radius;
	float d = b * b - 4.0 * c;
	if (d > 0.0) {
		float s = sqrt(d);
		float dst_near = max(0.0, (-b - s) * 0.5);
		float dst_far = (-b + s) * 0.5;
		if (dst_far >= 0.0) {
			return vec2(dst_near, dst_far - dst_near);
		}
	}
	return vec2(1e9, 0.0);
}

float density_at_point(vec3 point) {
	float height01 = clamp((length(point - planet_center) - planet_radius) / (atmosphere_radius - planet_radius), 0.0, 1.0);
	return exp(-height01 * density_falloff) * (1.0 - height01);
}

float optical_depth(vec3 ro, vec3 rd, float ray_length) {
	vec3 sample_point = ro;
	float step_size = ray_length / float(OPTICAL_DEPTH_POINTS - 1);
	float depth = 0.0;
	for (int i = 0; i < OPTICAL_DEPTH_POINTS; i++) {
		depth += density_at_point(sample_point) * step_size;
		sample_point += rd * step_size;
	}
	return depth;
}

vec3 calculate_scatter(vec3 ro, vec3 rd, float ray_length) {
	vec3 point = ro;
	float step_size = ray_length / float(IN_SCATTER_POINTS - 1);
	vec3 scattered = vec3(0.0);

	for (int i = 0; i < IN_SCATTER_POINTS; i++) {
		float sun_ray_length = ray_sphere(planet_center, atmosphere_radius, point, sun_direction).y;
		float sun_depth = optical_depth(point, sun_direction, sun_ray_length);
		float view_depth = optical_depth(point, -rd, step_size * float(i));
		vec3 transmittance = exp(-(sun_depth + view_depth) * (rayleigh_coefficients * 0.001 + mie_coefficient * 0.001));
		scattered += density_at_point(point) * transmittance * step_size;
		point += rd * step_size;
	}
	return scattered * (rayleigh_coefficients * 0.001) * intensity;
}

void fragment() {
	vec3 cam_pos = CAMERA_POSITION_WORLD;
	vec3 view_dir = normalize(world_pos - cam_pos);

	vec2 hit = ray_sphere(planet_center, atmosphere_radius, cam_pos, view_dir);

	float depth = texture(depth_texture, SCREEN_UV).r;
	float scene_dist;
	if (depth <= 0.00001) {
		// Nothing drawn here (empty space/sky) - don't treat the camera's far
		// clip plane as a solid occluder, or distant atmospheres get clipped to invisible.
		scene_dist = 1e20;
	} else {
		vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
		vec4 world = INV_VIEW_MATRIX * (INV_PROJECTION_MATRIX * vec4(ndc, 1.0));
		world.xyz /= world.w;
		scene_dist = length(world.xyz - cam_pos);
	}

	float dst_through = max(0.0, min(hit.y, scene_dist - hit.x));

	if (dst_through > 0.0) {
		vec3 entry_point = cam_pos + view_dir * (hit.x + 0.001);
		vec3 light = calculate_scatter(entry_point, view_dir, dst_through - 0.002);
		ALBEDO = light;
		ALPHA = clamp(length(light), 0.0, 1.0);
	} else {
		ALPHA = 0.0;
	}
}