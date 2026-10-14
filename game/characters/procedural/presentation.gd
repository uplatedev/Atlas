@tool
class_name AtlasCharacterPresentation
extends Node3D
## Procedurele voeten en lichaam, uitsluitend presentatie. Motor bepaalt pasvlucht.

const TestHumanoid = preload("res://characters/procedural/test_humanoid.gd")
const PoseModifier = preload("res://characters/procedural/pose_modifier.gd")
const IdleMotion = preload("res://characters/procedural/idle_motion.gd")
const GaitStyle = preload("res://characters/procedural/gait_style.gd")
const FootPhase = preload("res://characters/procedural/foot_phase.gd")
const TurnStepPlanner = preload("res://characters/procedural/turn_step_planner.gd")

var _character: Node3D
var _profile: AtlasCharacterBodyProfile
var _visual: Node3D
var _skeleton: Skeleton3D
var _modifier: SkeletonModifier3D
var _legs: Array[PackedInt32Array] = []
var _arms: Array[PackedInt32Array] = []
var _leg_lengths: Array[Vector2] = []
var _arm_lengths: Array[Vector2] = []
var _rest_feet: Array[Vector3] = []
var _rest_foot_basis: Array[Basis] = []
var _targets: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _contact_directions: Array[Vector3] = [Vector3.FORWARD, Vector3.FORWARD]
var _pose_delta: float = 1.0 / 60.0
var _jog_pose: float = 0.0
var _arm_phase_offset: float = 0.0
var _contact_forwards: Array[Vector3] = [Vector3.FORWARD, Vector3.FORWARD]
var _foot_roll: Array[float] = [0.0, 0.0]
var _foot_pivots: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _ground_points: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _ground_known: Array[bool] = [false, false]
var _sole_clearance_before: Array[float] = [INF, INF]
var _sole_clearance_after: Array[float] = [INF, INF]
var _sole_corrections: Array[float] = [0.0, 0.0]
var _sole_replans: int = 0
var _free_plan_origins: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _toe_lengths: Array[float] = [0.14, 0.14]
var _contact_sides: Array[int] = []
var _foot_phase := FootPhase.new()
var _walk_overlap_release_step: Array[int] = [-1, -1]
var _contacts: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _normals: Array[Vector3] = [Vector3.UP, Vector3.UP]
var _locked: Array[bool] = [false, false]
var _swing_phase_origin: Array[float] = [0.0, 0.0]
var _swing_style: String = ""
var _swing_from: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _pelvis: int = -1
var _spine: int = -1
var _head: int = -1
var _measured_leg_length: float = 0.76
var _ankle_height: float = 0.1
var _hip_height: float = 0.85
var _speed: float = 0.0
var _motion_profile: String = "jog"
var _strafe_amount: float = 0.0
var _gait_yaw: float = 0.0
var _phase: float = 0.0
var _step_index: int = 0
var _air_kind: String = "none"
var _posture: String = "staan"
var _sliding: bool = false
var _body_transform: Transform3D = Transform3D.IDENTITY
var _direction: Vector3 = Vector3.FORWARD
var _previous_velocity: Vector3 = Vector3.ZERO
var _lean: float = 0.0
var _jump_pose: float = 0.0
var _relaxed_walk: bool = false
var _jogging: bool = true
var _running_pose: float = 0.0
var _walking_pose: float = 0.0
var _gait_compression: float = 0.0
var _compression: float = 0.0
var _compression_velocity: float = 0.0
var _last_compression_step: int = -1
var _last_turn_compression_step: int = -1
var _compression_events: int = 0
var _head_yaw: float = 0.0
var _head_pitch: float = 0.0
var _initialized_pose: bool = false
var _rays_last_frame: int = 0
var _rays_total: int = 0
var _max_reach_error: float = 0.0
var _max_planted_error: float = 0.0
var _free_target_adjustment: Array[float] = [0.0, 0.0]
var _max_free_target_adjustment: float = 0.0
var _planned_pelvis_drop: float = 0.0
var _released_overreach: int = 0
var _frame_usec: int = 0
var _max_frame_usec: int = 0
var _driven_bones: PackedInt32Array = []
var _pose_previous: Array[Transform3D] = []
var _pose_current: Array[Transform3D] = []
var _idle := IdleMotion.new()
var _turn_planner := TurnStepPlanner.new()
var _turn_body_offset: float = 0.0
var _turn_torso_yaw: float = 0.0
var _turn_torso_ready: bool = false
var _turn_foot_yaws: Array[float] = [0.0, 0.0]
var _turn_release_remaining: float = 0.0
var _stationary_seconds: float = 0.0

func setup(character: Node3D, profile: AtlasCharacterBodyProfile) -> void:
	_character = character
	_profile = profile
	if _visual != null:
		remove_child(_visual)
		_visual.queue_free()
	_visual = profile.visual_scene.instantiate() as Node3D if profile.visual_scene != null else TestHumanoid.build(profile.test_body, profile.test_color)
	if _visual == null:
		push_error("Lichaamsmodel moet een Node3D-scene bevatten.")
		return
	add_child(_visual)
	_skeleton = _find_skeleton(_visual)
	if _skeleton == null:
		push_error("Lichaamsmodel mist Skeleton3D; kies een model met skelet.")
		return
	# Het model is de enige posebron: geen ingebakken Blender-animatie naast IK.
	for mixer in _visual.find_children("*", "AnimationMixer", true, false):
		mixer.active = false
	_pelvis = _skeleton.find_bone(profile.pelvis_bone)
	_spine = _skeleton.find_bone(profile.spine_bone)
	_head = _skeleton.find_bone(profile.head_bone)
	_legs.clear()
	_arms.clear()
	_leg_lengths.clear()
	_arm_lengths.clear()
	_rest_feet.clear()
	_rest_foot_basis.clear()
	var total_length := 0.0
	var ankle_total := 0.0
	for side in range(2):
		var leg := _indices(profile.leg_bones(side))
		var arm := _indices(profile.arm_bones(side))
		_legs.append(leg)
		_arms.append(arm)
		var lengths := _measure(leg)
		_leg_lengths.append(lengths)
		_arm_lengths.append(_measure(arm))
		total_length += lengths.x + lengths.y
		var foot := to_local(_rest_world(leg[2])) if _valid_chain(leg) else Vector3((-1.0 if side == 0 else 1.0) * 0.1, 0.1, 0.0)
		_rest_feet.append(foot)
		_rest_foot_basis.append((character.global_basis.inverse() * _skeleton.global_basis * _skeleton.get_bone_global_rest(leg[2]).basis).orthonormalized() if _valid_chain(leg) else Basis.IDENTITY)
		ankle_total += foot.y
	_measured_leg_length = maxf(total_length * 0.5, 0.05)
	for side in range(2):
		_toe_lengths[side] = _measured_leg_length * 0.20
		if _valid_chain(_legs[side]):
			for child in _skeleton.get_bone_children(_legs[side][2]):
				var toe_delta := _rest_world(child) - _rest_world(_legs[side][2])
				_toe_lengths[side] = clampf(Vector2(toe_delta.x, toe_delta.z).length(), _measured_leg_length * 0.08, _measured_leg_length * 0.30)
				break
	_ankle_height = clampf(ankle_total * 0.5, 0.025, _measured_leg_length * 0.3)
	_hip_height = to_local(_rest_world(_pelvis)).y if _pelvis >= 0 else _measured_leg_length
	if character.has_method("set_procedural_leg_length"):
		character.set_procedural_leg_length(_measured_leg_length)
	_driven_bones.clear()
	for bone in [_pelvis, _spine, _head]:
		if bone >= 0 and not _driven_bones.has(bone):
			_driven_bones.append(bone)
	for chain in _legs + _arms:
		for bone in chain:
			if bone >= 0 and not _driven_bones.has(bone):
				_driven_bones.append(bone)
	_modifier = SkeletonModifier3D.new()
	_modifier.set_script(PoseModifier)
	_modifier.set("driver", self)
	_modifier.name = "ProcedurelePose"
	_skeleton.add_child(_modifier)
	_skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_IDLE
	_idle.setup(_visual, _profile)
	_set_layers(_visual, character.get_presentation_layer() if character.has_method("get_presentation_layer") else 0)
	reset_pose()
	update_configuration_warnings()

func get_leg_length() -> float:
	return _measured_leg_length

