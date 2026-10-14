extends "res://tests/procedural_knee_checks.gd"
## Echte voet-, knie- en zoolcontacten tijdens snelle kijkdraaien met alle drie gangen.
## OPEN: free_step/contact_step meten pose-overdracht, geen bewijs van vloeiend uiterlijk.
## be4b773 had al tot 63 cm contactstap; de WALK-overdracht vraagt nog visueel vervolg.
func _run() -> void:
	var report:Array=[]
	for mode in ["walk","jog","run"]:
		_build(4,true)
		await _ticks(30)
		var states:Array=[]
		var previous:Array=[{},{},{},{}]
		for i in 4:
			states.append({"foot":INF,"knee":INF,"shin":INF,"target":0.0,"pin":0.0,"sole":0.0,"free_step":0.0,"contact_step":0.0,"twist":0.0,"queries":0,"releases":0,"worst":{}})
		for tick in 300:
			for actor in actors:
				var intent:=AtlasCharacterIntent.new()
				intent.movement=Vector2(0,-1)
				intent.walk=mode=="walk"
				intent.run=mode=="run"
				intent.has_look_direction=true
				intent.look_direction=Vector2([0.0,PI,-PI*0.5,PI*0.5,TAU][mini(tick/60,4)],0)
				actor.submit_intent(intent)
			await _ticks(1)
			for i in 4:
				var actor:AtlasCharacter=actors[i]
				var view:AtlasCharacterPresentation=actor.get_node("Presentation/ProceduralBody")
				var state:Dictionary=states[i]
				var frame:AtlasCharacterContactFrame=frames[i]
				view.apply_skeleton_pose(view._skeleton)
				var joints:Array=[]
				var markers:Array=[]
				var feet:Array=[]
				for side in 2:
					var points:=_joint_points(view,actor.body_profile.leg_bones(side))
					joints.append(points)
					feet.append(points[2])
					if previous[i].has("feet"):
						var foot_travel:Vector3=points[2]-previous[i].feet[side]-(actor.global_position-previous[i].body)
						if not view._locked[side] and not previous[i].locks[side]:
							state.free_step=maxf(state.free_step,foot_travel.length())
						elif view._locked[side] and not previous[i].locks[side]:
							state.contact_step=maxf(state.contact_step,foot_travel.length())
					if view._locked[side]:
						state.twist=maxf(state.twist,absf(wrapf(actor.global_rotation.y-atan2(-view._contact_forwards[side].x,-view._contact_forwards[side].z),-PI,PI)))
					state.target=maxf(state.target,points[2].distance_to(view._targets[side]))
					var foot_pose:Transform3D=view._skeleton.global_transform*view._skeleton.get_bone_global_pose(view._legs[side][2])
					var marker:Vector3=foot_pose*(view._rest_foot_basis[side].inverse()*Vector3(0,-view._ankle_height,view._toe_lengths[side]*(0.25 if view._foot_roll[side]>=0 else -1.0)))
					markers.append(marker)
					if view._locked[side] and previous[i].has("locks") and previous[i].locks[side] and not side in view._contact_sides and not frame.turn_step_landed:
						state.pin=maxf(state.pin,view._contacts[side].distance_to(previous[i].contacts[side]))
						if signf(view._foot_roll[side])==signf(previous[i].roll[side]):
							state.sole=maxf(state.sole,marker.distance_to(previous[i].markers[side]))
				var right:Vector3=(joints[1][0]-joints[0][0]).normalized()
				var gap:float=(joints[1][2]-joints[0][2]).dot(right)
				if gap<state.foot:
					state.worst={"tick":tick,"gap":gap,"phase":frame.gait_phase,"speed":frame.horizontal_speed,"locks":view._locked.duplicate(),"yaw":actor.rotation.y,"contacts":[actor.to_local(view._contacts[0]),actor.to_local(view._contacts[1])]}
				state.foot=minf(state.foot,gap)
				state.knee=minf(state.knee,(joints[1][1]-joints[0][1]).dot(right))
				var closest:=Geometry3D.get_closest_points_between_segments(joints[0][1],joints[0][2],joints[1][1],joints[1][2])
				state.shin=minf(state.shin,closest[0].distance_to(closest[1]))
				state.releases=view._released_overreach
				state.queries=maxi(state.queries,view._rays_last_frame)
				previous[i]={"locks":view._locked.duplicate(),"contacts":view._contacts.duplicate(),"markers":markers,"roll":view._foot_roll.duplicate(),"feet":feet,"body":actor.global_position}
				view._skeleton.reset_bone_poses()
		report.append({"mode":mode,"states":states})
		world.queue_free()
		actors.clear()
		frames.clear()
		await _ticks(3)
	await _blocked_landing()
	var file:=FileAccess.open("user://t011_moving_turn_metrics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("MOVING TURN ",JSON.stringify(report))
	for route in report:
		for state in route.states:
			_expect(state.foot>0.06 and state.knee>0.06 and state.shin>0.06,"echte enkels, knieën en schenen blijven uit elkaar tijdens "+route.mode)
			_expect(state.pin<0.00001 and state.sole<0.003,"werkelijk zoolpivot en wereldcontact blijven vast tijdens "+route.mode)
			_expect(state.target<0.003 and state.releases==0,"botten bereiken doelen zonder noodloslating tijdens "+route.mode)
			_expect(state.queries<=2,"draai gebruikt hoogstens twee lokale voetqueries")
	await AUDIO_SHUTDOWN.drain(self)
	print("MOVING TURN CHECKS: ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)

func _blocked_landing() -> void:
	_build(4,true)
	for actor in actors:
		var wall:=StaticBody3D.new()
		var collider:=CollisionShape3D.new()
		var shape:=BoxShape3D.new()
		shape.size=Vector3(1.5,6,0.2)
		collider.shape=shape
		wall.add_child(collider)
		wall.position=actor.position+Vector3(0,2,-0.45)
		world.add_child(wall)
		var intent:=AtlasCharacterIntent.new()
		intent.movement=Vector2(0,-1)
		actor.submit_intent(intent)
	await _ticks(30)
	for actor in actors:
		var view:AtlasCharacterPresentation=actor.get_node("Presentation/ProceduralBody")
		_expect(view._locked[0] or view._locked[1],"geblokkeerde start plant echte steun")
		actor.global_position.y+=1.7
		actor.velocity=Vector3.ZERO
	var landings:Array[int]=[0,0,0,0]
	for tick in 100:
		await _ticks(1)
		for index in 4:
			var frame:AtlasCharacterContactFrame=frames[index]
			if frame.landed:
				var view:AtlasCharacterPresentation=actors[index].get_node("Presentation/ProceduralBody")
				_expect(frame.horizontal_speed<0.1,"landingsproef houdt werkelijk geblokkeerde invoer")
				_expect(view._locked[0] or view._locked[1],"echte landing wordt nooit als omkeernulpassage overgeslagen")
				landings[index]+=1
	for count in landings:
		_expect(count==1,"elk lichaam landt éénmaal tegen de muur")
	world.queue_free()
	actors.clear()
	frames.clear()
	await _ticks(3)
