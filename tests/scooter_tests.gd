class_name ScooterTests
extends RefCounted
## Phase 2 exit criteria as physics tests. Each result is compared with a
## value worked out by hand from the tuning numbers (statics, energy,
## bicycle-model steering), not with the code's own output.

const SCOOTER_SCENE := preload("res://scooter/scooter.tscn")
const G := 9.81

var runner: Node3D
var tuning: ScooterTuning
## Physics ticks per second.
var tps := Engine.physics_ticks_per_second


func _init(test_runner: Node3D) -> void:
	runner = test_runner
	tuning = preload("res://scooter/scooter_tuning.tres")


func run() -> void:
	await _test_rest()
	await _test_coast()
	await _test_bank_energy()
	await _test_kicker()
	await _test_steering()
	await _test_grip_by_surface()
	await _test_recovery()


## Sits still on flat ground: no jitter, no creep, loads split by the
## centre of mass position.
func _test_rest() -> void:
	var s := _spawn(Vector3(40, 0, 40), 0.0)
	await _ticks(tps * 2)
	var start := s.global_position
	var max_speed := 0.0
	for i in tps:
		await _ticks(1)
		max_speed = maxf(max_speed, s.linear_velocity.length())
	var drift := (s.global_position - start).length()
	var weight := tuning.total_mass() * G
	var com_z := tuning.center_of_mass().z
	var expected_rear := weight * (tuning.wheelbase * 0.5 + com_z) / tuning.wheelbase
	var expected_front := weight - expected_rear
	_check(max_speed < 0.002 and drift < 0.001,
			"rest: still (max speed %.5f m/s, drift %.2f mm)" % [max_speed, drift * 1000.0])
	_check(_near(s.front_wheel.normal_force, expected_front, 0.02)
			and _near(s.rear_wheel.normal_force, expected_rear, 0.02),
			"rest: wheel loads F %.0f / R %.0f N (expected %.0f / %.0f)"
			% [s.front_wheel.normal_force, s.rear_wheel.normal_force, expected_front, expected_rear])
	s.queue_free()


## Coasting from 5 m/s on flat concrete: straight, and stops where rolling
## resistance plus air drag say it should.
## Distance = m / (2c) · ln(1 + c·v0² / (Crr·m·g)), with c = ½·ρ·CdA.
func _test_coast() -> void:
	var v0 := 5.0
	var start := Vector3(-100, 0, 150)
	var s := _spawn(start, 0.0, Vector3(0, 0, -v0))
	var ticks := 0
	while s.linear_velocity.length() > 0.02 and ticks < tps * 40:
		await _ticks(1)
		ticks += 1
	var m := tuning.total_mass()
	var c := 0.5 * Scooter.AIR_DENSITY * tuning.drag_area
	var expected := m / (2.0 * c) * log(1.0 + c * v0 * v0 / (tuning.rolling_resistance * m * G))
	var travelled := start.z - s.global_position.z
	var sideways := absf(s.global_position.x - start.x)
	_check(_near(travelled, expected, 0.05),
			"coast: stops after %.1f m (expected %.1f m) in %.1f s" % [travelled, expected, ticks / float(tps)])
	_check(sideways < 0.05, "coast: runs straight (%.1f mm sideways)" % (sideways * 1000.0))
	s.queue_free()


