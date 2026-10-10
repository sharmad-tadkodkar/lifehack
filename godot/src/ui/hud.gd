class_name Hud
extends CanvasLayer
## On-screen UI in an AR heads-up style: title card, task status (steps / time / mistakes), what's
## in hand, the spot prompt, the action menu, feedback toasts and the end summary. Built in code
## from HudStyle / ArPanel; colours, fonts, sizes and timings come from config/ui.cfg.
## The HUD only displays, it never decides anything.

var style: HudStyle

var _title: Control
var _status: ArPanel
var _task: Label
var _steps: HudStyle.StepBar
var _step_count: Label
var _time: Label
var _mistakes: Label
var _held_panel: ArPanel
var _held: Label
var _prompt_panel: ArPanel
var _prompt_key: HudStyle.KeyCap
var _prompt: Label
var _menu: ArPanel
var _menu_rows: VBoxContainer
var _toast: ArPanel
var _toast_label: Label
var _toast_timer: SceneTreeTimer
var _summary: ArPanel
var _summary_body: VBoxContainer


func _ready() -> void:
	layer = 10
	style = HudStyle.new()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_title(root)
	_build_status(root)
	_build_held(root)
	_build_prompt(root)
	_build_menu(root)
	_build_toast(root)
	_build_summary(root)


# --- public API -----------------------------------------------------------------------

func show_title(on: bool) -> void:
	if on:
		_title.modulate.a = 1.0
		_title.visible = true
	else:
		var tween := create_tween()
		tween.tween_property(_title, "modulate:a", 0.0, style.t.title_fade)
		tween.tween_callback(_title.hide)


func update_status(model: ProcedureModel, seconds: float) -> void:
	_task.text = model.data.title.to_upper()
	_steps.total = model.data.steps.size()
	_steps.set_done(model.completed.size())
	_step_count.text = "%d / %d" % [model.completed.size(), model.data.steps.size()]
	_time.text = format_time(seconds)
	_mistakes.text = "%d" % model.mistakes.size()
	_mistakes.add_theme_color_override("font_color", style.c.warn if model.mistakes.size() > 0 else style.c.text)
	var held := model.held_item()
	_held.text = model.data.item_label(held).to_upper() if held != "" else "EMPTY"
	_held.add_theme_color_override("font_color", style.c.text if held != "" else style.c.dim)
	_status.visible = true
	_held_panel.visible = true


func show_prompt(text: String) -> void:
	# prompts arrive as "E    Location"; the key goes in its own cap
	var parts := text.strip_edges().split(" ", false, 1)
	var keyed := parts.size() == 2 and parts[0].length() == 1
	_prompt_key.visible = keyed
	(_prompt_key.get_child(0) as Label).text = parts[0] if keyed else ""
	_prompt.text = (parts[1].strip_edges() if keyed else text).to_upper()
	_prompt_panel.visible = text != ""


func show_menu(title: String, rows: Array[String], footer: String) -> void:
	_menu.tag = title.to_upper()
	_menu.queue_redraw()
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
	var color: Color = style.c.warn if result.mistake else (style.c.good if result.ok else style.c.accent)
	_toast.tag = "WARNING" if result.mistake else ("CONFIRMED" if result.ok else "NOTICE")
	_toast.set_color(color)
	_toast_label.text = result.message
	_toast_label.add_theme_color_override("font_color", style.c.text)
	_toast.visible = false
	_toast.visible = true
	var seconds: float = style.t.mistake_toast_seconds if result.mistake else style.t.toast_seconds
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
	_summary_body.add_child(style.label("WHEEL CHANGED", style.s.summary_title, style.c.accent, true))
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 36)
	stats.add_child(_stat("TIME", format_time(seconds), style.c.text))
	stats.add_child(_stat("MISTAKES", "%d" % model.mistakes.size(), style.c.warn if model.mistakes.size() > 0 else style.c.good))
	_summary_body.add_child(stats)
	if model.mistakes.is_empty():
		_summary_body.add_child(style.label("Clean run. Every step in the right order.", style.s.body, style.c.good, false, true))
	else:
		_summary_body.add_child(style.label("INCIDENT LOG", style.s.tag, style.c.dim, true))
		for m: Dictionary in model.mistakes.slice(0, 6):
			var line := style.label("›  " + str(m.message), style.s.small, style.c.text)
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			line.custom_minimum_size.x = 640
			_summary_body.add_child(line)
	var keys := HBoxContainer.new()
	keys.add_theme_constant_override("separation", 12)
	keys.add_child(style.key_cap("E", style.c.accent))
	keys.add_child(style.label("PLAY AGAIN", style.s.small, style.c.text, true))
	keys.add_child(_spacer(18, 0))
	keys.add_child(style.key_cap("ESC", style.c.dim))
	keys.add_child(style.label("MENU", style.s.small, style.c.dim, true))
	_summary_body.add_child(keys)
	_summary.visible = true


