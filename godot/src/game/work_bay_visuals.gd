class_name WorkBayVisuals
extends Node3D
## Puts every prop where the ProcedureModel says it is: car raised or not, nuts on/loose/off,
## which wheel is on the hub, and each item on its rest marker, in the player's hand, or in use.
## apply() snaps; animated transitions (ActionPlayer) end by calling it, so state and visuals
## can never drift apart.
##
## Every placement keeps each item's own scale (a real car's wheel is a node inside a scaled
## model; a real character's hand bone carries the character's scale), and items laid on a rest
## marker are settled onto it by their actual bounds, so any model sits on the surface.

@export var car: CarRig
@export var player: PlayerController
@export var lug_wrench: ItemRig
@export var jack: JackRig
@export var spare: ItemRig
@export var action_player: ActionPlayer

var model: ProcedureModel
var _spots: Array[InteractionSpot] = []
## instance id -> the item's own global scale, captured where it starts
var _scale_of: Dictionary = {}
## instance id -> AABB of the item's meshes in its own (unscaled) frame
var _bounds_of: Dictionary = {}


func setup(procedure: ProcedureModel) -> void:
	model = procedure
	for node in get_tree().get_nodes_in_group(&"interaction_spot"):
		_spots.append(node as InteractionSpot)
	car.setup_nuts(model.data.nut_count)
	for item_id: String in model.inventory.item_at:
		var node := item_node(item_id)
		if node:
			_scale_of[node.get_instance_id()] = node.global_basis.get_scale()
			_bounds_of[node.get_instance_id()] = _measure(node)
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


## Plays out a StepResult (ActionPlayer if there is one, otherwise everything snaps).
func present(result: StepResult) -> void:
	if action_player:
		await action_player.play(result)
	else:
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
				var spot := drop.global_transform.translated_local(Vector3(spacing * drop_index, 0.0, 0.0))
				_attach_global(node, self, settle(node, spot))
				return true
			_attach_global(node, self, settle(node, marker.global_transform))
	return false


## `xform` moved up or down so `node`, oriented that way, rests on the height of `xform.origin`.
func settle(node: Node3D, xform: Transform3D) -> Transform3D:
	var bounds: AABB = _bounds_of.get(node.get_instance_id(), AABB())
	if bounds.size == Vector3.ZERO:
		return xform
	var rotation := xform.basis.orthonormalized()
	var lowest := INF
	for i in 8:
		lowest = minf(lowest, (rotation * bounds.get_endpoint(i)).y)
	xform.origin.y -= lowest
	return xform


## Settled transform of `item_id` on its rest marker at `location`.
func rest_transform(item_id: String, location: String) -> Transform3D:
	var node := item_node(item_id)
	var marker := rest_marker(location, item_id)
	return settle(node, marker.global_transform) if marker else node.global_transform


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


## Where nut `i` lies in the pile once it is off the wheel.
func nut_pile_transform(i: int) -> Transform3D:
	var pile := rest_marker("wheel", "nuts")
	var offset := Vector3(0.035 * (i % 3), 0.0, 0.035 * floori(i / 3.0))
	return pile.global_transform.translated_local(offset) if pile else car.hub.global_transform


func _place_nuts(nut_state: String) -> void:
	var backout := float(Config.v("animation", "mechanics", "nut_backout"))
	for i in car.nuts.size():
		var nut := car.nuts[i]
		if nut_state == "removed":
			_attach_global(nut, self, nut_pile_transform(i))
		else:
			_attach(nut, car.hub, Transform3D(Basis.IDENTITY, car.nut_seat(i, backout if nut_state == "loose" else 0.0)))


func _update_pattern_labels() -> void:
	var on := model.pattern_active
	var done: Array[int] = model.pattern.tightened if model.pattern else ([] as Array[int])
	car.show_nut_labels(on, done, Config.v("ui", "colors", "dim"), Config.v("ui", "colors", "accent"))


func attach(node: Node3D, parent: Node3D, local: Transform3D) -> void:
	_attach(node, parent, local)


func attach_global(node: Node3D, xform: Transform3D) -> void:
	_attach_global(node, self, xform)


## `local` is relative to the parent's position and orientation, ignoring the parent's scale.
func _attach(node: Node3D, parent: Node3D, local: Transform3D) -> void:
	var frame := parent.global_transform
	frame.basis = frame.basis.orthonormalized()
	_attach_global(node, parent, frame * local)


func _attach_global(node: Node3D, parent: Node3D, xform: Transform3D) -> void:
	if node.get_parent() != parent:
		node.reparent(parent, false)
	var scale: Vector3 = _scale_of.get(node.get_instance_id(), Vector3.ONE)
	node.global_transform = Transform3D(Basis(xform.basis.get_rotation_quaternion()) * Basis.from_scale(scale), xform.origin)


## Bounds of the visible meshes under `node`, in `node`'s position + orientation frame.
func _measure(node: Node3D) -> AABB:
	var frame := Transform3D(node.global_basis.orthonormalized(), node.global_position).affine_inverse()
	var bounds := AABB()
	var first := true
	for mesh_instance: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if not mesh_instance.is_visible_in_tree() or mesh_instance.mesh == null:
			continue
		var box: AABB = (frame * mesh_instance.global_transform) * mesh_instance.mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds
