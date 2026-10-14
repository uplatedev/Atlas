@tool
class_name AtlasFootPhase
extends RefCounted
## Contactvolgorde afgeleid van de motorfase; bezit geen klok of wereldqueries.
var contact: Array[bool] = [false, false]
var swing: Array[float] = [0.0, 0.0]
var support_age: Array[float] = [0.0, 0.0]
var uniform_phase: float = 0.0
var support_seconds: float = 0.1
var supported_cycle: bool = false
var overlap: float = 0.18
var _uniform_step: int = -2147483648
var _uniform_fraction: float = 0.5
var _uniform_supported: bool = false
var _last_motor_phase: float = 0.0
var _uniform_origin: float = 0.0
var _motor_origin: float = 0.0

func sample(frame: Variant, walking: bool, double_support: float = 0.18) -> void:
	var phase: float = clampf(frame.gait_phase, 0.0, 1.0)
	var fraction_value: Variant = frame.get("support_fraction")
	var fraction: float = clampf(float(fraction_value), 0.01, 1.0) if fraction_value != null else 0.5
	var duration_value: Variant = frame.get("step_duration")
	var duration: float = maxf(float(duration_value), 0.001) if duration_value != null else 0.3
	var supported_value: Variant = frame.get("gait_supported_cycle")
	supported_cycle = bool(supported_value) if supported_value != null else walking
	overlap = clampf(double_support, 0.0, 0.35)
	support_seconds = duration if supported_cycle else duration * fraction
	# Pose-tijd houdt de verhouding van deze motorstap. Actuele timing blijft
	# beschikbaar voor bereik/contact, maar verandert een afgelegde armzwaai niet.
	var current_supported := supported_cycle or fraction >= 0.999
	if frame.step_index != _uniform_step or (phase < _last_motor_phase - 0.00001 and current_supported == _uniform_supported):
		_uniform_step = frame.step_index
		_uniform_fraction = fraction
		_uniform_supported = current_supported
		_uniform_origin = 0.0
		_motor_origin = 0.0
	elif current_supported != _uniform_supported:
		# De motor geeft dezelfde steunvoortgang na deze overgang op een volle
		# in plaats van halve schaal. Draag de bereikte pose over op die schaal.
		var previous_progress := _last_motor_phase * (2.0 if current_supported else 0.5)
		_uniform_supported = current_supported
		_uniform_fraction = fraction
		_uniform_origin = uniform_phase
		_motor_origin = _map_uniform(previous_progress)
	_last_motor_phase = phase
	var mapped := _map_uniform(phase)
	uniform_phase = lerpf(_uniform_origin, 1.0, clampf((mapped - _motor_origin) / maxf(1.0 - _motor_origin, 0.001), 0.0, 1.0))
	var stance: int = posmod(frame.step_index, 2)
	for side in range(2):
		contact[side] = false
		support_age[side] = 0.0
		swing[side] = uniform_phase if side != stance else clampf((phase - 0.5) * 2.0, 0.0, 1.0)
	if walking and supported_cycle:
		contact[stance] = frame.supported
		contact[1-stance] = frame.supported and phase < overlap
		support_age[stance] = phase / (1.0 + overlap)
		support_age[1-stance] = clampf((1.0 + phase) / (1.0 + overlap), 0.0, 1.0)
		swing[1-stance] = clampf((phase - overlap) / maxf(1.0 - overlap, 0.001), 0.0, 1.0)
	else:
		contact[stance] = frame.supported
		support_age[stance] = phase if supported_cycle else phase * 2.0

func roll(side: int, heel_degrees: float, toe_degrees: float) -> float:
	var age := support_age[side]
	return deg_to_rad(heel_degrees) * (1.0 - smoothstep(0.0, 0.22, age)) - deg_to_rad(toe_degrees) * smoothstep(0.62, 1.0, age)

func _map_uniform(phase: float) -> float:
	return phase if _uniform_supported else (phase * 2.0 * _uniform_fraction if phase < 0.5 else _uniform_fraction + (phase - 0.5) * 2.0 * (1.0 - _uniform_fraction))
