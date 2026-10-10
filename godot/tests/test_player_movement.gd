extends GutTest
## The player walks where the camera looks, turns to face travel, and the placeholder
## character has every clip the animation map asks for.

var main: Node


func before_each() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(main)
	await wait_physics_frames(2)
	main.director.skip_intro()
	await wait_physics_frames(2)


func after_each() -> void:
	for action in [&"move_forward", &"move_right", &"jog"]:
		Input.action_release(action)


func test_controls_unlock_after_intro() -> void:
	assert_true(main.player.controls_enabled)


func test_walks_along_the_camera_view() -> void:
	var start: Vector3 = main.player.global_position
	Input.action_press(&"move_forward")
	await wait_physics_frames(45)
	var moved: Vector3 = main.player.global_position - start
	moved.y = 0.0
	var view: Vector3 = -main.director.camera.global_basis.z
	view.y = 0.0
	assert_gt(moved.length(), 0.5, "moved at least half a metre")
	assert_gt(moved.normalized().dot(view.normalized()), 0.9, "moved along the view direction")


func test_body_turns_to_face_travel() -> void:
	Input.action_press(&"move_right")
	await wait_physics_frames(60)
	var right: Vector3 = main.director.camera.global_basis.x
	right.y = 0.0
	var facing: Vector3 = -main.player.rig.global_basis.z
	assert_gt(facing.normalized().dot(right.normalized()), 0.9)


func test_jog_is_faster_than_walk() -> void:
	Input.action_press(&"move_forward")
	await wait_physics_frames(40)
	var walk_speed: float = Vector2(main.player.velocity.x, main.player.velocity.z).length()
	Input.action_press(&"jog")
	await wait_physics_frames(40)
	var jog_speed: float = Vector2(main.player.velocity.x, main.player.velocity.z).length()
	assert_gt(jog_speed, walk_speed + 0.8)
	assert_eq(main.player.rig.current_clip, "jog")


func test_placeholder_has_every_mapped_clip() -> void:
	var rig: CharacterRig = main.player.rig
	for logical: String in Config.section("animation", "clips.player"):
		assert_true(rig.has_clip(logical), "placeholder clip for '%s'" % logical)
