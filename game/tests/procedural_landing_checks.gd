extends "res://tests/procedural_knee_checks.gd"
## Werkelijke enkelbaan over landing, steun en afzet; geen test van curveformules.
func _run() -> void:
	_build(4, true)
	await _ticks(30)
	_intent(1.0, true)
	await _ticks(120)
	var states: Array = []
	var previous: Array = [{}, {}, {}, {}]
	for index in 4:
		states.append({"landings": 0, "left": 0, "right": 0, "takeoffs": 0, "support_side": -1, "max_landing_speed_ratio": 0.0, "max_landing_distance": 0.0, "max_pin_drift": 0.0, "max_target_error": 0.0, "max_queries": 0})
	for tick in 240:
		await _ticks(1)
		for index in 4:
			var actor: AtlasCharacter = actors[index]
			var frame: AtlasCharacterContactFrame = frames[index]
			var view: AtlasCharacterPresentation = actor.get_node("Presentation/ProceduralBody")
			var state: Dictionary = states[index]
			var before: Dictionary = previous[index]
			view.apply_skeleton_pose(view._skeleton)
			var ankles: Array[Vector3] = []
			var speeds: Array[float] = [0.0, 0.0]
			for side in 2:
				var ankle := _joint_points(view, actor.body_profile.leg_bones(side))[2]
				ankles.append(ankle)
				state.max_target_error = maxf(state.max_target_error, ankle.distance_to(view._targets[side]))
				if not before.is_empty():
					speeds[side] = ankle.distance_to(before.ankles[side]) / frame.delta
					if before.locked[side] and view._locked[side] and not frame.stride_landed:
						state.max_pin_drift = maxf(state.max_pin_drift, ankle.distance_to(before.ankles[side]))
			if frame.stride_landed and not before.is_empty():
				var side := posmod(frame.step_index, 2)
				_expect(view._locked[side] and not view._locked[1 - side], "alleen de echte landingsvoet draagt lichaam %s" % index)
				_expect(frame.step_index == before.step + 1 and view._contact_sides == [side], "landing bewaart voetidentiteit en één contactcue lichaam %s" % index)
				_expect(speeds[side] < before.speeds[side], "dezelfde enkel remt verder af tot contact lichaam %s" % index)
				state.landings += 1
				state.left += int(side == 0)
				state.right += int(side == 1)
				state.support_side = side
				state.max_landing_speed_ratio = maxf(state.max_landing_speed_ratio, speeds[side] / frame.horizontal_speed)
				state.max_landing_distance = maxf(state.max_landing_distance, speeds[side] * frame.delta)
			if frame.stride_started and state.support_side >= 0:
				var side: int = state.support_side
				_expect(not before.is_empty() and before.locked[side] and side == posmod(frame.step_index, 2), "de landingsvoet zelf zet af lichaam %s" % index)
				_expect(not view._locked[0] and not view._locked[1], "afzet geeft beide voeten vrij zonder luchtsteun lichaam %s" % index)
				state.takeoffs += 1
			state.max_queries = maxi(state.max_queries, view._rays_last_frame)
			previous[index] = {"ankles": ankles, "speeds": speeds, "locked": view._locked.duplicate(), "step": frame.step_index}
			view._skeleton.reset_bone_poses()
	for index in 4:
		var state: Dictionary = states[index]
		var view: AtlasCharacterPresentation = actors[index].get_node("Presentation/ProceduralBody")
		_expect(state.left >= 6 and state.right >= 6 and state.takeoffs >= 12, "beide voeten herhaald door landing, steun en afzet gevolgd lichaam %s" % index)
		_expect(state.max_landing_speed_ratio < 0.20 and state.max_landing_distance < view.get_leg_length() * 0.04, "eindzwaai remt vóór vast contact af lichaam %s: %s" % [index, state])
		_expect(state.max_pin_drift < 0.00001 and state.max_target_error < 0.003 and view._released_overreach == 0, "landingsbaan en steun blijven echt bereikbaar en plaatsvast lichaam %s" % index)
		_expect(state.max_queries <= 2, "eindzwaai voegt geen grondqueries toe lichaam %s" % index)
	print("LANDING METRICS ", JSON.stringify(states))
	var output := FileAccess.open("user://t015_landing_metrics.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(states, "\t"))
	output.close()
	world.queue_free()
	await AUDIO_SHUTDOWN.drain(self)
	print("LANDING CHECKS: ", "PASS" if failures.is_empty() else "FAIL " + str(failures))
	quit(0 if failures.is_empty() else 1)
