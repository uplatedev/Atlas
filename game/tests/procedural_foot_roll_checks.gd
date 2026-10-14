extends "res://tests/procedural_knee_checks.gd"
## Echte voetafrol en lead/follow-contacten; dezelfde vier skeletverhoudingen.
func _run() -> void:
	_phase_transfer()
	await _style_transfers()
	var report: Array = []
	for mode in ["walk", "jog", "run"]:
		for direction in [Vector2(0,-1), Vector2(1,0), Vector2(-1,0)]:
			_build(4, true)
			await _ticks(20)
			var samples: Array = []
			for index in 4:
				samples.append({"error":0.0,"pivot_error":0.0,"min_roll":0.0,"max_roll":0.0,"double":0,"air":0,"events":[],"max_drop":0.0,"min_drop":10.0,"min_gap":10.0,"free_correction":0.0,"steady_correction":0.0})
			for actor in actors:
				var intent := AtlasCharacterIntent.new()
				intent.movement=direction
				intent.walk=mode=="walk"
				intent.run=mode=="run"
				actor.submit_intent(intent)
			for tick in 180:
				await _ticks(1)
				for index in 4:
					var actor: AtlasCharacter = actors[index]
					var view: AtlasCharacterPresentation = actor.get_node("Presentation/ProceduralBody")
					var frame: AtlasCharacterContactFrame = frames[index]
					var state: Dictionary = samples[index]
					view.apply_skeleton_pose(view._skeleton)
					for side in 2:
						var points := _joint_points(view, actor.body_profile.leg_bones(side))
						state.error=maxf(state.error, points[2].distance_to(view._targets[side]))
						if view._locked[side] and absf(view._foot_roll[side])>0.00001:
							state.min_roll=minf(state.min_roll, view._foot_roll[side])
							state.max_roll=maxf(state.max_roll, view._foot_roll[side])
							var foot:=view._legs[side][2]
							var world_basis:=view._skeleton.global_basis*view._skeleton.get_bone_global_pose(foot).basis
							var pivot_z:float=view._toe_lengths[side]*(0.25 if view._foot_roll[side]>0 else -1.0)
							var point:=points[2]+world_basis*(view._rest_foot_basis[side].inverse()*Vector3(0,-view._ankle_height,pivot_z))
							state.pivot_error=maxf(state.pivot_error,point.distance_to(view._foot_pivots[side]))
					state.min_gap=minf(state.min_gap,(view._targets[1]-view._targets[0]).dot(view._body_transform.basis.x))
					if tick>40:
						state.double+=1 if view._locked[0] and view._locked[1] else 0
						state.air+=1 if not frame.supported else 0
						state.steady_correction=maxf(state.steady_correction,maxf(view._free_target_adjustment[0],view._free_target_adjustment[1]))
						var drop:float=view._planned_pelvis_drop
						if drop>state.max_drop:
							state.max_drop=drop
							state.peak={"tick":tick,"phase":frame.gait_phase,"lock":view._locked.duplicate(),"targets":[actor.to_local(view._targets[0]),actor.to_local(view._targets[1])],"roll":view._foot_roll.duplicate()}
						state.min_drop=minf(state.min_drop,drop)
						for side in view._contact_sides:
							state.events.append([tick,side])
					state.free_correction=view._max_free_target_adjustment
					_expect(view._rays_last_frame<=2,"querybudget")
					if direction.x!=0 and tick>40:
						_expect(view._contact_sides.size()<=1,"shuffle heeft afzonderlijke landingen")
					view._skeleton.reset_bone_poses()
			for index in 4:
				var state:Dictionary=samples[index]
				_expect(state.error<0.003,"werkelijke enkeldoelen %s/%s/%d: %s"%[mode,direction,index,state.error])
				_expect(state.min_gap>0.02,"geen kruisen %s/%s/%d"%[mode,direction,index])
				if mode=="walk" and direction.x==0:
					_expect(state.double>4 and state.air==0,"wandelen heeft echte overlap zonder vlucht")
					_expect(state.max_roll>deg_to_rad(5) and state.min_roll<deg_to_rad(-10),"hielcontact en teenafzet daadwerkelijk zichtbaar")
					_expect(state.pivot_error<0.003,"hiel/voorvoet blijven werkelijk op grondanker")
				if direction.x!=0:
					var lead:=1 if direction.x>0 else 0
					for pair in range(1,state.events.size()):
						_expect(state.events[pair][0]>state.events[pair-1][0] and state.events[pair][1]!=state.events[pair-1][1],"shufflecontacten volgen apart en afwisselend")
			print("FOOT ROLL ",mode," ",direction," ",JSON.stringify(samples))
			report.append({"mode":mode,"direction":direction,"bodies":samples})
			world.queue_free()
			actors.clear()
			frames.clear()
			await _ticks(2)
	var file:=FileAccess.open("user://t011_foot_roll_metrics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	await AUDIO_SHUTDOWN.drain(self)
	print("FOOT ROLL CHECKS: ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)

func _phase_transfer() -> void:
	var planner := AtlasFootPhase.new()
	var frame := {"gait_phase":0.30,"support_fraction":0.667,"step_duration":0.3,"gait_supported_cycle":false,"step_index":1,"supported":true,"delta":1.0/60.0}
	planner.sample(frame,false,false,0)
	var before := planner.uniform_phase
	frame.gait_phase=0.35
	frame.support_fraction=0.5
	planner.sample(frame,false,false,0)
	_expect(planner.uniform_phase>before,"kortere actuele steun draait posefase niet terug")
	before=planner.uniform_phase
	frame.gait_phase=0.80
	frame.gait_supported_cycle=true
	planner.sample(frame,true,false,0)
	_expect(planner.uniform_phase>before,"WALK tijdens bestaande steun draait posefase niet terug")
	frame.step_index=2
	frame.gait_phase=0.0
	planner.sample(frame,true,false,0)
	_expect(planner.uniform_phase==0.0,"echte nieuwe motorstap reset uniforme posefase")

func _style_transfers() -> void:
	_build(4,true)
	await _ticks(20)
	var routes := [["walk",Vector2(0,-1),73],["jog",Vector2(0,-1),47],["run",Vector2(0,-1),31],["walk",Vector2(0,-1),53],["run",Vector2(1,0),57],["jog",Vector2(1,-1).normalized(),43],["walk",Vector2(-1,0),49],["jog",Vector2(0,-1),51]]
	var previous: Array = [{},{},{},{}]
	var peak_error := 0.0
	var peak_hand_delta := 0.0
	var samples := 0
	for route in routes:
		for actor in actors:
			var intent := AtlasCharacterIntent.new()
			intent.movement=route[1]
			intent.walk=route[0]=="walk"
			intent.run=route[0]=="run"
			actor.submit_intent(intent)
		for tick in int(route[2]):
			await _ticks(1)
			for index in 4:
				var actor: AtlasCharacter=actors[index]
				var view: AtlasCharacterPresentation=actor.get_node("Presentation/ProceduralBody")
				var frame: AtlasCharacterContactFrame=frames[index]
				view.apply_skeleton_pose(view._skeleton)
				var hands: Array[Vector3]=[]
				for side in 2:
					var points:=_joint_points(view,actor.body_profile.leg_bones(side))
					peak_error=maxf(peak_error,points[2].distance_to(view._targets[side]))
					hands.append(actor.to_local(_joint_points(view,actor.body_profile.arm_bones(side))[2]))
					if previous[index].has("hands"):
						peak_hand_delta=maxf(peak_hand_delta,hands[side].distance_to(previous[index].hands[side]))
				if previous[index].has("step") and previous[index].step==frame.step_index and frame.gait_phase>=previous[index].phase:
					_expect(view._foot_phase.uniform_phase+0.00001>=previous[index].uniform,"echte gangwisseling heeft voorwaartse posefase")
					_expect(absf(view._jog_pose-previous[index].jog)<=frame.delta/actor.body_profile.gait_blend_time+0.00001,"jogarm mengt via ingestelde overdrachttijd")
					samples+=1
				previous[index]={"hands":hands,"step":frame.step_index,"phase":frame.gait_phase,"uniform":view._foot_phase.uniform_phase,"jog":view._jog_pose}
				view._skeleton.reset_bone_poses()
	_expect(peak_error<0.003,"werkelijke doelen tijdens gemengde gangwisseling: %s"%peak_error)
	_expect(peak_hand_delta<0.15,"geen armdoelsprong tijdens gangwisseling: %s"%peak_hand_delta)
	print("STYLE TRANSFER samples=",samples," target=",peak_error," hand_tick=",peak_hand_delta)
	world.queue_free()
	actors.clear()
	frames.clear()
	await _ticks(2)
