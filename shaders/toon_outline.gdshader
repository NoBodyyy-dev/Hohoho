shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, fog_disabled;
// Полноэкранный контур: рисуем чёрную обводку там, где резко меняется глубина
// или нормаль. Даёт «мультяшный» край на ВСЕЙ геометрии, не трогая материалы.
// Квад крепится к камере и всегда закрывает вьюпорт.

uniform float outline_thickness : hint_range(0.5, 3.0) = 1.2;
uniform float depth_threshold : hint_range(0.001, 0.2) = 0.035;
uniform float normal_threshold : hint_range(0.1, 1.5) = 0.55;
uniform vec4 outline_color : source_color = vec4(0.05, 0.04, 0.08, 1.0);

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest;

void vertex() {
	// разворачиваем квад на весь экран в clip-space
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float linear_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec3 ndc = vec3(uv * 2.0 - 1.0, d);
	vec4 view = inv_proj * vec4(ndc, 1.0);
	return -view.z / view.w;
}

void fragment() {
	vec2 px = outline_thickness / VIEWPORT_SIZE;
	vec3 base = texture(screen_tex, SCREEN_UV).rgb;

	// края по глубине (4 соседа крестом)
	float dc = linear_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	float dl = linear_depth(SCREEN_UV + vec2(-px.x, 0.0), INV_PROJECTION_MATRIX);
	float dr = linear_depth(SCREEN_UV + vec2( px.x, 0.0), INV_PROJECTION_MATRIX);
	float du = linear_depth(SCREEN_UV + vec2(0.0, -px.y), INV_PROJECTION_MATRIX);
	float dd = linear_depth(SCREEN_UV + vec2(0.0,  px.y), INV_PROJECTION_MATRIX);
	float depth_edge = (abs(dc - dl) + abs(dc - dr) + abs(dc - du) + abs(dc - dd));
	float de = step(depth_threshold * dc, depth_edge);

	// края по нормали
	vec3 nc = texture(normal_tex, SCREEN_UV).xyz;
	vec3 nl = texture(normal_tex, SCREEN_UV + vec2(-px.x, 0.0)).xyz;
	vec3 nr = texture(normal_tex, SCREEN_UV + vec2( px.x, 0.0)).xyz;
	vec3 nu = texture(normal_tex, SCREEN_UV + vec2(0.0, -px.y)).xyz;
	vec3 nd = texture(normal_tex, SCREEN_UV + vec2(0.0,  px.y)).xyz;
	float ndiff = (1.0 - dot(nc, nl)) + (1.0 - dot(nc, nr)) + (1.0 - dot(nc, nu)) + (1.0 - dot(nc, nd));
	float ne = step(normal_threshold, ndiff);

	// небо (глубина ~0) не обводим — контур только на объектах
	float on_geo = step(0.0001, texture(depth_tex, SCREEN_UV).r);
	float edge = clamp(de + ne, 0.0, 1.0) * on_geo;

	ALBEDO = mix(base, outline_color.rgb, edge * outline_color.a);
}
