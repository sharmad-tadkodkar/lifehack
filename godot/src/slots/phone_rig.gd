class_name PhoneRig
extends ItemRig
## The workbench NPC's phone. Its `ScreenGlow` light (and the screen's emission, if the model has
## a `Screen` mesh) come from npc.cfg [phone].


func _bind() -> void:
	_apply()
	Config.reloaded.connect(_apply)


func _apply() -> void:
	var cfg := Config.section("npc", "phone")
	var glow := get_node_or_null(^"ScreenGlow") as OmniLight3D
	if glow:
		glow.light_color = cfg.screen_light_color
		glow.light_energy = cfg.screen_light_energy
		glow.omni_range = cfg.screen_light_range
	var screen := model.find_child("Screen", true, false) as MeshInstance3D if model else null
	if screen and screen.get_active_material(0) is StandardMaterial3D:
		var material := screen.get_active_material(0).duplicate() as StandardMaterial3D
		material.emission = cfg.screen_light_color
		material.emission_energy_multiplier = cfg.screen_emission_energy
		screen.material_override = material
