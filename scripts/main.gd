extends Node
## Точка входа: меню ↔ матч. Env SANTA_TEST=1 — headless-смоук-тест (авто-матч и выход).

var menu: Menu
var backdrop: Node3D
var current_match: Match

func _ready() -> void:
	if OS.get_environment("SANTA_TEST") != "":
		_run_smoke_test()
		return
	if OS.get_environment("SANTA_SHOT") != "":
		_run_shot_test()
		return
	if OS.get_environment("CUSTOM_SHOWCASE") != "":
		_run_showcase()
		return
	if OS.get_environment("WATER_SHOT") != "":
		_run_water_shot()
		return
	if OS.get_environment("ROPE_SHOT") != "":
		_run_rope_shot()
		return
	_show_menu()

## Рендер верёвки-связки на чистой сцене: провисает дугой между двумя предметами.
func _run_rope_shot() -> void:
	var dir: String = OS.get_environment("ROPE_SHOT")
	var root := Node3D.new()
	add_child(root)
	HouseBuilder.build_night_env(root)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12, 12)
	floor.mesh = pm
	floor.material_override = Defs.wood_mat(Color(0.72, 0.55, 0.38))
	root.add_child(floor)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-45, 25, 0)
	key.light_energy = 1.2
	root.add_child(key)
	# два «предмета»: ведро слева на полу, люстра справа вверху; верёвка между ними
	var bucket := ModelLib.place(root, "c:bucket", Vector3(-1.2, 0, 0), Vector3(0.5, 0.45, 0.5))
	var mtrap := ModelLib.place(root, "c:mousetrap", Vector3(1.4, 0, 0.4), Vector3(0.5, 0.3, 0.5))
	var a := Vector3(-1.2, 0.45, 0)   # ручка ведра
	var b := Vector3(1.4, 0.12, 0.4)  # мышеловка на полу
	PropFX.build_rope(root, a, b, 0.3)
	# ещё одна — круто провисающая, повыше
	PropFX.build_rope(root, Vector3(-1.2, 0.5, 0), Vector3(0.2, 2.2, -1.5), 0.5)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(0, 1.4, 3.4)
	cam.look_at(Vector3(0, 0.7, 0))
	await get_tree().create_timer(0.8).timeout
	await _shot(dir + "/rope_link.png")
	get_tree().quit(0)

## Прицельный тест водяного ведра на ЧИСТОЙ сцене: налив → слив → лужа.
func _run_water_shot() -> void:
	var dir: String = OS.get_environment("WATER_SHOT")
	var root := Node3D.new()
	add_child(root)
	HouseBuilder.build_night_env(root)
	# пол под ведром
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(10, 10)
	floor.mesh = pm
	floor.material_override = Defs.wood_mat(Color(0.72, 0.55, 0.38))
	root.add_child(floor)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(0, 1.6, 2.6)
	cam.look_at(Vector3(0, 1.7, 0))
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-45, 25, 0)
	key.light_energy = 1.2
	root.add_child(key)
	# ведро на высоте 2.35 (как над дверью)
	var trap := Trap.new()
	root.add_child(trap)
	trap.add_to_group("traps")
	trap.setup("bucket_door", Vector2i(0, 0), 0.95, false, 1.0, {"pos": Vector3(0, 0, 0)})
	await get_tree().create_timer(2.6).timeout   # дождались налива
	await _shot(dir + "/water_full.png")
	trap.force_trigger()
	await get_tree().create_timer(0.4).timeout
	await _shot(dir + "/water_pour.png")
	cam.position = Vector3(0, 1.3, 2.6)
	cam.look_at(Vector3(0, 0.2, 0))
	await get_tree().create_timer(1.6).timeout
	await _shot(dir + "/water_puddle.png")
	get_tree().quit(0)