## Rolls off the deck of a 1 m bank and down the slope. Energy audit:
## final energy must equal the start plus the work every force did (wheels
## and drag). Physics that creates energy fails this. It also reports how
## much the stiff-legged ballast rider loses in the wheel dampers.
func _test_bank_energy() -> void:
	var bank := Bank.new()
	bank.position = Vector3(60, 0, 0)
	runner.add_child(bank)
	await _ticks(2)
	var start_z := -bank.slope_length() - 0.5
	var v0 := 0.8
	# Facing +Z (downhill), on the deck.
	var s := _spawn(Vector3(60, bank.height, start_z), 180.0, Vector3(0, 0, v0))
	await _ticks(1)
	var e0 := _energy(s)
	var c := 0.5 * Scooter.AIR_DENSITY * tuning.drag_area
	var drag_work := 0.0
	var max_compression := 0.0
	var airborne_ticks := 0
	var ticks := 0
	var work0 := _work(s)
	while s.global_position.z < 1.0 and ticks < tps * 10:
		var v := s.rider.linear_velocity.length()
		drag_work -= c * v * v * v / tps
		await _ticks(1)
		ticks += 1
		max_compression = maxf(max_compression, maxf(s.front_wheel.compression, s.rear_wheel.compression))
		if not s.is_grounded():
			airborne_ticks += 1
	_check(s.global_position.z >= 1.0, "bank: reaches the bottom (%.1f s)" % (ticks / float(tps)))
	var wheel_work := s.front_wheel.work_done + s.rear_wheel.work_done - work0.x
	var rider_work := s.rider.work_done - work0.y
	var e1 := _energy(s)
	var expected := e0 + wheel_work + rider_work + drag_work
	_check(absf(e1 - expected) < 0.02 * e0,
			"bank: energy audit balances (%.0f J, expected %.0f J)" % [e1, expected])
	var rolling := tuning.rolling_resistance * tuning.total_mass() * G * (s.global_position.z - start_z)
	runner.note("bank: wheels took %.0f J (rolling ≈ %.0f J), legs %.0f J, drag %.0f J, speed at bottom %.2f m/s"
			% [-wheel_work, rolling, -rider_work, -drag_work, s.linear_velocity.length()])
	_check(max_compression < tuning.wheel_travel * 0.8,
			"bank: never bottoms out (max compression %.1f mm)" % (max_compression * 1000.0))
	_check(airborne_ticks == 0, "bank: stays on the ground (%d airborne ticks)" % airborne_ticks)
	s.queue_free()
	bank.queue_free()


## Hits the kicker at 6 m/s: the rider's legs absorb the ~2 g transition so
## the rear wheel stays planted, it launches at the lip angle, and the energy
## audit balances up to takeoff.
func _test_kicker() -> void:
	var kicker := Kicker.new()
	kicker.position = Vector3(-60, 0, -40)
	runner.add_child(kicker)
	await _ticks(2)
	var lip_z := kicker.position.z - kicker.radius() * sin(deg_to_rad(kicker.lip_angle_deg))
	var v0 := 6.0
	var s := _spawn(Vector3(-60, 0, -36), 0.0, Vector3(0, 0, -v0))
	await _ticks(1)
	var e0 := _energy(s)
	var work0 := _work(s)
	var c := 0.5 * Scooter.AIR_DENSITY * tuning.drag_area
	var drag_work := 0.0
	var lost_contact_on_curve := 0
	var launch_angle := NAN
	var launched := false
	var min_leg := INF
	for i in tps * 2:
		var v := s.rider.linear_velocity.length()
		drag_work -= c * v * v * v / tps
		await _ticks(1)
		min_leg = minf(min_leg, s.rider.leg_length)
		var on_curve := s.front_wheel.contact_point.z < kicker.position.z - 0.05
		if not s.rear_wheel.in_contact and on_curve and s.global_position.z > lip_z + 0.15:
			lost_contact_on_curve += 1
		if not s.is_grounded() and s.global_position.z < lip_z:
			launched = true
			var flight := (s.linear_velocity * s.mass + s.rider.linear_velocity * s.rider.mass) \
					/ (s.mass + s.rider.mass)
			launch_angle = rad_to_deg(atan2(flight.y, Vector2(flight.x, flight.z).length()))
			var work := _work(s) - work0
			var expected := e0 + work.x + work.y + drag_work
			var energy := _energy(s)
			_check(absf(energy - expected) < 0.02 * e0,
					"kicker: energy audit balances at takeoff (%.0f J, expected %.0f J)" % [energy, expected])
			break
	_check(launched, "kicker: launches off the lip")
	_check(lost_contact_on_curve == 0,
			"kicker: rear wheel stays planted through the transition (%d ticks off)" % lost_contact_on_curve)
	# Flight direction of the combined centre of mass as the last wheel
	# leaves. A passive rider's knees soak up part of the transition, so it
	# launches flatter than the lip; popping at the lip (Phase 4) adds the rest.
	_check(launch_angle > kicker.lip_angle_deg * 0.5 and launch_angle < kicker.lip_angle_deg + 2.0,
			"kicker: passive rider flies off at %.1f° (lip %.0f°)" % [launch_angle, kicker.lip_angle_deg])
	runner.note("kicker: legs compressed to %.2f m (standing %.2f m)" % [min_leg, tuning.stand_leg_length()])
	s.queue_free()
	kicker.queue_free()


