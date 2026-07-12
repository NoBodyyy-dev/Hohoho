class_name HouseBuilder
extends RefCounted
## Строит локацию из данных Defs.LOCATIONS: пол, стены, потолки, мебель, окна,
## гирлянды, снег — и навигационный граф (AStar3D по клеткам) для Санты.

var loc: Dictionary
var loc_id: String
var root: Node3D

var cell_room: Dictionary = {}      # Vector2i -> room_idx
var doorway_set: Dictionary = {}    # каноничный ключ ребра -> true
var carpet_cells: Dictionary = {}   # Vector2i -> true
var furniture_cells: Dictionary = {}# Vector2i -> true (нельзя ходить/ставить)
var prop_at: Dictionary = {}        # Vector2i -> prop dict
var chandeliers: Dictionary = {}    # Vector2i -> Node3D
var shelves: Array = []             # роняемая мебель: {cells, cell, node, type}
var tvs: Array = []                 # телевизоры-электрошок: {cell, node}
var carpet_nodes: Array = []        # ковры-выдергушки: {rect, node}
var astar := AStar3D.new()
var entries: Array = []
var present_spots: Array = []
var room_tags: Array = []
var _garland_points: Array = []     # [pos, вдоль_x: bool]

const WALL_H := 3.0
const WALL_T := 0.16
const WALL_COLOR := Color(0.95, 0.89, 0.79)
const TRIM_COLOR := Color(0.55, 0.38, 0.24)

func build(parent: Node3D, id: String, loc_data: Dictionary = {}) -> void:
	loc_id = id
	loc = loc_data if not loc_data.is_empty() else Defs.LOCATIONS[id]
	root = Node3D.new()
	root.name = "House"
	parent.add_child(root)

	_fill_cell_map()
	_build_floors()
	_build_walls()
	_build_ceilings()
	_build_props()
	_build_furniture()
	_build_clutter()
	_build_garlands()
	_build_outside()
	_build_astar()
	entries = loc["entries"].duplicate(true)
	present_spots = loc["present_spots"].duplicate()

# ---------------------------------------------------------------- КАРТА КЛЕТОК

func _fill_cell_map() -> void:
	room_tags = []
	for i in loc["rooms"].size():
		var r: Dictionary = loc["rooms"][i]
		room_tags.append(r["tag"])
		var rect: Rect2i = r["rect"]
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			for z in range(rect.position.y, rect.position.y + rect.size.y):
				cell_room[Vector2i(x, z)] = i
	for pair in loc["doorways"]:
		doorway_set[_edge_key(pair[0], pair[1])] = true
	for rect in loc["carpets"]:
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			for z in range(rect.position.y, rect.position.y + rect.size.y):
				carpet_cells[Vector2i(x, z)] = true
	for p in loc["props"]:
		prop_at[p["cell"]] = p
	for f in loc.get("furniture", []):
		for c in f["cells"]:
			furniture_cells[c] = true

static func _edge_key(a: Vector2i, b: Vector2i) -> String:
	if a.x > b.x or (a.x == b.x and a.y > b.y):
		var t := a
		a = b
		b = t
	return "%d,%d|%d,%d" % [a.x, a.y, b.x, b.y]

func is_inside(cell: Vector2i) -> bool:
	return cell_room.has(cell)

func room_of(cell: Vector2i) -> int:
	return cell_room.get(cell, -1)

func room_tag(cell: Vector2i) -> String:
	var r := room_of(cell)
	return "" if r < 0 else room_tags[r]

## Свободна ли клетка для ловушки/прохода. Люстра и камин НЕ блокируют —
## наоборот, на этих клетках живут комбо.
func is_free_cell(cell: Vector2i) -> bool:
	if not is_inside(cell) or furniture_cells.has(cell):
		return false
	var p: Dictionary = prop_at.get(cell, {})
	return p.get("type", "") != "tree"

func passable(a: Vector2i, b: Vector2i) -> bool:
	if not is_inside(a) or not is_inside(b):
		return false
	if cell_room[a] == cell_room[b]:
		return true
	return doorway_set.has(_edge_key(a, b))

func is_doorway_cell(cell: Vector2i) -> bool:
	for pair in loc["doorways"]:
		if pair[0] == cell or pair[1] == cell:
			return true
	for e in loc["entries"]:
		if e["type"] == "door" and e["cell"] == cell:
			return true
	return false

# ---------------------------------------------------------------- БАЗОВЫЕ БЛОКИ

func _add_static_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, emission := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = Defs.flat_mat(color, emission)
	body.add_child(mi)
	body.position = pos
	parent.add_child(body)
	return body

func _add_mesh_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, emission := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = Defs.flat_mat(color, emission)
	mi.position = pos
	parent.add_child(mi)
	return mi

