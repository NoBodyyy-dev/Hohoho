class_name Minifig
## Округлые «блобные» фигурки в духе RV There Yet?: сферы и капсулы, никаких кубов.
## В root.meta("parts") — пивоты конечностей для процедурной ходьбы.

static func _sphere(parent: Node3D, r: float, squash: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0 * squash
	m.radial_segments = 24
	m.rings = 12
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

static func _capsule(parent: Node3D, r: float, h: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 16
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

static func _torus(parent: Node3D, inner: float, outer: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

## Конечность: пивот в суставе, капсула свисает вниз.
static func _limb(parent: Node3D, pivot_pos: Vector3, r: float, len: float, mat: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pivot_pos
	parent.add_child(pivot)
	_capsule(pivot, r, len, Vector3(0, -len * 0.5, 0), mat)
	return pivot

static func _face(parent: Node3D, y: float, z: float, scale: float, skin: Color) -> void:
	var dark := Defs.flat_mat(Color(0.12, 0.1, 0.12))
	dark.roughness = 0.3
	for side in [-1, 1]:
		var eye := _sphere(parent, 0.032 * scale, 1.0, Vector3(side * 0.075 * scale, y + 0.02 * scale, z), dark)
		# блик в глазу
		_sphere(eye, 0.011 * scale, 1.0, Vector3(0.008, 0.012, 0.022 * scale), Defs.flat_mat(Color(1, 1, 1), 0.6))
	# щёчки
	var cheek := Defs.flat_mat(skin.lerp(Color(0.95, 0.45, 0.4), 0.45))
	for side in [-1, 1]:
		_sphere(parent, 0.035 * scale, 0.7, Vector3(side * 0.11 * scale, y - 0.045 * scale, z - 0.01), cheek)

# ================================================================ ПАЦАН (~1.15 м)

static func build_kid(colors: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Model"
	var skin := Color(0.99, 0.84, 0.7)
	var skin_m := Defs.flat_mat(skin)
	skin_m.roughness = 0.7
	var shirt_m := Defs.fabric_mat(colors["shirt"])
	var pants_m := Defs.fabric_mat(colors["pants"])
	var hat_m := Defs.fabric_mat(colors["hat"])
	var scarf_m := Defs.fabric_mat(Color(colors["hat"]).lightened(0.25))
	var boot_m := Defs.flat_mat(Color(0.3, 0.24, 0.24))
	boot_m.roughness = 0.5

	var leg_l := _limb(root, Vector3(-0.09, 0.34, 0), 0.065, 0.26, pants_m)
	var leg_r := _limb(root, Vector3(0.09, 0.34, 0), 0.065, 0.26, pants_m)
	_sphere(leg_l, 0.085, 0.7, Vector3(0, -0.28, 0.03), boot_m)
	_sphere(leg_r, 0.085, 0.7, Vector3(0, -0.28, 0.03), boot_m)

	# туловище: пузико + курточка
	_sphere(root, 0.21, 0.9, Vector3(0, 0.44, 0), pants_m)
	_sphere(root, 0.23, 0.95, Vector3(0, 0.58, 0), shirt_m)
	# пуговицы
	for i in 2:
		_sphere(root, 0.02, 1.0, Vector3(0, 0.52 + i * 0.11, 0.215), Defs.flat_mat(Color(0.95, 0.9, 0.75)))

	var arm_l := _limb(root, Vector3(-0.23, 0.68, 0), 0.055, 0.24, shirt_m)
	var arm_r := _limb(root, Vector3(0.23, 0.68, 0), 0.055, 0.24, shirt_m)
	var mitten := Defs.fabric_mat(Color(0.85, 0.3, 0.3))
	_sphere(arm_l, 0.07, 0.9, Vector3(0, -0.27, 0), mitten)
	_sphere(arm_r, 0.07, 0.9, Vector3(0, -0.27, 0), mitten)

	# шарф
	var scarf := _torus(root, 0.13, 0.21, Vector3(0, 0.76, 0), scarf_m)
	scarf.scale.y = 0.7
	_capsule(root, 0.05, 0.16, Vector3(0.1, 0.66, 0.17), scarf_m)

	# голова — большая, чуть приплюснутая
	_sphere(root, 0.24, 0.92, Vector3(0, 0.98, 0), skin_m)
	_face(root, 0.98, 0.215, 1.0, skin)
	# нос-кнопка
	_sphere(root, 0.028, 1.0, Vector3(0, 0.955, 0.235), Defs.flat_mat(skin.darkened(0.06)))
	# шапка-бини с отворотом и помпоном
	var beanie := _sphere(root, 0.235, 0.75, Vector3(0, 1.12, 0), hat_m)
	beanie.rotation_degrees = Vector3(4, 0, 0)
	var brim := _torus(root, 0.19, 0.26, Vector3(0, 1.06, 0), hat_m)
	brim.scale.y = 0.55
	_sphere(root, 0.06, 1.0, Vector3(0, 1.26, 0), Defs.fabric_mat(Color(0.97, 0.96, 0.94)))

	root.set_meta("parts", {"leg_l": leg_l, "leg_r": leg_r, "arm_l": arm_l, "arm_r": arm_r})
	return root

# ================================================================ САНТА (~1.95 м)

static func build_santa() -> Node3D:
	var root := Node3D.new()
	root.name = "Model"
	var red_m := Defs.fabric_mat(Color(0.8, 0.18, 0.18))
	var white_m := Defs.fabric_mat(Color(0.97, 0.96, 0.94))
	var skin := Color(0.99, 0.82, 0.7)
	var skin_m := Defs.flat_mat(skin)
	skin_m.roughness = 0.7
	var boot_m := Defs.flat_mat(Color(0.16, 0.13, 0.14))
	boot_m.roughness = 0.4

	var leg_l := _limb(root, Vector3(-0.16, 0.6, 0), 0.1, 0.42, red_m)
	var leg_r := _limb(root, Vector3(0.16, 0.6, 0), 0.1, 0.42, red_m)
	_sphere(leg_l, 0.13, 0.65, Vector3(0, -0.5, 0.05), boot_m)
	_sphere(leg_r, 0.13, 0.65, Vector3(0, -0.5, 0.05), boot_m)

	# пузо — главная форма
	_sphere(root, 0.42, 1.0, Vector3(0, 0.95, 0.02), red_m)
	# меховая планка спереди
	_capsule(root, 0.05, 0.62, Vector3(0, 0.95, 0.4), white_m)
	# ремень
	var belt := _torus(root, 0.36, 0.44, Vector3(0, 0.82, 0.01), Defs.flat_mat(Color(0.2, 0.15, 0.13)))
	belt.scale.y = 0.5
	_sphere(root, 0.06, 0.8, Vector3(0, 0.82, 0.42), Defs.flat_mat(Color(0.95, 0.8, 0.25), 0.5))
	# меховой ворот
	var collar := _torus(root, 0.16, 0.3, Vector3(0, 1.32, 0), white_m)
	collar.scale.y = 0.7

	var arm_l := _limb(root, Vector3(-0.4, 1.22, 0), 0.085, 0.4, red_m)
	var arm_r := _limb(root, Vector3(0.4, 1.22, 0), 0.085, 0.4, red_m)
	_torus(arm_l, 0.06, 0.11, Vector3(0, -0.36, 0), white_m)
	_torus(arm_r, 0.06, 0.11, Vector3(0, -0.36, 0), white_m)
	_sphere(arm_l, 0.1, 0.9, Vector3(0, -0.45, 0), white_m)
	_sphere(arm_r, 0.1, 0.9, Vector3(0, -0.45, 0), white_m)

	# голова
	_sphere(root, 0.28, 0.95, Vector3(0, 1.62, 0), skin_m)
	_face(root, 1.66, 0.25, 1.25, skin)
	# нос-картошка
	_sphere(root, 0.05, 1.0, Vector3(0, 1.6, 0.28), Defs.flat_mat(Color(0.93, 0.55, 0.45)))
	# борода — пышная, из трёх сфер
	_sphere(root, 0.2, 0.8, Vector3(0, 1.46, 0.14), white_m)
	_sphere(root, 0.13, 0.8, Vector3(-0.11, 1.5, 0.19), white_m)
	_sphere(root, 0.13, 0.8, Vector3(0.11, 1.5, 0.19), white_m)
	# усы
	_capsule(root, 0.035, 0.1, Vector3(-0.06, 1.57, 0.26), white_m).rotation_degrees = Vector3(0, 0, 70)
	_capsule(root, 0.035, 0.1, Vector3(0.06, 1.57, 0.26), white_m).rotation_degrees = Vector3(0, 0, -70)
	# брови
	_capsule(root, 0.02, 0.07, Vector3(-0.09, 1.74, 0.24), white_m).rotation_degrees = Vector3(0, 0, 80)
	_capsule(root, 0.02, 0.07, Vector3(0.09, 1.74, 0.24), white_m).rotation_degrees = Vector3(0, 0, -80)
	# колпак: конус + отворот + помпон, чуть набекрень
	var hat := Node3D.new()
	hat.position = Vector3(0, 1.82, 0)
	hat.rotation_degrees = Vector3(0, 0, -10)
	root.add_child(hat)
	var cone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.03
	cm.bottom_radius = 0.24
	cm.height = 0.34
	cone.mesh = cm
	cone.material_override = red_m
	cone.position = Vector3(0, 0.14, 0)
	hat.add_child(cone)
	var hbrim := _torus(hat, 0.2, 0.29, Vector3(0, 0.0, 0), white_m)
	hbrim.scale.y = 0.6
	_sphere(hat, 0.07, 1.0, Vector3(0.1, 0.33, 0), white_m)
	# мешок
	var sack := _sphere(root, 0.42, 1.0, Vector3(0, 1.15, -0.5), Defs.fabric_mat(Color(0.52, 0.38, 0.24)))
	sack.scale = Vector3(1.0, 1.15, 0.85)
	sack.name = "Sack"
	_torus(root, 0.05, 0.1, Vector3(0, 1.62, -0.42), Defs.flat_mat(Color(0.4, 0.3, 0.2)))

	root.set_meta("parts", {"leg_l": leg_l, "leg_r": leg_r, "arm_l": arm_l, "arm_r": arm_r})
	return root

# ================================================================ АНИМАЦИЯ

static func animate_walk(model: Node3D, t: float, move: float) -> void:
	if not model.has_meta("parts"):
		return
	var p: Dictionary = model.get_meta("parts")
	var swing := sin(t) * 0.7 * move
	p["leg_l"].rotation.x = swing
	p["leg_r"].rotation.x = -swing
	p["arm_l"].rotation.x = -swing * 0.8
	p["arm_r"].rotation.x = swing * 0.8
	p["arm_l"].rotation.z = 0.12 * move
	p["arm_r"].rotation.z = -0.12 * move
	model.position.y = absf(sin(t)) * 0.05 * move
	model.rotation.z = sin(t) * 0.04 * move

# ================================================================ FP-РУКА (пухлая, с пальцами)

## side: -1 левая, 1 правая. Как на референсе — ладошка и четыре пальца.
static func build_fp_hand(side: int, skin: Color, sleeve: Color) -> Node3D:
	var root := Node3D.new()
	var skin_m := Defs.flat_mat(skin)
	skin_m.roughness = 0.65
	var sleeve_m := Defs.fabric_mat(sleeve)
	# рукав
	var cuff := _capsule(root, 0.075, 0.16, Vector3(0, -0.02, 0.14), sleeve_m)
	cuff.rotation_degrees = Vector3(75, 0, 0)
	# ладонь — приплюснутая сфера
	var palm := _sphere(root, 0.085, 0.55, Vector3(0, 0, 0), skin_m)
	palm.scale = Vector3(1.0, 1.0, 1.25)
	# четыре пухлых пальца веером вперёд
	for i in 4:
		var f := _capsule(root, 0.024, 0.075, Vector3((i - 1.5) * 0.038, 0.012, -0.1), skin_m)
		f.rotation_degrees = Vector3(85, 0, (i - 1.5) * -5.0)
	# большой палец сбоку
	var thumb := _capsule(root, 0.026, 0.06, Vector3(side * 0.085, 0.005, -0.02), skin_m)
	thumb.rotation_degrees = Vector3(60, side * -35.0, 0)
	return root

# ================================================================ ПРОЧЕЕ

static func build_present() -> Node3D:
	var root := Node3D.new()
	var ids := ["h:present-a-cube", "h:present-b-cube", "h:present-a-round",
		"h:present-b-round", "h:present-a-rectangle", "h:present-b-rectangle"]
	if ModelLib.place(root, ids[randi() % ids.size()], Vector3.ZERO, Vector3(0.5, 0.45, 0.5), randf() * TAU) != null:
		return root
	var palettes := [Color(0.85, 0.25, 0.3), Color(0.25, 0.55, 0.85), Color(0.3, 0.7, 0.4), Color(0.9, 0.7, 0.2)]
	var c: Color = palettes[randi() % palettes.size()]
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.4, 0.32, 0.4)
	box.mesh = bm
	box.material_override = Defs.fabric_mat(c)
	box.position = Vector3(0, 0.16, 0)
	root.add_child(box)
	var ribbon_m := Defs.flat_mat(Color(0.97, 0.92, 0.8))
	for s in [Vector3(0.44, 0.08, 0.1), Vector3(0.1, 0.08, 0.44)]:
		var r := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = s
		r.mesh = rm
		r.material_override = ribbon_m
		r.position = Vector3(0, 0.16, 0)
		root.add_child(r)
	_torus(root, 0.03, 0.07, Vector3(-0.05, 0.36, 0), ribbon_m).rotation_degrees = Vector3(0, 0, 30)
	_torus(root, 0.03, 0.07, Vector3(0.05, 0.36, 0), ribbon_m).rotation_degrees = Vector3(0, 0, -30)
	return root

static func build_held_item(item_id: String) -> Node3D:
	var root := Node3D.new()
	match item_id:
		"rope":
			var t := TorusMesh.new()
			t.inner_radius = 0.05
			t.outer_radius = 0.11
			var mi := MeshInstance3D.new()
			mi.mesh = t
			mi.material_override = Defs.fabric_mat(Color(0.8, 0.7, 0.5))
			mi.rotation_degrees = Vector3(70, 0, 0)
			root.add_child(mi)
		"shards":
			for i in 3:
				_sphere(root, 0.035, 1.0, Vector3(0.04 * (i - 1), 0.02 * (i % 2), 0),
					Defs.flat_mat([Color(0.9, 0.3, 0.3), Color(0.3, 0.6, 0.9), Color(0.9, 0.8, 0.3)][i], 0.6))
		"tape":
			_torus(root, 0.03, 0.07, Vector3.ZERO, Defs.flat_mat(Color(0.75, 0.72, 0.6)))
		"oil":
			_capsule(root, 0.045, 0.12, Vector3.ZERO, Defs.flat_mat(Color(0.85, 0.75, 0.2)))
		"glue":
			_capsule(root, 0.035, 0.12, Vector3.ZERO, Defs.flat_mat(Color(0.9, 0.85, 0.5)))
		"mousetrap":
			var b := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.1, 0.03, 0.14)
			b.mesh = bm
			b.material_override = Defs.wood_mat(Color(0.6, 0.45, 0.3))
			root.add_child(b)
		"firecracker":
			_capsule(root, 0.03, 0.12, Vector3.ZERO, Defs.flat_mat(Color(0.85, 0.2, 0.2), 0.4))
		"bucket":
			var c := CylinderMesh.new()
			c.top_radius = 0.09
			c.bottom_radius = 0.065
			c.height = 0.12
			var mi := MeshInstance3D.new()
			mi.mesh = c
			mi.material_override = Defs.flat_mat(Color(0.55, 0.6, 0.65))
			mi.material_override.roughness = 0.35
			root.add_child(mi)
		"garland_shock":
			for i in 3:
				_sphere(root, 0.03, 1.0, Vector3(0.035 * (i - 1), 0, 0),
					Defs.flat_mat([Color(1, 0.3, 0.3), Color(0.3, 0.7, 1), Color(1, 0.8, 0.3)][i], 2.0))
		"net":
			var b := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.14, 0.03, 0.14)
			b.mesh = bm
			b.material_override = Defs.fabric_mat(Color(0.25, 0.3, 0.35))
			root.add_child(b)
		"cookie":
			var c := CylinderMesh.new()
			c.top_radius = 0.06
			c.bottom_radius = 0.06
			c.height = 0.025
			var mi := MeshInstance3D.new()
			mi.mesh = c
			mi.material_override = Defs.flat_mat(Color(0.75, 0.5, 0.25))
			root.add_child(mi)
		"banana":
			var b := _capsule(root, 0.035, 0.15, Vector3.ZERO, Defs.flat_mat(Color(0.95, 0.85, 0.25)))
			b.rotation_degrees = Vector3(0, 0, 55)
		"marbles":
			for i in 3:
				_sphere(root, 0.03, 1.0, Vector3(0.04 * (i - 1), 0.015 * (i % 2), 0),
					Defs.flat_mat([Color(0.9, 0.4, 0.4), Color(0.4, 0.6, 0.95), Color(0.5, 0.9, 0.5)][i], 0.4))
		"plate":
			var p := MeshInstance3D.new()
			var pm := BoxMesh.new()
			pm.size = Vector3(0.14, 0.02, 0.14)
			p.mesh = pm
			p.material_override = Defs.flat_mat(Color(0.5, 0.5, 0.55))
			root.add_child(p)
		"perfume":
			var f := MeshInstance3D.new()
			var fm := CylinderMesh.new()
			fm.top_radius = 0.03
			fm.bottom_radius = 0.045
			fm.height = 0.11
			f.mesh = fm
			f.material_override = Defs.flat_mat(Color(0.85, 0.55, 0.8))
			root.add_child(f)
			for i in 3:
				_sphere(root, 0.008, 1.0, Vector3(0.02 * (i - 1), 0.015, 0.01 * (i % 2)), Defs.flat_mat(Color(0.3, 0.2, 0.12)))
	return root
