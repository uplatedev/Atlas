extends SceneTree
## Echte motorproef: geen posemock bepaalt vloercontact, vlucht of momentum.

const CHARACTER = preload("res://characters/Character.tscn")
const AUDIO_SHUTDOWN = preload("res://tests/test_audio_shutdown.gd")
const DT := 1.0 / 60.0
const ACTIONS := ["move_forward", "move_back", "move_left", "move_right", "sprint", "sneak", "crouch", "prone", "jump"]
var world: Node3D
var actor: AtlasCharacter
var contacts: Array[AtlasCharacterContactFrame] = []
var failures: Array[String] = []
var fake_support: bool = false
var probe_max: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	_box(Vector3(0, -0.1, 0), Vector3(400, 0.2, 400))
	actor = CHARACTER.instantiate() as AtlasCharacter
	actor.position = Vector3(0, 0.05, 0)
	actor.feedback_enabled = false
	world.add_child(actor)
	actor.set_controlled(true)
	actor.contact_frame_ready.connect(_capture)
	await _frames(8)
	await _test_intent_parity()
	await _test_gait()
	await _test_deceleration_phase()
	await _test_walk_momentum_handoff()
	await _test_jump_phases()
	await _test_posture_and_slide()
	await _test_slide_preference_and_low_route()
	await _test_cliff_and_ceiling()
	await _test_impulses()
	_release()
	world.queue_free()
	await AUDIO_SHUTDOWN.drain(self)
	if failures.is_empty():
		print("PASS: procedurele motor, echte pasvlucht, intentpariteit, randen en massa-impulsen.")
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: ", failure)
		quit(1)


func _test_intent_parity() -> void:
	var traces: Array = []
	for external in [false, true]:
		await _reset(Vector3(0, 0.05, 0), false)
		actor.set_controlled(not external)
		var trace: Array[Vector3] = []
		for frame in 85:
			if external:
				if frame == 0 or frame == 20 or frame == 21 or frame == 55:
					_send(Vector2(0, -1) if frame < 55 else Vector2.ZERO, frame < 55, frame == 20)
			else:
				if frame == 0:
					Input.action_press("move_forward")
					Input.action_press("sprint")
				if frame == 20:
					Input.action_press("jump")
				if frame == 21:
					Input.action_release("jump")
				if frame == 55:
					_release()
			await _frames(1)
			trace.append(actor.global_position)
			trace.append(actor.velocity)
		traces.append(trace)
	var error := 0.0
	for index in traces[0].size():
		error = maxf(error, Vector3(traces[0][index]).distance_to(traces[1][index]))
	_expect(error < 0.00001, "toetsenbord en één gedeelde AI-intent volgen exact dezelfde fysieke route")
	print("MEASURE: player/AI trajectory maximum difference %.8f" % error)
	await _reset(Vector3(0, 0.05, 0), false)
	_send(Vector2.ZERO, false, true)
	await _frames(140)
	_expect(_count("jumped") == 1, "één ingediende sprongedge wordt nooit herhaald door de vastgehouden intent")


func _test_gait() -> void:
	var walk := await _gait_sample(false)
	var sprint := await _gait_sample(true)
	_expect(walk.cycles >= 4 and sprint.cycles >= 4, "lopen en sprinten herhalen echte afzet en echte touchdown")
	_expect(sprint.height > walk.height * 1.5 and sprint.air_frames > walk.air_frames, "meer snelheid geeft meetbaar hogere én langere echte pasvluchten")
	_expect(absf(walk.speed - actor.walk_forward_speed) < 0.06 and absf(sprint.speed - actor.sprint_forward_speed) < 0.06, "pasvlucht bewaart ingestelde strakke horizontale loop- en sprintvaart")
	_expect(not fake_support and probe_max <= 1, "echte paslucht meldt geen steun en gebruikt hoogstens één lokale vloerprobe per tick")
	print("MEASURE: walk height %.4f/air %d; sprint height %.4f/air %d; probes %d" % [walk.height, walk.air_frames, sprint.height, sprint.air_frames, probe_max])
	await _reset()
	_send(Vector2.ZERO)
	await _frames(100)
	_expect(_count("stride_started") == 0, "stilstand start geen kunstmatige pasvlucht")


