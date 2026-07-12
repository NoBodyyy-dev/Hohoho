class_name TrapMode
extends Node
## Режим ловушек (F) от первого лица. Предмет выбираешь ХОТБАРОМ снизу (цифры 1-9 или
## колесо). Обычные ловушки — призрак на клетке + клик. Растяжка/верёвка — ДВЕ ТОЧКИ:
## клик ставит первый конец, тянешь нить, второй клик закрепляет; концы привязываются
## к люстре/шкафу/ТВ/ковру. После установки — QTE на качество.

const RANGE := 4.5
const ROPE_ITEMS := ["rope"]   # предметы с установкой «две точки»

var match_node: Node
var house: HouseBuilder
var kid: Kid

var active := false
var aimed_cell := Vector2i(-99, -99)
var items: Array = []      # item_id в порядке хотбара
var sel_i := 0
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
var place_pos := Vector3.ZERO
var place_normal := Vector3.UP
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
				elif wire_from_trap != null:
					wire_from_trap = null
					match_node.hud.show_message("Провод смотан обратно", Color(1, 0.8, 0.6))
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
	elif item == "wire":
		_wire_click()
	else:
		_place_single(item)

## Подходит ли поверхность предмету: пол/столешница — всем, стены/потолок — списку.
func _surface_ok(item: String, aim: Dictionary) -> bool:
	return aim["normal"].y >= 0.6 or item in Defs.ANY_SURFACE

func _select(idx: int) -> void:
	if items.is_empty():
		return
	sel_i = clampi(idx, 0, items.size() - 1)
	rope_anchor = {}
	wire_from_trap = null
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
	wire_from_trap = null
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

