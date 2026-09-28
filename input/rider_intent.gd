class_name RiderIntent
extends RefCounted
## What the rider wants to do this physics tick, independent of the device.
## Physics code reads only this, never the gamepad, so input can be replayed.

## Left stick. x: lean right (+) / left (-). y: weight forward (+) / back (-).
var lean := Vector2.ZERO
## Right stick. x: right (+) / left (-). y: extend/pop (+) / compress (-).
## Grounded it drives stance; airborne it's the trick flick (see plan §4).
var pose := Vector2.ZERO
## Rear brake, 0..1.
var brake := 0.0
## Held state of the kick button. Physics detects presses by edge.
var kick := false


func duplicate_intent() -> RiderIntent:
	var copy := RiderIntent.new()
	copy.lean = lean
	copy.pose = pose
	copy.brake = brake
	copy.kick = kick
	return copy


func to_array() -> PackedFloat64Array:
	return PackedFloat64Array([lean.x, lean.y, pose.x, pose.y, brake, 1.0 if kick else 0.0])


static func from_array(a: PackedFloat64Array) -> RiderIntent:
	var intent := RiderIntent.new()
	intent.lean = Vector2(a[0], a[1])
	intent.pose = Vector2(a[2], a[3])
	intent.brake = a[4]
	intent.kick = a[5] > 0.5
	return intent


func equals(other: RiderIntent) -> bool:
	return to_array() == other.to_array()
