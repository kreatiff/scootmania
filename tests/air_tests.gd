class_name AirTests
extends ScooterTests
## Phase 5: airs, landings and bails.


func run() -> void:
	await _test_kicker_landings()
	await _test_air_control()
	await _test_free_flight_audit()
	await _test_bad_landing_bails()
	await _test_air_back_in()
	await _test_slow_motion()


## Rolling and popping off the kicker both land without bailing. The
## landing assist is what lines the flat landing up after a 33° launch.
func _test_kicker_landings() -> void:
	var kicker := _add_kicker(Vector3(-140, 0, -60))
	await _ticks(2)
	var passive := await _kicker_run(kicker, false, 1.0)
	var popped := await _kicker_run(kicker, true, 1.0)
	var unassisted := await _kicker_run(kicker, false, 0.0)
	runner.note("kicker landings: passive %s (%.0f°), popped %s (%.0f°), no assist %s (%.0f°)" % [
			AirControl.landing_name(passive[0]), passive[1], AirControl.landing_name(popped[0]), popped[1],
			AirControl.landing_name(unassisted[0]), unassisted[1]])
	_check(passive[0] != AirControl.Landing.BAIL and passive[0] != AirControl.Landing.NONE,
			"landing: rolling off the kicker lands (%s)" % AirControl.landing_name(passive[0]))
	_check(popped[0] != AirControl.Landing.BAIL and popped[0] != AirControl.Landing.NONE,
			"landing: popping off the kicker lands (%s)" % AirControl.landing_name(popped[0]))
	_check(passive[2], "landing: the assist lined up the landing")
	_check(passive[1] < unassisted[1],
			"landing: assist lands flatter (%.0f° vs %.0f° without)" % [passive[1], unassisted[1]])
	kicker.queue_free()


## Returns [landing grade, tilt at landing (deg), assist was active].
func _kicker_run(kicker: Kicker, pop: bool, assist: float) -> Array:
	var lip_z := kicker.position.z - kicker.radius() * sin(deg_to_rad(kicker.lip_angle_deg))
	var s := _spawn(kicker.position + Vector3(0, 0, 4), 0.0, Vector3(0, 0, -6.0))
	s.tuning = tuning.duplicate()
	s.tuning.landing_assist_strength = assist
	if pop:
		s.manual_intent.pose = Vector2(0, -1)
	var grade := AirControl.Landing.NONE
	var assisted := false
	for i in tps * 4:
		await _ticks(1)
		if pop and s.global_position.z < lip_z + 0.9:
			s.manual_intent.pose = Vector2(0, 1)
		assisted = assisted or s.air.assist_active
		if s.air.last_landing != AirControl.Landing.NONE:
			grade = s.air.last_landing
			break
	var tilt := rad_to_deg(s.air.last_tilt)
	s.queue_free()
	return [grade, tilt, assisted]


## In the air, left stick forward pitches the nose down, centred holds the
## pitch, and sideways spins.
func _test_air_control() -> void:
	var kicker := _add_kicker(Vector3(-140, 0, -100))
	await _ticks(2)
	var held := await _air_rotation(kicker, Vector2.ZERO)
	var nose_down := await _air_rotation(kicker, Vector2(0, 1))
	var spun := await _air_rotation(kicker, Vector2(1, 0))
	_check(absf(held[0]) < 8.0, "air: stick centred holds the pitch (%+.1f° in 0.3 s)" % held[0])
	_check(nose_down[0] < -30.0, "air: stick forward pitches the nose down (%+.1f° in 0.3 s)" % nose_down[0])
	_check(absf(spun[1]) > 70.0, "air: stick sideways spins (%.0f° in 0.3 s)" % absf(spun[1]))
	kicker.queue_free()


