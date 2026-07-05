shader_type spatial;
render_mode blend_mix, diffuse_burley, specular_schlick_ggx, unshaded, cull_disabled;
uniform vec4 albedo : source_color = vec4(1.0, 0.5, 0.3, 1.0);
uniform float time_scale : hint_range(0.0, 3.0) = 0.2;   // animation speed
uniform float detail_scale : hint_range(0.05, 2.0) = 0.5; // was hardcoded 0.5 in myMap
uniform float fade_radius : hint_range(0.1, 5.0) = 1.0;   // where falloff starts (now half-extent of the box)
uniform float fade_softness : hint_range(0.01, 3.0) = 0.6; // how gradual the fade is
const float nudge = 0.739513;
const float normalizer = 1.0 / sqrt(1.0 + nudge*nudge);
uniform float field_scale : hint_range(1.0, 20.0) = 6.0; // expands local coords into the noise's natural domain
varying vec3 local_cam_pos;
varying vec3 local_vertex_pos;
uniform float shape_noise_amount : hint_range(0.0, 2.0) = 0.5;  // how irregular the edge is
uniform float shape_noise_scale : hint_range(0.1, 10.0) = 3.0;  // size of the bumps/lobes


float SpiralNoiseC(vec3 p) {
    float n = 0.0;
    float iter = 1.0;
    for (int i = 0; i < 8; i++) {
        n += -abs(sin(p.y*iter) + cos(p.x*iter)) / iter;
        p.xy += vec2(p.y, -p.x) * nudge;
        p.xy *= normalizer;
        p.xz += vec2(p.z, -p.x) * nudge;
        p.xz *= normalizer;
        iter *= 1.733733;
    }
    return n;
}
float NebulaNoise(vec3 p) {
    float final = p.y + 4.5;
    final -= SpiralNoiseC(p.xyz);
    final += SpiralNoiseC(p.zxy*0.5123+100.0)*4.0;
    return final;
}
float myMap(vec3 p) {
    float NebNoise = abs(NebulaNoise(p/detail_scale) * 0.5) + 0.03;
    return NebNoise;
}
void vertex() {
    local_cam_pos = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
    local_vertex_pos = VERTEX;
}
void fragment() {
    vec3 ray_dir = normalize(local_vertex_pos - local_cam_pos);
    float t_anim = TIME * time_scale;
    vec3 drift = vec3(t_anim*0.3, t_anim*0.15, t_anim*0.2);
    float ang = t_anim * 0.1;
    mat2 rot = mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang)));
    vec3 col = vec3(0.0);
    float alpha_accum = 0.0;
    float entry_dist = FRONT_FACING ? length(local_vertex_pos - local_cam_pos) : 0.0;
    float t = 0.0;
    for (int i = 0; i < 40; i++) {
        if (alpha_accum > 0.99 || t > 10.0) break;
        vec3 pos = local_cam_pos + (entry_dist + t) * ray_dir;
        vec3 sample_pos = pos * field_scale + drift;
        sample_pos.xz = rot * sample_pos.xz;
        float raw_d = myMap(sample_pos);
        float step_d = max(raw_d / field_scale, 0.04);
        float density = clamp(1.0 - raw_d * 5.0, 0.0, 1.0);
        density = pow(density, 2.0);
        if (density > 0.001) {
            vec3 ldst = -pos;
            float lDist = max(length(ldst), 0.05);
            vec3 glow = albedo.rgb / (lDist * lDist);
            vec3 local_color = mix(albedo.rgb * 0.4, glow, clamp(1.0 / lDist, 0.0, 1.0));
            float contrib = density * (1.0 - alpha_accum) * 0.5;
            col += local_color * contrib;
            alpha_accum += contrib;
        }
        t += max(step_d * 0.3, 0.03);
    }

// Fade based on the ray's closest approach to the center — NOT mesh vertex position.
    float t_closest = dot(-local_cam_pos, ray_dir);
    vec3 closest_point = local_cam_pos + ray_dir * max(t_closest, 0.0);

    float dist_from_center = length(closest_point);

    // Perturb the distance itself using noise based on direction from center.
    // This bends the fade boundary inward/outward differently depending on which
    // way you look, turning a perfect sphere into a random lumpy blob.
    vec3 dir_from_center = closest_point / max(dist_from_center, 0.001);
    float shape_noise = SpiralNoiseC(dir_from_center * shape_noise_scale + 50.0);
    dist_from_center += shape_noise * shape_noise_amount;

    float edge_fade = 1.0 - smoothstep(fade_radius, fade_radius + fade_softness, dist_from_center);

    ALBEDO = col;
    ALPHA = clamp(alpha_accum, 0.0, 1.0) * edge_fade;
}