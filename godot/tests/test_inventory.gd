extends GutTest
## One item in hand at a time; picking something up swaps out what you were holding.

const H := preload("res://tests/procedure_helpers.gd")

var model: ProcedureModel


func before_each() -> void:
	model = ProcedureModel.new(H.load_data())


func test_starting_places() -> void:
	var inv := model.inventory
	assert_eq(inv.location_of("lug_wrench"), "tool_cart")
	assert_eq(inv.location_of("jack"), "tool_cart")
	assert_eq(inv.location_of("spare"), "trunk")
	assert_eq(inv.location_of("flat"), Inventory.INSTALLED)
	assert_eq(inv.held, "")


func test_take_then_swap() -> void:
	assert_true(model.take("lug_wrench", "tool_cart").ok)
	assert_eq(model.held_item(), "lug_wrench")
	var swap := model.take("jack", "tool_cart")
	assert_true(swap.ok)
	assert_eq(swap.swapped_item, "lug_wrench")
	assert_eq(model.held_item(), "jack")
	assert_eq(model.inventory.location_of("lug_wrench"), "tool_cart")


func test_put_down_where_you_stand() -> void:
	model.take("lug_wrench", "tool_cart")
	assert_true(model.put_down("wheel").ok)
	assert_eq(model.inventory.location_of("lug_wrench"), "wheel")
	assert_eq(model.held_item(), "")
	assert_false(model.put_down("wheel").ok, "nothing left to put down")


func test_cannot_take_what_is_elsewhere_or_in_use() -> void:
	assert_eq(model.take("spare", "tool_cart").reason, "not_here")
	assert_eq(model.take("flat", "wheel").reason, "installed")


func test_steps_move_items() -> void:
	H.perform(model, "loosen_nuts")
	H.perform(model, "raise_car")
	assert_eq(model.inventory.location_of("jack"), Inventory.INSTALLED, "jack is under the car")
	assert_eq(model.held_item(), "", "placing the jack frees your hands")
	H.perform(model, "remove_wheel")
	assert_eq(model.inventory.location_of("flat"), "wheel", "flat lies by the wheel")
	H.perform(model, "fit_spare")
	assert_eq(model.inventory.location_of("spare"), Inventory.INSTALLED)
	H.perform(model, "hand_tighten")
	H.perform(model, "lower_car")
	assert_eq(model.inventory.location_of("jack"), "jack_point", "jack comes back out")


func test_menu_offers_pickups_and_put_down() -> void:
	var at_cart := model.actions_at(["tool_cart"])
	assert_eq(at_cart.map(func(a): return a.id), ["jack", "lug_wrench"])
	model.take("jack", "tool_cart")
	var kinds := model.actions_at(["tool_cart"]).map(func(a): return a.kind)
	assert_eq(kinds, ["take", "put"])
