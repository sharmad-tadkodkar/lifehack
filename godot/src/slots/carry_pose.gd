class_name CarryPose
extends SkeletonModifier3D
## Holds a set of bones (the carrying arm) in a pose taken from one frame of a clip, with the
## fingers closed into a fist, on top of whatever the AnimationPlayer is playing. CharacterRig
## fades `influence` in while the character walks or stands holding something, so a held tool
## stays in a closed hand beside the hip instead of swinging through the leg with the walk cycle.

## bone index -> local rotation in the carry pose
var _rotations := {}


## Samples `animation` at `time` for every bone whose name starts with one of `bone_prefixes`.
## Returns how many bones the pose drives.
func setup(animation: Animation, time: float, bone_prefixes: Array) -> int:
	_rotations.clear()
	var skeleton := get_skeleton()
	if skeleton == null:
		return 0
	for track in animation.get_track_count():
		if animation.track_get_type(track) != Animation.TYPE_ROTATION_3D:
			continue
		var bone := str(animation.track_get_path(track).get_concatenated_subnames())
		if not bone_prefixes.any(func(prefix: String) -> bool: return bone.begins_with(prefix)):
			continue
		var index := skeleton.find_bone(bone)
		if index >= 0:
			_rotations[index] = animation.rotation_track_interpolate(track, time)
	return _rotations.size()


## Closes the hand around a handle: every bone starting with one of `fingers` (plus the `thumb`
## bones) is turned from its rest pose toward the palm by the angle for its joint (degrees,
## proximal / intermediate / distal; the thumb's metacarpal / proximal / distal).
## `palm_normal` points out of the palm, in skeleton space at rest.
func add_fist(fingers: Array, curl_deg: Array, thumb: String, thumb_curl_deg: Array, palm_normal: Vector3) -> void:
	var skeleton := get_skeleton()
	for index in skeleton.get_bone_count():
		var bone := skeleton.get_bone_name(index)
		var angles: Array = thumb_curl_deg if bone.begins_with(thumb) else curl_deg
		if not bone.begins_with(thumb) and not fingers.any(func(prefix: String) -> bool: return bone.begins_with(prefix)):
			continue
		var joint := _joint_of(bone)
		var parent := skeleton.get_bone_parent(index)
		if joint < 0 or joint >= angles.size() or parent < 0:
			continue
		var rest := skeleton.get_bone_global_rest(index)
		var children := skeleton.get_bone_children(index)
		var along := (skeleton.get_bone_global_rest(children[0]).origin - rest.origin) if not children.is_empty() else rest.basis.y
		var axis := along.cross(palm_normal)
		if axis.length() < 0.0001:
			continue
		var axis_in_parent := (skeleton.get_bone_global_rest(parent).basis.orthonormalized().inverse() * axis).normalized()
		var rest_rotation := skeleton.get_bone_rest(index).basis.get_rotation_quaternion()
		_rotations[index] = Quaternion(axis_in_parent, deg_to_rad(float(angles[joint]))) * rest_rotation


## 0 / 1 / 2 for a finger's first / middle / last joint (Proximal or Metacarpal / Intermediate
## or the thumb's Proximal / Distal), -1 if the name says neither.
static func _joint_of(bone: String) -> int:
	if bone.ends_with("Metacarpal"):
		return 0
	if bone.ends_with("Proximal"):
		return 1 if bone.contains("Thumb") else 0
	if bone.ends_with("Intermediate"):
		return 1
	if bone.ends_with("Distal"):
		return 2
	return -1


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	for index: int in _rotations:
		skeleton.set_bone_pose_rotation(index, _rotations[index])
