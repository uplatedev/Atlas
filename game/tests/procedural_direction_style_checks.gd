extends "res://tests/procedural_knee_checks.gd"
## Werkelijke open/sluit-zijpas en voor-/achterdiagonale RUN op vier lichaamsverhoudingen.
func _run() -> void:
	Engine.max_fps=144
	var records:Array=[]
	for run in [false,true]:
		var directions:Array[Vector2]=[Vector2(1,0),Vector2(-1,0)]
		directions.append_array([Vector2(1,-1).normalized(),Vector2(-1,-1).normalized(),Vector2(1,1).normalized(),Vector2(-1,1).normalized()])
		for direction in directions:
			_build(4,true)
			await _ticks(20)
			_send_direction(direction,run)
			var states:=await _direction_sample(160,direction,run)
			records.append({"direction":str(direction),"run":run,"bodies":states})
			_send_direction(Vector2.ZERO,false)
			var stopped:=await _direction_sample(100,Vector2.ZERO,false)
			records.append({"stop_from":str(direction),"run":run,"bodies":stopped})
			world.queue_free()
			actors.clear()
			frames.clear()
			await _ticks(2)
	_build(4,true)
	await _ticks(20)
	for direction in [Vector2(1,0),Vector2(1,-1).normalized(),Vector2(1,1).normalized(),Vector2(-1,0),Vector2(1,0),Vector2(0,-1)]:
		_send_direction(direction,true)
		var state:=await _direction_sample(120,direction,true)
		records.append({"transition":str(direction),"run":true,"bodies":state})
	world.queue_free()
	actors.clear()
	frames.clear()
	await _ticks(2)
	var file:=FileAccess.open("user://t011_direction_style_metrics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(records,"\t"))
	file.close()
	print("DIRECTION STYLE METRICS: user://t011_direction_style_metrics.json")
	await AUDIO_SHUTDOWN.drain(self)
	print("DIRECTION STYLE CHECKS: ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)

func _send_direction(direction:Vector2,run:bool) -> void:
	for actor in actors:
		var intent:=AtlasCharacterIntent.new()
		intent.movement=direction
		intent.run=run
		actor.submit_intent(intent)

func _direction_sample(count:int,direction:Vector2,run:bool) -> Array:
	var states:Array=[]
	var previous:Array=[]
	for index in range(4):
		states.append({"max_target_error":0.0,"max_planted_error":0.0,"max_pin_drift":0.0,"max_head_error":0.0,"min_gap":INF,"max_side_lift":0.0,"height_min":INF,"height_max":-INF,"hop_air":0,"double_support":0,"lead_only":0,"trail_only":0,"contact_sides":[],"simultaneous_contacts":0,"rays":0,"releases":0,"last_yaw":0.0,"last_running":0.0,"worst":{}})
		previous.append({})
	for tick in range(count):
		await _ticks(1)
		for index in range(4):
			var actor:=actors[index]
			var view:AtlasCharacterPresentation=actor.get_node("Presentation/ProceduralBody")
			var frame:AtlasCharacterContactFrame=frames[index]
			var state:Dictionary=states[index]
			view.apply_skeleton_pose(view._skeleton)
			var feet:Array[Vector3]=[]
			for side in range(2):
				var points:=_joint_points(view,actor.body_profile.leg_bones(side))
				feet.append(points[2])
				var error:float=points[2].distance_to(view._targets[side])
				if error>state.max_target_error:
					state.worst={"tick":tick,"phase":frame.gait_phase,"side":side,"hop":view._side_hop,"target":str(actor.to_local(view._targets[side])),"locked":view._locked.duplicate()}
				state.max_target_error=maxf(state.max_target_error,error)
				if view._locked[side]:
					state.max_planted_error=maxf(state.max_planted_error,error)
					if previous[index].has("locked") and previous[index].locked[side] and not frame.stride_landed and not frame.ground_step and not frame.turn_step_landed:
						state.max_pin_drift=maxf(state.max_pin_drift,view._contacts[side].distance_to(previous[index].contacts[side]))
				if tick>50 and view._side_hop:
					state.max_side_lift=maxf(state.max_side_lift,actor.to_local(points[2]).y-view._ankle_height)
			state.min_gap=minf(state.min_gap,(feet[1]-feet[0]).dot(view._body_transform.basis.x))
			var head_delta:=view._skeleton.get_bone_global_pose(view._head).basis*view._skeleton.get_bone_global_rest(view._head).basis.inverse()
			state.max_head_error=maxf(state.max_head_error,absf(head_delta.get_euler().y))
			state.rays=maxi(state.rays,view._rays_last_frame)
			state.releases=view._released_overreach
			state.last_yaw=view._gait_yaw
			state.last_running=view._running_blend()
			if tick>50:
				state.height_min=minf(state.height_min,actor.position.y)
				state.height_max=maxf(state.height_max,actor.position.y)
			if tick>50 and view._side_hop:
				var lead:int=1 if direction.x>0.0 else 0
				state.lead_only+=int(view._locked[lead] and not view._locked[1-lead])
				state.trail_only+=int(view._locked[1-lead] and not view._locked[lead])
				var contacts:Array=view.get_debug_state().foot_contact_sides
				state.contact_sides.append_array(contacts)
				state.simultaneous_contacts+=int(contacts.size()>1)
				if frame.air_kind=="stride":
					state.hop_air+=1
					_expect(not view._locked[0] and not view._locked[1] and frame.foot_contacts.is_empty(),"echte zijhup heeft beide voeten los")
				elif frame.supported and view._locked[0] and view._locked[1]:
					state.double_support+=1
			previous[index]={"locked":view._locked.duplicate(),"contacts":view._contacts.duplicate()}
			_expect(not frame.jumped and not frame.landed,"richtingstijl verzint geen gewone sprong of zware landing")
			view._skeleton.reset_bone_poses()
	for index in range(4):
		var state:Dictionary=states[index]
		var actor:=actors[index]
		var view:AtlasCharacterPresentation=actor.get_node("Presentation/ProceduralBody")
		_expect(state.max_target_error<0.003 and state.max_planted_error<0.003,"werkelijke enkels bereiken ongeclampte doelen %s/%s/%s: %s"%[direction,run,index,state.max_target_error])
		_expect(state.max_pin_drift<0.00001 and state.releases==0,"vaste wereldcontacten blijven behouden %s/%s/%s"%[direction,run,index])
		_expect(state.min_gap>0.03,"benen behouden links/rechts in zichtbare lichaamsbasis %s/%s/%s"%[direction,run,index])
		_expect(state.max_head_error<0.002 and absf(actor.rotation.y)<0.00001,"visuele richting verandert geen hoofdblik of capsuleyaw")
		_expect(state.rays<=2,"zij-/diagonaal gebruikt hoogstens twee voetmetingen")
		if direction.y==0.0 and direction.x!=0.0:
			_expect(state.lead_only>2 and state.trail_only>2 and state.simultaneous_contacts==0,"zijpas heeft afzonderlijke leidende en volgende steun zonder dubbele landing")
			_expect(state.contact_sides.size()>3,"zijpas publiceert voldoende afzonderlijke contacten")
			for contact in range(1,state.contact_sides.size()):
				_expect(state.contact_sides[contact]!=state.contact_sides[contact-1],"leidende en volgende voet wisselen hoorbare contacten af")
			_expect(state.max_side_lift<view.get_leg_length()*0.12,"zijhup heeft bescheiden intrek zonder hoge renhiel")
		else:
			var expected:=AtlasGaitStyle.diagonal_yaw(Vector3(direction.x,0,direction.y),"run")
			_expect(absf(state.last_yaw-expected)<0.002 and (not run or state.last_running==1.0),"voor/achterdiagonaal gebruikt eigen stijl langs nabijste lengte-as")
	return states
