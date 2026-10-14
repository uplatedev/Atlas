extends SceneTree
## Echte Skeleton3D/physics-proef voor dezelfde planner op drie lichaamsverhoudingen.
const Profile = preload("res://characters/procedural/body_profile.gd")
const Presentation = preload("res://characters/procedural/presentation.gd")
var _failures: Array[String] = []
var _world: Node3D
class TestActor extends CharacterBody3D:
	var look: Vector2 = Vector2.ZERO
	func get_look_input() -> Vector2:
		return look

func _initialize() -> void:
	call_deferred("_run")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)

func _run() -> void:
	_world = Node3D.new()
	root.add_child(_world)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(30.0, 0.2, 30.0)
	floor_shape.shape = shape
	floor_shape.position.y = -0.1
	floor_body.add_child(floor_shape)
	_world.add_child(floor_body)
	await physics_frame
	await physics_frame
	_check_profile()
	await _check_persistence()
	var ratios: Array[float] = []
	for variant in range(4):
		var actor := TestActor.new()
		_world.add_child(actor)
		actor.position.x = float(variant) * 3.0
		var profile := Profile.new()
		profile.test_body = mini(variant, 2)
		if variant == 3:
			profile.visual_scene = load("res://assets/characters/artemis_rigged.glb") as PackedScene
		var presentation := Presentation.new()
		actor.add_child(presentation)
		presentation.setup(actor, profile)
		var skeleton: Skeleton3D = presentation.get("_skeleton")
		var segments: Array = presentation.get_debug_state().leg_segments
		ratios.append(segments[0].x / segments[0].y)
		_expect(absf(presentation.get_leg_length() - [0.76, 0.81, 0.71, 0.673776][variant]) < 0.001, "gemeten beenlengte %d" % variant)
		var frame := _frame(actor)
		presentation.consume_frame(frame)
		presentation.apply_skeleton_pose(skeleton)
		var lock: Array = presentation.get_debug_state().locked_feet
		_expect(lock[0] and lock[1], "rustvoeten geplant %d" % variant)
		var anchors: Array = presentation.get("_contacts").duplicate()
		for tick in range(1, 9):
			actor.position.z -= 0.01
			frame = _frame(actor, 2.0, float(tick) / 20.0)
			presentation.consume_frame(frame)
			presentation.apply_skeleton_pose(skeleton)
			var state: Dictionary = presentation.get_debug_state()
			_expect(presentation.get("_contacts")[0].distance_to(anchors[0]) < 0.00001, "zoolanker blijft wereldvast terwijl enkel mag afrollen %d/%d" % [variant, tick])
			_expect(state.rays_last_frame <= 2, "begrensde rays")
			_expect(state.max_planted_error < 0.002, "werkelijke enkel bereikt het actuele IK-doel %d: %f" % [variant, state.max_planted_error])
		actor.position.y = 0.08
		frame = _frame(actor, 8.0, 0.7)
		frame.supported = false
		frame.air_kind = "stride"
		presentation.consume_frame(frame)
		presentation.apply_skeleton_pose(skeleton)
		lock = presentation.get_debug_state().locked_feet
		_expect(not lock[0] and not lock[1], "beide voeten vrij in pasvlucht %d" % variant)
		_expect(frame.foot_contacts.is_empty(), "geen contactcue in vlucht")
		actor.position.y = 0.0
		frame = _frame(actor, 8.0, 0.0)
		frame.step_index = 1
		frame.stride_landed = true
		presentation.consume_frame(frame)
		presentation.apply_skeleton_pose(skeleton)
		_expect(frame.foot_contacts.size() == 1, "precies een voetcontact na echte landing %d" % variant)
		frame = _frame(actor, 5.0, 0.0)
		frame.step_index = 2
		frame.ground_step = true
		presentation.consume_frame(frame)
		presentation.apply_skeleton_pose(skeleton)
		_expect(frame.foot_contacts.size() == 1 and presentation.get_debug_state().locked_feet[0], "gesteunde stap wisselt voet zonder vlucht %d" % variant)
		frame = _frame(actor, 5.0, 0.7)
		frame.step_index = 2
		presentation.consume_frame(frame)
		_expect(frame.foot_contacts.is_empty() and presentation.get_debug_state().locked_feet[0], "gesteunde zwaaifase dupliceert contact niet")
		for posture in ["kruipen", "liggen", "staan"]:
			frame = _frame(actor, 4.0, 0.2)
			frame.posture = posture
			frame.sliding = posture == "staan"
			presentation.consume_frame(frame)
			presentation.apply_skeleton_pose(skeleton)
			_expect(skeleton.get_bone_global_pose(0).origin.is_finite(), "lage pose eindig")
		var state: Dictionary = presentation.get_debug_state()
		_expect(state.max_reach_error < 0.002, "IK blijft op bereikbaar doel %d: %f" % [variant, state.max_reach_error])
		_expect(actor.position.distance_to(frame.body_transform.origin) < 0.00001, "presentatie verplaatst actor niet")
		frame = _frame(actor, 0.0, 0.0)
		presentation.consume_frame(frame)
		presentation.apply_skeleton_pose(skeleton)
		var head := skeleton.find_bone(profile.head_bone)
		var old_head := skeleton.get_bone_global_pose(head).basis.get_rotation_quaternion()
		actor.look = Vector2(0.35, -0.20)
		presentation.consume_frame(frame)
		presentation.apply_skeleton_pose(skeleton)
		_expect(old_head.angle_to(skeleton.get_bone_global_pose(head).basis.get_rotation_quaternion()) > 0.20, "zichtbaar hoofd volgt besturing")
		frame.air_kind = "jump"
		frame.supported = false
		presentation.consume_frame(frame)
		_expect(presentation.get("_jump_pose") > 0.0 and presentation.get("_jump_pose") < 1.0, "sprongpose mengt zonder harde omslag")
		profile.knee_min_flex_degrees = 55.0
		profile.knee_max_flex_degrees = 85.0
		profile.elbow_min_flex_degrees = 50.0
		profile.elbow_max_flex_degrees = 80.0
		presentation.apply_skeleton_pose(skeleton)
		for side in range(2):
			_check_flexion(skeleton, profile.leg_bones(side), 55.0, 85.0)
			_check_flexion(skeleton, profile.arm_bones(side), 50.0, 80.0)
		print("BODY ", variant, " ", state)
		actor.queue_free()
		await process_frame
	_expect(absf(ratios[0] - ratios[1]) > 0.3 and absf(ratios[0] - ratios[2]) > 0.3, "niet-uniforme segmentverhoudingen")
	_world.queue_free()
	await process_frame
	print("PROCEDURAL PRESENTATION CHECKS: ", "PASS" if _failures.is_empty() else "FAIL "+str(_failures))
	quit(0 if _failures.is_empty() else 1)

