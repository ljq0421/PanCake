shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform float wood_contrast : hint_range(0.5, 1.0) = 0.80;
uniform float wood_saturation : hint_range(0.5, 1.0) = 0.92;
uniform float scene_contrast : hint_range(0.5, 1.0) = 0.94;
uniform float scene_saturation : hint_range(0.5, 1.0) = 0.82;
uniform float center_lift : hint_range(0.0, 0.08) = 0.04;
uniform vec4 wood_base : source_color = vec4(0.725, 0.471, 0.243, 1.0);
uniform float wood_base_mix : hint_range(0.0, 0.3) = 0.14;

void fragment() {
	vec4 authored = texture(TEXTURE, UV);
	float worktop_mask = smoothstep(0.49, 0.66, UV.y);
	float luma = dot(authored.rgb, vec3(0.299, 0.587, 0.114));
	vec3 scene_softened = mix(vec3(luma), authored.rgb, scene_saturation);
	scene_softened = (scene_softened - vec3(0.5)) * scene_contrast + vec3(0.5);
	vec3 softened = mix(vec3(luma), authored.rgb, wood_saturation);
	softened = (softened - vec3(0.5)) * wood_contrast + vec3(0.5);
	softened = mix(softened, wood_base.rgb, wood_base_mix);
	float center = 1.0 - smoothstep(0.08, 0.52, abs(UV.x - 0.5));
	softened += vec3(center_lift * center);
	vec3 treated = mix(scene_softened, softened, worktop_mask);
	COLOR = vec4(clamp(treated, vec3(0.0), vec3(1.0)), authored.a);
}
