class_name ProcedureController
extends Node
## Bridges the pure ProcedureModel and the 3D world. Walking into an InteractionSpot shows a
## prompt; E opens that spot's action menu (the player walks to the stand mark and the camera
## blends to the close-up); number keys choose; the model judges the choice and the StepResult
## is shown (HUD) and played out (WorkBayVisuals -> ActionPlayer).

signal finished
## E pressed on the end summary.
signal play_again_requested

@export var player: PlayerController
@export var director: CameraDirector
@export var visuals: WorkBayVisuals
@export var hud: Hud
## Camera shot for the end summary.
@export var outro_shot: Camera3D

var model: ProcedureModel
var running := false
var elapsed := 0.0
var menu_open := false
var busy := false
var autoplaying := false

var _nearby: Array[InteractionSpot] = []
var _spot: InteractionSpot
var _location := ""
var _actions: Array[Dictionary] = []


func _ready() -> void:
	var data := ProcedureData.load_file(Config.v("game", "procedure", "file"))
	if not data.is_valid():
		push_error("[procedure] invalid procedure data:\n" + "\n".join(data.errors))
	model = ProcedureModel.new(data)
	visuals.setup(model)
	for spot: InteractionSpot in get_tree().get_nodes_in_group(&"interaction_spot"):
		spot.player_entered.connect(_on_spot_entered)
		spot.player_exited.connect(_on_spot_exited)


func start() -> void:
	running = true
	hud.update_status(model, elapsed)
	_refresh_prompt()


func _process(delta: float) -> void:
	if running:
		elapsed += delta
		hud.update_status(model, elapsed)


func _unhandled_input(event: InputEvent) -> void:
	if model.is_complete() and not running:
		if event.is_action_pressed(&"interact"):
			play_again_requested.emit()
		return
	if not running or busy or autoplaying:
		return
	if menu_open:
		for i in 9:
			if event.is_action_pressed(StringName("choice_%d" % (i + 1))):
				get_viewport().set_input_as_handled()
				choose(i)
				return
		if event.is_action_pressed(&"cancel"):
			close_menu()
	elif _spot and event.is_action_pressed(&"interact"):
		open_menu()


func open_menu(spot: InteractionSpot = null) -> void:
	if spot:
		_spot = spot
	menu_open = true
	busy = true
	player.controls_enabled = false
	hud.show_prompt("")
	await _stage(_spot.primary_location())
	busy = false
	_refresh_menu()


func close_menu() -> void:
	busy = true
	hud.hide_menu()
	model.pause_pattern()
	await visuals.action_player.stand_if_kneeling()
	visuals.apply()
	menu_open = false
	busy = false
	director.release()
	player.controls_enabled = true
	if not _nearby.has(_spot):
		_spot = _nearby[-1] if not _nearby.is_empty() else null
	_refresh_prompt()


## The actions currently on the menu (step / take / put), in display order.
func current_actions() -> Array[Dictionary]:
	return _actions


## Menu row `index` (0-based). During the star pattern the rows are the nuts.
func choose(index: int) -> void:
	if busy:
		return
	if model.pattern_active:
		if index < model.data.nut_count:
			await perform_nut(index)
	elif index < _actions.size():
		await perform(_actions[index])


func perform(action: Dictionary) -> void:
	if action.location != _location:
		busy = true
		await _stage(action.location)
	var result: StepResult
	match action.kind:
		"step":
			result = model.attempt(action.id)
		"take":
			result = model.take(action.id, action.location)
		"put":
			result = model.put_down(action.location)
	await _present(result)


func perform_nut(index: int) -> void:
	await _present(model.tighten_nut(index))


## Plays the real procedure from the data: fetch each step's tool, walk to the step's spot, do it.
func autoplay() -> void:
	autoplaying = true
	for step_id in model.data.step_ids_in_order():
		var s := model.data.step(step_id)
		if s.tool != null and model.held_item() != s.tool:
			var where := model.inventory.location_of(s.tool)
			await _go_to(where)
			await perform({"kind": "take", "id": s.tool, "location": where})
		await _go_to(s.location)
		await perform({"kind": "step", "id": step_id, "location": s.location})
		while model.pattern_active:
			await perform_nut(model.pattern.valid_next()[0])
	autoplaying = false


