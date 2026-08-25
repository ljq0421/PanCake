shader_type canvas_item;
render_mode unshaded;

// The generated overlay uses a magenta key instead of an alpha channel so the
// hand-painted mat pixels can remain untouched. The threshold also softens
// the anti-aliased edge against the wooden workbench.
void fragment() {
	vec4 sampled = texture(TEXTURE, UV);
	float magenta_strength = min(sampled.r, sampled.b) - sampled.g;
	float matte_alpha = 1.0 - smoothstep(0.32, 0.58, magenta_strength);
	COLOR = vec4(sampled.rgb, sampled.a * matte_alpha);
}
