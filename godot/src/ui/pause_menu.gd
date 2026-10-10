class_name PauseMenu
extends CanvasLayer
## The Esc menu: pauses the game and offers Resume, Restart, the voice and music switches, and
## Quit. Pick with 1-5, the arrow keys and Enter, or the mouse; Esc (or Q) resumes. Built in code
## in the HUD's AR style (HudStyle / ArPanel). It only reports the choice; Main restarts or quits.

signal restart_requested
signal quit_requested

const ROWS := ["Resume", "Restart", "Voice", "Music", "Quit"]

var is_open := false

var _style: HudStyle
var _c := {}
var _s := {}
var _buttons: Array[Button] = []


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_style = HudStyle.new()
	_c = _style.c
	_s = _style.s
	_build()
	visible = false


func open() -> void:
	if is_open:
		return
	is_open = true
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_labels()
	_buttons[0].grab_focus()
	Sfx.play_ui("ui_move")


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	get_tree().paused = false


## 0 resume, 1 restart, 2 voice on/off, 3 music on/off, 4 quit
func choose(index: int) -> void:
	Sfx.play_ui("ui_select")
	match index:
		0:
			close()
		1:
			close()
			restart_requested.emit()
		2:
			Sfx.set_voice_enabled(not Sfx.voice_enabled)
			_refresh_labels()
		3:
			Sfx.set_music_enabled(not Sfx.music_enabled)
			_refresh_labels()
		4:
			quit_requested.emit()


func _refresh_labels() -> void:
	for i in ROWS.size():
		var text: String = ROWS[i]
		if text == "Voice":
			text = "Voice    %s" % ("on" if Sfx.voice_enabled else "off")
		elif text == "Music":
			text = "Music    %s" % ("on" if Sfx.music_enabled else "off")
		_buttons[i].text = text.to_upper()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"cancel"):
		get_viewport().set_input_as_handled()
		close()
		return
	for i in ROWS.size():
		if event.is_action_pressed(StringName("choice_%d" % (i + 1))):
			get_viewport().set_input_as_handled()
			choose(i)
			return


func _build() -> void:
	var shade := ColorRect.new()
	shade.color = _c.overlay
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := _style.panel("SYSTEM // PAUSED")
	(panel.get_theme_stylebox("panel") as StyleBoxEmpty).set_content_margin_all(30)
	shade.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.custom_minimum_size.x = 380
	panel.add_child(column)
	column.add_child(_style.label("OH S#IT", _s.pause_title, _c.brand, true))
	column.add_child(_style.label("THE LIFE SKILLS GAME", _s.tag, _c.dim, true))
	column.add_child(_spacer(10))
	for i in ROWS.size():
		var button := _button(ROWS[i], i)
		button.pressed.connect(choose.bind(i))
		column.add_child(button)
		_buttons.append(button)
	column.add_child(_spacer(10))
	var keys := HBoxContainer.new()
	keys.add_theme_constant_override("separation", 8)
	for pair in [["ESC", "BACK"], ["V", "VOICE"], ["M", "MUSIC"]]:
		keys.add_child(_style.key_cap(pair[0], _c.dim))
		var l := _style.label(pair[1], _s.tag, _c.dim, true)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		keys.add_child(l)
		keys.add_child(_spacer(6))
	column.add_child(keys)


func _spacer(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(height, height)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


## A row: key cap with the number, then the label (Michroma); lit cyan when focused or hovered.
func _button(text: String, index: int) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", _style.display_font)
	button.add_theme_font_size_override("font_size", _s.small)
	button.add_theme_color_override("font_color", _c.text)
	for state in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, _c.accent)
	var plain := StyleBoxFlat.new()
	plain.bg_color = Color(0, 0, 0, 0)
	plain.set_content_margin_all(8)
	plain.content_margin_left = int(_s.key_cap) + 22
	var lit := plain.duplicate() as StyleBoxFlat
	lit.bg_color = _c.highlight
	lit.border_color = _c.accent
	lit.border_width_left = 2
	lit.border_width_bottom = 1
	button.add_theme_stylebox_override("normal", plain)
	for state in ["hover", "focus", "pressed", "hover_pressed"]:
		button.add_theme_stylebox_override(state, lit)
	var cap := _style.key_cap("%d" % (index + 1), _c.accent)
	cap.position = Vector2(8, 5)
	button.add_child(cap)
	button.mouse_entered.connect(button.grab_focus)
	return button
