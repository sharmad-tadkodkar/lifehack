extends PlaceholderMarker
## Placeholder car. CarRig calls set_paint() so the hero car and the lift car differ.


func set_paint(color: Color) -> void:
	var shell := $Body/Shell as CSGPolygon3D
	var material := shell.material.duplicate() as StandardMaterial3D
	material.albedo_color = color
	shell.material = material
	($Body/Roof as CSGPolygon3D).material = material
