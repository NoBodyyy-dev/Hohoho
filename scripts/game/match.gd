class_name Match
extends Node3D
## Один матч: дом, мелкие, грабители, ловушки, фазы, победа/поражение.
## Фазы: ПОДГОТОВКА (грабители снаружи) → ОГРАБЛЕНИЕ → ПОЛИЦИЯ (побег) → КОНЕЦ.

signal finished

enum Phase { PREP, HEIST, POLICE, OVER }

var config: Dictionary
var house: HouseBuilder
var kid: Kid
var robber: Robber
var hud: Hud
var trap_mode: TrapMode

var phase: Phase = Phase.PREP
var phase_t := Defs.PREP_TIME
var match_time := Defs.MATCH_TIME
var last_countdown := -1
var capture := 0.0
var traps: Dictionary = {}     # Vector2i -> Trap
var loadout: Dictionary = {}   # item_id -> count (общая сумка команды)
var robber_mode := false
var total_jewels := 0
var stolen_jewels := 0
var prep_barriers: Array = []  # невидимые стены на входах в фазе подготовки

# ХАОС-КОМБО
var combo_ids: Array = []
var combo_names: Array = []
var combo_timer := 0.0
var combo_mult := 0
var style_score := 0
var combo_named_hit: Dictionary = {}

func start(p_config: Dictionary) -> void:
	config = p_config
	robber_mode = config.get("robber_mode", false)
	loadout = Defs.SUITCASE_LOADOUT.duplicate()

	HouseBuilder.build_night_env(self)
	house = HouseBuilder.new()
	house.build(self, config["loc_id"], config.get("loc_data", {}))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(config.get("seed", randi()))
	house.scatter_loot(Defs.JEWELS_PER_HOUSE, rng)
	total_jewels = Defs.JEWELS_PER_HOUSE

	robber = Robber.new()
	add_child(robber)
	robber.setup(house, robber_mode, self)
	robber.roar_used.connect(_on_roar)
	robber.loot_sense_used.connect(_on_loot_sense)

	if not robber_mode:
		kid = Kid.new()
		add_child(kid)
		kid.setup(config["char_id"])
		kid.match_ref = self
		kid.global_position = Defs.cell_to_world(house.loc["kid_spawn"]) + Vector3(0, 0.1, 0)
		robber.kids_ref = [kid]
		kid.sacked_state_changed.connect(_on_kid_tie_changed)

	hud = Hud.new()
	add_child(hud)
	hud.quit_to_menu.connect(func(): finished.emit())
	hud.set_presents(0, total_jewels)
	hud.set_pockets(loadout)
	if robber_mode:
		hud.hint_label.text = "Грабитель: E (держать) — обыск/взлом | F — чутьё наживы | Q — глаз-алмаз | R — рык | SHIFT — рывок"

	if not robber_mode:
		trap_mode = TrapMode.new()
		add_child(trap_mode)
		trap_mode.setup(self, house, kid)

	_raise_prep_barriers()

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	match_time = float(config.get("match_time", Defs.MATCH_TIME))
	phase = Phase.PREP
	phase_t = float(config.get("prep_time", Defs.PREP_TIME)) if not robber_mode else 10.0
	hud.set_phase("ПОДГОТОВКА — ловушки, окна, обыск!" if not robber_mode else "Обойди дом, выбери, откуда зайдёшь")
	if not robber_mode:
		hud.big_announce("ГРАБИТЕЛИ ЕДУТ!", Color(0.5, 1.0, 0.6))
		hud.show_message("Ставь ловушки, закрывай окна (E), ищи снаряжение в мебели (E)!", Color(1, 0.9, 0.5))

# ---------------------------------------------------------------- ФАЗЫ

func _unhandled_input(event: InputEvent) -> void:
	if phase == Phase.OVER:
		return
	if event.is_action_pressed("pause"):
		if is_instance_valid(trap_mode) and trap_mode.active:
			trap_mode.deactivate()
		else:
			var opened := hud.toggle_pause()
			if kid != null:
				kid.frozen = opened
	if event.is_action_pressed("trap_mode") and kid != null and not kid.is_sacked:
		if not is_instance_valid(hud.pause_panel):
			trap_mode.toggle()

