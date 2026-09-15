shader_type canvas_item;

uniform vec4 paper_color : source_color = vec4(1.0, 0.953, 0.847, 1.0);
uniform float lighten_amount : hint_range(0.0, 1.0) = 0.55;
varying vec4 item_tint;

void vertex() { item_tint = COLOR; }

void fragment() {
    vec4 source = texture(TEXTURE, UV);
    // Warm paper is much brighter than the chocolate outline; preserve the ink and alpha.
    float paper_mask = smoothstep(0.48, 0.76, source.r);
    vec3 lightened = mix(source.rgb, paper_color.rgb, paper_mask * lighten_amount);
    COLOR = vec4(lightened, source.a) * item_tint;
}
