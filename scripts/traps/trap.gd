class_name Trap
extends Node3D
## Установленная ловушка на клетке. Area3D ловит Санту, эффект берётся из Defs.TRAPS.

signal triggered(trap: Trap, body: Node3D)

var trap_id: String
var def: Dictionary
var cell: Vector2i
var quality := 1.0          # 0.6..1.0 от QTE при установке; <0.75 — шанс осечки
var hidden := false         # под ковром
var visibility := 0.5       # итоговая заметность для грабителя
var spent := false
var chandelier: Node3D = null  # для rope_chandelier
var retrigger_cd := 0.0
var link: Dictionary = {}      # {"type": "chandelier"/"shelf", "cell": Vector2i, ...}
var delay := 0.0               # задержка срабатывания связанного объекта
var wire: Dictionary = {}      # {a, b} — нить растяжки в МИРОВЫХ координатах
var placer: Node3D = null      # кто поставил: свои ловушки его не бьют

func setup(id: String, p_cell: Vector2i, p_quality: float, p_hidden: bool, vis_mult: float, opts: Dictionary = {}) -> void:
	trap_id = id
	def = Defs.TRAPS[id]
	cell = p_cell
	quality = p_quality
	hidden = p_hidden
	link = opts.get("link", {})
	delay = float(opts.get("delay", 0.0))
	wire = opts.get("wire", {})
	visibility = def["vis"] * vis_mult * (Defs.CARPET_VIS_MULT if hidden else 1.0)
	placer = opts.get("placer", null)
	# ghost-установка даёт точную точку на поверхности; фолбэк — центр клетки
	position = opts.get("pos", Defs.cell_to_world(cell))
	# на стене/потолке — ловушка ложится плашмя по нормали поверхности
	var normal: Vector3 = opts.get("normal", Vector3.UP)
	if normal.y < 0.9:
		var x := normal.cross(Vector3.UP)
		if x.length() < 0.01:
			x = Vector3.RIGHT
		x = x.normalized()
		basis = Basis(x, normal, x.cross(normal))
	_build_visual()
	_build_area()

func _process(delta: float) -> void:
	if retrigger_cd > 0.0:
		retrigger_cd -= delta

func _build_area() -> void:
	var area := Area3D.new()
	area.name = "Area"
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	if not wire.is_empty():
		# растяжка: триггер-полоса вдоль всей нити
		var a: Vector3 = wire["a"] - position
		var b: Vector3 = wire["b"] - position
		var v := Vector3(b.x - a.x, 0, b.z - a.z)
		var l := maxf(v.length(), 1.0)
		shape.size = Vector3(0.5, 1.6, l)
		col.position = Vector3((a.x + b.x) * 0.5, 0.8, (a.z + b.z) * 0.5)
		col.rotation.y = atan2(v.x, v.z)
	else:
		shape.size = Vector3(1.0, 1.6, 1.0)
		col.position = Vector3(0, 0.8, 0)
	col.shape = shape
	area.add_child(col)
	# ловим и грабителей (слой 1|4), и мелких (слой 2) — дружеский огонь включён
	area.collision_mask = 7
	add_child(area)
	area.body_entered.connect(_on_body)

func _on_body(body: Node3D) -> void:
	if spent or retrigger_cd > 0.0:
		return
	var is_robber := body.is_in_group("robbers")
	var is_kid := body.is_in_group("kids")
	if not is_robber and not is_kid:
		return
	# свои ловушки поставившего не трогают; приманки на мелких не работают
	if is_kid and (body == placer or bool(def.get("bait", false))):
		return
	# осечка: плохо поставленная ловушка может не сработать
	if quality < 0.75 and randf() < 0.4:
		spent = def["oneshot"]
		if spent:
			_fizzle()
		return
	if def["oneshot"]:
		spent = true
	# 1.0с — чтобы работал пинг-понг «шарики → банан → обратно на шарики»
	retrigger_cd = 1.0
	triggered.emit(self, body)
	_play_trigger_fx()

## Цепное срабатывание от соседней ловушки/провода. body=null — эффект на грабителя.
func force_trigger(body: Node3D = null) -> void:
	if spent:
		return
	if def["oneshot"]:
		spent = true
	retrigger_cd = 1.0
	triggered.emit(self, body)
	_play_trigger_fx()

## Провод: подключить эту ловушку к объекту дома на расстоянии.
func attach_link(p_link: Dictionary, p_delay: float) -> void:
	link = p_link.duplicate()
	link["trigger_cell"] = cell
	delay = p_delay
	_draw_link_wire()

