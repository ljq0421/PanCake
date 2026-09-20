shader_type canvas_item;

// Recolors only painted warm accents. Cream paper, dark ink, food and source artwork stay intact.
uniform vec4 primary : source_color;
uniform vec4 secondary : source_color;
uniform float recolor_paper = 0.0;
varying vec4 item_tint;

void vertex() { item_tint = COLOR; }

vec3 recolor(vec3 source, vec3 target) {
    const vec3 weights = vec3(0.2126, 0.7152, 0.0722);
    float light = dot(source, weights);
    float target_light = dot(target, weights);
    if (light < target_light)
        return target * light / max(target_light, 0.001);
    return mix(target, vec3(1.0), (light - target_light) / max(1.0 - target_light, 0.001));
}

void fragment() {
    vec4 source = texture(TEXTURE, UV);
    float high = max(source.r, max(source.g, source.b));
    float low = min(source.r, min(source.g, source.b));
    float saturation = (high - low) / max(high, 0.001);

    // Gold/orange artwork becomes Wuhan jade; coral becomes its softer companion tone.
    float warm = smoothstep(0.10, 0.28, saturation) * step(source.b, source.g) * step(source.g, source.r)
        * smoothstep(0.34, 0.58, high);
    float coral = smoothstep(0.13, 0.30, saturation) * step(source.g, source.r) * step(source.g, source.b)
        * smoothstep(0.34, 0.58, high);
    // Upgrade card backings have pale warm paper rather than saturated paint.
    float pale_warm = recolor_paper * smoothstep(0.035, 0.14, saturation) * step(source.b, source.g)
        * step(source.g, source.r) * smoothstep(0.52, 0.76, high) * (1.0 - smoothstep(0.93, 0.985, high));

    vec3 result = mix(source.rgb, recolor(source.rgb, primary.rgb), warm);
    result = mix(result, recolor(source.rgb, secondary.rgb), max(coral, pale_warm));
    COLOR = vec4(result, source.a) * item_tint;
}
