extends SceneTree
## Regenerates scenes/placeholders/placeholder_character_anims.tres, the AnimationLibrary used by
## the placeholder mannequin. Clip names are the LOGICAL names the game asks for; a real model
## supplies its own clips and maps them in config/animation.cfg instead.
##   godot --headless --path godot -s res://tools/build_placeholder_anims.gd
##
## Keys: "<joint>.<x|y|z>" = rotation (radians), "<joint>.p<x|y|z>" = position.
## Every joint channel a clip doesn't key is pinned to its REST value so crossfades stay clean.

const OUT := "res://scenes/placeholders/placeholder_character_anims.tres"

const JOINTS := {
	"hips": "Hips",
	"spine": "Hips/Spine",
	"neck": "Hips/Spine/Neck",
	"shoulder_l": "Hips/Spine/ShoulderL",
	"elbow_l": "Hips/Spine/ShoulderL/ElbowL",
	"hand_l": "Hips/Spine/ShoulderL/ElbowL/HandL",
	"shoulder_r": "Hips/Spine/ShoulderR",
	"elbow_r": "Hips/Spine/ShoulderR/ElbowR",
	"hand_r": "Hips/Spine/ShoulderR/ElbowR/HandR",
	"hip_l": "Hips/HipL",
	"knee_l": "Hips/HipL/KneeL",
	"ankle_l": "Hips/HipL/KneeL/AnkleL",
	"hip_r": "Hips/HipR",
	"knee_r": "Hips/HipR/KneeR",
	"ankle_r": "Hips/HipR/KneeR/AnkleR",
}

const REST := {
	"hips.py": 0.95,
	"shoulder_l.z": -0.1,
	"shoulder_r.z": 0.1,
	"elbow_l.x": 0.12,
	"elbow_r.x": 0.12,
}


func _initialize() -> void:
	var library := AnimationLibrary.new()
	var clips := _clips()
	library.add_animation(&"RESET", _build("RESET", {"length": 0.01, "loop": false, "keys": {}}))
	for clip_name: String in clips:
		library.add_animation(StringName(clip_name), _build(clip_name, clips[clip_name]))
	var err := ResourceSaver.save(library, OUT)
	print("[anims] %d clips -> %s (%s)" % [clips.size(), OUT, error_string(err)])
	quit(0 if err == OK else 1)


func _build(clip_name: String, data: Dictionary) -> Animation:
	var anim := Animation.new()
	anim.resource_name = clip_name
	anim.length = data["length"]
	anim.loop_mode = Animation.LOOP_LINEAR if data["loop"] else Animation.LOOP_NONE
	var keys: Dictionary = data["keys"]
	for joint: String in JOINTS:
		for channel: String in ["x", "y", "z", "px", "py", "pz"]:
			var id := "%s.%s" % [joint, channel]
			var is_position := channel.begins_with("p")
			if is_position and not keys.has(id) and not REST.has(id):
				continue
			var prop := ("position:" + channel.substr(1)) if is_position else ("rotation:" + channel)
			var track := anim.add_track(Animation.TYPE_VALUE)
			anim.track_set_path(track, NodePath("%s:%s" % [JOINTS[joint], prop]))
			anim.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
			anim.value_track_set_update_mode(track, Animation.UPDATE_CONTINUOUS)
			var frames: Array = keys.get(id, [[0.0, REST.get(id, 0.0)]])
			for frame: Array in frames:
				anim.track_insert_key(track, frame[0], float(frame[1]))
	return anim


## Shifts a looping key list by half a cycle (for the opposite limb).
func _phase(frames: Array, length: float) -> Array:
	var out := []
	for f: Array in frames:
		out.append([fmod(f[0] + length * 0.5, length), f[1]])
	out.sort_custom(func(a, b): return a[0] < b[0])
	if out[0][0] > 0.0:
		out.push_front([0.0, out[-1][1]])
	if out[-1][0] < length:
		out.append([length, out[0][1]])
	return out


func _clips() -> Dictionary:
	var walk_leg := [[0.0, 0.42], [0.5, -0.38], [1.0, 0.42]]
	var walk_knee := [[0.0, -0.08], [0.15, -0.25], [0.5, -0.1], [0.7, -0.95], [0.85, -0.45], [1.0, -0.08]]
	var walk_ankle := [[0.0, 0.15], [0.5, -0.2], [0.75, 0.1], [1.0, 0.15]]
	var walk_arm := [[0.0, -0.32], [0.5, 0.32], [1.0, -0.32]]
	var walk_elbow := [[0.0, 0.25], [0.5, 0.45], [1.0, 0.25]]

	var jog_leg := [[0.0, 0.7], [0.35, -0.55], [0.7, 0.7]]
	var jog_knee := [[0.0, -0.3], [0.1, -0.5], [0.35, -0.2], [0.5, -1.5], [0.62, -1.0], [0.7, -0.3]]
	var jog_ankle := [[0.0, 0.25], [0.35, -0.35], [0.55, 0.2], [0.7, 0.25]]
	var jog_arm := [[0.0, -0.6], [0.35, 0.55], [0.7, -0.6]]

	return {
		"idle": {
			"length": 3.0, "loop": true, "keys": {
				"hips.py": [[0.0, 0.95], [1.5, 0.944], [3.0, 0.95]],
				"spine.x": [[0.0, -0.01], [1.5, 0.025], [3.0, -0.01]],
				"neck.y": [[0.0, 0.0], [1.2, 0.12], [2.2, -0.05], [3.0, 0.0]],
				"shoulder_l.z": [[0.0, -0.1], [1.5, -0.12], [3.0, -0.1]],
				"shoulder_r.z": [[0.0, 0.1], [1.5, 0.12], [3.0, 0.1]],
			},
		},
		"walk": {
			"length": 1.0, "loop": true, "keys": {
				"hips.py": [[0.0, 0.95], [0.25, 0.975], [0.5, 0.95], [0.75, 0.975], [1.0, 0.95]],
				"spine.x": [[0.0, -0.04]],
				"spine.y": [[0.0, 0.08], [0.5, -0.08], [1.0, 0.08]],
				"hip_l.x": walk_leg, "hip_r.x": _phase(walk_leg, 1.0),
				"knee_l.x": walk_knee, "knee_r.x": _phase(walk_knee, 1.0),
				"ankle_l.x": walk_ankle, "ankle_r.x": _phase(walk_ankle, 1.0),
				"shoulder_l.x": _phase(walk_arm, 1.0), "shoulder_r.x": walk_arm,
				"elbow_l.x": _phase(walk_elbow, 1.0), "elbow_r.x": walk_elbow,
			},
		},
		"jog": {
			"length": 0.7, "loop": true, "keys": {
				"hips.py": [[0.0, 0.93], [0.175, 0.98], [0.35, 0.93], [0.525, 0.98], [0.7, 0.93]],
				"spine.x": [[0.0, -0.15]],
				"spine.y": [[0.0, 0.12], [0.35, -0.12], [0.7, 0.12]],
				"hip_l.x": jog_leg, "hip_r.x": _phase(jog_leg, 0.7),
				"knee_l.x": jog_knee, "knee_r.x": _phase(jog_knee, 0.7),
				"ankle_l.x": jog_ankle, "ankle_r.x": _phase(jog_ankle, 0.7),
				"shoulder_l.x": _phase(jog_arm, 0.7), "shoulder_r.x": jog_arm,
				"elbow_l.x": [[0.0, 1.25]], "elbow_r.x": [[0.0, 1.25]],
			},
		},
	}
