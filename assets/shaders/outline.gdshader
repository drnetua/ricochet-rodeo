// Контур «inverted hull»: друга оболонка, роздута вздовж нормалей і повернута навиворіт.
// Товщина майже стала на екрані: росте з відстанню до камери.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled, fog_disabled;

uniform vec4 outline_color : source_color = vec4(0.09, 0.055, 0.035, 1.0);
uniform float thickness = 0.0022;
uniform float max_width = 0.06;

void vertex() {
	vec4 vpos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float scale = length(MODEL_MATRIX[0].xyz);
	float w = min(thickness * max(-vpos.z, 0.3), max_width) / max(scale, 0.0001);
	VERTEX += normalize(NORMAL) * w;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
