class_name Hud
extends CanvasLayer
## On-screen UI: title card, status (steps / time / mistakes), what's in hand, the spot prompt,
## the action menu, feedback toasts and the end summary. Built in code; colours, sizes and
## timings come from config/ui.cfg. The HUD only displays, it never decides anything.

var _c := {}
var _s := {}
var _t := {}
var _bold: FontVariation

var _title: Control
var _status: Label
var _held: Label
var _prompt: Label
var _menu: PanelContainer
var _menu_title: Label
var _menu_rows: VBoxContainer
var _toast: PanelContainer
var _toast_label: Label
var _toast_timer: SceneTreeTimer
var _summary: PanelContainer
var _summary_body: VBoxContainer


func _ready() -> void:
	layer = 10
	_load_style()
	_bold = FontVariation.new()
	_bold.base_font = ThemeDB.fallback_font
	_bold.variation_embolden = 0.9
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_title(root)
	_build_status(root)
	_build_prompt(root)
	_build_menu(root)
	_build_toast(root)
	_build_summary(root)


func _load_style() -> void:
	_c = Config.section("ui", "colors")
	_s = Config.section("ui", "sizes")
	_t = Config.section("ui", "timing")


# --- public API -----------------------------------------------------------------------

func show_title(on: bool) -> void:
	if on:
		_title.modulate.a = 1.0
		_title.visible = true
	else:
		var tween := create_tween()
		tween.tween_property(_title, "modulate:a", 0.0, _t.title_fade)
		tween.tween_callback(_title.hide)


func update_status(model: ProcedureModel, seconds: float) -> void:
	_status.text = "%s\nSTEPS  %d / %d\nTIME   %s\nMISTAKES  %d\n\nESC  MENU" % [
		model.data.title.to_upper(), model.completed.size(), model.data.steps.size(),
		format_time(seconds), model.mistakes.size()]
	var held := model.held_item()
	_held.text = "IN HAND   " + (model.data.item_label(held) if held != "" else "nothing")
	_status.get_parent().visible = true
	_held.get_parent().visible = true


func show_prompt(text: String) -> void:
	_prompt.text = text
	_prompt.get_parent().visible = text != ""


func show_menu(title: String, rows: Array[String], footer: String) -> void:
	_menu_title.text = title.to_upper()
	for child in _menu_rows.get_children():
		child.queue_free()
	for i in rows.size():
		_menu_rows.add_child(_row("%d" % (i + 1), rows[i]))
	_menu_rows.add_child(_row("Q", footer, true))
	_menu.visible = true


func hide_menu() -> void:
	_menu.visible = false


func toast(result: StepResult) -> void:
	if result.message == "":
		return
	var color: Color = _c.accent if result.mistake else (_c.good if result.ok else _c.text)
	var tag := "MISTAKE   " if result.mistake else ""
	_toast_label.text = tag + result.message
	_toast_label.add_theme_color_override("font_color", color)
	(_toast.get_theme_stylebox("panel") as StyleBoxFlat).border_color = color
	_toast.visible = true
	var seconds: float = _t.mistake_toast_seconds if result.mistake else _t.toast_seconds
	_toast_timer = get_tree().create_timer(seconds)
	var timer := _toast_timer
	timer.timeout.connect(func() -> void:
		if _toast_timer == timer:
			_toast.visible = false)


func show_summary(model: ProcedureModel, seconds: float) -> void:
	hide_menu()
	show_prompt("")
	for child in _summary_body.get_children():
		child.queue_free()
	_summary_body.add_child(_label("WHEEL CHANGED", _s.summary_title, _c.accent, true))
	_summary_body.add_child(_label("Time  %s      Mistakes  %d" % [format_time(seconds), model.mistakes.size()], _s.menu, _c.text))
	if model.mistakes.is_empty():
		_summary_body.add_child(_label("Clean run. Every step in the right order.", _s.body, _c.good))
	else:
		_summary_body.add_child(_label("What went wrong:", _s.body, _c.dim))
		for m: Dictionary in model.mistakes.slice(0, 6):
			var line := _label("•  " + str(m.message), _s.small, _c.text)
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			line.custom_minimum_size.x = 640
			_summary_body.add_child(line)
	_summary_body.add_child(_label("E   play again", _s.body, _c.accent, true))
	_summary_body.add_child(_label("ESC   menu", _s.body, _c.dim, true))
	_summary.visible = true


