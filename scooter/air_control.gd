class_name AirControl
extends RefCounted
## Everything that happens between leaving the ground and landing:
## - Air control (left stick): pitch the nose down/up, spin left/right.
##   With the stick centred the rider holds the scooter's pitch (hands on
##   the bars), and whatever spin you took off with carries on.
## - The rider keeps the scooter level in roll.
## - Landing assist: shortly before touchdown, if you're already close, the
##   scooter is rotated to meet the landing surface (skate.'s hidden
##   helper). Landing fakie counts as lined up.
## - Grading the landing: clean, sketchy or bail, from the tilt against the
##   ground and how sideways the scooter is to its direction of travel.
##
## All rotations act on the scooter body; the rider's upper body doesn't
## rotate (Rider), and follows through the hips and legs.

enum Landing { NONE, CLEAN, SKETCHY, BAIL }

## Seconds both wheels have been off the ground.
var air_time := 0.0
## Airborne long enough to count (short hops over bumps don't).
var airborne := false
## Seconds until the predicted touchdown, or INF if none is predicted.
var time_to_landing := INF
var assist_active := false
var last_landing := Landing.NONE
## At the last touchdown: tilt against the ground and sideways angle, rad.
var last_tilt := 0.0
var last_sideways := 0.0

var _landing_normal := Vector3.UP
var _have_prediction := false
var _last_torque := Vector3.ZERO
var _last_omega := Vector3.ZERO


## One tick. Returns the grade of a landing that just happened, or NONE.
func update(scooter: Scooter, tuning: ScooterTuning, intent: RiderIntent, delta: float) -> Landing:
	# Finish last tick's torque work with the step's average angular velocity.
	scooter.air_work += 0.5 * _last_torque.dot(scooter.angular_velocity - _last_omega) * delta
	_last_torque = Vector3.ZERO
	if scooter.is_grounded():
		var landed := Landing.NONE
		if airborne:
			landed = _grade(scooter, tuning)
			last_landing = landed
		air_time = 0.0
		airborne = false
		_have_prediction = false
		time_to_landing = INF
		assist_active = false
		return landed

	# Air control starts the moment both wheels leave (a scooter leaving a
	# vert lip still pitching would otherwise rotate past vertical first).
	# Only airtime past airborne_min_time counts as a jump to be graded.
	air_time += delta
	airborne = air_time >= tuning.airborne_min_time
	_predict_landing(scooter, tuning)
	var inertia := scooter.get_inverse_inertia_tensor().inverse()
	var omega := scooter.angular_velocity
	var right := scooter.global_basis.x
	var target_omega := omega

	# Air control. Pitch is always held or driven (hands on the bars);
	# spin only changes while the stick asks for it.
	var strength := tuning.air_control_strength
	var pitch_rate := -intent.lean.y * deg_to_rad(tuning.air_pitch_rate_deg) * strength
	target_omega += right * (pitch_rate - omega.dot(right))
	if absf(intent.lean.x) > 0.1:
		var spin_rate := -intent.lean.x * deg_to_rad(tuning.air_spin_rate_deg) * strength
		target_omega += Vector3.UP * (spin_rate - omega.dot(Vector3.UP))

	# Keep the scooter level in roll (relative to the direction of travel).
	var forward := -scooter.global_basis.z
	var roll := asin(clampf(-scooter.global_basis.x.y, -1.0, 1.0))
	target_omega += forward * (-roll * tuning.air_level_rate - omega.dot(forward)) * tuning.air_level_strength

	# Landing assist overrides, in the last moments, when close enough.
	assist_active = false
	if time_to_landing <= tuning.landing_assist_window and tuning.landing_assist_strength > 0.0:
		var correction := _alignment_error(scooter)
		if correction.length() <= deg_to_rad(tuning.landing_assist_max_deg):
			assist_active = true
			var wanted := correction / maxf(time_to_landing, 0.05)
			target_omega = target_omega.lerp(wanted, tuning.landing_assist_strength)

	# Torque to reach the target rotation rate over a short response time.
	var torque := inertia * (target_omega - omega) / tuning.air_control_response
	var limit := tuning.air_max_torque
	if torque.length() > limit:
		torque = torque.normalized() * limit
	scooter.add_tracked_torque(torque)
	scooter.air_work += torque.dot(omega) * delta
	_last_torque = torque
	_last_omega = omega
	return Landing.NONE


