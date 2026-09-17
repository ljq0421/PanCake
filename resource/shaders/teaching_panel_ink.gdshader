shader_type canvas_item;

varying vec4 item_tint;
void vertex() { item_tint = COLOR; }

// Stronger chocolate ink from the approved dialog reference. Keep paper and gold intact.
void fragment() {
    vec4 source = texture(TEXTURE, UV);
    float brightness = max(source.r, max(source.g, source.b));
    float ink = 1.0 - smoothstep(0.38, 0.62, brightness);
    source.rgb = mix(source.rgb, vec3(0.24, 0.105, 0.035), ink * 0.8);
    COLOR = source * item_tint;
}