func reset_pose() -> void:
	_idle.reset()
	_turn_planner.reset(_character.global_rotation.y if _character != null else 0.0)
	_turn_body_offset = 0.0
	_turn_torso_yaw = 0.0
	_turn_torso_ready = false
	_turn_release_remaining = 0.0
	_pose_previous.clear()
	_pose_current.clear()
	_locked = [false, false]
	_foot_roll = [0.0, 0.0]
	_foot_phase = FootPhase.new()
	_free_target_adjustment = [0.0, 0.0]
	_contact_sides.clear()
	_walk_overlap_release_step = [-1, -1]
	_swing_phase_origin = [0.0, 0.0]
	_swing_style = ""
	_initialized_pose = false
	_speed = 0.0
	_motion_profile = "jog"
	_relaxed_walk = false
	_jogging = true
	_running_pose = 0.0
	_jog_pose = 0.0
	_arm_phase_offset = 0.0
	_walking_pose = 0.0
	_strafe_amount = 0.0
	_gait_yaw = 0.0
	_phase = 0.0
	_step_index = 0
	_air_kind = "none"
	_posture = "staan"
	_sliding = false
	_previous_velocity = Vector3.ZERO
	_lean = 0.0
	_jump_pose = 0.0
	_gait_compression = 0.0
	_compression = 0.0
	_compression_velocity = 0.0
	_last_compression_step = -1
	_last_turn_compression_step = -1
	_compression_events = 0
	_head_yaw = 0.0
	_head_pitch = 0.0
	_max_reach_error = 0.0
	_max_planted_error = 0.0
	_max_free_target_adjustment = 0.0
	_planned_pelvis_drop = 0.0
	_stationary_seconds = 0.0
	_released_overreach = 0
	if _skeleton != null:
		_skeleton.reset_bone_poses()
		_body_transform = _character.global_transform
		for side in range(2):
			var rest := _rest_feet[side]
			rest.x *= _profile.get_stance_width_scale(0.0)
			_targets[side] = _body_transform * rest
			_contacts[side] = _targets[side] - Vector3.UP * _ankle_height
			_swing_from[side] = _body_transform.affine_inverse() * _targets[side]