func _process(delta: float) -> void:
	if phase == Phase.OVER:
		return
	phase_t -= delta
	hud.set_timer(phase_t)
	match phase:
		Phase.PREP:
			var s := int(ceil(phase_t))
			if s <= 5 and s != last_countdown and s > 0:
				last_countdown = s
				hud.big_announce(str(s), Color(1, 0.85, 0.4))
			if phase_t <= 0.0:
				_start_heist()
		Phase.HEIST:
			_update_capture(delta)
			_update_robber_status()
			_update_combo(delta)
			_update_deposit()
			if kid != null:
				hud.set_sacked(kid.is_sacked, kid.sack_progress())
			if phase_t <= Defs.ENRAGE_TIME and not robber.enraged and not robber_mode:
				robber.enrage()
				hud.big_announce("ГРАБИТЕЛЬ ОЗВЕРЕЛ!", Color(1, 0.3, 0.25))
			if phase_t <= 0.0:
				_start_police()
		Phase.POLICE:
			_update_capture(delta)
			_update_combo(delta)
			_update_deposit()
			if phase_t <= 0.0:
				_finish_by_loot(true)

func _start_heist() -> void:
	phase = Phase.HEIST
	phase_t = match_time
	_drop_prep_barriers()
	hud.set_phase("ОГРАБЛЕНИЕ — не дай вынести драгоценности!" if not robber_mode else "ИЩИ ДРАГОЦЕННОСТИ! Полиция уже едет")
	hud.big_announce("ОНИ В ДОМЕ!" if not robber_mode else "ВПЕРЁД!", Color(1, 0.45, 0.4))
	hud.show_message("Главная дверь открыта. Заколоченные окна их задержат." if not robber_mode
		else "Дверь открыта. Заколоченные окна придётся ломать (E).", Color(1, 0.6, 0.5))

func _start_police() -> void:
	phase = Phase.POLICE
	phase_t = Defs.POLICE_ESCAPE
	hud.set_phase("ПОЛИЦИЯ! Грабители удирают")
	hud.big_announce("СИРЕНЫ!!!", Color(0.4, 0.6, 1.0))
	hud.show_message("У грабителей %d секунд, чтобы выбежать с добычей!" % int(Defs.POLICE_ESCAPE), Color(0.6, 0.8, 1.0))

## Невидимые стены на входах: в подготовку грабителям в дом нельзя.
func _raise_prep_barriers() -> void:
	for e in house.entries:
		var cell: Vector2i = e["cell"]
		var dirv: Vector2i = e["out_dir"]
		var horizontal: bool = dirv.y != 0
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.2, 3.0, 0.2) if horizontal else Vector3(0.2, 3.0, 1.2)
		col.shape = shape
		body.position = Defs.cell_to_world(cell) + Vector3(dirv.x * 0.5, 1.5, dirv.y * 0.5)
		body.add_child(col)
		add_child(body)
		prep_barriers.append(body)

func _drop_prep_barriers() -> void:
	for b in prep_barriers:
		if is_instance_valid(b):
			b.queue_free()
	prep_barriers = []

# ---------------------------------------------------------------- ИНТЕРАКЦИИ ГРАБИТЕЛЯ

## Что грабитель может сделать здесь удержанием E. {} — ничего.
func robber_action_at(r: Robber) -> Dictionary:
	if phase == Phase.PREP:
		return {}
	# связать мелкого
	for k in r.kids_ref:
		if not k.is_sacked and r.global_position.distance_to(k.global_position) < Defs.INTERACT_RANGE:
			if not r.is_dizzy():
				hud.show_qte("Вяжем мелкого...")
				return {"type": "tie", "kid": k, "t": 0.0, "total": Defs.TIE_TIME}
	# взлом заколоченного окна
	var w := house.window_near(r.global_position, Defs.INTERACT_RANGE + 0.8)
	if not w.is_empty() and w["state"]["closed"]:
		hud.show_qte("Взлом окна... (шумно!)")
		return {"type": "break", "index": w["index"], "t": 0.0, "total": Defs.WINDOW_BREAK_TIME}
	# обыск мебели
	if r.is_inside_house():
		var s := house.searchable_near(r.global_position, Defs.INTERACT_RANGE)
		if not s.is_empty():
			if s["jewel"] and r.carrying > 0:
				hud.show_message("Руки заняты — сначала вынеси добычу!", Color(1, 0.7, 0.4))
				return {}
			hud.show_qte("Обыск...")
			return {"type": "search", "spot": s, "t": 0.0, "total": Defs.SEARCH_TIME}
	return {}

