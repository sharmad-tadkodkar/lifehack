extends Node
## Every tunable value lives in res://config/*.cfg; scripts read them through here.
##   Config.v("camera", "follow", "distance")   strict: a missing key is reported
##   Config.section("lighting", "glow")         whole section as a Dictionary
## F5 (reload_config) re-reads every file and emits `reloaded`, so lighting,
## camera and timing can be tuned while the game runs.

signal reloaded

const DIR := "res://config/"

var _files: Dictionary[String, ConfigFile] = {}


func _ready() -> void:
	load_all()
	_register_input()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"reload_config"):
		load_all()
		reloaded.emit()
		print("[config] reloaded")


func load_all() -> void:
	_files.clear()
	for file_name in DirAccess.get_files_at(DIR):
		if file_name.get_extension() != "cfg":
			continue
		var cfg := ConfigFile.new()
		var err := cfg.load(DIR + file_name)
		if err != OK:
			push_error("[config] could not parse %s (error %d)" % [file_name, err])
			continue
		_files[file_name.get_basename()] = cfg


func has(file: String, sect: String, key: String) -> bool:
	return _files.has(file) and _files[file].has_section_key(sect, key)


func v(file: String, sect: String, key: String) -> Variant:
	if not has(file, sect, key):
		push_error("[config] missing %s.cfg [%s] %s" % [file, sect, key])
		return null
	return _files[file].get_value(sect, key)


func section(file: String, sect: String) -> Dictionary:
	var out := {}
	if _files.has(file) and _files[file].has_section(sect):
		for key in _files[file].get_section_keys(sect):
			out[key] = _files[file].get_value(sect, key)
	return out


func file_names() -> Array[String]:
	return _files.keys()


func _register_input() -> void:
	var actions := section("input", "actions")
	for action: String in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		for key_name: String in actions[action]:
			var keycode := OS.find_keycode_from_string(key_name)
			if keycode == KEY_NONE:
				push_error("[config] input.cfg: unknown key '%s' for %s" % [key_name, action])
				continue
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode
			InputMap.action_add_event(action, ev)