func _test_deceleration_phase() -> void:
	var comparisons := 0
	var backwards := 0
	for supported_only in [false, true]:
		var original_curve := actor.body_profile.stride_flight_curve
		if supported_only:
			var curve := Curve.new()
			curve.add_point(Vector2.ZERO)
			curve.add_point(Vector2(1.0, 0.0))
			actor.body_profile.stride_flight_curve = curve
		for delay in range(0, 18, 3):
			await _reset()
			_send(Vector2(0, -1), true)
			await _frames(90 + delay)
			_send(Vector2.ZERO)
			var previous: AtlasCharacterContactFrame = contacts[-1]
			for tick in 60:
				await _frames(1)
				var current: AtlasCharacterContactFrame = contacts[-1]
				if current.horizontal_speed > 0.1 and current.step_index == previous.step_index:
					comparisons += 1
					if current.gait_phase + 0.000001 < previous.gait_phase:
						backwards += 1
				previous = current
		actor.body_profile.stride_flight_curve = original_curve
	_expect(comparisons > 50 and backwards == 0, "uitrollen op verschillende pasmomenten draait de vrije voetfase nooit achteruit")
	print("MEASURE: deceleration phase comparisons %d, backwards %d" % [comparisons, backwards])


func _test_walk_momentum_handoff() -> void:
	var defaults := Vector3(actor.sneak_forward_speed,actor.walk_forward_speed,actor.sprint_forward_speed)
	var cases := 0
	var transitional_frames := 0
	var max_speed_error := 0.0
	for speeds in [defaults, Vector3(1.4,6.5,11.0), Vector3(2.1,6.5,11.0)]:
		actor.sneak_forward_speed = speeds.x
		actor.walk_forward_speed = speeds.y
		actor.sprint_forward_speed = speeds.z
		for direction in [Vector2(0,-1),Vector2(1,-1).normalized(),Vector2(0,1),Vector2(1,0)]:
			for delay in [0,5]:
				await _reset()
				_send(direction,true)
				await _frames(120+delay)
				var intent := AtlasCharacterIntent.new()
				intent.movement = direction
				intent.sneak = true
				actor.submit_intent(intent)
				var previous: AtlasCharacterContactFrame = contacts[-1]
				var limit := actor.direction_speed_limit_for_state(direction,"sneak")
				var walking_frames := 0
				for tick in 90:
					var before_speed := Vector2(actor.velocity.x,actor.velocity.z).length()
					await _frames(1)
					var current: AtlasCharacterContactFrame = contacts[-1]
					var speed := Vector2(actor.velocity.x,actor.velocity.z).length()
					max_speed_error = maxf(max_speed_error,absf(speed-maxf(limit,before_speed-actor.sneak_deceleration*DT)))
					_expect(speed <= before_speed+0.00001,"Alt-overdracht voegt geen vaart toe")
					_expect(not current.jumped and not current.landed,"Alt-overdracht geeft geen sprong of impactcue")
					if speed > limit+0.01:
						transitional_frames += 1
						_expect(current.motion_profile == "lopen","werkelijke overgangsvaart publiceert jog voor timing en pose")
					if current.motion_profile == "sneak":
						walking_frames += 1
						_expect(speed <= limit+0.01001,"WALK begint pas binnen eigen richtingslimiet")
						if direction != Vector2(1,0):
							_expect(current.supported and current.gait_supported_cycle and current.support_fraction == 1.0,"WALK-contacten gebruiken coherente gesteunde timing")
							if previous.motion_profile != "sneak":
								_expect(current.ground_step or current.stride_landed or previous.gait_supported_cycle,"WALK neemt bestaande cyclus alleen bij contact over")
					if current.step_index == previous.step_index:
						_expect(current.gait_phase+0.000001 >= previous.gait_phase,"Alt-overgang draait motorfase niet terug")
					previous = current
				_expect(walking_frames > 20,"overdracht bereikt blijvend de eigen Alt-gang")
				cases += 1
	actor.sneak_forward_speed = defaults.x
	actor.walk_forward_speed = defaults.y
	actor.sprint_forward_speed = defaults.z
	_expect(max_speed_error < 0.00002,"Alt-overdracht bewaart de bestaande exacte remwet")
	print("MEASURE: momentum-to-WALK cases %d, transient JOG frames %d, brake error %.8f" % [cases,transitional_frames,max_speed_error])


