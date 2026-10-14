extends SceneTree
## Gerichte terreinproef met de geïntegreerde motor, echte collision en presentatie.
const CHARACTER = preload("res://characters/Character.tscn")
const AUDIO_SHUTDOWN = preload("res://tests/test_audio_shutdown.gd")
const DT := 1.0 / 60.0
var world: Node3D
var actor: AtlasCharacter
var fixtures: Array[Node3D] = []
var frames: Array[AtlasCharacterContactFrame] = []
var failures: Array[String] = []
var ray_max: int = 0
var foot_ray_max: int = 0
var bad_contact: bool = false
var measurements: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	_box(Vector3(0, -0.1, 0), Vector3(400, 0.2, 400), false)
	actor = CHARACTER.instantiate() as AtlasCharacter
	actor.position = Vector3(0, 0.05, 0)
	actor.contact_frame_ready.connect(_capture)
	world.add_child(actor)
	actor.set_controlled(true)
	await _ticks(10)
	await _directions()
	await _steps()
	await _step_guards()
	await _slope()
	await _roofs()
	await _cliff()
	await _slide_jump_preference()
	await _momentum_changes()
	_expect(ray_max <= 1 and foot_ray_max <= 2, "vloer- en voetstralen blijven per tick begrensd tot 1 + 2")
	_expect(not bad_contact, "geen voetcontact tijdens echte lucht en geen stride met fictieve steun")
	for measurement in measurements:
		print("TERRAIN: ", measurement)
	print("TERRAIN QUERY MAX motor/feet ", ray_max, "/", foot_ray_max)
	world.queue_free()
	await AUDIO_SHUTDOWN.drain(self)
	if failures.is_empty():
		print("PROCEDURAL TERRAIN: PASS")
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: ", failure)
		quit(1)

func _directions() -> void:
	for sprint in [false, true]:
		for direction in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, -1).normalized()]:
			await _reset()
			_send(direction, sprint)
			await _ticks(95)
			frames.clear()
			await _ticks(95)
			var speed := Vector2(actor.velocity.x, actor.velocity.z).length()
			var expected := actor.direction_speed_limit(direction, sprint)
			_expect(absf(speed - expected) < 0.06, "loop/sprint-richting %s bewaart bedoelde snelheid" % direction)
			_expect(_count("stride_started") >= 3, "iedere loop/sprint-richting herhaalt echte pasvlucht")
			var presentation: Dictionary = actor.get_node("Presentation/ProceduralBody").get_debug_state()
			_expect(float(presentation.max_planted_error) < 0.025 and int(presentation.released_overreach) == 0, "alle looprichtingen bewaren echte wereldvaste voetcontacten")
			measurements.append("direction %s sprint=%s speed=%.3f planted_error=%.4f releases=%d" % [direction, sprint, speed, presentation.max_planted_error, presentation.released_overreach])
			_send(-direction, sprint)
			var largest_change := 0.0
			var previous := actor.velocity
			for tick in 80:
				await _ticks(1)
				largest_change = maxf(largest_change, Vector2(actor.velocity.x - previous.x, actor.velocity.z - previous.z).length())
				previous = actor.velocity
			_expect(Vector2(actor.velocity.x, actor.velocity.z).dot(-direction) > 0.0, "tegeninvoer remt af en keert richting uiteindelijk om")
			_expect(largest_change <= maxf(actor.walk_deceleration, actor.sprint_deceleration) * actor.countersteer_brake_factor * DT + 0.03, "richtingomkeer heeft alleen begrensde profielremming")

