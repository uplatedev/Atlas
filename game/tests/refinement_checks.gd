extends SceneTree
## Regressies uit de gespeelde T-004-feedback: echte physics, richting en knopvolgorde.

const CHARACTER = preload("res://characters/Character.tscn")
const ACTIONS = ["move_forward", "move_back", "move_left", "move_right", "sprint", "sneak", "crouch", "prone", "jump"]
const PHYSICS_DELTA := 1.0 / 60.0
var failures: Array[String] = []
var world: Node3D
var character: AtlasCharacter


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	_add_box(Vector3(0, -0.1, 0), Vector3(400, 0.2, 400))
	character = CHARACTER.instantiate() as AtlasCharacter
	character.position = Vector3(0, 0.05, 0)
	world.add_child(character)
	character.set_controlled(true)
	await _frames(8)
	await _test_partial_acceleration_jump()
	await _test_air_wall_steering_recovery()
	await _test_crouch_landing_slide()
	await _test_air_braking()
	await _test_slide_negative_cases()
	await _test_slide_virtual_step_support()
	await _test_slide_step_boundary()
	await _test_explicit_posture_controls()
	await _test_automatic_posture_policy()
	await _test_oblique_step_and_chatter()
	await _test_idle_body_and_air_steering()
	_release_inputs()
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: feedbackregressies voor sprongafstand, landingsslide, luchtrem, houdingknoppen, schuine doorgang en lichaamsdraai.")
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: ", failure)
		quit(1)


func _test_partial_acceleration_jump() -> void:
	await _reset()
	character.jump_fatigue_enabled = false
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(6)
	var partial: Dictionary = await _jump_once()
	await _reset()
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(100)
	var full: Dictionary = await _jump_once()
	print("MEASURE: sprint partial/full launch %.3f/%.3f m/s; travel %.3f/%.3f m; apex %.3f/%.3f m; partial max-air %.3f/cap %.3f" % [partial.launch, full.launch, partial.travel, full.travel, partial.height, full.height, partial.air_max, partial.launch_cap])
	_expect(partial.launch < full.launch * 0.8, "0.10s sprintaanloop geeft minder afzetsnelheid dan volle sprint")
	_expect(partial.travel < full.travel * 0.9, "korte sprintaanloop geeft aantoonbaar minder sprongafstand dan volle sprint")
	_expect(partial.air_max <= partial.launch + 0.03, "luchtsturing versnelt een gedeeltelijke sprintafzet niet alsnog tot volle loopsnelheid")
	_expect(partial.launch_cap <= partial.launch + 0.03, "gedeeltelijke sprintafzet legt haar werkelijke eigen snelheidsbudget vast")
	var launches: Array[float] = [full.launch]
	for i in 7:
		var next: Dictionary = await _jump_once()
		launches.append(next.launch)
	_expect(launches.max() <= launches[0] + 0.03, "acht onmiddellijke sprintsprongen stapelen niet wanneer vermoeidheid uitstaat")
	_expect(launches.max() <= character.sprint_forward_speed + character.sprint_jump_boost + 0.03, "de sprongcap blijft maximaal één ingestelde sprintbonus")
	print("MEASURE: repeated launches ", launches)
	await _reset()
	Input.action_press("move_forward")
	await _frames(6)
	var walking_partial: Dictionary = await _jump_once()
	await _reset()
	Input.action_press("move_forward")
	await _frames(100)
	var walking_full: Dictionary = await _jump_once()
	print("MEASURE: walk partial/full launch %.3f/%.3f; travel %.3f/%.3f; partial max-air %.3f/cap %.3f" % [walking_partial.launch, walking_full.launch, walking_partial.travel, walking_full.travel, walking_partial.air_max, walking_partial.launch_cap])
	_expect(walking_partial.launch < walking_full.launch * 0.8, "0.10s loopaanloop geeft minder afzetsnelheid dan volle loop")
	_expect(walking_partial.travel < walking_full.travel * 0.9, "gedeeltelijke loopaanloop geeft minder sprongafstand dan volle loop")
	_expect(walking_partial.air_max <= walking_partial.launch + 0.03, "luchtsturing maakt een gedeeltelijke loopafzet niet alsnog volle loopsnelheid")


