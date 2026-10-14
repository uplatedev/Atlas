extends "res://tests/procedural_knee_checks.gd"
## Echte directionele zijpassen op vier lichaamsverhoudingen, met behouden snelheden.
func _run() -> void:
	var report: Array = []
	for mode in ["walk", "jog", "run"]:
		if "--walk-only" in OS.get_cmdline_user_args() and mode != "walk":
			continue
		for direction in [Vector2(1, 0), Vector2(-1, 0)]:
			_build(4, true)
			await _ticks(30)
			for actor in actors:
				var intent := AtlasCharacterIntent.new()
				intent.movement = direction
				intent.walk = mode == "walk"
				intent.run = mode == "run"
				actor.submit_intent(intent)
			await _ticks(100)
			var states: Array = []
			var previous: Array = []
			for index in 4:
				states.append({"target_error": 0.0, "pin_drift": 0.0, "min_gap": INF, "min_shin_gap": INF, "min_free_sole": INF, "height_min": INF, "height_max": -INF, "air": 0, "single": 0, "double": 0, "speed_error": 0.0, "head_error": 0.0, "torso_max": 0.0, "yaw_min": INF, "yaw_max": -INF, "contacts": [], "queries": 0})
				previous.append({})
			for tick in 480:
				await _ticks(1)
				for index in 4:
					var actor: AtlasCharacter = actors[index]
					var view: AtlasCharacterPresentation = actor.get_node("Presentation/ProceduralBody")
					var frame: AtlasCharacterContactFrame = frames[index]
					var state: Dictionary = states[index]
					var expected_speed := 1.12 if mode == "walk" else (2.4 if mode == "jog" else 7.2)
					state.speed_error = maxf(state.speed_error, absf(frame.horizontal_speed - expected_speed))
					state.height_min = minf(state.height_min, actor.position.y)
					state.height_max = maxf(state.height_max, actor.position.y)
					state.air += int(frame.air_kind == "stride")
					var locks := int(view._locked[0]) + int(view._locked[1])
					state.single += int(locks == 1)
					state.double += int(locks == 2)
					state.queries = maxi(state.queries, view._rays_last_frame)
					state.yaw_min = minf(state.yaw_min, absf(view._gait_yaw))
					state.yaw_max = maxf(state.yaw_max, absf(view._gait_yaw))
					_expect(not frame.jumped and not frame.landed, "strafe maakt geen bewuste sprong of impactlanding")
					_expect(view._contact_sides.size() <= 1, "afwisselende pas heeft één echte contactcue")
					state.contacts.append_array(view._contact_sides)
					view.apply_skeleton_pose(view._skeleton)
					var feet: Array[Vector3] = []
					var knees: Array[Vector3] = []
					for side in 2:
						var points := _joint_points(view, actor.body_profile.leg_bones(side))
						feet.append(points[2])
						knees.append(points[1])
						var error := points[2].distance_to(view._targets[side])
						if error > state.target_error:
							state.worst = {"tick": tick, "side": side, "locked": view._locked.duplicate(), "phase": frame.gait_phase, "target": str(view._targets[side]), "ankle": str(points[2]), "hip": str(points[0]), "drop": view._planned_pelvis_drop, "replans": view._sole_replans}
						state.target_error = maxf(state.target_error, error)
						if not previous[index].is_empty() and previous[index].locked[side] and view._locked[side] and not frame.stride_landed and not frame.ground_step:
							state.pin_drift = maxf(state.pin_drift, view._contacts[side].distance_to(previous[index].contacts[side]))
						if not view._locked[side]:
							var world_basis := view._skeleton.global_basis * view._skeleton.get_bone_global_pose(view._legs[side][2]).basis
							var toe := points[2] + world_basis * (view._rest_foot_basis[side].inverse() * Vector3(0, -view._ankle_height, -view._toe_lengths[side]))
							var heel := points[2] + world_basis * (view._rest_foot_basis[side].inverse() * Vector3(0, -view._ankle_height, view._toe_lengths[side] * 0.25))
							state.min_free_sole = minf(state.min_free_sole, minf(toe.y, heel.y))
					state.min_gap = minf(state.min_gap, (feet[1] - feet[0]).dot(view._body_transform.basis.x))
					var closest := Geometry3D.get_closest_points_between_segments(knees[0], feet[0], knees[1], feet[1])
					state.min_shin_gap = minf(state.min_shin_gap, closest[0].distance_to(closest[1]))
					var head_delta := view._skeleton.get_bone_global_pose(view._head).basis * view._skeleton.get_bone_global_rest(view._head).basis.inverse()
					var torso_delta := view._skeleton.get_bone_global_pose(view._spine).basis * view._skeleton.get_bone_global_rest(view._spine).basis.inverse()
					state.head_error = maxf(state.head_error, absf(head_delta.get_euler().y))
					state.torso_max = maxf(state.torso_max, absf(torso_delta.get_euler().y))
					previous[index] = {"locked": view._locked.duplicate(), "contacts": view._contacts.duplicate()}
					view._skeleton.reset_bone_poses()
			for index in 4:
				var state: Dictionary = states[index]
				var expected_yaw := deg_to_rad(60.0 if mode == "walk" else (70.0 if mode == "jog" else 80.0))
				_expect(state.speed_error < 0.03, "bestaande zijwaartse snelheid blijft behouden")
				_expect(state.target_error < 0.003 and state.pin_drift < 0.00001, "echte enkels bereiken doelen; vaste contacten schuiven niet")
				_expect(state.min_gap > 0.03 and state.min_shin_gap > 0.03, "zichtbare voeten en schenen kruisen niet")
				_expect(state.min_free_sole >= -0.003, "vrije hiel en teen blijven boven de vloer")
				_expect(state.queries <= 2, "hoogstens twee voetmetingen per tick")
				_expect(state.head_error < 0.002 and state.torso_max < deg_to_rad(25.0), "hoofd en borst blijven bij de kijkrichting")
				_expect(absf(state.yaw_min - expected_yaw) < 0.002 and absf(state.yaw_max - expected_yaw) < 0.002, "Walk/Jog/Run hebben eigen begrensde onderlichaamsrichting")
				_expect(state.contacts.size() >= 8, "voldoende echte afwisselende voetcontacten")
				for contact in range(1, state.contacts.size()):
					_expect(state.contacts[contact] != state.contacts[contact - 1], "links/rechts wisselen per pas af")
				if mode == "walk":
					_expect(state.air == 0 and state.single > 20 and state.double > 5 and state.height_max - state.height_min < 0.01, "Walk-strafe houdt rustige voortdurende grondsteun")
				else:
					_expect(state.air > 20 and state.single > 20 and state.double == 0, "Jog/Run hebben enkelsteun en korte echte pasvlucht")
				print("STRAFE ", mode, " ", direction, " body=", index, " ", JSON.stringify(state))
				report.append({"mode": mode, "direction": str(direction), "body": index, "measured": state})
			world.queue_free()
			actors.clear()
			frames.clear()
			await _ticks(3)
	var output := FileAccess.open("user://t014_strafe_metrics.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	await AUDIO_SHUTDOWN.drain(self)
	print("STRAFE CHECKS: ", "PASS" if failures.is_empty() else "FAIL " + str(failures))
	quit(0 if failures.is_empty() else 1)
