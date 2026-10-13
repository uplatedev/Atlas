@tool
class_name AtlasTurnStepPlanner
extends RefCounted
## Eén visuele bijstap tegelijk; een comfortabele scheve stand hoeft niet recht.
const MAX_PAIR_ANGLE := PI * 0.375
const STEP_TIME := 0.22
var step_duration: float = STEP_TIME
var fast_step_duration: float = 0.14
var speed_adaptation: float = 1.0
var filtered_yaw_speed: float = 0.0
var active_step_duration: float = STEP_TIME
var max_pair_angle: float = MAX_PAIR_ANGLE
var initialized: bool = false
var enabled: bool = false
var pose_yaw: float = 0.0
var foot_yaws: Array[float] = [0.0, 0.0]
var active_side: int = -1
var landed_side: int = -1
var started_side: int = -1
var phase: float = 0.0
var step_index: int = 0
var _next_side: int = 0
var _force_next: bool = false
var _replant_point: Variant = null
var _from_yaw: float = 0.0
var _target_yaw: float = 0.0
var _from: Vector3 = Vector3.ZERO
var _target: Vector3 = Vector3.ZERO
var _origin: Vector3 = Vector3.ZERO
var _previous_desired_yaw: float = 0.0

func reset(yaw: float) -> void:
	initialized = true
	enabled = false
	pose_yaw = yaw
	_previous_desired_yaw = yaw
	filtered_yaw_speed = 0.0
	active_step_duration = clampf(step_duration, 0.08, 0.4)
	foot_yaws = [yaw, yaw]
	active_side = -1
	landed_side = -1
	started_side = -1
	phase = 0.0
	step_index = 0
	_next_side = 0
	_force_next = false
	_replant_point = null

func request_replant(side: int, point: Variant = null) -> void:
	_next_side = side
	_force_next = true
	_replant_point = point

func advance(delta: float, desired_yaw: float, allowed: bool, origin: Vector3, rest: Array[Vector3], contacts: Array[Vector3], allow_turn_start: bool = true) -> void:
	if not initialized:
		reset(desired_yaw)
	started_side = -1
	landed_side = -1
	enabled = allowed
	var previous_motor := _previous_desired_yaw
	_previous_desired_yaw = desired_yaw
	var measured_speed := minf(absf(wrapf(desired_yaw - previous_motor, -PI, PI)) / maxf(delta, 0.000001), TAU * 2.0)
	filtered_yaw_speed = lerpf(filtered_yaw_speed, measured_speed, 1.0 - exp(-maxf(delta, 0.0) / 0.08)) if allowed else 0.0
	if not allowed:
		active_side = -1
		_force_next = false
		_replant_point = null
		# Bij lopen/lucht verdwijnt alleen de visuele vertraging, begrensd en soepel.
		pose_yaw = wrapf(desired_yaw + wrapf(pose_yaw - previous_motor, -PI, PI) * exp(-delta * 24.0), -PI, PI)
		foot_yaws = [pose_yaw, pose_yaw]
		return
	if active_side >= 0:
		phase = minf(1.0, phase + delta / active_step_duration)
		foot_yaws[active_side] = wrapf(lerp_angle(_from_yaw, _target_yaw, smoothstep(0.0, 1.0, phase)), -PI, PI)
		pose_yaw = wrapf(lerp_angle(foot_yaws[0], foot_yaws[1], 0.5), -PI, PI)
		if phase >= 1.0:
			landed_side = active_side
			active_side = -1
			step_index += 1
			_next_side = 1 - landed_side
		return
	var error := wrapf(desired_yaw - pose_yaw, -PI, PI)
	# Geen uitlijn-latch: na elk contact opnieuw kiezen. Deze dode zone bewaart
	# de borstreserve en een comfortabele asymmetrische stand bij kleine blikjes.
	if not _force_next and (not allow_turn_start or absf(error) < max_pair_angle * 0.38):
		return
	var side := _next_side
	if not _force_next:
		# Bij plots omkijken kan de geplande vrije voet al voorop staan in de
		# nieuwe richting. Neem dan de achterblijvende voet, zonder kruispasje.
		if wrapf(foot_yaws[side] - foot_yaws[1-side], -PI, PI) * signf(error) > 0.01:
			side = 1 - side
	active_side = side
	started_side = side
	# Eén vaste duur per vrije stap; een snelle blik verandert geen lopende fase.
	active_step_duration = _duration_for_turn(error, _force_next)
	phase = 0.0
	_origin = origin
	_from = contacts[side]
	_from_yaw = foot_yaws[side]
	var planted_yaw := foot_yaws[1-side]
	if _force_next:
		# Veilig landen/herplaatsen geeft nooit stilzwijgend toestemming tot draaien.
		_target_yaw = _from_yaw
		_target = _replant_point if _replant_point is Vector3 else origin + Basis(Vector3.UP, pose_yaw) * Vector3(rest[side].x, 0.0, 0.0)
	else:
		# Het bekken is het midden van beide voetrichtingen: één vrije voet
		# haalt daarom tweemaal de gewenste bekkenhoek in, met een echte stapmaat.
		var advance_angle := maxf(absf(error) * 2.0, max_pair_angle * 0.9)
		var wished_pair := wrapf(_from_yaw - planted_yaw, -PI, PI) + signf(error) * advance_angle
		_target_yaw = planted_yaw + clampf(wished_pair, -max_pair_angle, max_pair_angle)
		_target = origin + Basis(Vector3.UP, _target_yaw) * Vector3(rest[side].x, 0.0, 0.0)
	_target.y = contacts[side].y
	_force_next = false
	_replant_point = null

func _duration_for_turn(error: float, replant: bool) -> float:
	var ordinary := clampf(step_duration, 0.08, 0.4)
	if replant:
		return ordinary
	var fast := clampf(fast_step_duration, 0.08, ordinary)
	# Een grote achterstand mag ook na het stoppen van de blik worden ingehaald.
	# Kleine rustige blikjes houden de oude duur en de bestaande borstreserve.
	var catchup_speed := maxf(filtered_yaw_speed, absf(error) / 0.5)
	var speed_mix := smoothstep(deg_to_rad(90.0), deg_to_rad(360.0), catchup_speed)
	var angle_mix := smoothstep(max_pair_angle * 0.38, max_pair_angle * 0.85, absf(error))
	return lerpf(ordinary, fast, speed_mix * angle_mix * clampf(speed_adaptation, 0.0, 1.0))


func destination() -> Vector3:
	return _target

func place_destination(point: Vector3) -> void:
	_target = point

func swing_position(height: float) -> Vector3:
	var weight := smoothstep(0.0, 1.0, phase)
	var point := _from.lerp(_target, weight)
	# Draai om de capsule in plaats van via het midden door het andere been.
	var radius_from := Vector2(_from.x - _origin.x, _from.z - _origin.z).length()
	var radius_to := Vector2(_target.x - _origin.x, _target.z - _origin.z).length()
	var from_angle := atan2(-(_from.z - _origin.z), _from.x - _origin.x)
	var to_angle := atan2(-(_target.z - _origin.z), _target.x - _origin.x)
	var angle := lerp_angle(from_angle, to_angle, weight)
	var radius := lerpf(radius_from, radius_to, weight)
	point.x = _origin.x + cos(angle) * radius
	point.z = _origin.z - sin(angle) * radius
	point.y += sin(phase * PI) * height
	return point

func reject_step() -> void:
	active_side = -1
	started_side = -1
