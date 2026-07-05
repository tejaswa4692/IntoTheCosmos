shader_type spatial;

render_mode unshaded,
            cull_front,
            blend_add,
            depth_draw_never;

uniform sampler2D noise_tex;

uniform vec3 color_a : source_color = vec3(0.15,0.2,0.9);
uniform vec3 color_b : source_color = vec3(0.7,0.2,1.0);

uniform float scale = 0.00035;
uniform float density = 0.45;
uniform float emission_strength = 4.0;
uniform float drift_speed = 0.002;

void fragment()
{
    vec2 uv = WORLD_POSITION.xz * scale;

    uv += vec2(
        TIME * drift_speed,
        TIME * drift_speed * 0.4
    );

    float n = 0.0;

    n += texture(noise_tex, uv).r;
    n += texture(noise_tex, uv * 2.0).r * 0.5;
    n += texture(noise_tex, uv * 4.0).r * 0.25;

    n /= 1.75;

    n = smoothstep(density, 1.0, n);

    vec3 nebula =
        mix(color_a, color_b, n);

    ALBEDO = vec3(0.0);

    EMISSION = nebula * n * emission_strength;

    ALPHA = n * 0.15;
}