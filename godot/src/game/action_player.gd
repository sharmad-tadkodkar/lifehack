class_name ActionPlayer
extends Node
## Plays a StepResult out in the world: the character clips named in the procedure JSON (logical
## names, played through CharacterRig's AnimationPlayer) and tweens for the mechanical motion:
## the wrench turning each nut, nuts spinning off into a pile, the jack rolling under and
## pumping the car up, the wheel sliding off the hub.
##
## Each `mechanics` id in the JSON has a sequence below that uses the step's `animations` in
## order (unknown ids just play the clips one after another). Every sequence ends with
## WorkBayVisuals.apply(), so the props always land exactly where the model says they are.

@export var visuals: WorkBayVisuals
@export var player: PlayerController

var kneeling := false

var _m := {}
var _anims: Array = []


func play(result: StepResult) -> void:
	_m = Config.section("animation", "mechanics")
	_anims = result.animations
	player.rig.locomotion_enabled = false
	match result.kind:
		StepResult.Kind.STEP:
			if result.ok:
				await _run(result.mechanics)
			else:
				await _mistake()
		StepResult.Kind.PATTERN_START:
			await _kneel(_clip(0))
			player.rig.play("kneel_idle")
		StepResult.Kind.NUT:
			await _pattern_nut(result)
		StepResult.Kind.TAKE, StepResult.Kind.PUT:
			if result.ok:
				await _take_or_put(result)
			else:
				await _mistake()
	visuals.apply()
	if not kneeling:
		player.rig.locomotion_enabled = true


## Gets back up if the player walks away mid-pattern.
func stand_if_kneeling() -> void:
	if kneeling:
		await _stand("stand_up")
		player.rig.locomotion_enabled = true


func _run(mechanics: String) -> void:
	match mechanics:
		"loosen_nuts":
			await _loosen_nuts()
		"raise_car":
			await _raise_car()
		"remove_wheel":
			await _remove_wheel()
		"fit_spare":
			await _fit_spare()
		"hand_tighten":
			await _hand_tighten()
		"lower_car":
			await _lower_car()
		_:
			for clip in _anims:
				await player.rig.play_and_wait(clip)


# --- sequences ---------------------------------------------------------------------

func _loosen_nuts() -> void:
	await _kneel(_clip(0))
	await _glide_wrench_to(0)
	player.rig.play(_clip(1))
	var backout := float(_m.nut_backout)
	for i in car().nuts.size():
		await _turn_nut(i, -deg_to_rad(_m.nut_turn_deg), backout, _m.nut_turn_time)
	await _stand(_clip(2))


func _raise_car() -> void:
	var jack := visuals.jack
	await _kneel(_clip(0))
	player.rig.play(_clip(1))
	var under := car().jack_ground_transform()
	var start := jack.global_transform
	await _tween_method(func(t: float) -> void:
		visuals.attach_global(jack, start.interpolate_with(under, t)), 0.0, 1.0, _m.jack_roll_time)
	await _stand(_clip(2))
	player.rig.play(_clip(3))
	var strokes := int(_m.jack_pump_strokes)
	var stroke := float(_m.jack_stroke_time)
	for k in strokes:
		await _tween_method(jack.set_pump, 0.0, 1.0, stroke * 0.5)
		var from := float(k) / strokes
		var to := float(k + 1) / strokes
		await _tween_method(func(t: float) -> void:
			jack.set_pump(1.0 - t)
			car().set_raise(lerpf(from, to, t))
			jack.set_lift(lerpf(from, to, t)), 0.0, 1.0, stroke * 0.5)
	player.rig.play("idle")


func _remove_wheel() -> void:
	await _kneel(_clip(0))
	await _glide_wrench_to(0)
	player.rig.play(_clip(1))
	var spin := TAU * float(_m.unscrew_turns)
	var off := float(_m.nut_backout) + float(_m.thread_length)
	for i in car().nuts.size():
		await _turn_nut(i, -spin, off, _m.unscrew_time)
		_drop_nut_to_pile(i)
	visuals.place_item("lug_wrench", Inventory.HANDS)
	player.rig.play(_clip(2))
	var wheel := car().flat_wheel
	var slid := car().flat_wheel_rest.translated(Vector3(_m.wheel_slide_distance, 0.0, 0.0))
	await _tween_method(func(t: float) -> void:
		wheel.transform = car().flat_wheel_rest.interpolate_with(slid, t), 0.0, 1.0, _m.wheel_slide_time)
	var lifted := wheel.global_transform
	var rest := visuals.rest_transform("flat", "wheel")
	await _tween_method(func(t: float) -> void:
		visuals.attach_global(wheel, lifted.interpolate_with(rest, t)), 0.0, 1.0, _m.wheel_lay_time)
	await _stand(_clip(3))


