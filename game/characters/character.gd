@tool
class_name AtlasCharacter
extends CharacterBody3D
## Plaatsbare capsule. De oorsprong staat op de voetzool; wijzig de instellingen
## op deze node om een instance te variëren, zonder gedeelde Resources te wijzigen.

@export_category("Character")
@export_group("Naam en uiterlijk")
@export var display_name: String = "Character":
	set(value):
		display_name = value
		_refresh_if_ready()
@export var capsule_color: Color = Color(0.18, 0.65, 0.82):
	set(value):
		capsule_color = value
		_refresh_if_ready()
@export var name_visible: bool = true:
	set(value):
		name_visible = value
		_refresh_if_ready()
## Afstand tussen bovenkant capsule en naam, in meter.
@export_range(0.05, 2.0, 0.05, "suffix:m") var name_height: float = 0.35:
	set(value):
		name_height = value
		_refresh_if_ready()
@export_range(16, 96, 1) var name_font_size: int = 42:
	set(value):
		name_font_size = value
		_refresh_if_ready()

@export_group("Lopen")
## Snelheden in meter per seconde. Gecombineerde input krijgt één limiet.
@export_range(0.1, 20.0, 0.1, "suffix:m/s") var walk_forward_speed: float = 5.0
@export_range(0.05, 1.0, 0.01) var walk_side_ratio: float = 0.8
@export_range(0.05, 1.0, 0.01) var walk_back_ratio: float = 0.55
@export_range(0.1, 80.0, 0.5, "suffix:m/s²") var walk_acceleration: float = 18.0
@export_range(0.1, 80.0, 0.5, "suffix:m/s²") var walk_deceleration: float = 22.0

@export_group("Sprint")
## Sprint werkt ook zijwaarts en achteruit, met deze verhoudingen.
@export_range(0.1, 30.0, 0.1, "suffix:m/s") var sprint_forward_speed: float = 9.0
@export_range(0.05, 1.0, 0.01) var sprint_side_ratio: float = 0.8
@export_range(0.05, 1.0, 0.01) var sprint_back_ratio: float = 0.55
@export_range(0.1, 80.0, 0.5, "suffix:m/s²") var sprint_acceleration: float = 12.0
@export_range(0.1, 80.0, 0.5, "suffix:m/s²") var sprint_deceleration: float = 16.0

@export_group("Springen")
## Hoogte boven het afzetpunt. Werkelijke afzetsnelheid mengt de drie ankers.
@export_range(0.1, 6.0, 0.05, "suffix:m") var standing_jump_height: float = 2.0
@export_range(0.1, 6.0, 0.05, "suffix:m") var walking_jump_height: float = 1.25
@export_range(0.1, 6.0, 0.05, "suffix:m") var sprint_jump_height: float = 0.7
## Bewuste extra afzetimpuls voor afstand; geen bonus door diagonale input.
@export_range(0.0, 15.0, 0.1, "suffix:m/s") var sprint_jump_boost: float = 5.0
## 0 is geen luchtsturing, 1 gebruikt de gewone loopacceleratie.
@export_range(0.0, 1.0, 0.01) var air_control: float = 0.2
@export_range(1.0, 40.0, 0.5, "suffix:m/s²") var gravity_strength: float = 20.0

@export_group("Botsing")
@export_range(0.1, 1.0, 0.01, "suffix:m") var capsule_radius: float = 0.35:
	set(value):
		capsule_radius = value
		_refresh_if_ready()
## Totale hoogte inclusief ronde uiteinden. Minimaal twee keer de radius.
@export_range(0.3, 3.0, 0.05, "suffix:m") var capsule_height: float = 1.8:
	set(value):
		capsule_height = value
		_refresh_if_ready()
## Maximale verticale opstap. De volledige capsule moet bovenaan vrij passen.
@export_range(0.0, 1.0, 0.01, "suffix:m") var step_height: float = 0.35

@export_group("Camera")
@export_range(0.0, 12.0, 0.1, "suffix:m") var camera_start_distance: float = 4.0
@export_range(0.1, 20.0, 0.1, "suffix:m") var camera_max_distance: float = 8.0
@export_range(0.05, 2.0, 0.05, "suffix:m") var camera_zoom_step: float = 0.5
## Bij deze afstand klikt de zoom door naar de ogen, met eigen capsule uit beeld.
@export_range(0.0, 1.0, 0.01, "suffix:m") var first_person_threshold: float = 0.45
@export_range(0.1, 3.0, 0.01, "suffix:m") var camera_eye_height: float = 1.62:
	set(value):
		camera_eye_height = value
		_refresh_if_ready()
