class_name CarRig
extends AssetSlot
## The car slot. Everything that moves when the car is jacked (model, collision, hub, jack point)
## sits under `Chassis`, which tilts about `LiftPivot` (the far side's tyres). On the
## interactive car the model's flat wheel (assets.cfg flat_wheel_node) moves under the hub
## pivot (`FlatWheelPivot`, +X pointing out of the car), and separate lug nuts are laid out
## on the bolt circle there.

const LUG_NUT := preload("res://scenes/props/lug_nut.tscn")

@export var interactive := true
## Only used while the placeholder model is showing.
@export var placeholder_paint := Color(0.5, 0.03, 0.02)

var flat_wheel: Node3D
## The flat's resting transform on the hub (restored when it goes back on).
var flat_wheel_rest := Transform3D.IDENTITY
var nuts: Array[Node3D] = []
## 0 = on the ground, 1 = fully raised.
var raise_amount := 0.0

var _nut_labels: Array[Label3D] = []
var _nut_count := 0

@onready var chassis: Node3D = $Chassis
@onready var hub: Marker3D = $Chassis/FlatWheelPivot
@onready var jack_point: Marker3D = $Chassis/JackPoint
@onready var lift_pivot: Marker3D = $LiftPivot


func _bind() -> void:
	if using_placeholder and model.has_method(&"set_paint"):
		model.set_paint(placeholder_paint)
	if not interactive:
		# Set dressing only (e.g. the car on the lift): no interaction spots.
		var spots := get_node_or_null(^"Spots")
		if spots:
			for spot in spots.get_children():
				spot.remove_from_group(&"interaction_spot")
			spots.free()
		return
	flat_wheel = find_part("flat_wheel_node")
	if flat_wheel:
		# A real model's wheel defines where the hub is; the marker only keeps its orientation.
		if not using_placeholder and _setting("align_hub_to_flat_wheel", false):
			hub.global_position = flat_wheel.global_position
		flat_wheel.reparent(hub, true)
		flat_wheel_rest = flat_wheel.transform
		# e.g. lug bolts baked into the wheel mesh: the game's own nuts replace them
		AssetSlot.hide_meshes_with_materials(flat_wheel, _setting("flat_wheel_hide_materials", []))


## Creates `count` lug nuts on the hub (count comes from the procedure data).
func setup_nuts(count: int) -> void:
	for nut in nuts:
		nut.queue_free()
	nuts.clear()
	_nut_labels.clear()
	_nut_count = count
	for i in count:
		var nut := LUG_NUT.instantiate() as Node3D
		nut.name = "LugNut%d" % (i + 1)
		hub.add_child(nut)
		nut.position = nut_seat(i)
		nuts.append(nut)
		var label := Label3D.new()
		label.text = str(i + 1)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.fixed_size = true
		label.pixel_size = 0.0011
		label.font = load(str(Config.v("ui", "fonts", "display")))
		label.font_size = 26
		label.outline_size = 10
		label.visible = false
		hub.add_child(label)
		label.position = nut_seat(i) * Vector3(1.0, 1.9, 1.9) + Vector3(0.03, 0.0, 0.0)
		_nut_labels.append(label)


## Seat position of nut `i` in hub space. Numbered clockwise from the top as seen from outside.
func nut_seat(i: int, backed_out := 0.0) -> Vector3:
	var angle := TAU * i / float(maxi(_nut_count, 1))
	var r := float(_setting("bolt_circle_radius", 0.0572))
	var x := float(_setting("nut_seat_offset", 0.112)) + backed_out
	return Vector3(x, r * cos(angle), -r * sin(angle))


## Tilts the chassis about LiftPivot so the jack point rises by car_lift_height * amount.
func set_raise(amount: float) -> void:
	raise_amount = amount
	var lift := float(Config.v("animation", "mechanics", "car_lift_height")) * amount
	var arm := lift_pivot.position.x - jack_point_rest_position().x
	var angle := -atan2(lift, absf(arm)) * signf(arm)
	var pivot := Transform3D(Basis.IDENTITY, lift_pivot.position)
	chassis.transform = pivot * Transform3D(Basis(Vector3.BACK, angle), Vector3.ZERO) * pivot.affine_inverse()


func jack_point_rest_position() -> Vector3:
	return jack_point.position


## Where the jack stands when placed: on the floor under the jack point, saddle toward the car.
func jack_ground_transform() -> Transform3D:
	var spot := jack_point.global_position
	spot.y = global_position.y
	var inward := global_basis.x
	inward.y = 0.0
	return Transform3D(Basis.looking_at(inward.normalized(), Vector3.UP), spot)


## Numbers floating by each nut during the star-pattern step; tightened ones dim.
func show_nut_labels(on: bool, tightened: Array[int] = [], dim := Color.GRAY, live := Color.WHITE) -> void:
	for i in _nut_labels.size():
		_nut_labels[i].visible = on
		_nut_labels[i].modulate = dim if tightened.has(i) else live
