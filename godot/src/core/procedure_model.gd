class_name ProcedureModel
extends RefCounted
## The procedure as a state machine: what is true about the car, where every item is, which
## steps are done, and what went wrong. Pure logic (no nodes, no rendering); the game layer
## asks it what is possible, tells it what the player chose, and animates the StepResult.
##
## Step order is never hard-coded: a step succeeds only when its preconditions match the
## state, so the sequence falls out of the data (tests prove only one order completes).

signal changed

var data: ProcedureData
var state: Dictionary = {}
var inventory: Inventory
var completed: Array[String] = []
## Each mistake: {action, reason, key, message}
var mistakes: Array[Dictionary] = []
## Progress of the star-pattern step, kept if the player steps away mid-way.
var pattern: StarPattern
var pattern_step := ""
var pattern_active := false


func _init(procedure: ProcedureData) -> void:
	data = procedure
	reset()


func reset() -> void:
	state = data.initial_state.duplicate(true)
	inventory = Inventory.new(data.items)
	completed.clear()
	mistakes.clear()
	pattern = null
	pattern_step = ""
	pattern_active = false


func is_complete() -> bool:
	return completed.size() == data.steps.size()


func is_done(step_id: String) -> bool:
	return completed.has(step_id)


func held_item() -> String:
	return inventory.held


## Everything the player can choose at these locations. Steps not yet done are listed
## alphabetically (never in procedure order, which would give the answer away), followed
## by items to pick up and setting down what is in hand.
func actions_at(locations: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Dictionary in data.steps:
		if locations.has(s.location) and not is_done(s.id):
			out.append({"kind": "step", "id": s.id, "label": s.label, "tool": s.tool, "location": s.location})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.label < b.label)
	for location: String in locations:
		for item_id in inventory.items_at(location):
			out.append({"kind": "take", "id": item_id, "location": location,
				"label": data.message("take_action", {"item": data.item_label(item_id).to_lower()})})
	if inventory.held != "":
		out.append({"kind": "put", "id": inventory.held, "location": locations[0],
			"label": data.message("put_action", {"item": data.item_label(inventory.held).to_lower()})})
	return out


func attempt(step_id: String) -> StepResult:
	if not data.has_step(step_id):
		return StepResult.failure(StepResult.Kind.STEP, step_id, "unknown", "Unknown step '%s'." % step_id)
	var s := data.step(step_id)
	if is_done(step_id):
		return StepResult.failure(StepResult.Kind.STEP, step_id, "already_done", data.message("already_done"))

	for key: String in s.preconditions:
		if state.get(key) != s.preconditions[key]:
			var r := StepResult.failure(StepResult.Kind.STEP, step_id, "precondition", _fail_text(s, key), true)
			r.failed_key = key
			return _record(r)
	if s.tool != null and inventory.held != s.tool:
		return _record(StepResult.failure(StepResult.Kind.STEP, step_id, "wrong_tool", str(s.wrong_tool), true))

	if s.has("pattern"):
		if pattern == null or pattern_step != step_id:
			pattern = StarPattern.new(data.nut_count)
			pattern_step = step_id
		pattern_active = true
		var start := StepResult.success(StepResult.Kind.PATTERN_START, step_id,
			data.message("pattern_start", {"count": data.nut_count}))
		start.animations = [s.animations[0]]
		start.mechanics = s.mechanics
		return start
	return _complete(s, StepResult.success(StepResult.Kind.STEP, step_id, str(s.success)))


## During a pattern step: tighten nut `index` (0-based, around the hub).
func tighten_nut(index: int) -> StepResult:
	if not pattern_active:
		return StepResult.failure(StepResult.Kind.NUT, pattern_step, "no_pattern", "")
	var outcome := pattern.try(index)
	var r: StepResult
	match outcome:
		"ok":
			r = StepResult.success(StepResult.Kind.NUT, pattern_step, data.message("nut_ok", {"n": index + 1}))
		"done":
			r = StepResult.failure(StepResult.Kind.NUT, pattern_step, "nut_done", data.message("nut_done"))
		"wrong":
			r = _record(StepResult.failure(StepResult.Kind.NUT, pattern_step, "nut_wrong", data.message("nut_wrong"), true))
		_:
			r = StepResult.failure(StepResult.Kind.NUT, pattern_step, "invalid", "")
	r.nut = index
	if r.ok and pattern.is_complete():
		var s := data.step(pattern_step)
		pattern_active = false
		r.message = str(s.success)
		_complete(s, r)
	return r


## Leave the pattern step part-way; progress is kept for when the player returns.
func pause_pattern() -> void:
	pattern_active = false


func take(item_id: String, location: String) -> StepResult:
	var before := inventory.held
	var why := inventory.take(item_id, location)
	if why != "":
		return StepResult.failure(StepResult.Kind.TAKE, item_id, why,
			data.message("installed_item" if why == "installed" else "not_here"))
	var item := data.item_label(item_id).to_lower()
	var r: StepResult
	if before != "":
		r = StepResult.success(StepResult.Kind.TAKE, item_id,
			data.message("swapped", {"item": item, "old": data.item_label(before).to_lower()}))
		r.swapped_item = before
	else:
		r = StepResult.success(StepResult.Kind.TAKE, item_id, data.message("took", {"item": item}))
	changed.emit()
	return r


func put_down(location: String) -> StepResult:
	var item_id := inventory.held
	var why := inventory.put_down(location)
	if why != "":
		return StepResult.failure(StepResult.Kind.PUT, "", why, data.message("nothing_held"))
	changed.emit()
	return StepResult.success(StepResult.Kind.PUT, item_id,
		data.message("put", {"item": data.item_label(item_id).to_lower()}))


func _complete(s: Dictionary, r: StepResult) -> StepResult:
	for key: String in s.effects:
		state[key] = s.effects[key]
	if s.get("consumes_tool", false):
		inventory.consume_held()
	for item_id: String in s.get("item_moves", {}):
		inventory.move(item_id, s.item_moves[item_id])
	completed.append(s.id)
	r.completes_step = true
	r.animations = s.animations.duplicate()
	r.mechanics = s.mechanics
	r.procedure_complete = is_complete()
	if r.procedure_complete:
		r.message += "\n" + data.message("complete")
	changed.emit()
	return r


func _record(r: StepResult) -> StepResult:
	mistakes.append({"action": r.action_id, "reason": r.reason, "key": r.failed_key, "message": r.message})
	return r


func _fail_text(s: Dictionary, key: String) -> String:
	var text: Variant = s.fail.get(key, "")
	if typeof(text) == TYPE_DICTIONARY:
		var by_value: Dictionary = text
		return str(by_value.get(str(state.get(key)), by_value.get("*", "")))
	return str(text)