func _test_air_wall_steering_recovery() -> void:
	await _reset()
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(80)
	var wall := _add_box(character.position + Vector3(0, 2.5, -2.0), Vector3(12, 5, 0.2))
	await _frames(2)
	Input.action_press("jump")
	await _frames(1)
	Input.action_release("jump")
	var cap := float(character.get_debug_state().get("air_speed_cap", _speed()))
	for i in 25:
		await _frames(1)
		if _speed() < 0.01:
			break
	_expect(not character.is_on_floor() and _speed() < 0.01, "echte frontale wandbotsing remt horizontale sprintvlucht tot nul voordat de speler landt")
	Input.action_release("move_forward")
	Input.action_press("move_right")
	await _frames(6)
	var recovery_cap := float(character.get_debug_state().get("air_speed_cap", cap))
	print("MEASURE: air wall recovery speed %.3f; current/launch cap %.3f/%.3f; floor %s" % [_speed(), recovery_cap, cap, character.is_on_floor()])
	_expect(not character.is_on_floor() and character.velocity.x > 0.1, "na een frontale luchtbotsing kan zijinput binnen de beperkte luchtsturing weer langs de wand bewegen")
	_expect(_speed() <= recovery_cap + 0.03 and recovery_cap <= cap + 0.03, "herstel na een luchtbotsing blijft binnen het actuele budget en vergroot de bestaande afzetcap niet")
	_release_inputs()
	wall.queue_free()
	await _frames(3)


func _test_crouch_landing_slide() -> void:
	for action in ["crouch", "prone"]:
		await _launch_sprint()
		var speed_before := _speed()
		var cap_before := float(character.get_debug_state().get("air_speed_cap", 0.0))
		var vertical_before := character.velocity.y
		var fatigue_before := float(character.get_debug_state().get("fatigue", 0.0))
		Input.action_press(action)
		await _frames(1)
		if action == "prone":
			Input.action_release(action)
		var speed_after := _speed()
		print("MEASURE: airborne %s speed %.3f -> %.3f; vertical %.3f -> %.3f; pending %s" % [action, speed_before, speed_after, vertical_before, character.velocity.y, _flag("slide_pending")])
		_expect(not character.is_on_floor() and speed_before > character.walk_forward_speed, "%s wordt tijdens een echte sprintsprong gemeten" % action)
		_expect(absf(speed_after - speed_before) < 0.03, "%s bewaart de horizontale afzetvaart tijdens de vlucht" % action)
		_expect(absf(float(character.get_debug_state().get("air_speed_cap", 0.0)) - cap_before) < 0.03, "%s bewaart het werkelijke afzetbudget tijdens de vormwissel" % action)
		_expect(absf(character.velocity.y - (vertical_before - character.gravity_strength * PHYSICS_DELTA)) < 0.04, "%s verandert de verticale sprong niet behalve normale zwaartekracht" % action)
		_expect(fatigue_before > 0.1 and absf(float(character.get_debug_state().get("fatigue", 0.0)) - fatigue_before) < 0.001, "%s reset werkelijk opgebouwde sprongvermoeidheid niet" % action)
		_expect(character.get_posture() == (1 if action == "crouch" else 2), "%s kiest rechtstreeks de bedoelde handmatige houding" % action)
		_expect(_flag("slide_pending") == (action == "crouch") and not _flag("slide_active"), "alleen succesvolle lucht-Ctrl bereidt een slide voor; de slide begint nog niet")
		var flight_stayed_clean := true
		var previous_speed := _speed()
		for i in 100:
			await _frames(1)
			if character.is_on_floor():
				break
			flight_stayed_clean = flight_stayed_clean and not _flag("slide_active") and absf(_speed() - speed_before) < 0.03
			previous_speed = _speed()
		_expect(flight_stayed_clean and character.is_on_floor(), "%s behoudt de vaart tot een echte landing zonder lucht-slide" % action)
		if action == "prone":
			_expect(not _flag("slide_active") and not _flag("slide_pending"), "Z-lig start ook bij de landing geen kruipslide")
			_expect(_speed() <= _ground_speed_limit("liggen") + 0.03, "Z-lig krijgt bij het eerste echte contact zijn eigen grondbudget zonder verborgen slide")
			print("MEASURE: prone first contact speed %.3f; ground limit %.3f; slide %s" % [_speed(), _ground_speed_limit("liggen"), _flag("slide_active")])
			continue
		_expect(_speed() >= previous_speed - 0.03 and _speed() <= cap_before + 0.03, "de Ctrl-landing behoudt momentum zonder nieuwe sprongbonus")
		_expect(_flag("slide_active") and not _flag("slide_pending"), "Ctrl-slide begint uitsluitend op het eerste echte grondcontact en verbruikt de voorbereiding")
		var initial_heading := Vector3(character.velocity.x, 0, character.velocity.z).normalized()
		Input.action_release("move_forward")
		Input.action_press("move_right")
		await _frames(6)
		var new_heading := Vector3(character.velocity.x, 0, character.velocity.z).normalized()
		var steered_angle := rad_to_deg(acos(clampf(initial_heading.dot(new_heading), -1.0, 1.0)))
		_expect(steered_angle > 0.05 and steered_angle <= _setting("crouch_slide_steering", 35.0) * PHYSICS_DELTA * 6.0 + 0.5, "zijinput stuurt de grondslide beperkt bij in plaats van direct negentig graden te draaien")
		_expect(_speed() > 0.5 and _speed() < speed_before - 0.1, "grondslide verliest geleidelijk vaart door wrijving in plaats van een onmiddellijke stop")
		Input.action_release("move_right")
		Input.action_press("move_forward")
		var step := _add_box(character.position + Vector3(0, 0.15, -3), Vector3(6, 0.3, 4))
		var previous_time := float(character.get_debug_state().get("slide_time_left", 0.0))
		var previous_slide_speed := _speed()
		var saw_virtual_support := false
		var timer_restarted := false
		var gained_speed := false
		var max_slide_frames := ceili(_setting("crouch_slide_duration", 0.45) / PHYSICS_DELTA) + 2
		var elapsed := 6
		while _flag("slide_active") and elapsed < max_slide_frames + 5:
			await _frames(1)
			elapsed += 1
			var state := character.get_debug_state()
			var remaining := float(state.get("slide_time_left", 0.0))
			timer_restarted = timer_restarted or remaining > previous_time + 0.0001
			if _flag("slide_active"):
				gained_speed = gained_speed or _speed() > previous_slide_speed + 0.03
			previous_time = remaining
			previous_slide_speed = _speed()
			# Jolt kan tegelijk de afgeronde trederand als echte vloer zien. De
			# uitgevoerde opstap bewijst de support-route zonder die vloer te ontkennen.
			saw_virtual_support = saw_virtual_support or (character.get_camera_grounded() and float(state.get("last_step_height", 0.0)) > 0.2)
		_expect(not gained_speed, "W en Shift toevoegen tijdens de slide geen snelheid of oude boost")
		_expect(saw_virtual_support and not timer_restarted, "een echte opstap via de steunroute herstart de landingsslide niet")
		_expect(not _flag("slide_active") and elapsed <= max_slide_frames, "grondslide eindigt binnen de ingestelde maximale duur")
		_expect(character.get_posture() == 1 and str(character.get_debug_state().get("manual_posture", "")) == "kruipen", "na de slide blijft de handmatige kruiphouding behouden")
		print("MEASURE: slide steering %.3fdeg; duration %d frames; step support %s; end speed %.3f" % [steered_angle, elapsed, saw_virtual_support, _speed()])
		step.queue_free()
		await _frames(3)
		_release_inputs()


