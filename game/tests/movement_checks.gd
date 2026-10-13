extends SceneTree
## Meet herhaalde sprongen, nieuwe houdingen en afzonderlijke hoofd-/lichaamsrichting.

const CHARACTER = preload("res://characters/Character.tscn")
const AUDIO_SHUTDOWN = preload("res://tests/test_audio_shutdown.gd")
const ACTIONS = ["move_forward", "move_back", "move_left", "move_right", "sprint", "sneak", "crouch", "prone", "jump"]
var failures: Array[String] = []
var world: Node3D
var character: AtlasCharacter


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	_add_box(Vector3(0, -0.1, 0), Vector3(300, 0.2, 300))
	character = CHARACTER.instantiate() as AtlasCharacter
	character.position = Vector3(0, 0.05, 0)
	world.add_child(character)
	character.set_controlled(true)
	await _frames(8)
	await _test_sneak_and_postures()
	await _test_repeat_jumps()
	await _test_jump_input()
	await _test_low_passages()
	await _test_head_and_turning()
	await _test_camera()
	_release_inputs()
	world.queue_free()
	await process_frame
	await _test_main_arena()
	await AUDIO_SHUTDOWN.drain(self)
	if failures.is_empty():
		print("PASS: movement-, houdings-, sprongherhaal- en hoofd/cameraregressies geslaagd.")
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: ", failure)
		quit(1)


func _test_sneak_and_postures() -> void:
	await _reset()
	Input.action_press("move_forward")
	Input.action_press("sprint")
	Input.action_press("sneak")
	await _frames(80)
	_expect(absf(_speed() - character.sneak_forward_speed) < 0.06, "Alt-sneak heeft voorrang op sprint")
	_expect(character.get_posture() == 0, "sneak verandert de staande capsule niet")
	await _reset()
	Input.action_press("crouch")
	await _frames(2)
	Input.action_release("crouch")
	await _frames(5)
	_expect(character.get_posture() == 1, "C kiest kruip en bewaart die na loslaten")
	Input.action_press("move_forward")
	await _frames(100)
	_expect(absf(_speed() - character.crouch_forward_speed) < 0.06, "kruip gebruikt eigen bewegingssnelheid")
	_release_inputs()
	Input.action_press("prone")
	await _frames(2)
	Input.action_release("prone")
	await _frames(5)
	_expect(character.get_posture() == 2, "Z gaat vanuit kruip naar lig")
	Input.action_press("move_forward")
	await _frames(100)
	_expect(absf(_speed() - character.prone_forward_speed) < 0.06, "lig gebruikt eigen bewegingssnelheid")
	_release_inputs()
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	_expect(character.is_on_floor() and character.get_posture() == 1, "spatie richt lig één houding op zonder sprong")
	await _reset()
	Input.action_press("prone")
	await _frames(2)
	Input.action_release("prone")
	await _frames(5)
	_expect(character.get_posture() == 2, "Z kiest handmatig rechtstreeks lig vanuit staan")
	await _reset()
	Input.action_press("sneak")
	var sneak_jump: Dictionary = await _jump_once()
	_expect(sneak_jump.height >= character.sneak_min_jump_height - 0.06 and sneak_jump.height < 0.65, "sneak-sprong blijft laag en boven de ingestelde minimumhoogte")


func _test_repeat_jumps() -> void:
	for direction_actions in [["move_forward"], ["move_right"], ["move_back"], ["move_forward", "move_right"]]:
		await _reset()
		character.jump_fatigue_enabled = false
		for action in direction_actions:
			Input.action_press(action)
		Input.action_press("sprint")
		await _frames(100)
		var launches: Array[float] = []
		for jump_index in 12:
			var jump: Dictionary = await _jump_once()
			launches.append(jump.launch)
		_expect(launches.max() <= launches[0] + 0.08, "twaalf directe sprongen stapelen niet, ook zonder vermoeidheid: %s" % str(direction_actions))
		print("MEASURE: repeated no-fatigue %s %s" % [str(direction_actions), str(launches)])
	await _reset()
	character.jump_fatigue_enabled = true
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(100)
	var first: Dictionary = await _jump_once()
	var second: Dictionary = await _jump_once()
	var third: Dictionary = await _jump_once()
	_expect(first.height > second.height and second.height > third.height, "opeenvolgende sprintsprongen worden lager")
	_expect(first.launch > second.launch and second.launch > third.launch, "opeenvolgende sprintsprongen verliezen extra sprintbonus")
	print("MEASURE: fatigue heights %.3f / %.3f / %.3f; launch %.3f / %.3f / %.3f" % [first.height, second.height, third.height, first.launch, second.launch, third.launch])
	_release_inputs()
	var before := float(character.get_debug_state().get("fatigue", 0.0))
	Input.action_press("sneak")
	await _frames(1)
	_expect(float(character.get_debug_state().get("fatigue", 0.0)) >= before - 0.04, "wisselen naar sneak wist sprintvermoeidheid niet")
	await _frames(80)
	_expect(float(character.get_debug_state().get("fatigue", 1.0)) < 0.01, "voldoende grondrust herstelt volle sprongkracht")
	_release_inputs()
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(100)
	var restored: Dictionary = await _jump_once()
	_expect(absf(restored.height - first.height) < 0.06 and absf(restored.launch - first.launch) < 0.08, "na grondherstel komt dezelfde volle sprong terug")


