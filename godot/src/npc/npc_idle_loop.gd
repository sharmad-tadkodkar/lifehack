class_name NpcIdleLoop
extends Node3D
## An NPC that stays put: loops `base_clip` and every so often plays one of `fidget_clips`
## (timings in npc.cfg [<config_section>]). Optionally holds a prop in its hand socket.

@export var base_clip := "lean_phone"
@export var fidget_clips: PackedStringArray = ["lean_glance", "shift_weight"]
@export var config_section := "phone"
## Prop moved into the character's hand socket at start (e.g. the phone).
@export var held_prop: Node3D

@onready var rig: CharacterRig = $CharacterRig


func _ready() -> void:
	rig.locomotion_enabled = false
	if held_prop:
		var hold := (held_prop as ItemRig).hold_transform() if held_prop is ItemRig else Transform3D.IDENTITY
		held_prop.reparent(rig.hand_socket, false)
		held_prop.transform = hold
	rig.play(base_clip)
	_fidget_loop()


func _fidget_loop() -> void:
	while is_inside_tree():
		var cfg := Config.section("npc", config_section)
		await _wait(randf_range(cfg.fidget_min, cfg.fidget_max))
		if not is_inside_tree() or fidget_clips.is_empty():
			return
		var fidget := fidget_clips[randi() % fidget_clips.size()]
		# a model without that fidget clip may map it to the base loop; don't restart it
		if rig.clip_for(fidget) != rig.clip_for(base_clip):
			rig.play(fidget)
			await _wait(rig.clip_length(fidget))
			rig.play(base_clip)


## Sleeps on a Timer this NPC owns, so freeing the NPC drops the loop instead of resuming it.
func _wait(seconds: float) -> void:
	var timer := Timer.new()
	timer.one_shot = true
	add_child(timer)
	timer.start(maxf(seconds, 0.01))
	await timer.timeout
	timer.queue_free()