func _add_static_mat(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> StaticBody3D:
	var body := _add_static_box(parent, size, pos, Color.WHITE)
	for c in body.get_children():
		if c is MeshInstance3D:
			c.material_override = mat
	return body

func _add_mesh_mat(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := _add_mesh_box(parent, size, pos, Color.WHITE)
	mi.material_override = mat
	return mi

# ---------------------------------------------------------------- ПОЛ / ПОТОЛОК

func _build_floors() -> void:
	for i in loc["rooms"].size():
		var r: Dictionary = loc["rooms"][i]
		var rect: Rect2i = r["rect"]
		var size := Vector3(rect.size.x, 0.2, rect.size.y)
		var pos := Vector3(rect.position.x + rect.size.x * 0.5, -0.1, rect.position.y + rect.size.y * 0.5)
		var fmat: Material = Defs.plaster_mat(r["floor"]) if r["tag"] == "плитка" else Defs.wood_mat(r["floor"])
		_add_static_mat(root, size, pos, fmat)
		# тёплый свет в каждой комнате
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.93, 0.82)
		l.light_energy = 0.95
		l.omni_range = maxf(rect.size.x, rect.size.y) * 1.1
		l.position = Vector3(pos.x, 2.5, pos.z)
		root.add_child(l)
	for rect in loc["carpets"]:
		var cnode := Node3D.new()
		cnode.position = Vector3(rect.position.x + rect.size.x * 0.5, 0, rect.position.y + rect.size.y * 0.5)
		root.add_child(cnode)
		_add_mesh_mat(cnode, Vector3(rect.size.x - 0.2, 0.04, rect.size.y - 0.2), Vector3(0, 0.02, 0), Defs.fabric_mat(Color(0.72, 0.26, 0.28)))
		_add_mesh_mat(cnode, Vector3(rect.size.x - 0.5, 0.045, rect.size.y - 0.5), Vector3(0, 0.02, 0), Defs.fabric_mat(Color(0.92, 0.82, 0.62)))
		carpet_nodes.append({"rect": rect, "node": cnode})

func _build_ceilings() -> void:
	var beam_mat := Defs.wood_mat(Color(0.42, 0.3, 0.2))
	for i in loc["rooms"].size():
		var rect: Rect2i = loc["rooms"][i]["rect"]
		var size := Vector3(rect.size.x + 0.3, 0.15, rect.size.y + 0.3)
		var pos := Vector3(rect.position.x + rect.size.x * 0.5, WALL_H + 0.07, rect.position.y + rect.size.y * 0.5)
		_add_static_mat(root, size, pos, Defs.plaster_mat(Color(0.93, 0.89, 0.83)))
		# деревянные балки под потолком — уют
		if rect.size.x >= rect.size.y:
			var x := rect.position.x + 2
			while x < rect.position.x + rect.size.x - 1:
				_add_mesh_mat(root, Vector3(0.18, 0.16, rect.size.y - 0.1), Vector3(x, WALL_H - 0.08, pos.z), beam_mat)
				x += 3
		else:
			var z := rect.position.y + 2
			while z < rect.position.y + rect.size.y - 1:
				_add_mesh_mat(root, Vector3(rect.size.x - 0.1, 0.16, 0.18), Vector3(pos.x, WALL_H - 0.08, z), beam_mat)
				z += 3

# ---------------------------------------------------------------- СТЕНЫ

func _entry_edge_keys() -> Dictionary:
	var keys := {}
	for e in loc["entries"]:
		keys[_edge_key(e["cell"], e["cell"] + e["out_dir"])] = e["type"]
	return keys

func _build_walls() -> void:
	var done := {}
	var entry_keys := _entry_edge_keys()
	var size: Vector2i = loc["size"]
	for x in range(-1, size.x + 1):
		for z in range(-1, size.y + 1):
			var a := Vector2i(x, z)
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var b: Vector2i = a + d
				var key := _edge_key(a, b)
				if done.has(key):
					continue
				done[key] = true
				var a_in := is_inside(a)
				var b_in := is_inside(b)
				if not a_in and not b_in:
					continue
				var outer := a_in != b_in
				var opening := false
				var lintel := false
				if a_in and b_in:
					if cell_room[a] == cell_room[b]:
						continue
					if doorway_set.has(key):
						opening = true
						lintel = true
				elif entry_keys.has(key):
					opening = true
					lintel = entry_keys[key] != "chimney"
				var mid := Vector3((a.x + b.x + 1) * 0.5, 0, (a.y + b.y + 1) * 0.5)
				var horizontal: bool = d == Vector2i(0, 1)
				var wsize := Vector3(1.0 + WALL_T, WALL_H, WALL_T) if horizontal else Vector3(WALL_T, WALL_H, 1.0 + WALL_T)
				var wall_mat := Defs.plaster_mat(WALL_COLOR)
				var trim_mat := Defs.wood_mat(TRIM_COLOR)
				# нормаль внутрь (к клетке a, если она внутри)
				var inside_cell := a if a_in else b
				var n := Vector3(0, 0, -1) if horizontal else Vector3(-1, 0, 0)
				if n.dot(Defs.cell_to_world(inside_cell) - Vector3(mid.x, 0, mid.z)) < 0:
					n = -n
				if opening:
					if lintel:
						_add_static_mat(root, Vector3(wsize.x, 0.8, wsize.z), Vector3(mid.x, WALL_H - 0.4, mid.z), wall_mat)
						var jsize := Vector3(0.12, 2.2, WALL_T + 0.06) if horizontal else Vector3(WALL_T + 0.06, 2.2, 0.12)
						var off := Vector3(0.5, 0, 0) if horizontal else Vector3(0, 0, 0.5)
						_add_static_mat(root, jsize, Vector3(mid.x, 1.1, mid.z) - off, trim_mat)
						_add_static_mat(root, jsize, Vector3(mid.x, 1.1, mid.z) + off, trim_mat)
					if outer:
						_garland_points.append([Vector3(mid.x, WALL_H - 0.06, mid.z), horizontal])
					continue
				# декоративное окно на каждом третьем внешнем сегменте
				if outer and (hash(key) % 3 == 0):
					_build_window_wall(mid, horizontal, wsize, n)
				else:
					_add_static_mat(root, wsize, Vector3(mid.x, WALL_H * 0.5, mid.z), wall_mat)
					# плинтус изнутри
					var tsize := Vector3(1.0, 0.18, 0.06) if horizontal else Vector3(0.06, 0.18, 1.0)
					_add_mesh_mat(root, tsize, Vector3(mid.x, 0.09, mid.z) + n * (WALL_T * 0.5 + 0.06), trim_mat)
					# картины и венки на стенах
					if a_in and b_in and hash(key) % 4 == 0:
						if hash(key) % 8 < 2:
							_build_wreath(mid, horizontal, n)
						else:
							_build_painting(mid, horizontal, n)
					elif outer and hash(key) % 5 == 1:
						_build_painting(mid, horizontal, n)
				if outer:
					_garland_points.append([Vector3(mid.x, WALL_H - 0.06, mid.z), horizontal])

func _build_window_wall(mid: Vector3, horizontal: bool, wsize: Vector3, n: Vector3) -> void:
	var wall_mat := Defs.plaster_mat(WALL_COLOR)
	var trim_mat := Defs.wood_mat(TRIM_COLOR)
	_add_mesh_mat(root, Vector3(wsize.x, 0.95, wsize.z), Vector3(mid.x, 0.475, mid.z), wall_mat)
	_add_mesh_mat(root, Vector3(wsize.x, 0.8, wsize.z), Vector3(mid.x, WALL_H - 0.4, mid.z), wall_mat)
	# рама + подоконник
	var fsize := Vector3(1.0 + WALL_T, 0.08, WALL_T + 0.05) if horizontal else Vector3(WALL_T + 0.05, 0.08, 1.0 + WALL_T)
	_add_mesh_mat(root, fsize, Vector3(mid.x, 0.99, mid.z), trim_mat)
	_add_mesh_mat(root, fsize, Vector3(mid.x, 2.16, mid.z), trim_mat)
	var sill := Vector3(1.1, 0.06, 0.22) if horizontal else Vector3(0.22, 0.06, 1.1)
	_add_mesh_mat(root, sill, Vector3(mid.x, 1.02, mid.z) + n * 0.1, trim_mat)
	# стекло — чуть светится лунной синевой
	var gsize := Vector3(1.0, 1.25, 0.04) if horizontal else Vector3(0.04, 1.25, 1.0)
	var glass := _add_mesh_box(root, gsize, Vector3(mid.x, 1.575, mid.z), Color(0.6, 0.78, 1.0, 0.3))
	var gm: StandardMaterial3D = glass.material_override
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.roughness = 0.08
	gm.emission_enabled = true
	gm.emission = Color(0.45, 0.6, 0.95)
	gm.emission_energy_multiplier = 0.35
	# переплёт окна
	var mull := Vector3(0.05, 1.25, WALL_T + 0.04) if horizontal else Vector3(WALL_T + 0.04, 1.25, 0.05)
	_add_mesh_mat(root, mull, Vector3(mid.x, 1.575, mid.z), trim_mat)
	# шторы по бокам изнутри
	var cur_mat := Defs.fabric_mat(Color(0.75, 0.35, 0.3))
	var cpos := Vector3(mid.x, 1.7, mid.z) + n * 0.22
	var coff := Vector3(0.42, 0, 0) if horizontal else Vector3(0, 0, 0.42)
	for s in [-1, 1]:
		var panel := _add_mesh_mat(root, Vector3(0.24, 1.7, 0.09) if horizontal else Vector3(0.09, 1.7, 0.24), cpos + coff * s, cur_mat)
		panel.rotation_degrees = Vector3(0, 0, s * 2.5) if horizontal else Vector3(s * 2.5, 0, 0)
	var rod := Vector3(1.15, 0.045, 0.045) if horizontal else Vector3(0.045, 0.045, 1.15)
	_add_mesh_mat(root, rod, Vector3(mid.x, 2.58, mid.z) + n * 0.18, trim_mat)
	# коллизия на весь сегмент
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = wsize
	col.shape = shape
	body.add_child(col)
	body.position = Vector3(mid.x, WALL_H * 0.5, mid.z)
	root.add_child(body)

## Рождественский венок на стене (модель висит в плоскости XY, тонкая по Z).
func _build_wreath(mid: Vector3, horizontal: bool, n: Vector3) -> void:
	var pos := Vector3(mid.x, 1.35, mid.z) + n * (WALL_T * 0.5 + 0.03)
	var w := ModelLib.place(root, "h:wreath-decorated", pos, Vector3(0, 0.6, 0), 0.0 if horizontal else PI * 0.5)
	if w == null:
		_build_painting(mid, horizontal, n)

## Картина: рама + «холст» со случайным оттенком.
func _build_painting(mid: Vector3, horizontal: bool, n: Vector3) -> void:
	var off := n * (WALL_T * 0.5 + 0.04)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(mid)
	var w := rng.randf_range(0.55, 0.8)
	var h := rng.randf_range(0.45, 0.65)
	var fr := Vector3(w, h, 0.05) if horizontal else Vector3(0.05, h, w)
	var cv := Vector3(w - 0.1, h - 0.1, 0.06) if horizontal else Vector3(0.06, h - 0.1, w - 0.1)
	_add_mesh_mat(root, fr, Vector3(mid.x, 1.75, mid.z) + off, Defs.wood_mat(Color(0.4, 0.28, 0.18)))
	var palettes := [Color(0.35, 0.5, 0.65), Color(0.55, 0.42, 0.3), Color(0.3, 0.5, 0.4), Color(0.6, 0.35, 0.35)]
	_add_mesh_mat(root, cv, Vector3(mid.x, 1.75, mid.z) + off, Defs.plaster_mat(palettes[rng.randi() % 4]))

func _build_garlands() -> void:
	if _garland_points.is_empty():
		return
	var colors := [Color(1.0, 0.35, 0.35), Color(0.4, 0.85, 1.0), Color(1.0, 0.85, 0.35), Color(0.5, 1.0, 0.55), Color(1.0, 0.55, 0.9)]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var sphere := SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.1
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sphere.material = mat
	mm.mesh = sphere
	mm.instance_count = _garland_points.size() * 3
	var idx := 0
	for gp in _garland_points:
		var base: Vector3 = gp[0]
		var along_x: bool = gp[1]
		for i in 3:
			var off := float(i - 1) * 0.33
			var pos := base + (Vector3(off, 0, 0) if along_x else Vector3(0, 0, off))
			pos.y -= 0.06 * absf(float(i - 1))  # лёгкое провисание
			mm.set_instance_transform(idx, Transform3D(Basis(), pos))
			mm.set_instance_color(idx, colors[idx % colors.size()])
			idx += 1
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	root.add_child(mmi)

# ---------------------------------------------------------------- ПРОПСЫ

func _build_props() -> void:
	for p in loc["props"]:
		var cell: Vector2i = p["cell"]
		var pos := Defs.cell_to_world(cell)
		match p["type"]:
			"chandelier":
				chandeliers[cell] = _build_chandelier(pos)
			"fireplace":
				_build_fireplace(pos)
			"tree":
				_build_tree(pos)
	for e in loc["entries"]:
		if e["type"] == "balcony":
			_build_balcony(e)

func _build_chandelier(pos: Vector3) -> Node3D:
	var ch := Node3D.new()
	ch.name = "Chandelier"
	ch.position = Vector3(pos.x, 2.55, pos.z)
	var chain := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.025
	cm.bottom_radius = 0.025
	cm.height = 0.5
	chain.mesh = cm
	chain.position = Vector3(0, 0.35, 0)
	chain.material_override = Defs.flat_mat(Color(0.3, 0.3, 0.32))
	ch.add_child(chain)
	var body := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.1
	bm.bottom_radius = 0.42
	bm.height = 0.3
	body.mesh = bm
	body.material_override = Defs.flat_mat(Color(0.95, 0.78, 0.35), 0.8)
	ch.add_child(body)
	for i in 5:
		var ang := i * TAU / 5.0
		var candle := MeshInstance3D.new()
		var cm2 := CylinderMesh.new()
		cm2.top_radius = 0.03
		cm2.bottom_radius = 0.03
		cm2.height = 0.12
		candle.mesh = cm2
		candle.position = Vector3(cos(ang) * 0.36, 0.16, sin(ang) * 0.36)
		candle.material_override = Defs.flat_mat(Color(1.0, 0.95, 0.8), 2.0)
		ch.add_child(candle)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.6)
	light.light_energy = 1.5
	light.omni_range = 8.0
	light.position = Vector3(0, -0.2, 0)
	ch.add_child(light)
	root.add_child(ch)
	return ch