## Mistakes are explained straight away; successes are described once they have played out.
func _present(result: StepResult) -> void:
	busy = true
	hud.hide_menu()
	if not result.ok:
		hud.toast(result)
	await visuals.present(result)
	if result.ok:
		hud.toast(result)
	hud.update_status(model, elapsed)
	busy = false
	if model.is_complete():
		_finish()
	elif menu_open:
		_refresh_menu()


func _finish() -> void:
	running = false
	menu_open = false
	hud.hide_menu()
	hud.show_summary(model, elapsed)
	if outro_shot:
		director.blend_to(outro_shot, Config.v("camera", "intro", "handoff"))
	else:
		director.release()
	finished.emit()


## Walk to the stand mark for `location` within the current spot and frame its close-up.
func _stage(location: String) -> void:
	_location = location
	director.blend_to(_spot.cam_for(location))
	var stand := _spot.stand_for(location)
	if stand.global_position.distance_to(player.global_position) > 0.08:
		await player.walk_to(stand)
	else:
		player.snap_to(stand)


## Autoplay: walk from wherever the player is to the spot covering `location`, going around the
## car via the spots' Approach markers, and open its menu.
func _go_to(location: String) -> void:
	var target := visuals.spot_for(location)
	if menu_open and _spot == target:
		if _location != location:
			await _stage(location)
		return
	if menu_open:
		await close_menu()
	var leaving := _spot
	if leaving and leaving != target and leaving.has_node(^"Approach"):
		await player.walk_to(leaving.get_node(^"Approach"))
	if target.has_node(^"Approach"):
		await player.walk_to(target.get_node(^"Approach"))
	await open_menu(target)
	if _location != location:
		await _stage(location)


## Debug / look-dev: perform the first `count` steps of the real procedure instantly.
func debug_fast_forward(count: int) -> void:
	for step_id in model.data.step_ids_in_order().slice(0, count):
		var tool: Variant = model.data.step(step_id).tool
		if tool != null and model.inventory.location_of(tool) != Inventory.HANDS:
			model.take(tool, model.inventory.location_of(tool))
		model.attempt(step_id)
		while model.pattern_active:
			model.tighten_nut(model.pattern.valid_next()[0])
	visuals.apply()
	hud.update_status(model, elapsed)
	if model.is_complete():
		_finish()


## Debug / look-dev: open the menu of the spot covering `location`.
func debug_open(location: String) -> void:
	var spot := visuals.spot_for(location)
	if spot == null:
		return
	await open_menu(spot)
	if location != spot.primary_location():
		await _stage(location)


func _refresh_menu() -> void:
	var rows: Array[String] = []
	if model.pattern_active:
		for i in model.data.nut_count:
			rows.append("Nut %d%s" % [i + 1, "   (tight)" if model.pattern.tightened.has(i) else ""])
		hud.show_menu(model.data.step(model.pattern_step).label, rows, "step away")
		visuals.apply()
		return
	_actions = model.actions_at(Array(_spot.locations))
	for action in _actions:
		var text: String = action.label
		if action.kind == "step" and action.tool != null:
			text += "   · " + model.data.item_label(action.tool).to_lower()
		rows.append(text)
	hud.show_menu(str(model.data.locations.get(_spot.primary_location(), "")), rows, "step away")


func _refresh_prompt() -> void:
	if not running or menu_open or _spot == null:
		hud.show_prompt("")
		return
	hud.show_prompt("E    " + str(model.data.locations.get(_spot.primary_location(), "")))


## While a menu is open the working spot is locked; physics enter/exit events (which can
## arrive a tick late) only update the list of nearby spots.
func _on_spot_entered(spot: InteractionSpot) -> void:
	if not _nearby.has(spot):
		_nearby.append(spot)
	if not menu_open:
		_spot = spot
	_refresh_prompt()


func _on_spot_exited(spot: InteractionSpot) -> void:
	_nearby.erase(spot)
	if not menu_open:
		_spot = _nearby[-1] if not _nearby.is_empty() else null
	_refresh_prompt()
