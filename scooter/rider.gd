class_name Rider
extends RigidBody3D
## The rider's upper body (hips, torso, arms, head): the "sprung" mass that
## rides on the legs. The lower legs move with the deck and are part of the
## scooter body.
##
## The rider is joined to the scooter by two sets of forces, computed here
## each tick and applied equally and oppositely to both bodies:
## - Legs: a spring-damper along the leg axis, which follows the direction
##   of the ground's push (vertical standing, along the lean in turns, into
##   the ramp on transitions and vert). Muscles hold body
##   weight; the right stick sets leg length (crouch / extend), and the
##   spring absorbs whatever the ground does.
## - Hips: a stiffer spring holding the hips over the deck, at a sideways and
##   fore/aft offset the rider chooses. Shifting the hips is how the rider
##   leans (weight shift) and moves weight forward or back.
## Sideways, the hip reaction goes into the scooter at hip height, as if
## through the bars and stiff ankles, so the scooter rolls with the rider.
## Fore/aft it goes through the feet, so the scooter pitches freely under
## the rider on ramps.
##
## The rider does not rotate (rotation is locked): the upper body's own
## rotation doesn't matter for riding yet. It collides only with the world.

const LAYER_RIDER := 8

## Leg length (hips above the feet, along the leg axis), m.
var leg_length := 0.0
## Leg force along the leg axis this tick, N (+ pushes the rider up).
var leg_force := 0.0
## Where the rider wants the hips relative to the deck: x = sideways
## (+ right), y = fore/aft (+ forward), m.
var hip_shift := Vector2.ZERO
## Running total of work done by the leg and hip forces on both bodies, J.
## Muscles add energy (extending), dampers remove it.
var work_done := 0.0
## True while crashed: the rider has let go and falls as a free body.
var bailed := false
## Direction the legs point, from the feet toward the hips (see
## follow_support).
var support_axis := Vector3.UP

# What was applied last tick, to finish counting its work with the step's
# average velocity (see ScooterWheel._finish_work). Scooter-side entries are
# [force, local point, velocity when applied].
var _last_on_rider := Vector3.ZERO
var _last_rider_velocity := Vector3.ZERO
var _last_on_scooter: Array = []
var _last_torque := Vector3.ZERO
var _last_angular := Vector3.ZERO



func _ready() -> void:
	top_level = true # simulated on its own, not dragged by the scooter node
	collision_layer = LAYER_RIDER
	collision_mask = PropMaterials.LAYER_WORLD
	lock_rotation = true
	can_sleep = false
	continuous_cd = true
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp = 0.0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.17
	capsule.height = 0.7
	shape.shape = capsule
	shape.position = Vector3(0, 0.15, 0) # torso sits above the hips
	add_child(shape)


## Point on the deck where the feet are, in world space.
static func feet_point(scooter: RigidBody3D, tuning: ScooterTuning) -> Vector3:
	return scooter.global_transform * Vector3(0, tuning.deck_top, tuning.rider_com_offset)


