extends GutTest
## Config files must parse, and every key binding must name a real key.


func test_every_config_file_parses() -> void:
	var found := 0
	for file_name in DirAccess.get_files_at("res://config/"):
		if file_name.get_extension() != "cfg":
			continue
		found += 1
		var cfg := ConfigFile.new()
		assert_eq(cfg.load("res://config/" + file_name), OK, file_name)
	assert_gt(found, 0, "config files found")


func test_input_bindings_resolve_to_keys() -> void:
	var cfg := ConfigFile.new()
	assert_eq(cfg.load("res://config/input.cfg"), OK)
	for action in cfg.get_section_keys("actions"):
		for key_name: String in cfg.get_value("actions", action):
			assert_ne(OS.find_keycode_from_string(key_name), KEY_NONE, "%s -> %s" % [action, key_name])


func test_config_autoload_reads_values() -> void:
	assert_true(Config.has("graphics", "quality", "msaa_3d"))
	assert_true(InputMap.has_action(&"interact"), "input actions registered from input.cfg")
