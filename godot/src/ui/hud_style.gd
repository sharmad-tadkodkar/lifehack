class_name HudStyle
extends RefCounted
## Shared look for the HUD and the Esc menu (config/ui.cfg): colours, sizes, the display font
## (Michroma, a Microgramma / Eurostile Extended style face) for headings, numbers and keys, the
## body font (Rajdhani) for sentences, and small building blocks: labels, key caps, a step bar.

var c := {}
var s := {}
var t := {}
var frame := {}
var display_font: Font
var body_font: Font
var body_bold: Font


func _init() -> void:
	c = Config.section("ui", "colors")
	s = Config.section("ui", "sizes")
	t = Config.section("ui", "timing")
	frame = Config.section("ui", "frame")
	var fonts := Config.section("ui", "fonts")
	display_font = _font(str(fonts.display), int(fonts.display_spacing))
	body_font = _font(str(fonts.body), 0)
	body_bold = _font(str(fonts.body_bold), 0)


## A label. `display` uses the wide Michroma face (headings, values); otherwise Rajdhani.
## Text in the HUD colours gets a faint glow.
func label(text: String, size: int, color: Color, display := false, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", display_font if display else (body_bold if bold else body_font))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(color, float(frame.glow)))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	l.add_theme_constant_override("shadow_outline_size", int(frame.glow_size))
	return l


func panel(tag := "") -> ArPanel:
	return ArPanel.new(self, tag)


## A key in a small bracketed box: [E], [1], [Q].
func key_cap(key: String, color: Color) -> KeyCap:
	var cap := KeyCap.new()
	cap.color = color
	# square for one character, wider for words like ESC
	var text_width := display_font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, int(s.key_text)).x
	cap.custom_minimum_size = Vector2(maxf(int(s.key_cap), text_width + 14.0), int(s.key_cap))
	var l := label(key, int(s.key_text), color, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	cap.add_child(l)
	return cap


func step_bar(total: int) -> StepBar:
	var bar := StepBar.new()
	bar.total = total
	bar.color = c.accent
	bar.custom_minimum_size = Vector2(0, int(s.step_bar))
	return bar


func _font(path: String, spacing: int) -> Font:
	var base := load(path) as Font
	if base == null:
		push_error("[ui] font not found: %s" % path)
		base = ThemeDB.fallback_font
	var variation := FontVariation.new()
	variation.base_font = base
	variation.spacing_glyph = spacing
	return variation


## Framed key box.
class KeyCap extends Control:
	var color := Color.CYAN

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(color, 0.12))
		draw_rect(r, Color(color, 0.55), false, 1.0)
		var k := size.y * 0.3
		draw_polyline(PackedVector2Array([Vector2(0, k), Vector2.ZERO, Vector2(k, 0)]), color, 2.0)
		draw_polyline(PackedVector2Array([Vector2(size.x, size.y - k), size, Vector2(size.x - k, size.y)]), color, 2.0)


## Segmented progress bar: `done` of `total` segments lit.
class StepBar extends Control:
	var total := 7
	var done := 0
	var color := Color.CYAN

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_done(value: int) -> void:
		if value != done:
			done = value
			queue_redraw()

	func _draw() -> void:
		var gap := 4.0
		var w := (size.x - gap * (total - 1)) / maxf(total, 1)
		for i in total:
			var r := Rect2(i * (w + gap), 0, w, size.y)
			if i < done:
				draw_rect(r, Color(color, 0.85))
				draw_rect(r.grow(1.5), Color(color, 0.18), false, 2.0)
			else:
				draw_rect(r, Color(color, 0.08))
				draw_rect(r, Color(color, 0.3), false, 1.0)
