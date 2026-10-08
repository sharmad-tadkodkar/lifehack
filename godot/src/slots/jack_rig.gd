class_name JackRig
extends ItemRig
## Floor jack. The model's lift arm and handle (assets.cfg handle_node / lift_arm_node) are
## separate nodes pivoting at their hinges: the arm swings up to raise the saddle, the handle
## swings for each pump stroke. The slot origin sits under the saddle.

var lift_arm: Node3D
var handle: Node3D
var _arm_rest: Vector3
var _handle_rest: Vector3


func _bind() -> void:
	lift_arm = find_part("lift_arm_node")
	handle = find_part("handle_node")
	if lift_arm:
		_arm_rest = lift_arm.rotation
	if handle:
		_handle_rest = handle.rotation


## 0 = arm down, 1 = saddle up at full car lift height.
func set_lift(amount: float) -> void:
	if lift_arm:
		lift_arm.rotation.x = _arm_rest.x + amount * deg_to_rad(Config.v("animation", "mechanics", "jack_arm_raise_deg"))


## -1..1 handle swing around its rest angle (a pump stroke goes 0 -> 1 -> 0).
func set_pump(amount: float) -> void:
	if handle:
		handle.rotation.x = _handle_rest.x + amount * deg_to_rad(Config.v("animation", "mechanics", "jack_pump_swing_deg"))
