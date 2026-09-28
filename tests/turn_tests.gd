class_name TurnTests
extends ScooterTests
## Hard turns: full stick never tips you over on its own, and the left
## trigger's foot plant turns tighter than the scooter can carve.


func run() -> void:
	await _test_full_stick_holds()
	await _test_foot_plant_turn()
	await _test_foot_scuff()


## Full stick at every speed, for 4 s on flat concrete: leans as far as the
## turn holds and stays up.
func _test_full_stick_holds() -> void:
	var falls: Array[String] = []
	var rows: Array[String] = []
	var x := -170.0
	for v in [0.5, 1.0, 1.5, 2.0, 3.0, 4.0, 5.0, 6.0, 8.0]:
		for side in [1.0, -1.0]:
			x += 18.0 # the test ground spans ±200 m
			var s := _spawn(Vector3(x, 0, 100), 0.0, Vector3(0, 0, -v))
			await _ticks(24)
			s.manual_intent.lean = Vector2(side, 0)
			var slid := 0
			var max_lean := 0.0
			var fell := false
			for i in tps * 4:
				await _ticks(1)
				if s.front_wheel.sliding or s.rear_wheel.sliding:
					slid += 1
				max_lean = maxf(max_lean, absf(s.lean_angle))
				if s.is_fallen() or s.rider.bailed:
					fell = true
					break
			if side > 0.0:
				rows.append("%.1f m/s: lean %.0f° (cap %.0f°), %d ticks sliding" % [v, rad_to_deg(max_lean),
						rad_to_deg(s.holdable_lean(v)), slid])
			if fell:
				falls.append("%.1f m/s %s" % [v, "right" if side > 0.0 else "left"])
			s.queue_free()
	runner.note("full stick: " + ", ".join(rows))
	_check(falls.is_empty(), "full stick: never falls over on flat concrete (fell: %s)" % ", ".join(falls))


## At walking-to-jogging pace, full stick with the foot down turns in a
## much smaller circle than carving, and stays up.
func _test_foot_plant_turn() -> void:
	var rows: Array[String] = []
	var ok := true
	var x := -170.0
	for v in [1.5, 2.5, 4.0]:
		var carve := await _turn_circle(Vector3(x, 0, 60), v, false)
		var planted := await _turn_circle(Vector3(x + 20.0, 0, 60), v, true)
		x += 40.0
		rows.append("%.1f m/s: carve r %.2f m, foot r %.2f m (%.0f° in %.1f s, %.1f m/s left%s)" % [
				v, carve[0], planted[0], planted[1], planted[2], planted[3], ", FELL" if planted[4] else ""])
		ok = ok and not planted[4] and not carve[4]
		if v < 3.0:
			ok = ok and planted[0] < carve[0] * 0.6
	runner.note("foot plant turns: " + "; ".join(rows))
	_check(ok, "foot plant: turns much tighter than carving at walking pace, and nobody falls")


## Full right stick for up to 3 s, stopping once turned 180° (or stopped).
## Returns [turn radius (path length / heading change), degrees turned,
## seconds, final speed, fell].
func _turn_circle(at: Vector3, v: float, planted: bool) -> Array:
	var s := _spawn(at, 0.0, Vector3(0, 0, -v))
	await _ticks(24)
	s.manual_intent.lean = Vector2(1, 0)
	s.manual_intent.foot = planted
	var turned := 0.0
	var path := 0.0
	var heading := s.global_basis.get_euler().y
	var last := s.global_position
	var fell := false
	var ticks := 0
	while ticks < tps * 3 and turned < PI and s.linear_velocity.length() > 0.1:
		await _ticks(1)
		ticks += 1
		var now := s.global_basis.get_euler().y
		turned += absf(wrapf(now - heading, -PI, PI))
		heading = now
		path += Vector2(s.global_position.x - last.x, s.global_position.z - last.z).length()
		last = s.global_position
		if s.is_fallen() or s.rider.bailed:
			fell = true
			break
	var result := [path / maxf(turned, 1e-3), rad_to_deg(turned), ticks / float(tps),
			s.linear_velocity.length(), fell]
	s.queue_free()
	return result


## Rolling straight with the foot down slows you at the scuff's rate, and
## you can't kick with that foot.
func _test_foot_scuff() -> void:
	var s := _spawn(Vector3(-170, 0, 20), 0.0, Vector3(0, 0, -3.0))
	await _ticks(24)
	s.manual_intent.foot = true
	var v0 := s.linear_velocity.length()
	await _ticks(tps)
	var decel := v0 - s.linear_velocity.length()
	# Rolling resistance and drag add a little to the scuff.
	var expected := tuning.foot_scuff_force / tuning.total_mass()
	_check(decel > expected * 0.9 and decel < expected * 1.6,
			"foot scuff: slows %.2f m/s in 1 s (scuff alone %.2f)" % [decel, expected])
	for i in tps * 3:
		await _ticks(1)
	_check(s.linear_velocity.length() < 0.05 and not s.is_fallen(), "foot scuff: stops and stays up")
	s.manual_intent.kick = true
	await _ticks(tps / 2)
	s.manual_intent.kick = false
	await _ticks(tps / 2)
	_check(s.linear_velocity.length() < 0.05, "foot plant: can't kick off the planted foot (%.2f m/s)" % s.linear_velocity.length())
	s.manual_intent.foot = false
	s.manual_intent.kick = true
	await _ticks(tps / 2)
	_check(s.linear_velocity.length() > 0.5, "foot plant: foot back on the deck, kick works (%.2f m/s)" % s.linear_velocity.length())
	s.queue_free()
