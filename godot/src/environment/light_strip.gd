@tool
class_name LightStrip
extends Node3D
## An LED/neon tube with a matching rectangular area light shining along the strip's -Y.
## Length and width are layout (set per instance in the scene); colour and brightness come
## from lighting.cfg [strip.<group>] via LightingRig.

@export var group := "ceiling"
@export var length := 2.4:
	set(value):
		length = value
		_rebuild()
@export var width := 0.06:
	set(value):
		width = value
		_rebuild()
@export var cast_light := true

var _tube: MeshInstance3D
var _light: AreaLight3D
var _material := StandardMaterial3D.new()


func _ready() -> void:
	add_to_group(&"light_strip")
	_material.albedo_color = Color.BLACK
	_material.emission_enabled = true
	_rebuild()


func apply(settings: Dictionary) -> void:
	var color: Color = settings.get("color", Color.WHITE)
	_material.emission = color
	_material.emission_energy_multiplier = settings.get("emission_energy", 1.0)
	if _light:
		_light.light_color = color
		_light.light_energy = settings.get("light_energy", 1.0)
		_light.area_range = settings.get("light_range", 5.0)
		_light.shadow_enabled = settings.get("shadows", false)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _tube == null:
		_tube = MeshInstance3D.new()
		_tube.mesh = BoxMesh.new()
		_tube.material_override = _material
		_tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_tube)
	(_tube.mesh as BoxMesh).size = Vector3(length, width, width)
	if cast_light and _light == null:
		_light = AreaLight3D.new()
		_light.rotation = Vector3(-PI / 2.0, 0.0, 0.0)
		_light.position.y = -width
		add_child(_light)
	if _light:
		_light.area_size = Vector2(length, width * 2.0)
