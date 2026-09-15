shader_type canvas_item;
// Only the painted sign layer is adjusted; text, icons and alpha remain untouched.
void fragment() {
    vec4 ink = texture(TEXTURE, UV) * COLOR;
    float light = dot(ink.rgb, vec3(0.299, 0.587, 0.114));
    vec3 paper = vec3(0.98, 0.935, 0.825);
    float amount = mix(0.13, 0.2, smoothstep(0.65, 0.95, light));
    COLOR = vec4(mix(ink.rgb, paper, amount), ink.a);
}
