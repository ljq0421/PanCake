shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform vec4 charcoal_color : source_color = vec4(0.212, 0.200, 0.184, 1.0);
uniform vec4 warm_shadow : source_color = vec4(0.20, 0.13, 0.09, 0.28);
uniform vec4 rim_highlight : source_color = vec4(0.86, 0.72, 0.54, 0.24);

void fragment() {
	vec4 authored = texture(TEXTURE, UV);
	float luma = dot(authored.rgb, vec3(0.299, 0.587, 0.114));
	float neutral = 1.0 - smoothstep(0.08, 0.24, max(max(authored.r, authored.g), authored.b) - min(min(authored.r, authored.g), authored.b));
	float dark_metal = (1.0 - smoothstep(0.24, 0.47, luma)) * neutral;
	vec3 charcoal_detail = charcoal_color.rgb * mix(0.96, 1.18, smoothstep(0.02, 0.42, luma));
	vec3 treated = mix(authored.rgb, charcoal_detail, dark_metal * 0.84);
	float top_light = clamp((1.0 - UV.x) * (1.0 - UV.y) * 1.35, 0.0, 1.0);
	treated = mix(treated, rim_highlight.rgb, rim_highlight.a * top_light * authored.a * 0.18);
	float lower_weight = smoothstep(0.62, 0.96, UV.y);
	treated = mix(treated, warm_shadow.rgb, warm_shadow.a * lower_weight * 0.12);
	COLOR = vec4(treated, authored.a);
}
