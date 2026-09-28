class_name Rider
extends RigidBody3D
## The rider's upper body (hips, torso, arms, head): the "sprung" mass that
## rides on the legs. The lower legs move with the deck and are part of the
## scooter body.
##
## The rider is joined to the scooter by two sets of forces, computed here
## each tick and applied equally and oppositely to both bodies:
## - Legs: a spring-damper along the leg axis (the scooter's roll, but
##   vertical in pitch). Muscles hold body
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

	# The leg axis follows the scooter's roll (you lean together) but stays
	# vertical in pitch: when the scooter pitches up a ramp, the hips stay
	# over the feet relative to gravity instead of swinging back with it.
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
	var m_reduced := mass * scooter.mass / (mass + scooter.mass)
	var extension_speed := (linear_velocity - feet_velocity).dot(axis)
	var muscle := mass * Scooter.GRAVITY * maxf(axis.y, 0.0) \
			+ tuning.leg_stiffness * (target_length - leg_length) \
			- 2.0 * tuning.leg_damping_ratio * sqrt(tuning.leg_stiffness * m_reduced) * extension_speed
	muscle = clampf(muscle, -tuning.leg_max_pull, tuning.leg_max_push)
	var joint_stop := 0.0
	var shortest := stand - tuning.crouch_depth - 0.1
	if leg_length < shortest:
		joint_stop = tuning.leg_stop_stiffness * (shortest - leg_length)
	elif leg_length > tuning.max_leg_length() + 0.05:
		joint_stop = -tuning.leg_stop_stiffness * (leg_length - tuning.max_leg_length() - 0.05)
	leg_force = muscle + joint_stop

	# Hips: pull toward the anchor plus the chosen shift, across the leg
	# axis only (the legs handle along it).
	var target := hip_anchor + right * hip_shift.x + forward * hip_shift.y
	var error := global_position - target
	var error_speed := linear_velocity - anchor_velocity
	var hip_damping := 2.0 * tuning.hip_damping_ratio * sqrt(tuning.hip_stiffness * m_reduced)
	var sideways_force := -(tuning.hip_stiffness * error.dot(right) + hip_damping * error_speed.dot(right))
	var fore_aft_force := -(tuning.hip_stiffness * error.dot(forward) + hip_damping * error_speed.dot(forward))

	# Sideways, the reaction goes into the scooter at hip height (hands on
	# the bars, stiff ankles): the scooter rolls with the rider. Fore/aft it
	# goes through the feet, so the scooter is free to pitch under them.
	var leg := axis * leg_force
	var side := right * sideways_force
	var fore := forward * fore_aft_force
	apply_central_force(leg + side + fore)
	scooter.add_tracked_force(-(leg + fore), feet)
	scooter.add_tracked_force(-side, hip_anchor)
	work_done += ((leg + side + fore).dot(linear_velocity) - (leg + fore).dot(feet_velocity)
			- side.dot(anchor_velocity)) * delta

	# Arms and ankles: damp the deck's pitch rate (the upper body doesn't
	# rotate, so this is the pitch rate relative to the rider).
	var pitch_axis := scooter.global_basis.x
	var pitch_torque := -pitch_axis * tuning.deck_pitch_damping * scooter.angular_velocity.dot(pitch_axis)
	scooter.add_tracked_torque(pitch_torque)
	work_done += pitch_torque.dot(scooter.angular_velocity) * delta


## Direction of the legs: the scooter's roll, but vertical in pitch.
static func leg_axis(scooter: RigidBody3D) -> Vector3:
	var right := scooter.global_basis.x
	var axis := Vector3.UP - right * Vector3.UP.dot(right)
	return axis.normalized() if axis.length_squared() > 1e-4 else scooter.global_basis.y


## Puts the rider standing on the deck, at rest.
func place_on(scooter: RigidBody3D, tuning: ScooterTuning) -> void:
	var feet := feet_point(scooter, tuning)
	# Standing length: muscles carry the weight, so there's no sag to add.
	global_transform = Transform3D(Basis(), feet + leg_axis(scooter) * tuning.stand_leg_length())
	linear_velocity = scooter.linear_velocity
	angular_velocity = Vector3.ZERO
	bailed = false
	reset_physics_interpolation()
