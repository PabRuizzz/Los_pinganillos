shader_type canvas_item;
render_mode unshaded;

float hash_cell(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

float soft_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 f = fract(point);
	vec2 weight = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash_cell(cell), hash_cell(cell + vec2(1.0, 0.0)), weight.x),
		mix(hash_cell(cell + vec2(0.0, 1.0)), hash_cell(cell + vec2(1.0, 1.0)), weight.x),
		weight.y
	);
}

void fragment() {
	// Shear the noise along the wind so the dust travels in diagonal sheets.
	vec2 wind = vec2(UV.x, UV.y - UV.x * 0.24);
	float haze = soft_noise(wind * vec2(4.0, 11.0) - vec2(TIME * 1.9, TIME * 0.15));
	float gust = soft_noise(wind * vec2(6.0, 42.0) - vec2(TIME * 6.0, TIME * 0.32));
	float streaks = soft_noise(wind * vec2(18.0, 165.0) - vec2(TIME * 33.0, TIME * 0.6));
	float grains = smoothstep(0.68, 0.9, streaks);
	float dust = 0.14 + haze * 0.23 + smoothstep(0.37, 0.88, gust) * 0.24 + grains * 0.19;
	vec3 color = mix(vec3(0.66, 0.24, 0.11), vec3(1.0, 0.63, 0.37), haze * 0.55 + grains * 0.42);
	COLOR = vec4(color, dust) * COLOR;
}
