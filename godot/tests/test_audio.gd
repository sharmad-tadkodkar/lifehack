extends GutTest
## Every sound slot resolves to a playable stream, the code only plays ids that exist, the buses are
## there, and the narrator picks sensible lines. The procedure flow test covers sounds in context.

func test_every_sfx_slot_loads() -> void:
	var ids := []
	for section: String in Config.sections("audio"):
		if section.begins_with("sfx."):
			ids.append(section.trim_prefix("sfx."))
	assert_gt(ids.size(), 15)
	for id: String in ids:
		assert_not_null(Sfx.stream_for(id), "sound for %s" % id)


func test_code_only_plays_configured_sounds() -> void:
	var regex := RegEx.create_from_string("Sfx\\.play(?:_ui)?\\(\\s*\"([a-z_]+)\"")
	var found := {}
	for dir in ["res://src/game/", "res://src/ui/", "res://src/player/", "res://src/npc/"]:
		for file_name in DirAccess.get_files_at(dir):
			if file_name.ends_with(".gd"):
				for m in regex.search_all(FileAccess.get_file_as_string(dir + file_name)):
					found[m.get_string(1)] = file_name
	assert_gt(found.size(), 10)
	for id: String in found:
		assert_true(Config.has("audio", "sfx." + id, "file"), "%s (played in %s) has an [sfx.%s] slot" % [id, found[id], id])
	# the pick-up sounds are chosen with a ternary, so the regex can't see both
	for id in ["pickup", "putdown"]:
		assert_true(Config.has("audio", "sfx." + id, "file"), id)


func test_music_and_ambience_loop() -> void:
	for id in ["music_loop", "garage_hum"]:
		var stream := Sfx.stream_for(id)
		assert_not_null(stream, id)
		if stream is AudioStreamWAV:
			assert_eq((stream as AudioStreamWAV).loop_mode, AudioStreamWAV.LOOP_FORWARD, id + " loops")
	assert_gt(Sfx.stream_for("music_loop").get_length(), 10.0, "music is a real loop, not a jingle")
	var music := Sfx.stream_for("music_loop")
	if "loop" in music:
		assert_true(music.get("loop"), "the music track loops")


func test_buses_exist() -> void:
	for bus in ["Music", "SFX", "Ambience", "Voice"]:
		assert_gt(AudioServer.get_bus_index(bus), 0, bus)


func test_narrator_lines() -> void:
	var data := ProcedureData.load_file(Config.v("game", "procedure", "file"))
	var narrator := Narrator.new(data, 3)
	assert_ne(narrator.intro(), "")
	var model := ProcedureModel.new(data)
	# a wrong-order mistake: opener + the consequence text from the JSON
	var early := model.attempt("raise_car")
	assert_false(early.ok)
	var line := narrator.line_for(early)
	assert_true(line.ends_with(early.message), line)
	assert_gt(line.length(), early.message.length(), "a quip comes first")
	assert_ne(narrator.finish(0), narrator.finish(9), "the finish line depends on mistakes")
	assert_true(narrator.finish(0).ends_with(data.message("complete")))


func test_narration_is_validated() -> void:
	var data := ProcedureData.new()
	data.narration = {"intro": []}
	data._validate_narration()
	assert_gt(data.errors.size(), 3, "empty / missing narration lists are reported")