func consume_frame(frame: Variant) -> void:
	if _skeleton == null or _profile == null:
		return
	var previous_arm_phase := float(_step_index) + _pose_phase() + _arm_phase_offset
	var started := Time.get_ticks_usec()
	_pose_delta = frame.delta
	_rays_last_frame = 0
	_ground_known = [false, false]
	_sole_clearance_before = [INF, INF]
	_sole_clearance_after = [INF, INF]
	_sole_corrections = [0.0, 0.0]
	_sole_replans = 0
	_contact_sides.clear()
	_body_transform = frame.body_transform
	_speed = frame.horizontal_speed
	var motion: Variant = frame.get("motion_profile")
	_motion_profile = str(motion) if motion != null else "jog"
	_phase = frame.gait_phase
	var changed_step: bool = frame.step_index != _step_index
	_step_index = frame.step_index
	var was_jump := _air_kind in ["jump", "fall"]
	_air_kind = frame.air_kind
	_jump_pose = move_toward(_jump_pose, 1.0 if _air_kind in ["jump", "fall"] else 0.0, frame.delta * 9.0)
	if _character.has_method("get_look_input"):
		var look: Vector2 = _character.get_look_input()
		_head_yaw = wrapf(look.x - _body_transform.basis.get_euler().y, -PI, PI)
		_head_pitch = look.y
	_posture = frame.posture
	_sliding = frame.sliding
	_relaxed_walk = _motion_profile == "walk"
	_jogging = _motion_profile == "jog"
	var style_rate: float = frame.delta / maxf(_profile.gait_blend_time, 0.01)
	_running_pose = move_toward(_running_pose, _requested_running_blend(), style_rate)
	_jog_pose = move_toward(_jog_pose, 1.0 if _jogging and _speed > 0.1 else 0.0, style_rate)
	_walking_pose = move_toward(_walking_pose, 1.0 if _relaxed_walk else 0.0, style_rate)
	var horizontal := Vector3(frame.body_velocity.x, 0.0, frame.body_velocity.z)
	if horizontal.length_squared() > 0.001:
		_direction = horizontal.normalized()
	var acceleration := (horizontal - _previous_velocity) / maxf(frame.delta, 0.001)
	_previous_velocity = horizontal
	var target_lean := clampf(acceleration.dot(-_body_transform.basis.z) * 0.005 + _speed * 0.008, -0.12, 0.18) * _profile.torso_lean_scale
	_lean = lerpf(_lean, target_lean, 1.0 - exp(-frame.delta * 10.0))
	var standing := _posture in ["staan", "stand"] and not _sliding
	var supported: bool = frame.supported
	var stance := posmod(_step_index, 2)
	var stationary := _speed < 0.10
	var turn_was_releasing := _turn_release_remaining > 0.0
	var movement_requested: bool = frame.get("movement_requested") == true
	_stationary_seconds = _stationary_seconds + frame.delta if stationary and supported else 0.0
	# Een korte omkeernulpassage start geen rustherplant. Lang tegen een muur
	# drukken laat hoofd/romp/bijstappen wel werken, ook met ingedrukte loopinvoer.
	# Een echte nog over te dragen draai bewaart de bestaande vrije-voetlanding;
	# die uitstellen zou de motor al door twee stilstaande pins laten draaien.
	var turning_to_transfer := absf(wrapf(frame.body_transform.basis.get_euler().y - _turn_planner.pose_yaw, -PI, PI)) > 0.01
	var idle_ready := not movement_requested or _stationary_seconds >= 0.12 or turning_to_transfer
	if stationary and idle_ready:
		_walk_overlap_release_step = [-1, -1]
	_update_turn_plan(frame, standing and stationary and idle_ready and supported and not was_jump and not frame.stride_landed)
	var reversing_pause := standing and stationary and supported and not idle_ready and _initialized_pose and (_locked[0] or _locked[1]) and not was_jump
	if reversing_pause:
		# Ook de visuele loopas wacht door de nulpassage heen; naar de rustas
		# terugdraaien zou de bewaarde voetbanen onder het bekken laten kruisen.
		_body_transform.basis *= Basis(Vector3.UP, _gait_yaw)
	else:
		_update_gait_basis(frame, standing, changed_step)
	_foot_phase.sample(frame, _relaxed_walk, _setting("walk_double_support_ratio", 0.18))
	if frame.get("direction_step") == true:
		# Een vroege voetwissel bij omkeren mag de armen niet midden in hun
		# zwaai spiegelen. Draag hun bereikte fase over en sluit rustig aan.
		_arm_phase_offset = wrapf(previous_arm_phase - float(_step_index) - _pose_phase(), -1.0, 1.0)
	else:
		_arm_phase_offset = lerpf(_arm_phase_offset, 0.0, 1.0 - exp(-frame.delta / maxf(_profile.gait_blend_time * 2.0, 0.02)))
		if absf(_arm_phase_offset) < 0.000001:
			_arm_phase_offset = 0.0
	var next_swing_style := "walk" if _relaxed_walk else "stride"
	var swing_style_changed := _swing_style != "" and next_swing_style != _swing_style
	_swing_style = next_swing_style
	var moving_stride := standing and not stationary and _air_kind in ["none", "stride"]
	var length := minf(_measured_leg_length * _profile.step_length_ratio, _measured_leg_length * 0.85)
	var running := _running_blend()
	var lift := _profile.foot_lift_ratio * _measured_leg_length * lerpf(_profile.walk_lift_ratio, 1.0, running)
	var lateral_lift := _profile.strafe_walk_foot_lift_ratio if _relaxed_walk else (_profile.strafe_jog_foot_lift_ratio if _jogging else _profile.strafe_run_foot_lift_ratio)
	lift = lerpf(lift, _measured_leg_length * lateral_lift, _strafe_amount)
	# Nieuwe steun wordt eerst bewezen; pas daarna mag de oude overlap los.
	for side in [stance, 1 - stance]:
		# Een omkeernulpassage is geen rustcontact: bewaar de bereikte vrije voet
		# en de echte steun totdat de nieuwe bewegingsrichting weer een pas plant.
		if reversing_pause:
			continue
		var previous_target := _targets[side]
		_foot_roll[side] = 0.0
		if _consume_turn_foot(frame, side):
			continue
		if (was_jump and supported) or changed_step:
			_swing_phase_origin[side] = 0.0
			_swing_from[side] = _body_transform.affine_inverse() * _targets[side]
		if swing_style_changed and not _locked[side]:
			_swing_from[side] = _body_transform.affine_inverse() * previous_target
			_swing_phase_origin[side] = _foot_phase.swing[side]
		var rest := _rest_feet[side]
		rest.x *= _profile.get_stance_width_scale(_speed, standing)
		var base := _body_transform * Vector3(rest.x, 0.0, 0.0)
		var ahead_length := length * 0.48
		if _relaxed_walk or _jogging or _strafe_amount > 0.001:
			var contact_seconds := _foot_phase.support_seconds * (1.0 + _foot_phase.overlap if _relaxed_walk else 1.0)
			ahead_length = clampf(_speed * contact_seconds * 0.5, _measured_leg_length * 0.12, _measured_leg_length * 0.50)
		var ahead := _direction * ahead_length
		var destination := base + ahead if moving_stride else base
		var new_cycle_contact: bool = (frame.stride_landed or frame.ground_step) and side == stance
		if _turn_release_remaining > 0.0 and supported and side == stance and (frame.stride_landed or not _locked[side]):
			# Eerste loopcontact mag de afgeronde bijstap niet naar een verre voorspelling verplaatsen.
			var reached := previous_target - Vector3.UP * _ankle_height
			destination = reached.move_toward(destination, _measured_leg_length * 0.08)
		if moving_stride and _strafe_amount > 0.001 and supported and _foot_phase.contact[side] and _foot_phase.contact[1 - side] and (not _locked[side] or new_cycle_contact) and _locked[1 - side]:
			# Een nieuwe landing mag de nog vaste andere voet niet voorbijgaan.
			# Plan de bestemming vóór de bestaande grondmeting; verplaats nooit de pin.
			var right := _pose_lateral_axis().slide(Vector3.UP).normalized()
			var sign_side := -1.0 if side == 0 else 1.0
			var separation := (destination + Vector3.UP * _ankle_height - _targets[1 - side]).dot(right) * sign_side
			destination += right * sign_side * maxf(0.0, _measured_leg_length * 0.16 - separation)
		var hit: Dictionary = {"position": _contacts[side], "normal": _normals[side]} if stationary and _locked[side] and supported and _initialized_pose else _ground_at(destination)
		var has_ground := not hit.is_empty()
		var ground := Vector3(hit.position) if has_ground else base - Vector3.UP * maxf(0.0, _body_transform.origin.y - _contacts[side].y)
		_ground_known[side] = has_ground
		if has_ground:
			_normals[side] = hit.normal
			_ground_points[side] = hit.position
		var ankle := ground + Vector3.UP * _ankle_height
		var early_walk_swing := false
		var may_plant := supported and standing and (stationary or _foot_phase.contact[side])
		if moving_stride and _relaxed_walk and side != stance:
			# Na een omkering draagt de nieuwe voet al. Rek de oude pin niet nog
			# een overlap verder in de verlaten bewegingsrichting uit.
			var narrow_overlap := (_targets[1] - _targets[0]).dot(_pose_lateral_axis()) < _measured_leg_length * 0.12
			if _locked[stance] and (_direction.dot(_contact_directions[side]) < 0.75 or narrow_overlap or _walk_overlap_release_step[side] == _step_index):
				_walk_overlap_release_step[side] = _step_index
				may_plant = false
				early_walk_swing = true
				_foot_phase.swing[side] = _phase
		# Bij een externe verplaatsing buiten fysiek beenbereik wordt contact expliciet
		# losgelaten. Tijdens gewone steun blijft het wereldpunt onveranderd.
		# Een gewone afzet/voetwissel mag niet als bereiknoodloslating meetellen:
		# de oude lock is hier nog zichtbaar, maar deze voet heeft al geen steunrecht meer.
		var overreach := may_plant and _locked[side] and Vector2(_contacts[side].x - base.x, _contacts[side].z - base.z).length() > _measured_leg_length * 0.9
		if overreach:
			may_plant = false
			_released_overreach += 1
		if may_plant and has_ground and (not _locked[side] or not _initialized_pose or new_cycle_contact):
			# Contact sluit op echte motorlanding of gesteunde voetwissel, nooit op voorspelde luchtsteun.
			_contacts[side] = ground
			_walk_overlap_release_step[side] = -1
			_contact_forwards[side] = -_body_transform.basis.z
			_contact_directions[side] = _direction
			_locked[side] = true
			var audible_contact: bool = new_cycle_contact and side == stance
			if audible_contact and _initialized_pose and _speed > 0.10:
				frame.foot_contacts.append(ground)
				_contact_sides.append(side)
		if not may_plant or not has_ground:
			if _locked[side]:
				_swing_phase_origin[side] = _foot_phase.swing[side] if swing_style_changed else 0.0
				_swing_from[side] = _body_transform.affine_inverse() * previous_target
			_locked[side] = false
		if not _initialized_pose:
			_swing_from[side] = _body_transform.affine_inverse() * ankle
			_contacts[side] = ground
		if _locked[side]:
			_targets[side] = _contacts[side] + Vector3.UP * _ankle_height
			if moving_stride and (_walking_pose > 0.0 or _jog_pose > 0.0):
				_foot_roll[side] = _foot_phase.roll(side, _setting("walk_heel_strike_degrees", 12.0), _setting("walk_toe_off_degrees", 24.0)) * _walking_pose
				_foot_roll[side] += _foot_phase.roll(side, 0.0, _profile.ankle_swing_degrees * 2.0) * _jog_pose
				_foot_roll[side] *= lerpf(1.0, 0.45, _strafe_amount)
				_targets[side] = _rolled_ankle(side, _foot_roll[side])
		elif moving_stride:
			var progress := _swing_progress(side)
			var speed_mix := clampf(_speed / maxf(_profile.reference_speed, 0.1), 0.0, 1.0)
			var heel_height := _measured_leg_length * _profile.heel_recovery_ratio * lerpf(_profile.walk_lift_ratio * 0.12, 1.0, running) * speed_mix
			heel_height = lerpf(heel_height, _measured_leg_length * _profile.heel_recovery_ratio * 0.45 * clampf(_speed / 3.0, 0.0, 1.0), _jog_pose)
			heel_height *= lerpf(1.0, 0.40, _strafe_amount)
			var lateral_ahead := _body_transform.basis.x * ahead.dot(_body_transform.basis.x)
			# Zijdelings herstel blijft in de toekomstige voetbaan; achteruit zwaaien
			# over de andere baan zou de benen tijdens strafing laten kruisen.
			var recovery := base - ahead * 0.6 + lateral_ahead * 1.6
			var next_target := ankle if side != stance else recovery + Vector3.UP * (_ankle_height + heel_height)
			# Losse voeten reizen met het lichaam. Een oud wereldcontact hier vasthouden
			# rekt het been tijdens pasvlucht uit en laat het bij de voetwissel terugspringen.
			var from_world := _body_transform * _swing_from[side]
			var travel_progress := lerpf(smoothstep(0.0, 1.0, progress), 1.0 - pow(1.0 - progress, 2.0), 1.0 if early_walk_swing else (_jog_pose if side == stance else 0.0))
			_targets[side] = from_world.lerp(next_target, travel_progress)
			_targets[side].y += _profile.get_swing_lift(progress) * lift
			if not supported:
				_targets[side].y = maxf(_targets[side].y, _body_transform.origin.y + _ankle_height * 0.7)
		elif not supported:
			_targets[side] = _body_transform * Vector3(rest.x, _ankle_height + _measured_leg_length * 0.16, 0.08 if side == 0 else -0.10)
		else:
			_targets[side] = ankle
		if not standing:
			_locked[side] = false
			if _sliding:
				# Knieslide: schenen en enkels liggen achter de lage knie, niet vóór de romp.
				_targets[side] = _body_transform * Vector3(rest.x * 1.12, _ankle_height, _leg_lengths[side].y * 0.94)
			else:
				_targets[side] = _body_transform * Vector3(rest.x * 1.3, _ankle_height, _measured_leg_length * 0.6 if _posture in ["liggen", "prone"] else 0.04)
		if (_turn_release_remaining > 0.0 or turn_was_releasing) and not _locked[side] and standing:
			var travel_limit: float = _speed * frame.delta + _measured_leg_length * frame.delta * 5.0
			if previous_target.distance_to(_targets[side]) > travel_limit:
				# Laat de begrenzing pas los wanneer het gewone zwaaidoel is ingehaald.
				_turn_release_remaining = maxf(_turn_release_remaining, frame.delta * 2.0)
				_targets[side] = previous_target.move_toward(_targets[side], travel_limit)
	if standing and moving_stride:
		_keep_turn_feet_separated()
	_initialized_pose = true
	_update_compression(frame, was_jump)
	# Idle has no clock in the render pass and never owns motor/contact state.
	_idle.advance(frame.delta, standing and stationary and supported and _air_kind == "none" and _turn_planner.active_side < 0)
	_cache_physics_pose()
	_frame_usec = Time.get_ticks_usec() - started
	_max_frame_usec = maxi(_max_frame_usec, _frame_usec)

