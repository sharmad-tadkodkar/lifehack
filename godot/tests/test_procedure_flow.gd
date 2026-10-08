extends GutTest
## Plays the procedure through the game layer (spots, menus, controller, visuals), checking that
## the props end up where the model says they are.

var main: Node
var pc: ProcedureController
var car: CarRig
var visuals: WorkBayVisuals


func before_each() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(main)
	await wait_physics_frames(2)
	main.director.skip_intro()
	await wait_physics_frames(2)
	pc = main.procedure
	car = main.get_node("WorkBay/Car")
	visuals = main.get_node("WorkBay/Items")


func _pick(kind: String, id: String) -> void:
	var actions := pc.current_actions()
	for i in actions.size():
		if actions[i].kind == kind and actions[i].id == id:
			await pc.choose(i)
			return
	fail_test("no %s '%s' on the menu: %s" % [kind, id, actions.map(func(a): return a.id)])


func _at(location: String) -> void:
	if pc.menu_open:
		pc.close_menu()
	pc.debug_open(location)


func test_only_the_hero_car_offers_spots() -> void:
	var owners := {}
	for spot: InteractionSpot in get_tree().get_nodes_in_group(&"interaction_spot"):
		owners[spot.get_parent().get_parent().name] = true
	assert_false(owners.has("LiftCar"), "the car on the lift is set dressing")


func test_full_procedure_through_the_menus() -> void:
	_at("tool_cart")
	await _pick("take", "lug_wrench")
	assert_eq(visuals.lug_wrench.get_parent(),
		main.player.rig.hand_socket, "wrench in hand")

	_at("wheel")
	await _pick("step", "loosen_nuts")
	assert_gt(car.nuts[0].position.x, car.nut_seat(0).x, "nuts backed out")
	await _pick("put", "lug_wrench")

	_at("tool_cart")
	await _pick("take", "jack")
	_at("jack_point")
	await _pick("step", "raise_car")
	assert_eq(car.raise_amount, 1.0, "car up")
	assert_almost_eq(visuals.jack.global_position.x, car.jack_point.global_position.x, 0.05, "jack under the jack point")

	await _pick("take", "lug_wrench")
	await _pick("step", "remove_wheel")
	assert_ne(car.flat_wheel.get_parent(), car.hub, "flat is off the hub")

	_at("trunk")
	await _pick("take", "spare")
	_at("wheel")
	await _pick("step", "fit_spare")
	assert_eq(visuals.spare.get_parent(), car.hub, "spare on the hub")
	await _pick("step", "hand_tighten")
	await _pick("step", "lower_car")
	assert_eq(car.raise_amount, 0.0, "car down")

	_at("trunk")
	await _pick("take", "lug_wrench")
	_at("wheel")
	await _pick("step", "torque_nuts")
	assert_true(pc.model.pattern_active)
	for nut in [0, 2, 4, 1, 3]:
		await pc.choose(nut)
	assert_true(pc.model.is_complete())
	assert_false(pc.running, "game over screen")
	assert_eq(pc.model.mistakes.size(), 0)


func test_a_wrong_choice_is_explained_and_changes_nothing() -> void:
	_at("jack_point")
	await _pick("step", "raise_car")
	assert_eq(pc.model.mistakes.size(), 1)
	assert_eq(car.raise_amount, 0.0)
	assert_true(pc.menu_open, "menu stays up so the player can choose again")
