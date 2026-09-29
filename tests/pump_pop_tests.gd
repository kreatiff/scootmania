class_name PumpPopTests
extends ScooterTests
## Phase 4: the rider's legs add and remove energy. Popping (crouch, then
## extend fast) lifts the scooter off the ground; popping at a kicker's lip
## flies higher than rolling off it; pumping a mini ramp keeps you going
## without kicking, where a passive rider stops.


func run() -> void:
	await _test_pop()
	await _test_kicker_pop()
	await _test_pumping()


## The pop is forgiving: a quick flick up from the centre leaves the
## ground at once and clears well over the height of a rail; from a crouch
## or as a sloppy diagonal it still pops; a slow push up doesn't (that's
## extending, for pumping).
func _test_pop() -> void:
	var flick := await _pop_height([Vector2(0, 1)])
	var crouched := await _pop_height([Vector2(0, -1), Vector2(0, -1), Vector2(0, 1)])
	var diagonal := await _pop_height([Vector2(0.6, 0.7)])
	var slow: Array[Vector2] = []
	for i in int(0.5 * tps):
		slow.append(Vector2(0, i / (0.5 * tps)))
	var pushed := await _pop_height(slow)
	runner.note("pop: flick %.2f m (off the ground after %.3f s), crouched %.2f m, diagonal %.2f m, slow push %.2f m" % [
			flick[0], flick[2], crouched[0], diagonal[0], pushed[0]])
	_check(flick[0] > 0.4 and flick[2] < 0.03, "pop: a flick up leaves the ground at once and clears %.2f m" % flick[0])
	_check(flick[1] and crouched[1], "pop: lands upright")
	_check(crouched[0] > 0.3, "pop: a flick up from a crouch pops too (%.2f m)" % crouched[0])
	_check(diagonal[0] > 0.3, "pop: a sloppy diagonal flick still pops (%.2f m)" % diagonal[0])
	_check(pushed[0] < 0.05, "pop: a slow push up doesn't pop (%.2f m)" % pushed[0])


## Rolling at 2 m/s, feeds `stick` one sample per tick (crouch samples
## are held for a quarter second), then lets go. Returns [max clearance of
## the lower wheel, landed upright, seconds from the last input to leaving
## the ground].
func _pop_height(stick: Array) -> Array:
	var s := _spawn(Vector3(140, 0, 140), 0.0, Vector3(0, 0, -2.0))
	await _ticks(tps / 4)
	for sample in stick:
		s.manual_intent.pose = sample
		await _ticks(tps / 4 if sample.y < -0.5 else 1)
	var clearance := 0.0
	var off_after := INF
	for i in tps:
		if off_after == INF and not s.is_grounded():
			off_after = i / float(tps)
		await _ticks(1)
		clearance = maxf(clearance, _lowest_wheel_clearance(s))
	s.manual_intent.pose = Vector2.ZERO
	await _ticks(tps * 2)
	var upright := not s.is_fallen() and not s.rider.bailed and s.is_grounded()
	s.queue_free()
	return [clearance, upright, off_after]


## Crouch into the kicker and extend just before the lip: flies higher and
## longer than rolling off passively.
func _test_kicker_pop() -> void:
	var kicker := Kicker.new()
	kicker.position = Vector3(-140, 0, 60)
	runner.add_child(kicker)
	await _ticks(2)
	var passive := await _kicker_flight(kicker, false)
	var popped := await _kicker_flight(kicker, true)
	runner.note("kicker: passive apex %.2f m, %.2f s air, %.1f°; popped apex %.2f m, %.2f s air, %.1f°"
			% [passive[0], passive[1], passive[2], popped[0], popped[1], popped[2]])
	_check(popped[0] > passive[0] + 0.1,
			"kicker pop: flies higher (%.2f m vs %.2f m)" % [popped[0], passive[0]])
	_check(popped[1] > passive[1],
			"kicker pop: stays up longer (%.2f s vs %.2f s)" % [popped[1], passive[1]])
	kicker.queue_free()


## Returns [apex height of the combined centre of mass above its start,
## airtime, launch angle].
func _kicker_flight(kicker: Kicker, pop: bool) -> Array:
	var lip_z := kicker.position.z - kicker.radius() * sin(deg_to_rad(kicker.lip_angle_deg))
	var s := _spawn(kicker.position + Vector3(0, 0, 4), 0.0, Vector3(0, 0, -6.0))
	if pop:
		s.manual_intent.pose = Vector2(0, -1)
	await _ticks(1)
	var start_height := s.system_center_of_mass().y
	var apex := 0.0
	var air := 0
	var angle := NAN
	var launched := false
	for i in tps * 3:
		await _ticks(1)
		# Flick up as the rear wheel reaches the lip.
		if pop and s.global_position.z < lip_z + 0.3:
			s.manual_intent.pose = Vector2(0, 1)
		if not s.is_grounded() and s.global_position.z < lip_z:
			if not launched:
				launched = true
				var v := (s.linear_velocity * s.mass + s.rider.linear_velocity * s.rider.mass) / (s.mass + s.rider.mass)
				angle = rad_to_deg(atan2(v.y, Vector2(v.x, v.z).length()))
			air += 1
			apex = maxf(apex, s.system_center_of_mass().y - start_height)
		elif launched:
			break
	s.queue_free()
	return [apex, air / float(tps), angle]


