extends "res://tests/procedural_turn_checks.gd"
## Echte borst- en hoofdbasis vóór de eerste bijstap; geen alleenliggende doelhoek.
func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(200, 0.2, 200)
	collision.shape = shape
	floor_body.position.y = -0.1
	floor_body.add_child(collision)
	world.add_child(floor_body)
	actor = CHARACTER.instantiate() as AtlasCharacter
	actor.position = Vector3(0, 0.05, 0)
	world.add_child(actor)
	actor.set_controlled(true)
	presentation = actor.get_node("Presentation/ProceduralBody")
	actor.contact_frame_ready.connect(_capture)
	await _ticks(12)
	for direction in [-1.0, 1.0]:
		await _measure_torso(direction, false)
		await _measure_torso(direction, true)
	await _profile_adjustments()
	world.queue_free()
	await AUDIO_SHUTDOWN.drain(self)
	for failure in failures:
		printerr("FAIL: ", failure)
	print("PROCEDURAL TORSO: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)

func _measure_torso(direction: float, abrupt: bool) -> void:
	await _reset()
	var first_step_tick := -1
	var first_step_chest := 0.0
	var first_step_head := 0.0
	var max_head_error := 0.0
	var max_neck := 0.0
	for tick in range(150):
		var degrees := 120.0 if abrupt else minf(float(tick), 120.0)
		_send(direction * deg_to_rad(degrees))
		await _ticks(1)
		var skeleton: Skeleton3D = presentation.get("_skeleton")
		presentation.apply_skeleton_pose(skeleton)
		var chest := _bone_yaw(skeleton, presentation.get("_spine"))
		var head := _bone_yaw(skeleton, presentation.get("_head"))
		var pelvis := _bone_yaw(skeleton, presentation.get("_pelvis"))
		var state := presentation.get_debug_state()
		max_head_error = maxf(max_head_error, absf(wrapf(head - actor.get_look_input().x, -PI, PI)))
		max_neck = maxf(max_neck, absf(wrapf(head - chest, -PI, PI)))
		if first_step_tick < 0 and int(state.turn_active_side) >= 0:
			first_step_tick = tick
			first_step_chest = absf(wrapf(chest - pelvis, -PI, PI))
			first_step_head = absf(head)
	_expect(first_step_tick >= 0, "grotere blik begint uiteindelijk afwisselende bijstappen")
	_expect(first_step_chest >= deg_to_rad(23.5), "borst draait merkbaar minstens24graden vóór eerste bijstap")
	_expect(max_neck <= deg_to_rad(actor.head_max_yaw + 0.2), "extra borstreserve overschrijdt de bestaande nekgrens niet")
	_expect(absf(float(presentation.get_debug_state().turn_body_offset)) < deg_to_rad(actor.body_profile.turn_step_angle_degrees * 0.38 + 0.2), "bijstappen eindigen na de borstreserve in een comfortabele stand")
	_expect(crossing_frames == 0 and lock_drift < 0.0001, "extra borstreserve bewaart gescheiden en geplante voeten")
	print("TORSO direction=", direction, " abrupt=", abrupt, " first_tick=", first_step_tick, " chest_before_step=", rad_to_deg(first_step_chest), " head_before_step=", rad_to_deg(first_step_head), " max_neck=", rad_to_deg(max_neck), " max_look_error=", rad_to_deg(max_head_error))

func _profile_adjustments() -> void:
	await _reset()
	var untouched := actor.body_profile.make_instance_unique()
	var old_visual: Node = presentation.get("_visual")
	actor.body_profile.turn_torso_max_degrees = 20.0
	actor.body_profile.turn_torso_before_step_degrees = 40.0
	_send(deg_to_rad(55.0))
	await _ticks(35)
	var skeleton: Skeleton3D = presentation.get("_skeleton")
	presentation.apply_skeleton_pose(skeleton)
	var chest := _bone_yaw(skeleton, presentation.get("_spine"))
	_expect(absf(chest - deg_to_rad(20.0)) < deg_to_rad(0.2), "Inspectorborstmaximum wordt live in de echte borstbasis gebruikt")
	_expect(presentation.get("_visual") == old_visual, "torsoafstelling bouwt het lichaam niet opnieuw op")
	_expect(untouched.turn_torso_max_degrees == 35.0 and untouched.turn_torso_before_step_degrees == 24.0, "eigen torsoafstelling verandert geen ander instanceprofiel")
	_send(deg_to_rad(120.0))
	await _ticks(120)
	_expect(int(presentation.get_debug_state().turn_step_index) > 0 and absf(float(presentation.get_debug_state().turn_body_offset)) < deg_to_rad(actor.body_profile.turn_step_angle_degrees * 0.38 + 0.2), "te hoge borst-wachthoek klemt veilig onder het maximum en blokkeert bijstappen niet")
	print("TORSO EDITOR live_chest=", rad_to_deg(chest), " max=20 threshold=40; independent/live/no-rebuild/completes PASS")
	for small_limit in [0.0, 1.0]:
		await _reset()
		actor.body_profile.turn_torso_max_degrees = small_limit
		_send(deg_to_rad(120.0))
		await _ticks(120)
		_expect(int(presentation.get_debug_state().turn_step_index) > 0 and absf(float(presentation.get_debug_state().turn_body_offset)) < deg_to_rad(actor.body_profile.turn_step_angle_degrees * 0.38 + 0.2), "nul of kleine live borstreserve blokkeert bijstappen niet")
		_expect(absf(float(presentation.get_debug_state().turn_torso_yaw)) <= deg_to_rad(small_limit + 0.1), "kleine borstinstelling blijft werkelijk binnen haar maximum")
	print("TORSO EDITOR maximum0/1 with threshold40: completes PASS")
func _bone_yaw(skeleton: Skeleton3D, index: int) -> float:
	var actual := (skeleton.global_basis * skeleton.get_bone_global_pose(index).basis * skeleton.get_bone_global_rest(index).basis.inverse()).orthonormalized()
	var forward := -actual.z
	return atan2(-forward.x, -forward.z)