class_name CarRig
extends AssetSlot
## The car slot. On the interactive car, the model's flat wheel (assets.cfg flat_wheel_node)
## is moved under FlatWheelPivot so it can be unbolted and slid off along the pivot's +X.

@export var interactive := true
## Only used while the placeholder model is showing.
@export var placeholder_paint := Color(0.5, 0.03, 0.02)

var flat_wheel: Node3D

@onready var flat_wheel_pivot: Marker3D = $FlatWheelPivot


func _bind() -> void:
	if using_placeholder and model.has_method(&"set_paint"):
		model.set_paint(placeholder_paint)
	if not interactive:
		return
	flat_wheel = find_part("flat_wheel_node")
	if flat_wheel:
		flat_wheel.reparent(flat_wheel_pivot, true)