func _frame(actor: Node3D, speed: float = 0.0, phase: float = 0.0) -> Dictionary:
	return {"body_transform": actor.global_transform, "horizontal_speed": speed, "gait_phase": phase, "step_index": 0, "air_kind": "none", "posture": "staan", "sliding": false, "body_velocity": Vector3(0.0, 0.0, -speed), "delta": 1.0/60.0, "supported": true, "stride_started": false, "stride_landed": false, "ground_step": false, "foot_contacts": []}

func _check_profile() -> void:
	var preview_profile := Profile.new()
	var changes: Array[int] = [0]
	preview_profile.changed.connect(func(): changes[0] += 1)
	var initial_signature: Array = preview_profile.rig_signature()
	preview_profile.test_body = 1
	_expect(changes[0] == 1 and preview_profile.rig_signature() != initial_signature, "rigwijziging geeft precies een refreshsignaal")
	preview_profile.test_body = 1
	_expect(changes[0] == 1, "gelijke rigwaarde veroorzaakt geen rebuild")
	preview_profile.left_foot_bone = &"ander_enkelbot"
	preview_profile.test_color = Color.RED
	preview_profile.visual_scene = PackedScene.new()
	_expect(changes[0] == 4, "botkoppeling/kleur/modelwijziging melden previewrefresh")
	var updated_signature: Array = preview_profile.rig_signature()
	preview_profile.arm_swing_degrees = 25.0
	preview_profile.mass_kg = 92.0
	preview_profile.knee_max_flex_degrees = 120.0
	preview_profile.swing_foot_curve.set_point_value(1, 0.7)
	_expect(changes[0] == 4 and updated_signature == preview_profile.rig_signature(), "stijl/curve/massa vraagt geen rigrebuild")
	var profile := Profile.new()
	var a := profile.make_instance_unique()
	var b := profile.make_instance_unique()
	var old := b.stride_flight_curve.get_point_position(3)
	a.stride_flight_curve.set_point_value(3, 0.18)
	_expect(b.stride_flight_curve.get_point_position(3) == old, "eigen pasvluchtcurve")
	_expect(a.swing_foot_curve != b.swing_foot_curve, "eigen voetcurve")
	_expect(profile.get_flight_height(0.3, 0.8, false) < profile.get_flight_height(0.9, 0.8, false), "vlucht groeit met snelheid")
	_expect(profile.get_flight_height(1.0, 0.8, true) < profile.get_flight_height(1.0, 0.8, false), "walk minimaal")
	_expect(profile.get_swing_lift(0.0) == 0.0 and profile.get_swing_lift(1.0) == 0.0, "veilige zwaai-eindpunten")

func _check_persistence() -> void:
	var source := Node3D.new()
	source.set_meta("body_profile", Profile.new().make_instance_unique())
	var packed := PackedScene.new()
	_expect(packed.pack(source) == OK, "profielscene pack")
	var path := "user://t011_profile_instance_check.tscn"
	_expect(ResourceSaver.save(packed, path) == OK, "profielscene opslaan")
	source.free()
	var loaded := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var first := loaded.instantiate()
	var second := loaded.instantiate()
	var a: Resource = first.get_meta("body_profile")
	var b: Resource = second.get_meta("body_profile")
	_expect(a != b and a.swing_foot_curve != b.swing_foot_curve and a.stride_flight_curve != b.stride_flight_curve, "heropenen geeft eigen profiel en beide curves")
	var old: Vector2 = b.swing_foot_curve.get_point_position(1)
	a.swing_foot_curve.set_point_value(1, 0.6)
	_expect(b.swing_foot_curve.get_point_position(1) == old, "heropende instance deelt wijziging niet")
	first.free()
	second.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _check_flexion(skeleton: Skeleton3D, bones: Array, minimum: float, maximum: float) -> void:
	var a := skeleton.get_bone_global_pose(skeleton.find_bone(bones[0])).origin
	var b := skeleton.get_bone_global_pose(skeleton.find_bone(bones[1])).origin
	var c := skeleton.get_bone_global_pose(skeleton.find_bone(bones[2])).origin
	var flex := rad_to_deg((b - a).angle_to(c - b))
	_expect(flex >= minimum - 0.01 and flex <= maximum + 0.01, "instelbare gewrichtsgrens %s: %.3f" % [bones[1], flex])





