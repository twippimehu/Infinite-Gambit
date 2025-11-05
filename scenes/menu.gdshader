shader_type canvas_item;

uniform vec2 scroll = vec2(0.100, 0.100); // scroll speed
uniform float darken = 0.25;              // 0 = normal, 1 = black

void fragment() {
    vec2 uv = UV + TIME * scroll;
    vec4 col = texture(TEXTURE, uv);
    col.rgb = mix(col.rgb, vec3(0.0), darken);
    COLOR = col;
}
