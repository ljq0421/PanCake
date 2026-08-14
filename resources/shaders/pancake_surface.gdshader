shader_type canvas_item;
render_mode unshaded;

uniform sampler2D field_texture : filter_linear;
uniform sampler2D damage_texture : filter_linear;
uniform sampler2D sauce_texture : filter_linear;
uniform sampler2D chili_sauce_field : filter_linear;
uniform sampler2D egg_texture : filter_linear;
uniform sampler2D raw_texture : repeat_enable, filter_linear;
uniform sampler2D cooked_texture : repeat_enable, filter_linear;
uniform sampler2D charred_texture : repeat_enable, filter_linear;
uniform sampler2D edge_texture : repeat_enable, filter_linear;
uniform sampler2D egg_surface_texture : repeat_enable, filter_linear;
uniform sampler2D sweet_sauce_texture : repeat_enable, filter_linear;
uniform sampler2D chili_sauce_texture : repeat_enable, filter_linear;
uniform vec2 field_texel_size = vec2(0.0078125);
uniform float pan_height_ratio = 0.694;
uniform float fold_left_line_ratio = 0.38;
uniform float fold_right_line_ratio = 0.62;
uniform float fold_left_progress = 0.0;
uniform float fold_right_progress = 0.0;
uniform float fillings_enclosed = 0.0;
uniform float package_hidden = 0.0;
uniform int view_mode = 0;

vec3 thickness_heat(float value) {
	float t = clamp(value, 0.0, 1.0);
	vec3 cold = vec3(0.08, 0.16, 0.34);
	vec3 even = vec3(0.16, 0.86, 0.90);
	vec3 thick = vec3(1.0, 0.25, 0.08);
	return t < 0.5 ? mix(cold, even, t * 2.0) : mix(even, thick, (t - 0.5) * 2.0);
}

