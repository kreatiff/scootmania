@tool
class_name Bank
extends ProfileProp
## A flat, straight slope up to a deck. Good for testing rolling on an
## incline: speed gain, and coasting uphill to a stop.

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


func _profile() -> PackedVector2Array:
	var slope_length := height / tan(deg_to_rad(angle_deg))
	return PackedVector2Array([
		Vector2.ZERO,
		Vector2(-slope_length, height),
		Vector2(-slope_length - deck_length, height),
		Vector2(-slope_length - deck_length, 0.0),
	])
