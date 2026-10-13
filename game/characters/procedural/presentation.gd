@tool
class_name AtlasCharacterPresentation
extends Node3D
## Procedurele voeten en lichaam, uitsluitend presentatie. Motor bepaalt pasvlucht.

const TestHumanoid = preload("res://characters/procedural/test_humanoid.gd")
const PoseModifier = preload("res://characters/procedural/pose_modifier.gd")

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
var _contacts: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _normals: Array[Vector3] = [Vector3.UP, Vector3.UP]
var _locked: Array[bool] = [false, false]
var _swing_from: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _pelvis: int = -1
var _spine: int = -1
var _head: int = -1
var _measured_leg_length: float = 0.76
var _ankle_height: float = 0.1
var _hip_height: float = 0.85
var _speed: float = 0.0
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
var _landing_pose: float = 0.0
var _head_yaw: float = 0.0
var _head_pitch: float = 0.0
var _initialized_pose: bool = false
var _rays_last_frame: int = 0
var _rays_total: int = 0
var _max_reach_error: float = 0.0
var _max_planted_error: float = 0.0
var _released_overreach: int = 0
var _frame_usec: int = 0
var _max_frame_usec: int = 0
var _driven_bones: PackedInt32Array = []
var _pose_previous: Array[Transform3D] = []
var _pose_current: Array[Transform3D] = []

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
	_set_layers(_visual, character.get_presentation_layer() if character.has_method("get_presentation_layer") else 0)
	reset_pose()
	update_configuration_warnings()

func get_leg_length() -> float:
	return _measured_leg_length

func reset_pose() -> void:
	_pose_previous.clear()
	_pose_current.clear()
	_locked = [false, false]
	_initialized_pose = false
	_speed = 0.0
	_phase = 0.0
	_step_index = 0
	_air_kind = "none"
	_posture = "staan"
	_sliding = false
	_previous_velocity = Vector3.ZERO
	_lean = 0.0
	_jump_pose = 0.0
	_landing_pose = 0.0
	_head_yaw = 0.0
	_head_pitch = 0.0
	_max_reach_error = 0.0
	_max_planted_error = 0.0
	_released_overreach = 0
	if _skeleton != null:
		_skeleton.reset_bone_poses()
		_body_transform = _character.global_transform
		for side in range(2):
			_targets[side] = _body_transform * _rest_feet[side]
			_contacts[side] = _targets[side] - Vector3.UP * _ankle_height
			_swing_from[side] = _body_transform.affine_inverse() * _targets[side]

