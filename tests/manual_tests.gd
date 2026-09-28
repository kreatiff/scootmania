class_name ManualTests
extends ScooterTests
## Manuals: weight back lifts the front wheel, and it's a balance.


func run() -> void:
	await _test_weight_moves_the_load()
	await _test_manual_band()
	await _test_nose_manual()


## Standing still, weight back loads the rear wheel and forward the front,
## by the moment of the shifted weight (statics).
func _test_weight_moves_the_load() -> void:
	var s := _spawn(Vector3(120, 0, -60), 0.0)
	s.manual_intent.lean.y = -0.3
	await _ticks(tps * 2)
	var shift := 0.3 * tuning.max_hip_fore_aft
	var rider_weight := tuning.sprung_rider_mass() * G
	var expected := rider_weight * shift / tuning.wheelbase
	var base_rear := tuning.total_mass() * G * (tuning.wheelbase * 0.5 + tuning.center_of_mass().z) / tuning.wheelbase
	var moved := s.rear_wheel.normal_force - base_rear
	_check(_near(moved, expected, 0.1),
			"manual: weight back moves %.0f N onto the rear wheel (statics %.0f N)" % [moved, expected])
	s.queue_free()


## At 3 m/s, holding the stick back: part way doesn't lift; all the way
## loops out. No fixed stick position holds a manual (at -0.7 the deck
## creeps up and would loop out): you balance it, and a player reacting
## 0.25 s late can.
func _test_manual_band() -> void:
	var results := {}
	var x := 100.0
	for mode in ["-0.5", "-0.7", "-1.0", "player"]:
		x += 15.0
		results[mode] = await _manual_run(Vector3(x, 0, -40), mode, false)
	runner.note("manual at 3 m/s: stick -0.5 %s, -0.7 %s, -1.0 %s, player (0.25 s late) %s" % [
			results["-0.5"][2], results["-0.7"][2], results["-1.0"][2], results["player"][2]])
	_check(results["-0.5"][0] < 0.2, "manual: easing back a little keeps both wheels down")
	_check(results["-1.0"][1], "manual: all the way back loops out")
	_check(results["player"][0] > 3.0 and not results["player"][1],
			"manual: a player reacting 0.25 s late can balance it (%.1f s)" % results["player"][0])


## Nose manual: weight forward lifts the rear, the mirror image, balanced
## by the same late-reacting player.
func _test_nose_manual() -> void:
	var r := await _manual_run(Vector3(160, 0, -40), "nose player", true)
	runner.note("nose manual at 3 m/s, player 0.25 s late: %s" % r[2])
	_check(r[0] > 3.0 and not r[1], "manual: a player can balance a nose manual (%.1f s)" % r[0])


## Returns [seconds on one wheel, fell, callout text].
func _manual_run(at: Vector3, mode: String, nose: bool) -> Array:
	var s := _spawn(at, 0.0, Vector3(0, 0, -3.0))
	var results: Array[String] = []
	s.trick_finished.connect(func(result: String, _landed: bool) -> void: results.append(result))
	await _ticks(24)
	var history: Array[Vector2] = []
	var one_wheel := 0.0
	var fell := false
	for i in tps * 4:
		var pitch := rad_to_deg(asin(clampf(-s.global_basis.z.y, -1.0, 1.0)))
		var rate := rad_to_deg(s.angular_velocity.dot(s.global_basis.x))
		history.append(Vector2(pitch, rate))
		if mode == "nose player":
			var seen := history[maxi(history.size() - 1 - int(0.25 * tps), 0)]
			s.manual_intent.lean.y = clampf(1.0 + 0.06 * (seen.x + 12.0) + 0.01 * seen.y, -1.0, 1.0)
		elif mode == "player":
			# Sees the deck 0.25 s late: more nose-up than ~12° eases off.
			var seen := history[maxi(history.size() - 1 - int(0.25 * tps), 0)]
			s.manual_intent.lean.y = clampf(-1.0 + 0.06 * (seen.x - 12.0) + 0.01 * seen.y, -1.0, 1.0)
		else:
			s.manual_intent.lean.y = float(mode)
		await _ticks(1)
		var lifted := s.rear_wheel.in_contact and not s.front_wheel.in_contact
		if nose:
			lifted = s.front_wheel.in_contact and not s.rear_wheel.in_contact
		if lifted:
			one_wheel += 1.0 / tps
		if s.is_fallen() or s.rider.bailed:
			fell = true
			break
	s.manual_intent.lean.y = 0.0
	await _ticks(tps / 2)
	var text := "fell after %.1f s" % one_wheel if fell else "%.1f s on one wheel" % one_wheel
	if not results.is_empty():
		text += " (\"%s\")" % results[-1]
	s.queue_free()
	return [one_wheel, fell, text]
