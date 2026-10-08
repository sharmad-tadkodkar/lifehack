class_name CharacterRig
extends AssetSlot
## Character slot for the player and the NPCs. Plays LOGICAL clip names (mapped through
## animation.cfg [clips.<slot>]) with crossfades, drives idle/walk/jog from ground speed, and
## exposes `hand_socket`, where held tools are attached (a BoneAttachment3D on real rigs).

## Only used while the placeholder model is showing.
@export var placeholder_outfit := Color(0.07, 0.1, 0.17)

var anim: AnimationPlayer
var hand_socket: Node3D
var current_clip := ""
## When false, set_locomotion() is ignored so an action clip can play uninterrupted.
var locomotion_enabled := true

var _loc := {}
var _blend_default := 0.2
var _blend_locomotion := 0.2
var _missing_reported := {}


func _bind() -> void:
	if using_placeholder and model.has_method(&"set_outfit"):
		model.set_outfit(placeholder_outfit)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		push_error("[slot %s] model has no AnimationPlayer" % slot)
	else:
		anim = players[0]
		_load_animation_libraries()
	hand_socket = _make_hand_socket()
	_load_config()
	Config.reloaded.connect(_load_config)


func _load_config() -> void:
	_loc = Config.section("animation", "locomotion")
	_blend_default = Config.v("animation", "blend", "default")
	_blend_locomotion = Config.v("animation", "blend", "locomotion")


## Adds every AnimationLibrary found in assets.cfg [slot] animation_dir (e.g. Mixamo clips imported
## as libraries by tools/setup_mixamo.gd) to the model's AnimationPlayer, named after the file:
## "Kneeling Down.fbx" -> library "kneeling_down", so its clip is "kneeling_down/mixamo_com".
func _load_animation_libraries() -> void:
	var dir := str(_setting("animation_dir", ""))
	if dir == "" or using_placeholder:
		return
	for file_name in DirAccess.get_files_at(dir):
		if not file_name.ends_with(".import"):
			continue
		var import_cfg := ConfigFile.new()
		if import_cfg.load(dir.path_join(file_name)) != OK:
			continue
		if import_cfg.get_value("remap", "type", "") != "AnimationLibrary":
			continue
		var source := file_name.trim_suffix(".import")
		var lib_name := StringName(source.get_basename().to_snake_case())
		var library := load(dir.path_join(source)) as AnimationLibrary
		if library and not anim.has_animation_library(lib_name):
			anim.add_animation_library(lib_name, library)


## The model's clip for a logical name. Map values may carry a speed: "kneeling_down/mixamo_com@-1"
## plays it backwards (standing up), "@1.2" faster, "@0" holds the first frame (a pose). Separate
## alternatives with "|": the first clip the model actually has wins, so a map can name clips that
## will only arrive later ("standard_walk/mixamo_com|shrugging/mixamo_com@0").
func clip_for(logical: String) -> String:
	return parse_clip_spec(_spec_for(logical))[0]


func _spec_for(logical: String) -> String:
	var spec := str(Config.section("animation", "clips." + slot).get(logical, logical))
	var options := spec.split("|", false)
	for option in options:
		var clip: String = parse_clip_spec(option.strip_edges())[0]
		if anim and anim.has_animation(clip):
			return option.strip_edges()
	return options[0].strip_edges() if not options.is_empty() else logical


## "Clip@speed" -> [clip, speed]
static func parse_clip_spec(spec: String) -> Array:
	var at := spec.rfind("@")
	if at > 0 and spec.substr(at + 1).is_valid_float():
		return [spec.substr(0, at), spec.substr(at + 1).to_float()]
	return [spec, 1.0]


func has_clip(logical: String) -> bool:
	return anim != null and anim.has_animation(clip_for(logical))