## Steady turn from 3 m/s at half stick: the rider's weight shift reaches
## the asked-for lean, the steering balances it (so the hips settle back
## over the deck), and the yaw rate matches the bicycle model. Tyre slip
## makes it understeer slightly.
func _test_steering() -> void:
	var s := _spawn(Vector3(100, 0, 100), 0.0, Vector3(0, 0, -3.0))
	s.manual_intent.lean = Vector2(0.5, 0.0)
	await _ticks(tps * 2)
	var speed := -s.linear_velocity.dot(s.global_basis.z)
	var yaw_rate := -s.angular_velocity.y
	var expected_rate := speed * _ground_steer_tan(s.steer_angle) / tuning.wheelbase
	var balanced_lean := atan(speed * yaw_rate / G)
	_check(absf(s.lean_angle - s.target_lean) < deg_to_rad(2.0),
			"steering: reaches the stick's lean (%.1f°, asked %.1f°)"
			% [rad_to_deg(s.lean_angle), rad_to_deg(s.target_lean)])
	_check(absf(s.lean_angle - balanced_lean) < deg_to_rad(2.0),
			"steering: the turn balances the lean (%.1f°, balanced %.1f°)"
			% [rad_to_deg(s.lean_angle), rad_to_deg(balanced_lean)])
	_check(absf(s.rider.hip_shift.x) < 0.05,
			"steering: hips back over the deck in the steady turn (%+.3f m)" % s.rider.hip_shift.x)
	_check(s.balance_torque == 0.0, "steering: no balance assist at speed")
	_check(_near(yaw_rate, expected_rate, 0.10),
			"steering: yaw rate %.3f rad/s at %.1f° steer (bicycle model %.3f)"
			% [yaw_rate, rad_to_deg(s.steer_angle), expected_rate])
	s.queue_free()


## Same hard carve on concrete and on steel: concrete (friction 0.9) grips
## at about 0.5 g sideways, steel (0.3) can't and slides.
func _test_grip_by_surface() -> void:
	var plate := StaticBody3D.new()
	plate.physics_material_override = PropMaterials.STEEL
	plate.position = Vector3(-120, 0.005, -120)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(40, 0.01, 40)
	plate.add_child(shape)
	runner.add_child(plate)
	await _ticks(2)

	var results := {}
	for surface in ["concrete", "steel"]:
		var at := Vector3(-120, 0.01, -105) if surface == "steel" else Vector3(-160, 0, -105)
		var s := _spawn(at, 0.0, Vector3(0, 0, -5.0))
		s.manual_intent.lean = Vector2(0.75, 0.0) # ~26° lean, ~0.5 g
		var slid := false
		for i in tps * 5 / 4:
			await _ticks(1)
			slid = slid or s.front_wheel.sliding or s.rear_wheel.sliding
		var speed := -s.linear_velocity.dot(s.global_basis.z)
		var lateral_g := speed * speed * _ground_steer_tan(s.steer_angle) / tuning.wheelbase / G
		results[surface] = [slid, lateral_g]
		s.queue_free()
	_check(not results["concrete"][0],
			"grip: concrete holds a %.2f g turn" % results["concrete"][1])
	_check(results["steel"][0],
			"grip: steel slides in the same %.2f g turn" % results["steel"][1])
	plate.queue_free()


