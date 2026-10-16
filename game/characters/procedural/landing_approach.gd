@tool
class_name AtlasLandingApproach
extends RefCounted
## Een korte wereldvaste eindzwaai; werkelijk motorcontact blijft vereist.

var step: int = -1
var ground: Vector3 = Vector3.ZERO
var _from: Vector3 = Vector3.ZERO
var _velocity: Vector3 = Vector3.ZERO
var _duration: float = 0.0
var _elapsed: float = 0.0

func reset() -> void:
	step = -1

func begin(at_step: int, from: Vector3, velocity: Vector3, to_ground: Vector3, duration: float) -> void:
	step = at_step
	ground = to_ground
	_from = from
	_velocity = velocity
	_duration = maxf(duration, 0.001)
	_elapsed = 0.0

func advance(delta: float, ankle_height: float) -> Vector3:
	_elapsed = minf(_elapsed + delta, _duration)
	var t := _elapsed / _duration
	# Neem de bereikte wereldsnelheid over. De vijfdegraads baan eindigt met
	# snelheid én versnelling nul, zodat de vaste pin dezelfde eindtoestand heeft.
	var travel := t * t * t * (10.0 + t * (-15.0 + 6.0 * t))
	var tangent := t + t * t * t * (-6.0 + t * (8.0 - 3.0 * t))
	return _from.lerp(ground + Vector3.UP * ankle_height, travel) + _velocity * _duration * tangent
