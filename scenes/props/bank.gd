@tool
class_name Bank
extends ProfileProp
## A straight slope up to a deck, starting from a short curved transition
## (as built in real parks; a sharp kink at the bottom would hit the wheels
## like a curb). Good for testing rolling on an incline: speed gain, and
## coasting uphill to a stop.

@export_range(0.2, 3.0, 0.05, "suffix:m") var height := 1.0:
	set(value):
		height = value
		queue_rebuild()
@export_range(5.0, 45.0, 1.0, "suffix:°") var angle_deg := 20.0:
	set(value):
		angle_deg = value
		queue_rebuild()
@export_range(0.3, 4.0, 0.05, "suffix:m") var deck_length := 1.5:
	set(value):
		deck_length = value
		queue_rebuild()
## Radius of the curve from the ground into the slope. 0 = sharp kink.
@export_range(0.0, 4.0, 0.05, "suffix:m") var transition_radius := 1.5:
	set(value):
		transition_radius = value
		queue_rebuild()
@export_range(2, 32, 1) var segments := 12:
	set(value):
		segments = value
		queue_rebuild()


func _profile() -> PackedVector2Array:
	var theta := deg_to_rad(angle_deg)
	# Keep the curve below the deck.
	var r := minf(transition_radius, height * 0.9 / (1.0 - cos(theta)))
	var pts := PackedVector2Array([Vector2.ZERO])
	if r > 0.0:
		for k in range(1, segments + 1):
			var a := theta * k / segments
			pts.append(Vector2(-r * sin(a), r * (1.0 - cos(a))))
	var curve_end := pts[pts.size() - 1]
	var top_z := curve_end.x - (height - curve_end.y) / tan(theta)
	pts.append(Vector2(top_z, height))
	pts.append(Vector2(top_z - deck_length, height))
	pts.append(Vector2(top_z - deck_length, 0.0))
	return pts


## Horizontal length from the start of the curve to the top of the slope.
func slope_length() -> float:
	var pts := _profile()
	return -pts[pts.size() - 3].x
