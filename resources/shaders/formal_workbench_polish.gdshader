shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform float intensity : hint_range(0.0, 1.0) = 0.72;

void fragment() {
	vec2 uv = UV;
	float edge_distance = distance(uv, vec2(0.5, 0.51));
	float vignette = smoothstep(0.38, 0.78, edge_distance) * 0.075;
	float counter_edge = exp(-pow((uv.y - 0.59) / 0.018, 2.0)) * 0.095;
	float counter_depth = smoothstep(0.58, 1.0, uv.y) * 0.035;
	float morning_pool = (1.0 - smoothstep(0.12, 0.58, distance(uv, vec2(0.47, 0.43)))) * 0.050;
	float window_pool = (1.0 - smoothstep(0.08, 0.34, distance(uv, vec2(0.10, 0.34)))) * 0.035;
	float griddle_contact = (1.0 - smoothstep(0.72, 1.08, length((uv - vec2(0.42, 0.77)) / vec2(0.18, 0.16)))) * 0.095;
	float tool_contact = (1.0 - smoothstep(0.68, 1.10, length((uv - vec2(0.60, 0.80)) / vec2(0.12, 0.13)))) * 0.065;

	float dark_alpha = (vignette + counter_edge + counter_depth + griddle_contact + tool_contact) * intensity;
	float warm_alpha = (morning_pool + window_pool) * intensity;
	float alpha = clamp(dark_alpha + warm_alpha, 0.0, 0.18);
	vec3 dark_tint = vec3(0.13, 0.055, 0.025);
	vec3 warm_tint = vec3(1.0, 0.68, 0.32);
	vec3 tint = mix(dark_tint, warm_tint, warm_alpha / max(alpha, 0.0001));
	COLOR = vec4(tint, alpha);
}
