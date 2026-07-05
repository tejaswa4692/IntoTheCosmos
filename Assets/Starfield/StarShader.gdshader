shader_type spatial;

render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform sampler2D star_texture;

void vertex()
{
    mat4 modified_model_view = VIEW_MATRIX * mat4(
        INV_VIEW_MATRIX[0],
        INV_VIEW_MATRIX[1],
        INV_VIEW_MATRIX[2],
        MODEL_MATRIX[3]
    );

    MODELVIEW_MATRIX = modified_model_view;
}

void fragment()
{
    vec4 tex = texture(star_texture, UV);

    float twinkle =
        0.9 +
        0.05 *
        sin(TIME * 10.0);

    vec3 col = tex.rgb * COLOR.rgb * twinkle;

    ALBEDO = col;
    EMISSION = col;
    ALPHA = tex.a;
}