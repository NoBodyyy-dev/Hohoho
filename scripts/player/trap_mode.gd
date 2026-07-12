class_name TrapMode
extends Node
## Режим ловушек (F) от первого лица. Предмет выбираешь ХОТБАРОМ снизу (цифры 1-9 или
## колесо). Обычные ловушки — призрак на клетке + клик. Растяжка/верёвка — ДВЕ ТОЧКИ:
## клик ставит первый конец, тянешь нить, второй клик закрепляет; концы привязываются
## к люстре/шкафу/ТВ/ковру. После установки — QTE на качество.

const RANGE := 4.5
const GRID_N := 5
const ROPE_ITEMS := ["rope"]   # предметы с установкой «две точки»

var match_node: Node
var house: HouseBuilder
var kid: Kid

var active := false
var aimed_cell := Vector2i(-99, -99)
var items: Array = []      # item_id в порядке хотбара
var sel_i := 0
var grid_quads: Array = []
var hint_nodes: Array = []

# призраки-превью
var ghost: MeshInstance3D          # диск для обычной ловушки
var wire_prev: MeshInstance3D      # нить для растяжки
var anchor_mk: MeshInstance3D      # маркер закреплённого конца
var rope_anchor: Dictionary = {}   # {world, cell, attach} — первый конец растяжки

# установка + QTE
var placing := false
var place_trap_id := ""
var place_item_id := ""
var place_hidden := false
var place_cell := Vector2i(-99, -99)
var place_link: Dictionary = {}
var place_wire: Dictionary = {}
var place_t := 0.0
var place_total := 1.0
var qte_locked := false
var qte_value := 0.5
var qte_quality := -1.0
var delay_i := 2

func setup(p_match: Node, p_house: HouseBuilder, p_kid: Kid) -> void:
	match_node = p_match
	house = p_house
	kid = p_kid

# ---------------------------------------------------------------- ВВОД

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.keycode
		if k >= KEY_1 and k <= KEY_9:
			_select(k - KEY_1)
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if placing:
					_adjust_delay(1)
				else:
					_select(wrapi(sel_i - 1, 0, maxi(items.size(), 1)))
			MOUSE_BUTTON_WHEEL_DOWN:
				if placing:
					_adjust_delay(-1)
				else:
					_select(wrapi(sel_i + 1, 0, maxi(items.size(), 1)))
			MOUSE_BUTTON_LEFT:
				_on_click()
			MOUSE_BUTTON_RIGHT:
				if placing:
					_cancel_place()
				elif not rope_anchor.is_empty():
					rope_anchor = {}
					match_node.hud.show_message("Растяжка отменена", Color(1, 0.8, 0.6))
	if event.is_action_pressed("jump") and placing and not qte_locked:
		qte_locked = true
		qte_quality = 0.6 + 0.4 * (1.0 - absf(qte_value - 0.5) * 2.0)

func _on_click() -> void:
	if placing or items.is_empty():
		return
	var item := _current_item()
	if int(match_node.loadout.get(item, 0)) <= 0:
		match_node.hud.show_message("«%s» кончились!" % Defs.ITEMS[item]["name"], Color(1, 0.6, 0.5))
		return
	if item in ROPE_ITEMS:
		_rope_click()
	else:
		_place_single(item)

func _select(idx: int) -> void:
	if items.is_empty():
		return
	sel_i = clampi(idx, 0, items.size() - 1)
	rope_anchor = {}
	match_node.hud.set_hotbar_sel(sel_i)
	kid.set_held(_current_item())

func _current_item() -> String:
	return items[sel_i] if sel_i < items.size() else ""

func _adjust_delay(dir: int) -> void:
	if place_link.is_empty():
		return
	delay_i = clampi(delay_i + dir, 0, Defs.LINK_DELAYS.size() - 1)
	_update_qte_title()

# ---------------------------------------------------------------- ЖИЗНЬ РЕЖИМА

func toggle() -> void:
	if active:
		deactivate()
	else:
		activate()

func activate() -> void:
	active = true
	items = match_node.loadout.keys()
	sel_i = clampi(sel_i, 0, maxi(items.size() - 1, 0))
	_make_grid()
	_make_ghost()
	_make_hints()
	match_node.hud.set_crosshair(true)
	match_node.hud.set_hotbar_sel(sel_i)
	kid.set_held(_current_item())
	match_node.hud.show_message("Ловушки: 1-9 — выбор, ЛКМ — ставить. Растяжку тяни от точки к точке!", Color(0.7, 0.9, 1.0))

