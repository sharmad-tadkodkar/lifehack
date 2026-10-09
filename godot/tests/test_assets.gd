extends GutTest
## Real assets are actually in use: every slot that assets.cfg points at a model has swapped out
## its placeholder, the car's flat wheel and the characters' hands are bound, and the work clips
## resolve to the Mixamo libraries (not the placeholder fallbacks).

var main: Node


func before_all() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait_physics_frames(2)


func after_all() -> void:
	main.free()


func _slots() -> Array[AssetSlot]:
	var out: Array[AssetSlot] = []
	for node in main.find_children("*", "Node3D", true, false):
		if node is AssetSlot:
			out.append(node)
	return out


func test_configured_slots_use_their_real_models() -> void:
	var checked := 0
	for slot in _slots():
		var path := str(Config.v("assets", slot.slot, "model")) if Config.has("assets", slot.slot, "model") else ""
		if path == "":
			continue
		checked += 1
		assert_false(slot.using_placeholder, "%s (%s) should use %s" % [slot.name, slot.slot, path])
	assert_gt(checked, 5, "real models configured")


func test_flat_wheel_is_the_models_wheel_on_the_hub() -> void:
	var car: CarRig = main.get_node("WorkBay/Car")
	assert_not_null(car.flat_wheel)
	assert_eq(car.flat_wheel.name, Config.v("assets", "car", "flat_wheel_node"))
	assert_eq(car.flat_wheel.get_parent(), car.hub)
	assert_eq(car.nuts.size(), 5, "the game's own lug nuts are on the hub")


func test_characters_hold_things_in_their_right_hand_bone() -> void:
	for path in ["Player/CharacterRig", "Garage/NPCs/NpcPhone/CharacterRig", "Garage/NPCs/NpcMechanic/CharacterRig"]:
		var rig: CharacterRig = main.get_node(path)
		var bone := rig.hand_socket.get_parent() as BoneAttachment3D
		assert_not_null(bone, path)
		assert_eq(bone.bone_name, "RightHand", path)


func test_work_clips_come_from_mixamo() -> void:
	var rig: CharacterRig = main.get_node("Player/CharacterRig")
	var expected := {
		"kneel_down": "kneeling_down/mixamo_com",
		"kneel_idle": "kneeling_idle/mixamo_com",
		"wrench_loosen": "kneeling_inspecting/mixamo_com",
		"pump_jack": "pulling_lever/mixamo_com",
		"pull_wheel": "pull_heavy_object/mixamo_com",
		"fit_wheel": "pushing/mixamo_com",
		"pick_up": "picking_up/mixamo_com",
		"shrug": "shrugging/mixamo_com",
	}
	for logical: String in expected:
		assert_eq(rig.clip_for(logical), expected[logical], logical)
	var mechanic: CharacterRig = main.get_node("Garage/NPCs/NpcMechanic/CharacterRig")
	assert_eq(mechanic.clip_for("work_overhead"), "standing_torch_inspect_upward/mixamo_com")
	var phone: CharacterRig = main.get_node("Garage/NPCs/NpcPhone/CharacterRig")
	assert_eq(phone.clip_for("lean_phone"), "texting_while_standing/mixamo_com")


func test_locomotion_clips_loop_in_place_at_a_walking_pace() -> void:
	var bone := str(Config.v("animation", "locomotion", "root_bone"))
	for path in ["Player/CharacterRig", "Garage/NPCs/NpcMechanic/CharacterRig"]:
		var rig: CharacterRig = main.get_node(path)
		for logical in ["walk", "jog"]:
			var animation := rig.anim.get_animation(rig.clip_for(logical))
			var track := animation.find_track(NodePath("%GeneralSkeleton:" + bone), Animation.TYPE_POSITION_3D)
			assert_gt(track, -1, "%s %s has a root track" % [path, logical])
			var drift := animation.position_track_interpolate(track, animation.length) \
				- animation.position_track_interpolate(track, 0.0)
			assert_lt(Vector2(drift.x, drift.z).length(), 0.01, "%s %s loops in place" % [path, logical])
			var speed := rig.stride_speed(logical)
			assert_between(speed, 0.8, 3.0, "%s %s stride speed (m/s)" % [path, logical])
			gut.p("%s %s: stride %.2f m/s" % [path, logical, speed])


func test_strip_root_travel_keeps_the_sway() -> void:
	var animation := Animation.new()
	animation.length = 1.0
	var track := animation.add_track(Animation.TYPE_POSITION_3D)
	animation.track_set_path(track, NodePath("%GeneralSkeleton:Hips"))
	animation.position_track_insert_key(track, 0.0, Vector3(0.0, 1.0, 0.0))
	animation.position_track_insert_key(track, 0.5, Vector3(0.1, 0.9, 1.0))
	animation.position_track_insert_key(track, 1.0, Vector3(0.0, 1.0, 2.0))
	var travel := CharacterRig.strip_root_travel(animation, "Hips")
	assert_eq(travel, Vector3(0.0, 0.0, 2.0))
	assert_eq(animation.track_get_key_value(track, 1), Vector3(0.1, 0.9, 0.0), "side sway and bob stay")
	assert_eq(animation.track_get_key_value(track, 2), Vector3(0.0, 1.0, 0.0))


func test_reports_clips_still_on_stopgaps() -> void:
	# Not a failure: lists logical clips whose Mixamo file has not been downloaded yet.
	var rig: CharacterRig = main.get_node("Player/CharacterRig")
	var waiting := []
	for logical in ["idle", "walk", "jog", "place_jack", "release_jack"]:
		var spec := str(Config.v("animation", "clips.player", logical)).split("|")[0]
		if rig.clip_for(logical) != CharacterRig.parse_clip_spec(spec)[0]:
			waiting.append("%s (wants %s)" % [logical, spec])
	if not waiting.is_empty():
		gut.p("Still on stopgap clips: " + ", ".join(waiting))
	pass_test("checked")
