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
	await _test_slide_safe_restore()
	await _test_slide_default_range()
	await _test_slide_jump()
	await _test_slide_jump_negative_cases()
	await _test_repeated_slide_jumps()
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
			flight_stayed_clean = flight_stayed_clean and not _flag("slide_active") and absf(_speed() - speed_before) < 0.03 and character.get_posture() == (1 if action == "crouch" else 2)
			previous_speed = _speed()
		_expect(flight_stayed_clean and character.is_on_floor(), "%s behoudt de vaart tot een echte landing zonder lucht-slide" % action)
		if action == "prone":
			_expect(not _flag("slide_active") and not _flag("slide_pending"), "Z-lig start ook bij de landing geen kruipslide")
			_expect(_speed() <= _ground_speed_limit("liggen") + 0.03, "Z-lig krijgt bij het eerste echte contact zijn eigen grondbudget zonder verborgen slide")
			print("MEASURE: prone first contact speed %.3f; ground limit %.3f; slide %s" % [_speed(), _ground_speed_limit("liggen"), _flag("slide_active")])
			continue
		_expect(_speed() >= previous_speed - 0.03 and _speed() <= cap_before + 0.03, "de Ctrl-landing behoudt momentum zonder nieuwe sprongbonus")
		_expect(_flag("slide_active") and not _flag("slide_pending"), "Ctrl-slide begint uitsluitend op het eerste echte grondcontact en verbruikt de voorbereiding")
		_expect(str(character.get_debug_state().get("manual_posture", "")) == "staan", "de Ctrl-skill bewaart staan als voorkeur tijdens de echte slide")
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
		var kept_skill_posture := character.get_posture() == 1
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
				kept_skill_posture = kept_skill_posture and character.get_posture() == 1 and str(state.get("manual_posture", "")) == "staan"
			previous_time = remaining
			previous_slide_speed = _speed()
			# Jolt kan tegelijk de afgeronde trederand als echte vloer zien. De
			# uitgevoerde opstap bewijst de support-route zonder die vloer te ontkennen.
			saw_virtual_support = saw_virtual_support or (character.get_camera_grounded() and float(state.get("last_step_height", 0.0)) > 0.2)
		_expect(not gained_speed, "W en Shift toevoegen tijdens de slide geen snelheid of oude boost")
		_expect(kept_skill_posture, "de tijdelijke skill blijft fysiek kruip zolang de slide actief is zonder permanente kruipvoorkeur")
		_expect(saw_virtual_support and not timer_restarted, "een echte opstap via de steunroute herstart de landingsslide niet")
		_expect(not _flag("slide_active") and elapsed <= max_slide_frames, "grondslide eindigt binnen de ingestelde maximale duur")
		var end_speed := _speed()
		await _frames(30)
		_expect(character.get_posture() == 0 and str(character.get_debug_state().get("manual_posture", "")) == "staan", "natuurlijk slide-einde herstelt veilig staan ondanks nog vastgehouden Ctrl")
		_expect(not _flag("slide_active") and not _flag("slide_pending"), "vastgehouden Ctrl maakt na natuurlijk slide-einde geen tweede skill")
		print("MEASURE: slide steering %.3fdeg; duration %d frames; step support %s; end speed %.3f; restored posture %d" % [steered_angle, elapsed, saw_virtual_support, end_speed, character.get_posture()])
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
		if cancel_action == "crouch":
			_expect(character.get_posture() == 1 and str(character.get_debug_state().get("manual_posture", "")) == "kruipen", "een nieuwe Ctrl tijdens voorbereide skill kiest permanente kruip en annuleert de skill")
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
	var legal_exit := _ground_speed_limit("sprint" if character.get_posture() == 0 else "kruipen")
	_expect(not _flag("slide_active") and _speed() <= legal_exit + 0.03, "ook een slide van 0.02s zonder wrijving eindigt binnen het grondbudget van de veilige houding")
	print("MEASURE: short frictionless slide exit speed %.3f; ground limit %.3f" % [_speed(), legal_exit])
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
	var step := _add_box(character.position + Vector3(0, 0.15, -2.6), Vector3(8, 0.3, 4))
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
	_expect(character.get_posture() == 0 and str(character.get_debug_state().get("manual_posture", "")) == "staan", "een natuurlijke wandstop herstelt vrij staan zonder vastgehouden kruipvoorkeur")
	_expect(character.velocity.x > 0.1 and _speed() <= minf(_ground_speed_limit("sprint"), character.sprint_acceleration * PHYSICS_DELTA * 6.0) + 0.03, "zijinput na een echte wandstop herstelt alleen gewone grondacceleratie zonder de oude sprintboost")
	print("MEASURE: real wall slide stopped; lateral recovery %.3f; ground limit %.3f" % [_speed(), _ground_speed_limit("sprint")])
	wall.queue_free()
	await _frames(3)