func robber_action_done(r: Robber, act: Dictionary) -> void:
	match act["type"]:
		"tie":
			var k: Kid = act["kid"]
			if not k.is_sacked and r.global_position.distance_to(k.global_position) < Defs.INTERACT_RANGE + 0.6:
				k.put_in_sack()
				r.tied_kid.emit(k)
		"break":
			house.break_entry(act["index"])
			hud.show_message("Окно взломано!", Color(1, 0.6, 0.4))
		"search":
			var s: Dictionary = act["spot"]
			if s["searched"]:
				return
			s["searched"] = true
			_shake_furniture(s["node"])
			if s["jewel"]:
				r.carrying += 1
				r.jewel_grabbed.emit()
				if robber_mode:
					hud.big_announce("ДРАГОЦЕННОСТЬ!", Color(1.0, 0.85, 0.3))
				hud.show_message("Грабитель что-то нашёл!" if not robber_mode else "Есть! Теперь вынеси её из дома.",
					Color(1, 0.8, 0.4))
			elif robber_mode:
				hud.show_message("Пусто... ищи дальше.", Color(0.8, 0.8, 0.9))

## Мелкий роется в мебели (снаряжение) / закрывает окно / развязывает друга.
func kid_action_at(k: Kid) -> Dictionary:
	var w := house.window_near(k.global_position, Defs.INTERACT_RANGE + 0.8)
	if not w.is_empty() and not w["state"]["closed"] and not w["state"]["broken"]:
		hud.show_qte("Заколачиваем окно...")
		return {"type": "close", "index": w["index"], "t": 0.0, "total": Defs.WINDOW_CLOSE_TIME}
	var s := house.searchable_near(k.global_position, Defs.INTERACT_RANGE)
	if not s.is_empty() and not s["jewel"]:
		hud.show_qte("Роемся в поисках полезного...")
		return {"type": "search", "spot": s, "t": 0.0, "total": Defs.KID_SEARCH_TIME}
	return {}

func kid_action_done(k: Kid, act: Dictionary) -> void:
	match act["type"]:
		"close":
			house.close_entry(act["index"])
			hud.show_message("Окно заколочено! Пусть попробуют влезть.", Color(0.6, 1, 0.7))
		"search":
			var s: Dictionary = act["spot"]
			if s["searched"]:
				return
			s["searched"] = true
			_shake_furniture(s["node"])
			var item: String = s["item"]
			if item == "":
				hud.show_message("Пусто. Бывает.", Color(0.8, 0.8, 0.9))
			else:
				loadout[item] = int(loadout.get(item, 0)) + 1
				hud.set_pockets(loadout)
				hud.show_message("Нашёл: %s!" % Defs.ITEMS[item]["name"], Color(0.6, 1, 0.7))

func _shake_furniture(node: Node3D) -> void:
	if not is_instance_valid(node):
		return
	var tw := node.create_tween()
	tw.tween_property(node, "rotation:z", 0.04, 0.07)
	tw.tween_property(node, "rotation:z", -0.04, 0.07)
	tw.tween_property(node, "rotation:z", 0.0, 0.07)

## Грабитель с добычей вышел за периметр — драгоценность украдена.
func _update_deposit() -> void:
	if robber.carrying > 0 and not robber.is_inside_house():
		stolen_jewels += robber.carrying
		robber.stolen += robber.carrying
		robber.carrying = 0
		robber.jewel_deposited.emit()
		hud.set_presents(stolen_jewels, total_jewels)
		hud.show_message("Драгоценность УКРАДЕНА! (%d/%d)" % [stolen_jewels, total_jewels],
			Color(1, 0.5, 0.4) if not robber_mode else Color(0.6, 1, 0.7))
		if stolen_jewels >= total_jewels:
			_finish_by_loot(false)

# ---------------------------------------------------------------- ХАОС-КОМБО

func _register_hit(id: String, name: String) -> void:
	if robber_mode or phase == Phase.OVER:
		return
	if combo_timer <= 0.0:
		combo_ids = []
		combo_names = []
		combo_mult = 0
		combo_named_hit = {}
	combo_timer = Defs.COMBO_WINDOW
	combo_mult += 1
	combo_ids.append(id)
	combo_names.append(name)
	var gained := Defs.COMBO_BASE_STYLE * combo_mult
	style_score += gained
	var tier := Defs.combo_tier(combo_mult)
	var tail: Array = combo_names.slice(maxi(0, combo_names.size() - 4))
	hud.show_combo(tail, combo_mult, style_score, tier, "")
	_check_named_combo()