func _test_air_braking() -> void:
	var reference: Dictionary = await _brake_flight(false)
	var braked: Dictionary = await _brake_flight(true)
	_expect(braked.travel < reference.travel * 0.97, "S tijdens een voorwaartse sprintsprong geeft werkelijk een kortere landingsafstand")
	_expect(braked.speeds.size() > 3 and braked.speeds[0] > braked.speeds[1] and braked.speeds[1] > braked.speeds[2] and braked.speeds[2] > 0.1, "S verlaagt de luchtvaart over meerdere frames zonder onmiddellijke stop")
	var vertical_matches: bool = reference.vertical.size() == braked.vertical.size()
	if vertical_matches:
		for i in reference.vertical.size():
			vertical_matches = vertical_matches and absf(float(reference.vertical[i]) - float(braked.vertical[i])) < 0.001
	_expect(vertical_matches, "S verandert de verticale vlucht niet vergeleken met dezelfde ongeremde afzet")
	print("MEASURE: airborne S travel %.3f vs %.3f without S; initial speeds %s" % [braked.travel, reference.travel, str(braked.speeds.slice(0, 4))])
	await _launch_sprint()
	Input.action_release("move_forward")
	Input.action_press("move_back")
	await _frames(6)
	var slowed := _speed()
	Input.action_release("move_back")
	Input.action_press("move_forward")
	await _frames(10)
	_expect(not character.is_on_floor() and _speed() <= slowed + 0.03, "vooruit sturen na luchtremmen herstelt geen verloren sprintbonus")
	for launch_actions in [["move_back"], ["move_back", "move_left"], ["move_forward", "move_left"]]:
		await _launch_sprint(launch_actions)
		var before := _speed()
		Input.action_release("move_forward")
		Input.action_release("move_left")
		Input.action_press("move_back")
		await _frames(6)
		if launch_actions.has("move_forward"):
			_expect(_speed() > 0.1 and _speed() < before - 0.05, "S remt ook een werkelijk voorwaartse diagonale afzet geleidelijk")
		else:
			_expect(absf(_speed() - before) < 0.03 and not _flag("air_braking"), "S remt een achterwaartse afzet niet wanneer de input al met de vaart meegaat")
	# Dezelfde grondslide met en zonder tegeninput; beiden verliezen vaart door wrijving.
	var coast_slide: Dictionary = await _slide_sample(false)
	var braked_slide: Dictionary = await _slide_sample(true)
	_expect(braked_slide.speed > 0.1 and braked_slide.speed < coast_slide.speed - 0.05, "S remt een voorwaartse grondslide sterker maar niet onmiddellijk tot stilstand")
	_expect(braked_slide.travel < coast_slide.travel - 0.01, "extra sliderem geeft een aantoonbaar kortere verplaatsing op de grond")
	print("MEASURE: slide S speed/travel %.3f/%.3f vs %.3f/%.3f without S" % [braked_slide.speed, braked_slide.travel, coast_slide.speed, coast_slide.travel])


