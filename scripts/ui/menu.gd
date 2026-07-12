class_name Menu
extends CanvasLayer
## Главное меню поверх живого 3D-фона (дом, снег, ночь). Персонажи с 3D-превью,
## карманы на очки, локации, магазин скинов.

signal start_match(config: Dictionary)

## 3D-задник меню: дача, ночь, снег, медленный облёт камерой.
class Backdrop extends Node3D:
	var pivot: Node3D
	func _ready() -> void:
		var hb := HouseBuilder.new()
		hb.build(self, "cabin")
		HouseBuilder.build_night_env(self)
		pivot = Node3D.new()
		pivot.position = Vector3(12, 0, 7)
		add_child(pivot)
		var cam := Camera3D.new()
		pivot.add_child(cam)
		cam.position = Vector3(0, 10.0, 20.0)
		cam.look_at(pivot.global_position + Vector3(0, 1.5, 0))
		cam.current = true
	func _process(delta: float) -> void:
		pivot.rotation.y += delta * 0.1

var sel_char := "speedy"
var sel_loc := "cabin"
var loadout: Dictionary = {}
# настройки лобби
var sel_santa := 0   # 0 — бот, 1 — я, 2 — рандом
var sel_prep := 1    # индекс в Defs.PREP_OPTIONS
var sel_time := 1    # индекс в Defs.TIME_OPTIONS

var root: Control
var coins_label: Label
var preview_model: Node3D

func _ready() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UITheme.make()
	add_child(root)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_title()

func _process(delta: float) -> void:
	if is_instance_valid(preview_model):
		preview_model.rotation.y += delta * 1.2

func _clear() -> void:
	preview_model = null
	for c in root.get_children():
		c.queue_free()

func _top_bar() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-190, 12)
	root.add_child(panel)
	coins_label = UITheme.fancy_label(panel, "Монеты: %d" % SaveGame.coins(), 19, UITheme.ACCENT)

func _btn(parent: Node, text: String, cb: Callable, big := false) -> Button:
	var b := Button.new()
	b.text = text
	if big:
		b.custom_minimum_size = Vector2(340, 54)
		b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

# ================================================================ ТИТУЛЬНИК

