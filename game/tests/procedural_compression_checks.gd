extends "res://tests/procedural_live_preview.gd"
## De presentatie mag contact verzachten zonder extra contact, drift of motorbeweging.
var failures:Array[String]=[]
var contact_counts:Array[int]=[0,0,0,0]
var landing_counts:Array[int]=[0,0,0,0]
var observe:bool=false
var maximum:Array[float]=[0.0,0.0,0.0,0.0]
var max_motor_difference:float=0.0
var previous_errors:Array[float]=[0.0,0.0,0.0,0.0]

func _run() -> void:
	Engine.max_fps=144
	_build(4,true)
	var control:=CHARACTER.instantiate() as AtlasCharacter
	control.body_profile=actors[0].body_profile.make_instance_unique()
	control.body_profile.step_compression_ratio=0.0
	control.body_profile.landing_compression_ratio=0.0
	control.position=Vector3(10.0,0.04,0.0)
	control.feedback_enabled=false
	control.name_visible=false
	actors.append(control)
	world.add_child(control)
	for index in range(4):
		actors[index].contact_frame_ready.connect(func(frame:AtlasCharacterContactFrame):
			if observe:
				if (frame.stride_landed or frame.ground_step or frame.turn_step_landed) and not frame.foot_contacts.is_empty():
					contact_counts[index]+=1
				elif frame.landed:
					landing_counts[index]+=1)
	await _ticks(30)
	for index in range(4):
		_view(index).reset_pose()
	observe=true
	_intent(1.0,true)
	for tick in range(600):
		await _ticks(1)
		_check_tick()
	var run_peaks:=maximum.duplicate()
	var run_contacts:=contact_counts.duplicate()
	for index in range(4):
		var view:=_view(index)
		var state:=view.get_debug_state()
		_expect(state.compression_events==contact_counts[index]+landing_counts[index],"precies een veerimpuls per echt contact %d"%index)
		_expect(contact_counts[index]>30,"langdurige echte contactreeks %d"%index)
		_expect(run_peaks[index]>view.get_leg_length()*0.01 and run_peaks[index]<view.get_leg_length()*0.06,"kleine begrensde pasveer %d"%index)
		_expect(state.max_planted_error<0.002,"steunvoet blijft bereikbaar tijdens compressie %d"%index)
	_intent(0.0)
	for tick in range(120):
		await _ticks(1)
		_check_tick()
	for index in range(4):
		_expect(_view(index).get_debug_state().compression<0.00001,"gedempte veer komt tot rust %d"%index)
	maximum=[0.0,0.0,0.0,0.0]
	_intent(0.0,false,true)
	for tick in range(120):
		await _ticks(1)
		_check_tick()
	for index in range(4):
		var view:=_view(index)
		_expect(landing_counts[index]>=1,"bewuste sprong geeft echte landing %d"%index)
		_expect(maximum[index]>run_peaks[index]*1.4,"spronglanding veert duidelijker dan gewone pas %d"%index)
		_expect(view.get_debug_state().compression_events==contact_counts[index]+landing_counts[index],"geen dubbele veerimpuls op spronglanding %d"%index)
		_expect(view.get_debug_state().max_planted_error<0.002,"ook sprongveer behoudt voetbereik %d: %s"%[index,view.get_debug_state()])
	_expect(max_motor_difference<0.00002,"aan/uit presentatieveer verandert capsule niet: %s"%max_motor_difference)
	var report:={"run_contacts":run_contacts,"run_peak_m":run_peaks,"jump_peak_m":maximum,"spring_event_counts":[],"max_motor_difference":max_motor_difference}
	var baseline:=contact_counts.duplicate()
	maximum=[0.0,0.0,0.0,0.0]
	for actor in actors:
		actor.body_profile.stride_flight_curve.clear_points()
		actor.body_profile.stride_flight_curve.add_point(Vector2.ZERO)
		actor.body_profile.stride_flight_curve.add_point(Vector2(1.0,0.0))
	_intent(1.0,true)
	for tick in range(120):
		await _ticks(1)
		_check_tick()
	for index in range(4):
		var view:=_view(index)
		_expect(contact_counts[index]>baseline[index]+10,"gesteunde passen geven contactveer %d"%index)
		_expect(maximum[index]<view.get_leg_length()*0.05,"snelle gesteunde contacten stapelen veer niet op %d"%index)
		_expect(view.get_debug_state().compression_events==contact_counts[index]+landing_counts[index],"gesteunde voetwissel telt een keer %d"%index)
	report.ground_step_peak_m=maximum.duplicate()
	for index in range(4):
		var view:=_view(index)
		report.spring_event_counts.append(view.get_debug_state().compression_events)
		view.reset_pose()
		var state:=view.get_debug_state()
		_expect(state.compression==0.0 and state.compression_velocity==0.0 and state.compression_events==0,"reset wist veer en contactgeschiedenis %d"%index)
	var file:=FileAccess.open("user://t011_compression_metrics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("COMPRESSION_METRICS ",JSON.stringify(report))
	world.queue_free()
	await AUDIO_SHUTDOWN.drain(self)
	print("COMPRESSION CHECKS: ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)

func _view(index:int) -> AtlasCharacterPresentation:
	return actors[index].get_node("Presentation/ProceduralBody")

func _check_tick() -> void:
	for index in range(4):
		var view:=_view(index)
		var amount:float=view.get_debug_state().compression
		maximum[index]=maxf(maximum[index],amount)
		var error:float=view.get_debug_state().max_planted_error
		if error>0.002 and error>previous_errors[index]+0.0001:
			print("COMPRESSION_REACH_DETAIL ",index," ",view.get_debug_state()," body=",actors[index].global_position," phase=",view._phase," kind=",view._air_kind)
		previous_errors[index]=error
		_expect(amount>=0.0 and amount<=view.get_leg_length()*0.18+0.000001,"veer blijft eindig en begrensd %d"%index)
	var a:=actors[0].global_position
	var b:=actors[4].global_position
	max_motor_difference=maxf(max_motor_difference,Vector2(a.y-b.y,a.z-b.z).length())

func _expect(value:bool,message:String) -> void:
	if not value and not failures.has(message):
		failures.append(message)
		push_error(message)
