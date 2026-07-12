class_name Match
extends Node3D
## Один матч: дом, пацан, Санта, ловушки, фазы, победа/поражение.

signal finished

enum Phase { PREP, SANTA, OVER }

var config: Dictionary
var house: HouseBuilder
var kid: Kid
var santa: Santa
var hud: Hud
var trap_mode: TrapMode

var phase: Phase = Phase.PREP
var phase_t := Defs.PREP_TIME
var match_time := Defs.MATCH_TIME
var last_countdown := -1
var capture := 0.0
var traps: Dictionary = {}     # Vector2i -> Trap
var loadout: Dictionary = {}   # item_id -> count
var spot_markers: Dictionary = {}  # Vector2i -> MeshInstance3D (метки доставки)
var delivered_count := 0
var total_presents := 0
var santa_mode := false

# ХАОС-КОМБО
var combo_ids: Array = []       # id-ловушек текущей цепи (для именованных связок)
var combo_names: Array = []     # читаемые имена звеньев для HUD
var combo_timer := 0.0          # сколько осталось до обрыва цепи
var combo_mult := 0             # длина текущей цепи
var style_score := 0            # накопленный «стиль» за матч
var combo_named_hit: Dictionary = {}  # какие именованные связки уже засчитаны в этой цепи

func start(p_config: Dictionary) -> void:
	config = p_config
	santa_mode = config.get("santa_mode", false)
	loadout = config.get("loadout", {}).duplicate()

	HouseBuilder.build_night_env(self)
	house = HouseBuilder.new()
	house.build(self, config["loc_id"], config.get("loc_data", {}))
	total_presents = house.present_spots.size()
	_build_spot_markers()

	santa = Santa.new()
	add_child(santa)
	santa.setup(house, santa_mode)
	santa.delivered.connect(_on_delivered)
	santa.escaped.connect(_on_escaped)
	santa.sacked_kid.connect(_on_sacked_kid)
	santa.hoho_used.connect(_on_santa_hoho)
	santa.present_sense_used.connect(_on_present_sense)

	if not santa_mode:
		kid = Kid.new()
		add_child(kid)
		kid.setup(config["char_id"])
		kid.global_position = Defs.cell_to_world(house.loc["kid_spawn"]) + Vector3(0, 0.1, 0)
		santa.kids_ref = [kid]
		kid.sacked_state_changed.connect(_on_kid_sack_changed)

	hud = Hud.new()
	add_child(hud)
	hud.quit_to_menu.connect(func(): finished.emit())
	hud.set_presents(0, total_presents)
	hud.set_pockets(loadout)
	if santa_mode:
		hud.hint_label.text = "Санта: E — подарок | F — чуйка на подарки | Q — чуйка на ловушки | R — ХО-ХО-ХО | SHIFT — рывок"

	if not santa_mode:
		trap_mode = TrapMode.new()
		add_child(trap_mode)
		trap_mode.setup(self, house, kid)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	match_time = float(config.get("match_time", Defs.MATCH_TIME))
	phase = Phase.PREP
	phase_t = float(config.get("prep_time", Defs.PREP_TIME)) if not santa_mode else 3.0
	hud.set_phase("ПОДГОТОВКА — расставляй ловушки!" if not santa_mode else "Приготовься...")
	if not santa_mode:
		hud.big_announce("РАССТАВЛЯЙ ЛОВУШКИ!", Color(0.5, 1.0, 0.6))
	hud.show_message("Санта уже близко. Времени мало!", Color(1, 0.9, 0.5))

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
				phase = Phase.SANTA
				phase_t = match_time
				santa.go()
				hud.set_phase("САНТА В ДЕЛЕ — лови его!")
				hud.big_announce("САНТА ИДЁТ!", Color(1, 0.45, 0.4))
				hud.show_message("Он выбирает, как залезть в дом...", Color(1, 0.6, 0.5))
		Phase.SANTA:
			_update_capture(delta)
			_update_santa_status()
			_update_combo(delta)
			if santa_mode:
				_update_delivery_reveal()
			if kid != null:
				hud.set_sacked(kid.is_sacked, kid.sack_progress())
			if phase_t <= Defs.ENRAGE_TIME and not santa.enraged and not santa_mode:
				santa.enrage()
				hud.big_announce("САНТА ОЗВЕРЕЛ!", Color(1, 0.3, 0.25))
				hud.show_message("Он быстрее, и его почти не замедлить!", Color(1, 0.35, 0.3))
			if phase_t <= 0.0:
				_finish("scare")