func _test_slide_safe_restore() -> void:
	var duration := _setting("crouch_slide_duration", 0.75)
	var friction := _setting("crouch_slide_deceleration", 10.0)
	character.set("crouch_slide_duration", 1.5)
	character.set("crouch_slide_deceleration", 100.0)
	await _launch_sprint()
	await _pulse("crouch")
	_expect(str(character.get_debug_state().get("manual_posture", "")) == "staan", "lucht-Ctrl is een tijdelijke skill bovenop de staande voorkeur")
	await _wait_for_landing()
	var elapsed := 0
	while _flag("slide_active") and elapsed < 100:
		await _frames(1)
		elapsed += 1
	_expect(elapsed < 30, "de speedgrens beëindigt de sterk geremde slide ruim vóór haar timer")
	await _frames(30)
	_expect(character.get_posture() == 0 and str(character.get_debug_state().get("manual_posture", "")) == "staan", "een natuurlijk einde op snelheid herstelt vrij staan")
	character.set("crouch_slide_duration", duration)
	character.set("crouch_slide_deceleration", friction)
	await _launch_sprint()
	await _pulse("crouch")
	await _wait_for_landing()
	var landing := character.position
	var crouch_roof := _add_box(landing + Vector3(0, 1.3, -7), Vector3(8, 0.2, 20))
	var prone_roof := _add_box(landing + Vector3(0, 0.9, -20), Vector3(8, 0.2, 6))
	elapsed = 0
	var premature_stand := false
	while _flag("slide_active") and elapsed < ceili(duration / PHYSICS_DELTA) + 5:
		await _frames(1)
		elapsed += 1
		premature_stand = premature_stand or character.get_posture() == 0
	await _frames(15)
	_expect(not premature_stand and not _flag("slide_active") and character.get_posture() == 1 and str(character.get_debug_state().get("manual_posture", "")) == "staan", "slide-einde onder 1.20m plafond blijft veilig automatisch kruip met voorkeur staan")
	var transitions: Array[int] = [character.get_posture()]
	var adjacent := true
	var retriggered := false
	for i in 850:
		await _frames(1)
		retriggered = retriggered or _flag("slide_pending") or _flag("slide_active")
		if transitions[-1] != character.get_posture():
			adjacent = adjacent and absi(transitions[-1] - character.get_posture()) == 1
			transitions.append(character.get_posture())
		if character.position.z < landing.z - 24.2 and character.get_posture() == 0:
			break
	_expect(transitions.has(2) and adjacent and character.position.z < landing.z - 24.2 and character.get_posture() == 0, "na een lage slide-uitgang volgt automatisch kruip-lig-kruip-staan zonder handmatige druk")
	_expect(not retriggered and str(character.get_debug_state().get("manual_posture", "")) == "staan", "herstelroute verandert de staande voorkeur niet en maakt geen tweede slide")
	print("MEASURE: low slide exit postures %s; adjacent %s; relative z %.3f" % [str(transitions), adjacent, character.position.z - landing.z])
	crouch_roof.queue_free()
	prone_roof.queue_free()
	await _frames(3)
	# De skill forceert tijdelijk kruip, maar mag een nog lager geldig pad niet
	# blokkeren. Automatisch lig annuleert de kruipslide en gebruikt het ligbudget.
	await _launch_sprint()
	await _pulse("crouch")
	await _wait_for_landing()
	landing = character.position
	var slide_prone_roof := _add_box(landing + Vector3(0, 0.9, -3), Vector3(8, 0.2, 4))
	var saw_prone := false
	var prone_skill := false
	var safe_prone_budget := true
	for i in 320:
		await _frames(1)
		if character.get_posture() == 2:
			saw_prone = true
			prone_skill = prone_skill or _flag("slide_pending") or _flag("slide_active")
			safe_prone_budget = safe_prone_budget and _speed() <= _ground_speed_limit("liggen") + 0.03
		if character.position.z < landing.z - 6.1 and character.get_posture() == 0:
			break
	_expect(saw_prone and not prone_skill and safe_prone_budget, "een ligingang tijdens actieve kruipslide verlaagt veilig, annuleert de skill en laat geen ligslide of overvaart achter")
	_expect(character.position.z < landing.z - 6.1 and character.get_posture() == 0 and str(character.get_debug_state().get("manual_posture", "")) == "staan", "ook een ligingang tijdens de skill herstelt daarna veilig de staande voorkeur")
	print("MEASURE: active slide prone entry %s; lingering skill %s; legal speed %s; relative z %.3f" % [saw_prone, prone_skill, safe_prone_budget, character.position.z - landing.z])
	slide_prone_roof.queue_free()
	await _frames(3)
	for cancel_action in ["crouch", "prone"]:
		await _launch_sprint()
		await _pulse("crouch")
		await _wait_for_landing()
		_expect(_flag("slide_active"), "expliciete houdingkeuze wordt tijdens een echte slide getoetst")
		await _pulse(cancel_action)
		await _frames(45)
		var expected_posture := 1 if cancel_action == "crouch" else 2
		var expected_manual := "kruipen" if cancel_action == "crouch" else "liggen"
		_expect(not _flag("slide_pending") and not _flag("slide_active") and character.get_posture() == expected_posture and str(character.get_debug_state().get("manual_posture", "")) == expected_manual, "%s tijdens de skill annuleert en bewaart de expliciete houding in plaats van later automatisch op te richten" % cancel_action)


