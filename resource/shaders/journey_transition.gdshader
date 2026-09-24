shader_type canvas_item;
render_mode unshaded;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform int effect = 0;
uniform bool reverse_turn = false;
uniform vec4 area = vec4(0.0, 0.0, 1.0, 1.0);
uniform sampler2D book_art : source_color, filter_linear;
uniform vec4 mask_fit = vec4(0.0, 0.0, 1.0, 1.0);

vec4 book_paper(vec2 local) {
    vec2 fitted = (local - mask_fit.xy) / mask_fit.zw;
    if (any(lessThan(fitted, vec2(0.0))) || any(greaterThan(fitted, vec2(1.0)))) return vec4(0.0);
    return texture(book_art, fitted);
}

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
    } else if (effect == 8) {
        // The photographed right leaf folds into the spine, then its paper reverse
        // opens over the left leaf. The real artwork supplies the page silhouette.
        vec2 local = (uv - area.xy) / max(area.zw, vec2(0.001));
        bool inside = all(greaterThanEqual(local, vec2(0.0))) && all(lessThanEqual(local, vec2(1.0)));
        float settle = 1.0 - smoothstep(0.82, 1.0, p);
        result = vec4(old.rgb, settle);
        if (inside) {
            float x = reverse_turn ? 1.0 - local.x : local.x;
            float spine = 0.5;
            float y = local.y;
            float lift = sin(p * 3.14159265);
            if (p < 0.5) {
                float turn = smoothstep(0.0, 1.0, p * 2.0);
                float width = 0.5 * (1.0 - turn);
                float edge = spine + width + lift * (0.026 * sin(y * 3.14159265) + 0.015 * (y - 0.5));
                if (x < spine) {
                    result = old;
                } else if (x <= edge && width > 0.001) {
                    float source_x = spine + (x - spine) * 0.5 / max(edge - spine, 0.001);
                    vec2 source = vec2(reverse_turn ? 1.0 - source_x : source_x, y);
                    vec4 paper = book_paper(source);
                    result = texture(TEXTURE, area.xy + source * area.zw);
                    float rim = smoothstep(0.78, 1.0, (x - spine) / max(edge - spine, 0.001));
                    result.rgb *= 1.0 - 0.16 * lift + 0.24 * lift * rim;
                    result.a = paper.a;
                } else {
                    float shadow = 0.24 * lift * exp(-max(x - edge, 0.0) * 62.0);
                    result = vec4(0.18, 0.11, 0.06, shadow * book_paper(local).a);
                }
            } else {
                float turn = smoothstep(0.0, 1.0, (p - 0.5) * 2.0);
                float width = 0.5 * turn;
                float edge = spine - width - lift * (0.026 * sin(y * 3.14159265) + 0.015 * (y - 0.5));
                if (x >= spine) {
                    result = vec4(0.0);
                } else if (x >= edge && width > 0.001) {
                    float source_x = spine + (spine - x) * 0.5 / max(spine - edge, 0.001);
                    vec2 source = vec2(reverse_turn ? 1.0 - source_x : source_x, y);
                    vec4 paper = book_paper(source);
                    vec3 plain_paper = book_paper(vec2(0.65, 0.5)).rgb;
                    float painted_edge = 1.0 - smoothstep(0.025, 0.11, min(y, 1.0 - y));
                    vec3 underside = mix(plain_paper, paper.rgb, 0.08 + 0.78 * painted_edge);
                    underside *= 1.0 - 0.17 * lift * (1.0 - (spine - x) / max(spine - edge, 0.001));
                    result = vec4(underside, paper.a * settle);
                } else {
                    result = vec4(old.rgb, settle);
                    float shadow = 0.22 * lift * exp(-max(edge - x, 0.0) * 55.0);
                    result.rgb = mix(result.rgb, vec3(0.19, 0.11, 0.06), shadow);
                }
            }
        }
    } else if (effect == 4 || effect == 5) {
        // A bounded paper curl crosses the spread and its spine. Closing mirrors
        // the turn, without folding the workbench or the full-screen dimmer.
        vec2 local = (uv - area.xy) / max(area.zw, vec2(0.001));
        bool inside = all(greaterThanEqual(local, vec2(0.0))) && all(lessThanEqual(local, vec2(1.0)));
        result = vec4(old.rgb, 1.0 - p);
        if (inside) {
            float x = effect == 5 ? 1.0 - local.x : local.x;
            float lift = sin(p * 3.14159265);
            float curl = 0.19 * lift;
            // A slight tilt and bowed fold keep the edge from reading as a wipe.
            float edge = 1.0 - p * 1.22
                + lift * (0.045 * (local.y - 0.5) + 0.025 * sin(local.y * 3.14159265));
            float d = x - edge;
            result = vec4(0.0);
            if (d < 0.0) {
                result = old;
                result.rgb *= 1.0 - 0.20 * exp(d * 45.0) * lift;
            } else if (d < curl) {
                float roll = d / max(curl, 0.0001);
                float bend = sin(roll * 3.14159265);
                float inset = 0.032 * bend * lift;
                if (local.y >= inset && local.y <= 1.0 - inset) {
                    vec3 paper = mix(vec3(0.66, 0.48, 0.29), vec3(0.99, 0.94, 0.82), pow(bend, 0.55));
                    // The departing book's ink shows faintly through its reverse.
                    float source_x = clamp(edge - d, 0.0, 1.0);
                    if (effect == 5) {
                        vec3 ink = texture(TEXTURE, area.xy + vec2(1.0 - source_x, local.y) * area.zw).rgb;
                        paper = mix(paper, ink, 0.07 * bend);
                    }
                    result = vec4(paper, smoothstep(0.0, 0.035, p));
                }
            } else {
                float shadow = 0.26 * exp(-(d - curl) * 48.0) * lift;
                result = vec4(0.18, 0.10, 0.04, shadow);
            }
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
