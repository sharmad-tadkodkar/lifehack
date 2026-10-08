class_name ProcedureData
extends RefCounted
## A procedure (e.g. config/procedure/flat_tire.json) loaded and validated. Pure data: no
## nodes, no rendering, so the logic built on it can be tested headless.
## Problems are collected in `errors` instead of crashing; check is_valid().

const STEP_KEYS := ["id", "order", "label", "location", "tool", "preconditions", "effects",
	"animations", "mechanics", "success", "fail"]
const INSTALLED := "installed"

var id := ""
var title := ""
var nut_count := 5
var initial_state: Dictionary = {}
var items: Dictionary = {}
var locations: Dictionary = {}
var messages: Dictionary = {}
var steps: Array[Dictionary] = []
var errors: PackedStringArray = []

var _by_id: Dictionary = {}


static func load_file(path: String) -> ProcedureData:
	var data := ProcedureData.new()
	if not FileAccess.file_exists(path):
		data.errors.append("missing file " + path)
		return data
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		data.errors.append("not a JSON object: " + path)
		return data
	data._read(parsed)
	return data


static func from_dict(source: Dictionary) -> ProcedureData:
	var data := ProcedureData.new()
	data._read(source.duplicate(true))
	return data


func is_valid() -> bool:
	return errors.is_empty()


func step(step_id: String) -> Dictionary:
	return _by_id.get(step_id, {})


func has_step(step_id: String) -> bool:
	return _by_id.has(step_id)


func step_ids_in_order() -> Array[String]:
	var ordered := steps.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.order < b.order)
	var out: Array[String] = []
	for s: Dictionary in ordered:
		out.append(s.id)
	return out


func item_label(item_id: String) -> String:
	return str(items.get(item_id, {}).get("label", item_id))


## Message from the "messages" table with {placeholders} filled in.
func message(key: String, args := {}) -> String:
	return str(messages.get(key, key)).format(args)


func _read(source: Dictionary) -> void:
	id = str(source.get("id", ""))
	title = str(source.get("title", ""))
	nut_count = int(source.get("nut_count", 5))
	initial_state = source.get("initial_state", {})
	items = source.get("items", {})
	locations = source.get("locations", {})
	messages = source.get("messages", {})
	for key in ["id", "initial_state", "items", "locations", "steps"]:
		if not source.has(key):
			errors.append("missing top-level '%s'" % key)
	if nut_count < 3:
		errors.append("nut_count must be at least 3")
	for item_id: String in items:
		var where := str(items[item_id].get("starts_at", ""))
		if where != INSTALLED and not locations.has(where):
			errors.append("item %s starts at unknown location '%s'" % [item_id, where])

	var orders := {}
	for raw: Variant in source.get("steps", []):
		if typeof(raw) != TYPE_DICTIONARY:
			errors.append("step is not an object")
			continue
		var s: Dictionary = raw
		s.order = int(s.get("order", 0))
		_validate_step(s)
		if _by_id.has(s.get("id", "")):
			errors.append("duplicate step id '%s'" % s.get("id", ""))
		if orders.has(s.order):
			errors.append("duplicate order %d" % s.order)
		orders[s.order] = true
		_by_id[s.get("id", "")] = s
		steps.append(s)
	for n in range(1, steps.size() + 1):
		if not orders.has(n):
			errors.append("step orders must run 1..%d (missing %d)" % [steps.size(), n])


func _validate_step(s: Dictionary) -> void:
	var sid := str(s.get("id", "?"))
	for key in STEP_KEYS:
		if not s.has(key):
			errors.append("step %s: missing '%s'" % [sid, key])
	if not locations.has(s.get("location", "")):
		errors.append("step %s: unknown location '%s'" % [sid, s.get("location", "")])
	var tool: Variant = s.get("tool")
	if tool != null and not items.has(tool):
		errors.append("step %s: unknown tool '%s'" % [sid, tool])
	if s.get("consumes_tool", false) and tool == null:
		errors.append("step %s: consumes_tool without a tool" % sid)
	for group in ["preconditions", "effects"]:
		for key: String in s.get(group, {}):
			if not initial_state.has(key):
				errors.append("step %s: %s key '%s' is not in initial_state" % [sid, group, key])
	for key: String in s.get("fail", {}):
		if not s.get("preconditions", {}).has(key):
			errors.append("step %s: fail text for '%s', which is not a precondition" % [sid, key])
	for key: String in s.get("preconditions", {}):
		if not s.get("fail", {}).has(key):
			errors.append("step %s: no fail text for precondition '%s'" % [sid, key])
	for item_id: String in s.get("item_moves", {}):
		var to := str(s.item_moves[item_id])
		if not items.has(item_id):
			errors.append("step %s: item_moves unknown item '%s'" % [sid, item_id])
		if to != INSTALLED and not locations.has(to):
			errors.append("step %s: item_moves to unknown location '%s'" % [sid, to])
	var anims: Variant = s.get("animations", [])
	if typeof(anims) != TYPE_ARRAY or (anims as Array).is_empty():
		errors.append("step %s: animations must be a non-empty list" % sid)
	if s.has("pattern") and str(s.pattern.get("type", "")) != "star":
		errors.append("step %s: unknown pattern '%s'" % [sid, s.pattern.get("type", "")])
	if tool != null and str(s.get("wrong_tool", "")) == "":
		errors.append("step %s: needs wrong_tool text" % sid)
