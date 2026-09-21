shader_type canvas_item;

uniform vec4 accent : source_color;
uniform vec4 outline : source_color;
uniform vec4 paper : source_color;
varying vec4 tint;

void vertex() { tint = COLOR; }

void fragment() {
    vec4 painted = texture(TEXTURE, UV);
    float lightness = dot(painted.rgb, vec3(0.299, 0.587, 0.114));
    vec3 city = mix(outline.rgb * 0.55, accent.rgb, smoothstep(0.05, 0.53, lightness));
    city = mix(city, paper.rgb, smoothstep(0.53, 0.93, lightness));
    // Mask only the baked gold star medallion in daily-challenge-pendant-v1.png.
    // Dynamic gold stars and reward controls are separate, unshaded children.
    float medal = 1.0 - smoothstep(0.93, 1.05, length((UV - vec2(0.075, 0.459)) / vec2(0.075, 0.219)));
    COLOR = tint * vec4(mix(city, painted.rgb, medal), painted.a);
}
