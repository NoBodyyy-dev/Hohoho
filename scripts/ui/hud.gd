class_name Hud
extends CanvasLayer
## Внутриигровой интерфейс: прицел, таймер, карманы, панель выбора ловушек,
## шкала поимки, QTE, мешок, результат.

signal quit_to_menu

var root: Control
var phase_label: Label
var timer_label: Label
var presents_label: Label
var pockets_box: HBoxContainer
var capture_bar: ProgressBar
var capture_hint: Label
var msg_box: VBoxContainer
var sack_panel: PanelContainer
var sack_bar: ProgressBar
var qte_panel: PanelContainer
var qte_title: Label
var qte_progress: ProgressBar
var qte_bar: ProgressBar
var hint_label: Label
var result_panel: Control
var pause_panel: Control
var crosshair: Panel
var trap_opts_panel: PanelContainer
var trap_opts_box: VBoxContainer
var hotbar_slots: Array = []
var hotbar_order: Array = []
var hotbar_sel := -1
var status_panel: PanelContainer
var status_label: Label
var combo_panel: PanelContainer
var combo_tier_label: Label
var combo_chain_label: Label
var combo_style_label: Label
var combo_bar: ProgressBar

func _ready() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.make()
	add_child(root)

	# виньетка по краям
	var vig := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0))
	grad.set_color(1, Color(0, 0, 0, 0.32))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 1.05)
	vig.texture = gt
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vig)

	# верхняя панель: фаза + таймер
	var top_panel := PanelContainer.new()
	top_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top_panel.position.y = 10
	top_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(top_panel)
	var top := VBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top_panel.add_child(top)
	phase_label = UITheme.fancy_label(top, "", 19, UITheme.ACCENT)
	timer_label = UITheme.fancy_label(top, "0:00", 30)

	# подарки — слева сверху
	var pres_panel := PanelContainer.new()
	pres_panel.position = Vector2(14, 14)
	root.add_child(pres_panel)
	presents_label = UITheme.fancy_label(pres_panel, "", 17)

	hint_label = UITheme.fancy_label(root, "", 14, Color(1, 1, 1, 0.7))
	hint_label.position = Vector2(16, 64)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hint_label.text = "F — режим ловушек | SHIFT — спринт"

	# прицел
	crosshair = Panel.new()
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(1, 1, 1, 0.85)
	cs.corner_radius_top_left = 4
	cs.corner_radius_top_right = 4
	cs.corner_radius_bottom_left = 4
	cs.corner_radius_bottom_right = 4
	crosshair.add_theme_stylebox_override("panel", cs)
	crosshair.custom_minimum_size = Vector2(5, 5)
	crosshair.position = Vector2(-2.5, -2.5)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(crosshair)

	# шкала поимки
	capture_bar = ProgressBar.new()
	capture_bar.max_value = 100
	capture_bar.custom_minimum_size = Vector2(380, 24)
	capture_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	capture_bar.position = Vector2(-190, 120)
	capture_bar.visible = false
	capture_bar.show_percentage = false
	var fill := UITheme.sb(UITheme.RED, 7)
	capture_bar.add_theme_stylebox_override("fill", fill)
	root.add_child(capture_bar)
	capture_hint = UITheme.fancy_label(root, "ЛОВИМ САНТУ! Стой рядом с ним!", 17, UITheme.ACCENT)
	capture_hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	capture_hint.position = Vector2(-140, 96)
	capture_hint.visible = false

	# карманы
	pockets_box = HBoxContainer.new()
	pockets_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	pockets_box.position.y = -66
	pockets_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pockets_box.alignment = BoxContainer.ALIGNMENT_CENTER
	pockets_box.add_theme_constant_override("separation", 6)
	root.add_child(pockets_box)

	# сообщения
	msg_box = VBoxContainer.new()
	msg_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	msg_box.position.y = -170
	msg_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	msg_box.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(msg_box)

	# панель вариантов ловушки (режим F)
	trap_opts_panel = PanelContainer.new()
	trap_opts_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	trap_opts_panel.position.y = -110
	trap_opts_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	trap_opts_panel.visible = false
	trap_opts_box = VBoxContainer.new()
	trap_opts_box.alignment = BoxContainer.ALIGNMENT_CENTER
	trap_opts_panel.add_child(trap_opts_box)
	root.add_child(trap_opts_panel)

	# статус Санты — справа сверху
	status_panel = PanelContainer.new()
	status_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	status_panel.position = Vector2(-14, 14)
	status_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	status_panel.visible = false
	status_label = UITheme.fancy_label(status_panel, "", 15, Color(1, 0.8, 0.4))
	root.add_child(status_panel)

	# ХАОС-КОМБО — справа по центру
	combo_panel = PanelContainer.new()
	combo_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	combo_panel.position = Vector2(-14, 220)
	combo_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	combo_panel.add_theme_stylebox_override("panel", UITheme.sb(Color(0.12, 0.08, 0.18, 0.82), 10, Color(1, 0.7, 0.3, 0.35), 2.0))
	combo_panel.visible = false
	var cvb := VBoxContainer.new()
	cvb.alignment = BoxContainer.ALIGNMENT_CENTER
	cvb.add_theme_constant_override("separation", 2)
	combo_panel.add_child(cvb)
	combo_tier_label = UITheme.fancy_label(cvb, "", 26, UITheme.ACCENT)
	combo_tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	combo_chain_label = UITheme.fancy_label(cvb, "", 15, Color(1, 1, 1, 0.85))
	combo_chain_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	combo_style_label = UITheme.fancy_label(cvb, "", 16, Color(0.7, 1, 0.7))
	combo_style_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	combo_bar = ProgressBar.new()
	combo_bar.max_value = 1.0
	combo_bar.show_percentage = false
	combo_bar.custom_minimum_size = Vector2(180, 6)
	combo_bar.add_theme_stylebox_override("fill", UITheme.sb(UITheme.ACCENT, 3))
	cvb.add_child(combo_bar)
	root.add_child(combo_panel)

	_build_sack_panel()
	_build_qte_panel()

