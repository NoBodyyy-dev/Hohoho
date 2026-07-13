class_name PropFX
extends RefCounted
## «Сочность» ловушек без новых моделей: пыль и обломки при ударе, настоящие
## катящиеся шарики (RigidBody), электродуга. Всё на примитивах + физике Godot.

## Удар тяжёлого объекта об пол: кольцо пыли + разлетающиеся обломки.
static func impact(parent: Node3D, pos: Vector3, color := Color(0.7, 0.65, 0.55), chunks := 8) -> void:
	# пыльное кольцо
	var dust := GPUParticles3D.new()
	dust.amount = 26
	dust.lifetime = 0.9
	dust.one_shot = true
	dust.explosiveness = 0.95
	dust.position = pos
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_radius = 0.3
	pm.emission_ring_inner_radius = 0.0
	pm.emission_ring_height = 0.05
	pm.emission_ring_axis = Vector3.UP
	pm.direction = Vector3(1, 0.3, 0)
	pm.spread = 55.0
	pm.initial_velocity_min = 1.2
	pm.initial_velocity_max = 3.0
	pm.gravity = Vector3(0, -2.5, 0)
	pm.damping_min = 2.0
	pm.damping_max = 4.0
	pm.scale_min = 1.5
	pm.scale_max = 3.5
	pm.color = Color(color.r, color.g, color.b, 0.6)
	dust.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	var qm := StandardMaterial3D.new()
	qm.albedo_color = Color(color.r, color.g, color.b, 0.6)
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = qm
	dust.draw_pass_1 = quad
	parent.add_child(dust)
	dust.emitting = true
	_autofree(dust, 2.0)
	# физические обломки — маленькие кубики разлетаются и оседают
	for i in chunks:
		var chunk := RigidBody3D.new()
		chunk.collision_layer = 0
		chunk.collision_mask = 1
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var sz := randf_range(0.05, 0.12)
		bm.size = Vector3(sz, sz, sz)
		mi.mesh = bm
		mi.material_override = Defs.flat_mat(color.darkened(randf() * 0.3))
		chunk.add_child(mi)
		var col := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = bm.size
		col.shape = bs
		chunk.add_child(col)
		chunk.position = pos + Vector3(randf_range(-0.2, 0.2), 0.1, randf_range(-0.2, 0.2))
		parent.add_child(chunk)
		var dir := Vector3(randf_range(-1, 1), randf_range(0.5, 1.5), randf_range(-1, 1)).normalized()
		chunk.apply_impulse(dir * randf_range(1.5, 3.5))
		chunk.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
		_fade_free(chunk, mi, 2.5)

## Рассыпать настоящие катящиеся шарики (RigidBody) — юркие, физичные.
static func scatter_marbles(parent: Node3D, pos: Vector3, count := 12) -> void:
	var cols := [Color(0.9, 0.4, 0.4), Color(0.4, 0.6, 0.95), Color(0.5, 0.9, 0.5),
		Color(0.95, 0.8, 0.4), Color(0.8, 0.5, 0.9)]
	for i in count:
		var b := RigidBody3D.new()
		b.collision_layer = 0
		b.collision_mask = 1
		b.physics_material_override = PhysicsMaterial.new()
		b.physics_material_override.bounce = 0.4
		b.physics_material_override.friction = 0.1
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.05
		sm.height = 0.1
		mi.mesh = sm
		mi.material_override = Defs.flat_mat(cols[i % cols.size()], 0.3)
		b.add_child(mi)
		var col := CollisionShape3D.new()
		var cs := SphereShape3D.new()
		cs.radius = 0.05
		col.shape = cs
		b.add_child(col)
		b.position = pos + Vector3(randf_range(-0.2, 0.2), 0.15, randf_range(-0.2, 0.2))
		parent.add_child(b)
		var dir := Vector3(randf_range(-1, 1), 0.2, randf_range(-1, 1)).normalized()
		b.apply_impulse(dir * randf_range(1.5, 3.0))
		_fade_free(b, mi, 8.0)

## Электродуга: рваная светящаяся линия между двумя точками + треск-искры.
static func electric_arc(parent: Node3D, a: Vector3, b: Vector3, color := Color(0.5, 0.9, 1.0)) -> void:
	var arc := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	arc.mesh = im
	var mat := Defs.flat_mat(color, 4.0)
	arc.material_override = mat
	parent.add_child(arc)
	var redraw := func():
		im.clear_surfaces()
		im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		var segs := 10
		for i in segs + 1:
			var t := float(i) / segs
			var p := a.lerp(b, t)
			if i != 0 and i != segs:
				p += Vector3(randf_range(-0.15, 0.15), randf_range(-0.15, 0.15), randf_range(-0.15, 0.15))
			im.surface_add_vertex(p)
		im.surface_end()
	redraw.call()
	# треск — перерисовываем несколько раз
	var flick := parent.get_tree().create_tween()
	flick.set_loops(6)
	flick.tween_callback(redraw).set_delay(0.05)
	flick.chain().tween_callback(arc.queue_free)
	# искры в точке удара
	var spark := GPUParticles3D.new()
	spark.amount = 20
	spark.lifetime = 0.4
	spark.one_shot = true
	spark.explosiveness = 1.0
	spark.position = b
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 90.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 5.0
	pm.gravity = Vector3(0, -8, 0)
	pm.color = color
	spark.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.04, 0.04)
	var qm := Defs.flat_mat(color, 3.0)
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = qm
	spark.draw_pass_1 = q
	parent.add_child(spark)
	spark.emitting = true
	_autofree(spark, 1.0)

## Настоящая верёвка между двумя точками: провисает дугой (катенария) + узлы
## на концах. Именно она делает связку «два предмета соединены» читаемой.
## Возвращает узел-контейнер (можно queue_free при снятии).
static func build_rope(parent: Node3D, a: Vector3, b: Vector3, sag := 0.35,
		color := Color(0.82, 0.72, 0.5), thickness := 0.02) -> Node3D:
	var holder := Node3D.new()
	holder.top_level = true
	parent.add_child(holder)
	var segs := 12
	var prev := a
	var mat := Defs.fabric_mat(color)
	for i in range(1, segs + 1):
		var t := float(i) / segs
		# провис по параболе (0 на концах, максимум в середине)
		var droop := sag * 4.0 * t * (1.0 - t)
		var p := a.lerp(b, t) - Vector3(0, droop, 0)
		_rope_segment(holder, prev, p, thickness, mat)
		prev = p
	# узлы-утолщения на концах
	for e in [a, b]:
		var knot := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = thickness * 2.2
		sm.height = thickness * 4.4
		knot.mesh = sm
		knot.material_override = Defs.fabric_mat(color.darkened(0.15))
		knot.position = e
		holder.add_child(knot)
	return holder

static func _rope_segment(holder: Node3D, a: Vector3, b: Vector3, r: float, mat: Material) -> void:
	var v := b - a
	var l := v.length()
	if l < 0.001:
		return
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r
	cyl.height = l
	mi.mesh = cyl
	mi.material_override = mat
	var y := v / l
	var x := y.cross(Vector3.UP)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	mi.transform = Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5)
	holder.add_child(mi)

# ---------------------------------------------------------------- helpers

static func _autofree(node: Node, delay: float) -> void:
	var tw := node.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(node.queue_free)

static func _fade_free(body: Node3D, mi: MeshInstance3D, delay: float) -> void:
	var tw := body.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func():
		if is_instance_valid(mi) and mi.material_override is StandardMaterial3D:
			var m: StandardMaterial3D = mi.material_override
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		)
	tw.tween_interval(0.5)
	tw.tween_callback(body.queue_free)
