shader_type canvas_item;
render_mode unshaded;
uniform sampler2D first_layer : filter_linear, repeat_disable;
uniform sampler2D second_layer : filter_linear, repeat_disable;
uniform vec4 contour_color : source_color = vec4(1.0, 0.91, 0.64, 1.0);
uniform float outline_pixels = 4.0;
uniform bool has_second = false;
uniform vec3 first_uv_x;
uniform vec3 first_uv_y;
uniform vec3 second_uv_x;
uniform vec3 second_uv_y;
uniform vec2 first_flip;
uniform vec2 second_flip;
uniform vec4 first_clip = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 second_clip = vec4(0.0, 0.0, 1.0, 1.0);
varying vec4 item_tint;
varying vec2 local_position;
void vertex() { item_tint = COLOR; local_position = VERTEX; }
float layer_alpha(sampler2D art, vec2 p, vec3 row_x, vec3 row_y, vec2 flip, vec4 clip) {
    vec2 uv = vec2(dot(row_x, vec3(p, 1.0)), dot(row_y, vec3(p, 1.0)));
    float bounds = step(clip.x, uv.x) * step(clip.y, uv.y) * step(uv.x, clip.z) * step(uv.y, clip.w);
    bounds *= step(0.0, uv.x) * step(0.0, uv.y) * step(uv.x, 1.0) * step(uv.y, 1.0);
    uv = mix(uv, vec2(1.0) - uv, flip);
    return texture(art, uv).a * bounds;
}
float silhouette(vec2 p) {
    float a = layer_alpha(first_layer, p, first_uv_x, first_uv_y, first_flip, first_clip);
    if (has_second) a = max(a, layer_alpha(second_layer, p, second_uv_x, second_uv_y, second_flip, second_clip));
    return a;
}
void fragment() {
    vec2 dx = dFdx(local_position);
    vec2 dy = dFdy(local_position);
    float base = silhouette(local_position);
    float edge = base;
    // Fill the disk so thin tips cannot leave gaps inside a thick outline.
    for (int radius = 1; radius <= 5; radius++) {
        if (float(radius) > outline_pixels) { break; }
        float distance_px = float(radius);
        for (int i = 0; i < 16; i++) {
            float angle = float(i) * 0.392699082;
            edge = max(edge, silhouette(local_position + (cos(angle) * dx + sin(angle) * dy) * distance_px));
        }
    }
    COLOR = vec4(contour_color.rgb, contour_color.a * max(0.0, edge - base)) * item_tint;
}