func _keep_turn_feet_separated() -> void:
	# Bij snelle loopinvoer draait de capsule al terwijl de oude steunvoet vast
	# blijft. Dit geldt ook voor zijwaartse passen; verplaats alleen vrije voeten.
	var right := _pose_lateral_axis()
	var gap := (_targets[1] - _targets[0]).dot(right)
	var correction := _measured_leg_length * 0.16 - gap
	if correction <= 0.0:
		return
	if not _locked[0] and not _locked[1]:
		_targets[0] -= right * correction * 0.5
		_targets[1] += right * correction * 0.5
	elif not _locked[0]:
		_targets[0] -= right * correction
	elif not _locked[1]:
		_targets[1] += right * correction
	for side in range(2):
		if not _locked[side]:
			_swing_from[side] = _body_transform.affine_inverse() * _targets[side]

func _pose_lateral_axis() -> Vector3:
	# Voetbanen volgen de werkelijke heupas, inclusief de kleine bekkenzwaai.
	# Alleen de capsule-as gebruiken kan diagonale enkels alsnog laten kruisen.
	var wave := cos((float(_step_index) + _pose_phase()) * PI) * clampf(_speed / 0.6, 0.0, 1.0)
	var twist := -wave * deg_to_rad(_profile.body_twist_degrees) * lerpf(0.25, 1.0, _running_blend())
	var roll := wave * deg_to_rad(_profile.body_roll_degrees) * lerpf(1.0, 0.45, _running_blend())
	return _body_transform.basis.x.rotated(Vector3.UP, twist).rotated(-_body_transform.basis.z, roll)

func _update_gait_basis(frame: Variant, standing: bool, _changed_step: bool) -> void:
	var local_velocity: Vector3 = frame.body_transform.basis.inverse() * frame.body_velocity
	_strafe_amount = GaitStyle.lateral_amount(local_velocity) if standing else 0.0
	var maximum: float = _profile.strafe_walk_yaw_degrees if _relaxed_walk else (_profile.strafe_jog_yaw_degrees if _jogging else _profile.strafe_run_yaw_degrees)
	var desired := GaitStyle.movement_yaw(local_velocity, maximum) if standing else 0.0
	var previous := _gait_yaw
	_gait_yaw = lerp_angle(_gait_yaw, desired, 1.0 - exp(-frame.delta * 14.0))
	if absf(_gait_yaw) < 0.000001 and desired == 0.0:
		_gait_yaw = 0.0
	# Een nieuwe richting draagt de bereikte vrije voetpositie over; steun blijft wereldvast.
	var change := Basis(Vector3.UP, previous - _gait_yaw)
	for side in range(2):
		_swing_from[side] = change * _swing_from[side]
	_body_transform.basis *= Basis(Vector3.UP, _gait_yaw)

func _setting(key: String, fallback: float) -> float:
	var value: Variant = _profile.get(key)
	return float(value) if value != null else fallback

func _rolled_ankle(side: int, pitch: float) -> Vector3:
	var forward := _contact_forwards[side].slide(_normals[side]).normalized()
	var ground_basis := Basis(forward.cross(_normals[side]).normalized(), _normals[side], -forward)
	# Het grondanker blijft hetzelfde; alleen de enkel draait geometrisch om
	# de hiel bij ontvangen en om de bal van de voet bij afzetten.
	var pivot_z := _toe_lengths[side] * 0.25 if pitch >= 0.0 else -_toe_lengths[side]
	_foot_pivots[side] = _contacts[side] + ground_basis * Vector3(0.0, 0.0, pivot_z)
	return _foot_pivots[side] + ground_basis * (Basis(Vector3.RIGHT, pitch) * Vector3(0.0, _ankle_height, -pivot_z))

func _swing_progress(side: int) -> float:
	var raw: float = _foot_phase.swing[side]
	if raw < _swing_phase_origin[side] - 0.001:
		_swing_phase_origin[side] = 0.0
	return clampf((raw - _swing_phase_origin[side]) / maxf(1.0 - _swing_phase_origin[side], 0.001), 0.0, 1.0)

func _pose_phase() -> float:
	return _foot_phase.uniform_phase

func _running_blend() -> float:
	return _running_pose

func _requested_running_blend() -> float:
	if _speed < 0.1:
		return 0.0
	if _relaxed_walk:
		return 0.0
	if _jogging:
		return _profile.jog_pose_blend
	if _motion_profile == "run" and _speed > 0.1:
		return 1.0
	return smoothstep(0.50, 0.90, clampf(_speed / maxf(_profile.reference_speed, 0.1), 0.0, 1.0))

func _update_compression(frame: Variant, was_jump: bool) -> void:
	_gait_compression = 0.0
	if _jog_pose > 0.0 and frame.supported and _speed > 0.1 and _posture in ["staan", "stand"] and not _sliding:
		# Eén compressieboog tijdens de echte steun. Geen tweede trillende pasveer
		# bovenop capsulevlucht en beenbereik; sprong/val houdt de impactveer.
		var contact_progress: float = _phase if _foot_phase.supported_cycle else clampf(_phase * 2.0, 0.0, 1.0)
		_gait_compression = _measured_leg_length * _profile.step_compression_ratio * sin(contact_progress * PI) * _jog_pose
	if _posture not in ["staan", "stand"] or _sliding:
		_compression = 0.0
		_compression_velocity = 0.0
		return
	var amplitude := 0.0
	if frame.supported and was_jump:
		var incoming: Variant = frame.get("incoming_velocity")
		var impact := maxf(0.0, -incoming.y) if incoming is Vector3 else 0.0
		amplitude = _measured_leg_length * _profile.landing_compression_ratio * clampf(impact / 8.0, 0.25, 1.0)
	elif frame.supported and frame.turn_step_landed and not frame.foot_contacts.is_empty() and frame.turn_step_index != _last_turn_compression_step:
		_last_turn_compression_step = frame.turn_step_index
		amplitude = _measured_leg_length * _profile.step_compression_ratio * 0.4
	elif not _relaxed_walk and not _jogging and frame.supported and (frame.stride_landed or frame.ground_step) and not frame.foot_contacts.is_empty() and _step_index != _last_compression_step:
		_last_compression_step = _step_index
		var speed_mix := clampf(_speed / maxf(_profile.reference_speed, 0.1), 0.0, 1.0)
		amplitude = _measured_leg_length * _profile.step_compression_ratio * lerpf(0.4, 1.0, speed_mix) * (1.0 - _jog_pose) * (1.0 - _walking_pose)
	var omega := 1.0 / maxf(_profile.compression_peak_time, 0.01)
	if amplitude > 0.0:
		_compression_events += 1
		# Een impuls bereikt na 1/omega zijn piek. Niet opstapelen bij snelle contacten.
		var remaining := maxf(0.0, amplitude - _compression)
		_compression_velocity = maxf(_compression_velocity, remaining * omega * exp(1.0))
	# Exacte kritisch gedempte veer: één gesloten berekening, geen iteratieve solver,
	# geen nieuwe motorveer en geen eigen klok die voetcontacten voorspelt.
	var delta: float = maxf(frame.delta, 0.0)
	var combined := _compression_velocity + omega * _compression
	var decay := exp(-omega * delta)
	_compression = maxf(0.0, (_compression + combined * delta) * decay)
	_compression_velocity = (_compression_velocity - omega * combined * delta) * decay
	var limit := _measured_leg_length * 0.18
	if _compression > limit:
		_compression = limit
		_compression_velocity = minf(_compression_velocity, 0.0)
	if _compression < 0.000001 and absf(_compression_velocity) < 0.00001:
		_compression = 0.0
		_compression_velocity = 0.0