## Graden per pixel muisbeweging.
@export_range(0.02, 1.0, 0.01, "suffix:°/px") var look_sensitivity: float = 0.12
@export_range(-85.0, 0.0, 1.0, "suffix:°") var camera_min_pitch: float = -70.0
@export_range(0.0, 85.0, 1.0, "suffix:°") var camera_max_pitch: float = 75.0
@export_range(-60.0, 60.0, 1.0, "suffix:°") var camera_start_pitch: float = -12.0

@export_group("Debug")
## Toon richtingpijlen. Geel = kijken, blauw = input, oranje = echte beweging.
@export var debug_enabled: bool = true:
	set(value):
		debug_enabled = value
		_refresh_if_ready()

static var _used_presentation_layers: Dictionary = {}

var _controlled: bool = false
var _spawn_transform: Transform3D
var _camera_distance: float = 4.0
var _presentation_layer: int = 0
var _input_direction: Vector3 = Vector3.ZERO
var _movement_direction: Vector3 = Vector3.ZERO
var _actual_speed: float = 0.0
var _sprint_requested: bool = false
var _last_ground_sprint: bool = false
var _air_speed_cap: float = 0.0
var _jump_profile: String = "geen"
var _jump_height: float = 0.0
var _launch_speed: float = 0.0
var _last_step_height: float = 0.0
var _step_support_remaining: float = 0.0
var _step_support_point: Vector3 = Vector3.ZERO
var _step_support_direction: Vector3 = Vector3.ZERO

@onready var _collider: CollisionShape3D = $CollisionShape3D
@onready var _capsule: MeshInstance3D = $Presentation/Capsule
@onready var _name_label: Label3D = $Presentation/NameLabel
@onready var _camera_pivot: Node3D = $CameraPivot
@onready var _camera_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var _camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var _debug_arrows: Node3D = $DebugArrows
@onready var _input_arrow: Node3D = $DebugArrows/InputArrow
@onready var _movement_arrow: Node3D = $DebugArrows/MovementArrow


func _ready() -> void:
	_spawn_transform = global_transform
	set_camera_distance(camera_start_distance)
	_camera_pivot.rotation.x = deg_to_rad(camera_start_pitch)
	_refresh_presentation()
	if Engine.is_editor_hint():
		set_physics_process(false)
		set_process_unhandled_input(false)
		return
	_allocate_presentation_layer()
	_camera_arm.add_excluded_object(get_rid())
	_refresh_camera()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		# SpringArm werkt de echte afstand na botsing bij. Filter ook wanneer een
		# muur de third-personcamera tijdelijk binnen de eigen capsule duwt.
		_update_camera_visibility()


func _exit_tree() -> void:
	if _presentation_layer > 0:
		_used_presentation_layers.erase(_presentation_layer)


func _refresh_if_ready() -> void:
	if is_node_ready():
		_refresh_presentation()
		update_configuration_warnings()


func _refresh_presentation() -> void:
	var height := maxf(capsule_height, capsule_radius * 2.0)
	# Maak vorm, mesh en materiaal voor deze instance; gedeelde subresources blijven intact.
	var shape := CapsuleShape3D.new()
	shape.radius = capsule_radius
	shape.height = height
	_collider.shape = shape
	_collider.position.y = height * 0.5
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = capsule_radius
	capsule_mesh.height = height
	_capsule.mesh = capsule_mesh
	_capsule.position.y = height * 0.5
	var material := StandardMaterial3D.new()
	material.albedo_color = capsule_color
	material.roughness = 0.7
	_capsule.material_override = material
	_name_label.text = display_name
	_name_label.position.y = height + name_height
	_name_label.font_size = name_font_size
	_name_label.visible = name_visible
	_camera_pivot.position.y = camera_eye_height
	_debug_arrows.visible = debug_enabled
	_refresh_camera()


func _allocate_presentation_layer() -> void:
	# Layer 1 blijft voor level/geometrie. Alleen de eigen camera filtert zijn layer.
	for layer in range(2, 21):
		if not _used_presentation_layers.has(layer):
			_presentation_layer = layer
			_used_presentation_layers[layer] = get_instance_id()
			break
	if _presentation_layer == 0:
		push_warning("Geen vrije Character-renderlayer: eerste-persoonszicht vraagt maximaal 19 Characters.")
		return
	var mask := 1 << (_presentation_layer - 1)
	_capsule.layers = mask
	_name_label.layers = mask
	for arrow in _debug_arrows.get_children():
		for mesh in arrow.get_children():
			if mesh is VisualInstance3D:
				mesh.layers = mask