# ---------------------------------------------------------------- ХАОС-КОМБО

## Показать/обновить панель текущей цепи. named != "" — засчитана именованная связка.
func show_combo(chain: Array, mult: int, style: int, tier: Dictionary, named: String) -> void:
	combo_panel.visible = true
	combo_panel.modulate.a = 1.0
	var tier_name: String = tier["name"]
	combo_tier_label.text = "%s ×%d" % [tier_name, mult] if tier_name != "" else "×%d" % mult
	combo_tier_label.add_theme_color_override("font_color", tier["color"])
	combo_chain_label.text = " → ".join(chain)
	combo_style_label.text = "+%d стиля" % style
	# пульс при каждом звене
	combo_panel.pivot_offset = combo_panel.size
	var s := 1.35 if named != "" else 1.15
	var tw := combo_panel.create_tween()
	tw.tween_property(combo_panel, "scale", Vector2(s, s), 0.08).set_trans(Tween.TRANS_BACK)
	tw.tween_property(combo_panel, "scale", Vector2.ONE, 0.18)

func update_combo_timer(frac: float) -> void:
	combo_bar.value = clampf(frac, 0.0, 1.0)

func hide_combo() -> void:
	var tw := combo_panel.create_tween()
	tw.tween_property(combo_panel, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func():
		combo_panel.visible = false
		combo_panel.modulate.a = 1.0)

## Показать активные статус-эффекты Санты (стан, головокружение, мокрый…).
func set_santa_status(effects: Array) -> void:
	if effects.is_empty():
		status_panel.visible = false
		return
	status_panel.visible = true
	status_label.text = "Грабитель: " + "  ".join(effects)

# ---------------------------------------------------------------- ОБНОВЛЕНИЯ

func set_phase(text: String) -> void:
	phase_label.text = text

func set_timer(sec: float) -> void:
	var s := maxi(int(ceil(sec)), 0)
	timer_label.text = "%d:%02d" % [s / 60, s % 60]
	timer_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4) if s <= 30 else UITheme.TEXT)

func set_presents(cur: int, total: int) -> void:
	presents_label.text = "💎 Украдено: %d / %d" % [cur, total]

## Хотбар-слоты предметов (как в Minecraft). В режиме ловушек ими выбираешь, что ставить.
func set_pockets(loadout: Dictionary) -> void:
	for c in pockets_box.get_children():
		c.queue_free()
	hotbar_slots = []
	hotbar_order = []
	var i := 0
	for item_id in loadout:
		i += 1
		var n := int(loadout[item_id])
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(108, 58)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 0)
		slot.add_child(vb)
		var top := HBoxContainer.new()
		vb.add_child(top)
		var num := Label.new()
		num.text = str(i) if i <= 9 else "•"
		num.add_theme_font_size_override("font_size", 12)
		num.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
		top.add_child(num)
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(spacer)
		var cnt := Label.new()
		cnt.text = "×%d" % n
		cnt.add_theme_font_size_override("font_size", 12)
		top.add_child(cnt)
		var name_l := Label.new()
		name_l.text = Defs.ITEMS[item_id]["name"]
		name_l.add_theme_font_size_override("font_size", 12)
		name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(name_l)
		slot.set_meta("count", n)
		slot.set_meta("name_l", name_l)
		slot.set_meta("cnt_l", cnt)
		pockets_box.add_child(slot)
		hotbar_slots.append(slot)
		hotbar_order.append(item_id)
	_restyle_hotbar()

