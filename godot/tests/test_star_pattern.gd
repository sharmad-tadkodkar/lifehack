extends GutTest
## Final tightening must go across the hub in a star; neighbours are refused.

const H := preload("res://tests/procedure_helpers.gd")


func test_every_star_is_accepted_from_any_start_in_either_direction() -> void:
	for start in 5:
		for stride in [2, 3]:
			var p := StarPattern.new(5)
			for k in 5:
				var nut: int = (start + k * stride) % 5
				assert_eq(p.try(nut), "ok", "start %d stride %d nut %d" % [start, stride, nut])
			assert_true(p.is_complete())


func test_neighbour_is_refused() -> void:
	var p := StarPattern.new(5)
	assert_eq(p.try(0), "ok")
	assert_eq(p.try(1), "wrong")
	assert_eq(p.try(4), "wrong")
	assert_eq(p.try(2), "ok")
	assert_eq(p.tightened, [0, 2] as Array[int])


func test_retightening_a_nut_is_reported() -> void:
	var p := StarPattern.new(5)
	p.try(3)
	assert_eq(p.try(3), "done")


func test_star_continues_one_way_only() -> void:
	var p := StarPattern.new(5)
	p.try(0)
	p.try(2)
	assert_eq(p.valid_next(), [4] as Array[int])


func test_four_nuts_criss_cross() -> void:
	var p := StarPattern.new(4)
	assert_eq(p.try(0), "ok")
	assert_eq(p.try(1), "wrong")
	assert_eq(p.try(2), "ok")
	assert_eq(p.try(1), "ok")
	assert_eq(p.try(3), "ok")
	assert_true(p.is_complete())


func test_model_counts_wrong_nuts_and_completes_on_the_fifth() -> void:
	var model := ProcedureModel.new(H.load_data())
	for step_id in ["loosen_nuts", "raise_car", "remove_wheel", "fit_spare", "hand_tighten", "lower_car"]:
		H.perform(model, step_id)
	H.ready_tool(model, "torque_nuts")
	var start := model.attempt("torque_nuts")
	assert_eq(start.kind, StepResult.Kind.PATTERN_START)
	assert_true(model.pattern_active)

	assert_true(model.tighten_nut(0).ok)
	var wrong := model.tighten_nut(1)
	assert_false(wrong.ok)
	assert_true(wrong.mistake)
	assert_eq(model.mistakes.size(), 1)
	assert_eq(model.state.nuts, "hand_tight", "not done until all five")

	for nut in [2, 4, 1]:
		assert_true(model.tighten_nut(nut).ok)
	var last := model.tighten_nut(3)
	assert_true(last.completes_step)
	assert_true(last.procedure_complete)
	assert_eq(model.state.nuts, "torqued")


func test_stepping_away_keeps_pattern_progress() -> void:
	var model := ProcedureModel.new(H.load_data())
	for step_id in ["loosen_nuts", "raise_car", "remove_wheel", "fit_spare", "hand_tighten", "lower_car"]:
		H.perform(model, step_id)
	H.ready_tool(model, "torque_nuts")
	model.attempt("torque_nuts")
	model.tighten_nut(0)
	model.pause_pattern()
	assert_false(model.tighten_nut(2).ok, "paused")
	model.attempt("torque_nuts")
	assert_eq(model.pattern.tightened, [0] as Array[int])
	assert_true(model.tighten_nut(2).ok)
