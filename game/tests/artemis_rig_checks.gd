extends SceneTree
## Exporteerde Artemis: echte huiddeformatie en behouden schaal/botlengtes.

const MODEL = preload("res://assets/characters/artemis_rigged.glb")
var failures: Array[String] = []
var skeleton: Skeleton3D
var skinned_mesh: MeshInstance3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("FAIL: huid-bakecontrole vereist een echte renderer; voer deze suite zonder --headless uit.")
		quit(1)
		return
	var model := MODEL.instantiate()
	root.add_child(model)
	for node in model.find_children("*", "Skeleton3D", true, false):
		skeleton = node as Skeleton3D
	for node in model.find_children("*", "MeshInstance3D", true, false):
		if (node as MeshInstance3D).skin != null:
			skinned_mesh = node as MeshInstance3D
	if skeleton == null or skinned_mesh == null:
		printerr("FAIL: Artemis mist geïmporteerde Skeleton3D of skinbinding.")
		quit(1)
		return
	await process_frame
	await process_frame
	_expect(skeleton.get_bone_count() == 53, "runtime bevat uitsluitend de 53 deformbotten")
	_expect(model.find_children("*", "Camera3D", true, false).is_empty(), "runtime-export bevat geen camera")
	for index in skeleton.get_bone_count():
		_expect(not String(skeleton.get_bone_name(index)).begins_with("IK"), "geen Blender-IK-controls in runtime-skelet")
	for side in ["l", "r"]:
		_expect(absf(_joint_distance("thigh." + side, "calf." + side) - 0.3345376) < 0.00001, "bovenbeenlengte blijft bewaard: " + side)
		_expect(absf(_joint_distance("calf." + side, "foot." + side) - 0.3392383) < 0.00001, "onderbeenlengte blijft bewaard: " + side)
		_expect(absf(_joint_distance("upperarm." + side, "forearm." + side) - 0.2392528) < 0.00001, "bovenarmlengte blijft bewaard: " + side)
		_expect(absf(_joint_distance("forearm." + side, "hand." + side) - 0.2375192) < 0.00001, "onderarmlengte blijft bewaard: " + side)
		_expect(_joint("toes." + side).z < _joint("foot." + side).z, "voet wijst Godot -Z: " + side)
	_expect(_joint("thigh.l").x < 0.0 and _joint("thigh.r").x > 0.0, "links/rechts passen bij -Z-front")
	var normalized := true
	for surface in skinned_mesh.mesh.get_surface_count():
		var arrays := skinned_mesh.mesh.surface_get_arrays(surface)
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var influences := roundi(float(weights.size()) / maxf(float(positions.size()), 1.0))
		normalized = normalized and influences in [4, 8]
		for vertex in positions.size():
			var total := 0.0
			for influence in influences:
				total += weights[vertex * influences + influence]
			normalized = normalized and absf(total - 1.0) < 0.0001
	_expect(normalized, "alle geïmporteerde huidvertices hebben genormaliseerde skin weights, inclusief wenkbrauwen")
	var bind_mesh: ArrayMesh = skinned_mesh.bake_mesh_from_current_skeleton_pose()
	var baseline := _vertices(bind_mesh)
	_expect(not baseline.is_empty(), "Godot kan de werkelijk geïmporteerde skin naar vertices evalueren")
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	for vertex in baseline:
		var point := skinned_mesh.global_transform * vertex
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	_expect(absf(minimum.y) < 0.0001 and absf(maximum.y - 1.7385552) < 0.0001, "voetoorsprong en werkelijke modelhoogte blijven in meters bewaard")
	for bone_name in ["upperarm.l", "upperarm.r", "hand.l", "hand.r", "index.001.l", "index.001.r", "calf.l", "calf.r", "head"]:
		skeleton.reset_bone_poses()
		var index := skeleton.find_bone(bone_name)
		skeleton.set_bone_pose_rotation(index, skeleton.get_bone_rest(index).basis.get_rotation_quaternion() * Quaternion(Vector3.RIGHT, deg_to_rad(35)))
		skeleton.force_update_all_bone_transforms()
		await process_frame
		var posed := _vertices(skinned_mesh.bake_mesh_from_current_skeleton_pose())
		var moved := 0
		var greatest := 0.0
		for vertex in mini(baseline.size(), posed.size()):
			var distance := baseline[vertex].distance_to(posed[vertex])
			moved += 1 if distance > 0.00001 else 0
			greatest = maxf(greatest, distance)
		_expect(posed.size() == baseline.size() and moved >= 4 and greatest > 0.005, bone_name + " vervormt na echte Godot-import zichtbare huidvertices")
		print("MEASURE: Godot Artemis %s: %d vertices bewegen; maximaal %.6f m." % [bone_name, moved, greatest])
	skeleton.reset_bone_poses()
	await _capture_checks(model)
	print("MEASURE: Godot Artemis bones %d, surfaces %d, skin vertices %d, bounds %s / %s." % [skeleton.get_bone_count(), skinned_mesh.mesh.get_surface_count(), baseline.size(), minimum, maximum])
	model.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: Artemis skinning, arm-/hand-/vinger-/knie-/hoofddeformatie, rustlengtes, meterschaal en -Z-front.")
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: ", failure)
		quit(1)


func _capture_checks(model: Node3D) -> void:
	var destination := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--rig-captures="):
			destination = arg.trim_prefix("--rig-captures=")
	if destination.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(destination)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.13, 0.15, 0.18)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color.WHITE
	world.environment.ambient_light_energy = 0.65
	model.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -25, 0)
	light.light_energy = 1.1
	model.add_child(light)
	var camera := Camera3D.new()
	model.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.0
	camera.position = Vector3(2.4, 2.1, -5)
	camera.look_at(Vector3(0, 0.87, 0))
	camera.current = true
	for pose in ["rest", "flex"]:
		skeleton.reset_bone_poses()
		if pose == "flex":
			for side in ["l", "r"]:
				_rotate_world("upperarm." + side, Vector3.RIGHT, 35.0)
				_rotate_world("forearm." + side, Vector3.RIGHT, 45.0)
				_rotate_world("thigh." + side, Vector3.RIGHT, 25.0)
				_rotate_world("calf." + side, Vector3.RIGHT, -50.0)
				_rotate_world("hand." + side, Vector3.FORWARD if side == "r" else Vector3.BACK, 20.0)
		skeleton.force_update_all_bone_transforms()
		await process_frame
		await RenderingServer.frame_post_draw
		var error := root.get_texture().get_image().save_png(destination.path_join("rig-godot-" + pose + ".png"))
		_expect(error == OK, "Godot-controlebeeld geschreven: " + pose)


func _rotate_world(name: String, axis: Vector3, degrees: float) -> void:
	var index := skeleton.find_bone(name)
	var local_axis := skeleton.get_bone_global_rest(index).basis.inverse() * axis
	skeleton.set_bone_pose_rotation(index, skeleton.get_bone_rest(index).basis.get_rotation_quaternion() * Quaternion(local_axis.normalized(), deg_to_rad(degrees)))


func _joint(name: String) -> Vector3:
	var index := skeleton.find_bone(name)
	_expect(index >= 0, "verwacht rigbot aanwezig: " + name)
	return skeleton.global_transform * skeleton.get_bone_global_rest(index).origin if index >= 0 else Vector3.ZERO


func _joint_distance(a: String, b: String) -> float:
	return _joint(a).distance_to(_joint(b))


func _vertices(mesh: ArrayMesh) -> PackedVector3Array:
	var result := PackedVector3Array()
	if mesh != null:
		for surface in mesh.get_surface_count():
			result.append_array(mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX])
	return result


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)