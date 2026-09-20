shader_type canvas_item;
render_mode unshaded;
uniform float progress = 0.0;
uniform bool reduced = false;
void fragment() {
    float p = clamp(progress, 0.0, 1.0);
    vec3 cream = vec3(1.0, 0.955, 0.86);
    if (reduced) {
        COLOR = vec4(cream, 1.0 - abs(2.0 * p - 1.0));
    } else {
        float phase = p < 0.5 ? p * 2.0 : (p - 0.5) * 2.0;
        float eased = phase * phase * (3.0 - 2.0 * phase);
        float edge = 1.0 - eased;
        float distance = p < 0.5 ? UV.x - edge : edge - UV.x;
        float curl = 0.035 * sin(phase * 3.14159265);
        vec3 paper = mix(vec3(0.77, 0.61, 0.40), cream, smoothstep(0.0, max(curl, 0.0001), distance));
        float alpha = distance >= 0.0 ? 1.0 : 0.24 * exp(distance * 90.0) * sin(phase * 3.14159265);
        if (p <= 0.0 || p >= 1.0) alpha = 0.0;
        COLOR = vec4(paper, alpha);
    }
}