func _steps() -> void:
	for height in [0.3, 0.45]:
		for sprint in [false, true]:
			for offset in [0.0, 0.13, 0.31]:
				await _reset(Vector3(0, 0.05, offset))
				# .45 m is bewust hoger dan de standaard .35 m; de proef stelt .50 in.
				actor.step_height = 0.5 if height > 0.35 else 0.35
				actor.sprint_step_height = actor.step_height
				_box(Vector3(0, height * 0.5, -8), Vector3(6, height, 6))
				await _ticks(2)
				_send(Vector2(0, -1), sprint)
				var min_speed := INF
				var max_step := 0.0
				var support_top := false
				for tick in 170:
					await _ticks(1)

					max_step = maxf(max_step, float(actor.get_debug_state().last_step_height))
					if actor.position.z < -4.2 and actor.position.z > -5.6:
						min_speed = minf(min_speed, Vector2(actor.velocity.x, actor.velocity.z).length())
					if actor.position.z < -5.5 and actor.is_on_floor() and actor.position.y >= height - 0.03:
						support_top = true
					if actor.position.z < -7.0:
						break
				_expect(actor.position.z < -7.0 and support_top, "trede %.2f sprint=%s offset=%.2f wordt werkelijk bestegen" % [height, sprint, offset])
				_expect(min_speed >= (actor.sprint_forward_speed if sprint else actor.walk_forward_speed) - 0.1, "geldige trede verbruikt geen horizontaal pasmomentum")
				_expect(_count("landed") == 0 and _count("jumped") == 0, "veilige opstap geeft geen fictieve impactlanding of bewuste sprong")
				measurements.append("step %.2f sprint=%s offset=%.2f z=%.2f y=%.3f minimum_speed=%.3f step_rise=%.3f" % [height, sprint, offset, actor.position.z, actor.position.y, min_speed, max_step])
				await _clear_fixtures()
	actor.step_height = 0.35
	actor.sprint_step_height = 0.35

func _step_guards() -> void:
	for height in [0.4, 0.45]:
		await _reset()
		actor.step_height = 0.35
		actor.sprint_step_height = 0.35
		_box(Vector3(0, height * 0.5, -8), Vector3(6, height, 6))
		await _ticks(2)
		_send(Vector2(0, -1), true)
		var max_step := 0.0
		var max_y := 0.0
		for tick in 150:
			await _ticks(1)
			max_step = maxf(max_step, float(actor.get_debug_state().last_step_height))
			max_y = maxf(max_y, actor.position.y)
		_expect(actor.position.z > -5.0 and max_step == 0.0 and max_y < 0.15, "pasvlucht telt zijn hoogte niet op bij de ingestelde .35 m opstaplimiet")
		measurements.append("blocked step %.2f max_y=%.4f max_step=%.4f z=%.3f" % [height, max_y, max_step, actor.position.z])
		await _clear_fixtures()
	for deliberate_jump in [true, false]:
		await _reset(Vector3(0, 0.05, -3.8))
		_box(Vector3(0, 0.15, -8), Vector3(6, 0.3, 6))
		await _ticks(2)
		if deliberate_jump:
			_send(Vector2(0, -1), true, true)
		else:
			actor.position.y = 0.7
			actor.apply_impulse(Vector3(0, -37.5, -675))
			_send(Vector2(0, -1), true)
		var air_frames := 0
		var collision_steps := 0
		for tick in 100:
			await _ticks(1)
			var kind := str(actor.get_debug_state().air_kind)
			if kind in ["jump", "fall"]:
				air_frames += 1
				collision_steps += 1 if float(actor.get_debug_state().last_step_height) > 0.0001 else 0
			elif air_frames > 0:
				break
		_expect(air_frames > 2 and collision_steps == 0, "gewone sprong/val krijgt geen stride-opstaprecht")
		measurements.append("step guard deliberate_jump=%s airframes=%d artificial_steps=%d" % [deliberate_jump, air_frames, collision_steps])
		await _clear_fixtures()