func _fit_spare() -> void:
	var spare := visuals.spare
	await _kneel(_clip(0))
	player.rig.play(_clip(1))
	var hub := car().hub.global_transform
	var lined_up := hub.translated_local(Vector3(_m.wheel_slide_distance, 0.0, 0.0))
	var start := spare.global_transform
	await _tween_method(func(t: float) -> void:
		visuals.attach_global(spare, start.interpolate_with(lined_up, t)), 0.0, 1.0, _m.fit_time * 0.5)
	await _tween_method(func(t: float) -> void:
		visuals.attach_global(spare, lined_up.interpolate_with(hub, t)), 0.0, 1.0, _m.fit_time)
	await _stand(_clip(2))


func _hand_tighten() -> void:
	await _kneel(_clip(0))
	player.rig.play(_clip(1))
	var out := float(_m.thread_length)
	for i in car().nuts.size():
		var nut := car().nuts[i]
		var from := nut.global_transform
		var start_local := Transform3D(Basis.IDENTITY, car().nut_seat(i, out))
		var start := car().hub.global_transform * start_local
		await _tween_method(func(t: float) -> void:
			visuals.attach_global(nut, from.interpolate_with(start, t)), 0.0, 1.0, _m.thread_time * 0.5)
		visuals.attach(nut, car().hub, start_local)
		var spin := TAU * float(_m.unscrew_turns)
		await _tween_method(func(t: float) -> void:
			nut.position = car().nut_seat(i, out * (1.0 - t))
			nut.rotation.x = -spin * t, 0.0, 1.0, _m.thread_time)
	await _stand(_clip(2))


func _lower_car() -> void:
	var jack := visuals.jack
	player.rig.play(_clip(0))
	await get_tree().create_timer(0.4, false).timeout
	await _tween_method(func(t: float) -> void:
		car().set_raise(1.0 - t)
		jack.set_lift(1.0 - t), 0.0, 1.0, _m.lower_time)
	var under := jack.global_transform
	var rest := visuals.rest_transform("jack", "jack_point")
	await _tween_method(func(t: float) -> void:
		visuals.attach_global(jack, under.interpolate_with(rest, t)), 0.0, 1.0, _m.jack_roll_time)
	player.rig.play("idle")


## Final tightening: one wrench pull on the chosen nut; stands up after the last one.
func _pattern_nut(result: StepResult) -> void:
	if not result.ok:
		await get_tree().create_timer(0.35, false).timeout
		return
	await _glide_wrench_to(result.nut)
	player.rig.play(_clip(1))
	await _turn_nut(result.nut, deg_to_rad(_m.nut_turn_deg), 0.0, _m.nut_turn_time)
	if result.completes_step:
		visuals.place_item("lug_wrench", Inventory.HANDS)
		await _stand(_clip(2))
	else:
		player.rig.play("kneel_idle")