## Точка прицела: ghost-превью на поверхности под прицелом (рейкаст физики).
## Возвращает: ok, cell, world (точка на поверхности), normal, reason, attach.
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
				"normal": Vector3.UP, "reason": "", "attach": {"type": "chandelier", "cell": ch_cell}}
	var space := kid.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * (RANGE + 3.0))
	query.exclude = [kid.get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return {"ok": false, "cell": Vector2i(-99, -99), "world": Vector3.ZERO,
			"normal": Vector3.UP, "reason": "слишком далеко", "attach": {}}
	var pos: Vector3 = hit["position"]
	var normal: Vector3 = hit["normal"]
	var cell := Defs.world_to_cell(pos)
	var reason := ""
	var ok := true
	if pos.distance_to(kid.global_position) > RANGE:
		ok = false
		reason = "слишком далеко"
	elif not house.is_inside(cell):
		ok = false
		reason = "целься внутрь дома"
	var attach: Dictionary = {}
	var world := pos + normal * 0.02
	if ok:
		var lk := house.find_linkable(cell)
		if not lk.is_empty():
			attach = lk
			# конец нити липнет к самому объекту (люстра/шкаф/ТВ)
			var h := 2.2 if lk["type"] == "chandelier" else 1.2
			world = Defs.cell_to_world(lk["cell"]) + Vector3(0, h, 0)
		elif house.carpet_cells.has(cell):
			attach = {"type": "rug", "cell": cell}
	return {"ok": ok, "cell": cell, "world": world, "normal": normal, "reason": reason, "attach": attach}

func _cell_valid(aim: Dictionary) -> bool:
	var cell: Vector2i = aim["cell"]
	if match_node.traps.has(cell):
		return false
	if house.is_free_cell(cell):
		return true
	# на мебель можно, если попал в её ВЕРХНЮЮ поверхность
	return house.furniture_cells.has(cell) and aim["world"].y > 0.25

# ---------------------------------------------------------------- PROCESS

func _process(_delta: float) -> void:
	if not active:
		return
	if placing:
		_process_placing(_delta)
		return
	var aim := _aim_point()
	var item := _current_item()
	if item in ROPE_ITEMS:
		_update_rope_preview(aim)
	elif item == "wire":
		_update_wire_link_preview(aim)
	else:
		_update_single_preview(item, aim)

# ---------------------------------------------------------------- ОБЫЧНАЯ ЛОВУШКА

func _update_single_preview(item: String, aim: Dictionary) -> void:
	wire_prev.visible = false
	anchor_mk.visible = false
	var cell: Vector2i = aim["cell"]
	var v := _variant_for(item, cell)
	var ok: bool = aim["ok"] and _cell_valid(aim) and _surface_ok(item, aim) and not v.is_empty()
	ghost.visible = aim["cell"] != Vector2i(-99, -99)
	ghost.position = aim["world"] if ghost.visible else Vector3.ZERO
	_align_to_normal(ghost, aim["normal"])
	var gmat: StandardMaterial3D = ghost.material_override
	gmat.albedo_color = Color(0.3, 1.0, 0.4, 0.4) if ok else Color(1.0, 0.3, 0.3, 0.35)
	if ok:
		var extra := str(v.get("extra", ""))
		var fx := Defs.trap_fx(v["trap_id"])
		var sub := fx
		if v.get("hidden", false):
			sub += "  · под ковром" if sub == "" else "  ·  под ковром"
		if aim["normal"].y < 0.6:
			sub += "  · на стене/потолке" if sub == "" else "  ·  на стене/потолке"
		elif aim["world"].y > 0.3:
			sub += "  · на мебели" if sub == "" else "  ·  на мебели"
		match_node.hud.show_context(Defs.ITEMS[item]["name"] + extra, sub, true)
	else:
		var why: String = aim["reason"]
		if why == "" and not _surface_ok(item, aim):
			why = "этот предмет — только на горизонтальное"
		elif why == "" and aim["ok"]:
			why = "здесь уже стоит ловушка" if match_node.traps.has(cell) else "не сюда"
		elif why == "" and v.is_empty():
			why = "этому предмету тут не место"
		match_node.hud.show_context("Сюда нельзя", why, false)

func _align_to_normal(node: Node3D, normal: Vector3) -> void:
	if normal.y >= 0.9:
		node.basis = Basis.IDENTITY
		return
	var x := normal.cross(Vector3.UP)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	node.basis = Basis(x, normal, x.cross(normal))

func _place_single(item: String) -> void:
	var aim := _aim_point()
	var cell: Vector2i = aim["cell"]
	var v := _variant_for(item, cell)
	if not (aim["ok"] and _cell_valid(aim) and _surface_ok(item, aim)) or v.is_empty():
		var why: String = str(aim.get("reason", ""))
		if why == "" and not _surface_ok(item, aim):
			why = "этот предмет — только на горизонтальное"
		match_node.hud.show_message("Сюда не поставить: %s" % why, Color(1, 0.6, 0.5))
		return
	_begin_place(v["trap_id"], item, cell, v.get("link", {}), v.get("hidden", false), {}, aim["world"], aim["normal"])

# ---------------------------------------------------------------- ПРОВОД (связь на расстоянии)

var wire_from_trap: Trap = null

## ЛКМ с проводом: клик 1 — своя ловушка, клик 2 — люстра/шкаф/ТВ/ковёр.
func _wire_click() -> void:
	var aim := _aim_point()
	if wire_from_trap == null:
		var t := _trap_near(aim["world"])
		if t == null:
			match_node.hud.show_message("Целься в СВОЮ ловушку — провод начинается с неё", Color(1, 0.7, 0.5))
			return
		if not t.link.is_empty():
			match_node.hud.show_message("К этой ловушке уже подключён провод", Color(1, 0.7, 0.5))
			return
		wire_from_trap = t
		match_node.hud.show_message("Провод подключён! Теперь кликни на люстру/шкаф/ТВ/ковёр.", Color(0.7, 1, 0.8))
		return
	var attach: Dictionary = aim["attach"]
	if attach.is_empty():
		match_node.hud.show_message("Второй конец — в люстру, шкаф, ТВ или ковёр", Color(1, 0.7, 0.5))
		return
	var target := Defs.cell_to_world(attach["cell"])
	if wire_from_trap.global_position.distance_to(target) > Defs.WIRE_MAX_LEN:
		match_node.hud.show_message("Провод не дотягивается (макс. %d м)" % int(Defs.WIRE_MAX_LEN), Color(1, 0.6, 0.5))
		return
	match_node.loadout["wire"] = int(match_node.loadout["wire"]) - 1
	match_node.hud.set_pockets(match_node.loadout)
	wire_from_trap.attach_link(attach, float(Defs.LINK_DELAYS[delay_i]))
	match_node.hud.show_message("СВЯЗКА ГОТОВА: %s → %s (задержка %.1fс, колесо при установке меняет)" %
		[wire_from_trap.def["name"], _link_name(attach), float(Defs.LINK_DELAYS[delay_i])], Color(0.55, 1.0, 0.9))
	wire_from_trap = null

func _trap_near(pos: Vector3) -> Trap:
	var best: Trap = null
	var best_d := 0.9
	for t in match_node.traps.values():
		if not is_instance_valid(t) or t.spent:
			continue
		var d: float = t.global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = t
	return best

func _update_wire_link_preview(aim: Dictionary) -> void:
	ghost.visible = false
	if wire_from_trap != null and not is_instance_valid(wire_from_trap):
		wire_from_trap = null
	if wire_from_trap == null:
		wire_prev.visible = false
		var t := _trap_near(aim["world"])
		anchor_mk.visible = t != null
		if t != null:
			anchor_mk.position = t.global_position + Vector3(0, 0.25, 0)
			_mark_color(anchor_mk, Color(0.4, 1, 0.5))
			match_node.hud.show_context("Провод — ЛКМ: подключить к «%s»" % t.def["name"],
				"потом кликни на люстру/шкаф/ТВ/ковёр — сработает на расстоянии", true)
		else:
			match_node.hud.show_context("Провод — целься в свою ловушку",
				"он свяжет её с люстрой/шкафом/ТВ/ковром где угодно", false)
		return
	anchor_mk.visible = true
	anchor_mk.position = wire_from_trap.global_position + Vector3(0, 0.25, 0)
	_mark_color(anchor_mk, Color(1, 0.85, 0.4))
	var attach: Dictionary = aim["attach"]
	var col := Color(1.0, 0.82, 0.4) if not attach.is_empty() else Color(1, 0.35, 0.35)
	wire_prev.visible = true
	_orient_along(wire_prev, wire_from_trap.global_position + Vector3(0, 0.2, 0), aim["world"], col)
	if not attach.is_empty():
		match_node.hud.show_context("Подключить: " + _link_name(attach) + "!",
			"клик — и связка на расстоянии готова", true)
	else:
		match_node.hud.show_context("Тяни провод к люстре/шкафу/ТВ/ковру", "", false)

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
	_begin_place(trap_id, "rope", mid_cell, link, false, place_wire, Defs.cell_to_world(mid_cell))

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

func _begin_place(trap_id: String, item_id: String, cell: Vector2i, link: Dictionary, hidden: bool, wire: Dictionary, pos: Vector3, normal := Vector3.UP) -> void:
	placing = true
	place_cell = cell
	place_pos = pos
	place_normal = normal
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
		match_node.hud.show_qte("Ставим: " + nm)
	else:
		match_node.hud.show_qte("Ставим: %s · задержка %.1fс (колесо!)" % [nm, float(Defs.LINK_DELAYS[delay_i])])

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
		var opts := {"pos": place_pos, "normal": place_normal}
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
