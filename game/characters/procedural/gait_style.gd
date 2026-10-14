@tool
class_name AtlasGaitStyle
extends RefCounted
## Zuivere richtingskeuze in motorruimte; kent geen IK, input of wereldcontacten.
static func side_amount(local_velocity: Vector3) -> float:
	var horizontal := Vector2(local_velocity.x, local_velocity.z)
	if horizontal.length_squared() < 0.01:
		return 0.0
	# Volledig zijwaarts binnen 20 graden; tussen 20 en 30 graden vloeiend mengen.
	return smoothstep(cos(deg_to_rad(30.0)), cos(deg_to_rad(20.0)), absf(horizontal.normalized().x))

static func diagonal_yaw(local_velocity: Vector3, motion_profile: String) -> float:
	if motion_profile not in ["jog", "run", "walk"] or Vector2(local_velocity.x, local_velocity.z).length_squared() < 0.01:
		return 0.0
	# De nabijste lengte-as geldt ook achterwaarts: nooit een nekdraai van 135 graden.
	var yaw := atan2(-local_velocity.x, -local_velocity.z)
	if yaw > PI * 0.5:
		yaw -= PI
	elif yaw < -PI * 0.5:
		yaw += PI
	return yaw * (1.0 - side_amount(local_velocity))
