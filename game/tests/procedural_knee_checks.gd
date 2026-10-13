extends "res://tests/procedural_live_preview.gd"
## Echte motorregressie voor ongeclampte voetdoelen, knieën en armtegenzwaai.
var failures:Array[String]=[]

func _run() -> void:
	Engine.max_fps=144
	_build(4,true)
	await _ticks(20)
	var results:Array=[]
	for amount in [0.2,1.0,1.8]:
		_intent(minf(amount,1.0),amount>1.0)
		await _ticks(35)
		var bodies:Array=[]
		for index in range(4):
			bodies.append({"max_target_error":0.0,"max_local_horizontal_target":0.0,"min_knee":180.0,"max_knee":0.0,"min_forward_bend":1.0,"arm_opposition_samples":0,"arm_opposition_failures":0,"max_landing_swing_jump":0.0,"min_ankle_pitch":180.0,"max_ankle_pitch":-180.0,"min_relative_ankle":180.0,"max_relative_ankle":-180.0,"min_foot_separation":100.0,"max_head_yaw_error":0.0})
		var previous_targets:Dictionary={}
		for tick in range(120):
			await _ticks(1)
			for index in range(4):
				var actor:=actors[index]
				var view:AtlasCharacterPresentation=actor.get_node("Presentation/ProceduralBody")
				var frame:AtlasCharacterContactFrame=frames[index]
				var state:Dictionary=bodies[index]
				# De renderer toont geïnterpoleerde poses. Deze proef controleert exact
				# de physics-eindpose tegen het bijbehorende huidige contactframe.
				view.apply_skeleton_pose(view._skeleton)
				var feet:Array[Vector3]=[]
				var hands:Array[Vector3]=[]
				for side in range(2):
					var points:=_joint_points(view,actor.body_profile.leg_bones(side))
					var target:Vector3=view._targets[side]
					var local:Vector3=actor.to_local(target)
					state.max_local_horizontal_target=maxf(state.max_local_horizontal_target,Vector2(local.x,local.z).length())
					state.max_target_error=maxf(state.max_target_error,points[2].distance_to(target))
					var flexion:=180.0-rad_to_deg((points[0]-points[1]).angle_to(points[2]-points[1]))
					state.min_knee=minf(state.min_knee,flexion)
					state.max_knee=maxf(state.max_knee,flexion)
					var axis:Vector3=(points[2]-points[0]).normalized()
					var bend:Vector3=points[1]-points[0]
					bend-=axis*bend.dot(axis)
					state.min_forward_bend=minf(state.min_forward_bend,bend.dot(-actor.global_basis.z))
					var foot_index:=view._skeleton.find_bone(actor.body_profile.leg_bones(side)[2])
					var current_basis:=actor.global_basis.inverse()*view._skeleton.global_basis*view._skeleton.get_bone_global_pose(foot_index).basis
					var ankle_rotation:=current_basis*view._rest_foot_basis[side].inverse()
					var ankle_pitch:=rad_to_deg(atan2(ankle_rotation.y.z,ankle_rotation.y.y))
					state.min_ankle_pitch=minf(state.min_ankle_pitch,ankle_pitch)
					state.max_ankle_pitch=maxf(state.max_ankle_pitch,ankle_pitch)
					if not view._locked[side]:
						var shin:Vector3=actor.global_basis.inverse()*(points[1]-points[2])
						var relative_ankle:=ankle_pitch+rad_to_deg(atan2(-shin.z,shin.y))
						state.min_relative_ankle=minf(state.min_relative_ankle,relative_ankle)
						state.max_relative_ankle=maxf(state.max_relative_ankle,relative_ankle)
					feet.append(actor.to_local(points[2]))
					hands.append(actor.to_local(_joint_points(view,actor.body_profile.arm_bones(side))[2]))
					if frame.stride_landed and side!=posmod(frame.step_index,2) and previous_targets.has(index):
						state.max_landing_swing_jump=maxf(state.max_landing_swing_jump,target.distance_to(previous_targets[index][side]))
				state.min_foot_separation=minf(state.min_foot_separation,feet[1].x-feet[0].x)
				var head_index:=view._skeleton.find_bone(actor.body_profile.head_bone)
				var head_delta:=view._skeleton.get_bone_global_pose(head_index).basis*view._skeleton.get_bone_global_rest(head_index).basis.inverse()
				var look:Vector2=actor.get_look_input()
				var expected_yaw:=wrapf(look.x-actor.global_rotation.y,-PI,PI)
				state.max_head_yaw_error=maxf(state.max_head_yaw_error,absf(wrapf(head_delta.get_euler().y-expected_yaw,-PI,PI)))
				if frame.gait_phase<0.1:
					state.arm_opposition_samples+=1
					if (feet[0].z-feet[1].z)*(hands[0].z-hands[1].z)>=0:
						state.arm_opposition_failures+=1
				previous_targets[index]=view._targets.duplicate()
				view._skeleton.reset_bone_poses()
		for index in range(4):
			var state:Dictionary=bodies[index]
			var leg:float=actors[index].get_node("Presentation/ProceduralBody").get_leg_length()
			_expect(state.min_foot_separation>0.03,"benen kruisen niet %s/%s"%[amount,index])
			_expect(state.max_head_yaw_error<0.002,"hoofd behoudt blik tijdens romptwist %s/%s"%[amount,index])
			_expect(state.max_local_horizontal_target<leg,"doel blijft lokaal binnen beenlengte %s/%s"%[amount,index])
			_expect(state.max_target_error<0.003,"ongeclampte enkel bereikt werkelijk doel %s/%s: %s"%[amount,index,state.max_target_error])
			_expect(state.min_forward_bend>=-0.001,"knie buigt vooruit %s/%s"%[amount,index])
			_expect(state.max_knee-state.min_knee>20.0,"knie beweegt mee met pas %s/%s"%[amount,index])
			_expect(state.arm_opposition_failures==0,"arm zwaait tegenover been %s/%s"%[amount,index])
			_expect(state.max_relative_ankle<20.1 and state.min_relative_ankle> -45.1,"vrije enkel blijft anatomisch begrensd %s/%s"%[amount,index])
			_expect(state.max_ankle_pitch-state.min_ankle_pitch>5.0,"enkel wisselt echte botpitch %s/%s"%[amount,index])
			_expect(state.max_landing_swing_jump<0.003,"landing behoudt actuele zwaaivoet %s/%s: %s"%[amount,index,state.max_landing_swing_jump])
		results.append({"speed_m_s":amount*5.0,"bodies":bodies})
		print("KNEE_BODY ",JSON.stringify(results[-1]))
	# Instelvelden blijven individueel en veranderen de rigidentiteit niet.
	var profile:=actors[0].body_profile
	var signature:=profile.rig_signature()
	profile.stance_width_ratio=1.25
	profile.torso_lean_scale=0.5
	await _ticks(2)
	_expect(profile.rig_signature()==signature,"stijlvelden herbouwen rig niet")
	_expect(actors[1].body_profile.stance_width_ratio==1.0 and actors[1].body_profile.torso_lean_scale==1.0,"stijlvelden instance-onafhankelijk")
	var file:=FileAccess.open("user://t011_knee_metrics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t"))
	file.close()
	world.queue_free()
	await AUDIO_SHUTDOWN.drain(self)
	print("KNEE MOTOR CHECKS: ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)

func _joint_points(view:AtlasCharacterPresentation,names:Array) -> Array[Vector3]:
	var result:Array[Vector3]=[]
	for bone in names:
		result.append(view._skeleton.global_transform*view._skeleton.get_bone_global_pose(view._skeleton.find_bone(bone)).origin)
	return result

func _expect(value:bool,message:String) -> void:
	if not value:
		failures.append(message)
		push_error(message)