func set_controlled(value: bool) -> void:
	_controlled = value
	if not is_node_ready():
		return
	if value:
		_camera.make_current()
	else:
		_camera.clear_current(false)
		_input_direction = Vector3.ZERO
	_refresh_camera()


func is_controlled() -> bool:
	return _controlled


func reset_to_spawn() -> void:
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	_input_direction = Vector3.ZERO
	_movement_direction = Vector3.ZERO
	_actual_speed = 0.0
	_last_ground_sprint = false
	_air_speed_cap = 0.0
	_jump_profile = "geen"
	_jump_height = 0.0
	_launch_speed = 0.0
	_step_support_remaining = 0.0
	set_camera_distance(camera_start_distance)
	_camera_pivot.rotation.x = deg_to_rad(camera_start_pitch)
	_refresh_camera()
	_update_debug_arrows()


func _unhandled_input(event: InputEvent) -> void:
	if not _controlled or Engine.is_editor_hint():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(deg_to_rad(-event.relative.x * look_sensitivity))
		_camera_pivot.rotation.x = clampf(
			_camera_pivot.rotation.x - deg_to_rad(event.relative.y * look_sensitivity),
			deg_to_rad(camera_min_pitch), deg_to_rad(camera_max_pitch))
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_camera_distance(_camera_distance - camera_zoom_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# Vanuit de ogen één stap over het klikpunt, ook bij een heel kleine zoomstap.
			var next_distance := _camera_distance + camera_zoom_step
			if _camera_distance == 0.0:
				next_distance = maxf(next_distance, _effective_first_person_threshold() + camera_zoom_step)
			set_camera_distance(next_distance)


func set_camera_distance(distance: float) -> void:
	_camera_distance = clampf(distance, 0.0, camera_max_distance)
	if _camera_distance <= _effective_first_person_threshold():
		_camera_distance = 0.0
	if is_node_ready():
		_refresh_camera()


func _refresh_camera() -> void:
	_camera_arm.spring_length = _camera_distance
	_update_camera_visibility()


func _effective_first_person_threshold() -> float:
	# Ook bij een heel kleine maximale afstand moet uitzoomen mogelijk blijven.
	return minf(first_person_threshold, camera_max_distance * 0.5)


func _update_camera_visibility() -> void:
	if _presentation_layer > 0:
		# get_hit_length is vóór SpringArm.margin; de camera zelf staat dichterbij.
		var close_distance := maxf(_effective_first_person_threshold(), capsule_radius + _camera.near + _camera_arm.margin + 0.05)
		var inside_self := _camera_distance == 0.0 or _camera_arm.get_hit_length() <= close_distance
		_camera.set_cull_mask_value(_presentation_layer, not inside_self)


## Elliptische richtingsgrens: diagonaal input blijft één vector en krijgt geen bonus.
## Vector2.y < 0 is vooruit; Vector2.y > 0 is achteruit.
func direction_speed_limit(local_direction: Vector2, sprinting: bool) -> float:
	var direction := local_direction.normalized()
	if direction.is_zero_approx():
		direction = Vector2(0.0, -1.0)
	var forward_speed := sprint_forward_speed if sprinting else walk_forward_speed
	var side_ratio := sprint_side_ratio if sprinting else walk_side_ratio
	var back_ratio := sprint_back_ratio if sprinting else walk_back_ratio
	var side_speed := maxf(forward_speed * side_ratio, 0.01)
	var longitudinal_speed := maxf(forward_speed * (back_ratio if direction.y > 0.0 else 1.0), 0.01)
	return 1.0 / sqrt(pow(direction.x / side_speed, 2.0) + pow(direction.y / longitudinal_speed, 2.0))


## Alleen afzetsnelheid bepaalt het profiel; Shift wordt hier bewust niet gelezen.
func jump_parameters(horizontal_velocity: Vector3) -> Dictionary:
	var horizontal := Vector3(horizontal_velocity.x, 0.0, horizontal_velocity.z)
	var speed := horizontal.length()
	var local_velocity := global_basis.inverse() * horizontal
	var direction := Vector2(local_velocity.x, local_velocity.z)
	var walk_limit := direction_speed_limit(direction, false)
	var sprint_limit := direction_speed_limit(direction, true)
	var walk_weight := clampf(speed / maxf(walk_limit, 0.01), 0.0, 1.0)
	var sprint_weight := 0.0
	if sprint_limit > walk_limit:
		sprint_weight = clampf((speed - walk_limit) / (sprint_limit - walk_limit), 0.0, 1.0)
	var height := lerpf(standing_jump_height, walking_jump_height, walk_weight)
	height = lerpf(height, sprint_jump_height, sprint_weight)
	var boost := sprint_jump_boost * sprint_weight
	var profile := "stilstand"
	if sprint_weight > 0.01:
		profile = "sprint"
	elif walk_weight > 0.01:
		profile = "lopen"
	return {
		"profile": profile,
		"height": height,
		"vertical_speed": sqrt(2.0 * gravity_strength * height),
		"horizontal_boost": boost,
		"launch_speed": speed + boost,
		"walk_weight": walk_weight,
		"sprint_weight": sprint_weight,
	}


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var input := Vector2.ZERO
	var input_allowed := _controlled and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or DisplayServer.get_name() == "headless")
	if input_allowed:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	_sprint_requested = input_allowed and Input.is_action_pressed("sprint")
	_input_direction = global_basis * Vector3(input.x, 0.0, input.y)
	var was_grounded := is_on_floor() or _step_support_remaining > 0.0
	_update_horizontal_velocity(input, was_grounded, delta)
	var jumped := false
	if was_grounded and input_allowed and Input.is_action_just_pressed("jump"):
		_start_jump()
		jumped = true
	elif was_grounded:
		velocity.y = -0.1
	else:
		velocity.y -= gravity_strength * delta
	var before := global_position
	_last_step_height = 0.0
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var stepped := was_grounded and not jumped and _try_step_up(horizontal * delta)
	if stepped:
		# De geteste opstap heeft de horizontale verplaatsing al uitgevoerd.
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()
	if stepped:
		velocity.x = horizontal.x
		velocity.z = horizontal.z
	var travel := global_position - before
	var real_horizontal := Vector3(travel.x, 0.0, travel.z) / delta
	_actual_speed = real_horizontal.length()
	_movement_direction = real_horizontal.normalized()
	_update_debug_arrows()
	if global_position.y < -20.0:
		reset_to_spawn()