# ---------------------------------------------------------------- ХАОС-КОМБО

## Единая точка: любое попадание по Санте продлевает цепь и копит стиль.
## id — техн. id (для именованных связок), name — что показать игроку.
func _register_hit(id: String, name: String) -> void:
	if santa_mode or phase == Phase.OVER:
		return
	if combo_timer <= 0.0:
		# новая цепь
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
	# показать текущую цепь
	var tail: Array = combo_names.slice(maxi(0, combo_names.size() - 4))
	hud.show_combo(tail, combo_mult, style_score, tier, "")
	# проверяем именованные связки
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

## Является ли seq подпоследовательностью arr (по порядку, не обязательно подряд).
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
		# цепь закрылась
		if combo_mult >= 2:
			hud.show_message("Цепь на ×%d закрыта: +%d стиля всего." % [combo_mult, style_score], Color(0.7, 0.9, 1.0))
		hud.hide_combo()

## Собирает читаемый список активных эффектов Санты для HUD.
func _update_santa_status() -> void:
	if santa_mode:
		return
	var fx: Array = []
	if santa.stun_t > 0.1:
		fx.append("ОГЛУШЁН %.0fс" % santa.stun_t)
	if santa.dizzy_t > 0.1:
		fx.append("🌀 голова кружится")
	if santa.slow_t > 0.1 and santa.slow_mult < 0.95:
		fx.append("медленный")
	if santa.wet_t > 0.1:
		fx.append("💧 мокрый")
	hud.set_santa_status(fx)

func _update_capture(delta: float) -> void:
	var capturing := false
	if not santa_mode and santa.is_stunned() and kid != null and not kid.is_sacked:
		if kid.global_position.distance_to(santa.global_position) < Defs.CAPTURE_RANGE:
			capturing = true
	if capturing:
		capture += Defs.CAPTURE_RATE * santa.capture_mult * delta
	else:
		capture = maxf(capture - Defs.CAPTURE_DECAY * delta, 0.0)
	hud.update_capture(capture)
	if capture >= Defs.CAPTURE_NEED:
		_finish("catch")

# ---------------------------------------------------------------- ЛОВУШКИ

func place_trap(trap_id: String, item_id: String, cell: Vector2i, quality: float, hidden: bool, opts: Dictionary = {}) -> void:
	if traps.has(cell) or int(loadout.get(item_id, 0)) <= 0:
		return
	loadout[item_id] = int(loadout[item_id]) - 1
	hud.set_pockets(loadout)
	# комбо-бонус: соседние ловушки повышают качество (и сработают цепочкой)
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
				santa.blocked_entries[i] = true
		hud.show_message("Дымоход заблокирован!", Color(1, 0.8, 0.4))

func _on_trap_triggered(trap: Trap) -> void:
	trap.apply_to(santa)
	_trigger_fx(trap)
	_chain_from(trap)
	_check_secret_combos(trap)
	_register_hit(trap.trap_id, trap.def["name"])
	if not trap.link.is_empty():
		_fire_linked(trap)
	if trap.trap_id == "cookie":
		hud.show_message("Санта уплетает печенье! Хватай его!", Color(1, 0.8, 0.4))
	else:
		hud.show_message("СРАБОТАЛО: %s!" % trap.def["name"], Color(1, 0.85, 0.3))
	if bool(trap.def.get("scare", false)):
		hud.show_message("Санта в панике бросился к выходу!", Color(1, 0.6, 0.4))

# ---------------------------------------------------------------- СВЯЗАННЫЕ ОБЪЕКТЫ