func _update_turn_plan(frame: Variant, allowed: bool) -> void:
	_turn_planner.step_duration = _profile.turn_step_duration
	_turn_planner.fast_step_duration = _profile.turn_step_fast_duration
	_turn_planner.speed_adaptation = _profile.turn_step_speed_adaptation
	_turn_planner.max_pair_angle = deg_to_rad(clampf(_profile.turn_step_angle_degrees, 20.0, 70.0))
	var motor_yaw: float = frame.body_transform.basis.get_euler().y
	var rest: Array[Vector3] = []
	for foot in _rest_feet:
		rest.append(Vector3(foot.x * _profile.get_stance_width_scale(0.0), 0.0, 0.0))
	# Loopinvoer geeft de pose direct aan de loopplanner; de capsule wacht niet
	# op een stilstaande bijstap. Voetdoelen nemen hun bereikte positie mee.
	if allowed and not _turn_planner.enabled:
		for side in range(2):
			if not _locked[side]:
				# Een uitlopende vrije voet begint waar hij nu is, nooit op een oud contact.
				_contacts[side] = _targets[side] - Vector3.UP * _ankle_height
				_turn_planner.request_replant(side, _contacts[side])
	if allowed and _turn_planner.active_side < 0 and _locked[0] and _locked[1]:
		var gap := (_contacts[1] - _contacts[0]).dot(Basis(Vector3.UP, _turn_planner.pose_yaw).x)
		var rest_gap := rest[1].x - rest[0].x
		if gap < minf(_measured_leg_length * 0.12, rest_gap * 0.75) or gap > maxf(_measured_leg_length * 0.6, rest_gap * 1.25):
			# Bewaar een scheve ruststand; herstel alleen gekruiste of te wijde sporen.
			var side := 0 if _contacts[0].distance_squared_to(frame.body_transform.origin) > _contacts[1].distance_squared_to(frame.body_transform.origin) else 1
			_turn_planner.request_replant(side)
	if allowed and _turn_planner.active_side < 0:
		# Alleen een werkelijk onbereikbare steun vraagt een veiligheidsherplaatsing.
		# Een andere afstand tot de ideale ruststand is op zichzelf geen fout.
		for side in range(2):
			var offset: Vector3 = _contacts[side] - frame.body_transform.origin
			if Vector2(offset.x, offset.z).length() > _measured_leg_length * 0.8:
				_turn_planner.request_replant(side)
				break
	var use_turn: bool = allowed and _initialized_pose
	var look: Vector2 = _character.get_look_input() if _character.has_method("get_look_input") else Vector2(motor_yaw, 0.0)
	var relative_look := wrapf(look.x - _turn_planner.pose_yaw, -PI, PI)
	var torso_limit := deg_to_rad(clampf(_profile.turn_torso_max_degrees, 0.0, 50.0))
	var torso_target := clampf(relative_look * 0.65, -torso_limit, torso_limit) if allowed else 0.0
	_turn_torso_yaw = lerpf(_turn_torso_yaw, torso_target, 1.0 - exp(-frame.delta * 9.0))
	# Iedere landing eindigt de toestemming. De werkelijke borst en huidige
	# kijkrichting bepalen de volgende stap, niet een oude uitlijnopdracht.
	var torso_before_step := minf(deg_to_rad(_profile.turn_torso_before_step_degrees), torso_limit * 0.85)
	_turn_torso_ready = use_turn and absf(_turn_torso_yaw) >= torso_before_step and _turn_torso_yaw * relative_look >= 0.0
	if _turn_planner.enabled and not use_turn and (_turn_planner.active_side >= 0 or absf(_turn_body_offset) > 0.01):
		# Begeleid de eerste aansluitende passen; daarna alleen zolang een vrij doel nog wordt ingehaald.
		_turn_release_remaining = 0.4
	else:
		_turn_release_remaining = maxf(0.0, _turn_release_remaining - frame.delta)
	_turn_planner.advance(frame.delta, motor_yaw, use_turn, frame.body_transform.origin, rest, _contacts, _turn_torso_ready)
	_turn_body_offset = wrapf(_turn_planner.pose_yaw - motor_yaw, -PI, PI)
	_body_transform.basis = Basis(Vector3.UP, _turn_planner.pose_yaw)
	_turn_foot_yaws.assign(_turn_planner.foot_yaws)
	relative_look = wrapf(look.x - _turn_planner.pose_yaw, -PI, PI)
	var head_limit := deg_to_rad(float(_character.get("head_max_yaw"))) if "head_max_yaw" in _character else deg_to_rad(85.0)
	# Dezelfde nekgrens geldt ten opzichte van de daadwerkelijk gedraaide borst.
	_head_yaw = _turn_body_offset + _turn_torso_yaw + clampf(relative_look - _turn_torso_yaw, -head_limit, head_limit)
	frame.turn_step_landed = false
	frame.turn_step_index = _turn_planner.step_index
	if _turn_planner.started_side >= 0:
		var destination := _turn_planner.destination()
		if absf(wrapf(_turn_planner.foot_yaws[0] - _turn_planner.foot_yaws[1], -PI, PI)) < 0.01:
			destination = _separated_stop_target(_turn_planner.started_side, destination)
		var hit := _ground_at(destination)
		if hit.is_empty():
			_turn_planner.reject_step()
		else:
			_turn_planner.place_destination(hit.position)
			_normals[_turn_planner.started_side] = hit.normal
			_locked[_turn_planner.started_side] = false

func _consume_turn_foot(frame: Variant, side: int) -> bool:
	if not _turn_planner.enabled:
		return false
	if _turn_planner.landed_side == side:
		# Eén bekende vrije zwaai eindigt op de lokaal gemeten vloer.
		_contacts[side] = _turn_planner.destination()
		_locked[side] = true
		frame.foot_contacts.append(_contacts[side])
		frame.turn_step_landed = true
		frame.turn_step_index = _turn_planner.step_index
	if _turn_planner.active_side == side:
		_locked[side] = false
		_targets[side] = _turn_planner.swing_position(_measured_leg_length * 0.09) + Vector3.UP * _ankle_height
		if absf(wrapf(_turn_planner.foot_yaws[0] - _turn_planner.foot_yaws[1], -PI, PI)) < 0.01:
			_targets[side] = _separated_stop_target(side, _targets[side])
	else:
		_locked[side] = true
		_targets[side] = _contacts[side] + Vector3.UP * _ankle_height
	_swing_from[side] = _body_transform.affine_inverse() * _targets[side]
	return true

func _separated_stop_target(side: int, target: Vector3) -> Vector3:
	# Na zijwaarts stoppen kunnen beide voeten naast de capsule staan. De
	# radiale bijstap mag dan niet door de andere, nog vaststaande voet gaan.
	var right := _body_transform.basis.x
	var rest_gap := (_rest_feet[1].x - _rest_feet[0].x) * _profile.get_stance_width_scale(0.0)
	var gap := minf(_measured_leg_length * 0.16, rest_gap)
	var sign_side := -1.0 if side == 0 else 1.0
	var separation := (target - _contacts[1-side]).dot(right) * sign_side
	return target + right * sign_side * maxf(0.0, gap - separation)

func _cache_physics_pose() -> void:
	# Physics plant de botpose; renderframes mengen alleen de gecachte lokale poses.
	var previous_targets := _targets.duplicate()
	_free_plan_origins.assign(_targets)
	apply_skeleton_pose(_skeleton, true)
	for side in 2:
		_free_target_adjustment[side] = _targets[side].distance_to(previous_targets[side]) if not _locked[side] else 0.0
		_max_free_target_adjustment = maxf(_max_free_target_adjustment, _free_target_adjustment[side])
	_pose_previous.assign(_pose_current)
	_pose_current.clear()
	for bone in _driven_bones:
		_pose_current.append(_skeleton.get_bone_pose(bone))
	if _pose_previous.is_empty():
		_pose_previous.assign(_pose_current)
	_skeleton.reset_bone_poses()

func apply_render_pose(skeleton: Skeleton3D) -> void:
	if _pose_current.is_empty():
		return
	var weight := Engine.get_physics_interpolation_fraction() if is_physics_interpolated_and_enabled() and not Engine.is_editor_hint() else 1.0
	for index in range(_driven_bones.size()):
		var pose := _pose_previous[index].interpolate_with(_pose_current[index], weight)
		var bone := _driven_bones[index]
		skeleton.set_bone_pose_position(bone, pose.origin)
		skeleton.set_bone_pose_rotation(bone, pose.basis.get_rotation_quaternion())
		skeleton.set_bone_pose_scale(bone, pose.basis.get_scale())

func _ground_at(at: Vector3) -> Dictionary:
	if Engine.is_editor_hint() or not is_inside_tree() or get_world_3d() == null or _rays_last_frame >= 2:
		return {}
	_rays_last_frame += 1
	_rays_total += 1
	var up := maxf(0.3, _measured_leg_length * 0.6)
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * up, at - Vector3.UP * (_measured_leg_length + 0.25))
	if _character is CollisionObject3D:
		query.exclude = [(_character as CollisionObject3D).get_rid()]
		query.collision_mask = (_character as CollisionObject3D).collision_mask
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and Vector3(hit.normal).dot(Vector3.UP) < 0.5:
		return {}
	return hit