func _gait_sample(sprint: bool) -> Dictionary:
	await _reset()
	_send(Vector2(0, -1), sprint)
	await _frames(100)
	contacts.clear()
	await _frames(240)
	var max_height := 0.0
	var baseline := 0.0
	var air_frames := 0
	var longest := 0
	var started := false
	var cycles := 0
	for contact in contacts:
		if contact.stride_started:
			baseline = contact.world_position.y - contact.body_velocity.y * DT
			started = true
			air_frames = 0
		if started and contact.air_kind == "stride":
			max_height = maxf(max_height, contact.world_position.y - baseline)
			air_frames += 1
		if contact.stride_landed:
			cycles += 1
			longest = maxi(longest, air_frames)
			started = false
	_expect(_count("jumped") == 0 and _count("landed") == 0 and float(actor.get_debug_state().fatigue) < 0.00001, "gewone passen verbruiken geen sprong en maken geen impactlandingen")
	return {"height": max_height, "air_frames": longest, "cycles": cycles, "speed": Vector2(actor.velocity.x, actor.velocity.z).length()}


func _test_jump_phases() -> void:
	for phase in [0.15, 0.55, 0.80]:
		await _reset()
		_send(Vector2(0, -1), true)
		await _frames(90)
		var found := false
		for index in 90:
			await _frames(1)
			var state := actor.get_debug_state()
			if absf(float(state.gait_phase) - phase) < 0.10 and (str(state.air_kind) == "stride" if phase > 0.5 else actor.is_on_floor()):
				found = true
				break
		_expect(found, "fase %.2f wordt in een werkelijke pas gevonden" % phase)
		var parameters := actor.jump_parameters(actor.velocity)
		var before_jump := _count("jumped")
		_send(Vector2(0, -1), true, true)
		await _frames(1)
		_expect(_count("jumped") == before_jump + 1 and str(actor.get_debug_state().air_kind) == "jump", "spatie in pasfase %.2f geeft direct één bewuste sprong" % phase)
		_expect(absf(actor.velocity.y - float(parameters.vertical_speed)) < 0.05, "sprong in pasfase %.2f vervangt verticale snelheid en stapelt geen pasimpuls" % phase)
		_expect(float(actor.get_debug_state().fatigue) > 0.1 and not bool(actor.get_debug_state().stride_jump_available), "bewuste sprong betaalt fatigue eenmaal en beëindigt het pas-sprongticket")
		await _frames(110)
		_expect(_count("jumped") == before_jump + 1, "ingediende sprongedge herhaalt niet na terugkeer naar pasbeweging")


