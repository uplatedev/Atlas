@tool
class_name AtlasCharacterCamera
extends Node3D
## Camerarig van Character. Instellingen staan op de Character-root, zodat één
## Inspector-ingang voldoende blijft. Hoofd/kijkrichting is los van lichaamsyaw.

signal look_direction_changed(yaw: float, pitch: float)

var _character: Node3D
var _motion_source: Callable
var _motion: AtlasCharacterCameraMotion = AtlasCharacterCameraMotion.new()
var _property_names: Dictionary = {}
var _controlled: bool = false
var _look_yaw: float = 0.0
var _pitch: float = 0.0
var _requested_distance: float = 4.0
var _zoom_distance: float = 4.0
var _actual_distance: float = 4.0
var _eye_height: float = 1.62
var _feet_height: float = 0.0
var _follow_position: Vector3 = Vector3.ZERO
var _previous_follow_target: Vector3 = Vector3.ZERO
var _follow_lag: float = 0.0
var _previous_follow_velocity: Vector3 = Vector3.ZERO
var _inertia_offset: Vector3 = Vector3.ZERO
var _inertia_velocity: Vector3 = Vector3.ZERO
var _inertia_reference_speed: float = 0.0
var _inertia_brake_time: float = 0.0
var _landing_seen_support: bool = false
var _landing_elapsed: float = 0.0
var _landing_start: float = 0.0
var _landing_peak: float = 0.0
var _landing_amount: float = 0.0
var _accent_offset: Vector3 = Vector3.ZERO
var _total_pose_offset: Vector3 = Vector3.ZERO
var _fov: float = 70.0
var _target_fov: float = 70.0
var _air_fov_mix: float = 0.0
var _air_walk_limit: float = 5.0
var _air_sprint_limit: float = 9.0
var _initialized: bool = false
var _camera_shape: SphereShape3D = SphereShape3D.new()

@onready var _arm: SpringArm3D = $SpringArm3D
@onready var _camera: Camera3D = $SpringArm3D/Camera3D


func _ready() -> void:
	process_priority = 100
	if not _initialized:
		initialize(get_parent() as Node3D)


func initialize(character: Node3D) -> void:
	_character = character
	_motion_source = Callable(character, "get_camera_motion_sample")
	if not _motion_source.is_valid():
		push_error("Character-camera vereist een fysieke motion sample van zijn eigenaar.")
		return
	_refresh_motion_sample()
	_property_names.clear()
	if is_instance_valid(_character):
		for entry in _character.get_property_list():
			_property_names[entry.name] = true
	if not is_node_ready():
		return
	_initialized = true
	if Engine.is_editor_hint():
		top_level = false
		position = Vector3(0.0, _value("camera_eye_height", 1.62), 0.0)
		rotation = Vector3(deg_to_rad(_value("camera_start_pitch", -12.0)), 0.0, 0.0)
		_arm.spring_length = _value("camera_start_distance", 4.0)
		_camera.fov = _value("camera_fov_third_person", 70.0)
		return
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if _motion.excluded_body.is_valid():
		_arm.add_excluded_object(_motion.excluded_body)
	# SpringArm schrijft normaal ieder physics-tick de globale cameratransform.
	# Onze renderchecks zijn de enige schrijver: geen tweede updatesnelheid.
	_arm.set_physics_process_internal(false)
	_arm.shape = _camera_shape
	reset_view(true)
	set_controlled(_controlled)


func _value(property_name: String, fallback: Variant) -> Variant:
	if is_instance_valid(_character) and _property_names.has(property_name):
		return _character.get(property_name)
	return fallback


func _refresh_motion_sample() -> void:
	if _motion_source.is_valid():
		_motion = _motion_source.call()


func set_controlled(value: bool) -> void:
	_controlled = value
	if not is_node_ready() or Engine.is_editor_hint():
		return
	if value:
		# Wisselen neemt de eigen bewaarde zoom/kijkhoek over, zonder oude positie-lag.
		reset_follow_history()
		_camera.make_current()
	else:
		_camera.clear_current(false)