## Подсветить выбранный слот хотбара (idx в порядке hotbar_order).
func set_hotbar_sel(idx: int) -> void:
	hotbar_sel = idx
	_restyle_hotbar()

func _restyle_hotbar() -> void:
	for i in hotbar_slots.size():
		var slot: PanelContainer = hotbar_slots[i]
		var n: int = slot.get_meta("count")
		var selected := i == hotbar_sel
		var bg := Color(0.16, 0.19, 0.3, 0.92) if selected else Color(0.09, 0.11, 0.2, 0.82)
		var border := Color(1.0, 0.82, 0.35, 0.95) if selected else Color(1, 1, 1, 0.08)
		var bw := 3.0 if selected else 1.0
		slot.add_theme_stylebox_override("panel", UITheme.sb(bg, 8, border, bw))
		var a := 1.0 if n > 0 else 0.32
		(slot.get_meta("name_l") as Label).add_theme_color_override("font_color", Color(1, 1, 1, a))
		(slot.get_meta("cnt_l") as Label).add_theme_color_override("font_color",
			Color(0.7, 1, 0.7, 1) if n > 0 else Color(1, 0.5, 0.5, 0.6))
		slot.pivot_offset = slot.size * 0.5
		slot.scale = Vector2(1.12, 1.12) if selected else Vector2.ONE

func update_capture(v: float) -> void:
	capture_bar.visible = v > 0.5
	capture_hint.visible = capture_bar.visible
	capture_bar.value = v

func show_message(text: String, color := Color.WHITE) -> void:
	var l := UITheme.fancy_label(msg_box, text, 17, color)
	var tw := l.create_tween()
	tw.tween_interval(2.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.9)
	tw.tween_callback(l.queue_free)

## Крупный анонс по центру: вылетает, висит, тает.
func big_announce(text: String, color := UITheme.ACCENT) -> void:
	var l := UITheme.fancy_label(root, text, 52, color)
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.grow_vertical = Control.GROW_DIRECTION_BOTH
	l.position.y -= 120
	l.pivot_offset = l.size * 0.5
	l.scale = Vector2(0.4, 0.4)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.1)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)

## Тряска экрана (испуг от «ХО-ХО-ХО» и т.п.).
func shake(strength := 14.0) -> void:
	var tw := root.create_tween()
	for i in 6:
		var off := Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
		tw.tween_property(root, "position", off, 0.05)
	tw.tween_property(root, "position", Vector2.ZERO, 0.06)

func set_crosshair(trap_mode: bool) -> void:
	var cs: StyleBoxFlat = crosshair.get_theme_stylebox("panel")
	if trap_mode:
		crosshair.custom_minimum_size = Vector2(9, 9)
		crosshair.position = Vector2(-4.5, -4.5)
		cs.bg_color = Color(0.4, 1.0, 0.5, 0.9)
	else:
		crosshair.custom_minimum_size = Vector2(5, 5)
		crosshair.position = Vector2(-2.5, -2.5)
		cs.bg_color = Color(1, 1, 1, 0.85)

# ---------------------------------------------------------------- ВАРИАНТЫ ЛОВУШЕК

func show_trap_options(labels: Array, sel: int) -> void:
	for c in trap_opts_box.get_children():
		c.queue_free()
	if labels.is_empty():
		var l := Label.new()
		l.text = "Сюда ничего не поставить"
		l.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		trap_opts_box.add_child(l)
	else:
		var hint := Label.new()
		hint.text = "колесо — выбор | ЛКМ — поставить"
		hint.add_theme_font_size_override("font_size", 12)
		hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		trap_opts_box.add_child(hint)
		for i in labels.size():
			var l := Label.new()
			l.text = ("»  %s  «" % labels[i]) if i == sel else str(labels[i])
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.add_theme_font_size_override("font_size", 18 if i == sel else 14)
			l.add_theme_color_override("font_color", UITheme.ACCENT if i == sel else Color(1, 1, 1, 0.6))
			trap_opts_box.add_child(l)
	trap_opts_panel.visible = true

func hide_trap_options() -> void:
	trap_opts_panel.visible = false

## Контекстная подсказка у прицела: что сделает установка сейчас (title) + эффект/этап (sub).
## ok=false — красный (сюда нельзя).
func show_context(title: String, sub: String, ok: bool) -> void:
	for c in trap_opts_box.get_children():
		c.queue_free()
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 19)
	t.add_theme_color_override("font_color", UITheme.ACCENT if ok else Color(1.0, 0.4, 0.4))
	trap_opts_box.add_child(t)
	if sub != "":
		var s := Label.new()
		s.text = sub
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.add_theme_font_size_override("font_size", 13)
		s.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
		trap_opts_box.add_child(s)
	trap_opts_panel.visible = true

# ---------------------------------------------------------------- МЕШОК

