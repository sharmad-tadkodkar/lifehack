class_name AssetSlot
extends Node3D
## A swappable model. The scene ships with a placeholder child named "Model". If
## assets.cfg [slot] model points at a real file, that file replaces it at runtime:
##   part="NodeName"         use just that node of the file (e.g. one wheel out of a kit), centred
##   scale / offset / rotation_deg   fit the model to the slot
##   hide_materials=[...]    hide meshes whose material has one of these names
## Subclasses bind named parts in _bind().

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
	var part_name := str(_setting("part", ""))
	if part_name != "":
		real = _extract_part(real, part_name)
		if real == null:
			return
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
	hide_meshes_with_materials(model, _setting("hide_materials", []))


## Takes one named node out of a multi-model file (a kit) and centres it on the slot origin,
## keeping its orientation and scale within the file.
func _extract_part(root: Node3D, part_name: String) -> Node3D:
	var part := root.find_child(part_name, true, false) as Node3D
	if part == null:
		push_error("[slot %s] no node '%s' in the model (assets.cfg part)" % [slot, part_name])
		root.free()
		return null
	var in_file := Transform3D.IDENTITY
	var node: Node = part
	while node != root:
		in_file = (node as Node3D).transform * in_file if node is Node3D else in_file
		node = node.get_parent()
	part.get_parent().remove_child(part)
	root.free()
	_clear_owner(part)
	var holder := Node3D.new()
	holder.add_child(part)
	part.transform = Transform3D(in_file.basis, Vector3.ZERO)
	return holder


func _clear_owner(node: Node) -> void:
	node.owner = null
	for child in node.get_children():
		_clear_owner(child)


## Hides every mesh under `root` whose first material is named in `materials`.
static func hide_meshes_with_materials(root: Node, materials: Array) -> void:
	if materials.is_empty():
		return
	for mesh_instance: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var material := mesh_instance.get_active_material(0)
		if material and materials.has(material.resource_name):
			mesh_instance.visible = false


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