func reset_follow_history() -> void:
	if not is_instance_valid(_character):
		return
	_refresh_motion_sample()
	_feet_height = _character.global_position.y
	_eye_height = _safe_eye_height()
	_follow_position = Vector3(_character.global_position.x, 0.0, _character.global_position.z)
	_previous_follow_target = _follow_position
	_follow_lag = 0.0
	_clear_inertia_history()
	_clear_landing_history(false)
	reset_physics_interpolation()
	_camera.reset_physics_interpolation()
	_refresh_transform(0.0, true)


func reset_view(reset_motion_history: bool = false) -> void:
	if not is_node_ready() or not is_instance_valid(_character):
		return
	_look_yaw = _body_yaw()
	_pitch = _clamp_pitch(deg_to_rad(_value("camera_start_pitch", -12.0)))
	if reset_motion_history:
		_air_fov_mix = 0.0
		_air_walk_limit = 5.0
		_air_sprint_limit = 9.0
		_clear_landing_history()
	set_distance(_value("camera_start_distance", 4.0))
	_zoom_distance = _requested_distance
	_actual_distance = _requested_distance
	_fov = _base_fov()
	reset_follow_history()


func set_distance(distance: float) -> void:
	_requested_distance = clampf(distance, 0.0, _value("camera_max_distance", 8.0))
	if _requested_distance <= _first_person_threshold():
		_requested_distance = 0.0
	if is_node_ready() and Engine.is_editor_hint():
		_arm.spring_length = _requested_distance


func _first_person_threshold() -> float:
	return minf(_value("first_person_threshold", 0.45), _value("camera_max_distance", 8.0) * 0.5)


