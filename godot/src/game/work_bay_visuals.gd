class_name WorkBayVisuals
extends Node3D
## Puts every prop where the ProcedureModel says it is: car raised or not, nuts on/loose/off,
## which wheel is on the hub, and each item on its rest marker, in the player's hand, or in use.
## apply() snaps; animated transitions (ActionPlayer) end by calling it, so state and visuals
## can never drift apart.

@export var car: CarRig
@export var player: PlayerController
@export var lug_wrench: ItemRig
@export var jack: JackRig
@export var spare: ItemRig

var model: ProcedureModel
var _spots: Array[InteractionSpot] = []


func setup(procedure: ProcedureModel) -> void:
	model = procedure
	for node in get_tree().get_nodes_in_group(&"interaction_spot"):
		_spots.append(node as InteractionSpot)
	car.setup_nuts(model.data.nut_count)
	apply()


func apply() -> void:
	car.set_raise(1.0 if model.state.car_raised else 0.0)
	_place_nuts(str(model.state.nuts))
	var drops := {}
	for item_id: String in model.inventory.item_at:
		var where := model.inventory.location_of(item_id)
		var index: int = drops.get(where, 0)
		if place_item(item_id, where, index):
			drops[where] = index + 1
	jack.set_lift(car.raise_amount if model.inventory.location_of("jack") == Inventory.INSTALLED else 0.0)
	jack.set_pump(0.0)
	_update_pattern_labels()


## Plays out a StepResult. For now everything snaps; the animation milestone replaces this
## with character clips and tweens that end in the same state.
func present(_result: StepResult) -> void:
	apply()
	await get_tree().process_frame


func item_node(item_id: String) -> Node3D:
	match item_id:
		"lug_wrench":
			return lug_wrench
		"jack":
			return jack
		"spare":
			return spare
		"flat":
			return car.flat_wheel
	return null


## Moves an item to `location`. Returns true when it used the location's shared drop marker.
func place_item(item_id: String, location: String, drop_index := 0) -> bool:
	var node := item_node(item_id)
	if node == null:
		return false
	match location:
		Inventory.HANDS:
			_attach(node, player.rig.hand_socket, hold_transform(item_id))
		Inventory.INSTALLED:
			match item_id:
				"jack":
					_attach_global(node, self, car.jack_ground_transform())
				"flat":
					_attach(node, car.hub, car.flat_wheel_rest)
				_:
					_attach(node, car.hub, Transform3D.IDENTITY)
		_:
			var marker := rest_marker(location, item_id)
			if marker == null:
				var drop := rest_marker(location, "drop")
				if drop == null:
					push_error("[visuals] no rest for %s at %s" % [item_id, location])
					return false
				var spacing := float(Config.v("animation", "mechanics", "drop_spacing"))
				_attach_global(node, self, drop.global_transform.translated_local(Vector3(spacing * drop_index, 0.0, 0.0)))
				return true
			_attach_global(node, self, marker.global_transform)
	return false


func hold_transform(item_id: String) -> Transform3D:
	var node := item_node(item_id)
	if node is ItemRig:
		return (node as ItemRig).hold_transform()
	return spare.hold_transform()  # the flat is carried like the spare


func rest_marker(location: String, key: String) -> Node3D:
	for spot in _spots:
		if spot.covers(location):
			var marker := spot.rest_for(location, key)
			if marker:
				return marker
	return null


func spot_for(location: String) -> InteractionSpot:
	for spot in _spots:
		if spot.covers(location):
			return spot
	return null


func _place_nuts(nut_state: String) -> void:
	var backout := float(Config.v("animation", "mechanics", "nut_backout"))
	var pile := rest_marker("wheel", "nuts")
	for i in car.nuts.size():
		var nut := car.nuts[i]
		if nut_state == "removed" and pile:
			var offset := Vector3(0.035 * (i % 3), 0.0, 0.035 * floori(i / 3.0))
			_attach_global(nut, self, pile.global_transform.translated_local(offset))
		else:
			_attach(nut, car.hub, Transform3D(Basis.IDENTITY, car.nut_seat(i, backout if nut_state == "loose" else 0.0)))


func _update_pattern_labels() -> void:
	var on := model.pattern_active
	var done: Array[int] = model.pattern.tightened if model.pattern else ([] as Array[int])
	car.show_nut_labels(on, done, Config.v("ui", "colors", "dim"), Config.v("ui", "colors", "accent"))


func _attach(node: Node3D, parent: Node3D, local: Transform3D) -> void:
	if node.get_parent() != parent:
		node.reparent(parent, false)
	node.transform = local


func _attach_global(node: Node3D, parent: Node3D, xform: Transform3D) -> void:
	if node.get_parent() != parent:
		node.reparent(parent, false)
	node.global_transform = xform