func deactivate() -> void:
	if placing:
		_cancel_place()
	active = false
	rope_anchor = {}
	for q in grid_quads:
		q.queue_free()
	grid_quads = []
	for h in hint_nodes:
		if is_instance_valid(h):
			h.queue_free()
	hint_nodes = []
	for n in [ghost, wire_prev, anchor_mk]:
		if is_instance_valid(n):
			n.queue_free()
	match_node.hud.set_crosshair(false)
	match_node.hud.set_hotbar_sel(-1)
	match_node.hud.hide_trap_options()
	kid.set_held("")

# ---------------------------------------------------------------- ПРИЦЕЛ

## Точка прицела: клетка, мир-позиция и объект-привязка (если рядом).
func _aim_point() -> Dictionary:
	var cam := kid.camera
	var origin := cam.global_position
	var dir := -cam.global_transform.basis.z
	# прямой прицел в люстру — конец нити крепится к ней
	for ch_cell in house.chandeliers:
		if house.chandeliers[ch_cell].has_meta("crashed"):
			continue
		var p := Defs.cell_to_world(ch_cell) + Vector3(0, 2.5, 0)
		var to := p - origin
		var along := to.dot(dir)
		if along > 0.5 and along < RANGE + 4.0 and (to - dir * along).length() < 0.85:
			return {"ok": true, "cell": ch_cell, "world": Defs.cell_to_world(ch_cell) + Vector3(0, 2.2, 0),
				"attach": {"type": "chandelier", "cell": ch_cell}}
	if dir.y > -0.05:
		return {"ok": false, "cell": Vector2i(-99, -99), "world": Vector3.ZERO, "attach": {}}
	var t := -origin.y / dir.y
	var hit := origin + dir * t
	if hit.distance_to(kid.global_position) > RANGE:
		hit = kid.global_position + (hit - kid.global_position).limit_length(RANGE)
	var cell := Defs.world_to_cell(hit)
	var ok := house.is_inside(cell)
	var attach: Dictionary = {}
	var world := Vector3(hit.x, 0.15, hit.z)
	if ok:
		var lk := house.find_linkable(cell)
		if not lk.is_empty():
			attach = lk
			var h := 2.2 if lk["type"] == "chandelier" else 1.2
			world = Defs.cell_to_world(lk["cell"]) + Vector3(0, h, 0)
		elif house.carpet_cells.has(cell):
			attach = {"type": "rug", "cell": cell}
	return {"ok": ok, "cell": cell, "world": world, "attach": attach}

func _cell_valid(cell: Vector2i) -> bool:
	return house.is_free_cell(cell) and not match_node.traps.has(cell)

# ---------------------------------------------------------------- PROCESS

func _process(_delta: float) -> void:
	if not active:
		return
	if placing:
		_process_placing(_delta)
		return
	var aim := _aim_point()
	_update_grid(aim["cell"])
	var item := _current_item()
	if item in ROPE_ITEMS:
		_update_rope_preview(aim)
	else:
		_update_single_preview(item, aim)

func _update_grid(cell: Vector2i) -> void:
	var qi := 0
	for dx in range(-GRID_N / 2, GRID_N / 2 + 1):
		for dz in range(-GRID_N / 2, GRID_N / 2 + 1):
			var c := cell + Vector2i(dx, dz)
			var q: MeshInstance3D = grid_quads[qi]
			qi += 1
			if not house.is_inside(c):
				q.visible = false
				continue
			q.visible = true
			q.position = Vector3(c.x + 0.5, 0.045, c.y + 0.5)
			var mat: StandardMaterial3D = q.material_override
			if match_node.traps.has(c):
				mat.albedo_color = Color(1.0, 0.45, 0.25, 0.3)
			elif house.carpet_cells.has(c):
				mat.albedo_color = Color(0.4, 0.7, 1.0, 0.2)
			elif not house.is_free_cell(c):
				mat.albedo_color = Color(0.5, 0.5, 0.5, 0.12)
			elif not house.find_linkable(c).is_empty():
				mat.albedo_color = Color(1.0, 0.8, 0.3, 0.17)
			else:
				mat.albedo_color = Color(1, 1, 1, 0.08)

# ---------------------------------------------------------------- ОБЫЧНАЯ ЛОВУШКА

func _update_single_preview(item: String, aim: Dictionary) -> void:
	wire_prev.visible = false
	anchor_mk.visible = false
	var cell: Vector2i = aim["cell"]
	var v := _variant_for(item, cell)
	var ok: bool = aim["ok"] and _cell_valid(cell) and not v.is_empty()
	ghost.visible = aim["ok"]
	ghost.position = Vector3(cell.x + 0.5, 0.04, cell.y + 0.5)
	var gmat: StandardMaterial3D = ghost.material_override
	gmat.albedo_color = Color(0.3, 1.0, 0.4, 0.4) if ok else Color(1.0, 0.3, 0.3, 0.35)
	if ok:
		var extra := str(v.get("extra", ""))
		var fx := Defs.trap_fx(v["trap_id"])
		var sub := fx
		if v.get("hidden", false):
			sub += "  · под ковром" if sub == "" else "  ·  под ковром"
		match_node.hud.show_context(Defs.ITEMS[item]["name"] + extra, sub, true)
	else:
		match_node.hud.show_context("Сюда нельзя", "цель в свободный пол", false)

func _place_single(item: String) -> void:
	var aim := _aim_point()
	var cell: Vector2i = aim["cell"]
	var v := _variant_for(item, cell)
	if not (aim["ok"] and _cell_valid(cell)) or v.is_empty():
		match_node.hud.show_message("Сюда не поставить", Color(1, 0.6, 0.5))
		return
	_begin_place(v["trap_id"], item, cell, v.get("link", {}), v.get("hidden", false), {})

# ---------------------------------------------------------------- РАСТЯЖКА (2 точки)

func _rope_click() -> void:
	var aim := _aim_point()
	if not aim["ok"]:
		match_node.hud.show_message("Целься внутрь дома", Color(1, 0.6, 0.5))
		return
	if rope_anchor.is_empty():
		rope_anchor = aim.duplicate()
		match_node.hud.show_message("Первый конец закреплён. Тяни нить и кликни второй!", Color(0.7, 1, 0.8))
		return
	# второй конец
	var a: Dictionary = rope_anchor
	var b := aim
	var mid_world: Vector3 = (a["world"] + b["world"]) * 0.5
	var mid_cell := Vector2i(floori(mid_world.x), floori(mid_world.z))
	if not house.is_inside(mid_cell):
		mid_cell = a["cell"]
	var len := (Vector3(a["world"].x, 0, a["world"].z) - Vector3(b["world"].x, 0, b["world"].z)).length()
	if len < 0.6:
		match_node.hud.show_message("Слишком коротко — растяни нить подальше", Color(1, 0.7, 0.5))
		return
	# привязка к объекту (люстра/шкаф/ТВ/ковёр) — по любому из концов
	var link: Dictionary = {}
	var trap_id := "rope_trip"
	for endp in [a, b]:
		if not endp["attach"].is_empty():
			link = endp["attach"].duplicate()
			trap_id = "rope_link"
			break
	place_wire = {"a": a["world"], "b": b["world"]}
	rope_anchor = {}
	_begin_place(trap_id, "rope", mid_cell, link, false, place_wire)

func _update_rope_preview(aim: Dictionary) -> void:
	ghost.visible = false
	if rope_anchor.is_empty():
		wire_prev.visible = false
		anchor_mk.visible = aim["ok"]
		if aim["ok"]:
			anchor_mk.position = aim["world"]
			_mark_color(anchor_mk, Color(0.4, 1, 0.5))
		match_node.hud.show_context("Растяжка — ЛКМ: первый конец",
			"привяжи к люстре/шкафу/ковру или просто протяни через проход", aim["ok"])
		return
	# тянем нить от закреплённого конца к прицелу
	anchor_mk.visible = true
	anchor_mk.position = rope_anchor["world"]
	_mark_color(anchor_mk, Color(1, 0.85, 0.4))
	var attach: Dictionary = aim["attach"]
	var col := Color(1.0, 0.82, 0.4) if not attach.is_empty() else Color(0.4, 1, 0.6)
	if not aim["ok"]:
		col = Color(1, 0.35, 0.35)
	wire_prev.visible = true
	_orient_along(wire_prev, rope_anchor["world"], aim["world"], col)
	if not attach.is_empty():
		match_node.hud.show_context("Привязать: " + _link_name(attach) + "!",
			"второй клик — закрепить нить", true)
	elif aim["ok"]:
		match_node.hud.show_context("Тяни нить · ЛКМ — закрепить второй конец",
			"пересечёт проход — Санта споткнётся", true)
	else:
		match_node.hud.show_context("Целься внутрь дома", "", false)

