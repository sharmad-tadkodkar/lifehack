extends SceneTree
## One-time import setup for Mixamo FBX files under res://assets/models (re-run after adding more):
##   - builds a BoneMap (Mixamo -> SkeletonProfileHumanoid) for each bone prefix it finds
##     ("mixamorig_", "mixamorig6_", ...), so every character and clip retargets to the same
##     humanoid skeleton (bones "Hips", "RightHand", ...; skeleton "GeneralSkeleton")
##   - files with no mesh are animation clips: imported as an AnimationLibrary, looping if listed
##     in config/animation.cfg [mixamo_import] loop_files
## Then run:  godot --headless --path godot --import
##   godot --headless --path godot -s res://tools/setup_mixamo.gd

const MODELS := "res://assets/models/"
const MAP_DIR := "res://assets/models/mixamo/"

## Godot humanoid profile bone -> Mixamo bone (without prefix)
const MIXAMO := {
	"Hips": "Hips", "Spine": "Spine", "Chest": "Spine1", "UpperChest": "Spine2", "Neck": "Neck", "Head": "Head",
	"LeftShoulder": "LeftShoulder", "LeftUpperArm": "LeftArm", "LeftLowerArm": "LeftForeArm", "LeftHand": "LeftHand",
	"RightShoulder": "RightShoulder", "RightUpperArm": "RightArm", "RightLowerArm": "RightForeArm", "RightHand": "RightHand",
	"LeftUpperLeg": "LeftUpLeg", "LeftLowerLeg": "LeftLeg", "LeftFoot": "LeftFoot", "LeftToes": "LeftToeBase",
	"RightUpperLeg": "RightUpLeg", "RightLowerLeg": "RightLeg", "RightFoot": "RightFoot", "RightToes": "RightToeBase",
	"LeftThumbMetacarpal": "LeftHandThumb1", "LeftThumbProximal": "LeftHandThumb2", "LeftThumbDistal": "LeftHandThumb3",
	"LeftIndexProximal": "LeftHandIndex1", "LeftIndexIntermediate": "LeftHandIndex2", "LeftIndexDistal": "LeftHandIndex3",
	"LeftMiddleProximal": "LeftHandMiddle1", "LeftMiddleIntermediate": "LeftHandMiddle2", "LeftMiddleDistal": "LeftHandMiddle3",
	"LeftRingProximal": "LeftHandRing1", "LeftRingIntermediate": "LeftHandRing2", "LeftRingDistal": "LeftHandRing3",
	"LeftLittleProximal": "LeftHandPinky1", "LeftLittleIntermediate": "LeftHandPinky2", "LeftLittleDistal": "LeftHandPinky3",
	"RightThumbMetacarpal": "RightHandThumb1", "RightThumbProximal": "RightHandThumb2", "RightThumbDistal": "RightHandThumb3",
	"RightIndexProximal": "RightHandIndex1", "RightIndexIntermediate": "RightHandIndex2", "RightIndexDistal": "RightHandIndex3",
	"RightMiddleProximal": "RightHandMiddle1", "RightMiddleIntermediate": "RightHandMiddle2", "RightMiddleDistal": "RightHandMiddle3",
	"RightRingProximal": "RightHandRing1", "RightRingIntermediate": "RightHandRing2", "RightRingDistal": "RightHandRing3",
	"RightLittleProximal": "RightHandPinky1", "RightLittleIntermediate": "RightHandPinky2", "RightLittleDistal": "RightHandPinky3",
}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MAP_DIR))
	var loops := _loop_files()
	var changed := 0
	for file_name in DirAccess.get_files_at(MODELS):
		if file_name.get_extension().to_lower() != "fbx":
			continue
		var path := MODELS + file_name
		if _already_set_up(path):
			print("[mixamo] %s: already set up" % file_name)
			continue
		var info := _inspect(path)
		if info.is_empty():
			print("[mixamo] skip %s (no Mixamo skeleton)" % file_name)
			continue
		var map_path := _bone_map_for(info.prefix, info.bones)
		_patch_import(path, map_path, info.is_clip, loops.has(file_name.get_basename()))
		changed += 1
		print("[mixamo] %s: prefix '%s', %s%s" % [file_name, info.prefix,
			"animation library" if info.is_clip else "character",
			" (loop)" if info.is_clip and loops.has(file_name.get_basename()) else ""])
	print("[mixamo] patched %d files; now run: godot --headless --path . --import" % changed)
	quit()


func _loop_files() -> Array:
	var cfg := ConfigFile.new()
	cfg.load("res://config/animation.cfg")
	return cfg.get_value("mixamo_import", "loop_files", [])


func _already_set_up(path: String) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(path + ".import") != OK:
		return false
	var nodes: Dictionary = cfg.get_value("params", "_subresources", {}).get("nodes", {})
	return nodes.get("PATH:Skeleton3D", {}).has("retarget/bone_map")


## Reads the source FBX scene (as currently imported) for its skeleton prefix and whether it has a mesh.
func _inspect(path: String) -> Dictionary:
	var res: Resource = load(path)
	if not res is PackedScene:
		return {}  # already an AnimationLibrary: inspect via the existing bone map instead
	var root: Node = (res as PackedScene).instantiate()
	var skeletons := root.find_children("*", "Skeleton3D", true, false)
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	var out := {}
	if not skeletons.is_empty():
		var sk: Skeleton3D = skeletons[0]
		var bones := {}
		for i in sk.get_bone_count():
			bones[sk.get_bone_name(i)] = true
		for bone_name: String in bones:
			if bone_name.ends_with("Hips") and bone_name.begins_with("mixamorig"):
				out = {"prefix": bone_name.trim_suffix("Hips"), "bones": bones, "is_clip": meshes.is_empty()}
				break
	root.free()
	return out


func _bone_map_for(prefix: String, bones: Dictionary) -> String:
	var map_path := MAP_DIR + "bone_map_%s.tres" % prefix.trim_suffix("_")
	var map := BoneMap.new()
	map.profile = SkeletonProfileHumanoid.new()
	for profile_bone: String in MIXAMO:
		var bone: String = prefix + MIXAMO[profile_bone]
		if bones.has(bone):
			map.set_skeleton_bone_name(StringName(profile_bone), StringName(bone))
	ResourceSaver.save(map, map_path)
	return map_path


func _patch_import(path: String, map_path: String, is_clip: bool, loop: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load(path + ".import")
	var subresources: Dictionary = cfg.get_value("params", "_subresources", {})
	var nodes: Dictionary = subresources.get("nodes", {})
	nodes["PATH:Skeleton3D"] = {"retarget/bone_map": load(map_path)}
	subresources["nodes"] = nodes
	if is_clip:
		var animations: Dictionary = subresources.get("animations", {})
		animations["mixamo_com"] = {"settings/loop_mode": 1 if loop else 0}
		subresources["animations"] = animations
		cfg.set_value("remap", "importer", "animation_library")
		cfg.set_value("remap", "type", "AnimationLibrary")
	cfg.set_value("params", "_subresources", subresources)
	cfg.save(path + ".import")