func _update_horizontal_velocity(input: Vector2, grounded: bool, delta: float) -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var target := Vector3.ZERO
	if not input.is_zero_approx():
		target = _input_direction.normalized() * direction_speed_limit(input, _sprint_requested) * minf(input.length(), 1.0)
	if grounded:
		if _sprint_requested and not input.is_zero_approx():
			_last_ground_sprint = true
		var slowing := target.length_squared() < horizontal.length_squared() or horizontal.dot(target) < 0.0
		var acceleration := sprint_acceleration if _sprint_requested else walk_acceleration
		var deceleration := sprint_deceleration if _last_ground_sprint else walk_deceleration
		horizontal = horizontal.move_toward(target, (deceleration if slowing else acceleration) * delta)
		if not _sprint_requested and (horizontal.is_zero_approx() or (not input.is_zero_approx() and horizontal.length() <= direction_speed_limit(input, false) + 0.01)):
			_last_ground_sprint = false
		# Ook van een rand af lopen behoudt de horizontale snelheid en beperkte sturing.
		_air_speed_cap = maxf(horizontal.length(), direction_speed_limit(input, false))
	else:
		# Laat de afzetafstand bestaan. Stuur beperkt binnen de vaste luchtlimiet.
		if not input.is_zero_approx():
			target = _input_direction.normalized() * _air_speed_cap * minf(input.length(), 1.0)
			horizontal = horizontal.move_toward(target, walk_acceleration * air_control * delta)
			horizontal = horizontal.limit_length(_air_speed_cap)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func _start_jump() -> void:
	_step_support_remaining = 0.0
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var parameters := jump_parameters(horizontal)
	_jump_profile = parameters["profile"]
	_jump_height = parameters["height"]
	_launch_speed = parameters["launch_speed"]
	if not horizontal.is_zero_approx():
		horizontal += horizontal.normalized() * float(parameters["horizontal_boost"])
	velocity = horizontal + Vector3.UP * float(parameters["vertical_speed"])
	var local_horizontal := global_basis.inverse() * horizontal
	_air_speed_cap = maxf(horizontal.length(), direction_speed_limit(Vector2(local_horizontal.x, local_horizontal.z), false))


