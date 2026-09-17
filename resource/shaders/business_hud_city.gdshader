shader_type canvas_item;

uniform vec4 accent : source_color;
uniform vec4 outline : source_color;
varying vec4 tint;

void vertex() {
    tint = COLOR;
}

void fragment() {
    vec4 painted = texture(TEXTURE, UV);
    // Coordinates belong to the original HUD atlas. Keep the calendar, clock,
    // coin and cream writing area intact; recolor only its painted frame/ties.
    vec2 source = UV / TEXTURE_PIXEL_SIZE;
    float frame = max(max(1.0 - step(340.0, source.x), step(1680.0, source.x)),
                      max(1.0 - step(325.0, source.y), step(505.0, source.y)));
    float warmth = smoothstep(0.28, 0.40, (painted.r - painted.b) / max(painted.r, 0.001));
    float lightness = dot(painted.rgb, vec3(0.299, 0.587, 0.114));
    vec3 dark = outline.rgb * 0.55;
    vec3 light = mix(accent.rgb, vec3(1.0, 0.98, 0.89), 0.74);
    vec3 city = mix(dark, accent.rgb, smoothstep(0.05, 0.5, lightness));
    city = mix(city, light, smoothstep(0.5, 0.86, lightness));
    COLOR = tint * vec4(mix(painted.rgb, city, frame * warmth), painted.a);
}
