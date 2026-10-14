extends SceneTree
## Real Artemis eye surface, resource isolation, timing and optional GPU captures.
const MODEL = preload("res://assets/characters/artemis_rigged.glb")
const IDLE = preload("res://characters/procedural/idle_motion.gd")
const TEST_BODY = preload("res://characters/procedural/test_humanoid.gd")
var failures: Array[String] = []
var world: Node3D
var camera: Camera3D
var models: Array[Node3D] = []
var helpers: Array[AtlasIdleMotion] = []
var capture_path: String = ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--idle-captures="):
			capture_path = argument.trim_prefix("--idle-captures=")
	world = Node3D.new()
	root.add_child(world)
	var profile := AtlasCharacterBodyProfile.new()
	var signature := profile.rig_signature()
	var independent := profile.make_instance_unique()
	independent.idle_breath_degrees = 1.8
	independent.idle_blink_seconds = Vector2(8, 9)
	_expect(profile.idle_breath_degrees == 0.55 and profile.idle_blink_seconds == Vector2(3, 7), "idle fields are instance independent")
	_expect(signature == independent.rig_signature(), "idle settings never rebuild the rig")
	for index in 2:
		var model := MODEL.instantiate() as Node3D
		world.add_child(model)
		models.append(model)
		var mesh := _mesh(model)
		var original := mesh.mesh
		var helper := IDLE.new()
		helper.setup(model, profile.make_instance_unique())
		helper._rng.seed = index + 13
		helper.reset()
		helpers.append(helper)
		_expect(helper.mesh_builds == 1 and helper._materials.size() == 1, "only Eyes gets one mesh copy and one private material")
		_expect(mesh.mesh != original and mesh.mesh.get_surface_count() == original.get_surface_count(), "imported mesh remains untouched")
		for surface in original.get_surface_count():
			var before := original.surface_get_arrays(surface)
			var after := mesh.mesh.surface_get_arrays(surface)
			_expect(before[Mesh.ARRAY_BONES] == after[Mesh.ARRAY_BONES] and before[Mesh.ARRAY_WEIGHTS] == after[Mesh.ARRAY_WEIGHTS], "all eight skin weights survive the eye copy")
			_expect(before[Mesh.ARRAY_INDEX] == after[Mesh.ARRAY_INDEX], "surface topology survives")
			var source_lods: Array = RenderingServer.mesh_get_surface(original.get_rid(), surface).get("lods", [])
			var copied_lods: Array = RenderingServer.mesh_get_surface(mesh.mesh.get_rid(), surface).get("lods", [])
			_expect(source_lods == copied_lods, "imported LOD indices and distances survive")
			var positions: PackedVector3Array = before[Mesh.ARRAY_VERTEX]
			for vertex in positions.size():
				_expect(positions[vertex].distance_to(after[Mesh.ARRAY_VERTEX][vertex]) < 0.00001, "body geometry stays intact")
			if surface == 3:
				_expect(before[Mesh.ARRAY_TEX_UV] != after[Mesh.ARRAY_TEX_UV], "empty eye UVs become stable blink coordinates")
			else:
				_expect(mesh.get_surface_override_material(surface) == null, "no other material is replaced")
		var copy_id := mesh.mesh.get_instance_id()
		helper._profile.idle_breath_degrees = 0.65
		helper.setup(model, helper._profile)
		_expect(mesh.mesh.get_instance_id() == copy_id and helper.mesh_builds == 1, "live tuning/setup reuse creates no rig or mesh rebuild")
	_expect(helpers[0]._materials[0] != helpers[1]._materials[0], "characters never share mutable eye parameters")
	var async_frames := 0
	var max_chest := 0.0
	for tick in 7200:
		for helper in helpers:
			helper.advance(1.0 / 60.0, true)
			max_chest = maxf(max_chest, absf(helper.chest_pitch))
			_expect(is_finite(helper.chest_pitch) and helper.blink_amount >= 0.0 and helper.blink_amount <= 1.0, "idle output remains finite and bounded")
		if absf(helpers[0].blink_amount - helpers[1].blink_amount) > 0.1:
			async_frames += 1
	for helper in helpers:
		_expect(helper.blink_count >= 10 and helper.blink_count <= 40 and helper.sigh_count >= 2 and helper.sigh_count <= 6, "bounded blink and sigh cadence over two minutes")
		for tick in 20:
			helper.advance(1.0 / 60.0, false)
		_expect(helper.weight == 0.0 and helper.chest_pitch == 0.0 and helper.head_pitch == 0.0 and helper.shoulder_lift == 0.0 and helper.blink_amount == 0.0, "leaving idle settles all additive values to exact zero")
		_expect(helper.mesh_builds == 1, "advance performs no mesh rebuild")
	_expect(async_frames > 100, "two instances blink asynchronously")
	var bounded := IDLE.new()
	var tuning := profile.make_instance_unique()
	tuning.idle_breath_seconds = Vector2(50, -2)
	tuning.idle_blink_seconds = Vector2(-8, -4)
	tuning.idle_sigh_seconds = Vector2(500, 400)
	bounded._profile = tuning
	bounded.reset()
	_expect(bounded._breath_duration >= 2.0 and bounded._breath_duration <= 12.0 and bounded._blink_wait == 0.5 and bounded._sigh_wait == 120.0, "reversed and out-of-range editor intervals are bounded")
	tuning.idle_enabled = false
	for tick in 60:
		bounded.advance(1.0 / 60.0, true)
	_expect(bounded.weight == 0.0 and bounded.blink_count == 0 and bounded.sigh_count == 0, "disabled idle starts no event")
	bounded.reset()
	_expect(bounded.chest_pitch == 0.0 and bounded.blink_amount == 0.0 and bounded.blink_count == 0, "reset clears events, pose and material state")
	var unsupported := TEST_BODY.build(0, Color.WHITE)
	world.add_child(unsupported)
	var fallback := IDLE.new()
	fallback.setup(unsupported, profile)
	_expect(fallback.mesh_builds == 0 and fallback._materials.is_empty(), "test humanoids without Eyes receive no blink shader")
	unsupported.queue_free()
	print("IDLE METRICS async_frames=", async_frames, " max_chest_degrees=", rad_to_deg(max_chest), " blinks=", [helpers[0].blink_count, helpers[1].blink_count], " sighs=", [helpers[0].sigh_count, helpers[1].sigh_count])
	if not capture_path.is_empty() and DisplayServer.get_name() != "headless":
		await _capture_eyes()
	world.queue_free()
	await process_frame
	for failure in failures:
		printerr("FAIL: ", failure)
	print("IDLE CHECKS: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)

func _mesh(model: Node3D) -> MeshInstance3D:
	return model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D

func _capture_eyes() -> void:
	DirAccess.make_dir_recursive_absolute(capture_path)
	root.size = Vector2i(1000, 680)
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
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 0.83
	world.add_child(camera)
	models[0].position.x = -0.24
	models[1].position.x = 0.24
	for pose in [0.0, 0.55, 1.0]:
		helpers[0].blink_amount = pose
		helpers[0]._update_eyes()
		helpers[1].blink_amount = 0.0
		helpers[1]._update_eyes()
		camera.position = Vector3(0, 1.56, -3)
		camera.look_at(Vector3(0, 1.56, 0))
		await _image("front_" + str(pose))
	models[1].visible = false
	models[0].position.x = 0.0
	var skeleton := models[0].find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var head := skeleton.find_bone("head")
	var rest := skeleton.get_bone_rest(head).basis.get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(head, Quaternion(Vector3.UP, 0.25) * Quaternion(Vector3.RIGHT, 0.12) * rest)
	helpers[0].blink_amount = 1.0
	helpers[0]._update_eyes()
	camera.size = 0.48
	camera.position = Vector3(1.0, 1.57, -2)
	camera.look_at(Vector3(0, 1.57, 0))
	await _image("side_closed_look")

func _image(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var path := capture_path.path_join(name + ".png")
	root.get_texture().get_image().save_png(path)
	print("IDLE IMAGE ", path)

func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)