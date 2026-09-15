shader_type canvas_item;

// Data texture at the original PNG size: R = leather/spine, G = ornaments.
// AtlasTexture supplies source-image UVs, so do not normalize to the cropped rect.
uniform sampler2D region_mask : filter_linear, repeat_disable;
uniform vec4 cover_color : source_color;
uniform vec4 ornament_color : source_color;
varying vec4 item_tint;

void vertex() { item_tint = COLOR; }

vec3 recolor(vec3 source, vec3 target) {
    const vec3 weights = vec3(0.2126, 0.7152, 0.0722);
    float light = dot(source, weights);
    float target_light = dot(target, weights);
    // Preserve texture/shading luminance, including pale ink and dark outlines.
    if (light < target_light) {
        return target * light / max(target_light, 0.001);
    }
    return mix(target, vec3(1.0), (light - target_light) / max(1.0 - target_light, 0.001));
}

void fragment() {
    vec4 source = texture(TEXTURE, UV);
    vec2 mask = texture(region_mask, UV).rg;
    vec3 result = source.rgb * (1.0 - mask.r - mask.g)
        + recolor(source.rgb, cover_color.rgb) * mask.r
        + recolor(source.rgb, ornament_color.rgb) * mask.g;
    COLOR = vec4(result, source.a) * item_tint;
}
