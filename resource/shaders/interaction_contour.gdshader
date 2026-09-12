shader_type canvas_item;
render_mode unshaded;

uniform sampler2D second_layer : filter_linear, repeat_disable;
uniform vec4 contour_color : source_color = vec4(1.0, 0.91, 0.64, 1.0);
uniform float outline_pixels = 2.0;
uniform vec2 art_size = vec2(100.0);
varying vec4 item_tint;

void vertex() { item_tint = COLOR; }

// Sampling both layers before dilation keeps the neck and head overlap clean.
void fragment() {
    vec2 uv = (UV * (art_size + vec2(10.0)) - vec2(5.0)) / art_size;
    vec2 pixel = vec2(length(vec2(dFdx(uv.x), dFdy(uv.x))),
                      length(vec2(dFdx(uv.y), dFdy(uv.y))));
    float inside = step(0.0, uv.x) * step(0.0, uv.y) * step(uv.x, 1.0) * step(uv.y, 1.0);
    float base = max(texture(TEXTURE, uv).a, texture(second_layer, uv).a) * inside;
    float edge = base;
    for (int i = 0; i < 16; i++) {
        float angle = float(i) * 0.392699082;
        vec2 sample_uv = uv + vec2(cos(angle), sin(angle)) * pixel * outline_pixels;
        float bounds = step(0.0, sample_uv.x) * step(0.0, sample_uv.y)
                     * step(sample_uv.x, 1.0) * step(sample_uv.y, 1.0);
        edge = max(edge, max(texture(TEXTURE, sample_uv).a, texture(second_layer, sample_uv).a) * bounds);
    }
    COLOR = vec4(contour_color.rgb, contour_color.a * max(0.0, edge - base)) * item_tint;
}
