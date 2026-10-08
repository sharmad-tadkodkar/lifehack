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