func _build_sack_panel() -> void:
	sack_panel = PanelContainer.new()
	sack_panel.set_anchors_preset(Control.PRESET_CENTER)
	sack_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	sack_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	sack_panel.visible = false
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	sack_panel.add_child(vb)
	UITheme.fancy_label(vb, "ТЕБЯ СВЯЗАЛИ!", 28, Color(1, 0.45, 0.35))
	UITheme.fancy_label(vb, "ЖМИ ПРОБЕЛ!", 22, UITheme.ACCENT)
	sack_bar = ProgressBar.new()
	sack_bar.max_value = 1.0
	sack_bar.custom_minimum_size = Vector2(320, 26)
	sack_bar.show_percentage = false
	vb.add_child(sack_bar)
	root.add_child(sack_panel)

func set_sacked(sacked: bool, progress: float) -> void:
	sack_panel.visible = sacked
	sack_bar.value = progress
	crosshair.visible = not sacked

# ---------------------------------------------------------------- QTE

func _build_qte_panel() -> void:
	qte_panel = PanelContainer.new()
	qte_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	qte_panel.position.y = -240
	qte_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	qte_panel.visible = false
	var vb := VBoxContainer.new()
	vb.custom_minimum_size.x = 380
	vb.add_theme_constant_override("separation", 6)
	qte_panel.add_child(vb)
	qte_title = UITheme.fancy_label(vb, "", 18, UITheme.ACCENT)
	qte_progress = ProgressBar.new()
	qte_progress.max_value = 1.0
	qte_progress.show_percentage = false
	qte_progress.custom_minimum_size.y = 12
	vb.add_child(qte_progress)
	var hint := UITheme.fancy_label(vb, "ПРОБЕЛ, когда бегунок в центре!", 13, Color(0.75, 1, 0.75))
	hint.name = "QteHint"
	qte_bar = ProgressBar.new()
	qte_bar.max_value = 1.0
	qte_bar.show_percentage = false
	qte_bar.custom_minimum_size.y = 18
	vb.add_child(qte_bar)
	root.add_child(qte_panel)

func show_qte(title: String) -> void:
	qte_panel.visible = true
	qte_title.text = title
	# для действий без QTE-бегунка (обыск/взлом) прячем подсказку про пробел
	var is_action := not title.begins_with("Ставим")
	qte_bar.visible = not is_action
	var hint := qte_panel.find_child("QteHint", true, false)
	if hint != null:
		hint.visible = not is_action

func update_qte(progress: float, value: float, locked: bool) -> void:
	qte_progress.value = clampf(progress, 0, 1)
	qte_bar.value = value
	qte_bar.modulate = Color(0.5, 1, 0.5) if locked else Color.WHITE

func hide_qte() -> void:
	qte_panel.visible = false

# ---------------------------------------------------------------- РЕЗУЛЬТАТ / ПАУЗА

func _overlay() -> Control:
	var over := Control.new()
	over.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dark := ColorRect.new()
	dark.color = Color(0.02, 0.03, 0.08, 0.6)
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	over.add_child(dark)
	root.add_child(over)
	return over

func show_result(title: String, sub: String, coins: int, xp: int, title_color := UITheme.ACCENT) -> void:
	if is_instance_valid(result_panel):
		return
	result_panel = _overlay()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_panel.add_child(center)
	var panel := PanelContainer.new()
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(460, 0)
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)
	var t := UITheme.fancy_label(vb, title, 40, title_color)
	t.scale = Vector2(0.6, 0.6)
	t.pivot_offset = Vector2(230, 25)
	var tw := t.create_tween()
	tw.tween_property(t, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var s := UITheme.fancy_label(vb, sub, 17)
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.fancy_label(vb, "+%d монет   +%d опыта" % [coins, xp], 20, Color(0.7, 1, 0.7))
	var b := Button.new()
	b.text = "В МЕНЮ"
	b.custom_minimum_size.y = 46
	b.pressed.connect(func(): quit_to_menu.emit())
	vb.add_child(b)
	center.add_child(panel)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func toggle_pause() -> bool:
	if is_instance_valid(result_panel):
		return false
	if is_instance_valid(pause_panel):
		pause_panel.queue_free()
		pause_panel = null
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return false
	pause_panel = _overlay()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_panel.add_child(center)
	var panel := PanelContainer.new()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.custom_minimum_size.x = 280
	panel.add_child(vb)
	UITheme.fancy_label(vb, "ПАУЗА", 28)
	var resume := Button.new()
	resume.text = "Продолжить"
	resume.pressed.connect(func(): toggle_pause())
	vb.add_child(resume)
	var quit := Button.new()
	quit.text = "Выйти в меню"
	quit.pressed.connect(func(): quit_to_menu.emit())
	vb.add_child(quit)
	center.add_child(panel)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return true
