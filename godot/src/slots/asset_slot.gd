class_name AssetSlot
extends Node3D
## A swappable model. The scene ships with a placeholder child named "Model". If
## assets.cfg [slot] model points at a real file, that file replaces it at runtime, with
## the slot's scale/offset/rotation_deg applied. Subclasses bind named parts in _bind().

@export var slot := ""
## Where the placeholder model sits inside this scene.
@export var model_path := NodePath("Model")

var model: Node3D
var using_placeholder := true


func _ready() -> void:
	model = get_node_or_null(model_path) as Node3D
	var path := str(_setting("model", ""))
	if path != "":
		_swap_in(path)
	_bind()


func _swap_in(path: String) -> void:
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("[slot %s] could not load %s, keeping the placeholder" % [slot, path])
		return
	var real := scene.instantiate() as Node3D
	real.scale = Vector3.ONE * float(_setting("scale", 1.0))
	real.position = _setting("offset", Vector3.ZERO)
	var deg: Vector3 = _setting("rotation_deg", Vector3.ZERO)
	real.rotation = Vector3(deg_to_rad(deg.x), deg_to_rad(deg.y), deg_to_rad(deg.z))
	var parent: Node = model.get_parent() if model else self
	if model:
		parent.remove_child(model)
		model.free()
	real.name = "Model"
	parent.add_child(real)
	parent.move_child(real, 0)
	model = real
	using_placeholder = false


## Override to look up the parts the code animates (see find_part).
func _bind() -> void:
	pass


## Finds the node named by assets.cfg [slot] <key> inside the model.
func find_part(key: String) -> Node3D:
	var part_name := str(_setting(key, ""))
	var part := model.find_child(part_name, true, false) as Node3D if model else null
	if part == null:
		push_error("[slot %s] model has no node '%s' (assets.cfg %s)" % [slot, part_name, key])
	return part


func _setting(key: String, fallback: Variant) -> Variant:
	return Config.v("assets", slot, key) if Config.has("assets", slot, key) else fallback