## Скрытое комбо петарда+масло: лужа вспыхивает и становится зоной паники.
func become_fire() -> void:
	if spent:
		return
	trap_id = "fire"
	def = {
		"name": "Горящее масло", "item": "oil",
		"slow": 0.55, "slow_dur": 3.0, "stun": 0.5, "scare": true,
		"vis": 0.95, "oneshot": false, "capture_mult": 1.0,
	}
	visibility = 0.95
	retrigger_cd = 0.0
	for c in get_children():
		if c is MeshInstance3D:
			c.queue_free()
	# пламя
	var parts := GPUParticles3D.new()
	parts.amount = 26
	parts.lifetime = 0.6
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.35, 0.05, 0.35)
	pm.gravity = Vector3(0, 2.2, 0)
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 0.8
	pm.direction = Vector3(0, 1, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.1
	parts.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.16, 0.16)
	var qm := StandardMaterial3D.new()
	qm.albedo_color = Color(1.0, 0.55, 0.12, 0.9)
	qm.emission_enabled = true
	qm.emission = Color(1.0, 0.45, 0.1)
	qm.emission_energy_multiplier = 2.2
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = qm
	parts.draw_pass_1 = quad
	add_child(parts)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.2)
	l.light_energy = 1.6
	l.omni_range = 4.0
	l.position = Vector3(0, 0.5, 0)
	add_child(l)
	# горит 12 секунд, потом гаснет
	var tw := create_tween()
	tw.tween_interval(12.0)
	tw.tween_callback(func():
		spent = true
		_fizzle())

## «Чуйка» Санты: подсветить ловушку красным кольцом.
func reveal() -> void:
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.35
	tm.outer_radius = 0.48
	ring.mesh = tm
	ring.material_override = Defs.flat_mat(Color(1.0, 0.25, 0.2), 2.0)
	ring.position = Vector3(0, 0.15, 0)
	add_child(ring)
	var tw := ring.create_tween()
	tw.tween_property(ring, "position:y", 0.6, 1.8)
	tw.parallel().tween_property(ring, "transparency", 1.0, 1.8)
	tw.tween_callback(ring.queue_free)

func apply_to(santa: Node) -> void:
	var scale_q := lerpf(0.7, 1.0, clampf((quality - 0.6) / 0.4, 0.0, 1.0))
	var extra := {}
	if def.has("knock"):
		extra["knock"] = float(def["knock"])
	if def.has("dizzy"):
		extra["dizzy"] = float(def["dizzy"]) * scale_q
	if def.get("disorient", false):
		extra["disorient"] = true
	if def.get("wet", false):
		extra["wet"] = true
	santa.apply_trap_effect(
		float(def["stun"]) * scale_q,
		float(def["slow"]),
		float(def["slow_dur"]) * scale_q,
		bool(def.get("scare", false)),
		float(def["capture_mult"]),
		extra
	)

## Честный tell: провод от триггера к связанному объекту видно глазами.
func _draw_link_wire() -> void:
	var target := Defs.cell_to_world(link["cell"]) + Vector3(0, 2.3 if link["type"] == "chandelier" else 1.2, 0)
	var from := position + Vector3(0, 0.2, 0)
	var vec := target - from
	if vec.length() < 0.05:
		return
	var wm := CylinderMesh.new()
	wm.top_radius = 0.015
	wm.bottom_radius = 0.015
	wm.height = vec.length()
	var mi := MeshInstance3D.new()
	mi.name = "LinkWire"
	mi.mesh = wm
	mi.material_override = Defs.flat_mat(Color(0.75, 0.65, 0.45))
	mi.position = (from + target) * 0.5 - position
	# ось Y цилиндра — вдоль верёвки
	var y := vec.normalized()
	var x := y.cross(Vector3.UP)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	mi.basis = basis.inverse() * Basis(x, y, x.cross(y))
	add_child(mi)

func _fizzle() -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.4)
	tw.tween_callback(queue_free)

func _play_trigger_fx() -> void:
	if trap_id == "rope_chandelier" and chandelier != null:
		var tw := chandelier.create_tween()
		tw.tween_property(chandelier, "position:y", 0.3, 0.25).set_ease(Tween.EASE_IN)
	if def["oneshot"]:
		var tw2 := create_tween()
		tw2.tween_interval(1.2)
		tw2.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.5)
		tw2.tween_callback(queue_free)

# ---------------------------------------------------------------- ВИЗУАЛ

