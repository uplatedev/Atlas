extends "res://tests/procedural_knee_checks.gd"
## Werkelijke richtingwissels, diagonalen, starten en stoppen op vier verhoudingen.
func _run() -> void:
	var records: Array = []
	for mode in ["walk", "jog", "run"]:
		_build(4, true)
		await _ticks(30)
		for direction in [Vector2(1, 0), Vector2(-1, 0), Vector2(1, -1).normalized(), Vector2(-1, -1).normalized(), Vector2(1, 1).normalized(), Vector2(-1, 1).normalized(), Vector2.ZERO]:
			_send_direction(direction, mode)
			var states := await _direction_sample(160, direction, mode)
			records.append({"mode": mode, "direction": str(direction), "bodies": states})
		world.queue_free()
		actors.clear()
		frames.clear()
		await _ticks(3)
	var output := FileAccess.open("user://t014_direction_style_metrics.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(records, "\t"))
	output.close()
	await AUDIO_SHUTDOWN.drain(self)
	print("DIRECTION STYLE CHECKS: ", "PASS" if failures.is_empty() else "FAIL " + str(failures))
	quit(0 if failures.is_empty() else 1)

func _send_direction(direction: Vector2, mode: String) -> void:
	for actor in actors:
		var intent := AtlasCharacterIntent.new()
		intent.movement = direction
		intent.walk = mode == "walk"
		intent.run = mode == "run"
		actor.submit_intent(intent)

func _direction_sample(count: int, direction: Vector2, mode: String) -> Array:
	var states: Array = []
	var previous: Array = []
	for index in 4:
		states.append({"target_error": 0.0, "pin_drift": 0.0, "min_gap": INF, "head_error": 0.0, "queries": 0, "contacts": [], "max_free_step": 0.0})
		previous.append({})
	for tick in count:
		await _ticks(1)
		for index in 4:
			var actor := actors[index]
			var view: AtlasCharacterPresentation = actor.get_node("Presentation/ProceduralBody")
			var frame: AtlasCharacterContactFrame = frames[index]
			var state: Dictionary = states[index]
			view.apply_skeleton_pose(view._skeleton)
			var feet: Array[Vector3] = []
			for side in 2:
				var points := _joint_points(view, actor.body_profile.leg_bones(side))
				feet.append(points[2])
				state.target_error = maxf(state.target_error, points[2].distance_to(view._targets[side]))
				if not previous[index].is_empty():
					if view._locked[side] and previous[index].locked[side] and not frame.stride_landed and not frame.ground_step and not frame.turn_step_landed:
						state.pin_drift = maxf(state.pin_drift, view._contacts[side].distance_to(previous[index].contacts[side]))
					if not view._locked[side]:
						state.max_free_step = maxf(state.max_free_step, points[2].distance_to(previous[index].feet[side]) - frame.horizontal_travel.length())
			state.min_gap = minf(state.min_gap, (feet[1] - feet[0]).dot(view._body_transform.basis.x))
			var head_delta := view._skeleton.get_bone_global_pose(view._head).basis * view._skeleton.get_bone_global_rest(view._head).basis.inverse()
			state.head_error = maxf(state.head_error, absf(head_delta.get_euler().y))
			state.queries = maxi(state.queries, view._rays_last_frame)
			state.contacts.append_array(view._contact_sides)
			previous[index] = {"locked": view._locked.duplicate(), "contacts": view._contacts.duplicate(), "feet": feet}
			_expect(not frame.jumped and not frame.landed, "richtingwissel maakt geen sprong of zware landing")
			if frame.direction_step:
				_expect(frame.ground_step and frame.real_grounded and frame.air_kind == "none" and view._contact_sides.size() == 1, "vroeg omkeercontact blijft een enkele echte gesteunde voetoverdracht")
			view._skeleton.reset_bone_poses()
	for index in 4:
		var state: Dictionary = states[index]
		var actor := actors[index]
		var view: AtlasCharacterPresentation = actor.get_node("Presentation/ProceduralBody")
		_expect(state.target_error < 0.003 and state.pin_drift < 0.00001, "bereikbare doelen en vaste contacten blijven behouden bij omkeren/start/stop")
		_expect(state.min_gap > 0.03, "richtingwissel laat de benen niet kruisen")
		_expect(state.head_error < 0.002 and absf(actor.rotation.y) < 0.00001, "richtingpose verandert geen hoofdblik of capsuleyaw")
		_expect(state.queries <= 2, "richtingwissel blijft binnen twee voetmetingen")
		if not direction.is_zero_approx():
			var limit := 60.0 if mode == "walk" else (70.0 if mode == "jog" else 80.0)
			var desired := -signf(direction.x) * deg_to_rad(limit if direction.y == 0.0 else 45.0 * (-1.0 if direction.y > 0.0 else 1.0))
			_expect(absf(view._gait_yaw - desired) < 0.003, "zij-/voor-/achterdiagonaal bereikt de juiste begrensde onderlichaamsrichting")
		else:
			_expect(view._speed < 0.01 and absf(view._gait_yaw) < 0.003, "stop herstelt de gewone rustoriëntatie")
		print("DIRECTION ", mode, " ", direction, " body=", index, " ", JSON.stringify(state))
	return states
