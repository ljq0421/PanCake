shader_type canvas_item;

uniform vec4 accent : source_color = vec4(0.44, 0.63, 0.55, 1.0);
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);
// 1: warm accent pixels, 2: book corners, 3: portrait inner ring,
// 4: separator, 5: note tape/corner. Never attached to food or status artwork.
uniform int area = 1;
varying vec4 item_tint;

void vertex() { item_tint = COLOR; }

void fragment() {
    vec4 source = texture(TEXTURE, UV);
    vec2 local = (UV - region.xy) / region.zw;
    float high = max(source.r, max(source.g, source.b));
    float low = min(source.r, min(source.g, source.b));
    float saturation = (high - low) / max(high, 0.001);
    // Protect cream paper and the dark brown outlines.
    float mask = smoothstep(0.22, 0.38, saturation) * smoothstep(0.58, 0.74, high);
    mask *= step(source.b, source.g) * step(source.g, source.r);
    if (area == 2) {
        // Only the small three-petal ornaments, never the book's leather cover.
        float edge_x = min(local.x, 1.0 - local.x);
        float edge_y = min(local.y, 1.0 - local.y);
        mask *= smoothstep(0.025, 0.035, edge_x) * (1.0 - smoothstep(0.070, 0.085, edge_x));
        mask *= smoothstep(0.030, 0.045, edge_y) * (1.0 - smoothstep(0.100, 0.120, edge_y));
    } else if (area == 3) {
        float radius = length(local - vec2(0.5));
        mask = smoothstep(0.29, 0.32, radius) * (1.0 - smoothstep(0.38, 0.41, radius)) * smoothstep(0.62, 0.76, high);
    } else if (area == 5) {
        float tape = (1.0 - smoothstep(0.10, 0.15, local.x)) * (1.0 - smoothstep(0.24, 0.32, local.y));
        float dots = smoothstep(0.90, 0.94, local.x) * (1.0 - smoothstep(0.38, 0.48, local.y));
        mask *= max(tape, dots);
    }
    vec3 tinted = accent.rgb * mix(0.85, 1.12, high);
    if (area == 4) { mask = 1.0; tinted = accent.rgb; }
    COLOR = vec4(mix(source.rgb, tinted, mask), source.a) * item_tint;
}
