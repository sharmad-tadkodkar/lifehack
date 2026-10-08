extends Node
## Boot: applies graphics.cfg, runs the intro, then hands control to the player.
## Debug flags go after `--` on the command line:
##   --shot=<png path>   save a viewport screenshot after --frames=N (default 120), then quit
##   --size=WxH          force a windowed size (consistent captures)
##   --skip-intro        start straight in the follow camera
##   --hold=a,b          hold these input actions from the start (e.g. move_forward,jog)
##   --campos=x,y,z --camlook=x,y,z   look-dev camera at a fixed spot
##   --steps=N           start with the first N procedure steps already done
##   --menu=<location>   open the action menu at that location (wheel, jack_point, trunk, tool_cart)
##   --choose=1,2        then pick these menu rows in turn
##   --autoplay          the procedure plays itself, start to finish (the real order, from the JSON)

const SCALING_MODES := {
	"bilinear": Viewport.SCALING_3D_MODE_BILINEAR,
	"fsr": Viewport.SCALING_3D_MODE_FSR,
	"fsr2": Viewport.SCALING_3D_MODE_FSR2,
}

var debug_args: Dictionary = {}

@onready var player: PlayerController = $Player
@onready var director: CameraDirector = $CameraDirector
@onready var procedure: ProcedureController = $ProcedureController
@onready var hud: Hud = $Hud


func _ready() -> void:
	debug_args = _parse_user_args()
	_apply_graphics()
	if debug_args.has("shot"):
		director.mouse_capture_allowed = false
		_capture_after(int(debug_args.get("frames", "120")), debug_args["shot"])
	if debug_args.has("campos"):
		_add_lookdev_camera()
	for action in str(debug_args.get("hold", "")).split(",", false):
		Input.action_press(action)
	_start()


func _start() -> void:
	player.controls_enabled = false
	var car := $WorkBay/Car as Node3D
	player.face_direction(car.global_position - player.global_position)
	director.set_follow_yaw(player.facing_yaw())
	director.snap_to_target()
	var skip: bool = debug_args.has("skip-intro") or not Config.v("camera", "intro", "enabled")
	if not skip:
		hud.show_title(true)
		director.play_intro($Shots/IntroStart, $Shots/IntroEnd,
			Config.v("camera", "intro", "duration"), Config.v("camera", "intro", "handoff"))
		await director.intro_finished
	hud.show_title(false)
	player.controls_enabled = true
	procedure.start()
	_debug_procedure()


func _debug_procedure() -> void:
	if debug_args.has("autoplay"):
		procedure.autoplay()
		return
	if debug_args.has("steps"):
		procedure.debug_fast_forward(int(debug_args["steps"]))
	if debug_args.has("menu"):
		await procedure.debug_open(debug_args["menu"])
	for pick in str(debug_args.get("choose", "")).split(",", false):
		await procedure.choose(int(pick) - 1)


func _unhandled_input(event: InputEvent) -> void:
	# Any key or click during the intro skips it.
	if director.is_in_intro() and (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		director.skip_intro()


func _parse_user_args() -> Dictionary:
	var out := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		out[parts[0]] = parts[1] if parts.size() > 1 else "true"
	return out


func _apply_graphics() -> void:
	var window := Config.section("graphics", "window")
	var quality := Config.section("graphics", "quality")
	var vp := get_viewport()

	vp.msaa_3d = quality.get("msaa_3d", 0)
	vp.use_taa = quality.get("taa", false)
	vp.screen_space_aa = quality.get("screen_space_aa", 0)
	vp.scaling_3d_scale = quality.get("render_scale", 1.0)
	vp.scaling_3d_mode = SCALING_MODES.get(quality.get("scaling_mode", "bilinear"), Viewport.SCALING_3D_MODE_BILINEAR)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if window.get("vsync", true) else DisplayServer.VSYNC_DISABLED)

	if DisplayServer.get_name() == "headless":
		return
	var forced_size := str(debug_args.get("size", ""))
	if forced_size != "":
		var wh := forced_size.split("x")
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
		return
	match window.get("mode", "windowed"):
		"fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		"maximized":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		_:
			DisplayServer.window_set_size(window.get("windowed_size", Vector2i(1600, 900)))


func _add_lookdev_camera() -> void:
	var cam := Camera3D.new()
	cam.name = "LookDevCamera"
	cam.fov = Config.v("camera", "overview", "fov")
	add_child(cam)
	cam.global_position = _parse_vec3(debug_args["campos"])
	cam.look_at(_parse_vec3(debug_args.get("camlook", "0,0.6,0")))
	cam.make_current()


func _parse_vec3(text: String) -> Vector3:
	var p := text.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))


func _capture_after(frames: int, path: String) -> void:
	for i in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(path)
	print("[main] screenshot %s -> %s (%d fps)" % [error_string(err), path, Engine.get_frames_per_second()])
	get_tree().quit()