## Pops off the kicker, then holds `stick` for 0.3 s early in the air.
## Returns [pitch change, yaw change] in degrees.
func _air_rotation(kicker: Kicker, stick: Vector2) -> Array:
	var lip_z := kicker.position.z - kicker.radius() * sin(deg_to_rad(kicker.lip_angle_deg))
	var s := _spawn(kicker.position + Vector3(0, 0, 4), 0.0, Vector3(0, 0, -6.0))
	s.manual_intent.pose = Vector2(0, -1)
	while not (s.air.airborne and s.global_position.z < lip_z):
		await _ticks(1)
		if s.global_position.z < lip_z + 0.9:
			s.manual_intent.pose = Vector2(0, 1)
	var pitch0 := _pitch(s)
	var yaw0 := s.global_basis.get_euler().y
	s.manual_intent.lean = stick
	await _ticks(int(0.3 * tps))
	var pitch_change := _pitch(s) - pitch0
	var yaw_change := rad_to_deg(wrapf(s.global_basis.get_euler().y - yaw0, -PI, PI))
	s.queue_free()
	return [pitch_change, yaw_change]


## Thrown high with a spin and no input, for 2 s: the energy audit
## balances (everything the hips, legs, air control and drag did is
## accounted for), and the spin doesn't grow into a wobble. The hips and the
## roll levelling used to feed each other here (the hip spring measured its
## stretch at the feet but pushed at hip height).
func _test_free_flight_audit() -> void:
	for spin in [Vector3(1.0, 0.5, 0.3), Vector3(0.0, 0.0, 1.0), Vector3(0.0, 0.5, 0.0)]:
		var audit := await _free_flight(spin)
		runner.note("free flight, spin %s: %s" % [spin, audit[1]])
		_check(audit[0], "free flight: energy audit balances with spin %s (%s)" % [spin, audit[1]])
		_check(audit[2] <= spin.length() * 1.05,
				"free flight: spin %s doesn't grow (peak %.2f rad/s in the second half)" % [spin, audit[2]])


## Returns [audit balanced, audit text, peak angular speed in the second
## second]. Energies are measured from the start height, so the audit is
## held to 3% of the motion's energy rather than of 60 m of height, and
## with the engine's gravity (the project default, not Scooter.GRAVITY).
func _free_flight(spin: Vector3) -> Array:
	var at := Vector3(200, 60, 200)
	var s := _spawn(at, 0.0, Vector3(0, 2, -3))
	s.angular_velocity = spin
	await _ticks(1)
	var g: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var total_mass := s.mass + s.rider.mass
	var height_energy := total_mass * g * at.y
	var e0 := _energy(s, g) - height_energy
	var work0 := _work(s)
	var air_work0 := s.air_work
	var c := 0.5 * Scooter.AIR_DENSITY * tuning.drag_area
	var drag_work := 0.0
	var peak := 0.0
	var grounded := false
	for i in tps * 2:
		var v := s.rider.linear_velocity.length()
		drag_work -= c * v * v * v / tps
		await _ticks(1)
		grounded = grounded or s.is_grounded() or s.air.assist_active
		if i >= tps:
			peak = maxf(peak, s.angular_velocity.length())
	# The integrator (velocity first, then position) falls a little further
	# each tick than the speed it gains pays for: ½·m·g²·dt² per tick.
	var dt := 1.0 / tps
	var integration := -0.5 * total_mass * g * g * dt * dt * tps * 2
	var work := _work(s) - work0
	var residual := (_energy(s, g) - height_energy) - (e0 + work.x + work.y + drag_work + integration)
	var text := "%+.1f J unexplained of %.0f J; hips and legs %+.0f J, air control %+.0f J, drag %+.0f J" % [
			residual, e0, work.y, s.air_work - air_work0, drag_work]
	s.queue_free()
	return [absf(residual) < 0.03 * e0 and not grounded, text, peak]


