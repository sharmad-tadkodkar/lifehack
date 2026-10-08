class_name ProcedureController
extends Node
## Bridges the pure ProcedureModel and the 3D world. Walking into an InteractionSpot shows a
## prompt; E opens that spot's action menu (camera blends to the close-up); number keys choose;
## the model judges the choice and the StepResult is shown (HUD) and played out (visuals).

signal finished

@export var player: PlayerController
@export var director: CameraDirector
@export var visuals: WorkBayVisuals
@export var hud: Hud

var model: ProcedureModel
var running := false
var elapsed := 0.0
var menu_open := false
var busy := false

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
			get_tree().reload_current_scene()
		return
	if not running or busy:
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
	player.controls_enabled = false
	hud.show_prompt("")
	_stage(_spot.primary_location())
	_refresh_menu()


func close_menu() -> void:
	menu_open = false
	model.pause_pattern()
	visuals.apply()
	hud.hide_menu()
	director.release()
	player.controls_enabled = true
	if not _nearby.has(_spot):
		_spot = _nearby[-1] if not _nearby.is_empty() else null
	_refresh_prompt()


## The actions currently on the menu (step / take / put), in display order.
func current_actions() -> Array[Dictionary]:
	return _actions


func choose(index: int) -> void:
	if busy:
		return
	var result: StepResult
	if model.pattern_active:
		if index >= model.data.nut_count:
			return
		result = model.tighten_nut(index)
	else:
		if index >= _actions.size():
			return
		var action := _actions[index]
		if action.location != _location:
			_stage(action.location)
		match action.kind:
			"step":
				result = model.attempt(action.id)
			"take":
				result = model.take(action.id, action.location)
			"put":
				result = model.put_down(action.location)
	await _present(result)
	if model.is_complete():
		_finish()
	elif menu_open:
		_refresh_menu()


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
	for spot: InteractionSpot in get_tree().get_nodes_in_group(&"interaction_spot"):
		if spot.covers(location):
			open_menu(spot)
			if location != spot.primary_location():
				_stage(location)
			return


func _present(result: StepResult) -> void:
	busy = true
	hud.hide_menu()
	hud.toast(result)
	await visuals.present(result)
	hud.update_status(model, elapsed)
	busy = false


func _finish() -> void:
	running = false
	menu_open = false
	hud.hide_menu()
	hud.show_summary(model, elapsed)
	director.release()
	finished.emit()


func _stage(location: String) -> void:
	_location = location
	player.snap_to(_spot.stand_for(location))
	director.blend_to(_spot.cam_for(location))


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