func _build_fireplace(pos: Vector3) -> void:
	var brick := Color(0.68, 0.34, 0.27)
	_add_static_box(root, Vector3(0.5, 2.0, 0.3), Vector3(pos.x - 0.3, 1.0, pos.z - 0.65), brick)
	_add_static_box(root, Vector3(0.5, 2.0, 0.3), Vector3(pos.x - 0.3, 1.0, pos.z + 0.65), brick)
	_add_static_box(root, Vector3(0.5, 0.4, 1.6), Vector3(pos.x - 0.3, 2.2, pos.z), brick)
	_add_mesh_mat(root, Vector3(0.6, 0.12, 1.8), Vector3(pos.x - 0.3, 2.46, pos.z), Defs.wood_mat(TRIM_COLOR))  # полка
	# носки на камине
	var sock_ids := ["h:sock-red", "h:sock-green", "h:sock-red-cane"]
	if ModelLib.scene("h:sock-red") != null:
		for i in 3:
			ModelLib.place(root, sock_ids[i], Vector3(pos.x - 0.02, 2.02, pos.z - 0.5 + i * 0.5), Vector3(0, 0.4, 0), PI * 0.5)
		ModelLib.place(root, "h:nutcracker", Vector3(pos.x + 0.05, 0, pos.z - 1.15), Vector3(0, 0.85, 0), PI * 0.35, true)
	else:
		for i in 3:
			var sock := Node3D.new()
			sock.position = Vector3(pos.x - 0.05, 2.2, pos.z - 0.5 + i * 0.5)
			root.add_child(sock)
			var sc: Color = [Color(0.85, 0.25, 0.25), Color(0.3, 0.65, 0.35), Color(0.9, 0.75, 0.3)][i]
			_add_mesh_mat(sock, Vector3(0.08, 0.28, 0.14), Vector3(0, -0.14, 0), Defs.fabric_mat(sc))
			_add_mesh_mat(sock, Vector3(0.08, 0.1, 0.2), Vector3(0, -0.31, 0.04), Defs.fabric_mat(sc))
			_add_mesh_mat(sock, Vector3(0.1, 0.07, 0.16), Vector3(0, -0.02, 0), Defs.fabric_mat(Color(0.95, 0.95, 0.92)))
	var fire := OmniLight3D.new()
	fire.light_color = Color(1.0, 0.55, 0.2)
	fire.light_energy = 1.8
	fire.omni_range = 5.0
	fire.position = Vector3(pos.x - 0.2, 0.6, pos.z)
	root.add_child(fire)
	_add_mesh_box(root, Vector3(0.3, 0.35, 0.8), Vector3(pos.x - 0.35, 0.18, pos.z), Color(1.0, 0.5, 0.15), 2.5)
	# огонь — партиклы
	var parts := GPUParticles3D.new()
	parts.amount = 24
	parts.lifetime = 0.7
	parts.position = Vector3(pos.x - 0.35, 0.35, pos.z)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.12, 0.05, 0.3)
	pm.gravity = Vector3(0, 1.8, 0)
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.5
	pm.direction = Vector3(0, 1, 0)
	pm.scale_min = 0.4
	pm.scale_max = 1.0
	parts.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	var qm := StandardMaterial3D.new()
	qm.albedo_color = Color(1.0, 0.6, 0.15, 0.85)
	qm.emission_enabled = true
	qm.emission = Color(1.0, 0.45, 0.1)
	qm.emission_energy_multiplier = 2.0
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = qm
	parts.draw_pass_1 = quad
	root.add_child(parts)