func _check_named_combo() -> void:
	for recipe in Defs.NAMED_COMBOS:
		var key: String = recipe["name"]
		if combo_named_hit.has(key):
			continue
		if _seq_in(recipe["seq"], combo_ids):
			combo_named_hit[key] = true
			style_score += int(recipe["bonus"])
			var tier := Defs.combo_tier(maxi(combo_mult, 2))
			hud.show_combo(combo_names.slice(maxi(0, combo_names.size() - 4)), combo_mult, style_score, tier, key)
			hud.big_announce("СВЯЗКА: %s!" % key, tier["color"])
			var flavor: String = ("Секретная связка открыта! " if recipe.get("secret", false) else "") + str(recipe["desc"])
			hud.show_message(flavor + "  +%d стиля" % int(recipe["bonus"]), tier["color"])
			SaveGame.data["combos"] = SaveGame.data.get("combos", {})
			SaveGame.data["combos"][key] = true

func _seq_in(seq: Array, arr: Array) -> bool:
	var i := 0
	for x in arr:
		if i < seq.size() and x == seq[i]:
			i += 1
	return i >= seq.size()

func _update_combo(delta: float) -> void:
	if combo_timer <= 0.0:
		return
	combo_timer -= delta
	hud.update_combo_timer(combo_timer / Defs.COMBO_WINDOW)
	if combo_timer <= 0.0:
		if combo_mult >= 2:
			hud.show_message("Цепь на ×%d закрыта: +%d стиля всего." % [combo_mult, style_score], Color(0.7, 0.9, 1.0))
		hud.hide_combo()

## Читаемый список активных эффектов грабителя для HUD.
func _update_robber_status() -> void:
	if robber_mode:
		return
	var fx: Array = []
	if robber.stun_t > 0.1:
		fx.append("ОГЛУШЁН %.0fс" % robber.stun_t)
	if robber.dizzy_t > 0.1:
		fx.append("🌀 голова кружится")
	if robber.slow_t > 0.1 and robber.slow_mult < 0.95:
		fx.append("медленный")
	if robber.wet_t > 0.1:
		fx.append("💧 мокрый")
	if robber.carrying > 0:
		fx.append("💎 несёт добычу!")
	hud.set_santa_status(fx)

func _update_capture(delta: float) -> void:
	var capturing := false
	if not robber_mode and robber.is_stunned() and kid != null and not kid.is_sacked:
		if kid.global_position.distance_to(robber.global_position) < Defs.CAPTURE_RANGE:
			capturing = true
	if capturing:
		capture += Defs.CAPTURE_RATE * robber.capture_mult * delta
	else:
		capture = maxf(capture - Defs.CAPTURE_DECAY * delta, 0.0)
	hud.update_capture(capture)
	if capture >= Defs.CAPTURE_NEED:
		_finish("catch")

# ---------------------------------------------------------------- ЛОВУШКИ

## Сколько ловушек сейчас активно (бюджет против спама).
func active_trap_count() -> int:
	var n := 0
	for c in traps:
		var t = traps[c]
		if is_instance_valid(t) and not t.spent:
			n += 1
	return n

func place_trap(trap_id: String, item_id: String, cell: Vector2i, quality: float, hidden: bool, opts: Dictionary = {}) -> void:
	if traps.has(cell) or int(loadout.get(item_id, 0)) <= 0:
		return
	if active_trap_count() >= Defs.TRAP_BUDGET:
		hud.show_message("Лимит ловушек (%d)! Сними или дождись срабатывания." % Defs.TRAP_BUDGET, Color(1, 0.6, 0.5))
		return
	loadout[item_id] = int(loadout[item_id]) - 1
	hud.set_pockets(loadout)
	var neighbors := 0
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if traps.has(cell + d):
			neighbors += 1
	if neighbors > 0:
		quality = minf(quality + Defs.COMBO_QUALITY_BONUS * neighbors, 1.0)
		hud.show_message("КОМБО ×%d! Соседние ловушки сработают цепочкой!" % neighbors, Color(0.55, 1.0, 0.9))
	var trap := Trap.new()
	add_child(trap)
	trap.add_to_group("traps")
	if kid != null and not opts.has("placer"):
		opts["placer"] = kid
	trap.setup(trap_id, cell, quality, hidden, kid.vis_mult if kid != null else 1.0, opts)
	if trap_id == "rope_chandelier":
		trap.chandelier = house.chandeliers.get(cell)
	traps[cell] = trap
	trap.triggered.connect(_on_trap_triggered)
	trap.tree_exited.connect(func():
		if traps.get(cell) == trap:
			traps.erase(cell))
	var qtext := "отлично!" if quality > 0.9 else ("норм" if quality >= 0.75 else "криво... может не сработать")
	hud.show_message("Поставил: %s (%s)" % [Defs.TRAPS[trap_id]["name"], qtext], Color(0.7, 1, 0.7))
	if trap_id == "firecracker_chimney":
		for i in house.entries.size():
			if house.entries[i]["type"] == "chimney":
				robber.blocked_entries[i] = true
		hud.show_message("Дымоход заблокирован!", Color(1, 0.8, 0.4))

