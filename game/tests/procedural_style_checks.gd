extends "res://tests/procedural_knee_checks.gd"
## Echte loop-/rensporen, tegenbeweging en knieslide op alle vier verhoudingen.
func _run() -> void:
	Engine.max_fps=144
	_build(4,true)
	await _ticks(30)
	var records:Array=[]
	for sprint in [false,true]:
		_intent(1.0,sprint)
		await _ticks(50)
		var samples:Array=[]
		for index in range(4):
			samples.append({"max_foot_lift":0.0,"pelvis_yaw":0.0,"pelvis_roll":0.0,"head_bank":0.0,"yaw_opposition_samples":0,"roll_opposition_samples":0})
		for tick in range(120):
			await _ticks(1)
			for index in range(4):
				var actor:=actors[index]
				var view:AtlasCharacterPresentation=actor.get_node("Presentation/ProceduralBody")
				view.apply_skeleton_pose(view._skeleton)
				var state:Dictionary=samples[index]
				var pelvis:=_rotation(view,view._pelvis).get_euler()
				var spine:=_rotation(view,view._spine).get_euler()
				var head:=_rotation(view,view._head).get_euler()
				state.pelvis_yaw=maxf(state.pelvis_yaw,absf(pelvis.y))
				state.pelvis_roll=maxf(state.pelvis_roll,absf(pelvis.z))
				state.head_bank=maxf(state.head_bank,absf(head.z))
				if absf(pelvis.y)>0.01:
					state.yaw_opposition_samples+=1
					_expect(pelvis.y*spine.y<0.0,"borst draait tegengesteld aan bekken %s/%s"%[sprint,index])
				if absf(pelvis.z)>0.01:
					state.roll_opposition_samples+=1
					_expect(pelvis.z*spine.z<0.0,"borst rolt tegengesteld aan bekken %s/%s"%[sprint,index])
				for side in range(2):
					state.max_foot_lift=maxf(state.max_foot_lift,actor.to_local(view._targets[side]).y-view._ankle_height)
				view._skeleton.reset_bone_poses()
		for index in range(4):
			_expect(samples[index].head_bank<0.002,"hoofd blijft rustig en recht %s/%s"%[sprint,index])
			_expect(samples[index].yaw_opposition_samples>20 and samples[index].roll_opposition_samples>20,"tegenbeweging komt echt voor %s/%s"%[sprint,index])
		records.append(samples)
	for index in range(4):
		_expect(records[0][index].max_foot_lift<records[1][index].max_foot_lift*0.50,"loopvoet veel lager dan renvoet %s"%index)
		_expect(records[0][index].pelvis_roll>records[1][index].pelvis_roll*1.5,"lopen gebruikt meer rustige rol %s"%index)
		_expect(records[1][index].pelvis_yaw>deg_to_rad(6.0),"rennen gebruikt zichtbare counteryaw %s"%index)
	_intent(1.0,true,false,true)
	for tick in range(100):
		await _ticks(1)
		if actors.all(func(actor):return actor.get_debug_state().slide_active):
			break
	var slide:Array=[]
	for index in range(4):
		var actor:=actors[index]
		var view:AtlasCharacterPresentation=actor.get_node("Presentation/ProceduralBody")
		_expect(view._sliding,"echte slide actief %s"%index)
		view.apply_skeleton_pose(view._skeleton)
		var sides:Array=[]
		for side in range(2):
			var points:=_joint_points(view,actor.body_profile.leg_bones(side))
			var hip:Vector3=actor.to_local(points[0])
			var knee:Vector3=actor.to_local(points[1])
			var ankle:Vector3=actor.to_local(points[2])
			sides.append({"hip":str(hip),"knee":str(knee),"ankle":str(ankle)})
			_expect(knee.y>0.015 and knee.y<0.14,"knie laag boven vloer %s/%s: %s"%[index,side,knee])
			_expect(ankle.z>knee.z+view._leg_lengths[side].y*0.65,"scheen en voet achter knie %s/%s"%[index,side])
			_expect(hip.y>knee.y+view._leg_lengths[side].x*0.7,"bovenbeen draagt knielpose %s/%s"%[index,side])
			_expect(points[2].distance_to(view._targets[side])<0.003,"slidevoet blijft bereikbaar %s/%s"%[index,side])
		slide.append(sides)
		view._skeleton.reset_bone_poses()
	var profile:=actors[0].body_profile
	var signature:=profile.rig_signature()
	var unique:=profile.make_instance_unique()
	unique.walking_stance_ratio=0.62
	unique.body_roll_degrees=1.5
	unique.slide_knee_clearance_ratio=0.15
	_expect(profile.walking_stance_ratio==0.75 and profile.body_roll_degrees==3.0 and profile.slide_knee_clearance_ratio==0.09,"nieuwe stijlvelden blijven per profiel onafhankelijk")
	_expect(unique.rig_signature()==signature,"nieuwe stijlvelden herbouwen de rig niet")
	var file:=FileAccess.open("user://t011_style_metrics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"walk":records[0],"run":records[1],"slide":slide},"\t"))
	file.close()
	world.queue_free()
	await AUDIO_SHUTDOWN.drain(self)
	print("STYLE CHECKS: ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)

func _rotation(view:AtlasCharacterPresentation,bone:int) -> Basis:
	return view._skeleton.get_bone_global_pose(bone).basis*view._skeleton.get_bone_global_rest(bone).basis.inverse()