func _show_title() -> void:
	_clear()
	_top_bar()
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_CENTER)
	vb.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vb.grow_vertical = Control.GROW_DIRECTION_BOTH
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 12)
	root.add_child(vb)
	var title := UITheme.fancy_label(vb, "SANTA HO HO", 74, Color(0.98, 0.32, 0.3))
	title.pivot_offset = Vector2(240, 40)
	var tw := title.create_tween().set_loops()
	tw.tween_property(title, "scale", Vector2(1.03, 1.03), 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(title, "scale", Vector2.ONE, 1.2).set_trans(Tween.TRANS_SINE)
	UITheme.fancy_label(vb, "Поймай деда. Спаси Новый год. Не попади в мешок.", 18, Color(0.85, 0.9, 1))
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 18
	vb.add_child(spacer)
	_btn(vb, "ИГРАТЬ", _show_setup, true)
	_btn(vb, "МАГАЗИН", _show_shop, true)
	_btn(vb, "ТРЕНИРОВКА САНТЫ", func(): start_match.emit({"santa_mode": true, "loc_id": sel_loc, "loadout": {}}), true)
	_btn(vb, "ВЫХОД", func(): get_tree().quit(), true)
	var stats := UITheme.fancy_label(vb, "Поймано Сант: %d" % int(SaveGame.data.get("catches", 0)), 14, Color(0.7, 0.75, 0.9))
	stats.modulate.a = 0.85

# ================================================================ ПОДГОТОВКА

func _show_setup() -> void:
	_clear()
	_top_bar()
	_default_loadout()
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 16)
	root.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	margin.add_child(vb)
	UITheme.fancy_label(vb, "СБОР КОМАНДЫ", 30, UITheme.ACCENT)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 14)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(cols)

	# --- персонажи + превью
	var char_panel := PanelContainer.new()
	cols.add_child(char_panel)
	var char_col := VBoxContainer.new()
	char_col.add_theme_constant_override("separation", 5)
	char_col.custom_minimum_size.x = 300
	char_panel.add_child(char_col)
	UITheme.fancy_label(char_col, "КТО ТЫ", 19)
	char_col.add_child(_make_preview())
	for id in Defs.CHARACTERS:
		var d: Dictionary = Defs.CHARACTERS[id]
		var b := Button.new()
		b.text = "%s  (ур. %d)" % [d["name"], SaveGame.char_level(id)]
		b.tooltip_text = str(d["desc"]) + "\n" + str(d["perk"])
		b.toggle_mode = true
		b.button_pressed = id == sel_char
		var cid: String = id
		b.pressed.connect(func():
			sel_char = cid
			_show_setup())
		char_col.add_child(b)
	var perk_l := UITheme.fancy_label(char_col, Defs.CHARACTERS[sel_char]["perk"], 13, Color(0.65, 1, 0.7))
	perk_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	perk_l.custom_minimum_size.x = 280

	# --- карманы
	var pocket_panel := PanelContainer.new()
	cols.add_child(pocket_panel)
	var pocket_col := VBoxContainer.new()
	pocket_col.add_theme_constant_override("separation", 3)
	pocket_col.custom_minimum_size.x = 400
	pocket_panel.add_child(pocket_col)
	UITheme.fancy_label(pocket_col, "КАРМАНЫ", 19)
	var budget := SaveGame.pocket_points(sel_char)
	var points_label := UITheme.fancy_label(pocket_col, "", 18, Color(0.6, 1, 0.6))
	for item_id in Defs.ITEMS:
		var it: Dictionary = Defs.ITEMS[item_id]
		if it["only_char"] != "" and it["only_char"] != sel_char:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		pocket_col.add_child(row)
		var name_l := Label.new()
		name_l.text = "%s [%d]" % [it["name"], it["cost"]]
		name_l.add_theme_font_size_override("font_size", 14)
		name_l.custom_minimum_size.x = 240
		name_l.tooltip_text = it["desc"]
		name_l.mouse_filter = Control.MOUSE_FILTER_STOP
		row.add_child(name_l)
		var count_l := Label.new()
		count_l.add_theme_font_size_override("font_size", 15)
		var iid: String = item_id
		var refresh := func():
			count_l.text = "×%d" % int(loadout.get(iid, 0))
			points_label.text = "Очки: %d / %d" % [_points_used(), budget]
		var minus := Button.new()
		minus.text = "−"
		minus.custom_minimum_size.x = 34
		minus.pressed.connect(func():
			if int(loadout.get(iid, 0)) > 0:
				loadout[iid] = int(loadout[iid]) - 1
				refresh.call())
		row.add_child(minus)
		row.add_child(count_l)
		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size.x = 34
		plus.pressed.connect(func():
			if _points_used() + int(it["cost"]) <= budget:
				loadout[iid] = int(loadout.get(iid, 0)) + 1
				refresh.call())
		row.add_child(plus)
		refresh.call()
	points_label.text = "Очки: %d / %d" % [_points_used(), budget]
	var hint := UITheme.fancy_label(pocket_col, "Наведи на предмет — описание", 12, Color(0.65, 0.7, 0.85))
	hint.modulate.a = 0.8

	# --- локации
	var loc_panel := PanelContainer.new()
	cols.add_child(loc_panel)
	var loc_col := VBoxContainer.new()
	loc_col.add_theme_constant_override("separation", 5)
	loc_col.custom_minimum_size.x = 280
	loc_panel.add_child(loc_col)
	UITheme.fancy_label(loc_col, "ГДЕ СИДИМ", 19)
	var all_locs: Dictionary = {}
	for id in Defs.LOCATIONS:
		all_locs[id] = Defs.LOCATIONS[id]
	for id in all_locs:
		var d: Dictionary = all_locs[id]
		var b := Button.new()
		b.text = d["name"]
		b.custom_minimum_size.y = 42
		b.toggle_mode = true
		b.button_pressed = id == sel_loc
		var lid: String = id
		b.pressed.connect(func():
			sel_loc = lid
			_show_setup())
		loc_col.add_child(b)
	var loc_desc := UITheme.fancy_label(loc_col, all_locs[sel_loc]["desc"], 13, Color(0.8, 0.85, 1))
	loc_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	loc_desc.custom_minimum_size.x = 260

	# --- настройки лобби
	var sep := HSeparator.new()
	loc_col.add_child(sep)
	UITheme.fancy_label(loc_col, "НАСТРОЙКИ ЛОББИ", 17)
	var santa_opt := OptionButton.new()
	for o in ["Санта: Бот", "Санта: Я (тренировка)", "Санта: Рандом"]:
		santa_opt.add_item(o)
	santa_opt.selected = sel_santa
	santa_opt.item_selected.connect(func(i): sel_santa = i)
	loc_col.add_child(santa_opt)
	var prep_opt := OptionButton.new()
	for o in Defs.PREP_OPTIONS:
		prep_opt.add_item("Подготовка: %d сек" % int(o))
	prep_opt.selected = sel_prep
	prep_opt.item_selected.connect(func(i): sel_prep = i)
	loc_col.add_child(prep_opt)
	var time_opt := OptionButton.new()
	for o in Defs.TIME_OPTIONS:
		time_opt.add_item("У Санты: %d мин" % int(o / 60))
	time_opt.selected = sel_time
	time_opt.item_selected.connect(func(i): sel_time = i)
	loc_col.add_child(time_opt)

	# --- низ
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 20)
	vb.add_child(bottom)
	_btn(bottom, "← Назад", _show_title)
	var start := _btn(bottom, "В ЗАСАДУ!", _emit_start, true)
	start.disabled = _points_used() == 0