func apply_skeleton_pose(skeleton: Skeleton3D, plan_free_targets: bool = false) -> void:
	if _profile == null or not _initialized_pose or _pelvis < 0:
		return
	skeleton.reset_bone_poses()
	var low := _posture in ["kruipen", "crouch"]
	var prone := _posture in ["liggen", "prone"]
	var body_up := (skeleton.global_basis.inverse() * Vector3.UP).normalized()
	var body_right := (skeleton.global_basis.inverse() * _body_transform.basis.x).normalized()
	var gait_active := not low and not prone and not _sliding and _air_kind in ["none", "stride"]
	var gait_wave := cos((float(_step_index) + _pose_phase()) * PI) * clampf(_speed / 0.6, 0.0, 1.0) if gait_active else 0.0
	var running := _running_blend()
	var twist := -gait_wave * deg_to_rad(_profile.body_twist_degrees) * lerpf(0.25, 1.0, running)
	var roll := gait_wave * deg_to_rad(_profile.body_roll_degrees) * lerpf(1.0, 0.45, running)
	var body_forward := (skeleton.global_basis.inverse() * -_body_transform.basis.z).normalized()
	_rotate_global(_pelvis, body_up, twist + _turn_body_offset + _gait_yaw)
	_rotate_global(_pelvis, body_forward, roll)
	var drop := _measured_leg_length * (0.47 if low else 0.0)
	if not low and not prone and not _sliding:
		# Verlaag het bekken binnen bereik van de actuele beenhouding, ook vlak na afzet.
		# Zonder deze correctie zou IK het bereik begrenzen en de zool optillen.
		for side in range(2):
			if not _valid_chain(_legs[side]):
				continue
			var hip := skeleton.global_transform * skeleton.get_bone_global_pose(_legs[side][0]).origin
			var delta := _targets[side] - hip
			var horizontal_distance := Vector2(delta.x, delta.z).length()
			# De gewichtsverplaatsing volgt hieronder; zijpassen houden daarvoor bereikreserve.
			var reach := (_leg_lengths[side].x + _leg_lengths[side].y) * lerpf(0.995, 0.975, _strafe_amount)
			var vertical_reach := sqrt(maxf(0.001, reach * reach - horizontal_distance * horizontal_distance))
			var required_drop := hip.y - _targets[side].y - vertical_reach
			if plan_free_targets and not _locked[side] and _air_kind == "stride" and absf(_gait_yaw) > 0.01:
				# Een net losgekomen diagonale voet mag al herstellen. Een oud laag
				# zwaaidoel hoort het hele bekken niet verder omlaag te trekken.
				var lift_correction := minf(maxf(0.0, required_drop - _measured_leg_length * 0.10), _measured_leg_length * 0.025)
				_targets[side].y += lift_correction
				required_drop -= lift_correction
			if _speed > 0.10 and not _locked[side] and (_relaxed_walk or _jogging or _strafe_amount > 0.001):
				# Een vrije voet past zich aan het lichaam aan. Alleen steun bepaalt
				# de noodzakelijke verlaging; de vrije keten wordt later éénmaal gepland.
				var preparing_contact := smoothstep(0.55, 0.95, _foot_phase.swing[side])
				required_drop = minf(required_drop, _measured_leg_length * lerpf(lerpf(0.075, 0.11, running), 0.20, preparing_contact))
			drop = maxf(drop, required_drop)
		# Bij uitrollen kan een vaste steunvoet verder achter het lichaam blijven.
		# Behoud dan het contact via begrensd bekkenbereik, zonder stille herplaatsing.
		drop = clampf(drop, 0.0, _measured_leg_length * 0.50)
	var slide_hip := Vector2.ZERO
	if prone:
		drop = _hip_height - _ankle_height - 0.17
	elif _sliding:
		var hip_rest_y := ((_rest_world(_legs[0][0]).y + _rest_world(_legs[1][0]).y) * 0.5) - _body_transform.origin.y
		# Bereken de zittende heup uit een lage knie en de echte scheen/bovenbeenlengte.
		# De voet blijft op hetzelfde doel; alleen bekkenhoogte en zitdiepte veranderen.
		var upper := (_leg_lengths[0].x + _leg_lengths[1].x) * 0.5
		var lower := (_leg_lengths[0].y + _leg_lengths[1].y) * 0.5
		var knee_height := _measured_leg_length * _profile.slide_knee_clearance_ratio
		var shin_rise := clampf(_ankle_height - knee_height, -lower * 0.5, lower * 0.5)
		var shin_horizontal := sqrt(lower * lower - shin_rise * shin_rise)
		var flex_limit := _profile.get_flexion_limits(false).y
		var available_sit := flex_limit - PI * 0.5 - asin(shin_rise / lower) - deg_to_rad(2.0)
		var sit_angle := clampf(deg_to_rad(_profile.slide_sit_degrees), 0.0, maxf(0.0, available_sit))
		slide_hip = Vector2(knee_height + upper * cos(sit_angle), lower * 0.94 - shin_horizontal + upper * sin(sit_angle))
		drop = hip_rest_y - slide_hip.x
	drop += (_compression + _gait_compression) if not low and not prone and not _sliding else 0.0
	# Vrije doelen worden hierna binnen de kniegrenzen gepland. Hergebruik bij
	# opnieuw toepassen dezelfde bekkenhoogte, anders verandert die tweede pose.
	if plan_free_targets:
		if (_relaxed_walk or _jog_pose > 0.0 or _strafe_amount > 0.001) and not low and not prone and not _sliding:
			# Loskomen van de oude steun tilt het bekken geleidelijk terug; de
			# vrije voet hoeft die hoogteverandering niet in één frame te overbruggen.
			drop = maxf(drop, _planned_pelvis_drop - _measured_leg_length * _pose_delta * 1.5)
		_planned_pelvis_drop = drop
	else:
		drop = _planned_pelvis_drop
	var pelvis_rest := skeleton.get_bone_rest(_pelvis)
	var weight_shift := -gait_wave * _measured_leg_length * _profile.weight_shift_ratio * (1.0 - running * 0.7)
	var slide_sit_back := slide_hip.y if _sliding else 0.0
	skeleton.set_bone_pose_position(_pelvis, pelvis_rest.origin + Vector3.DOWN * drop / maxf(skeleton.global_basis.get_scale().y, 0.001) + body_right * weight_shift - body_forward * slide_sit_back)
	if _spine >= 0:
		_rotate_global(_spine, body_up, -2.0 * twist + _turn_torso_yaw - _gait_yaw * (1.0 - _profile.strafe_torso_follow_ratio))
		_rotate_global(_spine, body_forward, -2.0 * roll)
		_rotate_global(_spine, body_right, (-0.35 if _sliding else (-0.60 if low else -_lean)) + _idle.chest_pitch)
	if prone:
		_rotate_global(_pelvis, Vector3.RIGHT, -PI * 0.48)
	elif _sliding:
		_rotate_global(_pelvis, body_right, 0.12)
	if _head >= 0:
		var up_axis := (skeleton.global_basis.inverse() * Vector3.UP).normalized()
		# Pitch begint om de motor-rustas; de volledige hoofd-yaw draait die daarna.
		# De al bijgedraaide visuele as zou pitch tijdens bijstappen dubbel draaien.
		var right_axis := (skeleton.global_basis.inverse() * _character.global_basis.x).normalized()
		# Het hoofd volgt de besturingsblik, onafhankelijk van schouder-/bekkendraai.
		var head_rotation := skeleton.get_bone_global_rest(_head).basis.get_rotation_quaternion()
		_set_global_rotation(_head, Quaternion(up_axis, _head_yaw) * Quaternion(right_axis, _head_pitch + _idle.head_pitch) * head_rotation)
	for side in range(2):
		if plan_free_targets and not _locked[side] and not low and not prone and not _sliding:
			_plan_free_target_within_reach(side)
		var local_target := skeleton.to_local(_targets[side])
		var forward := skeleton.global_basis.inverse() * (-_body_transform.basis.z)
		_solve_limb(_legs[side], _leg_lengths[side], local_target, forward, _profile.get_flexion_limits(false))
		if _valid_chain(_legs[side]):
			_apply_foot_rotation(side, skeleton)
			if plan_free_targets and _strafe_amount > 0.001 and not _locked[side] and _ground_known[side] and _air_kind in ["none", "stride"] and not low and not prone and not _sliding:
				_correct_free_sole(side, skeleton, forward)
		if _locked[side] and _valid_chain(_legs[side]):
			var actual_ankle := skeleton.global_transform * skeleton.get_bone_global_pose(_legs[side][2]).origin
			_max_planted_error = maxf(_max_planted_error, actual_ankle.distance_to(_targets[side]))
		_apply_idle_shoulder(side)
		_pose_arm(side, low, prone)

func _apply_foot_rotation(side: int, skeleton: Skeleton3D) -> void:
	var foot := _legs[side][2]
	# Ook een vlakke geplante zool bewaart de grondoriëntatie. Alleen de expliciete
	# bijstapplanner mag een geplaatste voet zijn eigen draaidoel geven.
	var normal := _normals[side].normalized()
	var foot_forward := -Basis(Vector3.UP, _turn_foot_yaws[side]).z if _turn_planner.enabled else (_contact_forwards[side] if _locked[side] else -_body_transform.basis.z)
	var forward_on_ground := foot_forward.slide(normal).normalized()
	var ground_basis := Basis(forward_on_ground.cross(normal).normalized(), normal, -forward_on_ground)
	var desired := skeleton.global_basis.inverse() * ground_basis * Basis(Vector3.RIGHT, _foot_pitch(side)) * _rest_foot_basis[side]
	_set_global_rotation(foot, desired.orthonormalized().get_rotation_quaternion())

