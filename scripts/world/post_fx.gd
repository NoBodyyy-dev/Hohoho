class_name PostFX
extends RefCounted
## Пост-обработка под «чистый мультяшный» стиль (вайб Meccha Chameleon):
## экранный контур на всей геометрии + тёплый ровный свет вместо тёмного тумана.

const OUTLINE_SHADER := preload("res://shaders/toon_outline.gdshader")

## Крепит полноэкранный квад-контур к камере. Работает на любой геометрии,
## материалы трогать не нужно.
static func attach_outline(camera: Camera3D) -> void:
	if camera.has_node("ToonOutline"):
		return
	var quad := MeshInstance3D.new()
	quad.name = "ToonOutline"
	var qm := QuadMesh.new()
	qm.size = Vector2(2, 2)
	quad.mesh = qm
	var mat := ShaderMaterial.new()
	mat.shader = OUTLINE_SHADER
	quad.material_override = mat
	# всегда рисуется, не отсекается фрустумом камеры
	quad.extra_cull_margin = 16384.0
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	camera.add_child(quad)

## Мягкий «премиальный» мультяшный вид (вайб Meccha Chameleon): без обводки,
## мягкое global illumination, мягкие контактные тени, сочные тёплые цвета.
static func apply_clean_env(env: Environment) -> void:
	env.ambient_light_energy = 1.05
	env.ambient_light_color = Color(0.95, 0.9, 0.85)
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_white = 2.0
	env.tonemap_exposure = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.1
	env.glow_hdr_threshold = 1.2
	# мягкое global illumination — свет переотражается, углы не чёрные
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_min_cell_size = 0.2
	env.sdfgi_energy = 1.0
	# мягкое контактное затенение под предметами (как в Meccha) — деликатно
	env.ssao_enabled = true
	env.ssao_intensity = 1.4
	env.ssao_radius = 1.1
	env.ssao_power = 1.6
	env.ssao_detail = 0.4
	env.ssil_enabled = false
	# туман почти убран — чистая читаемая картинка
	env.volumetric_fog_enabled = false
	# сочнее и теплее, лёгкий контраст
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.28
	env.adjustment_contrast = 1.06
	env.adjustment_brightness = 1.02
