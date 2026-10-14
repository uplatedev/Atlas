extends "res://tests/procedural_terrain_checks.gd"
## Onderscheid gewone liftoff van gedwongen loslaten buiten echt steunbereik.
func _run() -> void:
	world=Node3D.new()
	root.add_child(world)
	_box(Vector3(0,-0.1,0),Vector3(400,0.2,400),false)
	actor=CHARACTER.instantiate() as AtlasCharacter
	actor.position=Vector3(0,0.05,0)
	actor.contact_frame_ready.connect(_capture)
	world.add_child(actor)
	actor.set_controlled(true)
	await _ticks(10)
	await _reset()
	var view:AtlasCharacterPresentation=actor.get_node("Presentation/ProceduralBody")
	var max_pin_drift:=0.0
	var liftoffs:=0
	_send(Vector2.RIGHT,true)
	for tick in range(120):
		var contacts:=view._contacts.duplicate()
		var locks:=view._locked.duplicate()
		var previous_step:=view._step_index
		await _ticks(1)
		var frame:AtlasCharacterContactFrame=frames.back()
		if frame.stride_started:
			liftoffs+=1
			_expect(not view._locked[0] and not view._locked[1],"beide voeten komen vrij bij echte afzet")
		for side in range(2):
			if frame.supported and locks[side] and view._locked[side] and previous_step==view._step_index:
				max_pin_drift=maxf(max_pin_drift,view._contacts[side].distance_to(contacts[side]))
	_expect(liftoffs>=5,"rechts runen bevat echte herhaalde liftoffs")
	_expect(view._released_overreach==0,"gewone afzet telt niet als noodloslating")
	_expect(max_pin_drift<0.00001 and view._max_planted_error<0.002,"steunpin en werkelijke enkel blijven op hun contact")
	print("RELEASE_NORMAL liftoffs=",liftoffs," pin_drift=",max_pin_drift," planted_error=",view._max_planted_error," forced_releases=",view._released_overreach)
	# Een echte externe verplaatsing tijdens steun moet de beveiliging behouden.
	await _reset()
	_send(Vector2.RIGHT,true)
	await _ticks(2)
	_expect(frames.back().supported and view._locked[0],"teleport begint tijdens daadwerkelijke steun")
	actor.position.x+=view.get_leg_length()*2.0
	await _ticks(1)
	_expect(frames.back().supported and view._released_overreach==1 and not view._locked[0],"werkelijke ondersteunde overschrijding laat expliciet los")
	print("RELEASE_EXTERNAL supported=",frames.back().supported," forced_releases=",view._released_overreach," locks=",view._locked)
	world.queue_free()
	await AUDIO_SHUTDOWN.drain(self)
	print("CONTACT RELEASE CHECKS: ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)