func _test_slide_negative_cases() -> void:
	await _reset()
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(80)
	await _pulse("crouch")
	await _frames(10)
	_expect(character.get_posture() == 1 and not _flag("slide_pending") and not _flag("slide_active"), "Ctrl op de grond is gewone kruip en start geen slide")
	await _launch_sprint()
	character.request_posture(1)
	await _frames(2)
	_expect(character.get_posture() == 1 and not _flag("slide_pending"), "een programmatisch aangevraagde lage houding in de lucht is geen handmatige Ctrl-skill")
	await _wait_for_landing()
	_expect(not _flag("slide_active"), "automatisch aangevraagde kruip start bij de landing geen slide")
	_expect(_speed() <= _ground_speed_limit("kruipen") + 0.03, "een lage landing zonder Ctrl-skill houdt geen verborgen sprintvaart over")
	await _launch_sprint()
	var original_radius := character.crouch_capsule_radius
	character.crouch_capsule_radius = 0.6
	var left_wall := _add_box(character.position + Vector3(-0.6, 2.5, -2), Vector3(0.2, 5, 20))
	var right_wall := _add_box(character.position + Vector3(0.6, 2.5, -2), Vector3(0.2, 5, 20))
	await _pulse("crouch")
	_expect(character.get_posture() == 0 and not _flag("slide_pending"), "een werkelijk geblokkeerde brede kruipvorm bereidt geen slide voor")
	await _wait_for_landing()
	_expect(not _flag("slide_active") and not _flag("slide_pending"), "mislukte lucht-Ctrl wordt bij de landing geen vertraagde slide")
	left_wall.queue_free()
	right_wall.queue_free()
	character.crouch_capsule_radius = original_radius
	await _frames(3)
	for cancel_action in ["crouch", "prone"]:
		await _launch_sprint()
		await _pulse("crouch")
		_expect(_flag("slide_pending"), "succesvolle lucht-Ctrl bereidt de volgende negatieve proef werkelijk voor")
		await _pulse(cancel_action)
		_expect(not _flag("slide_pending"), "%s annuleert de voorbereiding vóór de landing" % cancel_action)
		await _wait_for_landing()
		_expect(not _flag("slide_active"), "%s laat een geannuleerde voorbereiding bij de landing niet terugkomen" % cancel_action)
	await _launch_sprint()
	await _pulse("crouch")
	_expect(_flag("slide_pending"), "respawnproef begint met een werkelijk voorbereide slide")
	await _reset()
	_expect(character.get_posture() == 0 and not _flag("slide_pending") and not _flag("slide_active"), "respawn wist de oude slide en begint weer gewoon staand")
	# Een legale minimale duur zonder wrijving mag de sprintvaart niet buiten
	# de zichtbare slide laten voortbestaan.
	var duration := _setting("crouch_slide_duration", 0.45)
	var friction := _setting("crouch_slide_deceleration", 18.0)
	character.set("crouch_slide_duration", 0.02)
	character.set("crouch_slide_deceleration", 0.0)
	await _launch_sprint()
	await _pulse("crouch")
	await _wait_for_landing()
	_expect(_flag("slide_active") and _speed() > character.crouch_forward_speed, "de korte slide begint met echte bewaarde afzetvaart")
	await _frames(2)
	_expect(not _flag("slide_active") and _speed() <= _ground_speed_limit("kruipen") + 0.03, "ook een slide van 0.02s zonder wrijving eindigt binnen het gewone kruipbudget")
	print("MEASURE: short frictionless slide exit speed %.3f; ground limit %.3f" % [_speed(), _ground_speed_limit("kruipen")])
	character.set("crouch_slide_duration", duration)
	character.set("crouch_slide_deceleration", friction)
	await _launch_sprint()
	await _pulse("crouch")
	await _wait_for_landing()
	_expect(_flag("slide_active"), "grond-Z-proef begint met een echte actieve Ctrl-slide")
	await _pulse("prone")
	_expect(character.get_posture() == 2 and not _flag("slide_active") and _speed() <= _ground_speed_limit("liggen") + 0.03, "Z tijdens de grondslide kiest lig, annuleert de slide en houdt alleen veilige ligvaart over")


