extends SceneTree
## Integrated idle uses the existing physics pose; the comparison actor has idle disabled.
const CHARACTER = preload("res://characters/Character.tscn")
const MODEL = preload("res://assets/characters/artemis_rigged.glb")
const AUDIO_SHUTDOWN = preload("res://tests/test_audio_shutdown.gd")
var failures: Array[String] = []
var world: Node3D
var actors: Array[AtlasCharacter] = []
var views: Array[AtlasCharacterPresentation] = []
var frames: Dictionary = {}
var origins: Array[Vector3] = [Vector3(-2, 0.04, 0), Vector3(2, 0.04, 0)]
var max_motor_error: float = 0.0
var max_contact_error: float = 0.0
var max_phase_error: float = 0.0
var max_cache_error: float = 0.0
var capture_path: String = ""
var max_chest: float = 0.0
var max_head: float = 0.0
var max_shoulder: float = 0.0
var max_shoulder_axis_error: float = 0.0
var max_pose_step: float = 0.0
var last_chest_delta: Quaternion
var has_last: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--idle-pose-captures="):
			capture_path = argument.trim_prefix("--idle-pose-captures=")
	world = Node3D.new()
	root.add_child(world)
	var ground := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(100, 0.2, 200)
	collider.shape = shape
	collider.position.y = -0.1
	ground.add_child(collider)
	world.add_child(ground)
	for index in 2:
		var actor := CHARACTER.instantiate() as AtlasCharacter
		actor.body_profile = AtlasCharacterBodyProfile.new()
		actor.body_profile.visual_scene = MODEL
		actor.body_profile.idle_enabled = index == 0
		actor.body_profile.idle_sigh_seconds = Vector2(5, 5)
		actor.body_profile.idle_blink_seconds = Vector2(1, 1)
		actor.feedback_enabled = false
		actor.name_visible = false
		actor.debug_enabled = false
		actor.position = origins[index]
		world.add_child(actor)
		actor.set_controlled(true)
		actors.append(actor)
		views.append(actor.get_node("Presentation/ProceduralBody"))
		actor.contact_frame_ready.connect(func(frame: AtlasCharacterContactFrame): frames[index] = frame)
	await _ticks(20)
	views[0]._idle._rng.seed = 41
	views[0]._idle.reset()
	var model_ids := [views[0]._visual.get_instance_id(), views[1]._visual.get_instance_id()]
	var skeleton_ids := [views[0]._skeleton.get_instance_id(), views[1]._skeleton.get_instance_id()]
	for tick in 600:
		await _ticks(1)
		_measure_pair()
		_measure_bones()
	_expect(views[0]._idle.blink_count >= 5 and views[0]._idle.sigh_count >= 1, "integrated idle actually blinks and sighs")
	_expect(views[1]._idle.blink_count == 0 and views[1]._idle.sigh_count == 0, "disabled comparison actor stays independent")
	_expect(max_chest > deg_to_rad(1.0) and max_head > deg_to_rad(0.15) and max_shoulder > 0.001, "breath/sigh visibly reach real chest, head and shoulder bones")
	_expect(max_shoulder_axis_error < 0.00001, "shoulder offset is world-up even after chest rotation")
	_send(Vector2(0, -1))
	for tick in 150:
		await _ticks(1)
		_measure_pair()
		_measure_bones()
		if tick >= 20:
			_expect(views[0]._idle.weight == 0.0 and _pose_difference() < 0.00001, "walking removes idle completely from actual bone poses")
	_send(Vector2.ZERO)
	for tick in 210:
		await _ticks(1)
		_measure_pair()
		_measure_bones()
	_expect(views[0]._idle.weight == 1.0, "after stopping and replanting idle resumes")
	for index in 2:
		_expect(model_ids[index] == views[index]._visual.get_instance_id() and skeleton_ids[index] == views[index]._skeleton.get_instance_id(), "idle transitions never rebuild model or skeleton")
		_expect(views[index]._idle.mesh_builds == 1, "one eye mesh copy per spawn")
		var phase := views[index]._idle._breath_phase
		for repeat in 4:
			views[index].apply_render_pose(views[index]._skeleton)
		_expect(views[index]._idle._breath_phase == phase, "rendering cannot advance idle timers")
	# Enable the second instance and verify runtime phase/event independence too.
	actors[1].body_profile.idle_enabled = true
	views[0]._idle._rng.seed = 41
	views[1]._idle._rng.seed = 73
	views[0]._idle.reset()
	views[1]._idle.reset()
	actors[0].body_profile.idle_blink_seconds = Vector2(1, 1)
	actors[1].body_profile.idle_blink_seconds = Vector2(1.7, 1.7)
	var async_frames := 0
	for tick in 210:
		await _ticks(1)
		_measure_pair()
		if absf(views[0]._idle.blink_amount - views[1]._idle.blink_amount) > 0.1:
			async_frames += 1
	_expect(async_frames > 5, "integrated instances keep distinct blink state")
	for index in 2:
		actors[index].reset_to_spawn()
		_expect(views[index]._idle.weight == 0.0 and views[index]._idle.chest_pitch == 0.0 and views[index]._idle.blink_amount == 0.0 and views[index]._idle.blink_count == 0, "Character reset clears idle pose and material state")
	_expect(max_motor_error < 0.000001 and max_contact_error < 0.00001 and max_phase_error < 0.000001, "idle never changes capsule motion or real foot contacts")
	_expect(max_pose_step < deg_to_rad(0.4) and max_cache_error < 0.000001, "idle contribution fades without a chest snap during idle/walk transitions")
	print("IDLE POSE METRICS motor=", max_motor_error, " contacts=", max_contact_error, " gait_phase=", max_phase_error, " chest_degrees=", rad_to_deg(max_chest), " head_degrees=", rad_to_deg(max_head), " shoulder_m=", max_shoulder, " shoulder_axis_error=", max_shoulder_axis_error, " max_idle_chest_step_degrees=", rad_to_deg(max_pose_step), " cache_error=", max_cache_error, " async_frames=", async_frames)
	if not capture_path.is_empty():
		await _capture_body()
	world.queue_free()
	await AUDIO_SHUTDOWN.drain(self)
	for failure in failures:
		printerr("FAIL: ", failure)
	print("IDLE POSE CHECKS: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)

func _send(movement: Vector2) -> void:
	for actor in actors:
		var intent := AtlasCharacterIntent.new()
		intent.movement = movement
		actor.submit_intent(intent)

func _ticks(count: int) -> void:
	for tick in count:
		await physics_frame
		await process_frame

func _measure_pair() -> void:
	if frames.size() != 2:
		return
	max_motor_error = maxf(max_motor_error, (actors[0].global_position-origins[0]).distance_to(actors[1].global_position-origins[1]))
	max_motor_error = maxf(max_motor_error, actors[0].velocity.distance_to(actors[1].velocity))
	for property in ["supported", "real_grounded", "posture", "sliding", "jumped", "landed", "stride_started", "stride_landed", "ground_step", "turn_step_landed", "turn_step_index", "step_index", "air_kind", "motion_profile"]:
		_expect(frames[0].get(property) == frames[1].get(property), "idle preserves contact field " + property)
	max_phase_error = maxf(max_phase_error, absf(frames[0].gait_phase - frames[1].gait_phase))
	_expect(frames[0].foot_contacts.size() == frames[1].foot_contacts.size(), "idle creates no foot events")
	for index in mini(frames[0].foot_contacts.size(), frames[1].foot_contacts.size()):
		var a: Vector3 = frames[0].foot_contacts[index] - origins[0]
		var b: Vector3 = frames[1].foot_contacts[index] - origins[1]
		max_contact_error = maxf(max_contact_error, a.distance_to(b))
	for side in 2:
		max_contact_error = maxf(max_contact_error, (views[0]._targets[side]-origins[0]).distance_to(views[1]._targets[side]-origins[1]))

func _measure_bones() -> void:
	for view in views:
		view.apply_skeleton_pose(view._skeleton)
	var view := views[0]
	var skeleton := view._skeleton
	var chest := skeleton.get_bone_global_pose(view._spine).basis.get_rotation_quaternion()
	var other_chest := views[1]._skeleton.get_bone_global_pose(views[1]._spine).basis.get_rotation_quaternion()
	max_chest = maxf(max_chest, chest.angle_to(other_chest))
	# Subtract the simultaneously moving control actor: normal walk lean is not an idle snap.
	var chest_delta := chest * other_chest.inverse()
	if has_last:
		max_pose_step = maxf(max_pose_step, chest_delta.angle_to(last_chest_delta))
	last_chest_delta = chest_delta
	has_last = true
	var head := skeleton.get_bone_global_pose(view._head).basis.get_rotation_quaternion()
	var other_head := views[1]._skeleton.get_bone_global_pose(views[1]._head).basis.get_rotation_quaternion()
	max_head = maxf(max_head, head.angle_to(other_head))
	for chain in view._arms:
		var bone: int = chain[0]
		var parent := skeleton.get_bone_parent(bone)
		var local_offset := skeleton.get_bone_pose_position(bone) - skeleton.get_bone_rest(bone).origin
		var actual := skeleton.global_basis * skeleton.get_bone_global_pose(parent).basis * local_offset
		max_shoulder = maxf(max_shoulder, actual.length())
		max_shoulder_axis_error = maxf(max_shoulder_axis_error, actual.distance_to(Vector3.UP * view._idle.shoulder_lift * view._measured_leg_length))
	for current in views:
		for index in current._driven_bones.size():
			var actual: Transform3D = current._skeleton.get_bone_pose(current._driven_bones[index])
			max_cache_error = maxf(max_cache_error, _transform_error(actual, current._pose_current[index]))
		current._skeleton.reset_bone_poses()

func _pose_difference() -> float:
	var error := 0.0
	for index in views[0]._pose_current.size():
		var a: Transform3D = views[0]._pose_current[index]
		var b: Transform3D = views[1]._pose_current[index]
		error = maxf(error, a.origin.distance_to(b.origin))
		error = maxf(error, a.basis.x.distance_to(b.basis.x))
		error = maxf(error, a.basis.y.distance_to(b.basis.y))
		error = maxf(error, a.basis.z.distance_to(b.basis.z))
	return error

func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
func _transform_error(a: Transform3D, b: Transform3D) -> float:
	return maxf(maxf(a.origin.distance_to(b.origin), a.basis.x.distance_to(b.basis.x)), maxf(a.basis.y.distance_to(b.basis.y), a.basis.z.distance_to(b.basis.z)))

func _capture_body() -> void:
	DirAccess.make_dir_recursive_absolute(capture_path)
	root.size = Vector2i(1400, 650)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.10, 0.12, 0.15)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	settings.ambient_light_energy = 0.75
	environment.environment = settings
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-25, -20, 0)
	light.light_energy = 1.1
	world.add_child(light)
	var floor_mesh := MeshInstance3D.new()
	var floor_shape := BoxMesh.new()
	floor_shape.size = Vector3(100, 0.2, 200)
	floor_mesh.mesh = floor_shape
	floor_mesh.position.y = -0.1
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.20, 0.23, 0.27)
	floor_mesh.material_override = floor_material
	world.add_child(floor_mesh)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.5
	world.add_child(camera)
	camera.position = Vector3(0, 1.05, -6)
	camera.look_at(Vector3(0, 0.90, 0))
	camera.make_current()
	actors[1].body_profile.idle_enabled = false
	for index in 2:
		views[index]._idle._rng.seed = 41 + index
		views[index]._idle.reset()
	await _ticks(120)
	await _image("body_breath")
	await _ticks(280)
	await _image("body_sigh")
	# Reach a natural blink; do not overwrite shader or skeleton state for this picture.
	for tick in 150:
		if views[0]._idle.blink_amount > 0.85:
			break
		await _ticks(1)
	await _image("body_blink")

func _image(image_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path := capture_path.path_join(image_name + ".png")
	root.get_texture().get_image().save_png(path)
	print("IDLE BODY IMAGE ", path, " chest_degrees=", rad_to_deg(views[0]._idle.chest_pitch), " blink=", views[0]._idle.blink_amount)