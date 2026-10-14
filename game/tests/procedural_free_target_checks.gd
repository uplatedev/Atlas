extends "res://tests/procedural_knee_checks.gd"
## Richtings-/gangwissels met echte doelen vóór IK; pins en herhaald toepassen blijven intact.
func _run() -> void:
	var directions:Array[Vector2]=[Vector2(0,-1),Vector2(1,-1).normalized(),Vector2(1,0),Vector2(1,1).normalized(),Vector2(0,1),Vector2(-1,1).normalized(),Vector2(-1,0),Vector2(-1,-1).normalized(),Vector2(1,0),Vector2(-1,0),Vector2(0,-1),Vector2(0,1),Vector2.ZERO]
	var reports:Array=[]
	for mode in ["jog", "sprint", "walk"]:
		_build(4,true)
		await _ticks(30)
		var states:Array=[]
		var previous:Array=[]
		for index in 4:
			states.append({"target_error":0.0,"pin_error":0.0,"pin_drift":0.0,"reapply_drift":0.0,"pose_reapply_error":0.0,"free_adjustment":0.0,"releases":0})
			previous.append({})
		for route in directions.size():
			for actor in actors:
				var intent:=AtlasCharacterIntent.new()
				intent.movement=directions[route]
				intent.sprint=mode=="sprint"
				intent.sneak=mode=="walk"
				actor.submit_intent(intent)
			for tick in 100:
				await _ticks(1)
				for index in 4:
					var actor:AtlasCharacter=actors[index]
					var view:AtlasCharacterPresentation=actor.get_node("Presentation/ProceduralBody")
					var state:Dictionary=states[index]
					var frame:AtlasCharacterContactFrame=frames[index]
					var before:Array=view._targets.duplicate()
					view.apply_skeleton_pose(view._skeleton)
					view.apply_skeleton_pose(view._skeleton)
					for pose_index in view._driven_bones.size():
						var actual := view._skeleton.get_bone_pose(view._driven_bones[pose_index])
						var cached := view._pose_current[pose_index]
						state.pose_reapply_error = maxf(state.pose_reapply_error, actual.origin.distance_to(cached.origin))
						for axis in 3:
							state.pose_reapply_error = maxf(state.pose_reapply_error, actual.basis[axis].distance_to(cached.basis[axis]))
					for side in 2:
						var points:=_joint_points(view,actor.body_profile.leg_bones(side))
						var error:=points[2].distance_to(view._targets[side])
						state.target_error=maxf(state.target_error,error)
						state.reapply_drift=maxf(state.reapply_drift,Vector3(before[side]).distance_to(view._targets[side]))
						if view._locked[side]:
							state.pin_error=maxf(state.pin_error,error)
							if previous[index].has("locked") and previous[index].locked[side] and frame.foot_contacts.is_empty():
								state.pin_drift=maxf(state.pin_drift,view._contacts[side].distance_to(previous[index].contacts[side]))
					state.free_adjustment=view._max_free_target_adjustment
					state.releases=view._released_overreach
					previous[index]={"locked":view._locked.duplicate(),"contacts":view._contacts.duplicate()}
					view._skeleton.reset_bone_poses()
		for index in 4:
			var state:Dictionary=states[index]
			_expect(state.target_error<0.003 and state.pin_error<0.003,"alle echte doelen bereikbaar na %s-richtingswissels lichaam%s: %s"%[mode,index,state])
			_expect(state.pin_drift<0.00001 and state.releases==0,"richtingswissel bewaart echte pin zonder noodloslating %s/%s"%[mode,index])
			_expect(state.reapply_drift==0.0 and state.pose_reapply_error<0.00001,"pose opnieuw toepassen herplant/verplaatst geen doel %s/%s"%[mode,index])
			_expect(state.free_adjustment<0.04,"vrije bereikplanning blijft een kleine correctie %s/%s: %s"%[mode,index,state.free_adjustment])
		print("FREE TARGET ",mode," ",JSON.stringify(states))
		reports.append({"mode":mode,"bodies":states})
		world.queue_free()
		actors.clear()
		frames.clear()
		await _ticks(3)
	reports.append(await _blocked_input_turn())
	reports.append(await _blocked_input_turn(0.6, PI))
	reports.append(await _blocked_input_turn(0.6, -PI))
	var file:=FileAccess.open("user://t011_free_target_metrics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(reports,"	"))
	file.close()
	await AUDIO_SHUTDOWN.drain(self)
	print("FREE TARGET CHECKS: ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)

func _blocked_input_turn(wall_offset: float = 0.45, turn_yaw: float = PI) -> Dictionary:
	_build(4, true)
	# Binnenmaat0,70m geeft langdurige echte blokkade.1,00m laat tussendoor
	# werkelijk lopen en test de overgang terug naar stilstand met grote blikdraai.
	for actor in actors:
		for offset in [Vector3(0,0,-wall_offset), Vector3(0,0,wall_offset), Vector3(-wall_offset,0,0), Vector3(wall_offset,0,0)]:
			var wall := StaticBody3D.new()
			var collider := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(1.4,3,0.2) if offset.z != 0.0 else Vector3(0.2,3,1.4)
			collider.shape = shape
			wall.add_child(collider)
			wall.position = actor.position + offset + Vector3.UP * 1.3
			world.add_child(wall)
	await _ticks(30)
	var stats := {"blocked_input":true,"inner_width":wall_offset*2.0-0.2,"turn_yaw":turn_yaw,"minimum_gap":INF,"max_target":0.0,"max_pin_drift":0.0,"max_queries":0,"turn_steps":0}
	var previous: Array = [{},{},{},{}]
	for tick in 300:
		for actor in actors:
			var intent := AtlasCharacterIntent.new()
			intent.movement = Vector2(0,-1)
			intent.has_look_direction = true
			intent.look_direction = Vector2(turn_yaw if tick > 80 else 0.0,0.0)
			actor.submit_intent(intent)
		await _ticks(1)
		for index in 4:
			var actor: AtlasCharacter = actors[index]
			var view: AtlasCharacterPresentation = actor.get_node("Presentation/ProceduralBody")
			var frame: AtlasCharacterContactFrame = frames[index]
			_expect(frame.movement_requested, "motor meldt blijvende invoer ook als collision de capsule stopt")
			view.apply_skeleton_pose(view._skeleton)
			var left := _joint_points(view, actor.body_profile.leg_bones(0))
			var right := _joint_points(view, actor.body_profile.leg_bones(1))
			stats.minimum_gap = minf(stats.minimum_gap,(right[2]-left[2]).dot((right[0]-left[0]).normalized()))
			stats.max_target = maxf(stats.max_target,maxf(left[2].distance_to(view._targets[0]),right[2].distance_to(view._targets[1])))
			for side in 2:
				if previous[index].has("locked") and previous[index].locked[side] and view._locked[side] and frame.foot_contacts.is_empty():
					stats.max_pin_drift = maxf(stats.max_pin_drift,view._contacts[side].distance_to(previous[index].contacts[side]))
			previous[index] = {"locked":view._locked.duplicate(),"contacts":view._contacts.duplicate()}
			stats.max_queries = maxi(stats.max_queries,view._rays_last_frame)
			view._skeleton.reset_bone_poses()
	for actor in actors:
		var view: AtlasCharacterPresentation = actor.get_node("Presentation/ProceduralBody")
		stats.turn_steps += view._turn_planner.step_index
		_expect(view._locked[0] and view._locked[1], "langdurig geblokkeerde invoer eindigt met twee gelande voeten")
		_expect(view._released_overreach == 0, "muurdraai heeft geen cosmetische noodloslating nodig")
		actor.submit_intent(AtlasCharacterIntent.new())
	await _ticks(30)
	for index in 4:
		_expect(not frames[index].movement_requested,"loslaten wist feitelijke loopinvoer in volgend motorframe")
	_expect(stats.minimum_gap > 0.06 and (wall_offset > 0.45 or stats.turn_steps >= 8), "blijvende muurinvoer laat veilige echte bijstappen toe: "+str(stats))
	_expect(stats.max_target < 0.003 and stats.max_pin_drift < 0.00001 and stats.max_queries <= 2,"muurcontacten blijven echt en plaatsvast binnen twee queries: "+str(stats))
	print("BLOCKED INPUT ",JSON.stringify(stats))
	world.queue_free()
	actors.clear()
	frames.clear()
	await _ticks(3)
	return stats