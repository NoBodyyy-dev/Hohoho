class_name ModelLib
extends RefCounted
## Библиотека 3D-моделей (Kenney, CC0). Грузит .glb, нормализует масштаб под
## нужный габарит и ставит на пол. Если модели нет — вернёт null, и вызывающий
## код падает обратно на процедурную геометрию.

const FURN := "res://assets/kenney/furniture/"
const HOLI := "res://assets/kenney/holiday/"
const CUSTOM := "res://assets/custom/"   # наши модели под стиль Meccha (GLB)

static var _cache: Dictionary = {}

## Пути моделей по логическому id.
##   "h:foo"  → holiday/foo.glb
##   "c:foo"  → custom/foo.glb (сгенерённые нейронкой под наш стиль)
##   "foo"    → furniture/foo.glb
static func _path(id: String) -> String:
	if id.begins_with("h:"):
		return HOLI + id.substr(2) + ".glb"
	if id.begins_with("c:"):
		return CUSTOM + id.substr(2) + ".glb"
	return FURN + id + ".glb"

static func scene(id: String) -> PackedScene:
	if _cache.has(id):
		return _cache[id]
	var p := _path(id)
	var ps: PackedScene = load(p) if ResourceLoader.exists(p) else null
	_cache[id] = ps
	if ps == null:
		push_warning("ModelLib: нет модели " + p)
	return ps

## Совокупный AABB всех мешей инстанса (в локальных координатах корня).
static func _calc_aabb(node: Node3D) -> AABB:
	var total := AABB()
	var first := true
	var stack: Array = [[node, Transform3D()]]
	while not stack.is_empty():
		var pair: Array = stack.pop_back()
		var n: Node = pair[0]
		var xf: Transform3D = pair[1]
		if n is Node3D:
			xf = xf * (n as Node3D).transform
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var ab: AABB = xf * (n as MeshInstance3D).get_aabb()
			total = ab if first else total.merge(ab)
			first = false
		for c in n.get_children():
			stack.push_back([c, xf])
	return total

## Инстанцирует модель, масштабирует под габарит target (оси с 0 не ограничивают),
## центрирует по XZ, ставит дном на y=0, поворачивает и добавляет к parent.
## solid=true — добавить невидимый коллайдер по итоговому AABB.
static func place(parent: Node3D, id: String, pos: Vector3, target := Vector3.ZERO, rot_y := 0.0, solid := false) -> Node3D:
	var ps := scene(id)
	if ps == null:
		return null
	var inst := ps.instantiate() as Node3D
	var aabb := _calc_aabb(inst)
	if aabb.size.length() < 0.001:
		inst.queue_free()
		return null
	var s := 1.0
	if target != Vector3.ZERO:
		s = INF
		for i in 3:
			if target[i] > 0.0 and aabb.size[i] > 0.001:
				s = minf(s, target[i] / aabb.size[i])
		if s == INF:
			s = 1.0
	var wrap := Node3D.new()
	wrap.name = "M_" + id.replace(":", "_")
	var center := aabb.get_center()
	inst.position = Vector3(-center.x, -aabb.position.y, -center.z) * s
	inst.scale = Vector3.ONE * s
	wrap.add_child(inst)
	wrap.position = pos
	wrap.rotation.y = rot_y
	wrap.set_meta("size", aabb.size * s)
	if solid:
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		var sz := aabb.size * s
		shape.size = Vector3(maxf(sz.x, 0.25), maxf(sz.y, 0.25), maxf(sz.z, 0.25))
		col.shape = shape
		col.position = Vector3(0, sz.y * 0.5, 0)
		body.add_child(col)
		wrap.add_child(body)
	parent.add_child(wrap)
	return wrap