func _on_trap_triggered(trap: Trap, body: Node3D) -> void:
	# ДРУЖЕСКИЙ ОГОНЬ: мелкий влетел в чужую ловушку — эффект на него, без стиля
	if body != null and body.is_in_group("kids"):
		body.hit_by_trap(float(trap.def["stun"]) * 0.7 + 1.0)
		_trigger_fx(trap)
		if not trap.link.is_empty():
			_fire_linked(trap)
		hud.big_announce("СВОЯ ЖЕ ЛОВУШКА!", Color(1, 0.7, 0.3))
		hud.show_message("Кто-то из мелких влетел в %s. Классика." % trap.def["name"], Color(1, 0.8, 0.5))
		return
	trap.apply_to(robber)
	_trigger_fx(trap)
	_chain_from(trap)
	_check_secret_combos(trap)
	_register_hit(trap.trap_id, trap.def["name"])
	if trap.trap_id == "cookie":
		hud.show_message("Грабитель жуёт печенье! Хватай его!", Color(1, 0.8, 0.4))
	else:
		hud.show_message("СРАБОТАЛО: %s!" % trap.def["name"], Color(1, 0.85, 0.3))

# ---------------------------------------------------------------- СВЯЗАННЫЕ ОБЪЕКТЫ

func _fire_linked(trap: Trap) -> void:
	var link := trap.link
	trap.link = {}
	var d := trap.delay
	var q := trap.quality
	if link["type"] == "chandelier":
		house.wobble_chandelier(link["cell"], d)
		if d > 0.05:
			hud.show_message("Люстра закачалась...", Color(1, 0.9, 0.6))
	get_tree().create_timer(maxf(d, 0.05)).timeout.connect(func():
		if not is_instance_valid(self) or phase == Phase.OVER:
			return
		_activate_object(link, q))