func _launch_sprint(actions: Array = ["move_forward"]) -> Vector3:
	await _reset()
	character.jump_fatigue_enabled = true
	for action in actions:
		Input.action_press(action)
	Input.action_press("sprint")
	await _frames(80)
	var origin := character.position
	Input.action_press("jump")
	await _frames(1)
	Input.action_release("jump")
	await _frames(8)
	return origin


func _test_slide_virtual_step_support() -> void:
	# Zonder Godot-vloersnap heeft de afgeronde voet even alleen de controller-
	# steunroute. Dat mag een bestaande slide behouden, maar geen nieuwe starten.
	var original_radius := character.crouch_capsule_radius
	var original_snap := character.floor_snap_length
	character.crouch_capsule_radius = 0.15
	character.floor_snap_length = 0.0
	await _launch_sprint()
	await _pulse("crouch")
	await _wait_for_landing()
	var step := _add_box(character.position + Vector3(0, 0.15, -2.5), Vector3(8, 0.3, 4))
	var saw_virtual_only := false
	var continued := true
	var previous_time := float(character.get_debug_state().get("slide_time_left", 0.0))
	for i in 10:
		await _frames(1)
		var remaining := float(character.get_debug_state().get("slide_time_left", 0.0))
		if character.get_camera_grounded() and not character.is_on_floor():
			saw_virtual_only = true
			continued = continued and _flag("slide_active") and remaining < previous_time and not _flag("slide_pending")
		previous_time = remaining
	_expect(saw_virtual_only and continued, "uitsluitend virtuele steun op een geldige opstap bewaart de bestaande slide zonder herstart of nieuwe voorbereiding")
	print("MEASURE: virtual-only step support %s; continued slide %s; speed %.3f" % [saw_virtual_only, continued, _speed()])
	step.queue_free()
	character.crouch_capsule_radius = original_radius
	character.floor_snap_length = original_snap
	await _frames(3)


func _test_slide_step_boundary() -> void:
	# Met de default radius raakt een slide een rand al door radius + één
	# bewegingsframe. De steunproef moet de geldige bovenkant dan ook bereiken.
	await _launch_sprint()
	await _pulse("crouch")
	await _wait_for_landing()
	var start := character.position
	var step := _add_box(start + Vector3(0, 0.15, -2.5), Vector3(8, 0.3, 4))
	var continued := true
	var crossed_step := false
	var previous_speed := _speed()
	for i in 10:
		await _frames(1)
		continued = continued and _flag("slide_active") and _speed() > 0.1 and _speed() <= previous_speed + 0.03
		crossed_step = crossed_step or character.position.y > start.y + 0.29
		previous_speed = _speed()
	_expect(crossed_step and continued, "een geldige trede van 0.30m op 0.50m vooruit bewaart de default-capsuleslide zonder botsingsstop of nieuwe vaart")
	print("MEASURE: close step crossed %s; slide continued %s; speed %.3f" % [crossed_step, continued, _speed()])
	step.queue_free()
	await _frames(3)
	await _launch_sprint()
	await _pulse("crouch")
	await _wait_for_landing()
	start = character.position
	var wall := _add_box(start + Vector3(0, 2, -0.6), Vector3(8, 4, 0.2))
	await _frames(8)
	_expect(not _flag("slide_active") and not _flag("slide_pending") and _speed() < 0.03, "een echte hoge wand stopt de slide en wordt niet als geldige opstap of nieuwe voorbereiding behandeld")
	_expect(character.position.y < start.y + 0.05 and character.position.z >= start.z - 0.19, "de slide blijft vóór de echte wand zonder lift of doorsnijden")
	Input.action_release("move_forward")
	Input.action_press("move_right")
	await _frames(6)
	_expect(character.velocity.x > 0.1 and _speed() <= _ground_speed_limit("kruipen") + 0.03, "zijinput na een echte wandstop herstelt alleen gewone kruipvaart zonder de oude sprintboost")
	print("MEASURE: real wall slide stopped; lateral recovery %.3f; ground limit %.3f" % [_speed(), _ground_speed_limit("kruipen")])
	wall.queue_free()
	await _frames(3)


func _brake_flight(brake: bool) -> Dictionary:
	var start: Vector3 = await _launch_sprint()
	if brake:
		Input.action_release("move_forward")
		Input.action_press("move_back")
	var speeds: Array[float] = []
	var vertical: Array[float] = []
	for i in 100:
		await _frames(1)
		speeds.append(_speed())
		vertical.append(character.velocity.y)
		if character.is_on_floor():
			break
	_expect(character.is_on_floor(), "gemeten luchtremvlucht eindigt werkelijk op de vloer")
	return {"travel": Vector2(character.position.x - start.x, character.position.z - start.z).length(), "speeds": speeds, "vertical": vertical}