func _test_slide_default_range() -> void:
	var duration := _setting("crouch_slide_duration", 0.75)
	var friction := _setting("crouch_slide_deceleration", 10.0)
	var current: Dictionary = await _coast_slide_range()
	character.set("crouch_slide_duration", 0.45)
	character.set("crouch_slide_deceleration", 18.0)
	var previous: Dictionary = await _coast_slide_range()
	character.set("crouch_slide_duration", duration)
	character.set("crouch_slide_deceleration", friction)
	_expect(current.frames > previous.frames and current.travel > previous.travel * 1.2, "sterkere slide-defaults bewaren de oorspronkelijke vaart langer en vergroten de werkelijke grondafstand")
	_expect(current.max_speed <= current.launch + 0.03 and current.frames <= ceili(duration / PHYSICS_DELTA) + 2, "de langere slide voegt geen boost toe en blijft binnen haar ingestelde duur")
	print("MEASURE: default/previous slide frames %d/%d; range %.3f/%.3f; launch/max %.3f/%.3f" % [current.frames, previous.frames, current.travel, previous.travel, current.launch, current.max_speed])


func _coast_slide_range() -> Dictionary:
	await _launch_sprint()
	await _pulse("crouch")
	await _wait_for_landing()
	var start := character.position
	var launch := _speed()
	var max_speed := launch
	var frames := 0
	while _flag("slide_active") and frames < 150:
		await _frames(1)
		frames += 1
		max_speed = maxf(max_speed, _speed())
	_expect(not _flag("slide_active") and frames > 0, "de gemeten slideafstand gebruikt een echte, beëindigde landingsslide")
	return {"frames": frames, "travel": Vector2(character.position.x - start.x, character.position.z - start.z).length(), "launch": launch, "max_speed": max_speed}


