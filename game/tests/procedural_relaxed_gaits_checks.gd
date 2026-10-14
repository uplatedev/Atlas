extends "res://tests/procedural_knee_checks.gd"
## Drie echte gangen met dezelfde motor en vier gemeten lichaamsverhoudingen.
func _run() -> void:
	var metrics:Dictionary={}
	for style in ["walk","jog","sprint"]:
		_build(4,true)
		await _ticks(30)
		for actor in actors:
			var intent:=AtlasCharacterIntent.new()
			intent.movement=Vector2(0,-1)
			intent.sneak=style=="walk"
			intent.sprint=style=="sprint"
			actor.submit_intent(intent)
		var states:Array=[]
		for index in range(4):
			states.append({"air_frames":0,"steps":0,"max_error":0.0,"max_drop":0.0,"max_elbow":0.0,"min_elbow":180.0,"max_foot_height":0.0,"speed":0.0,"locked_min":2,"rays":0})
		for tick in range(210):
			await _ticks(1)
			for index in range(4):
				var actor:=actors[index]
				var view:AtlasCharacterPresentation=actor.get_node("Presentation/ProceduralBody")
				var frame:AtlasCharacterContactFrame=frames[index]
				var state:Dictionary=states[index]
				view.apply_skeleton_pose(view._skeleton)
				var lock_count:=0
				for side in range(2):
					var leg:=_joint_points(view,actor.body_profile.leg_bones(side))
					var arm:=_joint_points(view,actor.body_profile.arm_bones(side))
					var flex:=180.0-rad_to_deg((arm[0]-arm[1]).angle_to(arm[2]-arm[1]))
					state.max_error=maxf(state.max_error,leg[2].distance_to(view._targets[side]))
					if tick>40:
						state.max_elbow=maxf(state.max_elbow,flex)
						state.min_elbow=minf(state.min_elbow,flex)
						state.max_foot_height=maxf(state.max_foot_height,actor.to_local(leg[2]).y-view._ankle_height)
					if view._locked[side]: lock_count+=1
				state.locked_min=mini(state.locked_min,lock_count)
				state.rays=maxi(state.rays,view._rays_last_frame)
				state.air_frames+=1 if frame.air_kind=="stride" else 0
				state.steps+=1 if frame.ground_step or frame.stride_landed else 0
				state.speed=frame.horizontal_speed
				state.max_drop=maxf(state.max_drop,view._skeleton.get_bone_rest(view._pelvis).origin.y-view._skeleton.get_bone_pose(view._pelvis).origin.y)
				if style=="walk":
					_expect(frame.supported and frame.air_kind=="none" and lock_count>=1,"Alt-wandelen houdt daadwerkelijke steun")
				_expect(not frame.jumped and not frame.landed,"passen veroorzaken geen sprong of zware landing")
				view._skeleton.reset_bone_poses()
		for index in range(4):
			var state:Dictionary=states[index]
			_expect(state.max_error<0.003,"enkels bereiken hun doelen %s/%d: %f"%[style,index,state.max_error])
			_expect(state.steps>5 and state.rays<=2,"gang wisselt voeten met begrensde lokale metingen")
			if style=="walk":
				_expect(state.air_frames==0 and state.max_elbow<35.0,"wandeling met lage ontspannen armen")
			else:
				_expect(state.air_frames>10,"jog en sprint behouden echte pasvlucht")
		metrics[style]=states
		world.queue_free()
		actors.clear()
		frames.clear()
		await _ticks(3)
	var file:=FileAccess.open("user://t011_relaxed_gaits_metrics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics,"\t"))
	file.close()
	print("RELAXED GAITS ",JSON.stringify(metrics))
	await AUDIO_SHUTDOWN.drain(self)
	print("RELAXED GAITS CHECKS: ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)
