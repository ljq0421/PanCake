shader_type canvas_item;
render_mode unshaded;
uniform sampler2D destination : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D book_mask : repeat_disable, filter_linear;
uniform vec4 mask_fit = vec4(0.0, 0.0, 1.0, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform int effect = 6;
uniform vec4 backdrop = vec4(0.15, 0.10, 0.06, 0.65);
uniform vec4 area = vec4(0.0, 0.0, 1.0, 1.0);

float paper_alpha(vec2 page) {
    vec2 uv = (page - mask_fit.xy) / mask_fit.zw;
    if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) return 0.0;
    return texture(book_mask, uv).a;
}
float depth_at(float leaf, float lift, float flex) {
    // Folded edges lift TOWARDS the reader and settle away as the book opens.
    return 0.16 * lift * leaf + 0.10 * flex * sin(leaf * 3.14159265);
}
float projected_x(float leaf, float width, float lift, float flex) {
    // A flexible leaf unfurls progressively instead of rotating as a rigid slab.
    float curved = leaf - 0.56 * flex * sin(leaf * 3.14159265) / 3.14159265;
    return width * curved / (1.0 - depth_at(leaf, lift, flex));
}
vec2 unproject(vec2 local, float width, float lift, float flex) {
    float distance = abs(local.x - 0.5) * 2.0;
    if (distance > projected_x(1.0, width, lift, flex)) return vec2(-2.0);
    float low = 0.0;
    float high = 1.0;
    for (int i = 0; i < 12; i++) {
        float middle = (low + high) * 0.5;
        if (projected_x(middle, width, lift, flex) < distance) low = middle;
        else high = middle;
    }
    float leaf = (low + high) * 0.5;
    float perspective = 1.0 - depth_at(leaf, lift, flex);
    float bow = 0.020 * flex * sin(leaf * 3.14159265);
    float y = (local.y - 0.5) * perspective + 0.5 + bow;
    float side = local.x < 0.5 ? -1.0 : 1.0;
    return vec2(0.5 + side * leaf * 0.5, y);
}
void fragment() {
    bool opening = effect == 6;
    float spread = opening ? progress : 1.0 - progress;
    float angle = (1.0 - spread) * 1.57079633;
    float width = max(cos(angle), 0.0001);
    float lift = sin(angle);
    float flex = sin(spread * 3.14159265);
    vec2 local = (UV - area.xy) / area.zw;
    vec4 previous = texture(TEXTURE, UV);
    vec4 next = texture(destination, SCREEN_UV);
    vec3 background = opening ? previous.rgb : next.rgb;
    // Continuous full-viewport backdrop: no rectangular bounds or ghost book.
    vec3 result = mix(background, backdrop.rgb, backdrop.a * spread);
    vec2 page = unproject(local, width, lift, flex);
    float silhouette = paper_alpha(page);
    vec2 shadow_page = unproject(local - vec2(0.0, 0.014 * lift), width, lift, flex);
    float shadow = (paper_alpha(shadow_page + vec2(0.006, 0.0))
        + paper_alpha(shadow_page - vec2(0.006, 0.0)) + paper_alpha(shadow_page)) / 3.0;
    result *= 1.0 - shadow * 0.14 * lift * smoothstep(0.0, 0.06, spread);
    if (silhouette > 0.001 && spread > 0.001) {
        vec2 source = area.xy + page * area.zw;
        vec3 captured;
        vec3 source_background;
        if (opening) {
            captured = texture(destination, source).rgb;
            source_background = texture(TEXTURE, source).rgb;
        } else {
            captured = texture(TEXTURE, source).rgb;
            source_background = texture(destination, source).rgb;
        }
        source_background = mix(source_background, backdrop.rgb, backdrop.a);
        // Uncomposite the screenshot at the original paper's soft alpha edge.
        vec3 paper = clamp((captured - source_background * (1.0 - silhouette)) / max(silhouette, 0.01), vec3(0.0), vec3(1.0));
        float leaf = abs(page.x - 0.5) * 2.0;
        float crease = exp(-leaf * 18.0) * lift;
        float curved_light = sin(leaf * 3.14159265) * flex;
        paper *= 1.0 - 0.17 * crease - 0.10 * lift * leaf;
        paper = mix(paper, vec3(1.0, 0.96, 0.85), curved_light * 0.055);
        float rim = smoothstep(0.985, 1.0, leaf) * lift;
        paper = mix(paper, vec3(0.88, 0.77, 0.57), rim * 0.65);
        result = mix(result, paper, silhouette);
    }
    COLOR = progress >= 0.999 ? vec4(0.0) : vec4(result, 1.0);
}