## Триггер сработал — через задержку падает связанный объект (люстра/шкаф).
func _fire_linked(trap: Trap) -> void:
	var link := trap.link
	trap.link = {}  # один раз
	var d := trap.delay
	var q := trap.quality  # копируем: триггер-ловушка может исчезнуть до падения
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
				hud.shake(10.0)
				if santa.global_position.distance_to(target) < Defs.CHANDELIER_AOE:
					santa.apply_trap_effect(7.0 * quality, 0.6, 4.0, false, 1.6, {"dizzy": 3.0})
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
				hud.shake(8.0)
				if is_fridge:
					# холодильник разливает молоко: скользко + прячет ловушки
					var wet: Array = house.spill_milk(shelf["cell"])
					_apply_milk_zone(wet)
					hud.show_message("Молоко разлилось — скользко и ловушек не видно!", Color(0.9, 0.95, 1.0))
				if santa.global_position.distance_to(Defs.cell_to_world(tcell)) < Defs.SHELF_AOE:
					santa.apply_trap_effect(5.0 * quality, 0.7, 3.0, false, 1.4, {"dizzy": 2.0})
					hud.big_announce("ХОЛОДИЛЬНИКОМ ПРИДАВИЛО!" if is_fridge else "ШКАФОМ ПРИДАВИЛО!", Color(1, 0.85, 0.3))
					_register_hit("fridge_drop" if is_fridge else "shelf_drop", "Холодильник" if is_fridge else "Шкаф")
				else:
					hud.show_message("Грохнулось рядом. Почти!", Color(1, 0.6, 0.5)))
		"tv":
			if not house.spark_tv(link["tv"]):
				return
			hud.shake(6.0)
			var target_tv := Defs.cell_to_world(link["cell"])
			var wet := santa.wet_t > 0.0
			if santa.global_position.distance_to(target_tv) < 2.0:
				if wet:
					# СЕКРЕТ: мокрый + ТВ = мегашок
					santa.apply_trap_effect(6.5, 0.4, 5.0, false, 1.8, {"dizzy": 3.0})
					hud.big_announce("КОРОТКОЕ ЗАМЫКАНИЕ!", Color(0.5, 0.9, 1.0))
					hud.show_message("Мокрый Санта + телек = фейерверк из искр.", Color(0.6, 0.9, 1.0))
				else:
					santa.apply_trap_effect(4.0 * quality, 0.6, 3.5, false, 1.4, {"dizzy": 2.0})
					hud.big_announce("ЭЛЕКТРОШОК!", Color(0.6, 0.85, 1.0))
				_burst(target_tv + Vector3(0, 1.0, 0), Color(0.5, 0.85, 1.0), 45, 3.0)
				_register_hit("tv_spark", "Телевизор")
			else:
				hud.show_message("Телек искрит вхолостую — Санты рядом нет.", Color(1, 0.6, 0.5))
		"rug":
			var cells: Array = house.pull_rug(link["cell"])
			if cells.is_empty():
				return
			hud.shake(7.0)
			var on_rug := false
			var scell := Defs.world_to_cell(santa.global_position)
			for c in cells:
				if c == scell:
					on_rug = true
			if on_rug:
				santa.apply_trap_effect(3.5 * quality, 1.0, 0.0, false, 1.3, {"knock": -2.6, "dizzy": 1.5})
				hud.big_announce("КОВЁР ИЗ-ПОД НОГ!", Color(1, 0.7, 0.3))
				_register_hit("rug_pull", "Ковёр")
			else:
				hud.show_message("Ковёр улетел, но Санта не на нём. Момент!", Color(1, 0.6, 0.5))

## Молочная зона: клетки временно скользкие (danger для бота) — оформлено как эффект.
func _apply_milk_zone(cells: Array) -> void:
	# Санта-бот воспринимает молоко как лёгкую опасность и притормаживает
	for c in cells:
		if santa != null and not santa_mode:
			santa.danger[c] = maxf(float(santa.danger.get(c, 1.0)), 2.0)

# ---------------------------------------------------------------- СКРЫТЫЕ КОМБО
# Нигде не описаны — игроки открывают сами.

func _check_secret_combos(trap: Trap) -> void:
	# МОКРЫЙ + ШОКЕР: ведро воды недавно + гирлянда-шокер = мегастан
	if trap.trap_id == "garland_shock" and santa.wet_t > 0.0:
		santa.apply_trap_effect(6.0, 0.4, 5.0, false, 1.8, {"dizzy": 2.5})
		hud.big_announce("МЕГАВОЛЬТ!!!", Color(0.5, 0.9, 1.0))
		hud.show_message("Мокрый Санта проводит ток ОТЛИЧНО.", Color(0.6, 0.9, 1.0))
		_burst(santa.global_position + Vector3(0, 1, 0), Color(0.5, 0.9, 1.0), 70, 4.0)
	# ПЕТАРДА + МАСЛО: соседние масляные лужи вспыхивают
	if trap.trap_id == "firecracker":
		var ignited := false
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
			var other: Trap = traps.get(trap.cell + d)
			if other != null and not other.spent and other.trap_id in ["oil", "oil_tiles"]:
				other.become_fire()
				ignited = true
		if ignited:
			hud.big_announce("МАСЛО ВСПЫХНУЛО!", Color(1, 0.55, 0.2))
			hud.show_message("Теперь тут горит. Санта в ужасе.", Color(1, 0.6, 0.3))
	# ПЕЧЕНЬЕ + КЛЕЙ рядом: Санта жуёт, прилипнув — дольше стан
	if trap.trap_id == "cookie":
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i.ZERO]:
			var other: Trap = traps.get(trap.cell + d)
			if other != null and other != trap and not other.spent and other.trap_id in ["glue", "glue_door"]:
				santa.apply_trap_effect(3.0, 1.0, 0.0, false, 1.6, {})
				hud.show_message("Санта прилип ПРЯМО У ПЕЧЕНЬЯ. Позор.", Color(0.6, 1, 0.8))
				break