func _test_slide_jump() -> void:
	await _active_slide()
	var horizontal := Vector3(character.velocity.x, 0, character.velocity.z)
	var speed_before := horizontal.length()
	var fatigue_before := float(character.get_debug_state().get("fatigue", 0.0))
	var expected: Dictionary = character.jump_parameters(horizontal)
	Input.action_press("jump")
	await _frames(1)
	var state := character.get_debug_state()
	var launch_cap := float(state.get("air_speed_cap", 0.0))
	var launch_fatigue := float(state.get("fatigue", 0.0))
	var launched := not character.is_on_floor() and character.velocity.y > 1.0
	_expect(launched and character.get_posture() == 0 and not _flag("slide_active") and not _flag("slide_pending"), "een nieuwe spatie onderbreekt een echte actieve slide direct met een staande sprong")
	_expect(_speed() <= speed_before + 0.03 and _speed() >= speed_before - _setting("crouch_slide_deceleration", 10.0) * PHYSICS_DELTA - 0.03 and launch_cap <= speed_before + 0.03, "slide-sprong bewaart de overgebleven afzetvaart zonder sprintbonus toe te voegen of het oude budget te herstellen")
	_expect(absf(float(state.get("jump_boost", -1.0))) < 0.001 and absf(character.velocity.y - float(expected.vertical_speed)) < 0.08, "slide-sprong gebruikt het actuele hoogteprofiel maar geen extra horizontale bonus")
	_expect(fatigue_before > 0.1 and launch_fatigue > fatigue_before + 0.1, "slide-sprong behoudt opgebouwde vermoeidheid en betaalt een echte nieuwe sprong")
	_expect(not _flag("ground_jump_available") and float(state.get("jump_buffer_remaining", 1.0)) <= 0.001 and float(state.get("coyote_remaining", 1.0)) <= 0.001, "slide-sprong verbruikt grondticket, buffer en coyote eenmaal")
	print("MEASURE: slide jump speed %.3f -> %.3f; cap %.3f; Y %.3f; fatigue %.3f -> %.3f; bonus %.3f" % [speed_before, _speed(), launch_cap, character.velocity.y, fatigue_before, launch_fatigue, float(state.get("jump_boost", -1.0))])
	Input.action_release("jump")
	if not launched:
		return
	await _frames(1)
	var vertical := character.velocity.y
	Input.action_press("jump")
	await _frames(1)
	_expect(absf(character.velocity.y - (vertical - character.gravity_strength * PHYSICS_DELTA)) < 0.04 and absf(float(character.get_debug_state().get("fatigue", 0.0)) - launch_fatigue) < 0.001, "een tweede druk binnen coyotetijd geeft na slide-sprong geen tweede afzet of extra fatigue")
	var air_max := _speed()
	for i in 140:
		await _frames(1)
		air_max = maxf(air_max, _speed())
		if character.is_on_floor():
			break
	_expect(air_max <= launch_cap + 0.03 and character.is_on_floor(), "de hele slide-sprong houdt haar eigen beperkte budget en landt werkelijk")
	await _frames(12)
	_expect(character.is_on_floor() and character.velocity.y <= 0.05, "verlopen buffer en vastgehouden replay-spatie starten na de landing geen stille extra sprong")
	Input.action_release("jump")


func _test_slide_jump_negative_cases() -> void:
	# De oorspronkelijke spatie blijft vanaf de eerste afzet ingedrukt; alleen
	# een nieuwe druk mag de later gestarte slide onderbreken.
	await _reset()
	character.jump_fatigue_enabled = true
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(80)
	Input.action_press("jump")
	await _frames(9)
	await _pulse("crouch")
	await _wait_for_landing()
	await _frames(8)
	_expect(_flag("slide_active") and character.get_posture() == 1 and character.is_on_floor(), "vastgehouden oorspronkelijke sprongspatie onderbreekt de nieuwe landingsslide niet")
	await _frames(60)
	_expect(character.is_on_floor() and character.get_posture() == 0, "originele held-spatie geeft ook na natuurlijk slide-einde geen automatische sprong")
	Input.action_release("jump")
	await _reset()
	await _pulse("crouch")
	await _pulse("jump")
	await _frames(12)
	_expect(character.get_posture() == 0 and character.is_on_floor() and character.velocity.y <= 0.05 and not _flag("slide_active"), "Ctrl op de grond geeft geen skill: spatie richt gewone kruip alleen op zonder sprong")
	await _active_slide()
	var roof := _add_box(character.position + Vector3(0, 1.3, -5), Vector3(8, 0.2, 16))
	await _frames(1)
	var fatigue_before := float(character.get_debug_state().get("fatigue", 0.0))
	var time_before := float(character.get_debug_state().get("slide_time_left", 0.0))
	Input.action_press("jump")
	await _frames(1)
	_expect(character.get_posture() == 1 and character.is_on_floor() and character.velocity.y <= 0.05 and _flag("slide_active"), "onvoldoende staande hoofdruimte weigert slide-sprong zonder clippen of het onderbreken van de slide")
	_expect(float(character.get_debug_state().get("jump_buffer_remaining", 1.0)) <= 0.001 and float(character.get_debug_state().get("fatigue", 0.0)) <= fatigue_before + 0.001 and float(character.get_debug_state().get("slide_time_left", 1.0)) < time_before, "geweigerde slide-sprong bewaart de aflopende skill en maakt geen ticketkosten of buffer")
	roof.queue_free()
	await _frames(9)
	_expect(_flag("slide_active") and character.get_posture() == 1 and character.is_on_floor(), "vrijgekomen hoofdruimte herhaalt een geblokkeerde held-spatie niet alsnog stil")
	Input.action_release("jump")
	await _frames(1)
	Input.action_press("jump")
	await _frames(1)
	_expect(character.get_posture() == 0 and not character.is_on_floor() and character.velocity.y > 1.0 and not _flag("slide_active"), "na een geweigerde poging kan alleen een nieuwe veilige druk de slide werkelijk onderbreken")
	Input.action_release("jump")