func _test_posture_and_slide() -> void:
	await _reset()
	_send(Vector2(0, -1), true)
	await _wait_for_stride()
	var before := Vector2(actor.velocity.x, actor.velocity.z).length()
	_send(Vector2(0, -1), true, false, true)
	await _frames(1)
	_expect(actor.get_posture() == 1 and bool(actor.get_debug_state().slide_pending) and not bool(actor.get_debug_state().stride_jump_available), "C tijdens sprintpasvlucht kiest veilige kruip en bereidt slide zonder pas-sprongticket voor")
	for index in 40:
		if bool(actor.get_debug_state().slide_active):
			break
		await _frames(1)
	_expect(bool(actor.get_debug_state().slide_active) and actor.is_on_floor(), "voorbereide passlide begint pas bij werkelijk grondcontact")
	_expect(Vector2(actor.velocity.x, actor.velocity.z).length() <= before + 0.03 and _count("jumped") == 0 and _count("landed") == 0, "pas-naar-slide bewaart vaart zonder boost, sprong of valse impact")
	await _reset()
	_send(Vector2(0, -1))
	await _wait_for_stride()
	_send(Vector2(0, -1), false, false, true)
	await _frames(60)
	_expect(actor.get_posture() == 1 and not bool(actor.get_debug_state().slide_active) and not bool(actor.get_debug_state().slide_pending), "gewone C tijdens looppas kiest blijvend kruip zonder sprintslide")
	var after := _count("stride_started")
	await _frames(40)
	_expect(_count("stride_started") == after, "lage houding start geen nieuwe rechtop-passen")


func _test_slide_preference_and_low_route() -> void:
	await _reset(Vector3(0, 0.05, 0), false)
	_send(Vector2(0, -1), true)
	await _frames(80)
	_send(Vector2(0, -1), true, false, true)
	await _frames(1)
	var before_speed := Vector2(actor.velocity.x, actor.velocity.z).length()
	var before_time := float(actor.get_debug_state().slide_time_left)
	_send(Vector2(0, -1), true, false, true)
	await _frames(1)
	_expect(bool(actor.get_debug_state().slide_active) and str(actor.get_debug_state().manual_posture) == "kruipen", "nieuwe C tijdens slide bewaart de slide en kiest uitsluitend kruip erna")
	_expect(absf(float(actor.get_debug_state().slide_time_left) - before_time + DT) < 0.00001 and absf(Vector2(actor.velocity.x, actor.velocity.z).length() - before_speed + actor.crouch_slide_deceleration * DT) < 0.03, "C verandert timer en vaart niet buiten de gewone framewrijving")
	await _frames(80)
	_expect(actor.get_posture() == 1 and not bool(actor.get_debug_state().slide_active) and not bool(actor.get_debug_state().slide_pending), "natuurlijk slide-einde bewaart de tijdens slide gekozen kruipvoorkeur")
	var crouch_roof := _box(Vector3(0, 1.3, -4), Vector3(8, 0.2, 4))
	var prone_roof := _box(Vector3(0, 0.9, -8), Vector3(8, 0.2, 4))
	await _reset(Vector3(0, 0.05, 0), false)
	_send(Vector2(0, -1))
	await _frames(210)
	var saw_prone := false
	for contact in contacts:
		saw_prone = saw_prone or contact.posture == "liggen"
	_expect(not saw_prone and actor.position.z > -6.0 and actor.get_posture() == 1, "staande voorkeur mag automatisch kruipen maar stopt vóór een ligdoorgang")
	_send(Vector2(0, -1), false, false, true)
	for frame in 330:
		await _frames(1)
		saw_prone = saw_prone or actor.get_posture() == 2
		if actor.position.z < -11.5:
			break
	_expect(saw_prone and actor.position.z < -11.5 and actor.get_posture() == 1 and str(actor.get_debug_state().manual_posture) == "kruipen", "pas expliciet gekozen kruip laat de lagere ligdoorgang automatisch passeren en herstelt kruip")
	crouch_roof.queue_free()
	prone_roof.queue_free()
	await _frames(2)

