shader_type canvas_item;

// Data texture at the original PNG size: R = leather/spine, G = ornaments.
// AtlasTexture supplies source-image UVs, so do not normalize to the cropped rect.
uniform sampler2D region_mask : filter_linear, repeat_disable;
uniform vec4 cover_color : source_color;
uniform vec4 ornament_color : source_color;
uniform vec4 note_color : source_color;
uniform float note_enabled = 0.0;
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

float cross2(vec2 from, vec2 to, vec2 point) {
    vec2 edge = to - from;
    vec2 relative = point - from;
    return edge.x * relative.y - edge.y * relative.x;
}

float information_slip_mask(vec2 point) {
    // Trace the supplied note's four printed paper edges in source-image UV space.
    vec2 top_left = vec2(0.523, 0.175);
    vec2 top_right = vec2(0.876, 0.149);
    vec2 bottom_right = vec2(0.905, 0.717);
    vec2 bottom_left = vec2(0.548, 0.755);
    return step(0.0, cross2(top_left, top_right, point))
        * step(0.0, cross2(top_right, bottom_right, point))
        * step(0.0, cross2(bottom_right, bottom_left, point))
        * step(0.0, cross2(bottom_left, top_left, point));
}

void fragment() {
    vec4 source = texture(TEXTURE, UV);
    vec2 mask = texture(region_mask, UV).rg;
    vec3 result = source.rgb * (1.0 - mask.r - mask.g)
        + recolor(source.rgb, cover_color.rgb) * mask.r
        + recolor(source.rgb, ornament_color.rgb) * mask.g;
    // The right-page information slip is printed into the master rather than exported as a separate asset.
    // Restrict the tint to its warm paper pixels, so the handwritten content and food artwork remain unchanged.
    float high = max(source.r, max(source.g, source.b));
    float low = min(source.r, min(source.g, source.b));
    float saturation = (high - low) / max(high, 0.001);
    float note_bounds = information_slip_mask(UV);
    float note_paper = (1.0 - smoothstep(0.15, 0.31, saturation)) * smoothstep(0.76, 0.91, high);
    float note_rule = smoothstep(0.10, 0.30, saturation) * step(source.b, source.g) * step(source.g, source.r)
        * smoothstep(0.49, 0.74, high);
    result = mix(result, recolor(source.rgb, note_color.rgb), note_enabled * note_bounds * note_paper);
    result = mix(result, recolor(source.rgb, ornament_color.rgb), note_enabled * note_bounds * note_rule);
    COLOR = vec4(result, source.a) * item_tint;
}