## Цепная реакция: соседние ловушки срабатывают следом, если Санта рядом.
func _chain_from(trap: Trap) -> void:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var other: Trap = traps.get(trap.cell + d)
		if other == null or other.spent or other.retrigger_cd > 0.0 or bool(other.def.get("bait", false)):
			continue
		var o := other
		get_tree().create_timer(Defs.CHAIN_DELAY).timeout.connect(func():
			if is_instance_valid(o) and not o.spent and is_instance_valid(santa):
				if santa.global_position.distance_to(o.global_position) < Defs.CHAIN_RANGE:
					o.force_trigger())

func _on_santa_hoho() -> void:
	hud.show_message("ХО-ХО-ХО!!!", Color(1, 0.5, 0.4))
	if kid != null and kid.global_position.distance_to(santa.global_position) < Defs.SANTA_HOHO_RANGE:
		hud.shake()
		if is_instance_valid(trap_mode) and trap_mode.placing:
			trap_mode._cancel_place()
			hud.show_message("Санта напугал тебя — установка сорвалась!", Color(1, 0.6, 0.5))

## Партиклы в точке срабатывания.
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
			_burst(pos, Color(0.6, 0.7, 0.95), 22, 1.6)
		"perfume":
			# розовое облако, висит и расползается
			_cloud(pos + Vector3(0, 0.5, 0), Color(0.9, 0.5, 0.85))
		"garland_shock":
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

## Медленное расползающееся облако (духи) — держится пару секунд.
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

# ---------------------------------------------------------------- СОБЫТИЯ САНТЫ