## Follows the ballistic path for up to a second and ray-casts it in short
## segments to find where and when the scooter will touch down.
func _predict_landing(scooter: Scooter, tuning: ScooterTuning) -> void:
	time_to_landing = INF
	var space := scooter.get_world_3d().direct_space_state
	# Start just above the deck: the scooter's origin is at wheel-contact
	# level, which can sit on or inside a surface it just left.
	var p := scooter.global_position + scooter.global_basis.y * 0.15
	var v := (scooter.linear_velocity * scooter.mass + scooter.rider.linear_velocity * scooter.rider.mass) \
			/ (scooter.mass + scooter.rider.mass)
	var g := Vector3.DOWN * Scooter.GRAVITY
	var step := 0.05
	var t := 0.0
	while t < 1.0:
		var next := p + v * step + 0.5 * g * step * step
		var query := PhysicsRayQueryParameters3D.create(p, next, PropMaterials.LAYER_WORLD,
				[scooter.get_rid(), scooter.rider.get_rid()])
		var hit := space.intersect_ray(query)
		# Ignore surfaces facing away from the motion (hit from behind).
		if not hit.is_empty() and (hit["normal"] as Vector3).dot(next - p) < 0.0:
			var fraction := p.distance_to(hit["position"]) / maxf(p.distance_to(next), 1e-4)
			time_to_landing = t + step * fraction
			_landing_normal = hit["normal"]
			_have_prediction = true
			return
		p = next
		v += g * step
		t += step


## Rotation (axis × angle) that would line the scooter up with the landing:
## up along the surface normal, and the deck along the direction of travel
## on that surface (forward or fakie, whichever is closer).
func _alignment_error(scooter: Scooter) -> Vector3:
	var normal := _landing_normal
	var v := scooter.linear_velocity
	var along := v - normal * v.dot(normal)
	var forward := -scooter.global_basis.z
	if along.length_squared() < 0.01:
		along = forward - normal * forward.dot(normal)
	along = along.normalized()
	if along.dot(forward) < 0.0:
		along = -along # land fakie
	var target := Basis(normal.cross(-along).normalized(), normal, -along).orthonormalized()
	var q := Quaternion(target * scooter.global_basis.inverse())
	var angle := q.get_angle()
	if angle > PI:
		angle -= TAU
	return q.get_axis() * angle if absf(angle) > 1e-4 else Vector3.ZERO


## Graded against whichever surface the scooter is best lined up with:
## the one the landing prediction aimed for, or what the wheels actually
## touch. Either alone misleads sometimes: a wheel touching coping or an
## edge first has a normal pointing almost anywhere, and a prediction ray
## skimming past a ramp wall can "see" the flat ground beyond it.
func _grade(scooter: Scooter, tuning: ScooterTuning) -> Landing:
	var contact := Vector3.ZERO
	for wheel in [scooter.front_wheel, scooter.rear_wheel]:
		if wheel.in_contact:
			contact += wheel.contact_normal
	contact = contact.normalized() if contact != Vector3.ZERO else Vector3.UP
	var normal := contact
	if _have_prediction and scooter.global_basis.y.angle_to(_landing_normal) < scooter.global_basis.y.angle_to(contact):
		normal = _landing_normal
	var up := scooter.global_basis.y
	last_tilt = up.angle_to(normal)
	# Sideways: along the surface actually touched.
	var v := scooter.linear_velocity - contact * scooter.linear_velocity.dot(contact)
	var forward := -scooter.global_basis.z
	forward -= contact * forward.dot(contact)
	last_sideways = 0.0
	# Only meaningful when sliding along the surface: landing mostly into it
	# (e.g. back onto a wall after stalling at the top), the direction of
	# travel along it is noise.
	if v.length() > 1.5 and forward.length_squared() > 1e-4:
		var angle := forward.angle_to(v)
		last_sideways = minf(angle, PI - angle) # fakie is fine
	var tilt_deg := rad_to_deg(last_tilt)
	var side_deg := rad_to_deg(last_sideways)
	if tilt_deg > tuning.landing_sketchy_deg or side_deg > tuning.landing_sideways_sketchy_deg:
		return Landing.BAIL
	if tilt_deg > tuning.landing_clean_deg or side_deg > tuning.landing_sideways_clean_deg:
		return Landing.SKETCHY
	return Landing.CLEAN


static func landing_name(landing: Landing) -> String:
	return ["none", "CLEAN", "sketchy", "BAIL"][landing]