func _build_tree(pos: Vector3) -> void:
	if ModelLib.scene("h:tree-decorated") != null:
		var tr := Node3D.new()
		tr.position = pos
		root.add_child(tr)
		ModelLib.place(tr, "h:tree-decorated", Vector3.ZERO, Vector3(0, 2.7, 0), randf() * TAU)
		var tl := OmniLight3D.new()
		tl.light_color = Color(0.95, 0.85, 0.55)
		tl.light_energy = 1.1
		tl.omni_range = 5.0
		tl.position = Vector3(0, 1.4, 0)
		tr.add_child(tl)
		var tbody := StaticBody3D.new()
		var tcol := CollisionShape3D.new()
		var tshape := CylinderShape3D.new()
		tshape.radius = 0.5
		tshape.height = 2.4
		tcol.shape = tshape
		tcol.position = Vector3(0, 1.2, 0)
		tbody.add_child(tcol)
		tr.add_child(tbody)
		for i in 4:
			var g := Minifig.build_present()
			var ang := 0.8 + i * 1.6
			g.position = Vector3(cos(ang) * 0.8, 0, sin(ang) * 0.8)
			g.rotation.y = ang
			g.scale = Vector3.ONE * (0.75 + 0.12 * i)
			tr.add_child(g)
		return
	var tree := Node3D.new()
	tree.position = pos
	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.1
	tm.bottom_radius = 0.12
	tm.height = 0.4
	trunk.mesh = tm
	trunk.position = Vector3(0, 0.2, 0)
	trunk.material_override = Defs.flat_mat(Color(0.45, 0.3, 0.18))
	tree.add_child(trunk)
	var green := Color(0.2, 0.58, 0.3)
	var sizes := [Vector2(0.75, 0.8), Vector2(0.6, 0.7), Vector2(0.42, 0.6)]
	var y := 0.55
	for s in sizes:
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.02
		cm.bottom_radius = s.x
		cm.height = s.y
		cone.mesh = cm
		cone.position = Vector3(0, y, 0)
		cone.material_override = Defs.flat_mat(green)
		tree.add_child(cone)
		y += s.y * 0.62
	var star := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.1
	sm.height = 0.2
	star.mesh = sm
	star.position = Vector3(0, y + 0.15, 0)
	star.material_override = Defs.flat_mat(Color(1.0, 0.85, 0.3), 3.0)
	tree.add_child(star)
	var glcolors := [Color(1, 0.3, 0.3), Color(0.3, 0.7, 1), Color(1, 0.8, 0.3), Color(0.4, 1, 0.5)]
	for i in 12:
		var b := MeshInstance3D.new()
		var bm := SphereMesh.new()
		bm.radius = 0.05
		bm.height = 0.1
		b.mesh = bm
		var ang := i * TAU / 12.0 * 2.3
		var h := 0.45 + 0.12 * i
		var rr := 0.75 - 0.048 * i
		b.position = Vector3(cos(ang) * rr, h, sin(ang) * rr)
		b.material_override = Defs.flat_mat(glcolors[i % 4], 2.2)
		tree.add_child(b)
	var light := OmniLight3D.new()
	light.light_color = Color(0.95, 0.85, 0.55)
	light.light_energy = 1.1
	light.omni_range = 5.0
	light.position = Vector3(0, 1.2, 0)
	tree.add_child(light)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.5
	shape.height = 2.0
	col.shape = shape
	col.position = Vector3(0, 1, 0)
	body.add_child(col)
	tree.add_child(body)
	# подарки под ёлкой
	for i in 3:
		var g := Minifig.build_present()
		var ang := 0.8 + i * 2.0
		g.position = Vector3(cos(ang) * 0.75, 0, sin(ang) * 0.75)
		g.rotation.y = ang
		g.scale = Vector3.ONE * (0.7 + 0.15 * i)
		tree.add_child(g)
	root.add_child(tree)

func _build_balcony(e: Dictionary) -> void:
	var outer: Vector2i = e["cell"] + e["out_dir"]
	var pos := Defs.cell_to_world(outer)
	_add_static_box(root, Vector3(1.4, 0.06, 1.4), Vector3(pos.x, 0.03, pos.z), Color(0.6, 0.6, 0.65))
	for off in [Vector3(0, 0.55, -0.65), Vector3(0, 0.55, 0.65)]:
		_add_static_box(root, Vector3(1.4, 0.07, 0.07), pos + off, Color(0.42, 0.42, 0.48))
		for i in 4:
			_add_mesh_box(root, Vector3(0.05, 0.5, 0.05), pos + Vector3(-0.5 + i * 0.34, 0.28, off.z), Color(0.42, 0.42, 0.48))

# ---------------------------------------------------------------- МЕБЕЛЬ

func _build_furniture() -> void:
	for f in loc.get("furniture", []):
		var cells: Array = f["cells"]
		var minc: Vector2i = cells[0]
		var maxc: Vector2i = cells[0]
		for c in cells:
			minc = Vector2i(mini(minc.x, c.x), mini(minc.y, c.y))
			maxc = Vector2i(maxi(maxc.x, c.x), maxi(maxc.y, c.y))
		var w := float(maxc.x - minc.x + 1)
		var d := float(maxc.y - minc.y + 1)
		var center := Vector3((minc.x + maxc.x + 1) * 0.5, 0, (minc.y + maxc.y + 1) * 0.5)
		var node := Node3D.new()
		node.position = center
		var rot: int = f.get("rot", 0)
		node.rotation.y = PI - deg_to_rad(float(rot))
		root.add_child(node)
		# при повороте на 90/270 локальные оси меняются местами
		if rot % 180 != 0:
			var tmp := w
			w = d
			d = tmp
		_make_furniture(node, f["type"], w, d)
		# высокая мебель — интерактив: её можно уронить триггером
		if f["type"] in ["shelf", "wardrobe", "fridge"]:
			shelves.append({"cells": cells, "cell": cells[0], "node": node, "type": f["type"]})
		elif f["type"] == "tv":
			tvs.append({"cell": cells[0], "node": node})

func _make_furniture(n: Node3D, type: String, w: float, d: float) -> void:
	if _make_furniture_model(n, type, w, d):
		return
	_make_furniture_proc(n, type, w, d)

## Мебель из настоящих моделей (Kenney, CC0). false — модели нет, падаем на кубы.
func _make_furniture_model(n: Node3D, type: String, w: float, d: float) -> bool:
	match type:
		"sofa":
			var id := "loungeSofaLong" if w >= 1.9 else "loungeSofa"
			return ModelLib.place(n, id, Vector3.ZERO, Vector3(w - 0.1, 1.2, d - 0.15), 0.0, true) != null
		"armchair":
			return ModelLib.place(n, "loungeChairRelax", Vector3.ZERO, Vector3(0.85, 1.1, 0.85), 0.0, true) != null
		"tv":
			var cab := ModelLib.place(n, "cabinetTelevision", Vector3.ZERO, Vector3(w - 0.2, 0.55, 0.75), 0.0, true)
			if cab == null:
				return false
			var ch: float = cab.get_meta("size").y
			ModelLib.place(n, "televisionVintage", Vector3(0, ch, 0), Vector3(w - 0.8, 0.65, 0.5))
			return true
		"shelf":
			var sh := ModelLib.place(n, "bookcaseClosedWide", Vector3.ZERO, Vector3(0.95, 1.9, 0.5), 0.0, true)
			if sh == null:
				return false
			ModelLib.place(n, "books", Vector3(0.05, sh.get_meta("size").y, 0), Vector3(0.45, 0.3, 0.3), randf_range(-0.3, 0.3))
			return true
		"table":
			var tb := ModelLib.place(n, "tableCloth", Vector3.ZERO, Vector3(w - 0.2, 0.8, d - 0.2), 0.0, true)
			if tb == null:
				return false
			var th: float = tb.get_meta("size").y
			ModelLib.place(n, "h:gingerbread-man", Vector3(0.12, th - 0.02, 0.08), Vector3(0, 0.22, 0), randf() * TAU)
			return true
		"counter":
			var mods := ["kitchenSink", "kitchenStove", "kitchenCabinetDrawer"]
			var count := maxi(1, roundi(w))
			for i in count:
				var mid: String = mods[i % mods.size()] if count > 1 else "kitchenCabinetDrawer"
				if ModelLib.place(n, mid, Vector3(-w * 0.5 + 0.5 + i, 0, -0.1), Vector3(0.98, 1.05, 0.75), 0.0, true) == null:
					return false
			return true
		"fridge":
			return ModelLib.place(n, "kitchenFridgeLarge", Vector3.ZERO, Vector3(0.85, 1.95, 0.8), 0.0, true) != null
		"bed":
			var id := "bedDouble" if w >= 1.9 and d >= 1.9 else "bedSingle"
			var bed := ModelLib.place(n, id, Vector3.ZERO, Vector3(w - 0.05, 1.1, d - 0.05), 0.0, true)
			if bed == null:
				return false
			if hash(n.position) % 2 == 0:
				ModelLib.place(n, "bear", Vector3(-w * 0.2, bed.get_meta("size").y * 0.55, 0.1), Vector3(0, 0.35, 0), randf_range(-0.6, 0.6))
			return true
		"wardrobe":
			return ModelLib.place(n, "bookcaseClosedDoors", Vector3.ZERO, Vector3(w - 0.15, 2.1, 0.65), 0.0, true) != null
		"lamp":
			var lp := ModelLib.place(n, "lampRoundFloor", Vector3.ZERO, Vector3(0.5, 1.5, 0.5), 0.0, true)
			if lp == null:
				return false
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.8, 0.55)
			l.light_energy = 0.9
			l.omni_range = 4.0
			l.position = Vector3(0, lp.get_meta("size").y - 0.15, 0)
			n.add_child(l)
			return true
		"bench":
			return ModelLib.place(n, "benchCushionLow", Vector3.ZERO, Vector3(0.95, 0.6, 0.5), 0.0, true) != null
		"coat_rack":
			return ModelLib.place(n, "coatRackStanding", Vector3.ZERO, Vector3(0.6, 1.85, 0.6), 0.0, true) != null
		"boxes":
			var bx := ModelLib.place(n, "cardboardBoxClosed", Vector3(0.02, 0, -0.05), Vector3(0.72, 0.55, 0.72), 0.15, true)
			if bx == null:
				return false
			ModelLib.place(n, "cardboardBoxOpen", Vector3(0.05, bx.get_meta("size").y, -0.02), Vector3(0.55, 0.5, 0.55), -0.3)
			return true
		"tub":
			return ModelLib.place(n, "bathtub", Vector3.ZERO, Vector3(w - 0.1, 0.75, d - 0.2), 0.0, true) != null
		"sink":
			return ModelLib.place(n, "bathroomSink", Vector3.ZERO, Vector3(0.6, 1.05, 0.5), 0.0, true) != null
		"toilet":
			return ModelLib.place(n, "toilet", Vector3.ZERO, Vector3(0.5, 0.9, 0.65), 0.0, true) != null
	return false