func _on_delivered(spot: Vector2i) -> void:
	delivered_count += 1
	hud.set_presents(delivered_count, total_presents)
	# метку доставленного места убираем
	if spot_markers.has(spot):
		spot_markers[spot].queue_free()
		spot_markers.erase(spot)
	var box := Minifig.build_present()
	box.position = Defs.cell_to_world(spot)
	box.scale = Vector3(0.01, 0.01, 0.01)
	add_child(box)
	var tw := box.create_tween()
	tw.tween_property(box, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	hud.show_message("Санта подложил подарок! (%d/%d)" % [delivered_count, total_presents], Color(1, 0.7, 0.6))

# ---------------------------------------------------------------- САНТА: ПОИСК МЕСТ

## «Чуйка на подарки» (F): всплывают ПРИМЕРНЫЕ зоны у неразложенных мест — со сдвигом,
## чтобы не выдать точку. Санта видит «где-то здесь» и должен подойти вплотную.
func _on_present_sense() -> void:
	if not santa_mode:
		return
	hud.show_message("Чуйка: подарки просятся наружу... ищи в подсвеченных зонах!", Color(1, 0.85, 0.5))
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var shown := 0
	for spot in santa.spots_left:
		if shown >= 4:
			break
		shown += 1
		var off := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized() * Defs.PSENSE_SPOT_FUZZ
		var base := Defs.cell_to_world(spot) + off
		var group := Node3D.new()
		group.position = base
		add_child(group)
		# диск на полу
		var zone := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 2.4
		cyl.bottom_radius = 2.4
		cyl.height = 0.03
		zone.mesh = cyl
		var mat := Defs.flat_mat(Color(1.0, 0.8, 0.35, 0.4), 1.6)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		zone.material_override = mat
		zone.position = Vector3(0, 0.06, 0)
		group.add_child(zone)
		# высокий столб света — видно через полдома
		var beam := MeshInstance3D.new()
		var bc := CylinderMesh.new()
		bc.top_radius = 0.9
		bc.bottom_radius = 1.6
		bc.height = 4.0
		beam.mesh = bc
		var bmat := Defs.flat_mat(Color(1.0, 0.82, 0.4, 0.22), 1.4)
		bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		beam.material_override = bmat
		beam.position = Vector3(0, 2.0, 0)
		group.add_child(beam)
		var tw := group.create_tween()
		tw.tween_property(mat, "albedo_color:a", 0.0, 6.0)
		tw.parallel().tween_property(bmat, "albedo_color:a", 0.0, 6.0)
		tw.parallel().tween_property(group, "scale", Vector3(1.15, 1, 1.15), 6.0)
		tw.tween_callback(group.queue_free)

## «Горячо/холодно»: когда Санта близко к неразложенному месту, метка теплеет —
## подсказка, что он на месте доставки. Далеко — метка невидима.
func _update_delivery_reveal() -> void:
	for spot in spot_markers:
		var d := santa.global_position.distance_to(Defs.cell_to_world(spot))
		var a := clampf(1.0 - d / Defs.PSENSE_REVEAL, 0.0, 1.0)
		var mat: StandardMaterial3D = spot_markers[spot].material_override
		mat.albedo_color.a = a * 0.75

func _on_escaped() -> void:
	if delivered_count >= total_presents:
		_finish("santa_win")
	else:
		_finish("scare")

func _on_sacked_kid(_k: Kid) -> void:
	hud.show_message("Санта запихал тебя в мешок! ЖМИ ПРОБЕЛ!", Color(1, 0.4, 0.4))

func _on_kid_sack_changed(is_sacked: bool) -> void:
	if not is_sacked:
		hud.show_message("Вырвался из мешка!", Color(0.6, 1, 0.6))

# ---------------------------------------------------------------- ФИНАЛ

func _finish(outcome: String) -> void:
	if phase == Phase.OVER:
		return
	phase = Phase.OVER
	if is_instance_valid(trap_mode) and trap_mode.active:
		trap_mode.deactivate()
	if kid != null:
		kid.frozen = true
	santa.set_physics_process(false)
	var title := ""
	var sub := ""
	var reward := Defs.REWARD_LOSE
	var tcolor := UITheme.ACCENT
	match outcome:
		"catch":
			title = "САНТА ПОЙМАН!"
			sub = "Вы, мелкие пиздюки, сделали невозможное.\nМешок теперь ваш."
			reward = Defs.REWARD_CATCH
			SaveGame.data["catches"] = int(SaveGame.data.get("catches", 0)) + 1
		"scare":
			title = "САНТА СБЕЖАЛ!"
			sub = "Подарки не доставлены. Дом отстояли,\nно борода ушла... (%d/%d подарков)" % [delivered_count, total_presents]
			reward = Defs.REWARD_SCARE
		"santa_win":
			title = "ХО-ХО-ХО!"
			sub = "Санта разложил все подарки и свалил.\nВ следующий раз готовьтесь лучше."
			reward = Defs.REWARD_LOSE
			tcolor = Color(1, 0.4, 0.35)
	if santa_mode:
		reward = [0, 0]
		if outcome == "santa_win":
			sub = "Тренировка пройдена: все подарки на местах."
	# бонус за стиль: накопленный хаос конвертируется в монеты
	var style_coins := 0
	if not santa_mode:
		style_coins = int(style_score / Defs.STYLE_TO_COINS)
		if style_coins > 0:
			sub += "\n💥 Стиль: %d очков → +%d монет за хаос!" % [style_score, style_coins]
	var total_coins: int = reward[0] + style_coins
	SaveGame.add_coins(total_coins)
	if not santa_mode:
		SaveGame.add_xp(config["char_id"], reward[1])
	hud.hide_combo()
	hud.show_result(title, sub, total_coins, reward[1], tcolor)

# ---------------------------------------------------------------- МИР

## Метки мест доставки. Пацаны (обычный режим) видят их всегда — знают, где Санта
## разложит подарки, и куда ставить ловушки. Санта-ИГРОК их НЕ видит: только «горячо/
## холодно» по близости + «чуйка на подарки» (F) даёт примерные зоны.
func _build_spot_markers() -> void:
	for s in house.present_spots:
		var m := MeshInstance3D.new()
		var d := CylinderMesh.new()
		d.top_radius = 0.42
		d.bottom_radius = 0.42
		d.height = 0.02
		m.mesh = d
		var mat := Defs.flat_mat(Color(1.0, 0.85, 0.3, 0.5), 1.5)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.material_override = mat
		m.position = Defs.cell_to_world(s) + Vector3(0, 0.04, 0)
		add_child(m)
		spot_markers[s] = m
		if santa_mode:
			mat.albedo_color.a = 0.0  # спрятано от Санты — ищи сам

