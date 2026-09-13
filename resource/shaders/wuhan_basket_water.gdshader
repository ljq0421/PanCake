shader_type canvas_item;
render_mode unshaded;

uniform sampler2D basket_mask : filter_linear_mipmap, repeat_disable;
uniform vec4 mask_region;
uniform vec4 basket_rect;
uniform float water_y;
uniform vec2 water_center;
uniform vec2 water_radius;
varying vec2 local_position;

void vertex() { local_position = VERTEX; }

void fragment() {
    vec2 basket_uv = (local_position - basket_rect.xy) / basket_rect.zw;
    float silhouette = texture(basket_mask, mask_region.xy + basket_uv * mask_region.zw).a;
    float depth = smoothstep(water_y - 2.0, water_y + 12.0, local_position.y);
    float in_water = 1.0 - smoothstep(0.96, 1.0, length((local_position - water_center) / water_radius));
    // Sample undisturbed water at this fixed world position. The mask follows the
    // original antialiased basket silhouette, with no polygon-shaped blue patch.
    vec4 water = texture(TEXTURE, UV);
    COLOR = vec4(water.rgb, silhouette * depth * in_water * 0.96);
}