func _make_furniture_proc(n: Node3D, type: String, w: float, d: float) -> void:
	var fab := Defs.fabric_mat(Color(0.35, 0.55, 0.75))
	var wood_m := Defs.wood_mat(Color(0.62, 0.44, 0.28))
	var white_m := Defs.plaster_mat(Color(0.93, 0.94, 0.96))
	match type:
		"sofa":
			_add_static_mat(n, Vector3(w - 0.15, 0.42, d - 0.35), Vector3(0, 0.21, 0.1), fab)
			_add_mesh_mat(n, Vector3(w - 0.15, 0.55, 0.22), Vector3(0, 0.62, -d * 0.5 + 0.26), fab)
			_add_mesh_mat(n, Vector3(0.2, 0.32, d - 0.35), Vector3(-w * 0.5 + 0.18, 0.55, 0.1), fab)
			_add_mesh_mat(n, Vector3(0.2, 0.32, d - 0.35), Vector3(w * 0.5 - 0.18, 0.55, 0.1), fab)
			var cushion := Defs.fabric_mat(Color(0.45, 0.65, 0.85))
			_add_mesh_mat(n, Vector3(w * 0.42, 0.14, d - 0.5), Vector3(-w * 0.22, 0.46, 0.12), cushion)
			_add_mesh_mat(n, Vector3(w * 0.42, 0.14, d - 0.5), Vector3(w * 0.22, 0.46, 0.12), cushion)
			# круглая подушка
			var pil := MeshInstance3D.new()
			var pm := SphereMesh.new()
			pm.radius = 0.16
			pm.height = 0.2
			pil.mesh = pm
			pil.material_override = Defs.fabric_mat(Color(0.9, 0.6, 0.3))
			pil.position = Vector3(w * 0.3, 0.6, 0)
			n.add_child(pil)
		"armchair":
			var arm_fab := Defs.fabric_mat(Color(0.75, 0.45, 0.3))
			_add_static_mat(n, Vector3(0.8, 0.4, 0.7), Vector3(0, 0.2, 0.05), arm_fab)
			_add_mesh_mat(n, Vector3(0.8, 0.5, 0.2), Vector3(0, 0.6, -0.28), arm_fab)
		"tv":
			_add_static_mat(n, Vector3(w - 0.4, 0.5, 0.45), Vector3(0, 0.25, -0.15), wood_m)
			_add_mesh_box(n, Vector3(w - 0.6, 0.75, 0.08), Vector3(0, 0.95, -0.15), Color(0.12, 0.12, 0.15))
			_add_mesh_box(n, Vector3(w - 0.72, 0.62, 0.02), Vector3(0, 0.95, -0.1), Color(0.2, 0.35, 0.6), 0.8)
		"shelf":
			_add_static_mat(n, Vector3(0.9, 1.9, 0.4), Vector3(0, 0.95, -0.25), wood_m)
			for i in 3:
				_add_mesh_mat(n, Vector3(0.7, 0.18, 0.28), Vector3(randf_range(-0.05, 0.05), 0.5 + i * 0.55, -0.22),
					Defs.fabric_mat([Color(0.8, 0.35, 0.3), Color(0.35, 0.6, 0.8), Color(0.85, 0.7, 0.3)][i]))
		"table":
			_add_static_mat(n, Vector3(w - 0.3, 0.1, d - 0.3), Vector3(0, 0.72, 0), wood_m)
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					_add_mesh_mat(n, Vector3(0.08, 0.7, 0.08), Vector3(sx * (w * 0.5 - 0.25), 0.35, sz * (d * 0.5 - 0.25)), wood_m)
			# тарелка с печеньем и кружка
			var plate := MeshInstance3D.new()
			var plm := CylinderMesh.new()
			plm.top_radius = 0.16
			plm.bottom_radius = 0.12
			plm.height = 0.04
			plate.mesh = plm
			plate.material_override = white_m
			plate.position = Vector3(0, 0.8, 0)
			n.add_child(plate)
			var mug := MeshInstance3D.new()
			var mm := CylinderMesh.new()
			mm.top_radius = 0.05
			mm.bottom_radius = 0.05
			mm.height = 0.1
			mug.mesh = mm
			mug.material_override = Defs.flat_mat(Color(0.75, 0.3, 0.28))
			mug.position = Vector3(0.24, 0.83, 0.12)
			n.add_child(mug)
		"counter":
			_add_static_mat(n, Vector3(w - 0.1, 0.9, 0.65), Vector3(0, 0.45, -0.15), Defs.plaster_mat(Color(0.55, 0.68, 0.72)))
			_add_mesh_mat(n, Vector3(w - 0.05, 0.06, 0.72), Vector3(0, 0.93, -0.15), Defs.plaster_mat(Color(0.9, 0.88, 0.84)))
			_add_mesh_box(n, Vector3(0.4, 0.05, 0.35), Vector3(-w * 0.25, 0.99, -0.15), Color(0.4, 0.4, 0.44))
		"fridge":
			_add_static_mat(n, Vector3(0.8, 1.9, 0.75), Vector3(0, 0.95, 0), white_m)
			_add_mesh_box(n, Vector3(0.06, 0.4, 0.06), Vector3(0.32, 1.2, 0.39), Color(0.6, 0.6, 0.65))
			# магнитики
			for i in 3:
				_add_mesh_box(n, Vector3(0.07, 0.07, 0.02), Vector3(-0.2 + i * 0.16, 1.3 - (i % 2) * 0.2, 0.39),
					[Color(0.9, 0.4, 0.3), Color(0.3, 0.7, 0.4), Color(0.95, 0.8, 0.3)][i])
		"bed":
			_add_static_mat(n, Vector3(w - 0.2, 0.35, d - 0.2), Vector3(0, 0.18, 0), wood_m)
			_add_mesh_mat(n, Vector3(w - 0.3, 0.18, d - 0.3), Vector3(0, 0.44, 0), Defs.fabric_mat(Color(0.55, 0.75, 0.9)))
			_add_mesh_mat(n, Vector3(w - 0.3, 0.2, d * 0.4), Vector3(0, 0.47, d * 0.2), Defs.fabric_mat(Color(0.85, 0.3, 0.3)))
			var pil := MeshInstance3D.new()
			var pm := SphereMesh.new()
			pm.radius = 0.22
			pm.height = 0.18
			pil.mesh = pm
			pil.material_override = Defs.fabric_mat(Color(0.95, 0.94, 0.9))
			pil.position = Vector3(-w * 0.2, 0.56, -d * 0.5 + 0.35)
			n.add_child(pil)
			_add_mesh_mat(n, Vector3(w - 0.15, 0.7, 0.1), Vector3(0, 0.4, -d * 0.5 + 0.06), wood_m)
		"wardrobe":
			_add_static_mat(n, Vector3(w - 0.15, 2.1, 0.6), Vector3(0, 1.05, -0.18), Defs.wood_mat(Color(0.5, 0.35, 0.22)))
			_add_mesh_box(n, Vector3(0.04, 1.6, 0.05), Vector3(0, 1.0, 0.13), Color(0.85, 0.7, 0.4))
		"lamp":
			_add_static_box(n, Vector3(0.3, 0.06, 0.3), Vector3(0, 0.03, 0), Color(0.3, 0.3, 0.34))
			_add_mesh_box(n, Vector3(0.06, 1.3, 0.06), Vector3(0, 0.68, 0), Color(0.3, 0.3, 0.34))
			var shade := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.14
			cm.bottom_radius = 0.22
			cm.height = 0.28
			shade.mesh = cm
			shade.position = Vector3(0, 1.42, 0)
			shade.material_override = Defs.flat_mat(Color(1.0, 0.8, 0.5), 1.2)
			n.add_child(shade)
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.8, 0.55)
			l.light_energy = 0.9
			l.omni_range = 4.0
			l.position = Vector3(0, 1.35, 0)
			n.add_child(l)
		"bench":
			_add_static_mat(n, Vector3(0.9, 0.45, 0.4), Vector3(0, 0.22, 0), wood_m)
		"coat_rack":
			_add_static_mat(n, Vector3(0.12, 1.8, 0.12), Vector3(0, 0.9, 0), wood_m)
			_add_mesh_mat(n, Vector3(0.5, 0.06, 0.06), Vector3(0, 1.7, 0), wood_m)
			_add_mesh_mat(n, Vector3(0.3, 0.5, 0.1), Vector3(0.15, 1.35, 0), Defs.fabric_mat(Color(0.8, 0.4, 0.3)))
		"boxes":
			_add_static_mat(n, Vector3(0.7, 0.5, 0.7), Vector3(0, 0.25, 0), Defs.wood_mat(Color(0.72, 0.55, 0.35)))
			_add_mesh_mat(n, Vector3(0.5, 0.4, 0.5), Vector3(0.05, 0.7, -0.05), Defs.wood_mat(Color(0.78, 0.62, 0.4)))
		"tub":
			_add_static_mat(n, Vector3(w - 0.2, 0.6, d - 0.3), Vector3(0, 0.3, 0), white_m)
			_add_mesh_box(n, Vector3(w - 0.45, 0.05, d - 0.55), Vector3(0, 0.58, 0), Color(0.5, 0.8, 0.95))
		"sink":
			_add_static_mat(n, Vector3(0.6, 0.85, 0.5), Vector3(0, 0.42, 0), white_m)
			_add_mesh_box(n, Vector3(0.45, 0.08, 0.38), Vector3(0, 0.88, 0), Color(0.8, 0.9, 0.95))
		"toilet":
			_add_static_mat(n, Vector3(0.45, 0.45, 0.6), Vector3(0, 0.22, 0), white_m)
			_add_mesh_mat(n, Vector3(0.4, 0.55, 0.15), Vector3(0, 0.6, -0.22), white_m)