func _test_cliff_and_ceiling() -> void:
	var platform := _box(Vector3(0, 9.9, 0), Vector3(8, 0.2, 6))
	await _reset(Vector3(0, 10.05, 1))
	_send(Vector2(0, -1), true)
	for index in 150:
		await _frames(1)
		if actor.position.z < -3.4 and not actor.is_on_floor():
			break
	_expect(str(actor.get_debug_state().air_kind) == "fall" and not bool(actor.get_debug_state().stride_jump_available), "afgrond verliest lokale steun en verandert pasvlucht in echte val")
	# Gewone coyote na een echte afstap blijft toegestaan; toets na dat venster.
	await _frames(ceili(actor.coyote_time / DT) + 2)
	var jumps := _count("jumped")
	var vertical := actor.velocity.y
	_send(Vector2(0, -1), true, true)
	await _frames(1)
	_expect(_count("jumped") == jumps and actor.velocity.y < vertical, "boven een afgrond blijft geen kunstmatig pas-sprongticket beschikbaar")
	platform.queue_free()
	await _frames(2)
	var ceiling := _box(Vector3(0, 1.95, -30), Vector3(20, 0.2, 100))
	await _reset()
	_send(Vector2(0, -1), true)
	await _frames(100)
	contacts.clear()
	await _frames(90)
	_expect(_count("stride_started") == 0 and actor.global_position.y < 0.04 and actor.is_on_floor(), "onvoldoende plafondruimte onderdrukt echte pasvlucht zonder clippen of zweefsteun")
	_expect(_count("ground_step") >= 4 and _count("stride_landed") == 0 and _count("landed") == 0, "geblokkeerde pasboog houdt gesteunde voetwissels zonder fictieve vlucht of landingscue")
	_assert_supported_steps()
	ceiling.queue_free()
	await _frames(2)
	var curve := actor.body_profile.stride_flight_curve
	var zero_curve := Curve.new()
	zero_curve.add_point(Vector2.ZERO)
	zero_curve.add_point(Vector2(1, 0))
	actor.body_profile.stride_flight_curve = zero_curve
	await _reset()
	_send(Vector2(0, -1), true)
	await _frames(130)
	_expect(_count("stride_started") == 0 and _count("ground_step") >= 4, "nulhoogtecurve behoudt voortbeweging en afwisselende ondersteunde stappen")
	_assert_supported_steps()
	actor.body_profile.stride_flight_curve = curve


func _assert_supported_steps() -> void:
	var full_swing := false
	var previous := -1
	for contact in contacts:
		full_swing = full_swing or contact.gait_phase > 0.65
		if contact.ground_step:
			_expect(contact.supported and contact.air_kind == "none" and not contact.stride_started and not contact.stride_landed, "gesteunde stap is door werkelijk steuncontact bewezen")
			if previous >= 0:
				_expect(contact.step_index == previous + 1, "iedere gesteunde stap wisselt precies één voet")
			previous = contact.step_index
	_expect(full_swing, "gesteunde cyclus doorloopt volle zwaaifase binnen hetzelfde begrensde voetbereik")