func _unhandled_input(event: InputEvent) -> void:
	if not _controlled or Engine.is_editor_hint():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		apply_look_delta(event.screen_relative)
	elif event is InputEventMouseButton and event.pressed:
		var step: float = _value("camera_zoom_step", 0.5)
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_distance(_requested_distance - step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var distance := _requested_distance + step
			if _requested_distance == 0.0:
				distance = maxf(distance, _first_person_threshold() + step)
			set_distance(distance)


## Hetzelfde pad als muisinvoer, publiek voor herhaalbare hoofdgrensproeven.
func apply_look_delta(screen_pixels: Vector2) -> void:
	if not _initialized or not is_instance_valid(_character):
		return
	var old_sensitivity: float = _value("look_sensitivity", 0.12)
	var yaw_delta := deg_to_rad(-screen_pixels.x * float(_value("look_sensitivity_x", old_sensitivity)))
	var pitch_delta := deg_to_rad(-screen_pixels.y * float(_value("look_sensitivity_y", 0.10)))
	var body_yaw := _body_yaw()
	var relative_yaw := wrapf(_look_yaw - body_yaw, -PI, PI)
	var max_yaw := _max_head_yaw()
	relative_yaw = clampf(relative_yaw, -max_yaw, max_yaw)
	var soft_start := deg_to_rad(clampf(_value("head_soft_limit_start", 60.0), 0.0, rad_to_deg(max_yaw)))
	# Integreer zachte afremming analytisch: grote events kunnen de grens niet
	# overslaan. Omkeren reageert direct; afgewezen beweging wordt niet opgespaard.
	if not is_zero_approx(yaw_delta):
		var direction := signf(yaw_delta)
		var relative := relative_yaw * direction
		var remaining := absf(yaw_delta)
		if relative < soft_start:
			var direct := minf(remaining, soft_start - relative)
			relative += direct
			remaining -= direct
		if remaining > 0.0:
			var soft_range := max_yaw - soft_start
			if soft_range > 0.00001:
				relative = max_yaw - (max_yaw - relative) * exp(-remaining / soft_range)
			else:
				relative = minf(relative + remaining, max_yaw)
		relative_yaw = clampf(relative * direction, -max_yaw, max_yaw)
	_look_yaw = wrapf(body_yaw + relative_yaw, -PI, PI)
	_pitch = _advance_pitch(_pitch, pitch_delta)
	_refresh_rotation()


func _max_head_yaw() -> float:
	# Ook een ongeldige/scriptmatig ingestelde waarde kan geen volledige draai geven.
	return deg_to_rad(clampf(_value("head_max_yaw", 85.0), 1.0, 120.0))


func _clamp_pitch(pitch: float) -> float:
	var minimum := deg_to_rad(clampf(_value("camera_min_pitch", -65.0), -85.0, 0.0))
	var maximum := deg_to_rad(clampf(_value("camera_max_pitch", 70.0), 0.0, 85.0))
	return clampf(pitch, minimum, maximum)


func _advance_pitch(pitch: float, delta: float) -> float:
	pitch = _clamp_pitch(pitch)
	if is_zero_approx(delta):
		return pitch
	var direction := signf(delta)
	var limit: float = _value("camera_max_pitch", 70.0) if direction > 0.0 else -float(_value("camera_min_pitch", -65.0))
	limit = deg_to_rad(clampf(limit, 0.0, 85.0))
	var soft_range := deg_to_rad(clampf(_value("camera_pitch_soft_limit_range", 10.0), 0.0, rad_to_deg(limit)))
	var start := limit - soft_range
	var angle := pitch * direction
	var remaining := absf(delta)
	if angle < start:
		var direct := minf(remaining, start - angle)
		angle += direct
		remaining -= direct
	if remaining > 0.0:
		angle = limit - (limit - angle) * exp(-remaining / soft_range) if soft_range > 0.00001 else minf(angle + remaining, limit)
	return _clamp_pitch(angle * direction)


func _body_yaw() -> float:
	_refresh_motion_sample()
	return _motion.body_yaw


func get_look_yaw() -> float:
	return _look_yaw


func get_head_direction() -> Vector3:
	return -(Basis.from_euler(Vector3(_pitch, _look_yaw, 0.0))).z


func get_state() -> Dictionary:
	return {
		"camera_distance": _requested_distance,
		"camera_actual_distance": _actual_distance,
		"actual_distance": _actual_distance,
		"first_person": _requested_distance == 0.0,
		"head_direction": get_head_direction(),
		"head_yaw": rad_to_deg(_look_yaw),
		"head_pitch": rad_to_deg(_pitch),
		"head_relative_yaw": rad_to_deg(wrapf(_look_yaw - _body_yaw(), -PI, PI)),
		"body_yaw": rad_to_deg(_body_yaw()),
		"camera_fov": _fov,
		"fov": _fov,
		"camera_target_fov": _target_fov,
		"camera_profile_fov_offset": _profile_fov_offset(),
		"camera_follow_lag": _follow_lag,
		"camera_inertia_offset": _inertia_offset,
		"camera_inertia_amount": _inertia_offset.length(),
		"camera_landing_offset": Vector3.DOWN * _landing_amount,
		"camera_landing_amount": _landing_amount,
		"camera_accent_offset": _accent_offset,
		"camera_total_pose_offset": _total_pose_offset,
		"camera_air_launch_mix": _air_fov_mix,
		"camera_air_fov_mix": get_fov_speed_mix() if not _motion.grounded else 0.0,
		"camera_slide_fov_mix": _slide_fov_mix(),
		"camera_slide_fov_offset": _slide_fov_offset(),
	}


func _process(delta: float) -> void:
	if not _initialized or not is_instance_valid(_character):
		return
	if Engine.is_editor_hint():
		position.y = _value("camera_eye_height", 1.62)
		_arm.spring_length = _value("camera_start_distance", 4.0)
		_camera.fov = _value("camera_fov_third_person", 70.0)
		return
	# De fysieke ligcapsule kan lichaamsdraai blokkeren; hoofdgrens geldt toch.
	var relative := wrapf(_look_yaw - _body_yaw(), -PI, PI)
	_look_yaw = wrapf(_body_yaw() + clampf(relative, -_max_head_yaw(), _max_head_yaw()), -PI, PI)
	_pitch = _clamp_pitch(_pitch)
	_refresh_transform(delta)


func _safe_eye_height() -> float:
	var desired := _motion.eye_height
	var clearance := _motion.clearance_height
	var radius := _effective_camera_radius()
	var minimum := minf(radius + 0.01, clearance * 0.5)
	return clampf(desired, minimum, maxf(minimum, clearance - radius - 0.01))


func _required_camera_radius() -> float:
	# De sphere omvat ook de hoeken van het near-plane bij de grootste toegestane
	# beeldhoek/aspectratio. Een kleine Inspector-radius kan die niet uitschakelen.
	var size := get_viewport().get_visible_rect().size
	var aspect := size.x / maxf(size.y, 1.0)
	var maximum_fov := maxf(_value("camera_fov_third_person", 70.0), _value("camera_fov_first_person", 75.0))
	var maximum_offset := maxf(0.0, maxf(_value("camera_sneak_fov_offset", -2.0), maxf(_value("camera_crouch_fov_offset", -3.0), _value("camera_prone_fov_offset", -5.0))))
	var slide_bonus := 0.0
	if _value("camera_fov_refinement_enabled", true):
		slide_bonus = maxf(_value("camera_slide_fov_bonus", 3.0), _value("camera_first_person_slide_fov_bonus", 1.5))
	maximum_fov = clampf(maxf(_fov, maximum_fov + maximum_offset + float(_value("camera_sprint_fov_bonus", 6.0)) + maxf(slide_bonus, 0.0)), 30.0, 110.0)
	var near_height := _camera.near * tan(deg_to_rad(maximum_fov) * 0.5)
	var near_width := near_height * aspect
	return sqrt(_camera.near * _camera.near + near_height * near_height + near_width * near_width) + 0.01


func _effective_camera_radius() -> float:
	var clearance := _motion.clearance_height
	var desired: float = _value("camera_collision_radius", 0.18)
	# Een vrijwillig groot volume blijft passend in een lage houding; de minimale
	# beeldrandbescherming heeft altijd voorrang boven deze gewenste radius.
	return maxf(_required_camera_radius(), minf(desired, maxf(0.01, clearance * 0.5 - 0.01)))


func _refresh_transform(delta: float, immediate: bool = false) -> void:
	if not is_instance_valid(_character) or Engine.is_editor_hint():
		return
	_refresh_motion_sample()
	var interpolated: Transform3D = _character.get_global_transform_interpolated()
	var eye := _safe_eye_height()
	var actor_floor := interpolated.origin.y
	var clearance := _motion.clearance_height
	var radius := _effective_camera_radius()
	# Ook tijdens vallen gebruikt hoogte dezelfde renderpose. Een ruwe physics-Y
	# zou de camera anders steeds één tick omlaag trekken en tussen ticks stilzetten.
	var maximum_y := actor_floor + maxf(clearance * 0.5, clearance - radius - 0.01)
	if immediate:
		_eye_height = eye
		_feet_height = _character.global_position.y
	else:
		# Neerwaartse vormwissel wordt direct veilig; omhoog volgt zacht.
		_eye_height = eye if eye < _eye_height else lerpf(_eye_height, eye, _blend(delta, _value("camera_eye_half_life", 0.08)))
		var feet_half_life: float = _value("camera_step_half_life", 0.07)
		# Vlucht/val volgen zonder extra cameravertraging; kleine vloeropstapjes mogen zacht.
		var grounded := _motion.grounded
		if absf(actor_floor - _feet_height) > 0.6 or not grounded:
			_feet_height = actor_floor
		else:
			_feet_height = lerpf(_feet_height, actor_floor, _blend(delta, feet_half_life))
	_camera_shape.radius = radius
	var target := Vector3(interpolated.origin.x, 0.0, interpolated.origin.z)
	_update_follow_position(target, delta, immediate)
	_update_landing(delta, immediate)
	var eye_y := minf(_feet_height + _eye_height, maximum_y)
	var target_eye := Vector3(target.x, eye_y, target.z)
	# Remveer en landingsdip delen één 3D-accentbudget. Samen met de gewone
	# volglag volgen ze één renderpose en dezelfde volledige volumecontrole.
	var maximum_lag: float = maxf(0.0, _value("camera_follow_max_lag", 0.12))
	var maximum_accent := clampf(_value("camera_accent_max_offset", 0.04), 0.0, 0.1)
	_accent_offset = _inertia_offset + Vector3.DOWN * _landing_amount
	if _value("camera_landing_enabled", true):
		_accent_offset = _accent_offset.limit_length(maximum_accent)
	var followed_eye := target_eye + (_follow_position - target + _accent_offset).limit_length(maximum_lag)
	global_position = _safe_follow_anchor(target_eye, followed_eye)
	_total_pose_offset = global_position - target_eye
	if global_position.distance_squared_to(followed_eye) > 0.00000001:
		# Een wand stopt ook de veer direct; er blijft geen opgebouwde druk over
		# die de camera later alsnog tegen of door die wand zou duwen.
		_follow_position = Vector3(global_position.x, 0.0, global_position.z)
		_inertia_offset = Vector3.ZERO
		_inertia_velocity = Vector3.ZERO
		_clear_landing_history(false)
		_accent_offset = Vector3.ZERO
	_follow_lag = Vector3(global_position.x, 0.0, global_position.z).distance_to(target)
	_refresh_rotation()
	_zoom_distance = lerpf(_zoom_distance, _requested_distance, _blend(delta, _value("camera_zoom_half_life", 0.06))) if not immediate else _requested_distance
	if absf(_zoom_distance - _requested_distance) < 0.001:
		_zoom_distance = _requested_distance
	_arm.spring_length = _zoom_distance
	var safe_distance := _query_safe_distance(_zoom_distance)
	if immediate or safe_distance < _actual_distance:
		_actual_distance = safe_distance
	else:
		_actual_distance = lerpf(_actual_distance, safe_distance, _blend(delta, _value("camera_obstacle_return_half_life", 0.12)))
	# Afstand en kijkhoek komen uit hetzelfde renderframe en volledige volumecheck.
	_camera.position = Vector3(0.0, 0.0, _actual_distance)
	_refresh_fov(delta, immediate)
	_refresh_visibility()


func _update_follow_position(target: Vector3, delta: float, immediate: bool) -> void:
	var half_life: float = _value("camera_first_person_follow_half_life", 0.0) if _requested_distance == 0.0 else _value("camera_follow_half_life", 0.018)
	var displacement := target - _previous_follow_target
	var current_speed := _previous_follow_velocity.length()
	current_speed = maxf(current_speed, _motion.horizontal_velocity.length())
	# Lange onderbrekingen en verplaatsingen buiten het normale bewegingsbereik
	# zijn geen remactie. Wisselen/resetten wist dezelfde geschiedenis expliciet.
	var teleported := displacement.length() > maxf(1.0, current_speed * maxf(delta, 0.0) * 3.0 + 0.25)
	if immediate or delta <= 0.0 or delta > 0.25 or teleported:
		_follow_position = target
		_previous_follow_target = target
		_clear_inertia_history()
		_clear_landing_history(teleported)
		return
	var target_velocity := displacement / delta
	_update_inertia(target_velocity, delta)
	if half_life <= 0.0:
		_follow_position = target
	else:
		# Exacte oplossing voor een lineair bewegend renderdoel, geen gewone lerp
		# die bij dezelfde snelheid een andere achterstand krijgt op 30 versus 144 fps.
		var tau := half_life / log(2.0)
		var decay := exp(-delta / tau)
		_follow_position = target - target_velocity * tau + (_follow_position - _previous_follow_target + target_velocity * tau) * decay
		var maximum_lag: float = maxf(0.0, _value("camera_follow_max_lag", 0.12))
		_follow_position = target + (_follow_position - target).limit_length(maximum_lag)
	_previous_follow_target = target


func _clear_inertia_history() -> void:
	_previous_follow_velocity = Vector3.ZERO
	_inertia_offset = Vector3.ZERO
	_inertia_velocity = Vector3.ZERO
	_inertia_reference_speed = 0.0
	_inertia_brake_time = 0.0


func _clear_landing_history(clear_support: bool = true) -> void:
	_landing_elapsed = 0.0
	_landing_start = 0.0
	_landing_peak = 0.0
	_landing_amount = 0.0
	if clear_support:
		_landing_seen_support = false


func _maximum_landing_dip() -> float:
	var amount: float = _value("camera_first_person_landing_max_dip", 0.0) if _requested_distance == 0.0 else _value("camera_landing_max_dip", 0.01)
	return clampf(amount, 0.0, 0.05)


## Echte post-move impact, onafhankelijk van contactaudio of zijn volumevelden.
func capture_contact(frame: AtlasCharacterContactFrame) -> void:
	var primed := _landing_seen_support
	if frame.supported or frame.jumped:
		_landing_seen_support = true
	if not _value("camera_landing_enabled", true) or not primed or not frame.landed or frame.jumped or not frame.real_grounded:
		return
	var minimum: float = maxf(0.0, _value("camera_landing_min_speed", 0.75))
	var impact := maxf(0.0, -frame.incoming_velocity.y)
	if impact < minimum:
		return
	var full: float = maxf(minimum + 0.01, _value("camera_landing_full_speed", 8.0))
	var amount := _maximum_landing_dip() * clampf((impact - minimum) / (full - minimum), 0.0, 1.0)
	if amount <= 0.0:
		return
	# Een volgende impact begint vanaf de huidige uitslag, zonder impulsen op te tellen.
	_landing_start = minf(_landing_amount, _maximum_landing_dip())
	_landing_peak = minf(maxf(_landing_start, amount), _maximum_landing_dip())
	_landing_elapsed = 0.0


func _update_landing(delta: float, immediate: bool) -> void:
	var maximum := _maximum_landing_dip()
	if immediate or not _value("camera_landing_enabled", true) or maximum <= 0.0:
		_clear_landing_history(false)
		return
	if _landing_peak <= 0.0:
		return
	_landing_start = minf(_landing_start, maximum)
	_landing_peak = minf(_landing_peak, maximum)
	_landing_elapsed += maxf(delta, 0.0)
	var attack: float = maxf(0.0, _value("camera_landing_attack_time", 0.045))
	var recovery: float = maxf(0.01, _value("camera_landing_recovery_time", 0.20))
	if attack > 0.0 and _landing_elapsed < attack:
		_landing_amount = lerpf(_landing_start, _landing_peak, smoothstep(0.0, attack, _landing_elapsed))
	else:
		var phase := clampf((_landing_elapsed - attack) / recovery, 0.0, 1.0)
		_landing_amount = _landing_peak * (1.0 - smoothstep(0.0, 1.0, phase))
		if phase >= 1.0:
			_clear_landing_history(false)


func _update_inertia(target_velocity: Vector3, delta: float) -> void:
	var enabled: bool = _value("camera_inertia_enabled", true)
	if _requested_distance == 0.0 and not _value("camera_first_person_inertia_enabled", false):
		enabled = false
	var amount := clampf(_value("camera_inertia_amount", 0.035), 0.0, 0.08)
	var speed := target_velocity.length()
	if not enabled or amount <= 0.0:
		_clear_inertia_history()
		_previous_follow_velocity = target_velocity
		_inertia_reference_speed = speed
		return
	var previous_speed := _previous_follow_velocity.length()
	var lost_speed := maxf(0.0, previous_speed - speed)
	_inertia_brake_time = maxf(0.0, _inertia_brake_time - delta)
	if lost_speed > 0.01:
		if _inertia_brake_time <= 0.0:
			_inertia_reference_speed = previous_speed
		# Bij 144 fps liggen enkele renderframes tussen twee physics-ticks.
		# Bewaar de snelheid vóór deze remactie ook tijdens die tussenframes.
		_inertia_brake_time = 0.10
	elif speed > previous_speed + 0.01 or _inertia_brake_time <= 0.0:
		_inertia_reference_speed = speed
	var minimum: float = maxf(0.0, _value("camera_inertia_min_speed", 3.0))
	var full_speed: float = maxf(minimum + 0.01, _value("camera_inertia_full_speed", 9.0))
	var weight := clampf((_inertia_reference_speed - minimum) / (full_speed - minimum), 0.0, 1.0)
	weight *= weight
	var recovery: float = clampf(_value("camera_inertia_recovery_time", 0.32), 0.05, 2.0)
	var omega := 6.0 / recovery
	# Een kritisch gedempte veer krijgt uitsluitend verloren horizontale snelheid
	# als kracht. Muisbeweging en bochten op gelijke snelheid geven geen impuls.
	# Volledige remming op full_speed bereikt ongeveer amount aan veeruitslag.
	var force := _previous_follow_velocity.normalized() * (lost_speed / delta) * (amount * omega * exp(1.0) / full_speed) * weight
	var equilibrium := force / (omega * omega)
	var shifted := _inertia_offset - equilibrium
	var coefficient := _inertia_velocity + omega * shifted
	var decay := exp(-omega * delta)
	# Exact voor constante kracht in dit renderinterval, zonder Euler-stap die
	# bij een andere framerate meer energie of een ander herstel zou geven.
	_inertia_offset = equilibrium + (shifted + coefficient * delta) * decay
	_inertia_velocity = (_inertia_velocity - omega * coefficient * delta) * decay
	if _inertia_offset.length() > amount:
		_inertia_offset = _inertia_offset.limit_length(amount)
		var outward := _inertia_offset.normalized()
		_inertia_velocity -= outward * maxf(0.0, _inertia_velocity.dot(outward))
	_previous_follow_velocity = target_velocity


func _camera_query(position_at: Vector3) -> PhysicsShapeQueryParameters3D:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _camera_shape
	query.transform = Transform3D(Basis.IDENTITY, position_at)
	query.collision_mask = _arm.collision_mask
	query.collide_with_areas = false
	if _motion.excluded_body.is_valid():
		query.exclude = [_motion.excluded_body]
	return query


func _safe_follow_anchor(target: Vector3, candidate: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var query := _camera_query(target)
	# Vormwissel/hoekbotsing kan de oude renderpose onveilig maken. Veiligheid
	# heeft voorrang: kies dan de gecontroleerde actuele oogpositie, zonder lag.
	if not space.intersect_shape(query, 1).is_empty():
		var current_eye := _character.global_position + Vector3.UP * _safe_eye_height()
		query.transform.origin = current_eye
		if space.intersect_shape(query, 1).is_empty():
			return current_eye
		return target
	var motion := candidate - target
	if motion.is_zero_approx():
		return target
	query.motion = motion
	var fraction := space.cast_motion(query)
	var travel := maxf(0.0, motion.length() * float(fraction[0]) - 0.005) if float(fraction[0]) < 1.0 else motion.length()
	return target + motion.normalized() * travel


func _query_safe_distance(distance: float) -> float:
	if distance <= 0.0 or not is_inside_tree():
		return 0.0
	var query := _camera_query(global_position)
	var space := get_world_3d().direct_space_state
	# cast_motion slaat begin-overlap over; controleer die daarom afzonderlijk.
	if not space.intersect_shape(query, 1).is_empty():
		return 0.0
	query.motion = global_basis.z * distance
	var fraction := space.cast_motion(query)
	return maxf(0.0, distance * float(fraction[0]) - _arm.margin) if float(fraction[0]) < 1.0 else distance


func _base_fov() -> float:
	return _value("camera_fov_first_person", 75.0) if _requested_distance == 0.0 else _value("camera_fov_third_person", 70.0)


func _motion_profile() -> String:
	return _motion.motion_profile


func _speed_mix(horizontal: Vector3, walk_limit: float, sprint_limit: float) -> float:
	if sprint_limit <= walk_limit:
		return 0.0
	return clampf((horizontal.length() - walk_limit) / (sprint_limit - walk_limit), 0.0, 1.0)


## Geaccepteerde afzet bevat de vaart vóór sprongbonus. Haar mix is de bovengrens:
## luchtrem mag alleen terugnemen; uitgeschakelde refinement bewaart de oude mapping.
func capture_jump(horizontal: Vector3, walk_limit: float, sprint_limit: float, sneaking: bool) -> void:
	_air_fov_mix = 0.0 if sneaking else _speed_mix(horizontal, walk_limit, sprint_limit)
	_air_walk_limit = walk_limit
	_air_sprint_limit = sprint_limit


## De grondvaart vóór move_and_slide bewaart ook bij gewoon van een rand lopen
## exact hetzelfde vluchtbeeld. Grond-FOV zelf gebruikt de echte afgelegde vaart.
func capture_ground_motion(horizontal: Vector3, walk_limit: float, sprint_limit: float, low_or_sneaking: bool) -> void:
	_air_fov_mix = 0.0 if low_or_sneaking else _speed_mix(horizontal, walk_limit, sprint_limit)
	_air_walk_limit = walk_limit
	_air_sprint_limit = sprint_limit


func capture_posture(posture: String) -> void:
	if posture not in ["staan", "stand"]:
		_air_fov_mix = 0.0


func get_fov_speed_mix() -> float:
	_refresh_motion_sample()
	if _motion_profile() in ["sneak", "kruipen", "crouch", "liggen", "prone"]:
		return 0.0
	if not _motion.grounded:
		if _value("camera_fov_refinement_enabled", true):
			return minf(_air_fov_mix, _speed_mix(_motion.horizontal_velocity, _air_walk_limit, _air_sprint_limit))
		return _air_fov_mix
	return _speed_mix(_motion.actual_horizontal_velocity, _motion.walk_speed_limit, _motion.sprint_speed_limit)


func _profile_fov_offset() -> float:
	if not _value("camera_speed_fov_enabled", true):
		return 0.0
	match _motion_profile():
		"sneak":
			return _value("camera_sneak_fov_offset", -2.0)
		"kruipen", "crouch":
			return _value("camera_crouch_fov_offset", -3.0)
		"liggen", "prone":
			return _value("camera_prone_fov_offset", -5.0)
	return 0.0


func _slide_fov_mix() -> float:
	if not _value("camera_speed_fov_enabled", true) or not _value("camera_fov_refinement_enabled", true) or not _motion.sliding or not _motion.grounded:
		return 0.0
	var reference: float = maxf(0.1, _value("camera_slide_fov_reference_speed", 9.0))
	return clampf(_motion.actual_horizontal_velocity.length() / reference, 0.0, 1.0)


func _slide_fov_offset() -> float:
	var bonus: float = _value("camera_first_person_slide_fov_bonus", 1.5) if _requested_distance == 0.0 else _value("camera_slide_fov_bonus", 3.0)
	return _slide_fov_mix() * clampf(bonus, 0.0, 10.0)


func _refresh_fov(delta: float, immediate: bool) -> void:
	var mix := clampf(get_fov_speed_mix(), 0.0, 1.0)
	if _motion_profile() in ["sneak", "kruipen", "crouch", "liggen", "prone"]:
		mix = 0.0
	var target := _base_fov() + _profile_fov_offset() + _slide_fov_offset()
	if _value("camera_speed_fov_enabled", true):
		target += mix * float(_value("camera_sprint_fov_bonus", 6.0))
	target = clampf(target, 30.0, 110.0)
	_target_fov = target
	var half_life: float = _value("camera_fov_rise_half_life", 0.10) if target > _fov else _value("camera_fov_return_half_life", 0.18)
	_fov = target if immediate else lerpf(_fov, target, _blend(delta, half_life))
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.fov = _fov


func _refresh_visibility() -> void:
	var layer := _motion.presentation_layer
	if layer <= 0:
		return
	var radius := _motion.standing_radius
	var close_distance := maxf(_first_person_threshold(), radius + _camera.near + _arm.margin + 0.05)
	var inside_self := _requested_distance == 0.0 or _actual_distance <= close_distance
	if _motion.body_shape is CapsuleShape3D:
		# De ligcapsule is langer achter het hoofd dan een staande capsule breed is.
		# Test haar echte geroteerde vorm, zodat dicht zoomen geen eigen lichaam toont.
		var capsule := _motion.body_shape as CapsuleShape3D
		var point := _motion.body_shape_transform.affine_inverse() * _camera.global_position
		var half_axis := maxf(capsule.height * 0.5 - capsule.radius, 0.0)
		var closest := Vector3(0.0, clampf(point.y, -half_axis, half_axis), 0.0)
		var overlap_radius := capsule.radius + _required_camera_radius() + _arm.margin + 0.05
		inside_self = inside_self or point.distance_squared_to(closest) <= overlap_radius * overlap_radius
	_camera.set_cull_mask_value(layer, not inside_self)


func _refresh_rotation() -> void:
	global_rotation = Vector3(_pitch, _look_yaw, 0.0)
	look_direction_changed.emit(_look_yaw, _pitch)


func _blend(delta: float, half_life: float) -> float:
	return 1.0 if half_life <= 0.0 else 1.0 - exp(-log(2.0) * maxf(delta, 0.0) / half_life)
