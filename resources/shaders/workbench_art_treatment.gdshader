shader_type canvas_item;
render_mode blend_mix, unshaded;

// Shared P1 treatment for authored transparent workstation props.  It keeps
// the source artwork while aligning saturation, warm outlines, top-left light,
// and bottom-right contact shadows across machines and containers.
uniform float saturation : hint_range(0.0, 1.5) = 0.92;
uniform float contrast : hint_range(0.5, 1.5) = 0.96;
uniform vec4 tint_color : source_color = vec4(0.90, 0.86, 0.78, 1.0);
uniform float tint_mix : hint_range(0.0, 1.0) = 0.04;
uniform float green_replacement_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 outline_color : source_color = vec4(0.22, 0.14, 0.09, 0.96);
uniform float outline_texels : hint_range(0.0, 24.0) = 9.0;
uniform vec4 shadow_color : source_color = vec4(0.24, 0.15, 0.10, 0.30);
uniform vec2 shadow_offset_texels = vec2(11.0, 14.0);
uniform vec4 highlight_color : source_color = vec4(1.0, 0.94, 0.78, 0.82);
uniform float highlight_strength : hint_range(0.0, 1.0) = 0.18;

// When target is greater than source, the lower authored panel is compressed
// while the basket/top section receives the released height.
uniform float panel_source_split : hint_range(0.0, 1.0) = 1.0;
uniform float panel_target_split : hint_range(0.0, 1.0) = 1.0;

vec2 remap_panel_uv(vec2 uv) {
	if (panel_source_split >= 0.999 || panel_target_split <= panel_source_split) {
		return uv;
	}
	float mapped_y;
	if (uv.y <= panel_target_split) {
		mapped_y = uv.y / panel_target_split * panel_source_split;
	} else {
		mapped_y = panel_source_split + (uv.y - panel_target_split) / (1.0 - panel_target_split) * (1.0 - panel_source_split);
	}
	return vec2(uv.x, clamp(mapped_y, 0.0, 1.0));
}

void fragment() {
	vec2 source_uv = remap_panel_uv(UV);
	vec4 authored = texture(TEXTURE, source_uv);
	float alpha = authored.a;
	vec2 radius = TEXTURE_PIXEL_SIZE * outline_texels;
	float neighbor_alpha = 0.0;
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, remap_panel_uv(UV + vec2(radius.x, 0.0))).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, remap_panel_uv(UV - vec2(radius.x, 0.0))).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, remap_panel_uv(UV + vec2(0.0, radius.y))).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, remap_panel_uv(UV - vec2(0.0, radius.y))).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, remap_panel_uv(UV + radius)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, remap_panel_uv(UV - radius)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, remap_panel_uv(UV + vec2(radius.x, -radius.y))).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, remap_panel_uv(UV + vec2(-radius.x, radius.y))).a);

	float outline_alpha = max(neighbor_alpha - alpha, 0.0) * outline_color.a;
	float shadow_sample = texture(TEXTURE, remap_panel_uv(UV - TEXTURE_PIXEL_SIZE * shadow_offset_texels)).a;
	float shadow_alpha = shadow_sample * (1.0 - max(alpha, outline_alpha)) * shadow_color.a;

	float luma = dot(authored.rgb, vec3(0.299, 0.587, 0.114));
	vec3 treated = mix(vec3(luma), authored.rgb, saturation);
	treated = (treated - vec3(0.5)) * contrast + vec3(0.5);
	treated = mix(treated, treated * tint_color.rgb, tint_mix);
	float green_dominance = smoothstep(0.02, 0.28, authored.g - max(authored.r, authored.b));
	vec3 bean_green = tint_color.rgb * mix(0.78, 1.12, smoothstep(0.12, 0.72, luma));
	treated = mix(treated, bean_green, green_dominance * green_replacement_strength);

	float upper_left_edge = max(alpha - texture(TEXTURE, remap_panel_uv(UV - radius * 0.72)).a, 0.0);
	treated = mix(treated, highlight_color.rgb, upper_left_edge * highlight_strength * highlight_color.a);

	vec4 composed = vec4(shadow_color.rgb, shadow_alpha);
	composed.rgb = mix(composed.rgb, outline_color.rgb, outline_alpha);
	composed.a = max(composed.a, outline_alpha);
	composed.rgb = mix(composed.rgb, treated, alpha);
	composed.a = alpha + composed.a * (1.0 - alpha);
	COLOR = composed;
}