func play(logical: String, blend := -1.0, speed := 1.0) -> void:
	if anim == null:
		return
	var spec := parse_clip_spec(_spec_for(logical))
	var clip: String = spec[0]
	if not anim.has_animation(clip):
		if not _missing_reported.has(clip):
			_missing_reported[clip] = true
			push_error("[slot %s] no clip '%s' for '%s' (animation.cfg [clips.%s])" % [slot, clip, logical, slot])
		return
	var rate: float = speed * float(spec[1])
	anim.play(clip, _blend_default if blend < 0.0 else blend, rate, rate < 0.0)
	anim.speed_scale = 1.0
	current_clip = logical


## Plays a one-shot clip and waits for it to end (timed by the clip's length, so it works
## the same for placeholder and real clips).
func play_and_wait(logical: String, blend := -1.0, speed := 1.0) -> void:
	play(logical, blend, speed)
	await get_tree().create_timer(clip_length(logical) / maxf(speed, 0.01), false).timeout


func clip_length(logical: String) -> float:
	var spec := parse_clip_spec(_spec_for(logical))
	var clip: String = spec[0]
	if anim == null or not anim.has_animation(clip):
		return 0.0
	if is_zero_approx(float(spec[1])):
		return 0.0
	return anim.get_animation(clip).length / absf(spec[1])


## Picks idle / walk / jog for a ground speed and scales playback so feet don't slide.
func set_locomotion(ground_speed: float) -> void:
	if not locomotion_enabled or anim == null:
		return
	var want := "idle"
	var scale := 1.0
	if ground_speed >= _loc.jog_above:
		want = "jog"
		scale = ground_speed / _loc.jog_clip_speed
	elif ground_speed >= _loc.idle_below:
		want = "walk"
		scale = ground_speed / _loc.walk_clip_speed
	if want != current_clip:
		play(want, _blend_locomotion)
	anim.speed_scale = clampf(scale, _loc.min_playback_scale, _loc.max_playback_scale) if want != "idle" else 1.0


func _make_hand_socket() -> Node3D:
	if using_placeholder:
		return model.find_child("HandSocket", true, false) as Node3D
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		push_error("[slot %s] model has no Skeleton3D for the hand socket" % slot)
		return model
	var skeleton := skeletons[0] as Skeleton3D
	var attachment := BoneAttachment3D.new()
	attachment.name = "HandBone"
	attachment.bone_name = str(_setting("hand_bone", ""))
	skeleton.add_child(attachment)
	var socket := Marker3D.new()
	socket.name = "HandSocket"
	attachment.add_child(socket)
	socket.transform = _palm_frame(skeleton, attachment.bone_name)
	return socket


## A palm-centred frame in the hand bone's space, matching the placeholder's hand socket so item
## Grip markers fit any humanoid: -Y toward the fingers, -Z toward the thumb, +X the back of the hand.
## Built from the rest positions of a finger and the thumb (assets.cfg finger_bone / thumb_bone).
func _palm_frame(skeleton: Skeleton3D, hand: String) -> Transform3D:
	var hand_index := skeleton.find_bone(hand)
	var finger_index := skeleton.find_bone(str(_setting("finger_bone", "RightMiddleProximal")))
	var thumb_index := skeleton.find_bone(str(_setting("thumb_bone", "RightThumbProximal")))
	if hand_index < 0 or finger_index < 0 or thumb_index < 0:
		push_error("[slot %s] hand/finger/thumb bones not found; hand socket sits on the bone" % slot)
		return Transform3D.IDENTITY
	var to_hand := skeleton.get_bone_global_rest(hand_index).affine_inverse()
	var finger := to_hand * skeleton.get_bone_global_rest(finger_index).origin
	var thumb := to_hand * skeleton.get_bone_global_rest(thumb_index).origin
	var along := finger.normalized()
	var thumb_side := (thumb - along * thumb.dot(along)).normalized()
	var y := -along
	var z := -thumb_side
	var basis := Basis(y.cross(z), y, z)
	return Transform3D(basis, finger * float(_setting("palm_offset", 0.6)))