## Витрина: все custom-модели в ряд под нашим контуром+светом — оценить стиль.
func _run_showcase() -> void:
	var dir: String = OS.get_environment("CUSTOM_SHOWCASE")
	var root := Node3D.new()
	add_child(root)
	HouseBuilder.build_night_env(root)
	var cam := Camera3D.new()
	root.add_child(cam)
	var ids := ["saw", "mousetrap", "rope_coil", "banana_peel", "firecracker", "marbles",
		"pressure_plate", "perfume", "wire_spool", "screwdriver", "ladder", "suitcase", "jewel_ring",
		"bucket", "cookie_plate", "garland_shock", "iron", "tape", "weight"]
	var x := 0.0
	var placed: Array = []
	for id in ids:
		var m := ModelLib.place(root, "c:" + id, Vector3(x, 0, 0), Vector3(0.9, 0.9, 0.9), 0.0, false)
		if m != null:
			placed.append(id)
			var lbl := Label3D.new()
			lbl.text = id
			lbl.font_size = 48
			lbl.pixel_size = 0.003
			lbl.position = Vector3(x, -0.15, 0)
			lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			root.add_child(lbl)
		x += 1.2
	print("SHOWCASE: загружено %d/%d — %s" % [placed.size(), ids.size(), ", ".join(placed)])
	var total := (placed.size() - 1) * 1.2
	cam.position = Vector3(total * 0.5, 1.6, total * 0.75 + 3.0)
	cam.look_at(Vector3(total * 0.5, 0.4, 0))
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-45, 25, 0)
	key.light_energy = 1.2
	root.add_child(key)
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir + "/showcase.png")
	print("SHOT: " + dir + "/showcase.png")
	# крупный план первых трёх
	cam.position = Vector3(1.2, 1.0, 3.0)
	cam.look_at(Vector3(1.2, 0.4, 0))
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir + "/showcase_close.png")
	print("SHOT: " + dir + "/showcase_close.png")
	get_tree().quit(0)

## Автоскриншоты для визуальной проверки: меню, подготовка, режим ловушек, грабитель.
func _run_shot_test() -> void:
	var dir: String = OS.get_environment("SANTA_SHOT")
	backdrop = Menu.Backdrop.new()
	add_child(backdrop)
	menu = Menu.new()
	add_child(menu)
	await get_tree().create_timer(1.0).timeout
	await _shot(dir + "/shot_menu.png")
	menu._show_setup()
	await get_tree().create_timer(0.4).timeout
	await _shot(dir + "/shot_setup.png")
	menu.queue_free()
	backdrop.queue_free()
	var m := Match.new()
	add_child(m)
	var shot_loc := OS.get_environment("SANTA_SHOT_LOC")
	if shot_loc == "":
		shot_loc = "cabin"
	m.start({"char_id": "speedy", "loc_id": shot_loc, "robber_mode": false})
	m.kid.pitch = -0.25
	await get_tree().create_timer(1.0).timeout
	await _shot(dir + "/shot_prep.png")
	m.trap_mode.activate()
	# хотбар + призрак ловушки на поверхности под прицелом
	m.trap_mode._select(maxi(m.trap_mode.items.find("shards"), 0))
	m.kid.pitch = -0.5
	await get_tree().create_timer(0.5).timeout
	await _shot(dir + "/shot_trapmode.png")
	# растяжка: нить тянется от пола к люстре
	m.kid.global_position = Vector3(5.5, 0.1, 6.5)
	m.kid.yaw = 0.0
	m.kid.pitch = 0.4
	m.trap_mode._select(maxi(m.trap_mode.items.find("rope"), 0))
	m.trap_mode.rope_anchor = {"world": Defs.cell_to_world(Vector2i(5, 6)) + Vector3(0, 0.15, 0),
		"cell": Vector2i(5, 6), "attach": {}}
	await get_tree().create_timer(0.3).timeout
	await _shot(dir + "/shot_rope.png")
	m.trap_mode.rope_anchor = {}
	# подсказки на объектах: смотрим на люстру снизу
	m.kid.global_position = Vector3(5.5, 0.1, 6.5)
	m.kid.yaw = atan2(-(5.5 - 5.5), -(4.5 - 6.5))
	m.kid.pitch = 0.25
	await get_tree().create_timer(0.3).timeout
	await _shot(dir + "/shot_hints.png")
	m.trap_mode.deactivate()
	# гостиная: ёлка
	m.kid.global_position = Vector3(3.5, 0.1, 2.0)
	m.kid.yaw = atan2(-(8.5 - 3.5), -(6.5 - 2.0))
	m.kid.pitch = -0.1
	await get_tree().create_timer(0.3).timeout
	await _shot(dir + "/shot_tree.png")
	m.phase_t = 0.1
	await get_tree().create_timer(7.0).timeout
	m.hud.show_combo(["Масло", "Люстра", "Пожар"], 3, 360, Defs.combo_tier(3), "ПРЕИСПОДНЯЯ")
	m.hud.update_combo_timer(0.7)
	await get_tree().create_timer(0.4).timeout
	await _shot(dir + "/shot_combo.png")
	m.queue_free()
	await get_tree().process_frame
	# --- режим грабителя: чутьё наживы
	var sm := Match.new()
	add_child(sm)
	sm.start({"char_id": "speedy", "loc_id": "cabin", "robber_mode": true})
	sm.phase_t = 0.1
	await get_tree().create_timer(1.0).timeout
	var msp: Vector2i = sm.house.loc["kid_spawn"]
	sm.robber.global_position = Defs.cell_to_world(msp) + Vector3(0, 0.1, 0)
	sm.robber.pitch = -0.35
	sm.robber.yaw = PI * 0.25
	await get_tree().create_timer(0.2).timeout
	sm._on_loot_sense()
	await get_tree().create_timer(0.6).timeout
	await _shot(dir + "/shot_loot_sense.png")
	get_tree().quit(0)

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("SHOT: " + path)

