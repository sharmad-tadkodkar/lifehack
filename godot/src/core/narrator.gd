class_name Narrator
extends RefCounted
## Chooses what the narrator says for each StepResult, from the procedure's "narration" lines:
## step successes read their success text (sometimes with a little cheer), mistakes get a quip
## opener before the consequence, routine pick-ups and individual nuts stay quiet (sound effects
## cover them). Pure logic: no nodes, no audio.

var data: ProcedureData
var rng := RandomNumberGenerator.new()
var _last := {}


func _init(procedure_data: ProcedureData, seed_value := -1) -> void:
	data = procedure_data
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()


func intro() -> String:
	return _pick("intro")


## The line for `result`, or "" to stay quiet.
func line_for(result: StepResult) -> String:
	if not result.ok:
		if result.message == "":
			return ""
		if result.reason == "wrong_tool":
			return _join(_pick("wrong_tool_openers"), result.message)
		if result.mistake:
			return _join(_pick("mistake_openers"), result.message)
		return result.message
	match result.kind:
		StepResult.Kind.STEP:
			return _join(_pick("success_tags"), result.message)
		StepResult.Kind.PATTERN_START:
			return result.message
		StepResult.Kind.NUT:
			return result.message if result.completes_step else ""
	return ""


func finish(mistakes: int) -> String:
	var key := "clean" if mistakes == 0 else ("few" if mistakes <= int(data.narration.get("few_mistakes_max", 2)) else "many")
	return _join(_pick_from(data.narration.get("finish", {}).get(key, []), "finish." + key), data.message("complete"))


func _pick(key: String) -> String:
	return _pick_from(data.narration.get(key, []), key)


## A random line, never the same one twice in a row for a key.
func _pick_from(lines: Array, key: String) -> String:
	if lines.is_empty():
		return ""
	var index := rng.randi_range(0, lines.size() - 1)
	if lines.size() > 1 and index == _last.get(key, -1):
		index = (index + 1) % lines.size()
	_last[key] = index
	return str(lines[index])


static func _join(a: String, b: String) -> String:
	return b if a == "" else (a if b == "" else a + " " + b)
