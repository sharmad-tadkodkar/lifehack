extends GutTest
## Holding things with a real character rig: the hand path used to time grabs matches the pose the
## AnimationPlayer actually produces, the carry pose moves the hand (and what it holds), and a
## picked-up tool ends up gripped in the hand socket.

var main: Node
var rig: CharacterRig


func before_all() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait_physics_frames(2)
	rig = main.get_node("Player/CharacterRig")


func after_all() -> void:
	main.free()


func test_hand_path_matches_the_played_pose() -> void:
	rig.locomotion_enabled = false
	for logical in ["pick_up_floor", "pick_up_reach"]:
		var path := rig.hand_path(logical, 9)
		assert_eq(path.size(), 9, logical)
		for sample: Array in [path[3], path[6]]:
			rig.anim.play(rig.clip_for(logical), 0.0)
			rig.anim.seek(sample[0], true)
			rig.anim.pause()
			await wait_physics_frames(2)
			var actual := rig.global_transform.affine_inverse() * rig.hand_socket.global_position
			assert_lt(actual.distance_to(sample[1]), 0.03, "%s at %.2fs: %s vs %s" % [logical, sample[0], actual, sample[1]])
	rig.locomotion_enabled = true
	rig.play("idle", 0.0)


func test_carry_pose_moves_the_hand_socket() -> void:
	rig.carrying = false
	rig.play("idle", 0.0)
	await wait_physics_frames(30)
	var free_hand := rig.global_transform.affine_inverse() * rig.hand_socket.global_position
	rig.carrying = true
	await wait_physics_frames(40)
	assert_almost_eq(rig.carry_influence(), 1.0, 0.01, "carry pose fully in")
	var carrying_hand := rig.global_transform.affine_inverse() * rig.hand_socket.global_position
	assert_gt(carrying_hand.distance_to(free_hand), 0.1, "hand %s -> %s" % [free_hand, carrying_hand])
	assert_gt(carrying_hand.y, free_hand.y, "the carrying hand is raised")
	rig.carrying = false
	await wait_physics_frames(40)
	assert_almost_eq(rig.carry_influence(), 0.0, 0.01, "carry pose fully out")


func test_carry_pose_only_while_moving_or_standing() -> void:
	rig.carrying = true
	rig.locomotion_enabled = false
	await wait_physics_frames(40)
	assert_almost_eq(rig.carry_influence(), 0.0, 0.01, "action clips drive the arm")
	rig.locomotion_enabled = true
	rig.carrying = false
	await wait_physics_frames(40)


func test_reach_clip_fits_where_the_item_lies() -> void:
	var player: PlayerController = main.get_node("Player")
	var actions: ActionPlayer = main.get_node("ActionPlayer")
	var visuals: WorkBayVisuals = main.get_node("WorkBay/Items")
	player.snap_to(main.get_node("WorkBay/ToolCart/ToolCartSpot/Stand_tool_cart"))
	var cfg := Config.section("animation", "pickup")
	var tray := actions._plan_reach(cfg, visuals.reach_point("lug_wrench"))
	assert_eq(tray.clip, "pick_up_reach", "the wrench on the tray is reached for standing")
	var floor := actions._plan_reach(cfg, visuals.reach_point("jack"))
	assert_eq(floor.clip, "pick_up_floor", "the jack on the floor is bent down for")


func test_picked_up_tool_is_gripped_in_the_hand() -> void:
	Engine.time_scale = 8.0
	var procedure: ProcedureController = main.get_node("ProcedureController")
	var visuals: WorkBayVisuals = main.get_node("WorkBay/Items")
	procedure.start()
	await procedure._go_to("tool_cart")
	await procedure.perform({"kind": "take", "id": "lug_wrench", "location": "tool_cart"})
	Engine.time_scale = 1.0
	var wrench := visuals.lug_wrench
	assert_eq(wrench.get_parent(), rig.hand_socket, "the wrench hangs from the hand socket")
	assert_lt(wrench.grip.global_position.distance_to(rig.hand_socket.global_position), 0.01, "its grip is in the hand")
	assert_true(rig.carrying)