# ---------------------------------------------------------------- ВАРИАНТЫ

func _variant_for(item: String, cell: Vector2i) -> Dictionary:
	if not house.is_inside(cell):
		return {}
	var on_carpet: bool = house.carpet_cells.has(cell)
	var tiles := house.room_tag(cell) == "плитка"
	var lk := house.find_linkable(cell)
	var trap_id := ""
	var extra := ""
	var link: Dictionary = {}
	match item:
		"plate":
			if not lk.is_empty():
				trap_id = "plate_link"; extra = " → " + _link_name(lk); link = lk
			elif on_carpet:
				trap_id = "plate_link"; extra = " → ВЫДЕРНУТЬ КОВЁР"; link = {"type": "rug", "cell": cell}
			else:
				trap_id = "plate"
		"bucket":
			if house.is_doorway_cell(cell):
				trap_id = "bucket_door"; extra = " (над дверью)"
			else:
				return {}   # ведро только над дверью
		"glue":
			if house.is_doorway_cell(cell):
				trap_id = "glue_door"; extra = " + ПОРОГ!"
			else:
				trap_id = "glue"
		"oil":
			trap_id = "oil_tiles" if tiles else "oil"
			extra = " + ПЛИТКА!" if tiles else ""
		"firecracker":
			var p: Dictionary = house.prop_at.get(cell, {})
			if p.get("type", "") == "fireplace":
				trap_id = "firecracker_chimney"; extra = " → дымоход!"
			else:
				trap_id = "firecracker"
		_:
			trap_id = item
	var hidden: bool = on_carpet and item in Defs.CARPET_OK and link.is_empty()
	return {"trap_id": trap_id, "extra": extra, "link": link, "hidden": hidden}

func _link_name(lk: Dictionary) -> String:
	match lk["type"]:
		"chandelier":
			return "ЛЮСТРА"
		"tv":
			return "ТВ"
		"rug":
			return "КОВЁР"
		"shelf":
			var sh: Dictionary = lk.get("shelf", {})
			return "ХОЛОДИЛЬНИК" if sh.get("type", "") == "fridge" else "ШКАФ"
	return "ОБЪЕКТ"

# ---------------------------------------------------------------- УСТАНОВКА + QTE

func _begin_place(trap_id: String, item_id: String, cell: Vector2i, link: Dictionary, hidden: bool, wire: Dictionary) -> void:
	placing = true
	place_cell = cell
	place_trap_id = trap_id
	place_item_id = item_id
	place_hidden = hidden
	place_link = link.duplicate()
	place_wire = wire
	if not place_link.is_empty():
		place_link["trigger_cell"] = cell
	place_total = float(Defs.ITEMS[item_id]["place_time"]) * kid.place_mult
	place_t = 0.0
	qte_locked = false
	qte_value = 0.0
	qte_quality = -1.0
	kid.frozen = true
	kid.play_place_anim()
	ghost.visible = false
	wire_prev.visible = false
	anchor_mk.visible = false
	_update_qte_title()

func _update_qte_title() -> void:
	var nm: String = Defs.TRAPS[place_trap_id]["name"]
	if place_link.is_empty():
		match_node.hud.show_qte(nm)
	else:
		match_node.hud.show_qte("%s · задержка %.1fс (колесо!)" % [nm, float(Defs.LINK_DELAYS[delay_i])])

func _cancel_place() -> void:
	placing = false
	place_link = {}
	place_wire = {}
	kid.frozen = false
	kid.cancel_place_anim()
	match_node.hud.hide_qte()

func _process_placing(delta: float) -> void:
	place_t += delta
	if not qte_locked:
		qte_value = 0.5 + 0.5 * sin(place_t * 5.5)
	match_node.hud.update_qte(place_t / place_total, qte_value, qte_locked)
	if place_t >= place_total:
		placing = false
		kid.frozen = false
		kid.cancel_place_anim()
		match_node.hud.hide_qte()
		var q := qte_quality if qte_quality > 0.0 else randf_range(0.6, 0.85)
		var opts := {}
		if not place_link.is_empty():
			opts["link"] = place_link
			opts["delay"] = float(Defs.LINK_DELAYS[delay_i])
		if not place_wire.is_empty():
			opts["wire"] = place_wire
		match_node.place_trap(place_trap_id, place_item_id, place_cell, q, place_hidden, opts)
		place_link = {}
		place_wire = {}
		aimed_cell = Vector2i(-99, -99)

