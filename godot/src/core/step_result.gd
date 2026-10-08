class_name StepResult
extends RefCounted
## Outcome of one player action, returned by ProcedureModel. The visual layer reads it to
## decide what to animate; the HUD reads `message`.

enum Kind { STEP, TAKE, PUT, NUT, PATTERN_START }

var ok := false
var kind := Kind.STEP
## Step id for STEP / PATTERN_START / NUT, item id for TAKE / PUT.
var action_id := ""
## "", "precondition", "wrong_tool", "already_done", "unknown", "hands_full", "nothing_held",
## "not_here", "installed", "nut_wrong", "nut_done", "no_pattern"
var reason := ""
## The state key whose precondition failed.
var failed_key := ""
var message := ""
## Counts against the player (wrong order, wrong tool, wrong nut).
var mistake := false
var animations: Array = []
var mechanics := ""
var nut := -1
## The item set down when a take swapped what was in the player's hands.
var swapped_item := ""
## True when this action finished a step and changed the state.
var completes_step := false
var procedure_complete := false


static func success(kind_: Kind, action: String, text: String) -> StepResult:
	var r := StepResult.new()
	r.ok = true
	r.kind = kind_
	r.action_id = action
	r.message = text
	return r


static func failure(kind_: Kind, action: String, why: String, text: String, is_mistake := false) -> StepResult:
	var r := StepResult.new()
	r.kind = kind_
	r.action_id = action
	r.reason = why
	r.message = text
	r.mistake = is_mistake
	return r