func consume_frame(frame: Variant) -> void:
	if _skeleton == null or _profile == null:
		return
	var started := Time.get_ticks_usec()
	_rays_last_frame = 0
	_body_transform = frame.body_transform
	_speed = frame.horizontal_speed
	_phase = frame.gait_phase
	var changed_step: bool = frame.step_index != _step_index
	_step_index = frame.step_index
	var was_jump := _air_kind in ["jump", "fall"]
	_air_kind = frame.air_kind
	if was_jump and frame.supported:
		_landing_pose = 1.0
	_landing_pose = move_toward(_landing_pose, 0.0, frame.delta * 6.0)
	_jump_pose = move_toward(_jump_pose, 1.0 if _air_kind in ["jump", "fall"] else 0.0, frame.delta * 9.0)
	if _character.has_method("get_look_input"):
		var look: Vector2 = _character.get_look_input()
		_head_yaw = wrapf(look.x - _body_transform.basis.get_euler().y, -PI, PI)
		_head_pitch = look.y
	_posture = frame.posture
	_sliding = frame.sliding
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
	var moving_stride := standing and not stationary and _air_kind in ["none", "stride"]
	var length := minf(_measured_leg_length * _profile.step_length_ratio, _measured_leg_length * 0.85)
	var lift := _profile.foot_lift_ratio * _measured_leg_length * lerpf(0.25, 1.0, clampf(_speed / maxf(_profile.reference_speed, 0.1), 0.0, 1.0))
	for side in range(2):
		if (was_jump and supported) or changed_step:
			_swing_from[side] = _body_transform.affine_inverse() * _targets[side]
		var rest := _rest_feet[side]
		rest.x *= _profile.stance_width_ratio * lerpf(1.0, _profile.running_stance_ratio, smoothstep(0.1, 1.0, clampf(_speed / maxf(_profile.reference_speed, 0.1), 0.0, 1.0)))
		var base := _body_transform * Vector3(rest.x, 0.0, 0.0)
		var ahead := _direction * length * 0.48
		var destination := base + ahead if moving_stride else base
		var hit: Dictionary = {"position": _contacts[side], "normal": _normals[side]} if stationary and _locked[side] and supported and _initialized_pose else _ground_at(destination)
		var has_ground := not hit.is_empty()
		var ground := Vector3(hit.position) if has_ground else base - Vector3.UP * maxf(0.0, _body_transform.origin.y - _contacts[side].y)
		if has_ground:
			_normals[side] = hit.normal
		var ankle := ground + Vector3.UP * _ankle_height
		var may_plant := supported and standing and (stationary or side == stance)
		# Bij een externe verplaatsing buiten fysiek beenbereik wordt contact expliciet
		# losgelaten. Tijdens gewone steun blijft het wereldpunt onveranderd.
		var overreach := _locked[side] and Vector2(_contacts[side].x - base.x, _contacts[side].z - base.z).length() > _measured_leg_length * 0.9
		if overreach:
			may_plant = false
			_released_overreach += 1
		if may_plant and has_ground and (not _locked[side] or not _initialized_pose or frame.stride_landed or frame.ground_step):
			# Contact sluit op echte motorlanding of gesteunde voetwissel, nooit op voorspelde luchtsteun.
			_contacts[side] = ground
			_locked[side] = true
			if (frame.stride_landed or frame.ground_step) and side == stance and _initialized_pose and _speed > 0.10:
				frame.foot_contacts.append(ground)
		if not may_plant or not has_ground:
			if _locked[side]:
				_swing_from[side] = _body_transform.affine_inverse() * (_contacts[side] + Vector3.UP * _ankle_height)
			_locked[side] = false
		if not _initialized_pose:
			_swing_from[side] = _body_transform.affine_inverse() * ankle
			_contacts[side] = ground
		if _locked[side]:
			_targets[side] = _contacts[side] + Vector3.UP * _ankle_height
		elif moving_stride:
			var progress := clampf(_phase, 0.0, 1.0) if side != stance else clampf((_phase - 0.5) * 2.0, 0.0, 1.0)
			var speed_mix := clampf(_speed / maxf(_profile.reference_speed, 0.1), 0.0, 1.0)
			var heel_height := _measured_leg_length * _profile.heel_recovery_ratio * speed_mix * speed_mix
			var next_target := ankle if side != stance else base - ahead * 0.6 + Vector3.UP * (_ankle_height + heel_height)
			# Losse voeten reizen met het lichaam. Een oud wereldcontact hier vasthouden
			# rekt het been tijdens pasvlucht uit en laat het bij de voetwissel terugspringen.
			var from_world := _body_transform * _swing_from[side]
			_targets[side] = from_world.lerp(next_target, smoothstep(0.0, 1.0, progress))
			_targets[side].y += _profile.get_swing_lift(progress) * lift
			if not supported:
				_targets[side].y = maxf(_targets[side].y, _body_transform.origin.y + _ankle_height * 0.7)
		elif not supported:
			_targets[side] = _body_transform * Vector3(rest.x, _ankle_height + _measured_leg_length * 0.16, 0.08 if side == 0 else -0.10)
		else:
			_targets[side] = ankle
		if not standing:
			_locked[side] = false
			_targets[side] = _body_transform * Vector3(rest.x * 1.3, _ankle_height, -_measured_leg_length * 0.55 if _sliding else (_measured_leg_length * 0.6 if _posture in ["liggen", "prone"] else 0.04))
	_initialized_pose = true
	_cache_physics_pose()
	_frame_usec = Time.get_ticks_usec() - started
	_max_frame_usec = maxi(_max_frame_usec, _frame_usec)

func _cache_physics_pose() -> void:
	# Eén IK-berekening per motorframe; renderframes mengen alleen lokale botposes.
	apply_skeleton_pose(_skeleton)
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

