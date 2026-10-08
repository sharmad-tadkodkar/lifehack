extends PlaceholderMarker
## Placeholder mannequin. CharacterRig calls set_outfit() so the player and NPCs differ.


func set_outfit(color: Color) -> void:
	var suit := ($Hips/Pelvis as MeshInstance3D).mesh.surface_get_material(0)
	var outfit := suit.duplicate() as StandardMaterial3D
	outfit.albedo_color = color
	for mesh_instance: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		if mesh_instance.mesh.surface_get_material(0) == suit:
			mesh_instance.material_override = outfit