# ---------------------------------------------------------------- КЛАТТЕР

## Мелочи, делающие дом живым: растения по углам, настенные часы.
func _build_clutter() -> void:
	for i in loc["rooms"].size():
		var rect: Rect2i = loc["rooms"][i]["rect"]
		var corner := Vector2i(rect.position.x, rect.position.y + rect.size.y - 1)
		if i % 2 == 1:
			corner = Vector2i(rect.position.x + rect.size.x - 1, rect.position.y)
		if not is_free_cell(corner) or is_doorway_cell(corner):
			continue
		var plant := Node3D.new()
		plant.position = Defs.cell_to_world(corner) + Vector3(randf_range(-0.15, 0.15), 0, randf_range(-0.15, 0.15))
		root.add_child(plant)
		if ModelLib.scene("pottedPlant") != null:
			var pid: String = ["pottedPlant", "plantSmall1", "plantSmall2", "plantSmall3"][i % 4]
			ModelLib.place(plant, pid, Vector3.ZERO, Vector3(0, randf_range(0.6, 1.0), 0), randf() * TAU)
			continue
		var pot := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.16
		pm.bottom_radius = 0.11
		pm.height = 0.22
		pot.mesh = pm
		pot.material_override = Defs.plaster_mat(Color(0.7, 0.4, 0.3))
		pot.position = Vector3(0, 0.11, 0)
		plant.add_child(pot)
		for j in 3:
			var leaf := MeshInstance3D.new()
			var lm := SphereMesh.new()
			lm.radius = 0.13 - j * 0.02
			lm.height = 0.3 + j * 0.08
			leaf.mesh = lm
			leaf.material_override = Defs.flat_mat(Color(0.22, 0.5, 0.28))
			leaf.position = Vector3(cos(j * 2.1) * 0.07, 0.35 + j * 0.1, sin(j * 2.1) * 0.07)
			leaf.rotation_degrees = Vector3(j * 14 - 14, j * 40, 0)
			plant.add_child(leaf)
	# часы на стене первой комнаты
	var r0: Rect2i = loc["rooms"][0]["rect"]
	var clock := Node3D.new()
	clock.position = Vector3(r0.position.x + r0.size.x * 0.5 + 1.0, 2.25, r0.position.y + 0.12)
	root.add_child(clock)
	var face := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 0.24
	fm.bottom_radius = 0.24
	fm.height = 0.06
	face.mesh = fm
	face.rotation_degrees = Vector3(90, 0, 0)
	face.material_override = Defs.plaster_mat(Color(0.95, 0.93, 0.88))
	clock.add_child(face)
	var rim := MeshInstance3D.new()
	var rm := TorusMesh.new()
	rm.inner_radius = 0.22
	rm.outer_radius = 0.27
	rim.mesh = rm
	rim.rotation_degrees = Vector3(90, 0, 0)
	rim.material_override = Defs.wood_mat(Color(0.45, 0.3, 0.2))
	clock.add_child(rim)
	_add_mesh_box(clock, Vector3(0.03, 0.15, 0.02), Vector3(0, 0.06, 0.04), Color(0.15, 0.15, 0.18))
	_add_mesh_box(clock, Vector3(0.1, 0.03, 0.02), Vector3(0.04, 0, 0.04), Color(0.15, 0.15, 0.18))

# ---------------------------------------------------------------- УЛИЦА

