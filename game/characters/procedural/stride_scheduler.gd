@tool
class_name AtlasStrideScheduler
extends RefCounted
## Kleine motorplanner. Alleen werkelijk contact beëindigt een pasvlucht.

var phase: float = 0.0
var step_index: int = 0
var takeoff_y: float = 0.0
var height: float = 0.0
var _support_only: bool = false
var _support_elapsed: float = 0.0
var _flight_elapsed: float = 0.0
var _flight_duration: float = 0.0


func reset() -> void:
	phase = 0.0
	step_index = 0
	cancel()


func cancel() -> void:
	_support_only = false
	_support_elapsed = 0.0
	_flight_elapsed = 0.0
	_flight_duration = 0.0
	height = 0.0
	phase = 0.0


func support_tick(delta: float, duration: float, moving: bool) -> bool:
	if not moving:
		_support_elapsed = 0.0
		phase = 0.0
		return false
	_support_elapsed += delta
	phase = (1.0 if _support_only else 0.5) * clampf(_support_elapsed / maxf(duration, delta), 0.0, 1.0)
	return _support_elapsed + 0.000001 >= duration


func take_off(at_y: float, flight_height: float, gravity: float) -> float:
	_support_only = false
	takeoff_y = at_y
	height = flight_height
	_support_elapsed = 0.0
	_flight_elapsed = 0.0
	var launch := sqrt(2.0 * gravity * height)
	_flight_duration = 2.0 * launch / gravity
	phase = 0.5
	return launch


func flight_tick(delta: float) -> void:
	_flight_elapsed += delta
	# Een voorspelde vliegtijd is geen bewijs van steun; wacht op echte collision.
	phase = minf(0.999, 0.5 + 0.5 * _flight_elapsed / maxf(_flight_duration, delta))


func touch_down() -> void:
	step_index += 1
	cancel()


func supported_step() -> void:
	touch_down()
	# Geen dubbele steuntijd onder een plafond: hetzelfde bereik, volle zwaaifase.
	_support_only = true
