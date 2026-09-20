shader_type canvas_item;
render_mode unshaded;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform int effect = 0;
uniform bool reverse_turn = false;
uniform vec4 area = vec4(0.0, 0.0, 1.0, 1.0);

void fragment() {
    vec2 uv = UV;
    float p = progress;
    vec4 old = texture(TEXTURE, uv);
    vec4 result = vec4(0.0);
    if (effect == 0) {
        // The departing sheet rolls across the spread; its warm reverse catches the light.
        float x = reverse_turn ? 1.0 - uv.x : uv.x;
        float edge = 1.0 - p * 1.26;
        float curl = 0.12 * sin(p * 3.14159265);
        float d = x - edge;
        if (d < 0.0) {
            result = old;
            result.rgb *= 1.0 - 0.22 * exp(d * 38.0) * sin(p * 3.14159265);
        } else if (d < curl) {
            float roll = d / max(curl, 0.0001);
            float bend = sin(roll * 3.14159265);
            float inset = 0.045 * bend;
            if (uv.y > inset && uv.y < 1.0 - inset) {
                result = vec4(mix(vec3(0.64, 0.46, 0.27), vec3(0.98, 0.92, 0.77), bend), 1.0);
            }
        } else {
            result = vec4(0.16, 0.09, 0.04, 0.24 * exp(-(d - curl) * 65.0) * sin(p * 3.14159265));
        }
    } else if (effect == 1) {
        // Close over the old scene, then draw both cloth panels aside over the new scene.
        float coverage = p < 0.42 ? smoothstep(0.0, 0.42, p) : 1.0 - smoothstep(0.46, 1.0, p);
        float side = min(uv.x, 1.0 - uv.x);
        result = p < 0.44 ? old : vec4(0.0);
        if (side < coverage * 0.502) {
            float cloth_x = side + (1.0 - coverage) * 0.5;
            float folds = 0.84 + 0.12 * cos(cloth_x * 100.0) + 0.04 * cos(cloth_x * 200.0);
            vec3 cloth = vec3(0.31, 0.19, 0.13) * folds;
            float hem = step(0.952, uv.y) * step(uv.y, 0.962);
            cloth = mix(cloth, vec3(0.72, 0.52, 0.28), hem);
            result = vec4(cloth, 1.0);
        }
    } else {
        vec2 local = (uv - area.xy) / max(area.zw, vec2(0.001));
        bool inside = all(greaterThanEqual(local, vec2(0.0))) && all(lessThanEqual(local, vec2(1.0)));
        result = vec4(old.rgb, 1.0 - p);
        if (inside) {
            if (effect == 2) {
                float width = p * 0.53;
                float distance = abs(local.x - 0.5);
                result.a = smoothstep(width - 0.018, width, distance);
                if (abs(distance - width) < 0.013 && p > 0.02 && p < 0.98)
                    result = vec4(vec3(0.70, 0.52, 0.31), 0.45);
            } else {
                float width = max(1.0 - p, 0.001);
                vec2 folded = vec2((local.x - 0.5) / width + 0.5, local.y);
                result = vec4(0.0);
                if (folded.x >= 0.0 && folded.x <= 1.0) {
                    result = texture(TEXTURE, area.xy + folded * area.zw);
                    result.rgb *= 1.0 - p * 0.25;
                    result.a = 1.0 - p;
                }
            }
        }
    }
    COLOR = p >= 0.999 ? vec4(0.0) : result;
}
