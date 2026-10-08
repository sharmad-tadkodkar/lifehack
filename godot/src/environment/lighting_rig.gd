class_name LightingRig
extends Node3D
## Applies lighting.cfg to the WorldEnvironment, named lights/probe, light strips, the hex
## canopy and the floor shader. Re-applies on F5 so the look can be tuned live.

@export var world_environment: WorldEnvironment
@export var hex_grid: HexGrid
@export var floor_mesh: MeshInstance3D
## Lights and probes named in [node.<Name>] sections are searched for under this node.
@export var search_root: Node

const FILE := "lighting"


func _ready() -> void:
	apply()
	Config.reloaded.connect(apply)


func apply() -> void:
	_apply_environment()
	for sect in Config.sections(FILE):
		if sect.begins_with("node."):
			_apply_node(sect.trim_prefix("node."), Config.section(FILE, sect))
	_apply_strips()
	if hex_grid:
		hex_grid.build(Config.section(FILE, "hex_grid"))
	_apply_floor()


func _apply_environment() -> void:
	var env := world_environment.environment
	_set_properties(env, Config.section(FILE, "environment"), "[environment]")
	env.sdfgi_enabled = Config.v(FILE, "gi", "mode") == "sdfgi"


func _apply_node(node_name: String, props: Dictionary) -> void:
	var root := search_root if search_root else get_parent()
	var node := root.find_child(node_name, true, false)
	if node == null:
		push_error("[lighting] no node named %s for [node.%s]" % [node_name, node_name])
		return
	_set_properties(node, props, "[node.%s]" % node_name)


func _apply_strips() -> void:
	for strip: LightStrip in get_tree().get_nodes_in_group(&"light_strip"):
		var sect := "strip." + strip.group
		if not Config.sections(FILE).has(sect):
			push_error("[lighting] strip group '%s' has no [%s]" % [strip.group, sect])
			continue
		strip.apply(Config.section(FILE, sect))


func _apply_floor() -> void:
	if floor_mesh == null:
		return
	var material := floor_mesh.get_active_material(0) as ShaderMaterial
	for key: String in Config.section(FILE, "floor"):
		material.set_shader_parameter(key, Config.v(FILE, "floor", key))

	var textures := Config.section("assets", "floor_textures")
	var use_textures: bool = str(textures.get("albedo", "")) != ""
	material.set_shader_parameter("use_textures", use_textures)
	if use_textures:
		material.set_shader_parameter("tiling", textures.get("tiling", 0.25))
		for key in ["albedo", "normal", "roughness"]:
			var path := str(textures.get(key, ""))
			if path != "":
				material.set_shader_parameter(key + "_texture", load(path))


func _set_properties(target: Object, props: Dictionary, where: String) -> void:
	var known := {}
	for p in target.get_property_list():
		known[p.name] = true
	for key: String in props:
		if not known.has(key):
			push_error("[lighting] %s: %s has no property '%s'" % [where, target.get_class(), key])
			continue
		target.set(key, props[key])