func _activate_object(link: Dictionary, quality: float) -> void:
	var target := Defs.cell_to_world(link["cell"])
	match link["type"]:
		"chandelier":
			if not house.crash_chandelier(link["cell"]):
				return
			get_tree().create_timer(0.3).timeout.connect(func():
				_burst(target + Vector3(0, 0.6, 0), Color(1.0, 0.85, 0.4), 50, 3.0)
				PropFX.impact(self, target + Vector3(0, 0.1, 0), Color(0.85, 0.8, 0.5), 10)
				hud.shake(12.0)
				if robber.global_position.distance_to(target) < Defs.CHANDELIER_AOE:
					robber.apply_trap_effect(7.0 * quality, 0.6, 4.0, false, 1.6, {"dizzy": 3.0})
					hud.big_announce("ЛЮСТРОЙ ЕГО!", Color(1, 0.85, 0.3))
					_register_hit("chandelier_drop", "Люстра")
				else:
					hud.show_message("Люстра рухнула... мимо. Тайминг!", Color(1, 0.6, 0.5)))
		"shelf":
			var shelf: Dictionary = link["shelf"]
			var is_fridge: bool = shelf.get("type", "") == "fridge"
			if not house.topple_shelf(shelf, link.get("trigger_cell", link["cell"])):
				return
			var tcell: Vector2i = link.get("trigger_cell", link["cell"])
			get_tree().create_timer(0.4).timeout.connect(func():
				_burst(target + Vector3(0, 0.8, 0), Color(0.8, 0.65, 0.4), 40, 2.5)
				PropFX.impact(self, Defs.cell_to_world(tcell) + Vector3(0, 0.1, 0), Color(0.75, 0.6, 0.42), 12)
				hud.shake(10.0)
				if is_fridge:
					var wet: Array = house.spill_milk(shelf["cell"])
					hud.show_message("Молоко разлилось — скользко и ловушек не видно!", Color(0.9, 0.95, 1.0))
				if robber.global_position.distance_to(Defs.cell_to_world(tcell)) < Defs.SHELF_AOE:
					robber.apply_trap_effect(5.0 * quality, 0.7, 3.0, false, 1.4, {"dizzy": 2.0})
					hud.big_announce("ХОЛОДИЛЬНИКОМ ПРИДАВИЛО!" if is_fridge else "ШКАФОМ ПРИДАВИЛО!", Color(1, 0.85, 0.3))
					_register_hit("fridge_drop" if is_fridge else "shelf_drop", "Холодильник" if is_fridge else "Шкаф")
				else:
					hud.show_message("Грохнулось рядом. Почти!", Color(1, 0.6, 0.5)))
		"tv":
			if not house.spark_tv(link["tv"]):
				return
			hud.shake(6.0)
			var target_tv := Defs.cell_to_world(link["cell"])
			var wet := robber.wet_t > 0.0
			if robber.global_position.distance_to(target_tv) < 2.0:
				if wet:
					robber.apply_trap_effect(6.5, 0.4, 5.0, false, 1.8, {"dizzy": 3.0})
					hud.big_announce("КОРОТКОЕ ЗАМЫКАНИЕ!", Color(0.5, 0.9, 1.0))
					hud.show_message("Мокрый грабитель + телек = фейерверк из искр.", Color(0.6, 0.9, 1.0))
				else:
					robber.apply_trap_effect(4.0 * quality, 0.6, 3.5, false, 1.4, {"dizzy": 2.0})
					hud.big_announce("ЭЛЕКТРОШОК!", Color(0.6, 0.85, 1.0))
				# дуга от экрана к жертве
				PropFX.electric_arc(self, target_tv + Vector3(0, 1.0, 0), robber.global_position + Vector3(0, 1.0, 0))
				_burst(target_tv + Vector3(0, 1.0, 0), Color(0.5, 0.85, 1.0), 45, 3.0)
				_register_hit("tv_spark", "Телевизор")
			else:
				hud.show_message("Телек искрит вхолостую — рядом никого.", Color(1, 0.6, 0.5))
		"rug":
			var cells: Array = house.pull_rug(link["cell"])
			if cells.is_empty():
				return
			hud.shake(7.0)
			var on_rug := false
			var scell := Defs.world_to_cell(robber.global_position)
			for c in cells:
				if c == scell:
					on_rug = true
			if on_rug:
				robber.apply_trap_effect(3.5 * quality, 1.0, 0.0, false, 1.3, {"knock": -2.6, "dizzy": 1.5})
				hud.big_announce("КОВЁР ИЗ-ПОД НОГ!", Color(1, 0.7, 0.3))
				_register_hit("rug_pull", "Ковёр")
			else:
				hud.show_message("Ковёр улетел, но на нём никого. Момент!", Color(1, 0.6, 0.5))

# ---------------------------------------------------------------- СКРЫТЫЕ КОМБО

func _check_secret_combos(trap: Trap) -> void:
	if trap.trap_id == "garland_shock" and robber.wet_t > 0.0:
		robber.apply_trap_effect(6.0, 0.4, 5.0, false, 1.8, {"dizzy": 2.5})
		hud.big_announce("МЕГАВОЛЬТ!!!", Color(0.5, 0.9, 1.0))
		hud.show_message("Мокрый грабитель проводит ток ОТЛИЧНО.", Color(0.6, 0.9, 1.0))
		_burst(robber.global_position + Vector3(0, 1, 0), Color(0.5, 0.9, 1.0), 70, 4.0)
	if trap.trap_id == "firecracker":
		var ignited := false
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
			var other: Trap = traps.get(trap.cell + d)
			if other != null and not other.spent and other.trap_id in ["oil", "oil_tiles"]:
				other.become_fire()
				ignited = true
		if ignited:
			hud.big_announce("МАСЛО ВСПЫХНУЛО!", Color(1, 0.55, 0.2))
			hud.show_message("Теперь тут горит. Грабитель в ужасе.", Color(1, 0.6, 0.3))
	if trap.trap_id == "cookie":
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i.ZERO]:
			var other: Trap = traps.get(trap.cell + d)
			if other != null and other != trap and not other.spent and other.trap_id in ["glue", "glue_door"]:
				robber.apply_trap_effect(3.0, 1.0, 0.0, false, 1.6, {})
				hud.show_message("Грабитель прилип ПРЯМО У ПЕЧЕНЬЯ. Позор.", Color(0.6, 1, 0.8))
				break

