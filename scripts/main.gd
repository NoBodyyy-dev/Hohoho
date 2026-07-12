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
	_show_menu()

## Автоскриншоты для визуальной проверки: меню, подготовка, Санта в деле.
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
	m.start({"char_id": "speedy", "loc_id": shot_loc,
		"loadout": {"shards": 2, "rope": 1, "oil": 1, "firecracker": 1, "cookie": 1}, "santa_mode": false})
	m.kid.pitch = -0.25
	await get_tree().create_timer(1.0).timeout
	await _shot(dir + "/shot_prep.png")
	m.trap_mode.activate()
	# хотбар + призрак ловушки на полу
	m.trap_mode._select(maxi(m.trap_mode.items.find("shards"), 0))
	m.kid.pitch = -0.5
	await get_tree().create_timer(0.5).timeout
	await _shot(dir + "/shot_trapmode.png")
	# растяжка: нить тянется от пола к люстре (клетка 5,4)
	m.kid.global_position = Vector3(5.5, 0.1, 6.5)
	m.kid.yaw = 0.0
	m.kid.pitch = 0.4
	m.trap_mode._select(maxi(m.trap_mode.items.find("rope"), 0))
	m.trap_mode.rope_anchor = {"world": Defs.cell_to_world(Vector2i(5, 6)) + Vector3(0, 0.15, 0),
		"cell": Vector2i(5, 6), "attach": {}}
	await get_tree().create_timer(0.3).timeout
	await _shot(dir + "/shot_rope.png")
	m.trap_mode.rope_anchor = {}
	# подсказки на объектах: смотрим на люстру (клетка 5,4) снизу
	m.kid.global_position = Vector3(5.5, 0.1, 6.5)
	m.kid.yaw = atan2(-(5.5 - 5.5), -(4.5 - 6.5))
	m.kid.pitch = 0.25
	await get_tree().create_timer(0.3).timeout
	await _shot(dir + "/shot_hints.png")
	# новые объекты: ТВ (клетки 4-5,7) и ковёр (4,3) из угла гостиной
	m.kid.global_position = Vector3(2.0, 0.1, 4.0)
	m.kid.yaw = atan2(-(4.5 - 2.0), -(6.0 - 4.0))
	m.kid.pitch = 0.05
	await get_tree().create_timer(0.3).timeout
	await _shot(dir + "/shot_objects.png")
	m.trap_mode.deactivate()
	# гостиная: ёлка с подарками
	m.kid.global_position = Vector3(3.5, 0.1, 2.0)
	m.kid.yaw = atan2(-(8.5 - 3.5), -(6.5 - 2.0))
	m.kid.pitch = -0.1
	await get_tree().create_timer(0.3).timeout
	await _shot(dir + "/shot_tree.png")
	# камин с носками
	m.kid.global_position = Vector3(6.5, 0.1, 2.5)
	m.kid.yaw = atan2(-(0.5 - 6.5), 0.0)
	m.kid.pitch = 0.05
	await get_tree().create_timer(0.3).timeout
	await _shot(dir + "/shot_fireplace.png")
	m.kid.pitch = 0.0
	m.kid.yaw = PI * 0.75
	m.phase_t = 0.1
	await get_tree().create_timer(7.0).timeout
	# показать виджет ХАОС-КОМБО для скриншота
	m.hud.show_combo(["Масло", "Люстра", "Пожар"], 3, 360, Defs.combo_tier(3), "ПРЕИСПОДНЯЯ")
	m.hud.update_combo_timer(0.7)
	await get_tree().create_timer(0.4).timeout
	await _shot(dir + "/shot_combo.png")
	m.queue_free()
	await get_tree().process_frame
	# --- режим Санты-игрока: чуйка на подарки (примерные зоны)
	var sm := Match.new()
	add_child(sm)
	sm.start({"char_id": "speedy", "loc_id": "cabin", "santa_mode": true, "loadout": {}})
	sm.phase_t = 0.1
	await get_tree().create_timer(1.0).timeout
	# ставим Санту внутрь дома, чтобы увидеть примерные зоны на полу
	var msp: Vector2i = sm.house.loc["kid_spawn"]
	sm.santa.global_position = Defs.cell_to_world(msp) + Vector3(0, 0.1, 0)
	sm.santa.pitch = -0.35
	sm.santa.yaw = PI * 0.25
	await get_tree().create_timer(0.2).timeout
	sm._on_present_sense()
	await get_tree().create_timer(0.6).timeout
	await _shot(dir + "/shot_santa_sense.png")
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
		m.start({
			"char_id": "brains",
			"loc_id": loc_id,
			"loadout": {"shards": 1, "rope": 1, "oil": 2, "net": 1, "firecracker": 1,
				"banana": 1, "marbles": 1, "plate": 1, "perfume": 1, "garland_shock": 1, "bucket": 1},
			"santa_mode": false,
		})
		m.phase_t = 0.5
		var spots: Array = Defs.LOCATIONS[loc_id]["present_spots"]
		# ставим ловушки прямо на точки подарков — Санта обязан в них влезть
		m.place_trap("shards", "shards", spots[0], 0.9, false)
		m.place_trap("net", "net", spots[1], 0.65, false)
		m.place_trap("oil", "oil", spots[2], 0.9, false)
		# новые механики: банан+шарики рядом (пинг-понг), духи, петарда+масло
		m.place_trap("marbles", "marbles", spots[3], 0.9, false)
		m.place_trap("banana", "banana", spots[3] + Vector2i(1, 0), 0.9, false)
		m.place_trap("perfume", "perfume", spots[4], 0.9, false)
		m.place_trap("oil", "oil", spots[5] + Vector2i(1, 0), 0.9, false)
		m.place_trap("firecracker", "firecracker", spots[5], 0.9, false)
		# связанная ловушка: плита у люстры с задержкой 1.5с
		var ch_cell: Vector2i = Defs.LOCATIONS[loc_id]["props"][0]["cell"]
		var trig := ch_cell + Vector2i(0, 1)
		if m.house.is_free_cell(trig):
			m.place_trap("plate_link", "plate", trig, 0.9, false,
				{"link": {"type": "chandelier", "cell": ch_cell, "trigger_cell": trig}, "delay": 1.5})
		# новые объекты: ковёр-выдергушка, электрошок-ТВ, холодильник-молоко
		if not m.house.carpet_nodes.is_empty():
			var rc: Rect2i = m.house.carpet_nodes[0]["rect"]
			var rug_cell := rc.position + Vector2i(0, 0)
			if m.house.is_free_cell(rug_cell) and not m.traps.has(rug_cell):
				m.place_trap("plate_link", "plate", rug_cell, 0.9, false,
					{"link": {"type": "rug", "cell": rug_cell}, "delay": 0.0})
		if not m.house.tvs.is_empty():
			var tv_cell: Vector2i = m.house.tvs[0]["cell"]
			var tv_trig := tv_cell + Vector2i(0, 1)
			if m.house.is_free_cell(tv_trig) and not m.traps.has(tv_trig):
				m.place_trap("plate_link", "plate", tv_trig, 0.9, false,
					{"link": {"type": "tv", "cell": tv_cell, "tv": m.house.tvs[0]}, "delay": 0.5})
		for sh in m.house.shelves:
			if sh.get("type", "") == "fridge":
				var fr_trig: Vector2i = Vector2i(sh["cell"]) + Vector2i(0, 1)
				if m.house.is_free_cell(fr_trig) and not m.traps.has(fr_trig):
					m.place_trap("plate_link", "plate", fr_trig, 0.9, false,
						{"link": {"type": "shelf", "cell": sh["cell"], "shelf": sh, "trigger_cell": fr_trig}, "delay": 0.0})
				break
		# без бота ловушки не наступятся сами — подводим Санту и дёргаем принудительно
		await get_tree().create_timer(5.0).timeout
		var fired := 0
		for cell in m.traps.keys().duplicate():
			var trap = m.traps.get(cell)
			if trap == null or not is_instance_valid(trap) or trap.spent:
				continue
			m.santa.global_position = Defs.cell_to_world(cell) + Vector3(0, 0.1, 0)
			trap.force_trigger()
			fired += 1
			await get_tree().create_timer(4.0).timeout
		await get_tree().create_timer(10.0).timeout
		print("SANTA_TEST: %s — фаза=%d, сработало=%d, стан=%.1f, стиль=%d" % [
			loc_id, m.phase, fired, m.santa.stun_t, m.style_score])
		if fired == 0:
			push_error("SANTA_TEST: в %s не сработала ни одна ловушка" % loc_id)
		m.queue_free()
		await get_tree().process_frame
	Engine.time_scale = 1.0
	print("SANTA_TEST: OK")
	get_tree().quit(0)