# ---------------------------------------------------------------- ПРИЗРАКИ/СЕТКА/ХИНТЫ

func _make_ghost() -> void:
	ghost = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.45
	cyl.bottom_radius = 0.45
	cyl.height = 0.02
	ghost.mesh = cyl
	ghost.material_override = _unshaded(Color(0.3, 1.0, 0.4, 0.4))
	ghost.visible = false
	match_node.add_child(ghost)
	wire_prev = MeshInstance3D.new()
	var wc := CylinderMesh.new()
	wc.top_radius = 0.025
	wc.bottom_radius = 0.025
	wc.height = 1.0
	wire_prev.mesh = wc
	wire_prev.material_override = _unshaded(Color(0.4, 1, 0.6, 0.85))
	wire_prev.visible = false
	match_node.add_child(wire_prev)
	anchor_mk = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.09
	sm.height = 0.18
	anchor_mk.mesh = sm
	anchor_mk.material_override = _unshaded(Color(1, 0.85, 0.4, 0.95))
	anchor_mk.visible = false
	match_node.add_child(anchor_mk)

func _unshaded(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m

func _mark_color(node: MeshInstance3D, c: Color) -> void:
	(node.material_override as StandardMaterial3D).albedo_color = c

## Ставит цилиндр-нить между точками a и b (ось Y меша вытягивается по вектору).
func _orient_along(node: MeshInstance3D, a: Vector3, b: Vector3, col: Color) -> void:
	var mid := (a + b) * 0.5
	var v := b - a
	var l := v.length()
	if l < 0.01:
		node.visible = false
		return
	var yd := v / l
	var xd := yd.cross(Vector3.UP)
	if xd.length() < 0.01:
		xd = Vector3.RIGHT
	xd = xd.normalized()
	var zd := xd.cross(yd)
	node.transform = Transform3D(Basis(xd, yd * l, zd), mid)
	_mark_color(node, col)

func _make_grid() -> void:
	for i in GRID_N * GRID_N:
		var q := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(0.9, 0.9)
		q.mesh = pm
		q.material_override = _unshaded(Color(1, 1, 1, 0.06))
		q.visible = false
		match_node.add_child(q)
		grid_quads.append(q)

func _make_hints() -> void:
	for cell in house.chandeliers:
		if house.chandeliers[cell].has_meta("crashed"):
			continue
		_add_hint(Defs.cell_to_world(cell) + Vector3(0, 1.95, 0), "ЛЮСТРА", "тяни к ней растяжку → рухнет")
	for sh in house.shelves:
		if sh["node"].has_meta("toppled"):
			continue
		var c: Vector2i = sh["cell"]
		var is_fridge: bool = sh.get("type", "") == "fridge"
		_add_hint(Defs.cell_to_world(c) + Vector3(0, 2.2, 0),
			"ХОЛОДИЛЬНИК" if is_fridge else "ШКАФ",
			"молоко: скользко + прячет" if is_fridge else "плита/растяжка → завалится")
	for tv in house.tvs:
		if tv["node"].has_meta("sparked"):
			continue
		_add_hint(Defs.cell_to_world(tv["cell"]) + Vector3(0, 1.5, 0), "ТВ", "триггер → электрошок")
	for cn in house.carpet_nodes:
		var rect: Rect2i = cn["rect"]
		var mid := Vector3(rect.position.x + rect.size.x * 0.5, 0.5, rect.position.y + rect.size.y * 0.5)
		_add_hint(mid, "КОВЁР", "растяжка/плита → выдернуть")
	for cell in house.prop_at:
		if house.prop_at[cell]["type"] == "fireplace":
			_add_hint(Defs.cell_to_world(cell) + Vector3(0, 2.7, 0), "КАМИН", "петарда → блок дымохода")

func _add_hint(pos: Vector3, title: String, sub: String) -> void:
	var l := Label3D.new()
	l.text = title + "\n" + sub
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 40
	l.outline_size = 10
	l.pixel_size = 0.004
	l.modulate = Color(1.0, 0.85, 0.35)
	l.outline_modulate = Color(0.15, 0.1, 0.0, 0.85)
	l.position = pos
	match_node.add_child(l)
	hint_nodes.append(l)
