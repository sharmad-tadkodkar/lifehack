extends GutTest
## The procedure JSON is well-formed and internally consistent.

const H := preload("res://tests/procedure_helpers.gd")

var data: ProcedureData


func before_each() -> void:
	data = H.load_data()


func test_flat_tire_procedure_is_valid() -> void:
	assert_true(data.is_valid(), "\n".join(data.errors))


func test_has_the_seven_steps_in_order() -> void:
	assert_eq(data.step_ids_in_order(), [
		"loosen_nuts", "raise_car", "remove_wheel", "fit_spare",
		"hand_tighten", "lower_car", "torque_nuts",
	])


func test_every_step_names_tool_animation_and_preconditions() -> void:
	for s: Dictionary in data.steps:
		assert_true(s.tool == null or data.items.has(s.tool), "%s tool" % s.id)
		assert_gt((s.animations as Array).size(), 0, "%s animations" % s.id)
		assert_gt((s.preconditions as Dictionary).size(), 0, "%s preconditions" % s.id)
		assert_ne(str(s.success), "", "%s success text" % s.id)


func test_final_tightening_uses_the_star_pattern() -> void:
	assert_eq(data.step("torque_nuts").pattern.type, "star")
	assert_eq(data.nut_count, 5)


func test_validation_catches_broken_data() -> void:
	var broken := {
		"id": "broken",
		"initial_state": {"nuts": "tight"},
		"items": {"wrench": {"label": "Wrench", "starts_at": "nowhere"}},
		"locations": {"wheel": "Wheel"},
		"steps": [
			{"id": "a", "order": 1, "label": "A", "location": "moon", "tool": "hammer",
				"preconditions": {"ghost": true}, "effects": {"nuts": "loose"},
				"animations": [], "mechanics": "x", "success": "ok", "fail": {}},
			{"id": "a", "order": 3, "label": "B", "location": "wheel", "tool": null,
				"preconditions": {}, "effects": {}, "animations": ["x"], "mechanics": "x",
				"success": "ok", "fail": {}},
		],
	}
	var bad := ProcedureData.from_dict(broken)
	assert_false(bad.is_valid())
	var all := "\n".join(bad.errors)
	for expected in ["unknown location 'nowhere'", "unknown location 'moon'", "unknown tool 'hammer'",
			"'ghost' is not in initial_state", "no fail text for precondition 'ghost'",
			"animations must be a non-empty list", "duplicate step id 'a'", "missing 2"]:
		assert_string_contains(all, expected)
