@tool
class_name AtlasTurnStepPlanner
extends RefCounted
## Eén visuele bijstap tegelijk; geen motorbeweging, collision of wachtrij.
const START_ANGLE := PI / 12.0
const MAX_PAIR_ANGLE := PI * 0.30
const STEP_TIME := 0.15
var step_duration: float = STEP_TIME
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
var _aligning: bool = false
var _force_next: bool = false
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
	foot_yaws = [yaw, yaw]
	active_side = -1
	landed_side = -1
	started_side = -1
	phase = 0.0
	step_index = 0
	_next_side = 0
	_aligning = false
	_force_next = false

func request_replant(side: int) -> void:
	_next_side = side
	_aligning = true
	_force_next = true

func advance(delta: float, desired_yaw: float, allowed: bool, origin: Vector3, rest: Array[Vector3], contacts: Array[Vector3]) -> void:
	if not initialized:
		reset(desired_yaw)
	started_side = -1
	landed_side = -1
	enabled = allowed
	var previous_motor := _previous_desired_yaw
	_previous_desired_yaw = desired_yaw
	if not allowed:
		active_side = -1
		_aligning = false
		# Bij lopen/lucht verdwijnt alleen de visuele vertraging, begrensd en soepel.
		pose_yaw = wrapf(desired_yaw + wrapf(pose_yaw - previous_motor, -PI, PI) * exp(-delta * 24.0), -PI, PI)
		foot_yaws = [pose_yaw, pose_yaw]
		return
	if active_side >= 0:
		phase = minf(1.0, phase + delta / clampf(step_duration, 0.08, 0.4))
		foot_yaws[active_side] = wrapf(lerp_angle(_from_yaw, _target_yaw, smoothstep(0.0, 1.0, phase)), -PI, PI)
		pose_yaw = wrapf(lerp_angle(foot_yaws[0], foot_yaws[1], 0.5), -PI, PI)
		if phase >= 1.0:
			landed_side = active_side
			active_side = -1
			step_index += 1
			_next_side = 1 - landed_side
		return
	var error := wrapf(desired_yaw - pose_yaw, -PI, PI)
	var position_errors: Array[float] = []
	for side in range(2):
		var destination := origin + Basis(Vector3.UP, desired_yaw) * Vector3(rest[side].x, 0.0, 0.0)
		position_errors.append(Vector2(destination.x - contacts[side].x, destination.z - contacts[side].z).length())
	if not _aligning and absf(error) < START_ANGLE and maxf(position_errors[0], position_errors[1]) < 0.075:
		return
	_aligning = true
	var side := _next_side
	if not _force_next and absf(wrapf(desired_yaw - foot_yaws[side], -PI, PI)) < 0.005 and position_errors[side] < 0.01:
		side = 1 - side
	if not _force_next and absf(wrapf(desired_yaw - foot_yaws[side], -PI, PI)) < 0.005 and position_errors[side] < 0.01:
		_aligning = false
		return
	_force_next = false
	active_side = side
	started_side = side
	phase = 0.0
	_origin = origin
	_from = contacts[side]
	_from_yaw = foot_yaws[side]
	var planted_yaw := foot_yaws[1 - side]
	_target_yaw = planted_yaw + clampf(wrapf(desired_yaw - planted_yaw, -PI, PI), -max_pair_angle, max_pair_angle)
	_target = origin + Basis(Vector3.UP, _target_yaw) * Vector3(rest[side].x, 0.0, 0.0)
	_target.y = contacts[side].y

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
	_aligning = false