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

## Чистая тёплая среда: светлее, меньше тумана/SSAO, мягкий bloom.
## Дом читается ясно, силуэты чёткие — как в мультяшных кооп-играх.
static func apply_clean_env(env: Environment) -> void:
	env.ambient_light_energy = 1.15
	env.ambient_light_color = Color(0.95, 0.9, 0.85)
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_white = 2.0
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 1.1
	# лёгкая экспозиция вверх — уют, а не мрак
	env.tonemap_exposure = 1.15
	# мягкое затенение в углах, но без тяжёлого «грязного» AO
	env.ssao_enabled = true
	env.ssao_intensity = 1.1
	env.ssao_radius = 0.9
	env.ssao_power = 1.4
	env.ssil_enabled = false
	# туман почти убираем — чистая читаемая картинка
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.004
	env.volumetric_fog_albedo = Color(0.9, 0.85, 0.95)
	env.volumetric_fog_gi_inject = 0.3
	# чуть подкрутим цвет: сочнее и теплее
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.22
	env.adjustment_contrast = 1.08
	env.adjustment_brightness = 1.04
