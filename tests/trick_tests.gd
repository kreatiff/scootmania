class_name TrickTests
extends ScooterTests
## Phase 7: flicks, barspins and tailwhips.


func run() -> void:
	_test_flick_recognition()
	await _test_tricks_off_kicker()


## A quick flick counts; a slow push, a held stick or a flick from off
## centre doesn't.
func _test_flick_recognition() -> void:
	var dt := 1.0 / tps
	var d := Tricks.FlickDetector.new()
	var seen := _feed(d, [Vector2.ZERO, Vector2(0.5, 0), Vector2(1, 0), Vector2(1, 0), Vector2(1, 0)], dt)
	_check(seen.size() == 1 and seen[0].x > 0.99, "flick: a quick flick right counts once (%s)" % [seen])
	var slow: Array[Vector2] = [Vector2.ZERO]
	for i in int(0.4 * tps):
		slow.append(Vector2(0, clampf(i / (0.4 * tps), 0.0, 1.0)))
	seen = _feed(Tricks.FlickDetector.new(), slow, dt)
	_check(seen.is_empty(), "flick: pushing the stick slowly isn't a flick")
	var again: Array[Vector2] = [Vector2.ZERO, Vector2(0, 1), Vector2(0, 1), Vector2(0.5, 0.8), Vector2(0, 1)]
	seen = _feed(Tricks.FlickDetector.new(), again, dt)
	_check(seen.size() == 1, "flick: moving a held stick around doesn't flick again")
	var twice: Array[Vector2] = [Vector2.ZERO, Vector2(-1, 0), Vector2.ZERO, Vector2(0, -1)]
	seen = _feed(Tricks.FlickDetector.new(), twice, dt)
	_check(seen.size() == 2 and seen[1].y < -0.99, "flick: back through the centre re-arms it")


func _feed(d: Tricks.FlickDetector, samples: Array, dt: float) -> Array[Vector2]:
	var seen: Array[Vector2] = []
	for sample in samples:
		var flick := d.update(sample, tuning, dt)
		if flick != Vector2.ZERO:
			seen.append(flick)
	return seen


## Popped off the kicker, a tailwhip or barspin flicked right after takeoff
## lands; the same flick just before touchdown is "too early" and bails.
## Flicks on the ground do nothing.
func _test_tricks_off_kicker() -> void:
	var kicker := Kicker.new()
	kicker.position = Vector3(-60, 0, -170)
	runner.add_child(kicker)
	await _ticks(2)
	var whip := await _trick_run(kicker, Vector2(1, 0), 0.05)
	var bar := await _trick_run(kicker, Vector2(0, 1), 0.05)
	var late := await _trick_run(kicker, Vector2(-1, 0), -0.2)
	var ground := await _trick_run(kicker, Vector2(1, 0), -1.0)
	runner.note("tricks off the kicker: tailwhip \"%s\" (%s), barspin \"%s\" (%s), late \"%s\" (%s), mid-trick deck at %.0f°" % [
			whip[0], AirControl.landing_name(whip[2]), bar[0], AirControl.landing_name(bar[2]),
			late[0], AirControl.landing_name(late[2]), whip[3]])
	_check(whip[0] == "TAILWHIP" and whip[1] and whip[2] != AirControl.Landing.BAIL,
			"tricks: tailwhip flicked after the pop lands")
	_check(bar[0] == "BARSPIN" and bar[1] and bar[2] != AirControl.Landing.BAIL,
			"tricks: barspin flicked after the pop lands")
	_check(late[0] == "TAILWHIP — too early" and not late[1] and late[2] == AirControl.Landing.BAIL,
			"tricks: flicked just before landing is too early, and bails (\"%s\")" % late[0])
	_check(ground[0] == "" and ground[2] != AirControl.Landing.BAIL, "tricks: a flick on the ground does nothing")
	_check(absf(whip[3]) > 30.0 and whip[4], "tricks: the deck turns mid-tailwhip and ends square")
	kicker.queue_free()


## Pops off the kicker and flicks `stick` at `when` seconds after both
## wheels leave (negative: that long before the predicted touchdown; -1:
## on the ground, before the lip). Returns [trick result, landed, landing
## grade, deck angle mid-trick (deg), deck visual back to square after].
func _trick_run(kicker: Kicker, stick: Vector2, when: float) -> Array:
	var lip_z := kicker.position.z - kicker.radius() * sin(deg_to_rad(kicker.lip_angle_deg))
	var s := _spawn(kicker.position + Vector3(0, 0, 4), 0.0, Vector3(0, 0, -6.0))
	s.manual_intent.pose = Vector2(0, -1)
	var results := []
	s.trick_finished.connect(func(result: String, landed: bool) -> void: results.append([result, landed]))
	var grade := AirControl.Landing.NONE
	var flick_tick := -1
	var mid_deck := 0.0
	var ticks := 0
	var popped := false
	for i in tps * 4:
		await _ticks(1)
		ticks += 1
		if not popped and s.global_position.z < lip_z + 0.9:
			s.manual_intent.pose = Vector2.ZERO # pop: extend, then centre the stick
			popped = true
			s.manual_intent.pose = Vector2(0, 1)
		elif popped and s.manual_intent.pose == Vector2(0, 1) and s.air.air_time > 0.0:
			s.manual_intent.pose = Vector2.ZERO
		var flick_now := false
		if flick_tick < 0:
			if when == -1.0:
				flick_now = s.global_position.z < kicker.position.z + 2.0
			elif when >= 0.0:
				flick_now = s.air.air_time >= when and s.global_position.z < lip_z
			else:
				flick_now = s.air.airborne and s.global_position.z < lip_z and s.air.time_to_landing <= -when
		if flick_now:
			flick_tick = ticks
			s.manual_intent.pose = stick * 0.6
		elif flick_tick > 0 and ticks == flick_tick + 1:
			s.manual_intent.pose = stick
		elif flick_tick > 0 and ticks == flick_tick + 4:
			s.manual_intent.pose = Vector2.ZERO
		if s.tricks.active == Tricks.Trick.TAILWHIP and s.tricks.progress > 0.3 and mid_deck == 0.0:
			mid_deck = rad_to_deg(s._deck_visual.transform.basis.get_euler().y)
		if s.air.last_landing != AirControl.Landing.NONE and flick_tick > 0 and s.tricks.active == Tricks.Trick.NONE:
			grade = s.air.last_landing
			if s.is_grounded():
				break
	await _ticks(2)
	var square := s._deck_visual.transform.is_equal_approx(Transform3D.IDENTITY)
	var result: Array = results[-1] if not results.is_empty() else ["", false]
	s.queue_free()
	return [result[0], result[1], grade, mid_deck, square]