func _chain_from(trap: Trap) -> void:
	if not trap.link.is_empty():
		_fire_linked(trap)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var other: Trap = traps.get(trap.cell + d)
		if other == null or other.spent or other.retrigger_cd > 0.0 or bool(other.def.get("bait", false)):
			continue
		var o := other
		get_tree().create_timer(Defs.CHAIN_DELAY).timeout.connect(func():
			if is_instance_valid(o) and not o.spent and is_instance_valid(robber):
				if robber.global_position.distance_to(o.global_position) < Defs.CHAIN_RANGE:
					o.force_trigger())

func _on_roar() -> void:
	hud.show_message("ГРАБИТЕЛЬ РЫЧИТ!", Color(1, 0.5, 0.4))
	if kid != null and kid.global_position.distance_to(robber.global_position) < Defs.SANTA_HOHO_RANGE:
		hud.shake()
		if is_instance_valid(trap_mode) and trap_mode.placing:
			trap_mode._cancel_place()
			hud.show_message("Он напугал тебя — установка сорвалась!", Color(1, 0.6, 0.5))

## F — «чутьё наживы»: подсветить КОМНАТУ, где ещё лежит драгоценность.
func _on_loot_sense() -> void:
	if not robber_mode:
		return
	var target_room := -1
	for s in house.searchables:
		if s["jewel"] and not s["searched"]:
			target_room = house.room_of(Vector2i(s["cell"]))
			break
	if target_room < 0:
		hud.show_message("Чутьё молчит — в мебели пусто. Всё уже у вас?", Color(0.8, 0.8, 0.9))
		return
	var room: Dictionary = house.loc["rooms"][target_room]
	var rect: Rect2i = room["rect"]
	hud.show_message("Чутьё наживы: пахнет золотом — «%s»!" % room["name"], Color(1, 0.85, 0.5))
	var zone := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(rect.size.x, rect.size.y)
	zone.mesh = pm
	var mat := Defs.flat_mat(Color(1.0, 0.8, 0.35, 0.3), 1.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	zone.material_override = mat
	zone.position = Vector3(rect.position.x + rect.size.x * 0.5, 0.08, rect.position.y + rect.size.y * 0.5)
	add_child(zone)
	var tw := zone.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 5.0)
	tw.tween_callback(zone.queue_free)

# ---------------------------------------------------------------- FX

func _trigger_fx(trap: Trap) -> void:
	var pos := trap.global_position + Vector3(0, 0.4, 0)
	match trap.trap_id:
		"bucket_door":
			_burst(pos + Vector3(0, 1.6, 0), Color(0.45, 0.7, 1.0), 40, 2.5)
		"firecracker", "firecracker_chimney":
			_burst(pos, Color(1.0, 0.6, 0.2), 60, 4.0)
			var flash := OmniLight3D.new()
			flash.light_color = Color(1.0, 0.7, 0.3)
			flash.light_energy = 5.0
			flash.omni_range = 7.0
			flash.position = pos
			add_child(flash)
			var tw := flash.create_tween()
			tw.tween_property(flash, "light_energy", 0.0, 0.5)
			tw.tween_callback(flash.queue_free)
		"shards":
			_burst(pos, Color(0.9, 0.5, 0.8), 24, 1.8)
		"rope_chandelier":
			_burst(pos + Vector3(0, 1.0, 0), Color(1.0, 0.85, 0.4), 36, 2.2)
		"cookie":
			_burst(pos, Color(0.8, 0.6, 0.3), 16, 1.2)
		"banana":
			_burst(pos, Color(0.95, 0.85, 0.25), 20, 1.5)
		"marbles":
			# настоящие катящиеся шарики
			PropFX.scatter_marbles(self, trap.global_position + Vector3(0, 0.1, 0), 12)
		"perfume":
			_cloud(pos + Vector3(0, 0.5, 0), Color(0.9, 0.5, 0.85))
		"garland_shock":
			# дуга бьёт от гирлянды в грабителя
			PropFX.electric_arc(self, pos + Vector3(0, 0.4, 0), robber.global_position + Vector3(0, 1.0, 0))
			_burst(pos + Vector3(0, 0.6, 0), Color(0.5, 0.9, 1.0), 30, 2.4)
		_:
			_burst(pos, Color(0.9, 0.9, 1.0), 20, 1.6)