func _slide_sample(brake: bool) -> Dictionary:
	await _launch_sprint()
	await _pulse("crouch")
	await _wait_for_landing()
	var start := character.position
	if brake:
		Input.action_release("move_forward")
		Input.action_press("move_back")
	await _frames(6)
	_expect(_flag("slide_active"), "de vergeleken grondrem wordt tijdens een echte actieve slide gemeten")
	return {"speed": _speed(), "travel": Vector2(character.position.x - start.x, character.position.z - start.z).length()}


func _wait_for_landing() -> void:
	for i in 100:
		await _frames(1)
		if character.is_on_floor():
			return
	_expect(false, "de physicsproef moet werkelijk landen")


func _flag(key: String) -> bool:
	return bool(character.get_debug_state().get(key, false))


func _setting(key: String, fallback: float) -> float:
	for property in character.get_property_list():
		if str(property.name) == key:
			return float(character.get(key))
	return fallback


func _ground_speed_limit(state: String) -> float:
	var local := character.global_basis.inverse() * Vector3(character.velocity.x, 0, character.velocity.z)
	return character.direction_speed_limit_for_state(Vector2(local.x, local.z), state)


func _test_explicit_posture_controls() -> void:
	await _reset()
	await _pulse("prone")
	_expect(character.get_posture() == 2, "Z kiest vanuit staan handmatig direct lig")
	await _pulse("prone")
	_expect(character.get_posture() == 2, "Z tijdens lig blijft lig; alleen oprichten brengt de speler hoger")
	await _pulse("crouch")
	_expect(character.get_posture() == 1, "Ctrl kiest vanuit lig expliciet kruip")
	await _pulse("crouch")
	_expect(character.get_posture() == 0, "Ctrl schakelt de handmatig gekozen kruiphouding weer uit")
	await _pulse("prone")
	Input.action_press("jump")
	await _frames(25)
	Input.action_release("jump")
	await _frames(2)
	_expect(character.get_posture() == 1 and character.is_on_floor(), "eerste spatie vanuit lig richt op naar kruip zonder sprong")
	_expect(character.get_posture() == 1, "vasthouden van oprichtspatie voert geen tweede houdingstap uit")
	await _pulse("jump")
	_expect(character.get_posture() == 0 and character.is_on_floor(), "tweede spatie richt kruip op naar staan zonder sprong")
	await _frames(20)
	_expect(character.is_on_floor(), "opricht-input wordt geen gebufferde sprong na het staan")
	Input.action_press("jump")
	await _frames(2)
	_expect(not character.is_on_floor() and character.velocity.y > 1.0, "pas een nieuwe spatie vanuit staan start werkelijk een sprong")
	Input.action_release("jump")
	await _reset()
	await _pulse("prone")
	var roof := _add_box(Vector3(0, 1.5, 0), Vector3(4, 0.2, 4))
	await _frames(2)
	await _pulse("jump")
	await _pulse("jump")
	_expect(character.get_posture() == 1 and character.is_on_floor(), "spatie kan onder 1.40m plafond veilig niet vanuit kruip staan")
	await _frames(15)
	_expect(character.get_posture() == 1 and character.velocity.y <= 0.05, "geblokkeerd oprichten geeft geen sprong of houdingflikkering")
	roof.queue_free()
	await _frames(3)
	await _pulse("jump")
	_expect(character.get_posture() == 0 and character.is_on_floor(), "na vrije hoofdruimte kan een nieuwe oprichtdruk veilig staan")