## Falling over: stands itself up after the delay, where it fell. Tapping
## reset stands it up at once, keeping its heading. Holding reset returns
## to where it spawned.
func _test_recovery() -> void:
	var at := Vector3(-40, 0, 80)
	var s := _spawn(at, 0.0)
	# Tip it onto its side from a little height.
	s.global_transform = Transform3D(Basis(Vector3.FORWARD, PI * 0.5), at + Vector3(0, 0.3, 0))
	s.rider.place_on(s, tuning)
	var ticks := 0
	var rest := s.global_position
	while s.global_basis.y.y < 0.99 and ticks < tps * 5:
		rest = s.global_position
		await _ticks(1)
		ticks += 1
	var recovered_after := ticks / float(tps)
	_check(recovered_after >= tuning.auto_recover_delay and recovered_after < tuning.auto_recover_delay + 1.0,
			"recovery: stands itself up after %.2f s (delay %.1f s)" % [recovered_after, tuning.auto_recover_delay])
	var moved := Vector2(s.global_position.x - rest.x, s.global_position.z - rest.z).length()
	_check(moved < 0.05, "recovery: stands up where it came to rest (%.3f m away)" % moved)
	await _ticks(tps)
	_check(s.global_basis.y.y > 0.99 and s.linear_velocity.length() < 0.01,
			"recovery: settles upright (tilt %.1f°, %.3f m/s)"
			% [rad_to_deg(acos(clampf(s.global_basis.y.y, -1, 1))), s.linear_velocity.length()])
	s.queue_free()

	# Tap reset while riding: upright and stopped at once, same heading.
	var start := Vector3(-40, 0, 110)
	s = _spawn(start, 30.0, Basis(Vector3.UP, deg_to_rad(30.0)) * Vector3(0, 0, -4.0))
	s.manual_intent.lean = Vector2(0.6, 0.0)
	await _ticks(tps / 2)
	var heading_before := -s.global_basis.z
	s.manual_intent.lean = Vector2.ZERO
	s.manual_intent.reset = true
	await _ticks(1)
	s.manual_intent.reset = false
	await _ticks(1)
	_check(s.linear_velocity.length() < 0.05 and s.global_basis.y.y > 0.999,
			"recovery: tapping reset stands it up and stops it (%.3f m/s)" % s.linear_velocity.length())
	_check(Vector2(heading_before.x, heading_before.z).normalized().dot(
			Vector2(-s.global_basis.z.x, -s.global_basis.z.z)) > 0.999,
			"recovery: tapping reset keeps the heading")

	# Hold reset: back to the spawn point.
	s.linear_velocity = Basis(Vector3.UP, deg_to_rad(30.0)) * Vector3(0, 0, -4.0)
	await _ticks(tps * 3 / 4)
	s.manual_intent.reset = true
	await _ticks(int(tuning.respawn_hold_time * tps) + 5)
	s.manual_intent.reset = false
	await _ticks(2)
	var from_spawn := Vector2(s.global_position.x - start.x, s.global_position.z - start.z).length()
	_check(from_spawn < 0.02, "recovery: holding reset returns to the spawn point (%.3f m away)" % from_spawn)
	s.queue_free()


## Ground-plane steering from the headtube steering angle: the axis is
## raked back, so the wheel turns a little less across the ground.
func _ground_steer_tan(steer: float) -> float:
	return tan(steer) * sin(deg_to_rad(tuning.headtube_angle_deg))


func _spawn(pos: Vector3, yaw_deg: float, velocity := Vector3.ZERO) -> Scooter:
	var s: Scooter = SCOOTER_SCENE.instantiate()
	s.use_live_input = false
	# Start at the static wheel compression so it doesn't drop.
	var sink := tuning.total_mass() * G * 0.5 / tuning.wheel_stiffness
	s.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), pos - Vector3(0, sink, 0))
	s.linear_velocity = velocity
	runner.add_child(s)
	return s


func _ticks(n: int) -> void:
	for i in n:
		await runner.get_tree().physics_frame


## Total mechanical energy of scooter and rider: motion, height, and the
## wheel springs. (Leg forces aren't conservative, so their work is tracked
## separately in rider.work_done.)
func _energy(s: Scooter) -> float:
	var com := s.global_transform * s.center_of_mass
	var inertia := s.get_inverse_inertia_tensor().inverse()
	var r := s.rider
	return 0.5 * s.mass * s.linear_velocity.length_squared() \
			+ 0.5 * s.angular_velocity.dot(inertia * s.angular_velocity) \
			+ s.mass * G * com.y \
			+ 0.5 * r.mass * r.linear_velocity.length_squared() + r.mass * G * r.global_position.y \
			+ s.front_wheel.spring_energy(tuning) + s.rear_wheel.spring_energy(tuning)


## Work done so far by (wheels, rider's legs and hips).
func _work(s: Scooter) -> Vector2:
	return Vector2(s.front_wheel.work_done + s.rear_wheel.work_done, s.rider.work_done)


func _check(condition: bool, description: String) -> void:
	runner.check(condition, description)


## A criterion that belongs to a later phase: reported, not yet required.
func _pending(condition: bool, description: String) -> void:
	runner.note(("met early: " if condition else "later phase: ") + description)


static func _near(value: float, expected: float, tolerance: float) -> bool:
	return absf(value - expected) <= absf(expected) * tolerance