func _sole_clearance(side: int, skeleton: Skeleton3D) -> float:
	var foot_pose := skeleton.global_transform * skeleton.get_bone_global_pose(_legs[side][2])
	var toe := foot_pose * (_rest_foot_basis[side].inverse() * Vector3(0.0, -_ankle_height, -_toe_lengths[side]))
	var heel := foot_pose * (_rest_foot_basis[side].inverse() * Vector3(0.0, -_ankle_height, _toe_lengths[side] * 0.25))
	return minf((toe - _ground_points[side]).dot(_normals[side]), (heel - _ground_points[side]).dot(_normals[side]))

func _correct_free_sole(side: int, skeleton: Skeleton3D, forward: Vector3) -> void:
	# Gebruik het al gemeten lokale vlak. Een schuin begrensde enkel kan ondanks
	# een hoog genoeg enkelpunt toch de teen in de vloer steken.
	var before := _sole_clearance(side, skeleton)
	_sole_clearance_before[side] = before
	_sole_clearance_after[side] = before
	if before >= -0.0001:
		return
	var old_target := _targets[side]
	# Een hogere vrije enkel kan de anatomische pitchbegrenzing verder kantelen.
	# Een kleine begrensde reserve vangt die koppeling op zonder een zoeklus.
	# Bewaar het bestaande totale vrije-doelbudget van minder dan vier centimeter.
	var remaining := maxf(0.0, 0.039 - old_target.distance_to(_free_plan_origins[side]))
	var lift := minf((0.002 - before) * 2.0, minf(_measured_leg_length * 0.06, remaining))
	if lift <= 0.00001:
		return
	_targets[side] += _normals[side] * lift
	_plan_free_target_within_reach(side)
	_sole_corrections[side] = _targets[side].distance_to(old_target)
	_sole_replans += 1
	# Begin de extra IK vanuit dezelfde lokale rustrotaties. Anders kan de
	# eerste oplossing een resttwist achterlaten die herhaald toepassen niet heeft.
	for bone in _legs[side]:
		skeleton.set_bone_pose_rotation(bone, skeleton.get_bone_rest(bone).basis.get_rotation_quaternion())
	# Hoogstens één extra analytische IK voor deze vrije voet, geen herhaallus.
	_solve_limb(_legs[side], _leg_lengths[side], skeleton.to_local(_targets[side]), forward, _profile.get_flexion_limits(false))
	_apply_foot_rotation(side, skeleton)
	_sole_clearance_after[side] = _sole_clearance(side, skeleton)

func _apply_idle_shoulder(side: int) -> void:
	var chain := _arms[side]
	if not _valid_chain(chain) or _idle.shoulder_lift == 0.0:
		return
	# Raise the arm root in world-up without a second bone writer or new bone mapping.
	var bone := chain[0]
	var parent := _skeleton.get_bone_parent(bone)
	var parent_basis := _skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	var offset := _skeleton.global_basis.inverse() * Vector3.UP * (_idle.shoulder_lift * _measured_leg_length)
	_skeleton.set_bone_pose_position(bone, _skeleton.get_bone_pose_position(bone) + parent_basis.inverse() * offset)

func _foot_pitch(side: int) -> float:
	if _sliding:
		return _limit_ankle(side, deg_to_rad(-135.0))
	if _locked[side] and absf(_foot_roll[side]) > 0.00001:
		return _foot_roll[side]
	if _locked[side] or _speed < 0.1 or _posture not in ["staan", "stand"] or _sliding or _air_kind in ["jump", "fall"]:
		return 0.0
	var speed_mix := clampf(_speed / maxf(_profile.reference_speed, 0.1), 0.0, 1.0)
	var amount := deg_to_rad(_profile.ankle_swing_degrees) * lerpf(0.3, 1.0, speed_mix) * lerpf(1.0, 0.35, _strafe_amount)
	if side == posmod(_step_index, 2) and _air_kind == "stride":
		var recovery := clampf((_phase - 0.5) * 2.0, 0.0, 1.0)
		return _limit_ankle(side, amount * lerpf(-0.8, 0.6, smoothstep(0.0, 1.0, recovery)))
	# Hielherstel gaat door in de voorzwaai; tenen worden voor contact weer vlak.
	return _limit_ankle(side, amount * (0.6 + 0.35 * sin(_phase * PI)) * (1.0 - smoothstep(0.55, 1.0, _phase)))

func _limit_ankle(side: int, desired_pitch: float) -> float:
	if not _valid_chain(_legs[side]):
		return desired_pitch
	var knee := _skeleton.global_transform * _skeleton.get_bone_global_pose(_legs[side][1]).origin
	var ankle := _skeleton.global_transform * _skeleton.get_bone_global_pose(_legs[side][2]).origin
	var shin := (knee - ankle).normalized()
	var up := _normals[side].normalized()
	var forward := (-_body_transform.basis.z).slide(up).normalized()
	var shin_tilt := atan2(shin.dot(forward), shin.dot(up))
	# Wereldpitch alleen is onvoldoende: bij een knie vóór de enkel zou dezelfde
	# teenhef de voet scherp tegen de scheen vouwen. Grenzen volgen het onderbeen.
	return clampf(desired_pitch, -deg_to_rad(_profile.ankle_plantarflex_degrees) - shin_tilt, deg_to_rad(_profile.ankle_dorsiflex_degrees) - shin_tilt)
func _pose_arm(side: int, low: bool, prone: bool) -> void:
	var chain := _arms[side]
	if not _valid_chain(chain):
		return
	var lengths := _arm_lengths[side]
	var length := lengths.x + lengths.y
	var shoulder := _skeleton.get_bone_global_pose(chain[0]).origin
	var speed_mix := clampf(_speed / maxf(_profile.reference_speed, 0.1), 0.0, 1.0)
	var arm_phase := float(_step_index) + _pose_phase() + _arm_phase_offset
	var swing := cos(arm_phase * PI) * (-1.0 if side == 0 else 1.0)
	var amplitude := deg_to_rad(lerpf(8.0, _profile.arm_swing_degrees, speed_mix)) * clampf(_speed / 0.6, 0.0, 1.0)
	var side_sign := -1.0 if side == 0 else 1.0
	var reach := lerpf(0.94, 0.76, speed_mix)
	var run_offset := Basis(Vector3.RIGHT, swing * amplitude) * Vector3(side_sign * length * 0.08, -length * reach, 0.0)
	run_offset.z -= length * _profile.arm_forward_ratio
	run_offset.x -= side_sign * length * _profile.arm_inward_ratio * maxf(swing, 0.0) * speed_mix
	# De wandelarm hangt laag en zwaait klein uit de schouder; geen verkleinde runarm.
	var walk_swing := cos(arm_phase * PI - 0.12) * (-1.0 if side == 0 else 1.0)
	var walk_amplitude := deg_to_rad(_profile.walk_arm_swing_degrees) * clampf(_speed / 0.6, 0.0, 1.0)
	var walk_offset := Basis(Vector3.RIGHT, walk_swing * walk_amplitude) * Vector3(side_sign * length * 0.06, -length * _profile.walk_arm_reach_ratio, 0.0)
	walk_offset.z -= length * 0.015
	var offset := walk_offset.lerp(run_offset, _running_blend())
	if _jog_pose > 0.0:
		# Joggen heeft gebogen ellebogen en actieve schouderzwaai, ook bij 3 m/s.
		var jog_amplitude := deg_to_rad(25.0) * clampf(_speed / 1.0, 0.0, 1.0)
		var jog_offset := Basis(Vector3.RIGHT, swing * jog_amplitude) * Vector3(side_sign * length * 0.08, -length * 0.68, -length * 0.24)
		offset = offset.lerp(jog_offset, _jog_pose)
	if _sliding:
		offset = Vector3(side_sign * length * 0.22, -length * 0.62, -length * 0.35)
	elif prone or low:
		offset = Vector3(side_sign * length * 0.18, -length * 0.45, -length * 0.65)
	var jump_offset := Vector3(side_sign * length * 0.22, -length * 0.45, -length * 0.65)
	if not low and not prone and not _sliding:
		offset = offset.lerp(jump_offset, _jump_pose)
	# Restlengtes zijn wereldmeters; botposities en solver werken in skeletmeters.
	var arm_basis := _body_transform.basis * Basis(Vector3.UP, -_gait_yaw * (1.0 - _profile.strafe_torso_follow_ratio))
	var world_offset := arm_basis.orthonormalized() * offset
	var skeleton_offset := _skeleton.global_basis.inverse() * world_offset
	var pole := _skeleton.global_basis.inverse() * (arm_basis * Vector3(side_sign * 0.20, -0.1, 0.95))
	_solve_limb(chain, lengths, shoulder + skeleton_offset, pole, _profile.get_flexion_limits(true))

