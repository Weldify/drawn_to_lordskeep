shader_type spatial;
render_mode diffuse_toon,specular_disabled;

uniform sampler2D tex: filter_nearest;

void vertex() {
	VERTEX.y += sin(TIME + VERTEX.x) * 0.02;
	VERTEX.y += cos(TIME + VERTEX.z) * 0.02;
}

void fragment() {
	vec2 uv = UV;
	uv.x += sin(TIME + (UV.x + UV.y) * 5.0) * 0.02;
	uv.y += cos(TIME + (UV.x - UV.y) * 5.0) * 0.02;
	ALBEDO = texture(tex, uv).rgb;
}