func _build_outside() -> void:
	var size: Vector2i = loc["size"]
	var center := Vector3(size.x * 0.5, 0, size.y * 0.5)
	_add_static_box(root, Vector3(size.x + 60, 0.2, size.y + 60), Vector3(center.x, -0.12, center.z), Color(0.88, 0.92, 1.0))
	for e in loc["entries"]:
		if e["type"] != "door":
			continue
		var outer: Vector2i = e["cell"] + e["out_dir"]
		var pos := Defs.cell_to_world(outer)
		_add_static_box(root, Vector3(1.2, 0.06, 1.0), Vector3(pos.x, 0.03, pos.z), Color(0.55, 0.4, 0.28))
		# фонарь у входа
		_add_mesh_box(root, Vector3(0.08, 2.2, 0.08), pos + Vector3(0.8, 1.1, 0), Color(0.25, 0.25, 0.3))
		_add_mesh_box(root, Vector3(0.22, 0.25, 0.22), pos + Vector3(0.8, 2.25, 0), Color(1.0, 0.85, 0.5), 2.0)
		var pl := OmniLight3D.new()
		pl.light_color = Color(1.0, 0.8, 0.5)
		pl.light_energy = 1.2
		pl.omni_range = 6.0
		pl.position = pos + Vector3(0.8, 2.2, 0)
		root.add_child(pl)
		# леденцы у крыльца
		var od := Vector3(e["out_dir"].x, 0, e["out_dir"].y)
		var side := Vector3(od.z, 0, -od.x)
		ModelLib.place(root, "h:candy-cane-red", pos + side * 0.55 + od * 0.3, Vector3(0, 0.9, 0), randf() * TAU)
		ModelLib.place(root, "h:candy-cane-green", pos - side * 0.55 + od * 0.35, Vector3(0, 0.75, 0), randf() * TAU)
	# снеговик
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(loc_id)
	var sn_pos := center + Vector3(cos(rng.randf() * TAU), 0, sin(rng.randf() * TAU)) * (maxf(size.x, size.y) * 0.5 + 4.0)
	if ModelLib.scene("h:snowman-hat") != null:
		ModelLib.place(root, "h:snowman-hat", sn_pos, Vector3(0, 1.9, 0), rng.randf() * TAU)
		var deer_pos := sn_pos + Vector3(2.2, 0, 1.0)
		ModelLib.place(root, "h:reindeer", deer_pos, Vector3(0, 1.6, 0), rng.randf() * TAU)
		ModelLib.place(root, "h:sled", deer_pos + Vector3(1.5, 0, 0.6), Vector3(0, 0.8, 0), rng.randf() * TAU)
		ModelLib.place(root, "h:snow-pile", sn_pos + Vector3(-1.8, 0, 0.8), Vector3(0, 0.5, 0), rng.randf() * TAU)
	else:
		_build_snowman_proc(sn_pos)
	# ёлки вокруг
	var have_tree_models := ModelLib.scene("h:tree-snow-a") != null
	for i in 18:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(7.0, 20.0)
		var p := center + Vector3(cos(ang) * dist, 0, sin(ang) * dist)
		if p.x > -2 and p.x < size.x + 2 and p.z > -2 and p.z < size.y + 2:
			continue
		if have_tree_models:
			var tid: String = ["h:tree-snow-a", "h:tree-snow-b", "h:tree-snow-c"][rng.randi() % 3]
			ModelLib.place(root, tid, p, Vector3(0, rng.randf_range(2.6, 5.5), 0), rng.randf() * TAU)
		else:
			_build_pine_proc(p, rng.randf_range(1.2, 2.4))
	_build_snowfall(center, size)

func _build_snowman_proc(sn_pos: Vector3) -> void:
	var snowman := Node3D.new()
	snowman.position = sn_pos
	for i in 3:
		var ball := MeshInstance3D.new()
		var bm := SphereMesh.new()
		bm.radius = 0.55 - i * 0.15
		bm.height = bm.radius * 2
		ball.mesh = bm
		ball.position = Vector3(0, 0.4 + i * 0.72, 0)
		ball.material_override = Defs.flat_mat(Color(0.96, 0.97, 1.0))
		snowman.add_child(ball)
	var nose := MeshInstance3D.new()
	var nm := CylinderMesh.new()
	nm.top_radius = 0.01
	nm.bottom_radius = 0.05
	nm.height = 0.3
	nose.mesh = nm
	nose.rotation_degrees = Vector3(90, 0, 0)
	nose.position = Vector3(0, 1.84, 0.3)
	nose.material_override = Defs.flat_mat(Color(0.95, 0.55, 0.2))
	snowman.add_child(nose)
	root.add_child(snowman)

func _build_pine_proc(p: Vector3, s: float) -> void:
	var tree := Node3D.new()
	tree.position = p
	var cone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.02
	cm.bottom_radius = 0.8 * s
	cm.height = 2.2 * s
	cone.mesh = cm
	cone.position = Vector3(0, 1.1 * s, 0)
	cone.material_override = Defs.flat_mat(Color(0.16, 0.4, 0.26))
	tree.add_child(cone)
	var snow := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.02
	sm.bottom_radius = 0.45 * s
	sm.height = 1.0 * s
	snow.mesh = sm
	snow.position = Vector3(0, 1.9 * s, 0)
	snow.material_override = Defs.flat_mat(Color(0.95, 0.97, 1.0))
	tree.add_child(snow)
	root.add_child(tree)

## Падающий снег над всей локацией.
func _build_snowfall(center: Vector3, size: Vector2i) -> void:
	var parts := GPUParticles3D.new()
	parts.amount = 800
	parts.lifetime = 10.0
	parts.preprocess = 10.0
	parts.position = Vector3(center.x, 9.0, center.z)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(size.x + 20, 0.5, size.y + 20)
	pm.gravity = Vector3(0, -0.9, 0)
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.6
	pm.direction = Vector3(0, -1, 0)
	parts.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.07, 0.07)
	var qm := StandardMaterial3D.new()
	qm.albedo_color = Color(1, 1, 1, 0.9)
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = qm
	parts.draw_pass_1 = quad
	root.add_child(parts)

# ---------------------------------------------------------------- НОЧНОЕ НЕБО (общее с меню)

static func build_night_env(parent: Node) -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.09, 0.11, 0.26)
	sky_mat.sky_horizon_color = Color(0.36, 0.26, 0.44)
	sky_mat.ground_bottom_color = Color(0.12, 0.12, 0.2)
	sky_mat.ground_horizon_color = Color(0.36, 0.26, 0.44)
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.08
	# глобальное освещение — мягкие переотражения света, как в We Were Here
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_min_cell_size = 0.15
	env.sdfgi_energy = 1.1
	# затенение в углах и под мебелью — «объём» картинки
	env.ssao_enabled = true
	env.ssao_intensity = 2.2
	env.ssao_radius = 1.5
	env.ssil_enabled = true
	env.ssil_intensity = 1.2
	# объёмный туман: свет свечей и луны становится «густым»
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color(0.75, 0.78, 0.95)
	env.volumetric_fog_gi_inject = 0.6
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.18
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.62, 0.72, 1.0)
	moon.light_energy = 0.55
	moon.shadow_enabled = true
	moon.light_volumetric_fog_energy = 0.6
	moon.rotation_degrees = Vector3(-50, 35, 0)
	parent.add_child(moon)
	# луна
	var moon_ball := MeshInstance3D.new()
	var mm := SphereMesh.new()
	mm.radius = 5.0
	mm.height = 10.0
	moon_ball.mesh = mm
	moon_ball.material_override = Defs.flat_mat(Color(0.98, 0.96, 0.85), 1.4)
	moon_ball.position = Vector3(-60, 70, -85)
	parent.add_child(moon_ball)
	# звёзды
	var stars := MultiMesh.new()
	stars.transform_format = MultiMesh.TRANSFORM_3D
	var star_mesh := SphereMesh.new()
	star_mesh.radius = 0.3
	star_mesh.height = 0.6
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(1, 1, 1)
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star_mesh.material = smat
	stars.mesh = star_mesh
	stars.instance_count = 260
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	for i in 260:
		var yaw := rng.randf() * TAU
		var elev := rng.randf_range(0.12, 1.35)
		var r := 130.0
		var pos := Vector3(cos(yaw) * cos(elev), sin(elev), sin(yaw) * cos(elev)) * r
		var t := Transform3D(Basis().scaled(Vector3.ONE * rng.randf_range(0.5, 1.6)), pos)
		stars.set_instance_transform(i, t)
	var smi := MultiMeshInstance3D.new()
	smi.multimesh = stars
	parent.add_child(smi)

# ---------------------------------------------------------------- ИНТЕРАКТИВ

