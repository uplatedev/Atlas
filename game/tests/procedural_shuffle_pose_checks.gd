extends "res://tests/procedural_knee_checks.gd"
## Wereldvaste vlakke zool, zichtbare vrije opening en echte hiel/teenhoogte.
func _run() -> void:
	var report: Array=[]
	for sprinting in [false,true]:
		_build(4,true)
		await _ticks(20)
		var previous: Array=[{},{},{},{}]
		var states: Array=[]
		for index in 4:
			states.append({"target_error":0.0,"pin_marker_drift":0.0,"pin_samples":0,"basis_change":0.0,"min_air_sole":INF,"min_air_ankle":INF,"max_air_gap":0.0,"min_air_gap":INF,"max_ground_gap":0.0,"air_samples":0,"max_queries":0,"min_sole_before":INF,"max_sole_correction":0.0,"max_sole_replans":0,"ankle_limit_error":0.0})
		for tick in 240:
			for actor in actors:
				var intent:=AtlasCharacterIntent.new()
				intent.movement=Vector2(1,0)
				intent.sprint=sprinting
				intent.has_look_direction=true
				intent.look_direction=Vector2(0.0 if tick<120 else sin(float(tick-120)*0.035)*2.0,0.0)
				actor.submit_intent(intent)
			await _ticks(1)
			for index in 4:
				var actor:AtlasCharacter=actors[index]
				var view:AtlasCharacterPresentation=actor.get_node("Presentation/ProceduralBody")
				var frame:AtlasCharacterContactFrame=frames[index]
				var state:Dictionary=states[index]
				view.apply_skeleton_pose(view._skeleton)
				var markers: Array[Vector3]=[]
				for side in 2:
					state.min_sole_before=minf(state.min_sole_before,view._sole_clearance_before[side])
					state.max_sole_correction=maxf(state.max_sole_correction,view._sole_corrections[side])
					state.max_sole_replans=maxi(state.max_sole_replans,view._sole_replans)
					var points:=_joint_points(view,actor.body_profile.leg_bones(side))
					state.target_error=maxf(state.target_error,points[2].distance_to(view._targets[side]))
					var world_basis:=view._skeleton.global_basis*view._skeleton.get_bone_global_pose(view._legs[side][2]).basis
					var toe:=points[2]+world_basis*(view._rest_foot_basis[side].inverse()*Vector3(0,-view._ankle_height,-view._toe_lengths[side]))
					var heel:=points[2]+world_basis*(view._rest_foot_basis[side].inverse()*Vector3(0,-view._ankle_height,view._toe_lengths[side]*0.25))
					markers.append(toe)
					if not view._locked[side]:
						var normal:Vector3=view._normals[side]
						var forward:Vector3=(-view._body_transform.basis.z).slide(normal).normalized()
						var foot_up:Vector3=(world_basis*view._rest_foot_basis[side].inverse()).y
						var pitch:=atan2(-foot_up.dot(forward),foot_up.dot(normal))
						var shin:Vector3=(points[1]-points[2]).normalized()
						var relative:=pitch+atan2(shin.dot(forward),shin.dot(normal))
						state.ankle_limit_error=maxf(state.ankle_limit_error,maxf(relative-deg_to_rad(actor.body_profile.ankle_dorsiflex_degrees),-deg_to_rad(actor.body_profile.ankle_plantarflex_degrees)-relative))
					if tick>40 and not frame.supported and frame.air_kind=="stride":
						var normal:Vector3=view._normals[side]
						var ground:Vector3=view._contacts[side]
						var clearance:=minf((toe-ground).dot(normal),(heel-ground).dot(normal))
						if clearance<state.min_air_sole:
							state.min_air_sole=clearance
							state.lowest={"tick":tick,"phase":frame.gait_phase,"side":side,"sole":clearance,"ankle":points[2].y,"ground":ground.y,"body":actor.global_position.y,"pitch":view._foot_pitch(side),"target":view._targets[side]}
						state.min_air_ankle=minf(state.min_air_ankle,points[2].y-ground.y)
						state.air_samples+=1
					if previous[index].has("markers") and previous[index].locked[side] and view._locked[side] and frame.foot_contacts.is_empty() and not view._turn_planner.enabled and absf(view._foot_roll[side])<0.00001:
						state.pin_marker_drift=maxf(state.pin_marker_drift,previous[index].markers[side].distance_to(toe))
						state.pin_samples+=1
						state.basis_change=maxf(state.basis_change,previous[index].basis.angle_to(actor.global_basis.get_rotation_quaternion()))
				var gap:float=(view._targets[1]-view._targets[0]).dot(view._body_transform.basis.x)
				if tick>40 and tick<120:
					if frame.air_kind=="stride":
						state.max_air_gap=maxf(state.max_air_gap,gap)
						state.min_air_gap=minf(state.min_air_gap,gap)
					elif frame.supported:
						state.max_ground_gap=maxf(state.max_ground_gap,gap)
				state.max_queries=maxi(state.max_queries,view._rays_last_frame)
				previous[index]={"markers":markers,"locked":view._locked.duplicate(),"basis":actor.global_basis.get_rotation_quaternion()}
				view._skeleton.reset_bone_poses()
		for index in 4:
			var state:Dictionary=states[index]
			_expect(state.target_error<0.003,"shuffle bereikt echte doelen %s/%d: %s"%[sprinting,index,state.target_error])
			_expect(state.pin_marker_drift<0.003,"vlakke zool draait niet weg van het wereldcontact %s/%d: %s"%[sprinting,index,state.pin_marker_drift])
			_expect(state.pin_samples>10 and state.basis_change>0.01,"proef draait het lichaam tijdens echte vlakke steun")
			_expect(state.air_samples>10 and state.min_air_gap>0.02,"shuffle blijft vrij en kruist niet")
			_expect(state.min_air_sole>=-0.003,"echte vrije hiel/teen blijft boven bekend grondvlak: %s/%d %s"%[sprinting,index,state.min_air_sole])
			_expect(state.ankle_limit_error<0.002,"echte vrije voet behoudt anatomische enkelgrenzen")
			_expect(state.max_sole_replans<=2,"hoogstens één herstel per vrije voet")
			_expect(state.max_queries<=2,"geen extra grondqueries voor opening of zoolmeting")
		print("SHUFFLE POSE ",sprinting," ",JSON.stringify(states))
		report.append({"sprinting":sprinting,"bodies":states})
		world.queue_free()
		actors.clear()
		frames.clear()
		await _ticks(2)
	var file:=FileAccess.open("user://t011_shuffle_pose_metrics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	await AUDIO_SHUTDOWN.drain(self)
	print("SHUFFLE POSE CHECKS: ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)
