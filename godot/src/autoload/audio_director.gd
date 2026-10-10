extends Node
## Sound for the whole game (autoload "Sfx"). Everything is tuned in config/audio.cfg.
##   Sfx.play("ratchet")                one-shot effect (2D)
##   Sfx.play("jack_pump", node)        positioned at a Node3D, so it pans with the camera
##   Sfx.say("Bold choice.")            narrator line through the OS text-to-speech voice
## Effects pause with the game; music, ambience, UI ticks and the narrator keep going.
## Buses Music / SFX / Ambience / Voice are created here. The music ducks while the narrator speaks.
## V toggles the voice, M the music; both are remembered in user://settings.cfg.

signal settings_changed

const DEFAULT_DIR := "res://assets/audio/"
const SETTINGS := "user://settings.cfg"
const BUSES := ["Music", "SFX", "Ambience", "Voice"]

var voice_enabled := true
var music_enabled := true
## Every effect id played and every line spoken, newest last (tests and debugging read these).
var played: Array[String] = []
var spoken: Array[String] = []

var _streams := {}
var _music: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _voice_id := ""
var _music_db := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_buses()
	_load_settings()
	_voice_id = _pick_voice()
	if DisplayServer.get_name() != "headless":
		print("[audio] narrator voice: %s" % (_voice_id if _voice_id != "" else "none (text-to-speech unavailable)"))
	_music = _loop_player("music", "music_loop", "Music")
	_ambience = _loop_player("ambience", "garage_hum", "Ambience")
	_apply_config()
	Config.reloaded.connect(_apply_config)
	if DisplayServer.get_name() != "headless":
		_ambience.play()
		_start_music()


func _exit_tree() -> void:
	stop_voice()
	for child in get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer3D:
			child.stop()
			child.stream = null
			child.free()  # drops its playback too, so nothing holds the stream at exit
	_music = null
	_ambience = null
	_streams.clear()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_voice"):
		set_voice_enabled(not voice_enabled)
	elif event.is_action_pressed(&"toggle_music"):
		set_music_enabled(not music_enabled)


func _process(delta: float) -> void:
	# duck the music under the narrator
	var speaking := voice_enabled and _voice_id != "" and DisplayServer.tts_is_speaking()
	var target := _music_db + (float(Config.v("audio", "music", "duck_db")) if speaking else 0.0)
	var bus := AudioServer.get_bus_index("Music")
	var now := AudioServer.get_bus_volume_db(bus)
	var rate := absf(float(Config.v("audio", "music", "duck_db"))) / maxf(float(Config.v("audio", "music", "duck_time")), 0.01)
	AudioServer.set_bus_volume_db(bus, move_toward(now, target, rate * delta))


## Plays effect `id` (an [sfx.<id>] section). With `at`, the sound comes from that node's position.
func play(id: String, at: Node3D = null, pitch := 1.0) -> void:
	played.append(id)
	if played.size() > 400:
		played = played.slice(-200)
	var stream := stream_for(id)
	if stream == null or DisplayServer.get_name() == "headless":
		return  # headless (tests) has no audio output; the log above is what tests read
	var section := "sfx." + id
	var jitter := float(_sfx(section, "pitch_jitter"))
	var player: Node
	if at and at.is_inside_tree():
		var p3 := AudioStreamPlayer3D.new()
		p3.max_distance = float(Config.v("audio", "sfx", "max_distance"))
		p3.unit_size = 3.0
		p3.stream = stream
		p3.volume_db = float(_sfx(section, "volume_db"))
		p3.pitch_scale = pitch * (1.0 + randf_range(-jitter, jitter))
		p3.bus = &"SFX"
		add_child(p3)  # under this plain Node, so global_position is simply its position
		p3.global_position = at.global_position
		player = p3
	else:
		var p2 := AudioStreamPlayer.new()
		p2.stream = stream
		p2.volume_db = float(_sfx(section, "volume_db"))
		p2.pitch_scale = pitch * (1.0 + randf_range(-jitter, jitter))
		p2.bus = &"SFX"
		add_child(p2)
		player = p2
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.finished.connect(player.queue_free)
	player.play()


## UI sounds keep playing while the game is paused.
func play_ui(id: String) -> void:
	play(id)
	var last := get_child(get_child_count() - 1)
	if last is AudioStreamPlayer:
		last.process_mode = Node.PROCESS_MODE_ALWAYS