func _test_jump_input() -> void:
	await _reset()
	character.jump_fatigue_enabled = true
	Input.action_press("jump")
	await _frames(2)
	var fatigue_in_air := float(character.get_debug_state().get("fatigue", 0.0))
	await _frames(20)
	_expect(absf(float(character.get_debug_state().get("fatigue", 0.0)) - fatigue_in_air) < 0.001, "sprongvermoeidheid herstelt niet tijdens vliegen")
	await _frames(150)
	_expect(character.is_on_floor(), "vasthouden van spatie veroorzaakt geen automatische volgende sprong")
	Input.action_release("jump")
	await _reset()
	Input.action_press("jump")
	await _frames(1)
	Input.action_release("jump")
	await _frames(1)
	var first_velocity := character.velocity.y
	var first_fatigue := float(character.get_debug_state().get("fatigue", 0.0))
	Input.action_press("jump")
	await _frames(1)
	Input.action_release("jump")
	_expect(character.velocity.y < first_velocity and absf(float(character.get_debug_state().get("fatigue", 0.0)) - first_fatigue) < 0.001, "tweede druk binnen coyotetijd geeft geen dubbele luchtjump")
	await _reset()
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	var buffered := false
	var relaunched := false
	for i in 160:
		await _frames(1)
		if not buffered and character.velocity.y < 0.0 and character.position.y < 0.25:
			Input.action_press("jump")
			buffered = true
		elif buffered and character.velocity.y > 1.0:
			relaunched = true
			break
	_expect(buffered and relaunched, "vroege nieuwe druk wordt eenmaal bij landing uitgevoerd")
	Input.action_release("jump")
	var ledge := _add_box(Vector3(30, 2.9, 0), Vector3(4, 0.2, 4))
	for delay_frames in [2, 10]:
		await _reset()
		character.position = Vector3(30, 3.05, 0)
		character.velocity = Vector3.ZERO
		await _frames(8)
		Input.action_press("move_forward")
		var left_ledge := false
		for i in 100:
			await _frames(1)
			if not character.is_on_floor():
				left_ledge = true
				break
		await _frames(delay_frames)
		Input.action_press("jump")
		await _frames(1)
		Input.action_release("jump")
		if delay_frames == 2:
			_expect(left_ledge and character.velocity.y > 1.0, "kort na een echte rand blijft de coyote-sprong geldig")
		else:
			_expect(left_ledge and character.velocity.y < 0.0, "na verlopen coyotetijd start geen luchtjump")
	ledge.queue_free()
	await _frames(2)