func _test_impulses() -> void:
	var deceleration := actor.walk_deceleration
	actor.walk_deceleration = 0.0
	var speeds: Array[float] = []
	for mass in [75.0, 150.0]:
		await _reset(Vector3(0, 0.05, 0), false)
		actor.body_profile.mass_kg = mass
		actor.apply_impulse(Vector3(750, 0, 0))
		await _frames(1)
		speeds.append(actor.velocity.x)
		_expect(actor.is_on_floor(), "horizontale grondimpuls verzint geen verticale afzet")
	_expect(absf(speeds[0] - 10.0) < 0.03 and absf(speeds[1] - 5.0) < 0.03, "dezelfde impuls verandert snelheid uitsluitend volgens impuls gedeeld door massa")
	actor.walk_deceleration = deceleration
	actor.body_profile.mass_kg = 75.0
	await _reset(Vector3(0, 5, 0), false)
	var before_y := actor.velocity.y
	actor.apply_impulse(Vector3(750, 375, 0))
	await _frames(1)
	_expect(absf(actor.velocity.x - 10.0) < 0.03 and absf(actor.velocity.y - before_y - 5.0 + actor.gravity_strength * DT) < 0.03, "luchtimpuls bewaart zijn horizontale surplus en telt precies één fysieke verticale verandering op")
	var after_y := actor.velocity.y
	await _frames(1)
	_expect(absf(actor.velocity.x - 10.0) < 0.03 and absf(actor.velocity.y - after_y + actor.gravity_strength * DT) < 0.03, "volgende tick past de impuls niet opnieuw toe")
	await _reset(Vector3(0, 0.05, 0), false)
	actor.apply_impulse(Vector3(0, 150, 0))
	await _frames(1)
	_expect(not actor.is_on_floor() and actor.velocity.y > 1.5 and _count("jumped") == 0, "verticale grondimpuls maakt echte vlucht zonder sprongkosten of grondoverschrijving")
	await _reset(Vector3(0, 0.05, 0), false)
	_send(Vector2(0, -1), true)
	await _frames(80)
	actor.apply_impulse(Vector3(0, 0, -750))
	await _frames(1)
	var incoming := -actor.velocity.z
	_expect(incoming > 18.0, "extern sprintsurplus wordt op de grond geleidelijk geremd in plaats van afgekapt")
	_send(Vector2(0, -1), true, true)
	await _frames(1)
	_expect(-actor.velocity.z >= incoming - 0.6 and -actor.velocity.z <= incoming + actor.sprint_jump_boost + 0.03, "bewuste sprong bewaart extern surplus met hoogstens één normale sprongbonus")
	var budget := Vector2(actor.velocity.x, actor.velocity.z).length()
	for index in 6:
		for tick in 160:
			await _frames(1)
			if actor.is_on_floor():
				break
		_send(Vector2(0, -1), true, true)
		await _frames(1)
		_expect(Vector2(actor.velocity.x, actor.velocity.z).length() <= budget + 0.04, "herhaalde sprong hergebruikt geen verdwenen impuls of stapelbare bonus")
	await _reset()
	_send(Vector2(0, -1), true)
	await _wait_for_stride()
	var air_before := actor.velocity
	actor.apply_impulse(Vector3(375, 0, 0))
	await _frames(1)
	var expected_air_speed := Vector2(air_before.x + 5.0, air_before.z).length()
	_expect(str(actor.get_debug_state().air_kind) == "fall" and not actor.is_on_floor() and not bool(actor.get_debug_state().stride_jump_available), "inslag tijdens echte paslucht schakelt naar luchtreactie zonder grond- of pasprivilege")
	_expect(absf(Vector2(actor.velocity.x, actor.velocity.z).length() - expected_air_speed) < 0.03, "inslag in paslucht bewaart de echte impuls in het luchtbudget")
	print("MEASURE: impulse 750 Ns at masses75/150 -> %.3f/%.3f m/s; external sprint %.3f" % [speeds[0], speeds[1], incoming])


func _wait_for_stride() -> void:
	for index in 160:
		await _frames(1)
		if str(actor.get_debug_state().air_kind) == "stride" and not actor.is_on_floor():
			return
	_expect(false, "fixture bereikt echte pasvlucht")


func _send(movement: Vector2, sprint: bool = false, jump: bool = false, crouch: bool = false, prone: bool = false) -> void:
	var intent := AtlasCharacterIntent.new()
	intent.movement = movement
	intent.sprint = sprint
	intent.jump_pressed = jump
	intent.crouch_pressed = crouch
	intent.prone_pressed = prone
	actor.submit_intent(intent)


func _reset(at: Vector3 = Vector3(0, 0.05, 0), enabled: bool = true) -> void:
	_release()
	actor.use_player_input()
	actor.procedural_enabled = enabled
	actor.reset_to_spawn()
	actor.global_position = at
	actor.set_controlled(true)
	await _frames(8)
	contacts.clear()


func _capture(contact: AtlasCharacterContactFrame) -> void:
	contacts.append(contact)
	if contact.air_kind == "stride":
		fake_support = fake_support or contact.supported or contact.real_grounded or actor.is_on_floor()
	probe_max = maxi(probe_max, int(actor.get_debug_state().stride_probe_count))


func _count(field: String) -> int:
	var count := 0
	for contact in contacts:
		if bool(contact.get(field)):
			count += 1
	return count


func _frames(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame


func _release() -> void:
	for action in ACTIONS:
		Input.action_release(action)


func _box(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)
	return body


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