## Back and forth on a mini ramp for 20 s without kicking. Passive: stops.
## Pumping (extend going up the transitions, crouch elsewhere): still riding
## high at the end, and the energy audit balances, so the extra energy
## really comes from the legs.
func _test_pumping() -> void:
	var origin := Vector3(150, 0, -150)
	var ramps: Array[QuarterPipe] = []
	for spec in [[origin + Vector3(0, 0, -2.5), 0.0], [origin, PI]]:
		var q := QuarterPipe.new()
		q.height = 0.9
		q.radius = 1.8
		q.deck_length = 1.0
		q.width = 4.0
		q.transform = Transform3D(Basis(Vector3.UP, spec[1]), spec[0])
		runner.add_child(q)
		ramps.append(q)
	await _ticks(2)

	var passive := await _ride_mini_ramp(origin, false)
	var pumped := await _ride_mini_ramp(origin, true)
	runner.note("mini ramp: passive highest point in the last 5 s %.2f m; pumping %.2f m"
			% [passive[0], pumped[0]])
	_check(passive[1] < 0.05, "mini ramp: passive rider stops (%.2f m/s)" % passive[1])
	_check(pumped[0] > 0.3, "mini ramp: pumping still rides %.2f m up the walls after 20 s" % pumped[0])
	_check(pumped[2], "mini ramp: pumping makes no energy of its own (%s)" % pumped[3])
	for q in ramps:
		q.queue_free()


## Returns [highest scooter point in the last 5 s, final speed,
## audit balanced, audit text].
func _ride_mini_ramp(origin: Vector3, pump: bool) -> Array:
	var s := _spawn(origin + Vector3(0, 0, -1.25), 0.0, Vector3(0, 0, -3.2))
	# The audit can't count contact forces from the physics engine (the deck
	# or body scraping the ramp), so it only sums ticks without any.
	s.contact_monitor = true
	s.max_contacts_reported = 4
	s.rider.contact_monitor = true
	s.rider.max_contacts_reported = 4
	var residual := 0.0
	var clean_ticks := 0
	await _ticks(1)
	var e0 := _energy(s)
	var c := 0.5 * Scooter.AIR_DENSITY * tuning.drag_area
	var drag_work := 0.0
	var highest := 0.0
	var duration := tps * 20
	for i in duration:
		var v := s.rider.linear_velocity.length()
		var drag_step := -c * v * v * v / tps
		drag_work += drag_step
		var energy_before := _energy(s)
		var work_before := _work(s)
		if pump:
			s.manual_intent.pose.y = move_toward(s.manual_intent.pose.y, _pump_target(s), 6.0 / tps)
		# Stay on the ramp's centre line, as a rider would, by leaning
		# toward it (leaning right accelerates right, forward or fakie). Only
		# on the ground: in the air, the same stick spins the scooter.
		var want := atan((-2.0 * (s.global_position.x - origin.x) - 2.0 * s.linear_velocity.x) / G)
		s.manual_intent.lean.x = clampf(want / deg_to_rad(tuning.max_lean_deg), -1.0, 1.0) \
				if s.is_grounded() else 0.0
		await _ticks(1)
		if s.get_contact_count() == 0 and s.rider.get_contact_count() == 0:
			var step_work := _work(s) - work_before
			residual += (_energy(s) - energy_before) - (step_work.x + step_work.y + drag_step)
			clean_ticks += 1
		if i > duration - tps * 5:
			highest = maxf(highest, s.global_position.y)
	# What the audit guards against is physics *making* energy, so pumping
	# would work for the wrong reason. Each tick carries up to ±0.5 J of
	# integration error from the stiff legs (average velocity over the step
	# is exact only for a constant force), which over 20 s sums to a small
	# net loss; that's numerical damping, reported but not failed.
	var clean_share := clean_ticks / float(duration)
	var result := [highest, s.linear_velocity.length(),
			residual < 0.03 * e0 and clean_share > 0.8,
			"%+.0f J unexplained (%.1f%% of the start) over the %.0f%% of ticks without a body scrape"
			% [residual, residual / e0 * 100.0, clean_share * 100.0]]
	s.queue_free()
	return result


## A simple pumping rhythm (kept under the pop threshold, 0.5: a quick
## push past it pops): extend through the lower transition while
## going up (where the ground pushes hardest), then stay still, so the legs
## don't reach full stretch and throw the scooter off the wall; crouch on
## the way down.
static func _pump_target(s: Scooter) -> float:
	var normal := (s.front_wheel.contact_normal + s.rear_wheel.contact_normal).normalized()
	var slope := rad_to_deg(acos(clampf(normal.y, -1.0, 1.0)))
	if not s.is_grounded():
		return 0.0
	if s.rider.linear_velocity.y > 0.05:
		return 0.45 if slope > 8.0 and slope < 35.0 else 0.0
	return -0.7


func _lowest_wheel_clearance(s: Scooter) -> float:
	var front := (s.global_transform * s.front_wheel.position).y
	var rear := (s.global_transform * s.rear_wheel.position).y
	return minf(front, rear) - tuning.wheel_radius
