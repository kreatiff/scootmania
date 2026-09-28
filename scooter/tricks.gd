class_name Tricks
extends RefCounted
## Air tricks, skate.-style: a right-stick flick in the air starts a trick,
## which then plays by itself along a fixed curve. The physics body doesn't
## rotate; only the scooter's visuals do. The skill is in the pop and the
## timing: land before the trick has (nearly) finished and you bail.
##
## - Flick left / right: tailwhip. The deck whips around the headtube
##   while the rider holds the bars.
## - Flick up / down: barspin. The bars, stem and front wheel spin around
##   the headtube while the deck stays under the feet.
## Tricks chain: once one finishes, another flick starts the next.

enum Trick { NONE, BARSPIN, TAILWHIP }

## Trick playing now, and its direction (+1 or -1).
var active := Trick.NONE
var direction := 1.0
## 0..1 through the active trick.
var progress := 0.0
## Current visual angles about the headtube, radians.
var bars_angle := 0.0
var deck_angle := 0.0
## Tricks finished in this air, in order.
var done: Array[Trick] = []
## The last flick seen (for the debug HUD): Vector2 direction, and age.
var last_flick := Vector2.ZERO
var last_flick_age := INF
## Result of the last air, for feedback: e.g. "TAILWHIP + BARSPIN" or
## "BARSPIN — too early". Empty when nothing happened.
var last_result := ""
var last_landed := false
## True on the tick an air's tricks were settled (landed or not).
var just_resolved := false

## Seconds into the current manual (0 = not in one), and which kind.
var manual_time := 0.0
var nose_manual := false

var _flick := FlickDetector.new()
var _manual_off := 0.0


## One tick. Returns true when the ground cut a trick short (a bail).
func update(scooter: Scooter, tuning: ScooterTuning, intent: RiderIntent, delta: float) -> bool:
	just_resolved = false
	var flick := _flick.update(intent.pose, tuning, delta)
	last_flick_age += delta
	if flick != Vector2.ZERO:
		last_flick = flick
		last_flick_age = 0.0
	var airborne := not scooter.is_grounded() and not scooter.rider.bailed
	_update_manual(scooter, tuning, delta)

	if airborne and active == Trick.NONE and flick != Vector2.ZERO:
		_start(flick)
	if active != Trick.NONE:
		progress += delta / _duration(active, tuning)
		if progress >= 1.0:
			done.append(active)
			active = Trick.NONE
			progress = 0.0
	_update_angles()

	if airborne or (active == Trick.NONE and done.is_empty()):
		return false
	# Back on the ground (or bailed) with tricks to settle.
	var cut_short := false
	if active != Trick.NONE:
		var left := (1.0 - _eased(progress)) * TAU # as it looks
		if left > deg_to_rad(tuning.trick_grace_deg) or scooter.rider.bailed:
			cut_short = true
			last_result = "%s — too early" % trick_name(active)
			last_landed = false
		else:
			done.append(active) # close enough: it snaps round
	if not cut_short:
		last_result = " + ".join(done.map(trick_name))
		last_landed = true
	active = Trick.NONE
	progress = 0.0
	done.clear()
	_update_angles()
	just_resolved = true
	return cut_short


## The tricks were finished, but the landing itself was a bail.
func fail_landing() -> void:
	if just_resolved and last_landed:
		last_landed = false
		last_result += " — bailed"


## A manual: rolling on one wheel, deck tipped past manual_min_deg to
## start. Ends a moment after it stops being on one wheel (both down, or
## off the ground), or at once on a bail.
func _update_manual(scooter: Scooter, tuning: ScooterTuning, delta: float) -> void:
	var pitch := scooter.rider.manual_pitch # 0 unless exactly one wheel is down
	var threshold := 0.0 if manual_time > 0.0 else deg_to_rad(tuning.manual_min_deg)
	var on_one := pitch != 0.0 and absf(pitch) > threshold \
			and scooter.linear_velocity.length() > 0.5 and not scooter.rider.bailed
	if on_one:
		if manual_time == 0.0:
			nose_manual = pitch < 0.0
		manual_time += delta
		_manual_off = 0.0
		return
	if manual_time == 0.0:
		return
	# A wheel brushing the ground, or the other skipping off it for a tick,
	# doesn't end it.
	var both_down := scooter.front_wheel.in_contact and scooter.rear_wheel.in_contact
	if not scooter.rider.bailed:
		_manual_off += delta
		if _manual_off < 0.1:
			return
	var kind := "NOSE MANUAL" if nose_manual else "MANUAL"
	if manual_time >= tuning.manual_min_time:
		just_resolved = true
		last_landed = both_down and not scooter.rider.bailed
		last_result = "%s %.1f s" % [kind, manual_time]
		if scooter.rider.bailed:
			last_result += " — looped out" if not nose_manual else " — over the bars"
	manual_time = 0.0
	_manual_off = 0.0


## Cancels everything (on a bail landing or a reset). Keeps last_result.
func clear() -> void:
	manual_time = 0.0
	_manual_off = 0.0
	active = Trick.NONE
	progress = 0.0
	done.clear()
	_update_angles()


## Visual rotation, in the scooter's frame, for the bars and front wheel
## (or the deck and rear wheel): about the headtube axis through `pivot`.
static func pivot_transform(angle: float, axis: Vector3, pivot: Vector3) -> Transform3D:
	var rotation := Basis(axis.normalized(), angle)
	return Transform3D(rotation, pivot - rotation * pivot)


## Share of the turn done at `t` of the time: quick start, smooth settle.
static func _eased(t: float) -> float:
	return 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 2.5)


static func trick_name(trick: Trick) -> String:
	return ["", "BARSPIN", "TAILWHIP"][trick]


func _start(flick: Vector2) -> void:
	if absf(flick.x) >= absf(flick.y):
		active = Trick.TAILWHIP
		direction = signf(flick.x)
	else:
		active = Trick.BARSPIN
		direction = signf(flick.y)
	progress = 0.0


func _duration(trick: Trick, tuning: ScooterTuning) -> float:
	return tuning.barspin_time if trick == Trick.BARSPIN else tuning.tailwhip_time


func _update_angles() -> void:
	var angle := 0.0
	if active != Trick.NONE:
		angle = _eased(progress) * TAU * direction
	bars_angle = angle if active == Trick.BARSPIN else 0.0
	deck_angle = angle if active == Trick.TAILWHIP else 0.0


## Recognises a flick: the right stick going from near the centre to near
## the edge within a short time. Holding it out doesn't repeat; it re-arms
## once the stick is back near the centre.
class FlickDetector:
	var _armed := true
	var _time_since_centre := 0.0

	## Returns the flick's direction (unit Vector2) on the tick it happens.
	func update(stick: Vector2, tuning: ScooterTuning, delta: float) -> Vector2:
		var r := stick.length()
		if r < tuning.flick_centre:
			_armed = true
			_time_since_centre = 0.0
			return Vector2.ZERO
		_time_since_centre += delta
		if _armed and r >= tuning.flick_edge:
			_armed = false
			if _time_since_centre <= tuning.flick_max_time:
				return stick / r
		return Vector2.ZERO