func _test_automatic_posture_policy() -> void:
	await _reset()
	var roof := _add_box(Vector3(0, 0.9, -3), Vector3(4, 0.2, 4))
	await _frames(2)
	Input.action_press("move_forward")
	var highest_low_posture := 0
	for i in 230:
		await _frames(1)
		highest_low_posture = maxi(highest_low_posture, character.get_posture())
	_expect(highest_low_posture <= 1 and character.position.z > -1.05, "automatische verlaging vanuit staan eindigt maximaal in kruip en blokkeert een ligingang")
	print("MEASURE: auto from stand max posture %s, stopped z %.3f" % [highest_low_posture, character.position.z])
	_release_inputs()
	roof.queue_free()
	await _frames(3)
	await _reset()
	var crouch_roof := _add_box(Vector3(0, 1.3, -3), Vector3(4, 0.2, 4))
	roof = _add_box(Vector3(0, 0.9, -6), Vector3(4, 0.2, 2))
	await _frames(2)
	Input.action_press("move_forward")
	await _frames(200)
	_expect(character.get_posture() == 1 and str(character.get_debug_state().get("manual_posture", "")) == "staan", "eerste 1.20m doorgang maakt werkelijk automatisch kruip terwijl de handmatige keuze staan blijft")
	# De actuele vorm is al automatisch kruip, maar de handmatige keuze is nog stand.
	# Ctrl moet nu handmatig kruip kiezen, zodat dezelfde doorgang vervolgens lig mag gebruiken.
	await _pulse("crouch")
	_expect(str(character.get_debug_state().get("manual_posture", "")) == "kruipen", "Ctrl tijdens automatisch kruip kiest handmatig kruip in plaats van terug naar stand te toggelen")
	var saw_prone := character.get_posture() == 2
	var restored_manual_crouch := false
	for i in 500:
		await _frames(1)
		saw_prone = saw_prone or character.get_posture() == 2
		if character.position.z < -8.1 and character.get_posture() == 1:
			restored_manual_crouch = true
			break
	_expect(saw_prone and character.position.z < -8.1, "handmatig kruip mag automatisch lig gebruiken voor de lage doorgang")
	_expect(restored_manual_crouch, "na automatische lig keert de handmatig gekozen kruip terug")
	_release_inputs()
	roof.queue_free()
	crouch_roof.queue_free()
	await _frames(3)


func _test_oblique_step_and_chatter() -> void:
	# Schuine aanloop vanaf beide buitenhoeken; de capsule raakt eerder dan een center-ray.
	for fixture in [{"x": 0.0, "yaw": 0.0}, {"x": -1.75, "yaw": -30.0}, {"x": 1.75, "yaw": 30.0}, {"x": -1.2, "yaw": -45.0}, {"x": 1.2, "yaw": 45.0}]:
		await _reset()
		character.position.x = fixture.x
		character.rotation.y = deg_to_rad(float(fixture.yaw))
		character.get_node("CameraPivot").reset_view()
		var step := _add_box(Vector3(0, 0.15, -3), Vector3(3, 0.3, 4))
		var roof := _add_box(Vector3(0, 1.60, -3), Vector3(3, 0.2, 4))
		await _frames(2)
		Input.action_press("move_forward")
		Input.action_press("sprint")
		var transitions: Array[int] = [character.get_posture()]
		var greatest_height := character.position.y
		var entered := false
		var unexpected_slide := false
		for i in 260:
			await _frames(1)
			unexpected_slide = unexpected_slide or _flag("slide_pending") or _flag("slide_active")
			greatest_height = maxf(greatest_height, character.position.y)
			if transitions[-1] != character.get_posture():
				transitions.append(character.get_posture())
			if character.position.z < -1.8 and absf(character.position.x) < 1.2 and character.position.y > 0.28:
				entered = true
				break
		print("MEASURE: oblique x %.2f yaw %.1f reached %s at %s; maxY %.3f; postures %s" % [fixture.x, fixture.yaw, entered, str(character.position), greatest_height, str(transitions)])
		_expect(entered and greatest_height > 0.28, "geldige .30m opstap met 1.20m hoofdruimte passeert bij x %.2f / yaw %.1f" % [fixture.x, fixture.yaw])
		_expect(not transitions.has(2), "staan kiest ook schuin geen automatische lighouding")
		_expect(not unexpected_slide, "automatische kruip en opstapsteun starten geen handmatige landingsslide")
		_expect(transitions.size() <= 2, "aanloop tot binnen de doorgang wisselt niet voortdurend staan/kruip")
		_release_inputs()
		step.queue_free()
		roof.queue_free()
		await _frames(3)
	await _reset()
	character.rotation.y = deg_to_rad(30.0)
	character.get_node("CameraPivot").reset_view()
	var sidewall := _add_box(Vector3(-0.55, 1.0, -3), Vector3(0.2, 2.0, 8))
	var raised_floor := _add_box(Vector3(0, 0.15, -3), Vector3(3, 0.3, 4))
	var low_ceiling := _add_box(Vector3(0, 1.60, -3), Vector3(3, 0.2, 4))
	await _frames(2)
	Input.action_press("move_forward")
	var wallslide_entered := false
	for i in 260:
		await _frames(1)
		if character.position.z < -1.8 and character.position.y > 0.28:
			wallslide_entered = true
			break
	print("MEASURE: 30-degree wallslide reached %s at %s" % [wallslide_entered, str(character.position)])
	_expect(wallslide_entered and character.get_posture() == 1, "schuine input langs een wand gebruikt het vrije pad om automatisch de geldige kruipopstap te nemen")
	_release_inputs()
	sidewall.queue_free()
	raised_floor.queue_free()
	low_ceiling.queue_free()
	await _frames(3)


