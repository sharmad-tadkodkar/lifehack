class_name NpcPatrol
extends CharacterBody3D
## An NPC that walks a loop of NpcWaypoint markers and does each one's task. It is a physics
## body, so it stops for (and is blocked by) the player; if blocked too long it moves on.
## Speeds and timings: npc.cfg [mechanic].

@export var waypoints: Node3D

## Emitted every physics tick. Coroutines await this (not the SceneTree) so that freeing the NPC
## mid-walk simply drops them instead of resuming on a freed object.
signal _ticked

var _cfg := {}
var _target := Vector3.ZERO
var _moving := false

@onready var rig: CharacterRig = $CharacterRig


func _ready() -> void:
	_cfg = Config.section("npc", "mechanic")
	Config.reloaded.connect(func() -> void: _cfg = Config.section("npc", "mechanic"))
	_patrol()


func _physics_process(delta: float) -> void:
	var wish := Vector3.ZERO
	if _moving:
		var to := _target - global_position
		to.y = 0.0
		if to.length() <= float(_cfg.arrive_radius):
			_moving = false
		else:
			wish = to.normalized() * float(_cfg.walk_speed)
	velocity.x = wish.x
	velocity.z = wish.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - float(_cfg.gravity) * delta
	move_and_slide()
	var ground := Vector3(velocity.x, 0.0, velocity.z)
	if ground.length() > 0.05:
		_turn_toward(ground, delta)
	if rig.locomotion_enabled:
		rig.set_locomotion(get_real_velocity().length())
	_ticked.emit()


func _patrol() -> void:
	var stops: Array[NpcWaypoint] = []
	for child in waypoints.get_children():
		if child is NpcWaypoint:
			stops.append(child)
	if stops.is_empty():
		return
	while is_inside_tree():
		for stop in stops:
			await _walk_to(stop)
			if not is_inside_tree():
				return
			await _face(-stop.global_basis.z)
			await _do(stop.task)


func _walk_to(stop: NpcWaypoint) -> void:
	rig.locomotion_enabled = true
	_target = stop.global_position
	_moving = true
	var stuck := 0.0
	while _moving and is_inside_tree():
		await _ticked
		if get_real_velocity().length() < 0.1:
			stuck += get_physics_process_delta_time()
			if stuck > float(_cfg.blocked_timeout):
				_moving = false
		else:
			stuck = 0.0


func _face(direction: Vector3) -> void:
	var t := 0.0
	while t < 0.6 and is_inside_tree():
		_turn_toward(direction, get_physics_process_delta_time())
		await _ticked
		t += get_physics_process_delta_time()


func _do(task: String) -> void:
	rig.locomotion_enabled = false
	var hold := randf_range(_cfg.task_min, _cfg.task_max)
	match task:
		"inspect":
			await _play_and_wait("kneel_down")
			rig.play("kneel_idle")
			await _wait(hold)
			await _play_and_wait("stand_up")
		"work_overhead":
			rig.play(task)
			await _wait(hold)
		"look_around", "browse_shelf":
			await _play_and_wait(task)
		_:
			rig.play("idle")
			await _wait(hold)
	rig.play("idle")


## Sleeps on a Timer this NPC owns (freed with it), for the same reason as _ticked.
func _wait(seconds: float) -> void:
	var timer := Timer.new()
	timer.one_shot = true
	add_child(timer)
	timer.start(maxf(seconds, 0.01))
	await timer.timeout
	timer.queue_free()


func _play_and_wait(clip: String) -> void:
	rig.play(clip)
	await _wait(rig.clip_length(clip))


func _turn_toward(direction: Vector3, delta: float) -> void:
	var yaw := atan2(-direction.x, -direction.z)
	rig.rotation.y = lerp_angle(rig.rotation.y, yaw, 1.0 - exp(-float(_cfg.turn_rate) * delta))