## Picking something up or setting it down (animation.cfg [pickup]). Uses whichever pick-up clip
## brings the hand closest to the item (or the place it goes). The player walks up if it is out
## of reach, then turns and steps so the hand meets it; at that moment of the clip the item glides
## into the hand (or out of it onto its rest) and the clip plays back to standing.
## Rigs without a skeleton use the simple timed _pickup().
func _take_or_put(result: StepResult) -> void:
	var cfg := Config.section("animation", "pickup")
	var target := visuals.reach_point(result.action_id)
	var plan := _plan_reach(cfg, target)
	if plan.is_empty():
		await _pickup()
		return
	var rig := player.rig
	if (plan.to as Vector3).distance_to(plan.from) > float(cfg.max_step):
		rig.locomotion_enabled = true
		await player.approach(plan.to, float(cfg.approach_timeout))
		rig.locomotion_enabled = false
		plan = _plan_reach(cfg, target)
		if plan.is_empty():
			await _pickup()
			return
	var speed := float(cfg.reach_speed)
	rig.play(plan.clip, -1.0, speed)
	var to: Vector3 = (plan.from as Vector3).move_toward(plan.to, float(cfg.max_step))
	var setup := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	setup.tween_method(func(t: float) -> void:
		player.global_position = (plan.from as Vector3).lerp(to, t)
		rig.rotation.y = lerp_angle(plan.yaw_from, plan.yaw, t), 0.0, 1.0, maxf(cfg.setup_time, 0.01)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await get_tree().create_timer(maxf(plan.time / speed, float(cfg.setup_time)), false).timeout
	visuals.apply_gliding(cfg.glide_time)
	rig.reverse(cfg.return_speed)
	await get_tree().create_timer(maxf(plan.time / float(cfg.return_speed), float(cfg.glide_time)), false).timeout
	rig.play("idle")


## Which pick-up clip and moment of it to use, and where to stand and face so the hand meets
## `target`. Scores every sampled hand position of every [pickup] clips entry by its height
## mismatch plus step_cost per metre the player would have to move. The spot to stand on stops
## short of anything solid (the car, the cart) on the way.
func _plan_reach(cfg: Dictionary, target: Vector3) -> Dictionary:
	var rig := player.rig
	var body := player.global_position
	var to_target := Vector3(target.x - body.x, 0.0, target.z - body.z)
	if to_target.length() < 0.001:
		return {}
	var height := target.y - body.y - rig.position.y
	var best := {}
	var best_cost := INF
	for logical: String in cfg.clips:
		for sample: Array in rig.hand_path(logical, int(cfg.path_samples)):
			var hand: Vector3 = sample[1]
			var step := to_target.length() - Vector2(hand.x, hand.z).length()
			var cost := absf(hand.y - height) + absf(step) * float(cfg.step_cost)
			if cost < best_cost - 0.001:
				best_cost = cost
				best = {"clip": logical, "time": float(sample[0]), "hand": hand, "step": step}
	if best.is_empty():
		return {}
	var hand: Vector3 = best.hand
	var direction := to_target.normalized()
	var motion := direction * float(best.step)
	var hit := player.move_and_collide(motion, true)
	if hit:
		motion = hit.get_travel()
	best.from = body
	best.to = body + motion
	best.yaw_from = rig.rotation.y
	best.yaw = atan2(-direction.x, -direction.z) - atan2(-hand.x, -hand.z)
	return best


## Fallback for rigs without a skeleton: the item jumps to the hand on the pick-up beat.
func _pickup() -> void:
	var clip := "pick_up"
	player.rig.play(clip)
	await get_tree().create_timer(_m.pickup_time, false).timeout
	visuals.apply()
	var length := player.rig.clip_length(clip)
	await get_tree().create_timer(maxf(length - float(_m.pickup_time), 0.0), false).timeout
	player.rig.play("idle")


func _mistake() -> void:
	if kneeling:
		await get_tree().create_timer(0.4, false).timeout
		return
	await player.rig.play_and_wait("shrug")
	player.rig.play("idle")


# --- helpers -----------------------------------------------------------------------

func car() -> CarRig:
	return visuals.car


func _clip(i: int) -> String:
	return str(_anims[i]) if i < _anims.size() else "idle"


func _kneel(clip: String) -> void:
	if kneeling:
		return
	await player.rig.play_and_wait(clip)
	kneeling = true


func _stand(clip: String) -> void:
	if not kneeling:
		return
	await player.rig.play_and_wait(clip)
	kneeling = false
	player.rig.play("idle")


## Wrench socket on nut `i`, its cross arm at `angle` (radians, clockwise from the top as
## seen from outside). The wrench's -Z goes into the nut, its arms stick out toward the player.
func _wrench_on_nut(i: int, angle: float) -> Transform3D:
	var x := Vector3(0.0, cos(angle), -sin(angle))
	var z := Vector3.RIGHT
	var basis := Basis(x, z.cross(x), z)
	var nut := car().nuts[i]
	return Transform3D(basis, Vector3(nut.position.x + 0.03, nut.position.y, nut.position.z))


func _nut_angle(i: int) -> float:
	return TAU * i / float(car().nuts.size())


func _glide_wrench_to(i: int) -> void:
	var wrench := visuals.lug_wrench
	var from := wrench.global_transform
	var to := car().hub.global_transform * _wrench_on_nut(i, _nut_angle(i))
	await _tween_method(func(t: float) -> void:
		visuals.attach_global(wrench, from.interpolate_with(to, t)), 0.0, 1.0, 0.25)
	visuals.attach(wrench, car().hub, _wrench_on_nut(i, _nut_angle(i)))


## Turns nut `i` (and the wrench on it) by `turn` radians while it travels to `backed_out`.
## Negative turns loosen (anticlockwise from outside).
func _turn_nut(i: int, turn: float, backed_out: float, seconds: float) -> void:
	var nut := car().nuts[i]
	var wrench := visuals.lug_wrench
	var start_angle := _nut_angle(i)
	var spin_start := nut.rotation.x
	var from := nut.position
	var to := car().nut_seat(i, backed_out)
	visuals.attach(wrench, car().hub, _wrench_on_nut(i, start_angle))
	await _tween_method(func(t: float) -> void:
		nut.position = from.lerp(to, t)
		nut.rotation.x = spin_start - turn * t
		wrench.transform = _wrench_on_nut(i, start_angle + turn * t), 0.0, 1.0, seconds)


func _drop_nut_to_pile(i: int) -> void:
	var nut := car().nuts[i]
	var from := nut.global_transform
	var to := visuals.nut_pile_transform(i)
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_method(func(t: float) -> void:
		var xform := from.interpolate_with(to, t)
		xform.origin.y += sin(t * PI) * 0.08
		visuals.attach_global(nut, xform), 0.0, 1.0, 0.3)


## Mechanical motion runs on the physics tick so physics interpolation smooths it like the body.
func _tween_method(method: Callable, from: float, to: float, seconds: float) -> void:
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_method(method, from, to, maxf(seconds, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
