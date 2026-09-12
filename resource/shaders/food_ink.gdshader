shader_type canvas_item;
render_mode unshaded;

uniform vec4 ink : source_color = vec4(0.29, 0.16, 0.09, 1.0);
uniform float outline_pixels = 1.1;
uniform float detail_pixels = 0.45;
uniform float detail_strength = 0.65;
uniform bool key_green = false;
varying vec4 vertex_tint;

void vertex() { vertex_tint = COLOR; }

vec4 sample_art(sampler2D art, vec2 uv) {
    vec4 value = texture(art, uv);
    if (key_green) {
        float excess = value.g - max(value.r, value.b);
        value.a *= 1.0 - smoothstep(0.08, 0.35, excess);
        if (excess > 0.08) value.g = min(value.g, max(value.r, value.b));
    }
    return value;
}

// Derivatives keep the line weight stable when the same food is used in a
// stock pile, a drag preview, or a small order icon. No source image is changed.
void fragment() {
    vec4 tint = vertex_tint;
    vec4 base = sample_art(TEXTURE, UV);
    vec2 pixel = vec2(length(vec2(dFdx(UV.x), dFdy(UV.x))),
                      length(vec2(dFdx(UV.y), dFdy(UV.y))));
    float edge = base.a;
    float dark = 0.0;
    for (int i = 0; i < 8; i++) {
        float angle = float(i) * 0.785398163;
        vec2 direction = vec2(cos(angle), sin(angle));
        vec4 outside = sample_art(TEXTURE, UV + direction * pixel * outline_pixels);
        edge = max(edge, outside.a);
        vec4 inside = sample_art(TEXTURE, UV + direction * pixel * detail_pixels);
        float luminance = dot(inside.rgb, vec3(0.299, 0.587, 0.114));
        float brown = smoothstep(0.72, 0.95, inside.r / max(inside.g, 0.01));
        dark = max(dark, (1.0 - smoothstep(0.19, 0.38, luminance)) * inside.a * brown);
    }
    vec3 fill = mix(base.rgb, ink.rgb, dark * detail_strength);
    float alpha = max(base.a, edge);
    COLOR = vec4(mix(ink.rgb, fill, base.a), alpha) * tint;
}
