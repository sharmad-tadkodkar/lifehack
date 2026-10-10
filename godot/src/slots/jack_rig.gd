class_name JackRig
extends ItemRig
## The jack. The slot origin sits under the lifting point (saddle / piston). Two kinds of jack,
## chosen by assets.cfg [jack] lift_mode:
##   "rotate"     floor jack: lift_arm_node swings about its local X to raise the saddle
##   "translate"  bottle jack: every node in lift_nodes slides straight up (piston, screw)
## handle_node swings about its local X for each pump stroke. If the model has its own animation
## of the handle seated in its socket, handle_pose_clip / handle_pose_time borrow that pose.

var lift_arm: Node3D
var handle: Node3D
var lift_nodes: Array[Node3D] = []
var _arm_rest: Vector3
var _handle_rest: Transform3D
var _lift_rest: Array[Vector3] = []


func _bind() -> void:
	if str(_setting("lift_mode", "rotate")) == "translate":
		for node_name: String in _setting("lift_nodes", []):
			var node := model.find_child(node_name, true, false) as Node3D
			if node == null:
				push_error("[slot jack] model has no node '%s' (assets.cfg lift_nodes)" % node_name)
				continue
			lift_nodes.append(node)
			_lift_rest.append(node.position)
	else:
		lift_arm = find_part("lift_arm_node")
		if lift_arm:
			_arm_rest = lift_arm.rotation
	handle = find_part("handle_node")
	if handle:
		_apply_handle_pose()
		_handle_rest = handle.transform


## 0 = collapsed, 1 = holding the car at full lift height.
func set_lift(amount: float) -> void:
	if lift_arm:
		lift_arm.rotation.x = _arm_rest.x + amount * deg_to_rad(Config.v("animation", "mechanics", "jack_arm_raise_deg"))
	if lift_nodes.is_empty() or not is_inside_tree():
		return
	var rise := float(Config.v("animation", "mechanics", "car_lift_height")) * amount
	for i in lift_nodes.size():
		var node := lift_nodes[i]
		var up_in_parent: Vector3 = node.get_parent().global_basis.inverse() * Vector3.UP
		node.position = _lift_rest[i] + up_in_parent * rise


## -1..1 handle swing around its rest angle (a pump stroke goes 0 -> 1 -> 0).
func set_pump(amount: float) -> void:
	if handle:
		var swing := amount * deg_to_rad(Config.v("animation", "mechanics", "jack_pump_swing_deg"))
		handle.transform = _handle_rest * Transform3D(Basis(Vector3.RIGHT, swing), Vector3.ZERO)


func _apply_handle_pose() -> void:
	var clip := str(_setting("handle_pose_clip", ""))
	if clip == "":
		return
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty() or not (players[0] as AnimationPlayer).has_animation(clip):
		push_error("[slot jack] no animation '%s' for handle_pose_clip" % clip)
		return
	var player := players[0] as AnimationPlayer
	var anim := player.get_animation(clip)
	var root := player.get_node(player.root_node)
	var path := root.get_path_to(handle)
	var t := float(_setting("handle_pose_time", 0.0))
	var pos_track := anim.find_track(path, Animation.TYPE_POSITION_3D)
	var rot_track := anim.find_track(path, Animation.TYPE_ROTATION_3D)
	if pos_track >= 0:
		handle.position = anim.position_track_interpolate(pos_track, t)
	if rot_track >= 0:
		handle.quaternion = anim.rotation_track_interpolate(rot_track, t)