static func format_time(seconds: float) -> String:
	var sec := int(seconds)
	return "%d:%02d" % [sec / 60, sec % 60]


# --- construction ----------------------------------------------------------------------

func _row(key: String, text: String, dim := false) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.add_child(style.key_cap(key, style.c.dim if dim else style.c.accent))
	var l := style.label(text, style.s.menu, style.c.dim if dim else style.c.text, false, true)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	return row


func _stat(name: String, value: String, color: Color) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.add_child(style.label(name, style.s.tag, style.c.dim, true))
	box.add_child(style.label(value, style.s.stat, color, true))
	return box


func _spacer(w: int, h: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(w, h)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


func _place(root: Control, panel: Control, preset: Control.LayoutPreset, edge := 28) -> void:
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, edge)
	_set_grow(panel, preset)
	panel.visible = false


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
	var panel := style.panel("FIELD TRAINING // 01")
	panel.margin = 30.0
	(panel.get_theme_stylebox("panel") as StyleBoxEmpty).set_content_margin_all(30)
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 60)
	_set_grow(panel, Control.PRESET_CENTER_TOP)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	for line in [["OH S#IT", style.s.title, style.c.brand, true], ["THE LIFE SKILLS GAME", style.s.subtitle, style.c.text, true],
			["FLAT TIRE  ·  NIGHT SHIFT", style.s.small, style.c.dim, true]]:
		var l := style.label(line[0], line[1], line[2], line[3])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)
	_title = panel


func _build_status(root: Control) -> void:
	_status = style.panel("SYS // TASK")
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size.x = int(style.s.status_width)
	_status.add_child(box)
	_task = style.label("", style.s.small, style.c.text, true)
	box.add_child(_task)
	var steps_row := HBoxContainer.new()
	steps_row.add_theme_constant_override("separation", 10)
	_steps = style.step_bar(7)
	_steps.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_steps.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	steps_row.add_child(_steps)
	_step_count = style.label("", style.s.small, style.c.accent, true)
	steps_row.add_child(_step_count)
	box.add_child(steps_row)
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 22)
	var time_box := _stat("TIME", "0:00", style.c.text)
	_time = time_box.get_child(1)
	stats.add_child(time_box)
	var mistakes_box := _stat("MISTAKES", "0", style.c.text)
	_mistakes = mistakes_box.get_child(1)
	stats.add_child(mistakes_box)
	box.add_child(stats)
	var hint := HBoxContainer.new()
	hint.add_theme_constant_override("separation", 8)
	hint.add_child(style.key_cap("ESC", style.c.dim))
	var hint_label := style.label("MENU", style.s.tag, style.c.dim, true)
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_child(hint_label)
	box.add_child(hint)
	_place(root, _status, Control.PRESET_TOP_LEFT)


func _build_held(root: Control) -> void:
	_held_panel = style.panel("IN HAND")
	_held = style.label("", style.s.menu, style.c.text, true)
	_held.custom_minimum_size.x = 200
	_held_panel.add_child(_held)
	_place(root, _held_panel, Control.PRESET_BOTTOM_LEFT)


func _build_prompt(root: Control) -> void:
	_prompt_panel = style.panel("INTERACT")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_prompt_key = style.key_cap("E", style.c.accent)
	row.add_child(_prompt_key)
	_prompt = style.label("", style.s.menu, style.c.text, true)
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_prompt)
	_prompt_panel.add_child(row)
	_place(root, _prompt_panel, Control.PRESET_CENTER_BOTTOM)


func _build_menu(root: Control) -> void:
	_menu = style.panel("ACTIONS")
	_menu_rows = VBoxContainer.new()
	_menu_rows.add_theme_constant_override("separation", 8)
	_menu.add_child(_menu_rows)
	_place(root, _menu, Control.PRESET_CENTER_RIGHT)


func _build_toast(root: Control) -> void:
	_toast = style.panel("NOTICE")
	_toast_label = style.label("", style.s.body, style.c.text, false, true)
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.custom_minimum_size.x = int(style.s.toast_width)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_child(_toast_label)
	root.add_child(_toast)
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.anchor_top = 1.0
	_toast.anchor_bottom = 1.0
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast.offset_bottom = -120
	_toast.visible = false


func _build_summary(root: Control) -> void:
	_summary = style.panel("MISSION REPORT")
	_summary_body = VBoxContainer.new()
	_summary_body.add_theme_constant_override("separation", 14)
	_summary.add_child(_summary_body)
	_place(root, _summary, Control.PRESET_CENTER_RIGHT)