## One tick of the rider: decide hip shift and leg length from the intent and
## the current lean, then apply leg and hip forces to both bodies.
func simulate(scooter: Scooter, tuning: ScooterTuning, intent: RiderIntent,
		lean: float, lean_rate: float, target_lean: float) -> void:
	var delta := get_physics_process_delta_time()
	_finish_work(scooter, delta)
	if bailed:
		leg_force = 0.0
		return
	mass = tuning.sprung_rider_mass()

	# Weight shift: move the hips toward the lean you want, damped by how
	# fast you're already leaning. In a balanced turn the lean error is zero,
	# so the hips sit centred.
	var sideways := tuning.hip_lean_gain * (target_lean - lean) - tuning.hip_lean_damping * lean_rate
	hip_shift.x = clampf(sideways, -tuning.max_hip_shift, tuning.max_hip_shift)
	hip_shift.y = intent.lean.y * tuning.max_hip_fore_aft

	# Leg length from the right stick: down crouches, up extends.
	var stand := tuning.stand_leg_length()
	var target_length := stand
	if intent.pose.y < 0.0:
		target_length = lerpf(stand, stand - tuning.crouch_depth, -intent.pose.y)
	else:
		target_length = lerpf(stand, tuning.max_leg_length(), intent.pose.y)

	var axis := leg_axis(scooter)
	var right := scooter.global_basis.x
	right = (right - axis * right.dot(axis)).normalized()
	var forward := axis.cross(right)
	var feet := feet_point(scooter, tuning)
	var com := scooter.global_transform * scooter.center_of_mass
	var feet_velocity := scooter.linear_velocity + scooter.angular_velocity.cross(feet - com)
	var relative := global_position - feet
	leg_length = relative.dot(axis)
	var hip_anchor := feet + axis * leg_length
	var anchor_velocity := scooter.linear_velocity + scooter.angular_velocity.cross(hip_anchor - com)

	# Legs. Muscles carry the body's weight (the share along the leg) plus a
	# spring toward the chosen length; the joints stop the leg at its limits.
	var leg_mass := _pair_mass(scooter, feet - com, axis)
	var extension_speed := (linear_velocity - feet_velocity).dot(axis)
	var muscle := mass * Scooter.GRAVITY * maxf(axis.y, 0.0) \
			+ tuning.leg_stiffness * (target_length - leg_length) \
			- _damping(tuning.leg_stiffness, tuning.leg_damping_ratio, leg_mass) * extension_speed
	muscle = clampf(muscle, -tuning.leg_max_pull, tuning.leg_max_push)
	var joint_stop := 0.0
	var shortest := stand - tuning.crouch_depth - 0.1
	if leg_length < shortest:
		joint_stop = tuning.leg_stop_stiffness * (shortest - leg_length)
	elif leg_length > tuning.max_leg_length() + 0.05:
		joint_stop = -tuning.leg_stop_stiffness * (leg_length - tuning.max_leg_length() - 0.05)
	leg_force = muscle + joint_stop

	# Hips: pull toward the anchor plus the chosen shift, across the leg
	# axis only (the legs handle along it). Sideways, the reaction goes into
	# the scooter on its own upright axis (bars and stem), so it can only
	# roll the scooter, never twist it in yaw however far it's pitched.
	var target := hip_anchor + right * hip_shift.x + forward * hip_shift.y
	var error := global_position - target
	var mast_point := feet + scooter.global_basis.y * leg_length
	var mast_velocity := scooter.linear_velocity + scooter.angular_velocity.cross(mast_point - com)
	var side_speed := (linear_velocity - mast_velocity).dot(right)
	var fore_speed := (linear_velocity - feet_velocity).dot(forward)
	# Damping sized for the mass each force actually meets. Pushed sideways
	# at hip height, the light scooter mostly rotates away (~1.3 kg
	# effective), and too much damping on a light body diverges.
	var side_mass := _pair_mass(scooter, mast_point - com, right)
	var fore_mass := _pair_mass(scooter, feet - com, forward)
	var sideways_force := -(tuning.hip_stiffness * error.dot(right)
			+ _damping(tuning.hip_stiffness, tuning.hip_damping_ratio, side_mass) * side_speed)
	var fore_aft_force := -(tuning.hip_stiffness * error.dot(forward)
			+ _damping(tuning.hip_stiffness, tuning.hip_damping_ratio, fore_mass) * fore_speed)

	var leg := axis * leg_force
	var side := right * sideways_force
	var fore := forward * fore_aft_force
	apply_central_force(leg + side + fore)
	# Legs and fore/aft hips push through the scooter's centre of mass: with
	# both feet sharing the load, a rider's weight doesn't pry the deck
	# round. (Applied at a single point on the deck below the centre of mass,
	# a tilted leg force pitched the light scooter nose-up and lifted it off
	# ramp walls.) The wheels then share the load by where that centre sits.
	var com_velocity := scooter.linear_velocity
	scooter.add_tracked_force(-(leg + fore), com)
	scooter.add_tracked_force(-side, mast_point)
	work_done += ((leg + side + fore).dot(linear_velocity) - (leg + fore).dot(com_velocity)
			- side.dot(mast_velocity)) * delta
	var to_local := scooter.global_transform.affine_inverse()
	_last_on_rider = leg + side + fore
	_last_rider_velocity = linear_velocity
	_last_on_scooter = [
		[-(leg + fore), to_local * com, com_velocity],
		[-side, to_local * mast_point, mast_velocity],
	]

	# Arms and ankles: damp the deck's pitch rate (the upper body doesn't
	# rotate, so this is the pitch rate relative to the rider). On the ground
	# only; in the air, AirControl holds or drives the pitch.
	if not scooter.is_grounded():
		return
	var pitch_axis := scooter.global_basis.x
	var pitch_torque := -pitch_axis * tuning.deck_pitch_damping * scooter.angular_velocity.dot(pitch_axis)
	scooter.add_tracked_torque(pitch_torque)
	work_done += pitch_torque.dot(scooter.angular_velocity) * delta
	_last_torque = pitch_torque
	_last_angular = scooter.angular_velocity