func _test_low_passages() -> void:
	await _reset()
	var step := _add_box(Vector3(0, 0.15, -3), Vector3(3, 0.3, 4))
	var ceiling := _add_box(Vector3(0, 1.60, -3), Vector3(3, 0.2, 4))
	Input.action_press("move_forward")
	var saw_crouch := false
	var saw_prone := false
	for i in 400:
		await _frames(1)
		saw_crouch = saw_crouch or character.get_posture() == 1
		saw_prone = saw_prone or character.get_posture() == 2
	_expect(saw_crouch and not saw_prone and character.position.z < -5.6, "geldige .30m trede met 1.20m hoofdruimte wordt automatisch kruipend gepasseerd")
	_release_inputs()
	await _frames(20)
	_expect(character.get_posture() == 0, "automatisch kruipen herstelt na vrije uitgang naar staan")
	step.queue_free()
	ceiling.queue_free()
	await _frames(2)
	await _reset()
	var low_roof := _add_box(Vector3(0, 0.9, -3), Vector3(3, 0.2, 4))
	Input.action_press("move_forward")
	var previous_posture := character.get_posture()
	var adjacent := true
	saw_crouch = false
	saw_prone = false
	for i in 400:
		await _frames(1)
		var current := character.get_posture()
		adjacent = adjacent and absi(current - previous_posture) <= 1
		previous_posture = current
		saw_crouch = saw_crouch or current == 1
		saw_prone = saw_prone or current == 2
	_expect(saw_crouch and saw_prone and adjacent and character.position.z < -5.9, "staande voorkeur passeert een ligingang automatisch via een echte kruiptussenhouding")
	_expect(character.get_posture() == 0 and str(character.get_debug_state().get("manual_posture", "")) == "staan", "automatische ligingang herstelt de hoogste veilige staande voorkeur")
	await _reset()
	character.request_posture(1)
	await _frames(3)
	Input.action_press("move_forward")
	previous_posture = character.get_posture()
	adjacent = true
	saw_crouch = true
	saw_prone = false
	for i in 500:
		await _frames(1)
		var current := character.get_posture()
		adjacent = adjacent and absi(current - previous_posture) <= 1
		previous_posture = current
		saw_crouch = saw_crouch or current == 1
		saw_prone = saw_prone or current == 2
	_expect(saw_crouch and saw_prone and adjacent and character.position.z < -5.9, "handmatige kruip staat automatische lig toe bij lage ingang")
	_release_inputs()
	low_roof.queue_free()
	await _frames(20)
	_expect(character.get_posture() == 1, "automatisch lig herstelt naar de handmatig gekozen kruip")
	await _reset()
	character.request_posture(1)
	await _frames(5)
	await _frames(30)
	_expect(character.get_posture() == 1, "handmatige kruiphouding blijft op open grond behouden")
	character.request_posture(2)
	await _frames(5)
	await _frames(30)
	_expect(character.get_posture() == 2, "handmatige lighouding blijft op open grond behouden")
	await _reset()
	var too_low := _add_box(Vector3(0, 0.70, -3), Vector3(3, 0.2, 4))
	Input.action_press("move_forward")
	await _frames(240)
	_expect(character.position.z > -0.9, "doorgang lager dan elke capsulevorm blijft geblokkeerd")
	_release_inputs()
	too_low.queue_free()
	await _frames(2)


func _test_head_and_turning() -> void:
	await _reset()
	var rig = character.get_node("CameraPivot")
	rig.apply_look_delta(Vector2(-20, 0))
	var direct_angle := absf(float(character.get_debug_state().get("head_relative_yaw", 0.0)))
	await _reset()
	rig.apply_look_delta(Vector2(-600, 0))
	var soft_before := absf(float(character.get_debug_state().get("head_relative_yaw", 0.0)))
	rig.apply_look_delta(Vector2(-20, 0))
	var soft_delta := absf(float(character.get_debug_state().get("head_relative_yaw", 0.0))) - soft_before
	_expect(soft_delta > 0.0 and soft_delta < direct_angle * 0.9, "gelijke muisbeweging draait geleidelijk langzamer in de zachte hoofdzone")
	await _reset()
	rig.apply_look_delta(Vector2(-10000, 0))
	var state: Dictionary = character.get_debug_state()
	_expect(absf(float(state.get("head_relative_yaw", 0.0))) <= character.head_max_yaw + 0.01, "grote muisinput kan de hoofdgrens niet overschrijden")
	var head: Vector3 = state.get("head_direction", Vector3.FORWARD)
	var body: Vector3 = state.get("body_direction", Vector3.FORWARD)
	_expect(head.distance_to(body) > 0.2, "hoofdrichting en lichaamsrichting worden afzonderlijk bijgehouden")
	var head_before := rig.get_head_direction() as Vector3
	rig.apply_look_delta(Vector2(20, 0))
	_expect(head_before.distance_to(rig.get_head_direction()) > 0.01, "terugdraaien reageert direct bij de hoofdgrens")
	var start_yaw := character.rotation.y
	await _frames(1)
	_expect(absf(wrapf(character.rotation.y - start_yaw, -PI, PI)) <= deg_to_rad(character.idle_turn_speed) / 60.0 + 0.002, "lichaam draait per physicsframe binnen zijn limiet bij")
	await _frames(40)
	_expect(absf(float(character.get_debug_state().get("head_relative_yaw", 999.0))) <= 46.0, "stilstaand lichaam haalt alleen de noodzakelijke hoofdhoek in")
	await _reset()
	var left := _add_box(Vector3(-0.55, 0.8, 0), Vector3(0.2, 1.6, 10))
	var right := _add_box(Vector3(0.55, 0.8, 0), Vector3(0.2, 1.6, 10))
	character.request_posture(1)
	await _frames(2)
	character.request_posture(2)
	await _frames(5)
	rig.apply_look_delta(Vector2(-10000, 0))
	await _frames(120)
	state = character.get_debug_state()
	_expect(absf(character.rotation.y) < deg_to_rad(40), "horizontale ligcapsule draait niet door de smalle tunnelwanden")
	_expect(absf(float(state.get("head_relative_yaw", 0.0))) <= character.head_max_yaw + 0.01, "hoofd en camera blijven begrensd wanneer lichaam niet kan draaien")
	left.queue_free()
	right.queue_free()
	await _frames(2)


