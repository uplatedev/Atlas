@tool
class_name AtlasGaitStyle
extends RefCounted
## Richting uit werkelijke motorvaart; geen extra pasfase of contactstrategie.
static func lateral_amount(local_velocity: Vector3) -> float:
	var horizontal := Vector2(local_velocity.x, local_velocity.z)
	if horizontal.length_squared() < 0.01:
		return 0.0
	return smoothstep(0.35, 0.90, absf(horizontal.normalized().x))

static func movement_yaw(local_velocity: Vector3, maximum_degrees: float) -> float:
	if Vector2(local_velocity.x, local_velocity.z).length_squared() < 0.01:
		return 0.0
	# Achterdiagonalen blijven achterwaartse passen; geen draai van 135 graden.
	var yaw := atan2(-local_velocity.x, -local_velocity.z)
	if yaw > PI * 0.5:
		yaw -= PI
	elif yaw < -PI * 0.5:
		yaw += PI
	var limit := deg_to_rad(clampf(maximum_degrees, 0.0, 85.0))
	return clampf(yaw, -limit, limit)
