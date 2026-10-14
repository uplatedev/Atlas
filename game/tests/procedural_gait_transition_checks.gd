extends "res://tests/procedural_knee_checks.gd"
## Echte overgang van gesteund wandelen naar vlucht, zonder fase-reset of extra afzet.
var transition_metrics: Array = []

func _run() -> void:
	for source in ["walk", "zero_curve", "ceiling"]:
		for direction in [Vector2(0,-1),Vector2(1,-1).normalized(),Vector2(1,0),Vector2(-1,0)]:
			for target in ["jog","run"]:
				await _handoff(source,target,direction)
	for mode in ["walk","jog","run"]:
		for direction in [Vector2(0,-1),Vector2(1,0)]:
			for phase in [0.15,0.65,0.9]:
				await _jump_modifiers(mode,direction,phase)
	for constrained in ["free","zero_curve","ceiling"]:
		await _run_reversals(constrained)
	await _input_priority()
	var file := FileAccess.open("user://t011_gait_transition_metrics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(transition_metrics,"\t"))
	file.close()
	await AUDIO_SHUTDOWN.drain(self)
	print("GAIT TRANSITION CHECKS: ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)

func _send(index: int, direction: Vector2, mode: String, jump: bool = false) -> void:
	var intent := AtlasCharacterIntent.new()
	intent.movement = direction
	intent.walk = mode == "walk"
	intent.run = mode == "run"
	intent.jump_pressed = jump
	actors[index].submit_intent(intent)

func _clear() -> void:
	world.queue_free()
	actors.clear()
	frames.clear()
	await _ticks(2)

func _handoff(source: String,target: String,direction: Vector2) -> void:
	_build(4,true)
	await _ticks(20)
	var curves: Array = []
	var ceiling: StaticBody3D
	if source == "ceiling":
		ceiling = StaticBody3D.new()
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(400,0.2,400)
		collider.shape = shape
		ceiling.add_child(collider)
		ceiling.position.y = 1.925
		world.add_child(ceiling)
	for index in range(4):
		var actor := actors[index]
		curves.append(actor.body_profile.stride_flight_curve)
		if source == "zero_curve":
			var curve := Curve.new()
			curve.add_point(Vector2.ZERO)
			curve.add_point(Vector2(1,0))
			actor.body_profile.stride_flight_curve = curve
		_send(index,direction,"walk" if source == "walk" else target)
	await _ticks(120)
	if ceiling != null:
		ceiling.queue_free()
	for index in range(4):
		actors[index].body_profile.stride_flight_curve = curves[index]
		_send(index,direction,target)
	var previous: Array = []
	var stats := {"source":source,"target":target,"direction":str(direction),"backwards":0,"flights":0,"ground_steps":0,"jumps":0,"lands":0,"max_pin":0.0,"max_target":0.0}
	for index in range(4): previous.append(_capture_state(index))
	for tick in range(110):
		await _ticks(1)
		for index in range(4):
			var frame: AtlasCharacterContactFrame = frames[index]
			var last: Dictionary = previous[index]
			var view: AtlasCharacterPresentation = actors[index].get_node("Presentation/ProceduralBody")
			if frame.step_index == last.step and frame.horizontal_speed > 0.1 and frame.gait_phase + 0.000001 < last.phase:
				stats.backwards += 1
			stats.flights += 1 if frame.stride_started else 0
			stats.ground_steps += 1 if frame.ground_step else 0
			stats.jumps += 1 if frame.jumped else 0
			stats.lands += 1 if frame.landed else 0
			_expect(not(frame.ground_step and frame.stride_landed),"één fysieke voetwissel heeft één contacttype")
			_expect(frame.step_index-last.step == (1 if frame.ground_step or frame.stride_landed else 0),"stapnummer volgt alleen één werkelijke wissel")
			_expect(frame.foot_contacts.size() <= 2 and view._rays_last_frame <= 2,"contacten en grondmetingen blijven begrensd")
			view.apply_skeleton_pose(view._skeleton)
			for side in range(2):
				var points := _joint_points(view,actors[index].body_profile.leg_bones(side))
				stats.max_target = maxf(stats.max_target,points[2].distance_to(view._targets[side]))
				if view._locked[side] and last.locked[side] and not frame.ground_step and not frame.stride_landed:
					stats.max_pin = maxf(stats.max_pin,view._contacts[side].distance_to(last.contacts[side]))
			view._skeleton.reset_bone_poses()
			previous[index] = _capture_state(index)
	_expect(stats.backwards == 0,"gesteunde cyclus gaat zonder teruglopende fase over: "+str(stats))
	_expect(stats.flights >= 4 and stats.jumps == 0 and stats.lands == 0,"overdracht start gewone pasvlucht zonder sprong-/impactcue")
	_expect(stats.max_pin < 0.00001,"overdracht bewaart wereldvaste steunpunten")
	transition_metrics.append(stats)
	print("HANDOFF ",JSON.stringify(stats))
	await _clear()

func _capture_state(index: int) -> Dictionary:
	var view: AtlasCharacterPresentation = actors[index].get_node("Presentation/ProceduralBody")
	return {"phase":frames[index].gait_phase,"step":frames[index].step_index,"locked":view._locked.duplicate(),"contacts":view._contacts.duplicate()}

func _jump_modifiers(mode: String,direction: Vector2,phase: float) -> void:
	_build(4,true)
	await _ticks(20)
	for index in range(4): _send(index,direction,mode)
	await _ticks(120)
	var ages: Array[int] = [-1,-1,-1,-1]
	var jumps: Array[int] = [0,0,0,0]
	var previous_y: Array[float] = [0,0,0,0]
	var previous_speed: Array[float] = [0,0,0,0]
	var max_ballistic_error := 0.0
	var max_air_boost := 0.0
	var landed: Array[bool] = [false,false,false,false]
	for tick in range(180):
		for index in range(4):
			var frame: AtlasCharacterContactFrame = frames[index]
			if ages[index] < 0 and absf(frame.gait_phase-phase) < 0.13:
				_send(index,direction,mode,true)
				ages[index] = 0
			elif ages[index] in [3,6,9]:
				_send(index,direction,["run","walk","jog"][ages[index]/3-1])
			previous_y[index] = actors[index].velocity.y
			previous_speed[index] = Vector2(actors[index].velocity.x,actors[index].velocity.z).length()
		await _ticks(1)
		for index in range(4):
			var actor := actors[index]
			var frame: AtlasCharacterContactFrame = frames[index]
			var view: AtlasCharacterPresentation = actor.get_node("Presentation/ProceduralBody")
			if frame.jumped:
				jumps[index] += 1
				_expect(frame.air_kind == "jump" and not frame.stride_started,"spatie vervangt een eventuele pasafzet")
			if ages[index] > 0 and not landed[index]:
				if frame.supported: landed[index] = true
				elif frame.air_kind == "jump":
					max_ballistic_error = maxf(max_ballistic_error,absf(actor.velocity.y-(previous_y[index]-actor.gravity_strength*frame.delta)))
					max_air_boost = maxf(max_air_boost,Vector2(actor.velocity.x,actor.velocity.z).length()-previous_speed[index])
					_expect(not view._locked[0] and not view._locked[1] and frame.foot_contacts.is_empty(),"bewuste luchtwissel krijgt geen kunstmatige voetsteun")
			if ages[index] >= 0: ages[index] += 1
	for index in range(4):
		_expect(jumps[index] == 1 and landed[index],"elke verhouding springt precies eenmaal en landt bij "+mode+str(direction)+str(phase))
	_expect(max_ballistic_error < 0.00001 and max_air_boost < 0.00001,"Alt/Shift in bewuste lucht bewaren parabool en geven geen nieuwe boost")
	var result := {"mode":mode,"direction":str(direction),"phase":phase,"jumps":jumps,"ballistic_error":max_ballistic_error,"air_boost":max_air_boost}
	transition_metrics.append(result)
	print("JUMP MODIFIERS ",JSON.stringify(result))
	await _clear()

func _run_reversals(constrained: String) -> void:
	_build(4,true)
	await _ticks(20)
	if constrained == "zero_curve":
		for actor in actors:
			var curve := Curve.new()
			curve.add_point(Vector2.ZERO)
			curve.add_point(Vector2(1,0))
			actor.body_profile.stride_flight_curve = curve
	elif constrained == "ceiling":
		var body := StaticBody3D.new()
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(400,0.2,400)
		collider.shape = shape
		body.add_child(collider)
		body.position.y = 1.925
		world.add_child(body)
	var directions: Array[Vector2] = [Vector2(0,-1),Vector2(1,-1).normalized(),Vector2(1,0),Vector2(1,1).normalized(),Vector2(0,1),Vector2(-1,1).normalized(),Vector2(-1,0),Vector2(-1,-1).normalized(),Vector2(1,0),Vector2(-1,0),Vector2(0,-1),Vector2(0,1),Vector2.ZERO]
	var stats := {"reversal":constrained,"max_target":0.0,"max_planted":0.0,"max_pin":0.0,"releases":0,"ray_max":0,"ground_steps":0,"flights":0}
	for direction in directions:
		for index in range(4): _send(index,direction,"run")
		var previous: Array = []
		for index in range(4): previous.append(_capture_state(index))
		for tick in range(100):
			await _ticks(1)
			for index in range(4):
				var actor := actors[index]
				var view: AtlasCharacterPresentation = actor.get_node("Presentation/ProceduralBody")
				var frame: AtlasCharacterContactFrame = frames[index]
				var last: Dictionary = previous[index]
				view.apply_skeleton_pose(view._skeleton)
				for side in range(2):
					var joints := _joint_points(view,actor.body_profile.leg_bones(side))
					var error := joints[2].distance_to(view._targets[side])
					stats.max_target = maxf(stats.max_target,error)
					if view._locked[side]:
						stats.max_planted = maxf(stats.max_planted,error)
						if last.locked[side] and not frame.ground_step and not frame.stride_landed and not frame.turn_step_landed:
							stats.max_pin = maxf(stats.max_pin,view._contacts[side].distance_to(last.contacts[side]))
				stats.ray_max = maxi(stats.ray_max,view._rays_last_frame)
				stats.releases = maxi(stats.releases,view._released_overreach)
				stats.ground_steps += 1 if frame.ground_step else 0
				stats.flights += 1 if frame.stride_started else 0
				_expect(not frame.jumped and not frame.landed,"omkeerpas gebruikt geen sprong of impactlanding")
				view._skeleton.reset_bone_poses()
				previous[index] = _capture_state(index)
	for actor in actors:
		_expect(actor._stride._support_direction.is_zero_approx(),"daadwerkelijk stoppen wist vorige contactrichting")
		actor.reset_to_spawn()
		_expect(actor._stride._support_direction.is_zero_approx(),"spawn-reset bewaart geen oude contactrichting")
	_expect(stats.max_planted < 0.003 and stats.max_pin < 0.00001 and stats.releases == 0,"omkeersteun blijft werkelijk bereikbaar en wereldvast: "+str(stats))
	_expect(stats.max_target < 0.003 and stats.ray_max <= 2,"omkeerdoelen blijven bereikbaar met dezelfde querygrens: "+str(stats))
	if constrained == "free":
		_expect(stats.flights > 20,"vrije omkering blijft echte pasvlucht gebruiken")
	else:
		_expect(stats.ground_steps > 20 and stats.flights == 0,"nulcurve/plafond omkering geeft uitsluitend echte gesteunde wissels")
	transition_metrics.append(stats)
	print("REVERSALS ",JSON.stringify(stats))
	await _clear()

func _input_priority() -> void:
	for action in ["jump","slide"]:
		_build(4,true)
		await _ticks(20)
		for index in range(4): _send(index,Vector2(0,-1),"walk")
		await _ticks(120)
		for actor in actors:
			var intent := AtlasCharacterIntent.new()
			intent.movement = Vector2(0,-1)
			intent.run = true
			intent.jump_pressed = action == "jump"
			intent.crouch_pressed = action == "slide"
			actor.submit_intent(intent)
		await _ticks(1)
		for index in range(4):
			var frame: AtlasCharacterContactFrame = frames[index]
			_expect(not frame.ground_step and not frame.stride_started,"bewuste actie gaat vóór gangoverdracht")
			if action == "jump":
				_expect(frame.jumped and frame.air_kind == "jump","sprong bij Alt→Shift wint van geplande pas")
			else:
				_expect(frame.sliding and frame.supported and not frame.jumped,"Shift+C bij Alt-overdracht start dezelfde grondslide")
		await _clear()
