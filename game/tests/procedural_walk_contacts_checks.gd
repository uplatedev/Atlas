extends "res://tests/procedural_knee_checks.gd"
## Eerste stap, beide zijrichtingen, omkeren en smal stoppen met echte motor en botten.
func _run() -> void:
	Engine.max_fps=144
	var results:Dictionary={}
	for direction in [Vector2(0,-1),Vector2(1,0),Vector2(-1,0),Vector2(1,-1).normalized(),Vector2(-1,-1).normalized()]:
		_build(4,true)
		await _ticks(30)
		var initial:Array=[]
		for actor in actors:
			var view:AtlasCharacterPresentation=actor.get_node("Presentation/ProceduralBody")
			initial.append((view._targets[1]-view._targets[0]).dot(actor.global_basis.x))
		_send_walk(direction)
		var start:=await _measure(180,true)
		var reverse:Array=[]
		if direction.x!=0.0:
			_send_walk(-direction)
			reverse=await _measure(180,false)
		_send_walk(Vector2.ZERO)
		var stop:=await _measure(150,false)
		var widths:Array=[]
		for index in range(4):
			var actor:=actors[index]
			var view:AtlasCharacterPresentation=actor.get_node("Presentation/ProceduralBody")
			var expected:float=(view._rest_feet[1].x-view._rest_feet[0].x)*actor.body_profile.get_stance_width_scale(0.0)
			var width:float=(view._targets[1]-view._targets[0]).dot(actor.global_basis.x)
			widths.append({"initial":initial[index],"stopped":width,"expected":expected})
			_expect(width>0.06 and width<view.get_leg_length()*0.6 and absf(initial[index]-expected)<0.003,"smalle beginstand en comfortabele asymmetrische stopstand %s/%s"%[direction,index])
			_expect(view._locked[0] and view._locked[1],"beide voeten echt geplant na stoppen %s/%s"%[direction,index])
		results[str(direction)]={"start":start,"reverse":reverse,"stop":stop,"widths":widths}
		world.queue_free()
		actors.clear()
		frames.clear()
		await _ticks(3)
	for route in ["zero_height", "ceiling"]:
		_build(4,true)
		await _ticks(30)
		if route=="zero_height":
			for actor in actors:
				var curve:=Curve.new()
				curve.add_point(Vector2.ZERO)
				curve.add_point(Vector2(1,0))
				actor.body_profile.stride_flight_curve=curve
		else:
			for actor in actors:
				var curve:=Curve.new()
				curve.add_point(Vector2(0,0.05))
				curve.add_point(Vector2(1,0.05))
				actor.body_profile.stride_flight_curve=curve
			var roof:=StaticBody3D.new()
			var collider:=CollisionShape3D.new()
			var shape:=BoxShape3D.new()
			shape.size=Vector3(100,0.2,100)
			collider.shape=shape
			collider.position.y=1.91
			roof.add_child(collider)
			world.add_child(roof)
			await _ticks(2)
		var route_samples:Array=[]
		for direction in [Vector2(1,0),Vector2(-1,0),Vector2(1,0)]:
			_send_walk(direction)
			var sample:=await _measure(100,false)
			for state in sample:
				_expect(state.air_frames==0 and state.ground_steps>4,"nulhoogte/plafond houdt echte gesteunde voetwissels na omkeren")
			route_samples.append(sample)
		results[route]=route_samples
		world.queue_free()
		actors.clear()
		frames.clear()
		await _ticks(3)
	var profile:=AtlasCharacterBodyProfile.new()
	var unique:=profile.make_instance_unique()
	unique.idle_stance_ratio=0.8
	unique.walking_stance_ratio=0.7
	unique.walk_start_support_ratio=0.7
	_expect(profile.idle_stance_ratio==0.5 and profile.walking_stance_ratio==0.5 and profile.walk_start_support_ratio==0.5,"nieuwe loopvelden zijn per profiel onafhankelijk")
	_expect(profile.rig_signature()==unique.rig_signature(),"loopinstellingen herbouwen geen rig")
	var file:=FileAccess.open("user://t011_walk_contacts_metrics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t"))
	file.close()
	print("WALK CONTACT METRICS: user://t011_walk_contacts_metrics.json")
	await AUDIO_SHUTDOWN.drain(self)
	print("WALK CONTACT CHECKS: ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)

func _send_walk(direction:Vector2) -> void:
	for actor in actors:
		var intent:=AtlasCharacterIntent.new()
		intent.movement=direction
		actor.submit_intent(intent)

func _measure(count:int,starting:bool) -> Array:
	var states:Array=[]
	var previous:Array=[]
	for index in range(4):
		states.append({"min_foot_gap":100.0,"min_knee_gap":100.0,"min_shin_distance":100.0,"max_drop":0.0,"max_start_drop":0.0,"max_start_compression":0.0,"max_steady_drop":0.0,"max_target_error":0.0,"max_planted_error":0.0,"max_pin_drift":0.0,"rays":0,"releases":0,"ground_steps":0,"air_frames":0,"worst":{}})
		previous.append({})
	for tick in range(count):
		await _ticks(1)
		for index in range(4):
			var actor:=actors[index]
			var view:AtlasCharacterPresentation=actor.get_node("Presentation/ProceduralBody")
			var frame:AtlasCharacterContactFrame=frames[index]
			view.apply_skeleton_pose(view._skeleton)
			var feet:Array[Vector3]=[]
			var knees:Array[Vector3]=[]
			var hips:Array[Vector3]=[]
			var state:Dictionary=states[index]
			for side in range(2):
				var points:=_joint_points(view,actor.body_profile.leg_bones(side))
				feet.append(points[2])
				knees.append(points[1])
				hips.append(points[0])
				var error:float=points[2].distance_to(view._targets[side])
				if error>state.max_target_error:
					state.worst={"tick":tick,"phase":frame.gait_phase,"air":frame.air_kind,"speed":frame.horizontal_speed,"side":side,"target":str(actor.to_local(view._targets[side])),"contact":str(actor.to_local(view._contacts[side])),"locked":view._locked.duplicate(),"step":frame.step_index}
				state.max_target_error=maxf(state.max_target_error,error)
				if view._locked[side]:
					state.max_planted_error=maxf(state.max_planted_error,error)
					if previous[index].has("locked") and previous[index].locked[side] and not frame.stride_landed and not frame.ground_step and not frame.turn_step_landed:
						state.max_pin_drift=maxf(state.max_pin_drift,view._contacts[side].distance_to(previous[index].contacts[side]))
			var drop:float=view._skeleton.get_bone_rest(view._pelvis).origin.y-view._skeleton.get_bone_pose(view._pelvis).origin.y
			var right:Vector3=(hips[1]-hips[0]).normalized()
			state.min_foot_gap=minf(state.min_foot_gap,(feet[1]-feet[0]).dot(right))
			state.min_knee_gap=minf(state.min_knee_gap,(knees[1]-knees[0]).dot(right))
			var nearest:=Geometry3D.get_closest_points_between_segments(knees[0],feet[0],knees[1],feet[1])
			state.min_shin_distance=minf(state.min_shin_distance,nearest[0].distance_to(nearest[1]))
			state.max_drop=maxf(state.max_drop,drop)
			if tick<30:
				state.max_start_drop=maxf(state.max_start_drop,drop)
				state.max_start_compression=maxf(state.max_start_compression,view._compression)
			elif tick>60:
				state.max_steady_drop=maxf(state.max_steady_drop,drop)
			state.rays=maxi(state.rays,view._rays_last_frame)
			state.releases=view._released_overreach
			state.ground_steps+=1 if frame.ground_step else 0
			state.air_frames+=1 if frame.air_kind!="none" else 0
			previous[index]={"locked":view._locked.duplicate(),"contacts":view._contacts.duplicate()}
			_expect(not frame.jumped and not frame.landed,"lopen veroorzaakt geen sprong of zware landing")
			if frame.air_kind=="stride":
				_expect(not view._locked[0] and not view._locked[1] and frame.foot_contacts.is_empty(),"pasvlucht heeft geen verborgen voetsteun")
			view._skeleton.reset_bone_poses()
	for index in range(4):
		var state:Dictionary=states[index]
		var view:AtlasCharacterPresentation=actors[index].get_node("Presentation/ProceduralBody")
		_expect(state.min_foot_gap>0.06 and state.min_knee_gap>0.06 and state.min_shin_distance>0.06,"echte enkels, knieën en schenen kruisen niet %s"%index)
		_expect(state.max_target_error<0.003 and state.max_planted_error<0.003,"echte enkels bereiken ongeclampte doelen %s: %s"%[index,state.max_target_error])
		_expect(state.max_pin_drift<0.00001 and state.releases==0,"geplante contacten blijven vast %s"%index)
		_expect(state.rays<=2,"hoogstens twee lokale voetmetingen %s"%index)
		if starting:
			_expect(state.max_start_drop<view.get_leg_length()*0.16 and state.max_start_drop<=state.max_steady_drop+0.015,"start zakt niet extra diep tegenover gewone pas %s"%index)
	return states