func _try_step_up(horizontal_motion: Vector3) -> bool:
	if step_height <= 0.0 or horizontal_motion.is_zero_approx():
		_step_support_remaining = 0.0
		return false
	if _step_support_remaining > 0.0:
		return _continue_step(horizontal_motion)
	var wall_collision := KinematicCollision3D.new()
	if not test_move(global_transform, horizontal_motion, wall_collision):
		return false
	if wall_collision.get_normal().dot(Vector3.UP) >= cos(floor_max_angle):
		return false
	var lift := Vector3.UP * (step_height + 0.01)
	if test_move(global_transform, lift):
		return false
	var raised := global_transform
	raised.origin += lift
	# Een capsule raakt eerst met de ronde rand. Zoek de echte bovenkant één
	# radius verderop, terwijl de werkelijke verplaatsing de gewone delta blijft.
	var probe_distance := maxf(horizontal_motion.length(), capsule_radius + 0.04)
	var probe_motion := horizontal_motion.normalized() * probe_distance
	if test_move(raised, probe_motion):
		return false
	raised.origin += probe_motion
	var landing := KinematicCollision3D.new()
	if not test_move(raised, -lift - Vector3.UP * 0.03, landing):
		return false
	if landing.get_normal().dot(Vector3.UP) < cos(floor_max_angle):
		return false
	var destination := raised.origin + landing.get_travel()
	var rise := destination.y - global_position.y
	if rise <= 0.005 or rise > step_height + 0.005:
		return false
	var actual_destination := global_position + horizontal_motion
	actual_destination.y = destination.y
	var actual_raised := global_transform
	actual_raised.origin.y = destination.y
	if test_move(actual_raised, horizontal_motion):
		return false
	global_position = actual_destination
	_step_support_point = destination
	_step_support_direction = horizontal_motion.normalized()
	_step_support_remaining = maxf(probe_distance - horizontal_motion.length(), 0.0)
	_last_step_height = rise
	return true


func _continue_step(horizontal_motion: Vector3) -> bool:
	# Ondersteun alleen de korte aanloop tot de voeten de gecontroleerde trede
	# bereiken. Omkeren, een verdwenen trede of een nieuwe botsing breekt dit af.
	if horizontal_motion.normalized().dot(_step_support_direction) < 0.7:
		_step_support_remaining = 0.0
		return false
	var support_probe := global_transform
	support_probe.origin = _step_support_point + Vector3.UP * 0.05
	var support := KinematicCollision3D.new()
	if not test_move(support_probe, Vector3.DOWN * 0.1, support):
		_step_support_remaining = 0.0
		return false
	if support.get_normal().dot(Vector3.UP) < cos(floor_max_angle):
		_step_support_remaining = 0.0
		return false
	var actual_destination := global_position + horizontal_motion
	actual_destination.y = _step_support_point.y
	if test_move(global_transform, actual_destination - global_position):
		_step_support_remaining = 0.0
		return false
	_last_step_height = maxf(actual_destination.y - global_position.y, 0.0)
	global_position = actual_destination
	_step_support_remaining = maxf(_step_support_remaining - horizontal_motion.length(), 0.0)
	return true


func _update_debug_arrows() -> void:
	_debug_arrows.visible = debug_enabled
	_update_arrow(_input_arrow, _input_direction)
	_update_arrow(_movement_arrow, _movement_direction)


func _update_arrow(arrow: Node3D, world_direction: Vector3) -> void:
	arrow.visible = not world_direction.is_zero_approx()
	if arrow.visible:
		var local_direction := global_basis.inverse() * world_direction
		arrow.rotation.y = atan2(-local_direction.x, -local_direction.z)


func get_debug_state() -> Dictionary:
	var state := "lucht"
	if is_on_floor() or _step_support_remaining > 0.0:
		state = "sprint" if _sprint_requested else "lopen"
		if _actual_speed < 0.02:
			state = "stilstand"
	return {
		"display_name": display_name,
		"speed": _actual_speed,
		"motion_mode": state,
		"input_direction": _input_direction,
		"movement_direction": _movement_direction,
		"facing_direction": -global_basis.z,
		"jump_profile": _jump_profile,
		"jump_height": _jump_height,
		"launch_speed": _launch_speed,
		"camera_distance": _camera_distance,
		"camera_actual_distance": _camera_arm.get_hit_length(),
		"first_person": _camera_distance == 0.0,
		"step_height": step_height,
		"last_step_height": _last_step_height,
		"debug_enabled": debug_enabled,
	}


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if capsule_height < capsule_radius * 2.0:
		warnings.append("Capsulehoogte moet minimaal twee keer de radius zijn; de proef gebruikt die minimumhoogte.")
	if walk_back_ratio >= walk_side_ratio or sprint_back_ratio >= sprint_side_ratio:
		warnings.append("Gebruik achterwaarts < zijwaarts < vooruit voor de afgesproken richtingssnelheden.")
	if sprint_forward_speed <= walk_forward_speed:
		warnings.append("Sprint moet sneller zijn dan lopen om een apart sprint-spronganker te bereiken.")
	if camera_max_distance <= capsule_radius + 0.1:
		warnings.append("Deze maximale camera-afstand blijft binnen de eigen capsule; gebruik een grotere afstand voor third person.")
	return warnings
