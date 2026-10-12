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
	await _test_air_precision_stop()
	await _test_explicit_posture_controls()
	await _test_automatic_posture_policy()
	await _test_oblique_step_and_chatter()
	await _test_idle_body_and_air_steering()
	_release_inputs()
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: feedbackregressies voor sprongafstand, precisierem, houdingknoppen, schuine doorgang en lichaamsdraai.")
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


func _test_air_precision_stop() -> void:
	for action in ["crouch", "prone"]:
		await _reset()
		Input.action_press("move_forward")
		Input.action_press("sprint")
		await _frames(100)
		Input.action_press("jump")
		await _frames(1)
		Input.action_release("jump")
		await _frames(8)
		var speed_before := _speed()
		var vertical_before := character.velocity.y
		var fatigue_before := float(character.get_debug_state().get("fatigue", 0.0))
		Input.action_press(action)
		await _frames(1)
		Input.action_release(action)
		var speed_after := _speed()
		print("MEASURE: airborne %s speed %.3f -> %.3f; vertical %.3f -> %.3f" % [action, speed_before, speed_after, vertical_before, character.velocity.y])
		_expect(not character.is_on_floor() and speed_before > character.walk_forward_speed, "%s wordt tijdens een echte sprintsprong gemeten" % action)
		_expect(speed_after <= 0.2, "%s remt sprintvlucht binnen één physicsframe abrupt horizontaal" % action)
		_expect(absf(character.velocity.y - (vertical_before - character.gravity_strength * PHYSICS_DELTA)) < 0.04, "%s verandert de verticale sprong niet behalve normale zwaartekracht" % action)
		_expect(absf(float(character.get_debug_state().get("fatigue", 0.0)) - fatigue_before) < 0.001, "%s reset sprongvermoeidheid niet tijdens de precisierem" % action)
		_expect(character.get_posture() == (1 if action == "crouch" else 2), "%s kiest rechtstreeks de bedoelde handmatige houding" % action)
		_release_inputs()
		await _frames(2)
		_expect(_speed() <= 0.2, "%s krijgt zonder nieuwe stuurinput geen oude sprintbonus terug" % action)


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
		for i in 260:
			await _frames(1)
			greatest_height = maxf(greatest_height, character.position.y)
			if transitions[-1] != character.get_posture():
				transitions.append(character.get_posture())
			if character.position.z < -1.8 and absf(character.position.x) < 1.2 and character.position.y > 0.28:
				entered = true
				break
		print("MEASURE: oblique x %.2f yaw %.1f reached %s at %s; maxY %.3f; postures %s" % [fixture.x, fixture.yaw, entered, str(character.position), greatest_height, str(transitions)])
		_expect(entered and greatest_height > 0.28, "geldige .30m opstap met 1.20m hoofdruimte passeert bij x %.2f / yaw %.1f" % [fixture.x, fixture.yaw])
		_expect(not transitions.has(2), "staan kiest ook schuin geen automatische lighouding")
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