## Speaks `text` in the narrator voice, cutting off whatever it was saying.
func say(text: String) -> void:
	if text.strip_edges() == "":
		return
	spoken.append(text)
	if spoken.size() > 200:
		spoken = spoken.slice(-100)
	if not voice_enabled or _voice_id == "":
		return
	DisplayServer.tts_stop()
	DisplayServer.tts_speak(text, _voice_id, int(Config.v("audio", "voice", "volume")),
		float(Config.v("audio", "voice", "pitch")), float(Config.v("audio", "voice", "rate")))


func stop_voice() -> void:
	if _voice_id != "":
		DisplayServer.tts_stop()


func set_voice_enabled(on: bool) -> void:
	voice_enabled = on
	if not on:
		stop_voice()
	_save_settings()
	settings_changed.emit()


func set_music_enabled(on: bool) -> void:
	music_enabled = on
	if on:
		_start_music()
	elif _music:
		_music.stop()
	_save_settings()
	settings_changed.emit()


func has_voice() -> bool:
	return _voice_id != ""


## The stream for effect / loop `id`: its configured file, or the synthesized default.
func stream_for(id: String) -> AudioStream:
	if _streams.has(id):
		return _streams[id]
	var section := "sfx." + id
	var path := ""
	if Config.has("audio", section, "file"):
		path = str(Config.v("audio", section, "file"))
	elif Config.has("audio", id.trim_suffix("_loop"), "file"):
		path = str(Config.v("audio", id.trim_suffix("_loop"), "file"))
	if path == "":
		path = DEFAULT_DIR + id + ".wav"
	var stream := load(path) as AudioStream if ResourceLoader.exists(path) else null
	if stream == null:
		push_error("[audio] no sound for '%s' (%s)" % [id, path])
	_streams[id] = stream
	return stream


func _sfx(section: String, key: String) -> Variant:
	return Config.v("audio", section, key) if Config.has("audio", section, key) else Config.v("audio", "sfx", key)


func _loop_player(section: String, default_id: String, bus: String) -> AudioStreamPlayer:
	var path := str(Config.v("audio", section, "file"))
	var stream := load(path if path != "" else DEFAULT_DIR + default_id + ".wav") as AudioStream
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = wav.data.size() / (2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1)
	elif "loop" in stream:
		stream.set("loop", true)
	_streams[default_id] = stream
	var player := AudioStreamPlayer.new()
	player.name = section.capitalize()
	player.stream = stream
	player.bus = bus
	add_child(player)
	return player


func _start_music() -> void:
	if not music_enabled or _music == null or _music.playing or DisplayServer.get_name() == "headless":
		return
	_music.volume_db = -40.0
	_music.play()
	create_tween().tween_property(_music, "volume_db", 0.0, float(Config.v("audio", "music", "fade_in")))


func _make_buses() -> void:
	for name: String in BUSES:
		if AudioServer.get_bus_index(name) < 0:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, name)
			AudioServer.set_bus_send(index, &"Master")


func _apply_config() -> void:
	_streams.clear()
	_streams["music_loop"] = _music.stream
	_streams["garage_hum"] = _ambience.stream
	var levels := Config.section("audio", "buses")
	_music_db = float(levels.get("music_db", 0.0))
	for name: String in BUSES:
		var key := name.to_lower() + "_db"
		if name != "Music" and levels.has(key):
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index(name), float(levels[key]))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), _music_db)


## First installed English voice whose name contains a [voice] preferred entry, else any English one.
func _pick_voice() -> String:
	if DisplayServer.get_name() == "headless" or not ProjectSettings.get_setting("audio/general/text_to_speech", false):
		return ""
	var voices := DisplayServer.tts_get_voices()
	var english := voices.filter(func(v: Dictionary) -> bool: return str(v.get("language", "")).begins_with("en"))
	for wanted: String in Config.v("audio", "voice", "preferred"):
		for v: Dictionary in english:
			if str(v.get("name", "")).contains(wanted):
				return str(v.id)
	return str(english[0].id) if not english.is_empty() else ""


func _load_settings() -> void:
	voice_enabled = bool(Config.v("audio", "voice", "enabled"))
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		voice_enabled = bool(cfg.get_value("audio", "voice", voice_enabled))
		music_enabled = bool(cfg.get_value("audio", "music", music_enabled))


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("audio", "voice", voice_enabled)
	cfg.set_value("audio", "music", music_enabled)
	cfg.save(SETTINGS)
