class_name InputTuning
extends Resource
## How raw gamepad values are shaped into rider intent.
## Every @export_range here shows up as a slider in the tuning panel.

@export_group("Sticks")
## Radius below which a stick reads as zero. Compensates for worn sticks.
@export_range(0.0, 0.5, 0.01) var stick_deadzone: float = 0.12
## Radius above which a stick reads as fully deflected.
@export_range(0.5, 1.0, 0.01) var stick_outer_deadzone: float = 0.95
## Response curve exponent: 1 = linear, >1 = finer control near the centre.
@export_range(0.5, 3.0, 0.05) var stick_curve: float = 1.5

@export_group("Triggers")
@export_range(0.0, 0.5, 0.01) var trigger_deadzone: float = 0.05
@export_range(0.5, 3.0, 0.05) var trigger_curve: float = 1.0


## Radial deadzone + response curve. Keeps direction, reshapes magnitude.
func shape_stick(raw: Vector2) -> Vector2:
	var length := raw.length()
	if length <= stick_deadzone:
		return Vector2.ZERO
	var t := clampf(inverse_lerp(stick_deadzone, stick_outer_deadzone, length), 0.0, 1.0)
	return raw / length * pow(t, stick_curve)


func shape_trigger(raw: float) -> float:
	if raw <= trigger_deadzone:
		return 0.0
	return pow(clampf(inverse_lerp(trigger_deadzone, 1.0, raw), 0.0, 1.0), trigger_curve)