func _burst(pos: Vector3, color: Color, amount: int, speed: float) -> void:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 0.7
	p.one_shot = true
	p.explosiveness = 1.0
	p.position = pos
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 70.0
	pm.initial_velocity_min = speed * 0.5
	pm.initial_velocity_max = speed
	pm.gravity = Vector3(0, -7, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.09)
	var qm := StandardMaterial3D.new()
	qm.albedo_color = color
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = qm
	p.draw_pass_1 = quad
	add_child(p)
	p.emitting = true
	var tw := p.create_tween()
	tw.tween_interval(1.5)
	tw.tween_callback(p.queue_free)

func _cloud(pos: Vector3, color: Color) -> void:
	var p := GPUParticles3D.new()
	p.amount = 30
	p.lifetime = 2.2
	p.one_shot = false
	p.position = pos
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.4
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.4
	pm.gravity = Vector3(0, 0.15, 0)
	pm.scale_min = 1.5
	pm.scale_max = 3.0
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.4, 0.4)
	var qm := StandardMaterial3D.new()
	qm.albedo_color = Color(color.r, color.g, color.b, 0.35)
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = qm
	p.draw_pass_1 = quad
	add_child(p)
	p.emitting = true
	var tw := p.create_tween()
	tw.tween_interval(2.5)
	tw.tween_callback(func(): p.emitting = false)
	tw.tween_interval(2.4)
	tw.tween_callback(p.queue_free)

# ---------------------------------------------------------------- СОБЫТИЯ

func _on_kid_tie_changed(is_tied: bool) -> void:
	if is_tied:
		hud.show_message("Тебя связали! ЖМИ ПРОБЕЛ, чтобы выпутаться!", Color(1, 0.4, 0.4))
	else:
		hud.show_message("Выпутался из верёвок!", Color(0.6, 1, 0.6))

# ---------------------------------------------------------------- ФИНАЛ

## Полиция приехала или всё украдено: исход по количеству украденного.
func _finish_by_loot(police_arrived: bool) -> void:
	var still_carrying := robber.carrying > 0 and police_arrived
	if still_carrying:
		robber.carrying = 0   # не успел вынести — не считается
	if stolen_jewels <= 0:
		_finish("defended")
	elif stolen_jewels * 2 < total_jewels:
		_finish("partial")
	else:
		_finish("robbed")

func _finish(outcome: String) -> void:
	if phase == Phase.OVER:
		return
	phase = Phase.OVER
	if is_instance_valid(trap_mode) and trap_mode.active:
		trap_mode.deactivate()
	if kid != null:
		kid.frozen = true
	robber.set_physics_process(false)
	var title := ""
	var sub := ""
	var reward := Defs.REWARD_LOSE
	var tcolor := UITheme.ACCENT
	match outcome:
		"catch":
			title = "ГРАБИТЕЛЬ СХВАЧЕН!"
			sub = "Вы, мелкие пиздюки, скрутили его до полиции.\nДом цел, добыча на месте."
			reward = Defs.REWARD_CATCH
			SaveGame.data["catches"] = int(SaveGame.data.get("catches", 0)) + 1
		"defended":
			title = "ДОМ ОТСТОЯЛИ!"
			sub = "Полиция приехала, грабители удрали НИ С ЧЕМ.\nНи одной драгоценности не пропало."
			reward = Defs.REWARD_CATCH
		"partial":
			title = "ОТБИЛИСЬ... ПОЧТИ"
			sub = "Грабители утащили %d из %d драгоценностей.\nМогло быть хуже." % [stolen_jewels, total_jewels]
			reward = Defs.REWARD_SCARE
		"robbed":
			title = "ОБЧИСТИЛИ!"
			sub = "Грабители вынесли %d из %d драгоценностей\nи растворились в ночи." % [stolen_jewels, total_jewels]
			reward = Defs.REWARD_LOSE
			tcolor = Color(1, 0.4, 0.35)
	if robber_mode:
		reward = [0, 0]
		if outcome == "robbed":
			title = "ДЕЛО СДЕЛАНО!"
			sub = "Ты вынес %d драгоценностей до сирен." % stolen_jewels
	var style_coins := 0
	if not robber_mode:
		style_coins = int(style_score / Defs.STYLE_TO_COINS)
		if style_coins > 0:
			sub += "\n💥 Стиль: %d очков → +%d монет за хаос!" % [style_score, style_coins]
	var total_coins: int = reward[0] + style_coins
	SaveGame.add_coins(total_coins)
	if not robber_mode:
		SaveGame.add_xp(config["char_id"], reward[1])
	hud.hide_combo()
	hud.show_result(title, sub, total_coins, reward[1], tcolor)
