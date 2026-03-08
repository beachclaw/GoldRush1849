shader_type spatial;
render_mode depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4  water_color   : source_color = vec4(0.15, 0.38, 0.68, 1.0);
uniform vec4  shallow_color : source_color = vec4(0.22, 0.55, 0.75, 1.0);
uniform float wave_speed    : hint_range(0.0, 5.0)  = 0.8;
uniform float wave_scale    : hint_range(0.1, 10.0) = 2.0;
uniform float wave_height   : hint_range(0.0, 1.0)  = 0.18;
uniform float foam_thresh   : hint_range(0.0, 1.0)  = 0.72;

void vertex() {
	// Two crossing sine waves — creates rolling, non-repeating surface
	float w1 = sin(VERTEX.x * wave_scale       + TIME * wave_speed * 2.6) * wave_height;
	float w2 = sin(VERTEX.z * wave_scale * 1.5 + TIME * wave_speed * 2.0) * wave_height * 0.7;
	float w3 = sin((VERTEX.x + VERTEX.z) * wave_scale * 0.7 + TIME * wave_speed * 1.4) * wave_height * 0.4;
	VERTEX.y += w1 + w2 + w3;

	// Pass wave height to fragment for foam
	NORMAL = normalize(vec3(
		-cos(VERTEX.x * wave_scale + TIME * wave_speed * 2.6) * wave_height * wave_scale,
		1.0,
		-cos(VERTEX.z * wave_scale * 1.5 + TIME * wave_speed * 2.0) * wave_height * wave_scale * 0.7
	));
}

void fragment() {
	// Downstream flow animation
	vec2 flow_uv = vec2(UV.x + TIME * wave_speed * 0.04,
	                    UV.y - TIME * wave_speed * 0.22);

	// Two shimmer layers at different scales
	float s1 = sin(flow_uv.x * 14.0 + flow_uv.y * 8.0) * 0.5 + 0.5;
	float s2 = sin(flow_uv.x * 6.0  - flow_uv.y * 11.0 + TIME * 1.2) * 0.5 + 0.5;
	float shimmer = (s1 * 0.6 + s2 * 0.4);

	// Flow stripe pattern (darker troughs, lighter crests)
	float stripe = smoothstep(0.3, 0.7, fract(flow_uv.y * 5.0 + shimmer * 0.3));

	// Colour: blend deep/shallow based on shimmer
	vec3 col = mix(water_color.rgb, shallow_color.rgb, shimmer * 0.4);
	col += vec3(stripe * 0.05, stripe * 0.07, stripe * 0.04);

	// Sparkle highlights — tiny bright flecks
	float sparkle = step(0.94, s1 * s2);
	col += vec3(sparkle * 0.35);

	// Foam on wave peaks (high VERTEX.y maps to bright white edge)
	float foam = smoothstep(foam_thresh, 1.0, s1);
	col = mix(col, vec3(0.95, 0.97, 1.0), foam * 0.25);

	ALBEDO    = col;
	ALPHA     = 1.0;
	SPECULAR  = 0.95;
	ROUGHNESS = 0.04;
	// Fake subsurface glow
	SSS_STRENGTH = 0.3;
}