func _slope() -> void:
	for sprint in [false, true]:
		await _reset()
		var angle := deg_to_rad(15.0)
		var ramp := _box(Vector3(0, sin(angle) * 5.0 - cos(angle) * 0.1, -8), Vector3(6, 0.2, 10))
		ramp.rotation.x = angle
		await _ticks(2)
		_send(Vector2(0, -1), sprint)
		var max_y := 0.0
		for tick in 260:
			await _ticks(1)
			max_y = maxf(max_y, actor.position.y)
			if actor.position.z < -11.0:
				break
		_expect(actor.position.z < -11.0 and max_y > 1.8, "15-gradenhelling wordt beklommen met sprint=%s" % sprint)
		_send(Vector2(0, 1), sprint)
		# De route is >10 m achteruit: 3 m/s jog geeft daar 1,65 m/s, geen oude 2,75.
		# Budgetteer de routeafstand plus één seconde voor afremmen en omkeren.
		var descent_start := actor.position.z
		var descent_speed := actor.direction_speed_limit(Vector2(0, 1), sprint)
		var descent_budget := ceili(((-1.0 - descent_start) / descent_speed + 1.0) / DT)
		var descent_ticks := 0
		for tick in descent_budget:
			descent_ticks += 1
			await _ticks(1)
			if actor.position.z > -1.0:
				break
		_expect(actor.position.z > -1.0 and actor.position.y < 0.15, "hellingafdaling komt veilig op gewone vloer terug")
		measurements.append("slope sprint=%s maximum_y=%.3f descent_start=%.3f backward_speed=%.3f descent_ticks=%d/%d final_z=%.3f planted_error=%.4f" % [sprint, max_y, descent_start, descent_speed, descent_ticks, descent_budget, actor.position.z, actor.get_node("Presentation/ProceduralBody").get_debug_state().max_planted_error])
		await _clear_fixtures()

func _roofs() -> void:
	var phases: Array[float] = []
	for offset in [0.0, 0.09, 0.2, 0.39, 0.58]:
		await _reset(Vector3(0, 0.05, offset))
		_box(Vector3(0, 1.95, -9), Vector3(6, 0.2, 10))
		await _ticks(2)
		_send(Vector2(0, -1), true)
		var phase_recorded := false
		var ceiling_max_y := 0.0
		for tick in 150:
			await _ticks(1)
			if not phase_recorded and actor.position.z < -3.45:
				phases.append(float(actor.get_debug_state().gait_phase))
				phase_recorded = true
			if actor.position.z < -4.5 and actor.position.z > -13.5:
				ceiling_max_y = maxf(ceiling_max_y, actor.position.y)
			if actor.position.z < -11.0:
				break
		_expect(actor.position.z < -11.0 and actor.get_posture() == 0, "lage pasboog past veilig zonder onnodig kruipen of vastlopen")
		_expect(ceiling_max_y < 0.055 and _count("ground_step") >= 3, "plafond begrenst lichaamshoogte en behoudt ondersteunde voetwissels")
		measurements.append("roof offset=%.2f approachphase=%.3f max_y=%.4f steps=%d" % [offset, phases.back(), ceiling_max_y, _count("ground_step")])
		await _clear_fixtures()
	_expect(phases.max() - phases.min() > 0.15, "plafondproef arriveert aantoonbaar op verschillende pasfasen")

func _cliff() -> void:
	await _reset(Vector3(0, 8.1, 0))
	_box(Vector3(0, 7.9, 0), Vector3(6, 0.2, 8))
	await _ticks(15)
	_send(Vector2(0, -1), true)
	for tick in 160:
		await _ticks(1)
		if actor.position.z < -4.8 and actor.position.y < 7.5:
			break
	_expect(actor.get_debug_state().air_kind == "fall" and not actor.get_debug_state().stride_jump_available, "afgrond trekt pasrechten in en wordt gewone echte val")
	var camera := actor.get_camera_motion_sample()
	_expect(camera.air_kind == "fall" and camera.stride_offset_y == 0.0, "camera behandelt afgrond niet als ritmische pasvlucht")
	await _clear_fixtures()