void fragment() {
	vec4 fields = texture(field_texture, UV);
	float coverage = fields.r;
	float thickness = fields.g;
	float wetness = fields.b;
	float doneness = fields.a;
	float damage = texture(damage_texture, UV).r;
	float sauce = texture(sauce_texture, UV).r;
	float chili_sauce = texture(chili_sauce_field, UV).r;
	vec4 egg_fields = texture(egg_texture, UV);
	float sauce_debug = max(sauce, chili_sauce);
	vec2 pan_delta = UV - vec2(0.5);
	float pan_distance = length(vec2(pan_delta.x, pan_delta.y / max(pan_height_ratio, 0.01)));
	float pan_mask = 1.0 - step(0.5, pan_distance);

	if (view_mode > 0) {
		vec3 debug_color = vec3(0.10, 0.12, 0.14);
		float debug_alpha = 0.34;
		if (view_mode == 1) {
			debug_color = coverage > 0.01 ? vec3(0.93, 0.76, 0.28) : debug_color;
			debug_alpha = coverage > 0.01 ? 0.92 : debug_alpha;
		} else if (view_mode == 2) {
			debug_color = thickness_heat(thickness);
			debug_alpha = mix(0.34, 0.98, step(0.001, thickness));
		} else if (view_mode == 3) {
			debug_color = mix(vec3(0.12, 0.33, 0.55), vec3(0.35, 0.88, 1.0), wetness);
			debug_alpha = mix(0.32, 0.95, wetness);
		} else if (view_mode == 4) {
			debug_color = mix(vec3(0.85, 0.69, 0.38), vec3(0.38, 0.10, 0.04), doneness);
			debug_alpha = mix(0.35, 0.98, doneness);
		} else if (view_mode == 5) {
			debug_color = mix(vec3(0.12, 0.12, 0.14), vec3(1.0, 0.12, 0.18), damage);
			debug_alpha = mix(0.30, 0.98, damage);
		} else if (view_mode == 6) {
			debug_color = mix(vec3(0.94, 0.78, 0.30), vec3(0.42, 0.035, 0.018), sauce_debug);
			debug_alpha = mix(0.28, 0.98, smoothstep(0.01, 0.65, sauce_debug));
		} else if (view_mode == 7) {
			float egg_total = egg_fields.r + egg_fields.g;
			float white_ratio = egg_fields.r / max(egg_total, 0.001);
			debug_color = mix(vec3(1.0, 0.52, 0.03), vec3(1.0, 0.95, 0.72), white_ratio);
			debug_alpha = mix(0.28, 0.98, smoothstep(0.005, 0.08, egg_fields.a));
		}
		COLOR = vec4(debug_color, debug_alpha * pan_mask);
	} else {
		vec2 detail_uv = UV;
		vec3 raw_color = texture(raw_texture, detail_uv).rgb;
		vec3 cooked_color = texture(cooked_texture, detail_uv).rgb;
		vec3 charred_color = texture(charred_texture, detail_uv).rgb;
		float cooked_mix = smoothstep(0.12, 0.72, doneness);
		float charred_mix = smoothstep(0.76, 1.0, doneness);
		vec3 pancake_color = mix(raw_color, cooked_color, cooked_mix);
		pancake_color = mix(pancake_color, charred_color, charred_mix);
		// Fresh batter must remain legible against the dark griddle before it
		// begins to brown.  Wetness only affects presentation; simulation fields
		// and scoring remain unchanged.
		float raw_batter_visibility = wetness * (1.0 - cooked_mix);
		pancake_color = mix(pancake_color, vec3(0.92, 0.82, 0.58), raw_batter_visibility * 0.34);
		pancake_color += vec3(0.055, 0.042, 0.018) * raw_batter_visibility;

		float neighbor_coverage = min(
			min(texture(field_texture, UV + vec2(field_texel_size.x, 0.0)).r, texture(field_texture, UV - vec2(field_texel_size.x, 0.0)).r),
			min(texture(field_texture, UV + vec2(0.0, field_texel_size.y)).r, texture(field_texture, UV - vec2(0.0, field_texel_size.y)).r)
		);
		float edge = coverage * (1.0 - smoothstep(0.20, 0.82, neighbor_coverage));
		float edge_detail = texture(edge_texture, detail_uv).r;
		pancake_color *= mix(0.92, 1.08, wetness * texture(raw_texture, detail_uv.yx).r);
		pancake_color *= mix(0.86, 1.08, clamp(thickness * 1.25, 0.0, 1.0));
		pancake_color = mix(pancake_color, pancake_color * mix(0.62, 0.82, edge_detail), edge * 0.72);
		pancake_color = mix(pancake_color, vec3(0.30, 0.055, 0.025), damage * 0.78);
		vec4 egg_left = texture(egg_texture, UV - vec2(field_texel_size.x * 2.0, 0.0));
		vec4 egg_right = texture(egg_texture, UV + vec2(field_texel_size.x * 2.0, 0.0));
		vec4 egg_up = texture(egg_texture, UV - vec2(0.0, field_texel_size.y * 2.0));
		vec4 egg_down = texture(egg_texture, UV + vec2(0.0, field_texel_size.y * 2.0));
		float egg_neighbor_amount = max(max(egg_left.a, egg_right.a), max(egg_up.a, egg_down.a));
		float egg_visual_amount = max(egg_fields.a, egg_neighbor_amount * 0.72);
		float egg_total = egg_fields.r + egg_fields.g;
		float egg_white_ratio = egg_fields.r / max(egg_total, 0.001);
		vec3 raw_egg_color = mix(vec3(1.0, 0.53, 0.02), vec3(1.0, 0.95, 0.73), egg_white_ratio);
		vec3 set_egg_color = mix(vec3(0.94, 0.39, 0.015), vec3(1.0, 0.88, 0.57), egg_white_ratio);
		vec3 egg_color = mix(raw_egg_color, set_egg_color, smoothstep(0.18, 0.78, egg_fields.b));
		vec3 egg_material = texture(egg_surface_texture, detail_uv * 1.18 + vec2(0.07, 0.03)).rgb;
		float egg_material_warmth = clamp(egg_material.r - egg_material.b, 0.0, 1.0);
		float yolk_streak = smoothstep(0.07, 0.19, egg_material_warmth);
		float white_gloss = smoothstep(0.86, 0.99, min(egg_material.g, egg_material.b));
		vec3 egg_material_boosted = mix(vec3(1.0, 0.92, 0.67), vec3(1.0, 0.58, 0.035), yolk_streak * 0.68);
		egg_material_boosted = mix(egg_material_boosted, vec3(1.0, 0.98, 0.84), white_gloss * 0.42);
		egg_color = mix(egg_color, egg_material_boosted, 0.88);
		float egg_visibility = smoothstep(0.0005, 0.022, egg_visual_amount) * coverage;
		float left_landing_edge = mix(fold_left_line_ratio, min(1.0, fold_left_line_ratio * 2.0), clamp(fold_left_progress, 0.0, 1.0));
		float right_landing_edge = mix(fold_right_line_ratio, max(0.0, fold_right_line_ratio * 2.0 - 1.0), clamp(fold_right_progress, 0.0, 1.0));
		float left_filling_occlusion = (1.0 - step(max(fold_left_line_ratio, left_landing_edge), UV.x)) * clamp(fold_left_progress, 0.0, 1.0);
		float right_filling_occlusion = step(min(fold_right_line_ratio, right_landing_edge), UV.x) * clamp(fold_right_progress, 0.0, 1.0);
		float filling_visibility = (1.0 - max(left_filling_occlusion, right_filling_occlusion)) * (1.0 - clamp(fillings_enclosed, 0.0, 1.0));
		egg_visibility *= filling_visibility;
		float egg_opacity = mix(0.64, 0.94, egg_fields.b);
		float egg_edge = clamp((egg_neighbor_amount - egg_fields.a) * 5.0, 0.0, 1.0);
		egg_color = mix(egg_color, vec3(1.0, 0.96, 0.77), egg_edge * 0.32);
		pancake_color = mix(pancake_color, egg_color, egg_visibility * egg_opacity);
		// The fold overlay is opaque and performs the actual landing occlusion.
		// Fading sauce across the estimated landing span changes the color of
		// stationary, still-exposed brush marks before the flap reaches them.
		float stationary_sauce_visibility = 1.0 - clamp(fillings_enclosed, 0.0, 1.0);
		float sauce_visibility = smoothstep(0.015, 0.32, sauce) * stationary_sauce_visibility;
		vec3 sweet_color = texture(sweet_sauce_texture, detail_uv).rgb;
		vec3 chili_color = texture(chili_sauce_texture, detail_uv).rgb;
		pancake_color = mix(pancake_color, sweet_color, sauce_visibility * 0.82);
		float chili_visibility = smoothstep(0.015, 0.32, chili_sauce) * stationary_sauce_visibility;
		pancake_color = mix(pancake_color, chili_color, chili_visibility * 0.80);

		float alpha = smoothstep(0.02, 0.32, coverage) * pan_mask;
		alpha *= 1.0 - smoothstep(0.91, 1.0, damage);
		float left_fold_source = 1.0 - step(fold_left_line_ratio, UV.x);
		float right_fold_source = step(fold_right_line_ratio, UV.x);
		float folded_source = max(
			left_fold_source * clamp(fold_left_progress, 0.0, 1.0),
			right_fold_source * clamp(fold_right_progress, 0.0, 1.0)
		);
		alpha *= 1.0 - folded_source;
		alpha *= 1.0 - clamp(package_hidden, 0.0, 1.0);
		COLOR = vec4(pancake_color, alpha);
	}
}
