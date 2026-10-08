extends GutTest
## Every animation the procedure JSON names (and the ones ActionPlayer uses itself) must exist
## on the player's character, and every mechanics id must have a sequence.

const CODE_CLIPS := ["idle", "walk", "jog", "kneel_idle", "pick_up", "shrug"]
const MECHANICS := ["loosen_nuts", "raise_car", "remove_wheel", "fit_spare", "hand_tighten", "lower_car", "torque_nuts"]

var rig: CharacterRig
var data: ProcedureData


func before_all() -> void:
	data = ProcedureData.load_file("res://config/procedure/flat_tire.json")


func before_each() -> void:
	var player: Node = load("res://scenes/characters/player.tscn").instantiate()
	add_child_autofree(player)
	rig = player.get_node("CharacterRig")


func test_every_step_animation_exists() -> void:
	for s: Dictionary in data.steps:
		for clip: String in s.animations:
			assert_true(rig.has_clip(clip), "%s needs clip '%s'" % [s.id, clip])


func test_clips_used_by_code_exist() -> void:
	for clip: String in CODE_CLIPS:
		assert_true(rig.has_clip(clip), clip)


func test_every_mechanics_id_is_known() -> void:
	for s: Dictionary in data.steps:
		assert_has(MECHANICS, s.mechanics, "%s mechanics '%s' has a sequence in ActionPlayer" % [s.id, s.mechanics])


func test_one_shot_clips_have_length() -> void:
	for clip in ["kneel_down", "stand_up", "place_jack", "pull_wheel", "fit_wheel", "release_jack", "pick_up", "shrug"]:
		assert_gt(rig.clip_length(clip), 0.0, clip)
