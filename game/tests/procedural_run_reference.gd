extends SceneTree
## Meet dezelfde werkelijke renpose op twee bronversies; alleen expliciet uitgevoerd.
const CHARACTER = preload("res://characters/Character.tscn")
const AUDIO_SHUTDOWN = preload("res://tests/test_audio_shutdown.gd")
var actors: Array[AtlasCharacter] = []
var sample: Array[float] = []
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(500, 0.2, 500)
	collision.shape = shape
	floor_body.position.y = -0.1
	floor_body.add_child(collision)
	world.add_child(floor_body)
	for index in range(4):
		var actor := CHARACTER.instantiate() as AtlasCharacter
		actor.position = Vector3(index * 5.0, 0.04, 0)
		if index > 0:
			var profile := AtlasCharacterBodyProfile.new()
			profile.test_body = index - 1
			actor.body_profile = profile
		world.add_child(actor)
		actors.append(actor)
	await _ticks(30)
	for actor in actors:
		var intent := AtlasCharacterIntent.new()
		intent.movement = Vector2(0, -1)
		intent.sprint = true
		actor.submit_intent(intent)
	await _ticks(240)
	for tick in range(120):
		await _ticks(1)
		for actor in actors:
			_vector(actor.position)
			_vector(actor.velocity)
			var view: AtlasCharacterPresentation = actor.get_node("Presentation/ProceduralBody")
			sample.append(view._phase)
			for target in view._targets:
				_vector(target)
			view.apply_skeleton_pose(view._skeleton)
			for bone in view._driven_bones:
				var pose: Transform3D = view._skeleton.get_bone_global_pose(bone)
				_vector(pose.origin)
				_vector(pose.basis.x)
				_vector(pose.basis.y)
				_vector(pose.basis.z)
			view._skeleton.reset_bone_poses()
	var destination := "user://t011_run_reference.json"
	var comparison := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			destination = argument.trim_prefix("--output=")
		elif argument.begins_with("--compare="):
			comparison = argument.trim_prefix("--compare=")
	var max_error := 0.0
	var success := true
	if not comparison.is_empty():
		var file := FileAccess.open(comparison, FileAccess.READ)
		if file == null:
			success = false
		else:
			var baseline: Variant = JSON.parse_string(file.get_as_text())
			file.close()
			if not baseline is Array or baseline.size() != sample.size():
				success = false
			else:
				for index in range(sample.size()):
					max_error = maxf(max_error, absf(sample[index] - float(baseline[index])))
				success = max_error < 0.00001
	var output := FileAccess.open(destination, FileAccess.WRITE)
	if output == null:
		success = false
	else:
		output.store_string(JSON.stringify(sample))
		output.close()
	print("RUN_REFERENCE values=", sample.size(), " max_error=", max_error, " compared=", not comparison.is_empty(), " status=", "PASS" if success else "FAIL")
	world.queue_free()
	await AUDIO_SHUTDOWN.drain(self)
	quit(0 if success else 1)
func _vector(value: Vector3) -> void:
	sample.append(value.x)
	sample.append(value.y)
	sample.append(value.z)
func _ticks(count: int) -> void:
	for tick in range(count):
		await physics_frame
		await process_frame