func _mesh(m: Mesh, pos: Vector3, color: Color, emission := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	mi.material_override = Defs.flat_mat(color, emission)
	add_child(mi)
	return mi

## Нить растяжки от конца a к концу b (мировые координаты) + узелки на концах.
func _build_wire_mesh() -> void:
	var a: Vector3 = wire["a"] - position
	var b: Vector3 = wire["b"] - position
	var v := b - a
	var l := v.length()
	if l < 0.05:
		return
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.02
	cyl.bottom_radius = 0.02
	cyl.height = 1.0
	mi.mesh = cyl
	mi.material_override = Defs.flat_mat(Color(0.82, 0.72, 0.5))
	var yd := v / l
	var xd := yd.cross(Vector3.UP)
	if xd.length() < 0.01:
		xd = Vector3.RIGHT
	xd = xd.normalized()
	mi.transform = Transform3D(Basis(xd, yd * l, zd_of(xd, yd)), (a + b) * 0.5)
	add_child(mi)
	for p in [a, b]:
		var knot := SphereMesh.new()
		knot.radius = 0.05
		knot.height = 0.1
		_mesh(knot, p, Color(0.7, 0.6, 0.42))

static func zd_of(xd: Vector3, yd: Vector3) -> Vector3:
	return xd.cross(yd)

# Ловушки с готовой custom-моделью (id ловушки → файл в assets/custom/).
const CUSTOM_MODELS := {
	"mousetrap": "c:mousetrap", "banana": "c:banana_peel", "marbles": "c:marbles",
	"firecracker": "c:firecracker", "firecracker_chimney": "c:firecracker",
	"perfume": "c:perfume", "plate": "c:pressure_plate", "plate_link": "c:pressure_plate",
}

func _build_visual() -> void:
	# сначала пробуем настоящую модель (нейронка, стиль Meccha); нет — процедура
	if CUSTOM_MODELS.has(trap_id):
		var m := ModelLib.place(self, CUSTOM_MODELS[trap_id], Vector3.ZERO, Vector3(0.6, 0.4, 0.6))
		if m != null:
			_apply_hidden_alpha()
			return
	match trap_id:
		"shards":
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(cell)
			var cols := [Color(0.9, 0.3, 0.3), Color(0.3, 0.6, 0.9), Color(0.9, 0.8, 0.3), Color(0.5, 0.9, 0.5)]
			for i in 9:
				var s := SphereMesh.new()
				s.radius = 0.05
				s.height = 0.07
				_mesh(s, Vector3(rng.randf_range(-0.4, 0.4), 0.03, rng.randf_range(-0.4, 0.4)), cols[i % 4], 0.8)
		"oil", "oil_tiles":
			var d := CylinderMesh.new()
			d.top_radius = 0.45
			d.bottom_radius = 0.45
			d.height = 0.03
			_mesh(d, Vector3(0, 0.03, 0), Color(0.15, 0.13, 0.1, 0.85))
		"glue", "glue_door":
			var d := CylinderMesh.new()
			d.top_radius = 0.4
			d.bottom_radius = 0.4
			d.height = 0.04
			_mesh(d, Vector3(0, 0.03, 0), Color(0.9, 0.85, 0.5))
		"tape":
			var b := BoxMesh.new()
			b.size = Vector3(0.9, 0.02, 0.35)
			_mesh(b, Vector3(0, 0.02, 0), Color(0.75, 0.72, 0.6))
			var b2 := BoxMesh.new()
			b2.size = Vector3(0.9, 0.02, 0.35)
			var mi := _mesh(b2, Vector3(0, 0.025, 0), Color(0.8, 0.77, 0.65))
			mi.rotation_degrees = Vector3(0, 40, 0)
		"garland_shock":
			var wire := BoxMesh.new()
			wire.size = Vector3(0.95, 0.03, 0.05)
			_mesh(wire, Vector3(0, 0.04, 0), Color(0.15, 0.3, 0.15))
			var cols := [Color(1, 0.3, 0.3), Color(0.3, 0.7, 1), Color(1, 0.8, 0.3), Color(0.4, 1, 0.5)]
			for i in 5:
				var s := SphereMesh.new()
				s.radius = 0.05
				s.height = 0.1
				_mesh(s, Vector3(-0.36 + i * 0.18, 0.08, 0.05 * (1 if i % 2 == 0 else -1)), cols[i % 4], 2.0)
		"mousetrap":
			var b := BoxMesh.new()
			b.size = Vector3(0.35, 0.05, 0.5)
			_mesh(b, Vector3(0, 0.04, 0), Color(0.6, 0.45, 0.3))
			var bar := BoxMesh.new()
			bar.size = Vector3(0.3, 0.03, 0.06)
			_mesh(bar, Vector3(0, 0.08, -0.15), Color(0.7, 0.7, 0.75))
		"rope_trip", "rope_link":
			if not wire.is_empty():
				_build_wire_mesh()
			else:
				var r := CylinderMesh.new()
				r.top_radius = 0.025
				r.bottom_radius = 0.025
				r.height = 0.95
				var mi := _mesh(r, Vector3(0, 0.18, 0), Color(0.8, 0.7, 0.5))
				mi.rotation_degrees = Vector3(0, 0, 90)
		"rope_chandelier":
			var r := CylinderMesh.new()
			r.top_radius = 0.02
			r.bottom_radius = 0.02
			r.height = 2.2
			_mesh(r, Vector3(0.3, 1.3, 0), Color(0.8, 0.7, 0.5))
		"bucket_door":
			var b := CylinderMesh.new()
			b.top_radius = 0.22
			b.bottom_radius = 0.16
			b.height = 0.3
			_mesh(b, Vector3(0, 2.35, 0), Color(0.55, 0.6, 0.65))
		"firecracker", "firecracker_chimney":
			var f := CylinderMesh.new()
			f.top_radius = 0.06
			f.bottom_radius = 0.06
			f.height = 0.25
			_mesh(f, Vector3(0, 0.13, 0), Color(0.85, 0.2, 0.2), 0.5)
		"net":
			var n := BoxMesh.new()
			n.size = Vector3(0.9, 0.04, 0.9)
			_mesh(n, Vector3(0, 0.03, 0), Color(0.25, 0.3, 0.35))
		"banana":
			# жёлтая кожура: три лепестка веером
			for i in 3:
				var p := CapsuleMesh.new()
				p.radius = 0.045
				p.height = 0.34
				var mi := _mesh(p, Vector3(0, 0.05, 0), Color(0.95, 0.85, 0.25))
				mi.rotation_degrees = Vector3(80, i * 120.0, 0)
		"marbles":
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(cell) + 7
			var cols := [Color(0.9, 0.4, 0.4), Color(0.4, 0.6, 0.95), Color(0.5, 0.9, 0.5), Color(0.95, 0.8, 0.4), Color(0.8, 0.5, 0.9)]
			for i in 10:
				var s := SphereMesh.new()
				s.radius = 0.045
				s.height = 0.09
				_mesh(s, Vector3(rng.randf_range(-0.38, 0.38), 0.045, rng.randf_range(-0.38, 0.38)), cols[i % 5], 0.5)
		"plate", "plate_link":
			var b := BoxMesh.new()
			b.size = Vector3(0.55, 0.05, 0.55)
			_mesh(b, Vector3(0, 0.03, 0), Color(0.45, 0.45, 0.5))
			var top := BoxMesh.new()
			top.size = Vector3(0.42, 0.03, 0.42)
			_mesh(top, Vector3(0, 0.065, 0), Color(0.75, 0.3, 0.25), 0.3)
		"perfume":
			var bottle := CylinderMesh.new()
			bottle.top_radius = 0.06
			bottle.bottom_radius = 0.09
			bottle.height = 0.22
			_mesh(bottle, Vector3(0, 0.11, 0), Color(0.85, 0.55, 0.8, 0.9))
			var cap := SphereMesh.new()
			cap.radius = 0.05
			cap.height = 0.1
			_mesh(cap, Vector3(0, 0.26, 0), Color(0.9, 0.8, 0.4), 0.5)
		"rope_link":
			var r := CylinderMesh.new()
			r.top_radius = 0.025
			r.bottom_radius = 0.025
			r.height = 0.95
			var mi := _mesh(r, Vector3(0, 0.18, 0), Color(0.8, 0.7, 0.5))
			mi.rotation_degrees = Vector3(0, 0, 90)
	# верёвка от триггера к связанному объекту — видно, что заряжено
	if not link.is_empty():
		_draw_link_wire()
	_apply_hidden_alpha()

## Под ковром ловушку видно полупрозрачно (и своим, и грабителю — слегка).
func _apply_hidden_alpha() -> void:
	if not hidden:
		return
	var stack: Array = [self]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi: MeshInstance3D = n
			if mi.material_override is StandardMaterial3D:
				var mat: StandardMaterial3D = mi.material_override
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.albedo_color.a = 0.45
			else:
				mi.transparency = 0.55
		for c in n.get_children():
			stack.push_back(c)