func _test_repeated_slide_jumps() -> void:
	await _launch_sprint()
	character.jump_fatigue_enabled = false
	await _pulse("crouch")
	await _wait_for_landing()
	var first_speed := _speed()
	var launches: Array[float] = []
	var budgets_kept := true
	for i in 12:
		await _frames(3)
		var before := _speed()
		Input.action_press("jump")
		await _frames(1)
		Input.action_release("jump")
		if character.is_on_floor() or character.velocity.y <= 1.0:
			break
		launches.append(_speed())
		budgets_kept = budgets_kept and _speed() <= before + 0.03 and float(character.get_debug_state().get("air_speed_cap", 0.0)) <= before + 0.03 and absf(float(character.get_debug_state().get("jump_boost", -1.0))) < 0.001
		if i < 11:
			await _frames(8)
			await _pulse("crouch")
			await _wait_for_landing()
			if not _flag("slide_active"):
				break
	_expect(launches.size() == 12 and budgets_kept, "twaalf echte slide-sprong-slidecycli behouden ieder hun actuele budget zonder nieuwe bonus, ook met fatigue uit")
	_expect(not launches.is_empty() and launches.max() <= first_speed + 0.03, "herhaald slide-springen stapelt nooit boven de oorspronkelijke sprintafzet")
	print("MEASURE: twelve slide jump launches %s; individual budgets %s" % [str(launches), budgets_kept])
	character.jump_fatigue_enabled = true


func _active_slide() -> void:
	await _launch_sprint()
	await _pulse("crouch")
	await _wait_for_landing()
	await _frames(6)
	_expect(_flag("slide_active") and character.get_posture() == 1 and character.is_on_floor(), "slide-sprongproef begint met een werkelijk actieve, ondersteunde kruipslide")


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
	_expect(character.get_posture() == 0 and character.is_on_floor() and character.velocity.y <= 0.05, "staan-Z-spatie keert direct terug naar staan zonder tussentijdse kruip of sprong")
	_expect(float(character.get_debug_state().get("jump_buffer_remaining", 1.0)) <= 0.001, "vasthouden van directe oprichtspatie voert geen sprong of buffer uit")
	await _frames(20)
	_expect(character.is_on_floor(), "opricht-input wordt geen gebufferde sprong na het staan")
	Input.action_press("jump")
	await _frames(2)
	_expect(not character.is_on_floor() and character.velocity.y > 1.0, "pas een nieuwe spatie vanuit staan start werkelijk een sprong")
	Input.action_release("jump")
	await _reset()
	await _pulse("crouch")
	await _pulse("prone")
	await _pulse("jump")
	_expect(character.get_posture() == 1 and character.is_on_floor() and str(character.get_debug_state().get("manual_posture", "")) == "kruipen", "handmatige kruip-Z-spatie keert terug naar de vorige kruipvoorkeur zonder sprong")
	await _frames(20)
	_expect(character.get_posture() == 1 and character.velocity.y <= 0.05, "de onthouden kruipvoorkeur blijft na de handmatige lig-terugkeer bewaard")
	await _reset()
	await _pulse("prone")
	await _pulse("prone")
	await _pulse("jump")
	_expect(character.get_posture() == 0 and character.is_on_floor(), "herhaalde Z overschrijft de vorige staande voorkeur niet")
	await _reset()
	await _pulse("prone")
	var roof := _add_box(Vector3(0, 1.5, 0), Vector3(4, 0.2, 4))
	await _frames(2)
	Input.action_press("jump")
	await _frames(1)
	_expect(character.get_posture() == 2 and character.is_on_floor(), "geblokkeerde directe lig-naar-staan-terugkeer blijft lig, ook als kruip wel zou passen")
	await _frames(15)
	_expect(character.get_posture() == 2 and character.velocity.y <= 0.05 and float(character.get_debug_state().get("jump_buffer_remaining", 1.0)) <= 0.001, "geblokkeerde lig-terugkeer geeft geen fallback, sprong, buffer of houdingflikkering")
	roof.queue_free()
	await _frames(9)
	_expect(character.get_posture() == 2 and character.is_on_floor(), "vrijgekomen hoofdruimte voert geweigerde held-oprichtinput niet stil alsnog uit")
	Input.action_release("jump")
	await _frames(1)
	await _pulse("jump")
	_expect(character.get_posture() == 0 and character.is_on_floor(), "na vrije hoofdruimte kan een nieuwe oprichtdruk veilig staan")