func _finish_work(scooter: RigidBody3D, delta: float) -> void:
	var extra := _last_on_rider.dot(linear_velocity - _last_rider_velocity)
	var com := scooter.global_transform * scooter.center_of_mass
	for entry in _last_on_scooter:
		var point: Vector3 = scooter.global_transform * entry[1]
		var v_now := scooter.linear_velocity + scooter.angular_velocity.cross(point - com)
		extra += (entry[0] as Vector3).dot(v_now - entry[2])
	extra += _last_torque.dot(scooter.angular_velocity - _last_angular)
	work_done += 0.5 * extra * delta
	_last_on_rider = Vector3.ZERO
	_last_on_scooter = []
	_last_torque = Vector3.ZERO


## Mass seen by a force between the rider and the scooter at `r` (from the
## scooter's centre of mass) along `dir`: the rider and the scooter's
## effective mass at that point, in series.
func _pair_mass(scooter: RigidBody3D, r: Vector3, dir: Vector3) -> float:
	var scooter_mass := ScooterWheel._effective_mass(scooter, r, dir)
	return 1.0 / (1.0 / mass + 1.0 / scooter_mass)


static func _damping(stiffness: float, ratio: float, pair_mass: float) -> float:
	return 2.0 * ratio * sqrt(stiffness * pair_mass)


## Direction of the legs: along the ground's push on the rider (see
## follow_support). Kept within 70° of the deck's up, as a safety limit.
func leg_axis(scooter: RigidBody3D) -> Vector3:
	var up := scooter.global_basis.y
	if support_axis.dot(up) < 0.34:
		return up
	return support_axis


## A rider keeps their body along the push they get from the ground, or
## they'd be tipped over by it. That push is gravity plus the centripetal
## push of a curved ramp, so the axis is the scooter's roll (you lean
## together) combined with the ramp's curvature at the current speed:
## vertical on flat ground, tilted toward the ramp on a transition, into the
## wall on vert at speed. It's computed from geometry, not from measured
## forces: following the measured ground force feeds back on itself (the
## rider's own lean tilts the force) and tips the rider over.
## `normal` is the average contact normal, `curvature` 1/m (+ concave).
## Only called with both wheels on the ground; in the air the axis stays.
func follow_ramp(scooter: RigidBody3D, normal: Vector3, curvature: float, speed: float,
		response: float, delta: float) -> void:
	var right := scooter.global_basis.x
	var level := Vector3.UP - right * Vector3.UP.dot(right)
	level = level.normalized() if level.length_squared() > 1e-4 else scooter.global_basis.y
	var push := level * Scooter.GRAVITY + normal * speed * speed * curvature
	if push.length() < 1.0:
		return # nearly weightless (over a crest): keep the current axis
	# Normalised lerp, not slerp: slerp's internal rotation axis loses
	# precision when the two directions are nearly parallel (most ticks).
	support_axis = support_axis.lerp(push.normalized(), 1.0 - exp(-delta / response)).normalized()


## Puts the rider standing on the deck, at rest.
func place_on(scooter: RigidBody3D, tuning: ScooterTuning) -> void:
	var feet := feet_point(scooter, tuning)
	# Standing length: muscles carry the weight, so there's no sag to add.
	support_axis = scooter.global_basis.y
	global_transform = Transform3D(Basis(), feet + support_axis * tuning.stand_leg_length())
	linear_velocity = scooter.linear_velocity
	angular_velocity = Vector3.ZERO
	bailed = false
	reset_physics_interpolation()
