@tool
class_name AtlasStrideScheduler
extends RefCounted
## Kleine motorplanner. Alleen werkelijk contact beëindigt een pasvlucht.

var phase: float = 0.0
var step_index: int = 0
var takeoff_y: float = 0.0
var height: float = 0.0
var _support_only: bool = false
var _short_support: bool = true
var _support_direction: Vector2 = Vector2.ZERO
var _support_progress: float = 0.0
var _flight_elapsed: float = 0.0
var _flight_duration: float = 0.0


func reset() -> void:
	phase = 0.0
	step_index = 0
	cancel()


func cancel() -> void:
	_support_direction = Vector2.ZERO
	_short_support = true
	_support_only = false
	_support_progress = 0.0
	_flight_elapsed = 0.0
	_flight_duration = 0.0
	height = 0.0
	phase = 0.0


func support_tick(delta: float, duration: float, moving: bool, first_support_ratio: float = 1.0, horizontal_velocity: Vector2 = Vector2.ZERO) -> bool:
	if not moving:
		_support_direction = Vector2.ZERO
		_short_support = true
		_support_progress = 0.0
		phase = 0.0
		return false
	if _support_direction == Vector2.ZERO:
		_support_direction = horizontal_velocity.normalized()
	elif horizontal_velocity.dot(_support_direction) < -0.1:
		# Na omkeren ligt de bestaande steun nog aan de oude voorkant.
		# Kort alleen gewone WALK-steun in; de factor voor sprint blijft een.
		_short_support = true
	# Vanuit stilstand staat de eerste voet nog niet vooruit: een kortere gewone
	# steunfase voorkomt een onbereikbare achterblijvende pin. Sprint geeft ratio 1.
	if _short_support:
		duration *= clampf(first_support_ratio, 0.25, 1.0)
	# Snelheid verandert de verdere pascadans, niet de al afgelegde fase.
	# Verstreken tijd delen door een groeiende duur liet de voet achteruit zwaaien.
	_support_progress += maxf(delta, 0.0) / maxf(duration, maxf(delta, 0.000001))
	phase = (1.0 if _support_only else 0.5) * clampf(_support_progress, 0.0, 1.0)
	return _support_progress + 0.000001 >= 1.0


func take_off(at_y: float, flight_height: float, gravity: float) -> float:
	_short_support = false
	_support_only = false
	takeoff_y = at_y
	height = flight_height
	_support_progress = 0.0
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
	_short_support = false


func supported_step() -> void:
	touch_down()
	# Geen dubbele steuntijd onder een plafond: hetzelfde bereik, volle zwaaifase.
	_support_only = true
