shader_type canvas_item;
render_mode unshaded;

// 黑色遮罩=未涂抹；白色=已涂抹。遮罩是数据，不使用 source_color。
uniform sampler2D reveal_mask : filter_linear, repeat_disable;
uniform float complete_reveal : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    float painted = texture(reveal_mask, UV).r;
    // COLOR 已包含贴图颜色与 CanvasItem 调制，不再重复乘主贴图。
    // 主贴图自身的透明边界仍然有效。
    COLOR.a *= mix(painted, 1.0, complete_reveal);
}
