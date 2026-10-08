extends RefCounted
## Shared helpers for the procedure tests (not a test script: no test_ prefix).

const PATH := "res://config/procedure/flat_tire.json"


static func load_data() -> ProcedureData:
	return ProcedureData.load_file(PATH)


## Puts whatever `step_id` needs into the player's hands, from wherever it is lying.
static func ready_tool(model: ProcedureModel, step_id: String) -> void:
	var tool: Variant = model.data.step(step_id).tool
	if tool == null:
		return
	var where := model.inventory.location_of(tool)
	if where != Inventory.HANDS:
		model.take(tool, where)


## Attempts a step with the right tool in hand; pattern steps are finished nut by nut.
static func perform(model: ProcedureModel, step_id: String) -> StepResult:
	ready_tool(model, step_id)
	var r := model.attempt(step_id)
	if r.kind == StepResult.Kind.PATTERN_START:
		while model.pattern_active:
			r = model.tighten_nut(model.pattern.valid_next()[0])
	return r


static func permutations(items: Array) -> Array:
	if items.size() <= 1:
		return [items.duplicate()]
	var out := []
	for i in items.size():
		var rest := items.duplicate()
		var head: Variant = rest.pop_at(i)
		for tail: Array in permutations(rest):
			out.append([head] + tail)
	return out
