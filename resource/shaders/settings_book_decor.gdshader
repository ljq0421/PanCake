shader_type canvas_item;
render_mode unshaded;

// Shared by settings and city pages opened from home. Coordinates refer to the source book atlas.
float spot(vec2 uv, vec2 center, vec2 radius) {
    return 1.0 - smoothstep(0.65, 1.0, length((uv - center) / radius));
}
void fragment() {
    vec4 source = texture(TEXTURE, UV);
    float small_stars = max(spot(UV, vec2(.111, .319), vec2(.016, .024)),
                           spot(UV, vec2(.932, .398), vec2(.015, .026)));
    small_stars = max(small_stars, spot(UV, vec2(.826, .833), vec2(.014, .024)));
    small_stars = max(small_stars, spot(UV, vec2(.934, .647), vec2(.021, .034)));
    float paths = max(spot(UV, vec2(.16, .805), vec2(.022, .065)),
                     spot(UV, vec2(.897, .697), vec2(.025, .069)));
    float ink = 1.0 - smoothstep(.80, .95, min(source.r, min(source.g, source.b)));
    source.rgb = mix(source.rgb, vec3(1.0, .962, .891), max(small_stars, paths) * .35 * ink);
    COLOR = source;
}
