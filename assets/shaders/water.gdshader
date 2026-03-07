shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4  water_color : source_color = vec4(0.18, 0.42, 0.72, 0.82);
uniform float wave_speed  : hint_range(0.0, 5.0) = 0.6;
uniform float wave_scale  : hint_range(0.1, 10.0) = 2.5;
uniform float wave_height : hint_range(0.0, 0.5)  = 0.04;

void vertex() {
	float wx = sin(VERTEX.x * wave_scale       + TIME * wave_speed * 2.8) * wave_height;
	float wz = sin(VERTEX.z * wave_scale * 1.4 + TIME * wave_speed * 2.1) * wave_height * 0.6;
	VERTEX.y += wx + wz;
}

void fragment() {
	float flow    = fract(UV.y - TIME * wave_speed * 0.18);
	float shimmer = sin(UV.x * 18.0 + TIME * wave_speed * 3.0) * 0.5 + 0.5;
	vec3  col     = water_color.rgb + vec3(shimmer * 0.06, shimmer * 0.08, shimmer * 0.04);
	float stripe  = smoothstep(0.45, 0.55, fract(flow * 6.0));
	col          += vec3(stripe * 0.04);
	ALBEDO        = col;
	ALPHA         = water_color.a;
	SPECULAR      = 0.9;
	ROUGHNESS     = 0.05;
}