## Dropped nose-high from a metre up, too far out for the assist to save:
## a bail. The rider lets go, and recovery stands the scooter back up.
func _test_bad_landing_bails() -> void:
	var at := Vector3(-100, 1.0, -140)
	var s := _spawn(at, 0.0)
	s.global_transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(60.0)), at)
	s.rider.place_on(s, tuning)
	var bail_signals := [0]
	s.bailed.connect(func() -> void: bail_signals[0] += 1)
	var grade := AirControl.Landing.NONE
	for i in tps * 2:
		await _ticks(1)
		if s.air.last_landing != AirControl.Landing.NONE:
			grade = s.air.last_landing
			break
	_check(grade == AirControl.Landing.BAIL,
			"bail: 60° nose-high landing bails (%s, %.0f°)" % [AirControl.landing_name(grade), rad_to_deg(s.air.last_tilt)])
	_check(bail_signals[0] == 1 and s.rider.bailed, "bail: the rider lets go (signal sent once)")
	var got_up := false
	for i in int((tuning.auto_recover_delay + 1.5) * tps):
		await _ticks(1)
		if not s.rider.bailed and s.is_grounded() and s.global_basis.y.y > 0.99:
			got_up = true
			break
	_check(got_up, "bail: recovery stands the scooter back up")
	s.queue_free()


## Air out of a vertical-lipped quarter pipe and come back down into it
## fakie. Like a real rider, crouch on the way in and extend through the
## transition: passively, the knees soak up the transition and you stall
## below the lip. (The park's quarter pipe has a 70° lip, which throws you
## onto the deck unless you turn; that's real, and why riders spin 180s.)
func _test_air_back_in() -> void:
	var qp := QuarterPipe.new()
	qp.height = 2.0
	qp.radius = 2.0
	qp.width = 4.0
	qp.position = Vector3(0, 0, -160)
	runner.add_child(qp)
	await _ticks(2)
	var s := _spawn(qp.position + Vector3(0, 0, 5), 0.0, Vector3(0, 0, -8.5))
	var grades: Array[int] = []
	s.landed.connect(func(grade: int) -> void: grades.append(grade))
	var apex := 0.0
	s.manual_intent.pose = Vector2(0, -1)
	for i in tps * 5:
		await _ticks(1)
		apex = maxf(apex, s.global_position.y - qp.height)
		# Extend while on the transition, going up.
		if s.is_grounded() and s.global_position.z < qp.position.z and s.linear_velocity.y > 0.0:
			s.manual_intent.pose = Vector2(0, 0.5)
		elif s.air.airborne:
			s.manual_intent.pose = Vector2.ZERO
	var bails := grades.count(AirControl.Landing.BAIL)
	runner.note("air back in: %.2f m above the coping, landings %s" % [apex, grades.map(AirControl.landing_name)])
	_check(apex > 0.2, "air back in: gets %.2f m above the coping" % apex)
	_check(bails == 0 and not s.rider.bailed, "air back in: lands back in without bailing")
	_check(s.global_position.z > qp.position.z and s.linear_velocity.z > 1.0,
			"air back in: rides away fakie (%.1f m/s)" % s.linear_velocity.z)
	s.queue_free()
	qp.queue_free()


## Slow motion slows the game, then restores it after its (real) time.
func _test_slow_motion() -> void:
	var slow := SlowMotion.new()
	runner.add_child(slow)
	slow.play(0.3, 0.5)
	_check(is_equal_approx(Engine.time_scale, 0.3), "slow motion: starts at 0.3× speed")
	for i in 200: # 200 frames at the test's fixed 1/240 s ≈ 0.83 s
		await runner.get_tree().process_frame
	_check(is_equal_approx(Engine.time_scale, 1.0) and not slow.active, "slow motion: back to normal after 0.5 s")
	slow.queue_free()


func _add_kicker(at: Vector3) -> Kicker:
	var kicker := Kicker.new()
	kicker.position = at
	runner.add_child(kicker)
	return kicker


static func _pitch(s: Scooter) -> float:
	return rad_to_deg(asin(clampf(-s.global_basis.z.y, -1.0, 1.0)))
