extends GutTest
## The ambient NPCs have their clips, the mechanic actually walks the route, and the phone
## stays in the bench NPC's hand.

var garage: Node3D


func before_each() -> void:
	Engine.time_scale = 8.0
	garage = load("res://scenes/environment/garage.tscn").instantiate()
	add_child_autofree(garage)
	await wait_physics_frames(2)


func after_each() -> void:
	Engine.time_scale = 1.0


func test_npc_clips_exist() -> void:
	for npc_name in ["NpcPhone", "NpcMechanic"]:
		var rig: CharacterRig = garage.get_node("NPCs/%s/CharacterRig" % npc_name)
		for logical: String in Config.section("animation", "clips." + rig.slot):
			assert_true(rig.has_clip(logical), "%s: %s" % [npc_name, logical])


func test_mechanic_reaches_the_first_stop() -> void:
	var mechanic: NpcPatrol = garage.get_node("NPCs/NpcMechanic")
	var first: Node3D = garage.get_node("NpcWaypoints").get_child(0)
	var start := mechanic.global_position
	var closest := INF
	for i in 120:
		await wait_physics_frames(5)
		closest = minf(closest, Vector2(mechanic.global_position.x - first.global_position.x,
			mechanic.global_position.z - first.global_position.z).length())
	assert_gt(start.distance_to(mechanic.global_position), 1.0, "moved")
	assert_lt(closest, 0.3, "got to the first waypoint")


func test_phone_is_in_hand() -> void:
	var npc: NpcIdleLoop = garage.get_node("NPCs/NpcPhone")
	assert_eq(npc.held_prop.get_parent(), npc.rig.hand_socket)
