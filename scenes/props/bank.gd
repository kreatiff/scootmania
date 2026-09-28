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
## Radius of the rounded edge from the slope onto the deck. A sharp edge
## catches the scooter's deck between the wheels (a "hang-up"). 0 = sharp.
@export_range(0.0, 2.0, 0.05, "suffix:m") var top_radius := 0.4:
	set(value):
		top_radius = value
		queue_rebuild()
@export_range(2, 32, 1) var segments := 12:
	set(value):
		segments = value
		queue_rebuild()


func _profile() -> PackedVector2Array:
	var theta := deg_to_rad(angle_deg)
	# Keep the bottom curve below the deck.
	var r := minf(transition_radius, height * 0.9 / (1.0 - cos(theta)))
	var pts := PackedVector2Array([Vector2.ZERO])
	if r > 0.0:
		for k in range(1, segments + 1):
			var a := theta * k / segments
			pts.append(Vector2(-r * sin(a), r * (1.0 - cos(a))))
	var curve_end := pts[pts.size() - 1]
	# Where the slope would meet the deck if the edge were sharp.
	var corner_z := curve_end.x - (height - curve_end.y) / tan(theta)
	# Rounded top edge: an arc tangent to the slope and to the deck.
	var tangent_len := minf(top_radius * tan(theta * 0.5), deck_length * 0.5)
	var rt := tangent_len / tan(theta * 0.5) if theta > 0.0 else 0.0
	if rt > 0.0:
		var center := Vector2(corner_z - tangent_len, height - rt)
		for k in range(segments, -1, -1):
			var a := theta * k / segments
			pts.append(center + Vector2(rt * sin(a), rt * cos(a)))
	else:
		pts.append(Vector2(corner_z, height))
	pts.append(Vector2(corner_z - deck_length, height))
	pts.append(Vector2(corner_z - deck_length, 0.0))
	return pts


## Horizontal distance from the start of the bottom curve to where the
## slope meets the deck (the corner, if the top edge were sharp).
func slope_length() -> float:
	var theta := deg_to_rad(angle_deg)
	var r := minf(transition_radius, height * 0.9 / (1.0 - cos(theta)))
	var curve_end := Vector2(-r * sin(theta), r * (1.0 - cos(theta)))
	return -(curve_end.x - (height - curve_end.y) / tan(theta))