func _test_automatic_posture_policy() -> void:
	await _reset()
	var roof := _add_box(Vector3(0, 0.9, -3), Vector3(4, 0.2, 4))
	await _frames(2)
	Input.action_press("move_forward")
	var transitions: Array[int] = [character.get_posture()]
	var adjacent := true
	var unexpected_slide := false
	for i in 430:
		await _frames(1)
		unexpected_slide = unexpected_slide or _flag("slide_pending") or _flag("slide_active")
		if transitions[-1] != character.get_posture():
			adjacent = adjacent and absi(transitions[-1] - character.get_posture()) == 1
			transitions.append(character.get_posture())
		if character.position.z < -6.1 and character.get_posture() == 0:
			break
	_expect(transitions.has(1) and transitions.has(2) and adjacent and character.position.z < -6.1, "automatisch staan bereikt een ligingang via een werkelijk gemeten kruipframe, nooit rechtstreeks staan naar lig")
	_expect(character.get_posture() == 0 and str(character.get_debug_state().get("manual_posture", "")) == "staan", "na een automatische ligingang herstelt de hoogste veilige houding zonder handmatige voorkeur te wijzigen")
	_expect(not unexpected_slide, "automatisch kruip en lig voorbereiden of starten geen slide")
	print("MEASURE: auto direct low passage postures %s; adjacent %s; z %.3f" % [str(transitions), adjacent, character.position.z])
	_release_inputs()
	roof.queue_free()
	await _frames(3)
	for choose_manual_crouch in [false, true]:
		await _reset()
		var crouch_roof := _add_box(Vector3(0, 1.3, -3), Vector3(4, 0.2, 4))
		roof = _add_box(Vector3(0, 0.9, -6), Vector3(4, 0.2, 2))
		await _frames(2)
		Input.action_press("move_forward")
		for i in 100:
			await _frames(1)
			if character.get_posture() == 1 and character.position.z < -1.5:
				break
		_expect(character.get_posture() == 1 and str(character.get_debug_state().get("manual_posture", "")) == "staan", "eerste 1.20m doorgang kiest automatisch kruip en bewaart staan als voorkeur")
		if choose_manual_crouch:
			await _pulse("crouch")
			_expect(str(character.get_debug_state().get("manual_posture", "")) == "kruipen", "Ctrl tijdens automatisch kruip kiest permanent kruip zonder een slide te geven")
		transitions = [character.get_posture()]
		adjacent = true
		unexpected_slide = false
		var restored := false
		for i in 500:
			await _frames(1)
			unexpected_slide = unexpected_slide or _flag("slide_pending") or _flag("slide_active")
			if transitions[-1] != character.get_posture():
				adjacent = adjacent and absi(transitions[-1] - character.get_posture()) == 1
				transitions.append(character.get_posture())
			if character.position.z < -8.1 and character.get_posture() == (1 if choose_manual_crouch else 0):
				restored = true
				break
		_expect(transitions.has(2) and adjacent and restored, "getrapte kruip-naar-ligdoorgang passeert en herstelt %s via veilige tussenhoudingen" % ("handmatige kruip" if choose_manual_crouch else "automatisch staan"))
		_expect(str(character.get_debug_state().get("manual_posture", "")) == ("kruipen" if choose_manual_crouch else "staan") and not unexpected_slide, "lage route bewaart de gekozen voorkeur zonder slide-skill")
		print("MEASURE: stepped low route manualC %s; postures %s; z %.3f; restored %s" % [choose_manual_crouch, str(transitions), character.position.z, restored])
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
		_expect(not transitions.has(2), "een ruime kruipingang gebruikt ook schuin geen onnodige lighouding")
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