func _make_preview() -> Control:
	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(280, 190)
	svc.stretch = true
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.transparent_bg = true
	sv.size = Vector2i(280, 190)
	svc.add_child(sv)
	preview_model = Minifig.build_kid(SaveGame.char_colors(sel_char))
	preview_model.position = Vector3(0, -0.05, 0)
	sv.add_child(preview_model)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.72, 1.7)
	cam.rotation_degrees = Vector3(-8, 0, 0)
	cam.fov = 45
	sv.add_child(cam)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 30, 0)
	light.light_energy = 1.3
	sv.add_child(light)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-1, 1, 1.5)
	fill.light_color = Color(0.7, 0.8, 1.0)
	fill.light_energy = 0.8
	sv.add_child(fill)
	return svc

func _emit_start() -> void:
	if _points_used() == 0:
		return
	var santa_is_me := sel_santa == 1 or (sel_santa == 2 and randf() < 0.5)
	start_match.emit({
		"char_id": sel_char,
		"loc_id": sel_loc,
		"loadout": loadout.duplicate(),
		"santa_mode": santa_is_me,
		"prep_time": Defs.PREP_OPTIONS[sel_prep],
		"match_time": Defs.TIME_OPTIONS[sel_time],
	})

func _points_used() -> int:
	var used := 0
	for iid in loadout:
		used += int(loadout[iid]) * int(Defs.ITEMS[iid]["cost"])
	return used

func _default_loadout() -> void:
	if not loadout.is_empty():
		for iid in loadout.keys():
			var only: String = Defs.ITEMS[iid]["only_char"]
			if only != "" and only != sel_char:
				loadout.erase(iid)
		while _points_used() > SaveGame.pocket_points(sel_char):
			for iid in loadout.keys():
				if int(loadout[iid]) > 0:
					loadout[iid] = int(loadout[iid]) - 1
					break
		return
	loadout = {"shards": 2, "rope": 1, "oil": 1, "mousetrap": 1, "firecracker": 1}
	while _points_used() > SaveGame.pocket_points(sel_char):
		loadout["shards"] = maxi(int(loadout.get("shards", 0)) - 1, 0)
		if _points_used() > SaveGame.pocket_points(sel_char):
			loadout.erase("firecracker")

# ================================================================ МАГАЗИН

func _show_shop() -> void:
	_clear()
	_top_bar()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	UITheme.fancy_label(vb, "МАГАЗИН", 32, UITheme.ACCENT)
	var chars := HBoxContainer.new()
	chars.alignment = BoxContainer.ALIGNMENT_CENTER
	chars.add_theme_constant_override("separation", 6)
	vb.add_child(chars)
	for id in Defs.CHARACTERS:
		var cid: String = id
		var b := Button.new()
		b.text = Defs.CHARACTERS[id]["name"]
		b.toggle_mode = true
		b.button_pressed = id == sel_char
		b.pressed.connect(func():
			sel_char = cid
			_show_shop())
		chars.add_child(b)
	UITheme.fancy_label(vb, "Скины для: %s" % Defs.CHARACTERS[sel_char]["name"], 17)
	for skin_id in Defs.SKINS:
		var s: Dictionary = Defs.SKINS[skin_id]
		var sid: String = skin_id
		var owned := SaveGame.owns_skin(sel_char, sid)
		var active: bool = SaveGame.data["chars"][sel_char]["skin"] == sid
		var b := Button.new()
		if active:
			b.text = "%s — надет" % s["name"]
			b.disabled = true
		elif owned:
			b.text = "%s — надеть" % s["name"]
			b.pressed.connect(func():
				SaveGame.set_skin(sel_char, sid)
				_show_shop())
		else:
			b.text = "%s — купить за %d монет" % [s["name"], int(s["cost"])]
			b.disabled = SaveGame.coins() < int(s["cost"])
			b.pressed.connect(func():
				SaveGame.buy_skin(sel_char, sid)
				_show_shop())
		b.custom_minimum_size = Vector2(360, 40)
		vb.add_child(b)
	var perk := Button.new()
	if SaveGame.data.get("perk_pocket", false):
		perk.text = "Глубокие карманы (+1 очко) — куплено"
		perk.disabled = true
	else:
		perk.text = "Глубокие карманы (+1 очко всем) — %d монет" % Defs.PERK_POCKET_COST
		perk.disabled = SaveGame.coins() < Defs.PERK_POCKET_COST
		perk.pressed.connect(func():
			SaveGame.buy_perk_pocket()
			_show_shop())
	perk.custom_minimum_size = Vector2(360, 40)
	vb.add_child(perk)
	_btn(vb, "← Назад", _show_title)
