class_name HexGrid
extends Node3D
## Hexagon LED canopy (the detailing-garage look), built from lighting.cfg [hex_grid].
## Lies in this node's XZ plane, centred on its origin, bars facing down.

var _instance: MultiMeshInstance3D
var _material := StandardMaterial3D.new()


func build(settings: Dictionary) -> void:
	if _instance:
		_instance.queue_free()
		_instance = null
	if not settings.get("enabled", true):
		return

	var radius: float = settings.get("cell_radius", 0.6)
	var columns: int = settings.get("columns", 8)
	var rows: int = settings.get("rows", 5)
	var edges := _unique_edges(radius, columns, rows)

	var bar := BoxMesh.new()
	bar.size = Vector3(radius, settings.get("bar_depth", 0.04), settings.get("bar_width", 0.05))
	_material.albedo_color = Color.BLACK
	_material.emission_enabled = true
	_material.emission = settings.get("color", Color.WHITE)
	_material.emission_energy_multiplier = settings.get("emission_energy", 8.0)
	bar.material = _material

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = bar
	multimesh.instance_count = edges.size()
	for i in edges.size():
		multimesh.set_instance_transform(i, edges[i])

	_instance = MultiMeshInstance3D.new()
	_instance.multimesh = multimesh
	_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_instance)


## Pointy-top hex tiling; shared edges are emitted once. Returns one transform per bar.
func _unique_edges(radius: float, columns: int, rows: int) -> Array[Transform3D]:
	var dx := sqrt(3.0) * radius
	var dz := 1.5 * radius
	var width := dx * (columns - 0.5)
	var depth := dz * (rows - 1)
	var seen := {}
	var out: Array[Transform3D] = []
	for row in rows:
		for col in columns:
			var center := Vector2(col * dx + (dx * 0.5 if row % 2 else 0.0) - width * 0.5, row * dz - depth * 0.5)
			for k in 6:
				var a := center + Vector2.from_angle(deg_to_rad(60.0 * k + 30.0)) * radius
				var b := center + Vector2.from_angle(deg_to_rad(60.0 * k + 90.0)) * radius
				var mid := (a + b) * 0.5
				var key := Vector2i(roundi(mid.x * 1000.0), roundi(mid.y * 1000.0))
				if seen.has(key):
					continue
				seen[key] = true
				var dir := (b - a).normalized()
				var basis := Basis(Vector3.UP, -atan2(dir.y, dir.x))
				out.append(Transform3D(basis, Vector3(mid.x, 0.0, mid.y)))
	return out
