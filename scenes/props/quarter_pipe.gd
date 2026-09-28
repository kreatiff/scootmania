@tool
class_name QuarterPipe
extends ProfileProp
## A circular transition up to a flat deck, with round steel coping on the lip.
## Defaults are a common skatepark size: 1.2 m (4 ft) tall on a 1.8 m (6 ft)
## radius. Height equal to radius makes the lip exactly vertical.

@export_range(0.3, 4.0, 0.05, "suffix:m") var height := 1.2:
	set(value):
		height = value
		queue_rebuild()
## Treated as at least `height` (a lip can't go past vertical).
@export_range(0.5, 6.0, 0.05, "suffix:m") var radius := 1.8:
	set(value):
		radius = value
		queue_rebuild()
@export_range(0.3, 4.0, 0.05, "suffix:m") var deck_length := 1.2:
	set(value):
		deck_length = value
		queue_rebuild()
## Facets in the curve. More is smoother for the wheels, at a small cost.
@export_range(4, 64, 1) var segments := 32:
	set(value):
		segments = value
		queue_rebuild()
@export var coping := true:
	set(value):
		coping = value
		queue_rebuild()
@export_range(0.03, 0.1, 0.005, "suffix:m") var coping_diameter := 0.06:
	set(value):
		coping_diameter = value
		queue_rebuild()


func effective_radius() -> float:
	return maxf(radius, height)


func lip_angle() -> float:
	return acos(1.0 - height / effective_radius())


func lip() -> Vector2:
	return Vector2(-effective_radius() * sin(lip_angle()), height)


func _profile() -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2.ZERO])
	var r := effective_radius()
	var theta_max := lip_angle()
	for k in range(1, segments + 1):
		var theta := theta_max * k / segments
		pts.append(Vector2(-r * sin(theta), r * (1.0 - cos(theta))))
	var lip_z := lip().x
	pts.append(Vector2(lip_z - deck_length, height))
	pts.append(Vector2(lip_z - deck_length, 0.0))
	return pts


func _steel_edges() -> Array[Dictionary]:
	if not coping:
		return []
	# Coping sits slightly proud of the deck and sticks out past the face,
	# as on a real ramp, so wheels and pegs meet steel first at the lip.
	var r := coping_diameter * 0.5
	var at := lip() + Vector2(r * 0.5, -r * 0.6)
	return [{"at": at, "shape": "round", "size": coping_diameter}]
