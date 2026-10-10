class_name CameraDirector
extends Node3D
## Third-person follow camera (mouse orbit, spring-arm collision, smoothing) that can blend to
## fixed shots. A shot is any Camera3D node used as a marker: its transform and FOV are copied,
## so shots can be previewed and nudged in the editor. Used for the intro dolly and the
## close-ups while the player works on the car.

signal intro_finished

@export var target: Node3D

var _cfg := {}
var _shot: Camera3D
var _blend := 0.0
var _tween: Tween
var _intro_from: Camera3D
var _intro_t := -1.0
var mouse_capture_allowed := true

@onready var _yaw: Node3D = $Yaw
@onready var _pitch: Node3D = $Yaw/Pitch
@onready var _arm: SpringArm3D = $Yaw/Pitch/SpringArm3D
@onready var _anchor: Node3D = $Yaw/Pitch/SpringArm3D/Anchor
@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	camera.top_level = true
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_load_config()
	Config.reloaded.connect(_load_config)
	if target is CollisionObject3D:
		_arm.add_excluded_object((target as CollisionObject3D).get_rid())
	_pitch.rotation.x = deg_to_rad(_cfg.start_pitch)
	snap_to_target()
	camera.make_current()


func _load_config() -> void:
	_cfg = Config.section("camera", "follow")
	_cfg.merge(Config.section("camera", "shot"))
	_arm.spring_length = _cfg.distance
	_arm.margin = _cfg.collision_margin
	_arm.position.x = _cfg.shoulder_offset


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and mouse_capture_allowed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed(&"pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := (event as InputEventMouseMotion).relative * float(_cfg.mouse_sensitivity)
		_yaw.rotation.y -= motion.x
		var pitch_sign := 1.0 if _cfg.invert_y else -1.0
		_pitch.rotation.x = clampf(_pitch.rotation.x + motion.y * pitch_sign,
			deg_to_rad(_cfg.pitch_min), deg_to_rad(_cfg.pitch_max))


func _process(delta: float) -> void:
	var goal := _target_pivot()
	global_position = global_position.lerp(goal, 1.0 - exp(-float(_cfg.follow_smoothing) * delta))

	var xform := _anchor.global_transform
	var fov: float = _cfg.fov
	if _intro_t >= 0.0 and _intro_from:
		xform = _intro_from.global_transform.interpolate_with(_shot.global_transform, _intro_t)
		fov = lerpf(_intro_from.fov, _shot.fov, _intro_t)
	elif _shot:
		var t := smoothstep(0.0, 1.0, _blend)
		xform = xform.interpolate_with(_shot.global_transform, t)
		fov = lerpf(fov, _shot.fov, t)
	camera.global_transform = xform
	camera.fov = fov


## Yaw the player's input is relative to (whatever the camera is looking along right now).
func view_yaw() -> float:
	var forward := -camera.global_basis.z
	return atan2(-forward.x, -forward.z)


func set_follow_yaw(yaw: float) -> void:
	_yaw.rotation.y = yaw


func snap_to_target() -> void:
	if target:
		global_position = _target_pivot()


## Blend from wherever the camera is to a fixed shot.
func blend_to(shot: Camera3D, duration := -1.0) -> void:
	if _shot != shot:
		_blend = 0.0 if _shot == null else _blend
	_shot = shot
	_tween_blend(1.0, duration)


## Blend back to the follow camera.
func release(duration := -1.0) -> void:
	if _shot == null:
		return
	await _tween_blend(0.0, duration).finished
	if _blend <= 0.0:
		_shot = null


## Dolly from `from_shot` to `to_shot` over `duration`, then hand off to the follow camera.
func play_intro(from_shot: Camera3D, to_shot: Camera3D, duration: float, handoff: float) -> void:
	_intro_from = from_shot
	_shot = to_shot
	_blend = 1.0
	_intro_t = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "_intro_t", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _tween.finished
	_intro_t = -1.0
	_intro_from = null
	await release(handoff)
	intro_finished.emit()


func skip_intro() -> void:
	if _intro_t < 0.0:
		return
	if _tween:
		_tween.kill()
	_intro_t = -1.0
	_intro_from = null
	_shot = null
	_blend = 0.0
	intro_finished.emit()


func is_in_intro() -> bool:
	return _intro_t >= 0.0


func _tween_blend(to: float, duration: float) -> Tween:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	var seconds: float = _cfg.blend_time if duration < 0.0 else duration
	_tween.tween_property(self, "_blend", to, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return _tween


func _target_pivot() -> Vector3:
	var origin := target.get_global_transform_interpolated().origin if target else global_position
	return origin + Vector3(0.0, _cfg.height, 0.0)