func _test_camera() -> void:
	await _reset()
	var camera := character.get_node("CameraPivot/SpringArm3D/Camera3D") as Camera3D
	character.camera_speed_fov_enabled = false
	await _frames(60)
	_expect(absf(camera.fov - character.camera_fov_third_person) < 0.1, "FOV-uit houdt de gekozen third-personbasis")
	character.camera_speed_fov_enabled = true
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(100)
	_expect(camera.fov > character.camera_fov_third_person + 3.0 and camera.fov <= character.camera_fov_third_person + character.camera_sprint_fov_bonus + 0.1, "snelheids-FOV reageert begrensd op echte sprint")
	_release_inputs()
	await _frames(100)
	_expect(absf(camera.fov - character.camera_fov_third_person) < 0.2, "FOV keert na afremmen naar de basis terug")
	character.set_camera_distance(0.0)
	await _frames(60)
	_expect(bool(character.get_debug_state().get("first_person", false)) and absf(camera.fov - character.camera_fov_first_person) < 0.1, "first person gebruikt zijn eigen verticale basis-FOV")
	character.set_camera_distance(4.0)
	await _frames(60)
	character.request_posture(1)
	await _frames(2)
	character.request_posture(2)
	await _frames(30)
	var pivot := character.get_node("CameraPivot") as Node3D
	_expect(pivot.global_position.y - character.global_position.y < 0.71, "camerahoogte volgt de ligcapsule")


func _test_main_arena() -> void:
	for choose_manual_crouch in [false, true]:
		var main = load("res://scenes/main.tscn").instantiate()
		main.capture_mouse_on_start = false
		root.add_child(main)
		var actor = main.get_node("Characters/AtlasA")
		await _frames(8)
		actor.global_position = Vector3(-6, 0.05, -3.8)
		actor.velocity = Vector3.ZERO
		actor.reset_physics_interpolation()
		await _frames(8)
		Input.action_press("move_forward")
		var saw_crouch := false
		var saw_prone := false
		var adjacent := true
		var previous: int = actor.get_posture()
		var transitions: Array[int] = [previous]
		var chose_crouch := false
		var unexpected_slide := false
		for i in 850:
			await _frames(1)
			var current: int = actor.get_posture()
			if choose_manual_crouch and actor.global_position.z < -6.5 and not chose_crouch:
				actor.request_posture(1)
				chose_crouch = true
			adjacent = adjacent and absi(current - previous) <= 1
			if current != previous:
				transitions.append(current)
			previous = current
			saw_crouch = saw_crouch or current == 1
			saw_prone = saw_prone or current == 2
			var state: Dictionary = actor.get_debug_state()
			unexpected_slide = unexpected_slide or bool(state.get("slide_pending", false)) or bool(state.get("slide_active", false))
			if actor.global_position.z < -13.4 and current == (1 if choose_manual_crouch else 0):
				break
		Input.action_release("move_forward")
		await _frames(30)
		_expect(saw_crouch and saw_prone and adjacent and actor.global_position.z < -13.4 and actor.get_posture() == (1 if choose_manual_crouch else 0), "werkelijke arena: kruip-ligroute herstelt %s" % ("handmatige kruip" if choose_manual_crouch else "automatisch staan zonder handmatige injectie"))
		_expect(not unexpected_slide and str(actor.get_debug_state().get("manual_posture", "")) == ("kruipen" if choose_manual_crouch else "staan"), "arena-route bewaart de houdingvoorkeur en geeft geen slide")
		print("MEASURE: actual arena R1 manualC %s final %s; postures %s; adjacent %s" % [choose_manual_crouch, str(actor.global_position), str(transitions), adjacent])
		main.queue_free()
		await process_frame


func _jump_once() -> Dictionary:
	var start := character.position
	Input.action_press("jump")
	await _frames(1)
	Input.action_release("jump")
	var launch := _speed()
	var apex := character.position.y
	var airborne := not character.is_on_floor()
	for i in 240:
		await _frames(1)
		apex = maxf(apex, character.position.y)
		airborne = airborne or not character.is_on_floor()
		if airborne and character.is_on_floor():
			break
	_expect(airborne and character.is_on_floor(), "sprong wordt uitgevoerd en landt")
	return {"height": apex - start.y, "launch": launch}


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