## Люстра срывается с потолка. true — если ещё не падала.
func crash_chandelier(cell: Vector2i) -> bool:
	var ch: Node3D = chandeliers.get(cell)
	if ch == null or ch.has_meta("crashed"):
		return false
	ch.set_meta("crashed", true)
	var tw := ch.create_tween()
	tw.tween_property(ch, "position:y", 0.28, 0.30).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(ch, "rotation:z", 0.5, 0.30)
	for c in ch.get_children():
		if c is OmniLight3D:
			var lt := c.create_tween()
			lt.tween_property(c, "light_energy", 0.0, 0.35)
	return true

## Пошатать люстру (пока тикает таймер задержки) — сигнал внимательным.
func wobble_chandelier(cell: Vector2i, dur: float) -> void:
	var ch: Node3D = chandeliers.get(cell)
	if ch == null or ch.has_meta("crashed"):
		return
	var tw := ch.create_tween()
	for i in maxi(1, int(dur / 0.3)):
		tw.tween_property(ch, "rotation:x", 0.09, 0.15)
		tw.tween_property(ch, "rotation:x", -0.09, 0.15)
	tw.tween_callback(func():
		if not ch.has_meta("crashed"):
			ch.rotation.x = 0.0)

## Шкаф падает в сторону toward. true — если ещё стоял.
func topple_shelf(shelf: Dictionary, toward: Vector2i) -> bool:
	var node: Node3D = shelf["node"]
	if node.has_meta("toppled"):
		return false
	node.set_meta("toppled", true)
	var from: Vector2i = shelf["cell"]
	var dirv := Vector3(toward.x - from.x, 0, toward.y - from.y)
	if dirv.length() < 0.1:
		dirv = Vector3(1, 0, 0)
	dirv = dirv.normalized()
	var axis := Vector3.UP.cross(dirv).normalized()
	# наклон вокруг горизонтальной оси + смещение к точке падения
	var start_basis := node.basis
	var start_pos := node.position
	var tw := node.create_tween()
	tw.tween_method(func(a: float):
		node.basis = Basis(axis, a * 1.35) * start_basis
		node.position = start_pos + dirv * a * 0.55 + Vector3(0, a * 0.15, 0)
		, 0.0, 1.0, 0.45).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	# клетка, куда упал — занята
	block_cell(toward)
	return true

func block_cell(cell: Vector2i) -> void:
	furniture_cells[cell] = true
	if astar.has_point(cell_id(cell)):
		astar.set_point_disabled(cell_id(cell), true)

## Телевизор искрит электричеством. true — если ещё не срабатывал.
func spark_tv(tv: Dictionary) -> bool:
	var node: Node3D = tv["node"]
	if node.has_meta("sparked"):
		return false
	node.set_meta("sparked", true)
	# экран вспыхивает синим
	var l := OmniLight3D.new()
	l.light_color = Color(0.5, 0.75, 1.0)
	l.light_energy = 3.0
	l.omni_range = 4.0
	l.position = Vector3(0, 1.0, 0)
	node.add_child(l)
	var tw := node.create_tween()
	tw.set_loops(6)
	tw.tween_property(l, "light_energy", 0.4, 0.06)
	tw.tween_property(l, "light_energy", 3.0, 0.06)
	tw.chain().tween_callback(l.queue_free)
	return true

## Холодильник, падая, разливает молоко на соседние клетки: скользко + белая
## маскировка (ловушки под молоком менее заметны). Возвращает залитые клетки.
func spill_milk(from: Vector2i) -> Array:
	var wet_cells: Array = []
	for d in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var c: Vector2i = from + d
		if not is_inside(c):
			continue
		wet_cells.append(c)
		carpet_cells[c] = true  # белое молоко тоже прячет ловушки
		var puddle := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.5
		pm.bottom_radius = 0.5
		pm.height = 0.02
		puddle.mesh = pm
		puddle.material_override = Defs.flat_mat(Color(0.96, 0.96, 0.98, 0.9))
		puddle.position = Defs.cell_to_world(c) + Vector3(0, 0.02, 0)
		puddle.scale = Vector3(0.1, 1, 0.1)
		root.add_child(puddle)
		var tw := puddle.create_tween()
		tw.tween_property(puddle, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK)
	return wet_cells

## Выдёргивает ковёр, накрывающий cell. Возвращает клетки ковра (Санта на них падает).
func pull_rug(cell: Vector2i) -> Array:
	for cn in carpet_nodes:
		var rect: Rect2i = cn["rect"]
		if not rect.has_point(cell):
			continue
		var node: Node3D = cn["node"]
		if node.has_meta("pulled"):
			return []
		node.set_meta("pulled", true)
		# ковёр резко улетает в сторону и сворачивается
		var dir := Vector3(1, 0, 0.3).normalized()
		var tw := node.create_tween()
		tw.tween_property(node, "position", node.position + dir * 3.5, 0.35).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(node, "scale:x", 0.1, 0.35)
		tw.tween_callback(node.queue_free)
		var cells: Array = []
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			for z in range(rect.position.y, rect.position.y + rect.size.y):
				cells.append(Vector2i(x, z))
				carpet_cells.erase(Vector2i(x, z))
		return cells
	return []

## Ближайший интерактив (люстра/шкаф) в LINK_RANGE клеток от cell.
func find_linkable(cell: Vector2i) -> Dictionary:
	var best := {}
	var best_d := 999.0
	for ch_cell in chandeliers:
		var node: Node3D = chandeliers[ch_cell]
		if node.has_meta("crashed"):
			continue
		var d := float((ch_cell - cell).length())
		if d <= Defs.LINK_RANGE and d < best_d:
			best_d = d
			best = {"type": "chandelier", "cell": ch_cell}
	for sh in shelves:
		var node: Node3D = sh["node"]
		if node.has_meta("toppled"):
			continue
		for sc in sh["cells"]:
			var d := float((Vector2i(sc) - cell).length())
			if d <= Defs.LINK_RANGE and d < best_d:
				best_d = d
				best = {"type": "shelf", "cell": sc, "shelf": sh}
	for tv in tvs:
		if tv["node"].has_meta("sparked"):
			continue
		var d := float((Vector2i(tv["cell"]) - cell).length())
		if d <= Defs.LINK_RANGE and d < best_d:
			best_d = d
			best = {"type": "tv", "cell": tv["cell"], "tv": tv}
	return best

# ---------------------------------------------------------------- НАВИГАЦИЯ

func cell_id(cell: Vector2i) -> int:
	return (cell.x + 64) * 4096 + (cell.y + 64)

func _build_astar() -> void:
	for cell in cell_room:
		astar.add_point(cell_id(cell), Defs.cell_to_world(cell))
	for e in loc["entries"]:
		var outer: Vector2i = e["cell"] + e["out_dir"]
		if not astar.has_point(cell_id(outer)):
			astar.add_point(cell_id(outer), Defs.cell_to_world(outer))
	for cell in cell_room:
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			var b: Vector2i = cell + d
			if passable(cell, b):
				astar.connect_points(cell_id(cell), cell_id(b))
	for e in loc["entries"]:
		var outer: Vector2i = e["cell"] + e["out_dir"]
		astar.connect_points(cell_id(e["cell"]), cell_id(outer))
	# ёлки и мебель непроходимы
	for p in loc["props"]:
		if p["type"] == "tree":
			astar.set_point_disabled(cell_id(p["cell"]), true)
	for cell in furniture_cells:
		astar.set_point_disabled(cell_id(cell), true)

func find_path(from_cell: Vector2i, to_cell: Vector2i, danger: Dictionary) -> PackedVector3Array:
	for cell in cell_room:
		astar.set_point_weight_scale(cell_id(cell), 1.0)
	for cell in danger:
		if astar.has_point(cell_id(cell)):
			astar.set_point_weight_scale(cell_id(cell), danger[cell])
	if not astar.has_point(cell_id(from_cell)) or not astar.has_point(cell_id(to_cell)):
		return PackedVector3Array()
	return astar.get_point_path(cell_id(from_cell), cell_id(to_cell))
