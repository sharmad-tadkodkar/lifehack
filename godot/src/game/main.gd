extends Node
## Boot: applies graphics.cfg and handles debug flags passed after `--`:
##   --shot=<png path>   save a viewport screenshot after --frames=N (default 120), then quit
##   --size=WxH          force a windowed size (handy for consistent captures)
##   --campos=x,y,z --camlook=x,y,z   move the overview camera (look-dev captures)
##   --autoplay          the procedure plays itself (wired up in the animation milestone)

const SCALING_MODES := {
	"bilinear": Viewport.SCALING_3D_MODE_BILINEAR,
	"fsr": Viewport.SCALING_3D_MODE_FSR,
	"fsr2": Viewport.SCALING_3D_MODE_FSR2,
}

var debug_args: Dictionary = {}


func _ready() -> void:
	debug_args = _parse_user_args()
	_apply_graphics()
	_setup_overview_camera()
	if debug_args.has("shot"):
		_capture_after(int(debug_args.get("frames", "120")), debug_args["shot"])


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


func _setup_overview_camera() -> void:
	var cam := get_node_or_null(^"OverviewCamera") as Camera3D
	if cam == null:
		return
	cam.fov = Config.v("camera", "overview", "fov")
	if debug_args.has("campos"):
		cam.global_position = _parse_vec3(debug_args["campos"])
		cam.look_at(_parse_vec3(debug_args.get("camlook", "0,0.6,0")))


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