func apply_skeleton_pose(skeleton: Skeleton3D) -> void:
	if _profile == null or not _initialized_pose or _pelvis < 0:
		return
	skeleton.reset_bone_poses()
	var low := _posture in ["kruipen", "crouch"]
	var prone := _posture in ["liggen", "prone"]
	var body_up := (skeleton.global_basis.inverse() * Vector3.UP).normalized()
	var body_right := (skeleton.global_basis.inverse() * _body_transform.basis.x).normalized()
	var speed_mix := clampf(_speed / maxf(_profile.reference_speed, 0.1), 0.0, 1.0)
	var twist := -cos((float(_step_index) + _phase) * PI) * deg_to_rad(_profile.body_twist_degrees) * speed_mix if not low and not prone and not _sliding and _air_kind in ["none", "stride"] else 0.0
	_rotate_global(_pelvis, body_up, twist)
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
			var reach := (_leg_lengths[side].x + _leg_lengths[side].y) * 0.995
			var vertical_reach := sqrt(maxf(0.001, reach * reach - horizontal_distance * horizontal_distance))
			drop = maxf(drop, hip.y - _targets[side].y - vertical_reach)
		drop = clampf(drop, 0.0, _measured_leg_length * 0.36)
	if prone or _sliding:
		drop = _hip_height - _ankle_height - 0.17
	drop += _measured_leg_length * 0.045 * _landing_pose if not low and not prone and not _sliding else 0.0
	var pelvis_rest := skeleton.get_bone_rest(_pelvis)
	skeleton.set_bone_pose_position(_pelvis, pelvis_rest.origin + Vector3.DOWN * drop / maxf(skeleton.global_basis.get_scale().y, 0.001))
	if _spine >= 0:
		_rotate_global(_spine, body_up, -2.0 * twist)
		_rotate_global(_spine, body_right, -0.60 if low else -_lean)
	if prone:
		_rotate_global(_pelvis, Vector3.RIGHT, -PI * 0.48)
	elif _sliding:
		_rotate_global(_pelvis, Vector3.RIGHT, PI * 0.20)
	if _head >= 0:
		var up_axis := (skeleton.global_basis.inverse() * Vector3.UP).normalized()
		var right_axis := (skeleton.global_basis.inverse() * _body_transform.basis.x).normalized()
		# Het hoofd volgt de besturingsblik, onafhankelijk van schouder-/bekkendraai.
		var head_rotation := skeleton.get_bone_global_rest(_head).basis.get_rotation_quaternion()
		_set_global_rotation(_head, Quaternion(up_axis, _head_yaw) * Quaternion(right_axis, _head_pitch) * head_rotation)
	for side in range(2):
		var local_target := skeleton.to_local(_targets[side])
		var forward := skeleton.global_basis.inverse() * (-_body_transform.basis.z)
		_solve_limb(_legs[side], _leg_lengths[side], local_target, forward, _profile.get_flexion_limits(false))
		if _valid_chain(_legs[side]):
			var foot := _legs[side][2]
			# Bewaar de anatomische importrust: voetbot +Y is niet per definitie
			# horizontaal. Grondbasis plus fasepitch werkt voor beide lichaamszijden.
			var normal := _normals[side].normalized()
			var forward_on_ground := (-_body_transform.basis.z).slide(normal).normalized()
			var ground_basis := Basis(forward_on_ground.cross(normal).normalized(), normal, -forward_on_ground)
			var desired := skeleton.global_basis.inverse() * ground_basis * Basis(Vector3.RIGHT, _foot_pitch(side)) * _rest_foot_basis[side]
			_set_global_rotation(foot, desired.orthonormalized().get_rotation_quaternion())
		if _locked[side] and _valid_chain(_legs[side]):
			var actual_ankle := skeleton.global_transform * skeleton.get_bone_global_pose(_legs[side][2]).origin
			_max_planted_error = maxf(_max_planted_error, actual_ankle.distance_to(_targets[side]))
		_pose_arm(side, low, prone)

func _foot_pitch(side: int) -> float:
	if _locked[side] or _speed < 0.1 or _posture not in ["staan", "stand"] or _sliding or _air_kind in ["jump", "fall"]:
		return 0.0
	var speed_mix := clampf(_speed / maxf(_profile.reference_speed, 0.1), 0.0, 1.0)
	var amount := deg_to_rad(_profile.ankle_swing_degrees) * lerpf(0.3, 1.0, speed_mix)
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
	var swing := cos((float(_step_index) + _phase) * PI) * (-1.0 if side == 0 else 1.0)
	var amplitude := deg_to_rad(lerpf(8.0, _profile.arm_swing_degrees, speed_mix)) * clampf(_speed / 0.6, 0.0, 1.0)
	var side_sign := -1.0 if side == 0 else 1.0
	var reach := lerpf(0.94, 0.76, speed_mix)
	var offset := Basis(Vector3.RIGHT, swing * amplitude) * Vector3(side_sign * length * 0.08, -length * reach, 0.0)
	offset.z -= length * _profile.arm_forward_ratio
	offset.x -= side_sign * length * _profile.arm_inward_ratio * maxf(swing, 0.0) * speed_mix
	if prone or low:
		offset = Vector3(side_sign * length * 0.18, -length * 0.45, -length * 0.65)
	elif _sliding:
		offset = Vector3(side_sign * length * 0.25, -length * 0.55, length * 0.45)
	var jump_offset := Vector3(side_sign * length * 0.22, -length * 0.45, -length * 0.65)
	if not low and not prone and not _sliding:
		offset = offset.lerp(jump_offset, _jump_pose)
	# Restlengtes zijn wereldmeters; botposities en solver werken in skeletmeters.
	var world_offset := _body_transform.basis.orthonormalized() * offset
	var skeleton_offset := _skeleton.global_basis.inverse() * world_offset
	var pole := _skeleton.global_basis.inverse() * (_body_transform.basis * Vector3(side_sign * 0.20, -0.1, 0.95))
	_solve_limb(chain, lengths, shoulder + skeleton_offset, pole, _profile.get_flexion_limits(true))

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
	return {"leg_length": _measured_leg_length, "leg_segments": _leg_lengths, "arm_segments": _arm_lengths, "rays_last_frame": _rays_last_frame, "rays_total": _rays_total, "max_reach_error": _max_reach_error, "max_planted_error": _max_planted_error, "released_overreach": _released_overreach, "locked_feet": _locked.duplicate(), "foot_targets": _targets.duplicate(), "max_planner_usec": _max_frame_usec}

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if _profile != null and _skeleton != null:
		for side in range(_legs.size()):
			if not _valid_chain(_legs[side]) or not _valid_chain(_arms[side]):
				warnings.append("Het lichaamsprofiel mist botnamen voor een arm of been; controleer de links/rechts-koppelingen.")
	return warnings
