extends GutTest
## Step order: the real procedure succeeds, everything out of turn is refused with the right
## reason, failures never change the state, and no other order of the seven steps completes.

const H := preload("res://tests/procedure_helpers.gd")

var data: ProcedureData
var model: ProcedureModel


func before_each() -> void:
	data = H.load_data()
	model = ProcedureModel.new(data)


func test_canonical_order_completes_without_mistakes() -> void:
	for step_id in data.step_ids_in_order():
		var r := H.perform(model, step_id)
		assert_true(r.ok and r.completes_step, "%s: %s" % [step_id, r.message])
	assert_true(model.is_complete())
	assert_eq(model.mistakes.size(), 0)
	assert_eq(model.state, {"nuts": "torqued", "wheel": "spare", "car_raised": false, "jack_placed": false})


func test_only_the_last_step_reports_completion() -> void:
	var ids := data.step_ids_in_order()
	for i in ids.size():
		var r := H.perform(model, ids[i])
		assert_eq(r.procedure_complete, i == ids.size() - 1, ids[i])


func test_every_later_step_is_refused_at_every_point() -> void:
	var ids := data.step_ids_in_order()
	for i in ids.size():
		for later in ids.slice(i + 1):
			H.ready_tool(model, later)
			var before := model.state.duplicate()
			var r := model.attempt(later)
			assert_false(r.ok, "%s must be refused before %s is done" % [later, ids[i]])
			assert_eq(r.reason, "precondition", later)
			assert_true(r.mistake, later)
			assert_ne(r.message, "", "%s explains why" % later)
			assert_eq(model.state, before, "%s failure leaves the state alone" % later)
		H.perform(model, ids[i])


func test_out_of_order_reasons_at_the_start() -> void:
	var expected := {
		"raise_car": "nuts",
		"remove_wheel": "car_raised",
		"fit_spare": "wheel",
		"hand_tighten": "wheel",
		"lower_car": "car_raised",
		"torque_nuts": "nuts",
	}
	for step_id: String in expected:
		H.ready_tool(model, step_id)
		var r := model.attempt(step_id)
		assert_eq(r.failed_key, expected[step_id], step_id)


func test_jacking_before_loosening_explains_why() -> void:
	H.ready_tool(model, "raise_car")
	var r := model.attempt("raise_car")
	assert_false(r.ok)
	assert_string_contains(r.message, "Loosen them first")


func test_wrong_tool_is_refused_and_counts() -> void:
	model.take("jack", "tool_cart")
	var r := model.attempt("loosen_nuts")
	assert_false(r.ok)
	assert_eq(r.reason, "wrong_tool")
	assert_true(r.mistake)
	assert_eq(model.state.nuts, "tight")
	assert_eq(model.mistakes.size(), 1)


func test_empty_hands_cannot_loosen() -> void:
	var r := model.attempt("loosen_nuts")
	assert_eq(r.reason, "wrong_tool")


func test_hand_steps_need_no_tool() -> void:
	for step_id in ["loosen_nuts", "raise_car", "remove_wheel", "fit_spare"]:
		H.perform(model, step_id)
	model.take("lug_wrench", Inventory.HANDS) # no-op: proves holding something doesn't block
	var r := model.attempt("hand_tighten")
	assert_true(r.ok, r.message)


func test_repeating_a_done_step_is_not_a_mistake() -> void:
	H.perform(model, "loosen_nuts")
	var r := model.attempt("loosen_nuts")
	assert_eq(r.reason, "already_done")
	assert_false(r.mistake)
	assert_eq(model.mistakes.size(), 0)


func test_menu_lists_remaining_steps_without_revealing_the_order() -> void:
	var labels := []
	for action in model.actions_at(["wheel", "jack_point"]):
		if action.kind == "step":
			labels.append(action.label)
	assert_eq(labels.size(), 7)
	var sorted := labels.duplicate()
	sorted.sort()
	assert_eq(labels, sorted, "alphabetical, not procedural")
	H.perform(model, "loosen_nuts")
	assert_eq(model.actions_at(["wheel", "jack_point"]).filter(func(a): return a.kind == "step").size(), 6)


func test_only_the_canonical_order_of_all_seven_completes() -> void:
	var ids := data.step_ids_in_order()
	var winners := []
	var tried := 0
	for order: Array in H.permutations(ids):
		tried += 1
		var m := ProcedureModel.new(data)
		for step_id: String in order:
			H.perform(m, step_id)
		if m.is_complete():
			winners.append(order)
	assert_eq(tried, 5040)
	assert_eq(winners.size(), 1)
	assert_eq(winners[0], ids)
