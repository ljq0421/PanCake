shader_type canvas_item;

// Reuse the original nine-slice artwork, including its exact alpha and steam accents.
uniform vec4 paper_color : source_color = vec4(0.969, 0.953, 0.910, 1.0);
uniform vec4 ink_color : source_color = vec4(0.141, 0.349, 0.310, 1.0);
uniform vec4 accent_color : source_color = vec4(0.290, 0.620, 0.545, 1.0);
uniform vec4 accent_light : source_color = vec4(0.670, 0.863, 0.780, 1.0);
varying vec4 item_tint;

void vertex() { item_tint = COLOR; }

void fragment() {
    vec4 source = texture(TEXTURE, UV);
    float high = max(source.r, max(source.g, source.b));
    float low = min(source.r, min(source.g, source.b));
    float paper = smoothstep(0.58, 0.86, low / max(high, 0.001));
    vec3 accent = mix(accent_color.rgb, accent_light.rgb, smoothstep(0.48, 0.85, source.g));
    vec3 fill = mix(accent, paper_color.rgb, paper);
    vec3 ink = ink_color.rgb * mix(0.60, 1.0, smoothstep(0.10, 0.55, high));
    vec3 recolored = mix(ink, fill, smoothstep(0.46, 0.87, high));
    COLOR = vec4(recolored, source.a) * item_tint;
}