func _test_idle_body_and_air_steering() -> void:
	await _reset()
	var rig = character.get_node("CameraPivot")
	rig.apply_look_delta(Vector2(-200, 0))
	var idle_yaw := character.rotation.y
	await _frames(40)
	_expect(absf(wrapf(character.rotation.y - idle_yaw, -PI, PI)) < deg_to_rad(0.1), "klein rondkijken vanuit stilstand draait het lichaam niet mee")
	_expect(absf(float(character.get_debug_state().get("head_relative_yaw", 0.0))) > 15.0, "bij stilstand blijft aparte hoofdhoek behouden")
	rig.apply_look_delta(Vector2(-10000, 0))
	await _frames(12)
	_expect(absf(character.rotation.y - idle_yaw) > deg_to_rad(5.0), "ver rondkijken bij de hoofdgrens laat ook stilstaand het lichaam bijdraaien")
	await _reset()
	Input.action_press("jump")
	await _frames(1)
	Input.action_release("jump")
	var airborne_idle_yaw := character.rotation.y
	rig.apply_look_delta(Vector2(-200, 0))
	await _frames(10)
	_expect(not character.is_on_floor() and _speed() < 0.01, "stilstaand rondkijken in de lucht gebruikt een echte verticale sprong zonder WASD")
	_expect(absf(wrapf(character.rotation.y - airborne_idle_yaw, -PI, PI)) < deg_to_rad(0.1), "klein rondkijken tijdens een verticale stilstandsprong draait het lichaam niet mee")
	rig.apply_look_delta(Vector2(-10000, 0))
	await _frames(12)
	var airborne_turn := absf(wrapf(character.rotation.y - airborne_idle_yaw, -PI, PI))
	_expect(airborne_turn > deg_to_rad(5.0) and airborne_turn <= deg_to_rad(character.air_turn_speed * PHYSICS_DELTA * 12.0 + 0.1), "bij de hoofdgrens draait een horizontaal stilstaand lichaam in de lucht binnen de eigen luchtdraailimiet")
	await _reset()
	rig.apply_look_delta(Vector2(-200, 0))
	Input.action_press("move_forward")
	await _frames(40)
	_expect(absf(float(character.get_debug_state().get("head_relative_yaw", 999.0))) < 1.0, "tijdens beweging volgt het lichaam de kleine hoofddraai wel")
	for action in ["move_left", "move_right"]:
		await _reset()
		Input.action_press("move_forward")
		Input.action_press("sprint")
		await _frames(80)
		Input.action_press("jump")
		await _frames(1)
		Input.action_release("jump")
		var launch_direction := Vector3(character.velocity.x, 0, character.velocity.z).normalized()
		var cap := float(character.get_debug_state().get("air_speed_cap", _speed()))
		rig.apply_look_delta(Vector2(-200 if action == "move_right" else 200, 0))
		Input.action_press(action)
		await _frames(12)
		var steered := Vector3(character.velocity.x, 0, character.velocity.z).normalized()
		var angle := rad_to_deg(acos(clampf(launch_direction.dot(steered), -1.0, 1.0)))
		_expect(not character.is_on_floor() and angle > 0.5 and angle < 35.0, "%s plus cameradraai geeft beperkte echte luchtsturing" % action)
		_expect(_speed() <= cap + 0.03, "%s plus cameradraai vergroot de sprongcap niet" % action)
		print("MEASURE: %s air steering %.3f degrees; speed %.3f; cap %.3f" % [action, angle, _speed(), cap])


func _jump_once() -> Dictionary:
	var start := character.position
	Input.action_press("jump")
	await _frames(1)
	Input.action_release("jump")
	var launch := _speed()
	var launch_cap := float(character.get_debug_state().get("air_speed_cap", launch))
	var air_max := launch
	var apex := character.position.y
	var airborne := not character.is_on_floor()
	for i in 250:
		await _frames(1)
		apex = maxf(apex, character.position.y)
		if not character.is_on_floor():
			air_max = maxf(air_max, _speed())
		airborne = airborne or not character.is_on_floor()
		if airborne and character.is_on_floor():
			break
	_expect(airborne and character.is_on_floor(), "gemeten sprong heeft werkelijk een vlucht en landing")
	return {"height": apex - start.y, "launch": launch, "launch_cap": launch_cap, "air_max": air_max, "travel": Vector2(character.position.x - start.x, character.position.z - start.z).length()}


func _pulse(action: String) -> void:
	Input.action_press(action)
	await _frames(1)
	Input.action_release(action)
	await _frames(1)


func _reset() -> void:
	_release_inputs()
	character.reset_to_spawn()
	await _frames(8)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame


func _speed() -> float:
	return Vector2(character.velocity.x, character.velocity.z).length()


func _release_inputs() -> void:
	for action in ACTIONS:
		Input.action_release(action)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)


func _add_box(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	world.add_child(body)
	body.position = at
	return body