func _plan_free_target_within_reach(side: int) -> void:
	# Eén expliciete physics-planning vóór IK. Vaste wereldcontacten wijzigen
	# nooit; renderinterpolatie en opnieuw toepassen van een pose plannen niet.
	var chain := _legs[side]
	if not _valid_chain(chain):
		return
	var root := _skeleton.get_bone_global_pose(chain[0]).origin
	var target := _skeleton.to_local(_targets[side])
	var delta := target - root
	var scale := maxf(_skeleton.global_basis.get_scale().x, 0.001)
	var a := _leg_lengths[side].x / scale
	var b := _leg_lengths[side].y / scale
	var limits := _profile.get_flexion_limits(false)
	var minimum := maxf(absf(a - b) + 0.00001, sqrt(maxf(0.000001, a * a + b * b + 2.0 * a * b * cos(limits.y))))
	var maximum := minf(a + b - 0.00001, sqrt(maxf(0.000001, a * a + b * b + 2.0 * a * b * cos(limits.x))))
	var distance := delta.length()
	if distance >= minimum - 0.00001 and distance <= maximum + 0.00001 and _strafe_amount <= 0.001:
		return
	var axis := delta.normalized() if distance > 0.000001 else Vector3.DOWN
	var planned_delta := axis * clampf(distance, minimum, maximum)
	if _strafe_amount > 0.001:
		# Bereikprojectie mag een vrije voet niet terug over de andere baan trekken.
		# Snij de bereikbol analytisch met de veilige zijruimte; geen zoeklus of ray.
		var sign_side := -1.0 if side == 0 else 1.0
		var normal := (_skeleton.global_basis.inverse() * _body_transform.basis.x * sign_side).normalized()
		var other := _skeleton.to_local(_targets[1 - side]) - root
		# De anatomische heupas bewaakt hierboven de volle pasbreedte. Deze
		# tweede grens bewaart alleen een kleine vrije marge in de loopas;
		# twee verschillende assen mogen dezelfde voet niet ver uit haar baan duwen.
		var required := other.dot(normal) + _measured_leg_length * 0.06 / scale
		if planned_delta.dot(normal) < required:
			var normal_distance := clampf(required, -maximum, maximum)
			var tangent := planned_delta - normal * planned_delta.dot(normal)
			var tangent_axis := tangent.normalized() if tangent.length_squared() > 0.000001 else Vector3.DOWN.slide(normal).normalized()
			var tangent_max := sqrt(maxf(0.0, maximum * maximum - normal_distance * normal_distance))
			var tangent_min := sqrt(maxf(0.0, minimum * minimum - normal_distance * normal_distance))
			planned_delta = normal * normal_distance + tangent_axis * clampf(tangent.length(), tangent_min, tangent_max)
	var planned := _skeleton.global_transform * (root + planned_delta)
	_targets[side] = planned

func _solve_limb(chain: PackedInt32Array, lengths: Vector2, target: Vector3, pole: Vector3, flexion_limits: Vector2) -> void:
	if not _valid_chain(chain):
		return
	var root := _skeleton.get_bone_global_pose(chain[0]).origin
	var scale := maxf(_skeleton.global_basis.get_scale().x, 0.001)
	var a := lengths.x / scale
	var b := lengths.y / scale
	var delta := target - root
	var minimum := sqrt(maxf(0.000001, a * a + b * b + 2.0 * a * b * cos(flexion_limits.y)))
	var maximum := sqrt(maxf(0.000001, a * a + b * b + 2.0 * a * b * cos(flexion_limits.x)))
	var distance := clampf(delta.length(), maxf(absf(a - b) + 0.00001, minimum), minf(a + b - 0.00001, maximum))
	var axis := delta.normalized() if delta.length_squared() > 0.000001 else Vector3.DOWN
	var bend := pole - axis * pole.dot(axis)
	if bend.length_squared() < 0.0001:
		bend = Vector3.RIGHT - axis * Vector3.RIGHT.dot(axis)
	bend = bend.normalized()
	var along := (a * a - b * b + distance * distance) / (2.0 * distance)
	var height := sqrt(maxf(0.0, a * a - along * along))
	var joint := root + axis * along + bend * height
	var reachable := root + axis * distance
	_aim_bone(chain[0], chain[1], joint)
	_aim_bone(chain[1], chain[2], reachable)
	var actual := _skeleton.get_bone_global_pose(chain[2]).origin
	_max_reach_error = maxf(_max_reach_error, actual.distance_to(reachable) * scale)

func _aim_bone(bone: int, child: int, target: Vector3) -> void:
	var pose := _skeleton.get_bone_global_pose(bone)
	var from := _skeleton.get_bone_global_pose(child).origin - pose.origin
	var to := target - pose.origin
	if from.length_squared() < 0.0000001 or to.length_squared() < 0.0000001:
		return
	_set_global_rotation(bone, Quaternion(from.normalized(), to.normalized()) * pose.basis.get_rotation_quaternion())

func _set_global_rotation(bone: int, rotation: Quaternion) -> void:
	var parent := _skeleton.get_bone_parent(bone)
	var parent_rotation := _skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
	_skeleton.set_bone_pose_rotation(bone, (parent_rotation.inverse() * rotation).normalized())

func _rotate_global(bone: int, axis: Vector3, angle: float) -> void:
	var rotation := _skeleton.get_bone_global_pose(bone).basis.get_rotation_quaternion()
	_set_global_rotation(bone, Quaternion(axis, angle) * rotation)

func _indices(names: Array) -> PackedInt32Array:
	var result := PackedInt32Array()
	for bone in names:
		result.append(_skeleton.find_bone(bone))
	return result

func _valid_chain(chain: PackedInt32Array) -> bool:
	return chain.size() == 3 and chain[0] >= 0 and chain[1] >= 0 and chain[2] >= 0

func _measure(chain: PackedInt32Array) -> Vector2:
	if not _valid_chain(chain):
		return Vector2(0.35, 0.35)
	return Vector2(_rest_world(chain[0]).distance_to(_rest_world(chain[1])), _rest_world(chain[1]).distance_to(_rest_world(chain[2])))

func _rest_world(bone: int) -> Vector3:
	return _skeleton.global_transform * _skeleton.get_bone_global_rest(bone).origin

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var result := _find_skeleton(child)
		if result != null:
			return result
	return null

func _set_layers(node: Node, layer: int) -> void:
	if node is VisualInstance3D and layer > 0:
		node.layers = 1 << (layer - 1)
	for child in node.get_children():
		_set_layers(child, layer)

func get_debug_state() -> Dictionary:
	return {"sole_replans": _sole_replans, "sole_clearance_before": _sole_clearance_before.duplicate(), "sole_clearance_after": _sole_clearance_after.duplicate(), "sole_corrections": _sole_corrections.duplicate(), "foot_contact_sides": _contact_sides.duplicate(), "foot_roll": _foot_roll.duplicate(), "foot_pivots": _foot_pivots.duplicate(), "uniform_phase": _foot_phase.uniform_phase, "strafe_amount": _strafe_amount, "gait_yaw": _gait_yaw, "motion_profile": _motion_profile, "turn_body_offset": _turn_body_offset, "turn_torso_yaw": _turn_torso_yaw, "turn_pose_yaw": _turn_planner.pose_yaw, "turn_active_side": _turn_planner.active_side, "turn_step_index": _turn_planner.step_index, "turn_foot_yaws": _turn_foot_yaws.duplicate(), "leg_length": _measured_leg_length, "leg_segments": _leg_lengths, "arm_segments": _arm_lengths, "rays_last_frame": _rays_last_frame, "rays_total": _rays_total, "max_reach_error": _max_reach_error, "max_planted_error": _max_planted_error, "max_free_target_adjustment": _max_free_target_adjustment, "free_target_adjustment": _free_target_adjustment.duplicate(), "released_overreach": _released_overreach, "locked_feet": _locked.duplicate(), "foot_targets": _targets.duplicate(), "max_planner_usec": _max_frame_usec, "compression": _compression, "compression_velocity": _compression_velocity, "compression_events": _compression_events}

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if _profile != null and _skeleton != null:
		for side in range(_legs.size()):
			if not _valid_chain(_legs[side]) or not _valid_chain(_arms[side]):
				warnings.append("Het lichaamsprofiel mist botnamen voor een arm of been; controleer de links/rechts-koppelingen.")
	return warnings