func _slide_jump_preference() -> void:
	for prefer_crouch in [false, true]:
		await _reset()
		_send(Vector2(0, -1), true)
		await _ticks(90)
		_send(Vector2(0, -1), true, false, true)
		await _wait_slide()
		if prefer_crouch:
			_send(Vector2(0, -1), true, false, true)
			await _ticks(1)
		var speed := Vector2(actor.velocity.x, actor.velocity.z).length()
		_send(Vector2(0, -1), true, true)
		await _ticks(1)
		_expect(frames.back().jumped and actor.get_posture() == 0 and absf(Vector2(actor.velocity.x, actor.velocity.z).length() - speed) < 0.001, "slidesprong staat veilig op en bewaart exact resterende vaart")
		await _ticks(1)
		var air_posture := str(actor.get_debug_state().posture)
		var manual := str(actor.get_debug_state().manual_posture)
		_expect(manual == ("kruipen" if prefer_crouch else "staan"), "slidesprong behoudt de gekozen houdingvoorkeur")
		_send(Vector2.ZERO)
		await _ticks(150)
		_expect(actor.get_posture() == (1 if prefer_crouch else 0), "na slidesprong/landing keert expliciete kruipvoorkeur terug")
		measurements.append("slidejump prefer_crouch=%s second_air_posture=%s manual=%s remaining_speed=%.3f" % [prefer_crouch, air_posture, manual, speed])

func _momentum_changes() -> void:
	for transition in ["walk", "crouch", "slide", "jump"]:
		await _reset()
		_send(Vector2(0, -1), true)
		await _ticks(90)
		# Wacht op echte steun zodat elke variant exact dezelfde fysieke start heeft.
		for tick in 30:
			if actor.is_on_floor():
				break
			await _ticks(1)
		actor.apply_impulse(Vector3(0, 0, -750))
		await _ticks(1)
		var before := Vector2(actor.velocity.x, actor.velocity.z).length()
		_send(Vector2(0, -1), transition in ["slide", "jump"], transition == "jump", transition in ["crouch", "slide"])
		await _ticks(1)
		var after := Vector2(actor.velocity.x, actor.velocity.z).length()
		var allowance := maxf(actor.walk_deceleration, maxf(actor.sprint_deceleration, actor.crouch_deceleration)) * DT + 0.03
		_expect(after >= before - allowance, "extern momentum blijft bij overgang naar %s behouden behalve profielremming" % transition)
		_expect(after <= before + actor.sprint_jump_boost + 0.03, "overgang naar %s stapelt geen externe impuls" % transition)
		measurements.append("momentum %s before=%.4f after=%.4f posture=%s air=%s" % [transition, before, after, actor.get_debug_state().posture, actor.get_debug_state().air_kind])

func _wait_slide() -> void:
	for tick in 45:
		await _ticks(1)
		if actor.get_debug_state().slide_active:
			return
	_expect(false, "fixture bereikt actieve slide")

func _reset(at: Vector3 = Vector3(0, 0.05, 0)) -> void:
	_send(Vector2.ZERO)
	actor.reset_to_spawn()
	actor.global_position = at
	actor.set_look_input(0.0, 0.0)
	await _ticks(10)
	frames.clear()

func _send(direction: Vector2, sprint: bool = false, jump: bool = false, crouch: bool = false) -> void:
	var intent := AtlasCharacterIntent.new()
	intent.movement = direction
	intent.sprint = sprint
	intent.jump_pressed = jump
	intent.crouch_pressed = crouch
	actor.submit_intent(intent)

func _capture(frame: AtlasCharacterContactFrame) -> void:
	frames.append(frame)
	ray_max = maxi(ray_max, int(actor.get_debug_state().stride_probe_count))
	foot_ray_max = maxi(foot_ray_max, int(actor.get_node("Presentation/ProceduralBody").get_debug_state().get("rays_last_frame", 0)))
	bad_contact = bad_contact or (frame.air_kind == "stride" and (frame.real_grounded or frame.supported)) or (not frame.supported and not frame.foot_contacts.is_empty())
	if not actor.position.is_finite() or not actor.velocity.is_finite():
		_expect(false, "physics blijft eindig")

func _count(field: String) -> int:
	var count := 0
	for frame in frames:
		count += 1 if bool(frame.get(field)) else 0
	return count

func _ticks(count: int) -> void:
	for tick in count:
		await physics_frame
		await process_frame

func _box(at: Vector3, size: Vector3, temporary: bool = true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)
	if temporary:
		fixtures.append(body)
	return body

func _clear_fixtures() -> void:
	_send(Vector2.ZERO)
	for fixture in fixtures:
		fixture.queue_free()
	fixtures.clear()
	await _ticks(2)

func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)