func _show_menu() -> void:
	if is_instance_valid(current_match):
		current_match.queue_free()
		current_match = null
	backdrop = Menu.Backdrop.new()
	add_child(backdrop)
	menu = Menu.new()
	add_child(menu)
	menu.start_match.connect(_start_match)

func _start_match(config: Dictionary) -> void:
	if is_instance_valid(menu):
		menu.queue_free()
		menu = null
	if is_instance_valid(backdrop):
		backdrop.queue_free()
		backdrop = null
	current_match = Match.new()
	add_child(current_match)
	current_match.start(config)
	current_match.finished.connect(_show_menu)

# ---------------------------------------------------------------- СМОУК-ТЕСТ

func _run_smoke_test() -> void:
	print("SANTA_TEST: старт")
	# меню должно строиться без ошибок
	var test_menu := Menu.new()
	add_child(test_menu)
	await get_tree().process_frame
	test_menu.queue_free()
	await get_tree().process_frame
	Engine.time_scale = 5.0
	for loc_id in Defs.LOCATIONS:
		var m := Match.new()
		add_child(m)
		m.start({"char_id": "brains", "loc_id": loc_id, "robber_mode": false, "seed": 42})
		# насыпаем себе снаряжения, как будто обыскали дом
		for it in ["oil", "net", "firecracker", "banana", "marbles", "plate", "perfume", "garland_shock", "bucket", "cookie"]:
			m.loadout[it] = int(m.loadout.get(it, 0)) + 1
		# мелкий закрывает все окна в подготовку
		var closed := 0
		for i in m.house.entries.size():
			if m.house.entries[i]["type"] != "door":
				m.house.close_entry(i)
				closed += 1
		# обыск мебели мелким: собираем лут
		var found := 0
		for s in m.house.searchables:
			if not s["jewel"]:
				m.kid_action_done(m.kid, {"type": "search", "spot": s})
				if s["item"] != "":
					found += 1
		# ставим ловушки по свободным клеткам вокруг спавна
		var spawn: Vector2i = m.house.loc["kid_spawn"]
		var to_place := ["shards", "net", "oil", "marbles", "banana", "perfume", "firecracker", "oil"]
		var placed_cells: Array = []
		var r := 1
		while not to_place.is_empty() and r < 8:
			for dx in range(-r, r + 1):
				for dz in range(-r, r + 1):
					if to_place.is_empty():
						break
					var c := spawn + Vector2i(dx, dz)
					if m.house.is_free_cell(c) and not m.traps.has(c):
						var item: String = to_place.pop_front()
						m.place_trap(item, item, c, 0.9, false)
						if m.traps.has(c):
							placed_cells.append(c)
			r += 1
		# связанная ловушка: плита у люстры
		var ch_cell: Vector2i = Defs.LOCATIONS[loc_id]["props"][0]["cell"]
		var trig := ch_cell + Vector2i(0, 1)
		if m.house.is_free_cell(trig) and not m.traps.has(trig):
			m.place_trap("plate_link", "plate", trig, 0.9, false,
				{"link": {"type": "chandelier", "cell": ch_cell, "trigger_cell": trig}, "delay": 1.5})
			placed_cells.append(trig)
		# ПРОВОД: связываем первую свободную ловушку со ВТОРОЙ люстрой на расстоянии
		var wired := false
		var ch2 := Vector2i(-99, -99)
		for c in m.house.chandeliers:
			if c != ch_cell:
				ch2 = c
		if ch2 != Vector2i(-99, -99):
			for c in placed_cells:
				var t = m.traps.get(c)
				if t != null and t.link.is_empty() and not t.def.get("bait", false):
					t.attach_link({"type": "chandelier", "cell": ch2}, 0.5)
					wired = true
					break
		# БЮДЖЕТ: пробуем поставить сверх лимита
		m.loadout["shards"] = 30
		for dx in range(-9, 10):
			for dz in range(-9, 10):
				var c := spawn + Vector2i(dx, dz)
				if m.house.is_free_cell(c) and not m.traps.has(c):
					m.place_trap("shards", "shards", c, 0.9, false)
		var over_budget: bool = m.active_trap_count() > Defs.TRAP_BUDGET
		# фаза ограбления
		m.phase_t = 0.5
		await get_tree().create_timer(2.0).timeout
		# грабитель взламывает первое закрытое окно
		for i in m.house.entries.size():
			if m.house.entry_states[i]["closed"]:
				m.robber_action_done(m.robber, {"type": "break", "index": i})
				break
		# грабитель обыскивает мебель, пока не найдёт драгоценность
		var jewels_found := 0
		for s in m.house.searchables:
			if s["jewel"] and not s["searched"] and m.robber.carrying == 0:
				m.robber_action_done(m.robber, {"type": "search", "spot": s})
				jewels_found += 1
				break
		# выносит её за периметр
		if m.robber.carrying > 0:
			m.robber.global_position = Vector3(-6, 0.1, -6)
			await get_tree().create_timer(1.0).timeout
		# ДРУЖЕСКИЙ ОГОНЬ: мелкий наступает на «ничью» ловушку
		var ff_ok := false
		for cell in placed_cells:
			var t = m.traps.get(cell)
			if t != null and is_instance_valid(t) and not t.spent and not t.def.get("bait", false):
				t.placer = null
				m.kid.global_position = Defs.cell_to_world(cell) + Vector3(0, 0.1, 0)
				# стан может быть коротким — ловим его пока действует
				for i in 40:
					await get_tree().process_frame
					if m.kid.trap_stun_t > 0.0:
						ff_ok = true
						break
				m.kid.global_position = Defs.cell_to_world(spawn) + Vector3(0, 0.1, 0)
				break
		# прогоняем грабителя по всем ловушкам
		var fired := 0
		for cell in placed_cells:
			var trap = m.traps.get(cell)
			if trap == null or not is_instance_valid(trap) or trap.spent:
				continue
			m.robber.global_position = Defs.cell_to_world(cell) + Vector3(0, 0.1, 0)
			trap.force_trigger()
			fired += 1
			await get_tree().create_timer(4.0).timeout
		await get_tree().create_timer(10.0).timeout
		var wire_ok: bool = wired and ch2 != Vector2i(-99, -99) and m.house.chandeliers[ch2].has_meta("crashed")
		print("SANTA_TEST: %s — фаза=%d, окон=%d, лута=%d, украдено=%d/%d, ловушек=%d, стиль=%d, провод=%s, свой_огонь=%s, бюджет_ок=%s" % [
			loc_id, m.phase, closed, found, m.stolen_jewels, m.total_jewels, fired, m.style_score,
			str(wire_ok), str(ff_ok), str(not over_budget)])
		if fired == 0:
			push_error("SANTA_TEST: в %s не сработала ни одна ловушка" % loc_id)
		if m.stolen_jewels == 0:
			push_error("SANTA_TEST: кража в %s не засчиталась" % loc_id)
		if closed == 0:
			push_error("SANTA_TEST: в %s нечего закрывать?" % loc_id)
		if wired and not wire_ok:
			push_error("SANTA_TEST: провод-связка в %s не уронила люстру" % loc_id)
		if not ff_ok:
			push_error("SANTA_TEST: дружеский огонь в %s не сработал" % loc_id)
		if over_budget:
			push_error("SANTA_TEST: бюджет ловушек в %s не соблюдён" % loc_id)
		m.queue_free()
		await get_tree().process_frame
	Engine.time_scale = 1.0
	print("SANTA_TEST: OK")
	get_tree().quit(0)
