class_name PlayerController
extends CharacterBody3D
## Camera-relative WASD movement with a jog, gravity and smoothed turning. The body never
## rotates; the CharacterRig child turns to face the direction of travel.

@export var camera_director: CameraDirector

## Off during the intro and while an action plays.
var controls_enabled := true

var _cfg := {}

@onready var rig: CharacterRig = $CharacterRig


func _ready() -> void:
	_load_config()
	Config.reloaded.connect(_load_config)


func _load_config() -> void:
	_cfg = Config.section("player", "movement")


func _physics_process(delta: float) -> void:
	var wish := Vector3.ZERO
	if controls_enabled:
		var input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
		if input != Vector2.ZERO:
			wish = (Basis(Vector3.UP, camera_director.view_yaw()) * Vector3(input.x, 0.0, input.y)).limit_length(1.0)

	var speed: float = _cfg.jog_speed if Input.is_action_pressed(&"jog") else _cfg.walk_speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var rate: float = _cfg.acceleration if wish != Vector3.ZERO else _cfg.deceleration
	horizontal = horizontal.move_toward(wish * speed, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - _cfg.gravity * delta
	move_and_slide()

	var ground_speed := Vector3(velocity.x, 0.0, velocity.z).length()
	if ground_speed > 0.05:
		face_direction(Vector3(velocity.x, 0.0, velocity.z), delta)
	rig.set_locomotion(ground_speed)


## Turns the visible body toward `direction` (instantly when delta is 0).
func face_direction(direction: Vector3, delta := 0.0) -> void:
	var target := atan2(-direction.x, -direction.z)
	var weight := 1.0 if delta <= 0.0 else 1.0 - exp(-float(_cfg.turn_rate) * delta)
	rig.rotation.y = lerp_angle(rig.rotation.y, target, weight)


## Puts the player on a stand marker, facing along the marker's -Z.
func snap_to(marker: Node3D) -> void:
	var spot := marker.global_position
	spot.y = global_position.y
	global_position = spot
	velocity = Vector3.ZERO
	reset_physics_interpolation()
	face_direction(-marker.global_basis.z)
	rig.set_locomotion(0.0)


func facing_yaw() -> float:
	return rig.global_rotation.y
