@tool
class_name Kicker
extends ProfileProp
## A launch ramp: a curved transition that ends at the lip angle, with a
## vertical back. The radius follows from height and lip angle.

@export_range(0.1, 2.0, 0.05, "suffix:m") var height := 0.5:
	set(value):
		height = value
		queue_rebuild()
## Angle of the riding surface at the lip. Steeper launches more upward.
@export_range(10.0, 60.0, 1.0, "suffix:°") var lip_angle_deg := 33.0:
	set(value):
		lip_angle_deg = value
		queue_rebuild()
@export_range(4, 64, 1) var segments := 24:
	set(value):
		segments = value
		queue_rebuild()


func radius() -> float:
	return height / (1.0 - cos(deg_to_rad(lip_angle_deg)))


func _profile() -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2.ZERO])
	var r := radius()
	var theta_max := deg_to_rad(lip_angle_deg)
	for k in range(1, segments + 1):
		var theta := theta_max * k / segments
		pts.append(Vector2(-r * sin(theta), r * (1.0 - cos(theta))))
	pts.append(Vector2(pts[pts.size() - 1].x, 0.0))
	return pts
