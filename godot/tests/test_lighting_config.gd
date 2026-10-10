extends GutTest
## lighting.cfg must map onto real Environment/node properties. LightingRig reports every
## unknown key or missing node with push_error, which GUT counts as a failure.


func test_garage_applies_lighting_config_cleanly() -> void:
	var garage: Node3D = load("res://scenes/environment/garage.tscn").instantiate()
	add_child_autofree(garage)
	var env: Environment = garage.get_node("WorldEnvironment").environment
	assert_eq(env.glow_enabled, Config.v("lighting", "environment", "glow_enabled"))
	assert_almost_eq(env.volumetric_fog_density, float(Config.v("lighting", "environment", "volumetric_fog_density")), 0.0001)
	assert_eq(env.sdfgi_enabled, Config.v("lighting", "gi", "mode") == "sdfgi")


func test_every_strip_group_is_configured() -> void:
	var garage: Node3D = load("res://scenes/environment/garage.tscn").instantiate()
	add_child_autofree(garage)
	var strips := get_tree().get_nodes_in_group(&"light_strip")
	assert_gt(strips.size(), 0)
	for strip: LightStrip in strips:
		assert_true(Config.sections("lighting").has("strip." + strip.group), strip.name)