static func format_time(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d" % [s / 60, s % 60]


# --- construction ----------------------------------------------------------------------

func _panel(border := false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = _c.panel
	box.set_corner_radius_all(6)
	box.set_content_margin_all(14)
	if border:
		box.border_color = _c.panel_border
		box.border_width_left = 3
	return box


func _label(text: String, size: int, color: Color, bold := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if bold:
		label.add_theme_font_override("font", _bold)
	return label


func _row(key: String, text: String, dim := false) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var k := _label(key, _s.menu, _c.accent, true)
	k.custom_minimum_size.x = 22
	row.add_child(k)
	row.add_child(_label(text, _s.menu, _c.dim if dim else _c.text))
	return row


func _anchored_panel(root: Control, preset: Control.LayoutPreset, border := false) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel(border))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, 28)
	_set_grow(panel, preset)
	panel.visible = false
	return panel


## Panels grow away from the screen edge they are pinned to.
func _set_grow(control: Control, preset: Control.LayoutPreset) -> void:
	var h := Control.GROW_DIRECTION_END
	var v := Control.GROW_DIRECTION_END
	match preset:
		Control.PRESET_BOTTOM_LEFT:
			v = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_CENTER_BOTTOM:
			h = Control.GROW_DIRECTION_BOTH
			v = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_CENTER_RIGHT:
			h = Control.GROW_DIRECTION_BEGIN
			v = Control.GROW_DIRECTION_BOTH
		Control.PRESET_CENTER:
			h = Control.GROW_DIRECTION_BOTH
			v = Control.GROW_DIRECTION_BOTH
		Control.PRESET_CENTER_TOP:
			h = Control.GROW_DIRECTION_BOTH
	control.grow_horizontal = h
	control.grow_vertical = v


func _build_title(root: Control) -> void:
	var panel := PanelContainer.new()
	var style := _panel()
	style.set_content_margin_all(26)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 60)
	_set_grow(panel, Control.PRESET_CENTER_TOP)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	for line in [["OH S#IT", _s.title, _c.accent], ["THE LIFE SKILLS GAME", _s.subtitle, _c.text],
			["FLAT TIRE  ·  NIGHT SHIFT", _s.small, _c.dim]]:
		var label := _label(line[0], line[1], line[2], true)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(label)
	_title = panel


func _build_status(root: Control) -> void:
	var panel := _anchored_panel(root, Control.PRESET_TOP_LEFT, true)
	_status = _label("", _s.small, _c.text, true)
	panel.add_child(_status)
	var held_panel := _anchored_panel(root, Control.PRESET_BOTTOM_LEFT)
	_held = _label("", _s.body, _c.text, true)
	held_panel.add_child(_held)


func _build_prompt(root: Control) -> void:
	var panel := _anchored_panel(root, Control.PRESET_CENTER_BOTTOM)
	_prompt = _label("", _s.menu, _c.text, true)
	panel.add_child(_prompt)


func _build_menu(root: Control) -> void:
	_menu = _anchored_panel(root, Control.PRESET_CENTER_RIGHT, true)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_menu.add_child(box)
	_menu_title = _label("", _s.small, _c.dim, true)
	box.add_child(_menu_title)
	_menu_rows = VBoxContainer.new()
	_menu_rows.add_theme_constant_override("separation", 6)
	box.add_child(_menu_rows)


func _build_toast(root: Control) -> void:
	_toast = PanelContainer.new()
	_toast.add_theme_stylebox_override("panel", _panel(true))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toast)
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.anchor_top = 1.0
	_toast.anchor_bottom = 1.0
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast.offset_bottom = -110
	_toast_label = _label("", _s.body, _c.text, true)
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.custom_minimum_size.x = 620
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_child(_toast_label)
	_toast.visible = false


func _build_summary(root: Control) -> void:
	_summary = _anchored_panel(root, Control.PRESET_CENTER_RIGHT, true)
	_summary_body = VBoxContainer.new()
	_summary_body.add_theme_constant_override("separation", 12)
	_summary.add_child(_summary_body)
