class_name UITheme
## Единый стиль UI: тёмно-синие полупрозрачные панели, золотой акцент, скругления.

const ACCENT := Color(1.0, 0.82, 0.35)
const RED := Color(0.92, 0.3, 0.28)
const TEXT := Color(0.95, 0.96, 1.0)

static func make() -> Theme:
	var t := Theme.new()
	# кнопки
	t.set_stylebox("normal", "Button", sb(Color(0.12, 0.16, 0.28, 0.92), 10, Color(1, 1, 1, 0.1)))
	t.set_stylebox("hover", "Button", sb(Color(0.18, 0.24, 0.4, 0.95), 10, Color(1.0, 0.82, 0.35, 0.7)))
	t.set_stylebox("pressed", "Button", sb(Color(0.09, 0.12, 0.2, 0.95), 10, Color(1.0, 0.82, 0.35, 0.9)))
	t.set_stylebox("disabled", "Button", sb(Color(0.1, 0.12, 0.18, 0.6), 10, Color(1, 1, 1, 0.04)))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", ACCENT)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.35))
	t.set_font_size("font_size", "Button", 17)
	# панели
	t.set_stylebox("panel", "PanelContainer", sb(Color(0.07, 0.09, 0.17, 0.85), 14, Color(1.0, 0.82, 0.35, 0.18)))
	# прогрессбары
	t.set_stylebox("background", "ProgressBar", sb(Color(0, 0, 0, 0.5), 7))
	t.set_stylebox("fill", "ProgressBar", sb(ACCENT, 7))
	# подписи
	t.set_color("font_color", "Label", TEXT)
	t.set_font_size("font_size", "Label", 16)
	return t

static func sb(bg: Color, radius: int, border := Color(0, 0, 0, 0), margin := 8.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	s.content_margin_left = margin + 4
	s.content_margin_right = margin + 4
	s.content_margin_top = margin
	s.content_margin_bottom = margin
	if border.a > 0.0:
		s.border_width_left = 2
		s.border_width_right = 2
		s.border_width_top = 2
		s.border_width_bottom = 2
		s.border_color = border
	return s

## Заголовок с обводкой.
static func fancy_label(parent: Node, text: String, size: int, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.1, 0.85))
	l.add_theme_constant_override("outline_size", maxi(size / 4, 6))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l
