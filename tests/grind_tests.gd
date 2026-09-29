class_name GrindTests
extends ScooterTests
## Grinds: locking onto a steel edge, sliding along it, getting off.


func run() -> void:
	var rail := Rail.new()
	rail.length = 4.0
	rail.position = Vector3(60, 0, 190)
	runner.add_child(rail)
	await _ticks(2)
	await _test_rail_grind(rail)
	await _test_pop_off(rail)
	await _test_crossways(rail)
	await _test_pop_on(rail)
	rail.queue_free()


## Dropped onto the rail, lined up and moving along it at 4 m/s: it locks
## on, stays centred and upright, slows by steel friction (v² = v0² −
## 2·μ·g·d), balances an energy audit, runs off the end and lands.
func _test_rail_grind(rail: Rail) -> void:
	var s := _drop_on_rail(rail, 0.0, 4.0)
	var results: Array[String] = []
	s.trick_finished.connect(func(result: String, _landed: bool) -> void: results.append(result))
	await _ticks(1)
	var e0 := _energy(s)
	var w0 := _work(s)
	var g0 := s.grind.grind_work
	var c := 0.5 * Scooter.AIR_DENSITY * tuning.drag_area
	var drag := 0.0
	var caught := false
	var worst_side := 0.0
	var worst_tilt := 0.0
	var v_start := 0.0
	var x_start := 0.0
	var v_end := 0.0
	var x_end := 0.0
	var audit := ""
	for i in tps * 3:
		var v := s.rider.linear_velocity.length()
		drag -= c * v * v * v / tps
		await _ticks(1)
		if s.grind.active:
			if not caught:
				caught = true
				v_start = s.linear_velocity.x
				x_start = s.global_position.x
			worst_side = maxf(worst_side, absf(s.global_position.z - rail.position.z))
			worst_tilt = maxf(worst_tilt, rad_to_deg(s.global_basis.y.angle_to(Vector3.UP)))
			v_end = s.linear_velocity.x
			x_end = s.global_position.x
			var w := _work(s) - w0
			var dg := s.grind.grind_work - g0
			var residual := (_energy(s) - e0) - (w.x + w.y + dg + drag)
			audit = "%+.1f J unexplained of %.0f J" % [residual, e0]
			if absf(residual) > 0.03 * e0:
				audit += " (FAILED at %.2f s)" % (i / float(tps))
	for i in tps:
		await _ticks(1)
	var expected := sqrt(maxf(v_start * v_start - 2.0 * tuning.grind_friction * G * (x_end - x_start), 0.0))
	runner.note("rail grind: %.2f m at %.2f → %.2f m/s (friction predicts %.2f), side %.1f cm, tilt %.1f°, callouts %s, audit %s" % [
			x_end - x_start, v_start, v_end, expected, worst_side * 100.0, worst_tilt, results, audit])
	_check(caught, "grind: locks onto the rail")
	_check(worst_side < 0.03 and worst_tilt < 8.0, "grind: stays centred and upright on the rail")
	_check(x_end - x_start > 2.5 and _near(v_end, expected, 0.1), "grind: slides the rail, slowed by steel friction")
	_check(not audit.contains("FAILED"), "grind: energy audit balances (%s)" % audit)
	_check(not s.grind.active and s.is_grounded() and not s.rider.bailed, "grind: runs off the end and lands")
	_check(not results.is_empty() and results[-1].begins_with("50-50"), "grind: called out (%s)" % [results])
	s.queue_free()


## Crouch and extend on the rail: the legs push against it like the
## ground, and you hop off before the end.
func _test_pop_off(rail: Rail) -> void:
	var s := _drop_on_rail(rail, 0.0, 4.0)
	s.manual_intent.pose = Vector2(0, -1)
	var popped_at := INF
	var left_at := INF
	for i in tps * 2:
		await _ticks(1)
		if s.grind.active and s.grind.time > 0.15 and popped_at == INF:
			s.manual_intent.pose = Vector2(0, 1)
			popped_at = s.global_position.x
		if popped_at != INF and not s.grind.active and left_at == INF:
			left_at = s.global_position.x
	var rail_end := rail.position.x + rail.length * 0.5
	runner.note("pop off the rail: popped at x %.2f, left it at %.2f (rail ends at %.2f)" % [popped_at, left_at, rail_end])
	_check(left_at < rail_end - 0.3, "grind: popping hops off the rail before its end")
	s.queue_free()


## Coming down on the rail crossways (60° off): no lock until the rail has
## twisted the deck within grind_max_angle_deg of it, if at all.
func _test_crossways(rail: Rail) -> void:
	var s := _drop_on_rail(rail, 60.0, 4.0)
	var caught_off := -1.0
	for i in tps:
		await _ticks(1)
		if s.grind.active and caught_off < 0.0:
			var heading := -s.global_basis.z
			caught_off = rad_to_deg(Vector3(heading.x, 0, heading.z).normalized().angle_to(Vector3.RIGHT))
	runner.note("crossways onto the rail: %s" % ("no grind" if caught_off < 0.0 else "locked on once %.0f° off" % caught_off))
	_check(caught_off <= tuning.grind_max_angle_deg, "grind: crossways only locks on once lined up")
	s.queue_free()


## Rolling at the rail's end at 4.5 m/s: popping 2.2 m before it lands a
## 50-50 on it; popping at the last moment (1.5 m) hits its end.
func _test_pop_on(rail: Rail) -> void:
	var early := await _pop_at_rail(rail, 2.2)
	var late := await _pop_at_rail(rail, 1.5)
	runner.note("popping onto the rail: 2.2 m before: %.1f s grind; 1.5 m before: %s" % [
			early[0], "bail" if late[1] else "%.1f s grind" % late[0]])
	_check(early[0] > 0.4 and not early[1], "grind: pop onto the rail from the ground and grind it")
	_check(late[0] == 0.0, "grind: popping too late hits the rail's end")


## Returns [grind seconds, bailed].
func _pop_at_rail(rail: Rail, pop_before: float) -> Array:
	var rail_start := rail.position.x - rail.length * 0.5
	var s := _spawn(Vector3(rail_start - 6.0, 0, rail.position.z), -90.0, Vector3(4.5, 0, 0))
	s.manual_intent.pose = Vector2(0, -1)
	var longest := 0.0
	for i in tps * 2:
		await _ticks(1)
		if s.global_position.x > rail_start - pop_before:
			s.manual_intent.pose = Vector2(0, 1)
		if s.grind.active:
			longest = maxf(longest, s.grind.time)
	var bailed := s.rider.bailed
	s.queue_free()
	await _ticks(1)
	return [longest, bailed]


## A scooter just above the rail's start, heading along it (+X) turned by
## `off_deg`, moving along it at `speed`.
func _drop_on_rail(rail: Rail, off_deg: float, speed: float) -> Scooter:
	var start := rail.position + Vector3(-rail.length * 0.5 + 0.6, rail.height + 0.03 - Scooter.DECK_BOTTOM, 0)
	var s := _spawn(start, -90.0 + off_deg, Vector3(speed, 0, 0))
	return s
