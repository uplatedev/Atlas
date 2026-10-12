extends SceneTree
## Camera-overdracht: echte controllertrajecten en view-eigenaarschap, zonder
## verwachte uitkomsten uit de nieuwe implementatie te berekenen.
## Optioneel: --record=<absoluut.json> en --compare=<baseline.json> na --.

const CHARACTER = preload("res://characters/Character.tscn")
const AUDIO_SHUTDOWN = preload("res://tests/test_audio_shutdown.gd")
const NEW_CAMERA_FIELDS = ["camera_landing_enabled", "camera_landing_max_dip", "camera_first_person_landing_max_dip", "camera_landing_min_speed", "camera_landing_full_speed", "camera_landing_attack_time", "camera_landing_recovery_time", "camera_accent_max_offset", "camera_fov_refinement_enabled", "camera_slide_fov_bonus", "camera_first_person_slide_fov_bonus", "camera_slide_fov_reference_speed"]
const ACTIONS = ["move_forward", "move_back", "move_left", "move_right", "sprint", "sneak", "crouch", "prone", "jump"]
var failures: Array[String] = []
var trace: Dictionary = {}
var world: Node3D
var actor: AtlasCharacter
var floor_body: StaticBody3D
var compared_values := 0
var largest_delta := 0.0
var largest_delta_path := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	floor_body = _box(Vector3(0, -0.1, 0), Vector3(400, 0.2, 400))
	actor = CHARACTER.instantiate() as AtlasCharacter
	_legacy_camera(actor)
	actor.position = Vector3(0, 0.05, 0)
	world.add_child(actor)
	actor.set_controlled(true)
	await _frames(8)
	await _test_instances_and_zoom()
	if "--require-separation" in OS.get_cmdline_user_args():
		await _test_data_boundary()
		await _test_view_reset_history()
	await _test_head_render_and_logical_input()
	await _test_motion_and_fov()
	await _test_fall_memory()
	await _test_posture_route()
	await _test_render_rates()
	_release_inputs()
	world.queue_free()
	await process_frame
	await _test_main_controls()
	_handle_trace()
	await AUDIO_SHUTDOWN.drain(self)
	if failures.is_empty():
		print("PASS: camera-overdracht, FOV-/bewegingspariteit, kijkrichting, eigen zicht en instancebediening.")
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: ", failure)
		quit(1)


func _test_instances_and_zoom() -> void:
	var exports: Dictionary = {}
	for property in actor.get_property_list():
		var name := String(property.name)
		if name not in NEW_CAMERA_FIELDS and int(property.usage) & PROPERTY_USAGE_EDITOR and (name.begins_with("camera_") or name.begins_with("look_sensitivity") or name.begins_with("head_") or name in ["first_person_threshold", "crouch_eye_height", "prone_eye_height"]):
			exports[name] = {"type": int(property.type), "hint": String(property.hint_string), "value": actor.get(name)}
	trace["root_camera_exports"] = exports
	var other: AtlasCharacter = CHARACTER.instantiate()
	_legacy_camera(other)
	other.position = Vector3(8, 0.05, 0)
	other.camera_start_distance = 6.0
	other.camera_fov_third_person = 72.0
	other.camera_zoom_step = 0.25
	# Publieke vroege aanroep was veilig; ready blijft de startoverride gebruiken.
	other.set_camera_distance(0.0)
	world.add_child(other)
	await _frames(8)
	var other_rig: Node3D = other.get_node("CameraPivot")
	_expect(absf(float(other_rig.call("get_state").camera_distance) - 6.0) < 0.001, "component-ready gebruikt de eigen rootoverride voor startzoom")
	_expect(absf(_camera(other).fov - 72.0) < 0.05, "component-ready gebruikt eigen rootoverride voor FOV")
	actor.set_camera_distance(0.0)
	await _frames(60)
	var own_layer := actor.get_node("Presentation/Capsule").layers as int
	var other_layer := other.get_node("Presentation/Capsule").layers as int
	_expect(own_layer != other_layer, "presentatielagen zijn per Character verschillend")
	_expect((_camera(actor).cull_mask & own_layer) == 0 and (_camera(actor).cull_mask & other_layer) != 0, "first-personview verbergt alleen eigen presentatielaag")
	_expect(actor.get_node("Presentation/Capsule").visible and other.get_node("Presentation/Capsule").visible, "eigen zicht wijzigt geen globale zichtbaarheid van de Characters")
	_expect(absf(_camera(actor).fov - 75.0) < 0.08, "first person bewaart zijn bestaande verticale basis-FOV")
	actor.set_camera_distance(100.0)
	await _frames(60)
	_expect(absf(float(_rig().call("get_state").camera_distance) - 8.0) < 0.001, "rootzoom delegeert naar dezelfde maximale rigafstand")
	actor.set_camera_distance(4.0)
	await _frames(60)
	_scroll(MOUSE_BUTTON_WHEEL_UP)
	await _frames(1)
	_expect(absf(float(_rig().call("get_state").camera_distance) - 3.5) < 0.001, "scroll verandert gewenste zoom van actieve view")
	_expect(absf(float(other_rig.call("get_state").camera_distance) - 6.0) < 0.001, "scroll verandert de andere instance niet")
	actor.set_controlled(false)
	other.set_controlled(true)
	_scroll(MOUSE_BUTTON_WHEEL_UP)
	await _frames(1)
	_expect(absf(float(other_rig.call("get_state").camera_distance) - 5.75) < 0.001, "controlewisseling gebruikt de andere eigen zoomstap")
	other.set_controlled(false)
	actor.set_controlled(true)
	_expect(absf(float(_rig().call("get_state").camera_distance) - 3.5) < 0.001, "controlewisseling bewaart de eigen zoom")
	actor.request_posture(2)
	actor.set_camera_distance(0.8)
	await _frames(60)
	_expect((_camera(actor).cull_mask & own_layer) == 0, "dicht bij ligvorm gebruikt viewmask de fysieke horizontale lengte")
	actor.reset_to_spawn()
	await _frames(20)
	_expect(absf(float(_rig().call("get_state").camera_distance) - 4.0) < 0.001 and actor.get_posture() == 0, "reset herstelt zoom en fysieke houding")
	_expect((_camera(actor).cull_mask & own_layer) != 0, "third-personview na reset toont eigen presentatielaag weer")
	other.queue_free()
	await _frames(2)


func _test_head_render_and_logical_input() -> void:
	await _reset()
	actor.set_physics_process(false)
	_rig().call("apply_look_delta", Vector2(-200, 45))
	await process_frame
	var state: Dictionary = _rig().call("get_state")
	var arrow: Node3D = actor.get_node("DebugArrows/HeadArrow")
	var direction: Vector3 = state.head_direction
	_expect((-arrow.global_basis.z).distance_to(direction) < 0.0001, "hoofdpijl volgt renderinput ook zonder een physics-tick")
	_expect(arrow.global_position.distance_to(actor.get_global_transform_interpolated().origin + Vector3.UP * actor.camera_eye_height) < 0.005, "hoofdpijl gebruikt dezelfde renderpositie en ooghoogte")
	_expect(absf(actor.global_rotation.y) < 0.001, "renderinput schrijft de fysieke lichaamsyaw niet")
	trace["direct_look"] = _snapshot()
	_rig().call("apply_look_delta", Vector2(-10000, -10000))
	state = _rig().call("get_state")
	_expect(absf(float(state.head_relative_yaw)) <= 85.001 and float(state.head_pitch) <= 70.001, "grote kijkinput blijft binnen bestaande hoofd- en pitchgrens")
	var before := float(state.head_relative_yaw)
	_rig().call("apply_look_delta", Vector2(20, 0))
	_expect(float(_rig().call("get_state").head_relative_yaw) < before - 2.0, "omkeren aan hoofdgrens reageert direct")
	trace["head_bounds"] = _snapshot()
	actor.set_physics_process(true)
	await _reset()
	var twin: AtlasCharacter = CHARACTER.instantiate()
	_legacy_camera(twin)
	twin.position = Vector3(20, 0.05, 0)
	world.add_child(twin)
	twin.set_controlled(true)
	await _frames(8)
	for body in [actor, twin]:
		body.get_node("CameraPivot").call("apply_look_delta", Vector2(-200, 0))
		body.get_node("CameraPivot").set_process(false)
	# Een decoratieve viewtransform mag nooit logische input voor body/air worden.
	_camera(twin).rotation.y += 0.7
	_camera(twin).position.x += 0.2
	Input.action_press("move_forward")
	await _frames(12)
	_expect(absf(wrapf(actor.global_rotation.y - twin.global_rotation.y, -PI, PI)) < 0.0001, "lichaamsdraai is onafhankelijk van decoratieve cameratransform")
	Input.action_press("jump")
	await _frames(1)
	Input.action_release("jump")
	Input.action_release("move_forward")
	Input.action_press("move_right")
	await _frames(6)
	_expect(actor.velocity.distance_to(twin.velocity) < 0.0001, "luchtsturing gebruikt logische yaw en geen decoratieve cameratransform")
	trace["logical_air"] = _snapshot()
	_rig().set_process(true)
	twin.queue_free()
	await _frames(2)


func _test_motion_and_fov() -> void:
	for mode in ["walk_partial", "sprint_partial", "sprint_mid", "sprint_full", "sneak"]:
		await _reset()
		actor.jump_fatigue_enabled = false
		Input.action_press("move_forward")
		if mode.begins_with("sprint"):
			Input.action_press("sprint")
		if mode == "sneak":
			Input.action_press("sneak")
		var run_frames := 100 if mode in ["sprint_full", "sneak"] else (16 if mode == "sprint_mid" else 6)
		var curve: Array = []
		for frame in run_frames:
			await _frames(1)
			if frame < 18 or frame % 10 == 9:
				curve.append(_snapshot())
		var prelaunch := _horizontal_speed()
		var pre_target := float(_rig().call("get_state").camera_target_fov)
		Input.action_press("jump")
		await _frames(1)
		Input.action_release("jump")
		var launch: Dictionary = _snapshot()
		var launch_target := float(_rig().call("get_state").camera_target_fov)
		if mode == "sprint_mid":
			_expect(prelaunch > 5.0 and prelaunch < 9.0 and _horizontal_speed() > prelaunch, "tussensprint bewijst een echte bonus boven gedeeltelijke aanloop")
			_expect(absf(launch_target - pre_target) < 0.7, "sprongbonus wordt geen extra FOV-bonus boven afzetvaart")
		if mode in ["walk_partial", "sprint_partial"]:
			_expect(launch_target < 70.1 and _horizontal_speed() < 5.0, "korte aanloop krijgt geen volle sprint-FOV of vluchtvaart")
		if mode == "sneak":
			_expect(absf(launch_target - 68.0) < 0.001, "sneak-afzet gebruikt eigen FOV en geen sprintmix")
		var air: Array = []
		for frame in 10:
			await _frames(1)
			air.append(_snapshot())
		if mode == "sprint_full":
			var speed_before := _horizontal_speed()
			Input.action_release("move_forward")
			Input.action_press("move_back")
			await _frames(6)
			_expect(_horizontal_speed() < speed_before - 0.5 and _horizontal_speed() > 0.0, "S bouwt vluchtvaart geleidelijk af")
			_expect(absf(float(_rig().call("get_state").camera_target_fov) - launch_target) < 0.001, "bestaande lucht-FOV bewaart afzetgeheugen tijdens S-rem")
			air.append(_snapshot())
		trace[mode] = {"ground_curve": curve, "launch": launch, "air_curve": air}
	# Gewone sprintrem: echte snelheid en renderreactie worden samen vergeleken.
	await _reset()
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(100)
	_release_inputs()
	var brake_curve: Array = []
	for frame in 45:
		await _frames(1)
		brake_curve.append(_snapshot())
	trace["ground_brake"] = brake_curve


func _test_fall_memory() -> void:
	await _reset()
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(16)
	floor_body.queue_free()
	await _frames(2)
	var before := float(_rig().call("get_state").camera_target_fov)
	await _frames(4)
	_expect(not actor.is_on_floor() and actor.velocity.y < 0.0, "edgefallfixture is een echte val zonder jump")
	_expect(absf(float(_rig().call("get_state").camera_target_fov) - before) < 0.001, "edgefall bewaart de laatste ondersteunde snelheidsmix")
	trace["edge_fall"] = _snapshot()
	floor_body = _box(Vector3(0, -0.1, 0), Vector3(400, 0.2, 400))
	await _reset()


func _test_data_boundary() -> void:
	await _reset()
	_expect(actor.has_method("get_camera_motion_sample"), "controller levert een expliciet camera-datacontract")
	_expect(not actor.has_method("get_fov_speed_mix"), "controller bezit geen camera-specifieke FOV-mix meer")
	if not actor.has_method("get_camera_motion_sample"):
		return
	actor.request_posture(2)
	actor.set_camera_distance(0.8)
	await _frames(60)
	var shape_node: CollisionShape3D = actor.get_node("CollisionShape3D")
	var sample: Variant = actor.call("get_camera_motion_sample")
	_expect(sample.get("body_shape") == shape_node.shape and sample.get("body_shape_transform") == shape_node.global_transform, "motiondata levert de echte unieke fysieke ligvorm en wereldtransform")
	_expect(sample.get("excluded_body") == actor.get_rid(), "viewquery krijgt het eigen uit te sluiten physicslichaam als data")
	shape_node.name = "VerplaatstFysiekOnderdeel"
	actor.get_node("DebugArrows").name = "VerplaatsteDebugPresentatie"
	await _frames(3)
	var layer := actor.get_node("Presentation/Capsule").layers as int
	_expect((_camera(actor).cull_mask & layer) == 0, "eigen ligzicht werkt zonder collider- of debugnodepad in CameraRig")
	shape_node.name = "CollisionShape3D"
	actor.get_node("VerplaatsteDebugPresentatie").name = "DebugArrows"
	await _reset()


func _test_view_reset_history() -> void:
	await _reset()
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(100)
	Input.action_press("jump")
	await _frames(1)
	Input.action_release("jump")
	_expect(not actor.is_on_floor() and absf(_horizontal_speed() - 10.5) < 0.01, "viewresetfixture is een echte volle sprintvlucht")
	_rig().call("reset_view")
	await _frames(1)
	_expect(absf(float(_rig().call("get_state").camera_target_fov) - 76.0) < 0.001, "alleen viewreset bewaart het afzetgeheugen en vlucht-FOV")
	_release_inputs()
	actor.reset_to_spawn()
	await _frames(1)
	_expect(absf(float(_rig().call("get_state").camera_target_fov) - 70.0) < 0.001, "volledige Character-reset wist het afzetgeheugen")
	await _reset()


func _test_posture_route() -> void:
	await _reset()
	var first := _box(Vector3(0, 1.3, -3), Vector3(4, 0.2, 4))
	var second := _box(Vector3(0, 0.9, -6), Vector3(4, 0.2, 2))
	Input.action_press("move_forward")
	var route: Array = []
	var visited: Array[int] = [0]
	for frame in 390:
		await _frames(1)
		var posture := actor.get_posture()
		if posture != visited[-1]:
			visited.append(posture)
			route.append(_snapshot())
		if frame % 30 == 29:
			route.append(_snapshot())
	_expect(visited == [0, 1, 2, 1, 0], "automatische route behoudt echte opeenvolgende houdingen en veilig herstel")
	trace["low_route"] = route
	first.queue_free()
	second.queue_free()
	await _frames(2)


func _test_render_rates() -> void:
	# Dezelfde opgelegde renderdoelbaan, zonder physics/inputverandering. Dit is
	# een controle op het camerasysteem, niet op een nagemaakte filterformule.
	var outputs: Dictionary = {}
	for rate in [30, 60, 144]:
		await _reset()
		actor.set_physics_process(false)
		_rig().set_process(false)
		actor.set_camera_distance(0.0)
		actor.set_camera_distance(4.0)
		_rig().call("reset_view")
		var samples: Array = []
		for frame in rate * 2:
			var time := float(frame + 1) / float(rate)
			# 1s constante sprint, daarna een stop: volging en remnawerking.
			actor.global_position.z = -9.0 * minf(time, 1.0)
			actor.velocity = Vector3(0, 0, -9.0) if time <= 1.0 else Vector3.ZERO
			actor.reset_physics_interpolation()
			_rig().call("_process", 1.0 / float(rate))
			if frame + 1 in [rate, rate * 3 / 2, rate * 2]:
				samples.append(_snapshot())
		outputs[str(rate)] = samples
		_expect(float(_rig().call("get_state").camera_follow_lag) <= actor.camera_follow_max_lag + 0.0001, "renderbaan op %d Hz blijft binnen absolute camerabegrenzing" % rate)
		actor.set_physics_process(true)
		_rig().set_process(true)
	trace["render_rates"] = outputs


func _test_main_controls() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	for body in main.get_node("Characters").get_children():
		_legacy_camera(body)
	main.set("capture_mouse_on_start", false)
	root.add_child(main)
	await _frames(8)
	var first: AtlasCharacter = main.get_node("Characters/AtlasA")
	var second: AtlasCharacter = main.get_node("Characters/AtlasB")
	first.set_camera_distance(2.0)
	second.set_camera_distance(6.0)
	_key(KEY_TAB)
	await _frames(1)
	_expect(not first.is_controlled() and second.is_controlled() and _camera(second).is_current(), "Tab draagt viewcontrole aan juiste Character over")
	_key(KEY_F4)
	await _frames(1)
	_expect(first.camera_speed_fov_enabled and not second.camera_speed_fov_enabled, "live F4 wijzigt alleen actieve rootinstelling")
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(100)
	_expect(absf(_camera(second).fov - second.camera_fov_third_person) < 0.1, "component leest live F4-instelling zonder herinitialisatie")
	_key(KEY_R)
	_release_inputs()
	await _frames(2)
	_expect(absf(float(first.get_debug_state().camera_distance) - first.camera_start_distance) < 0.001 and absf(float(second.get_debug_state().camera_distance) - second.camera_start_distance) < 0.001, "R reset beide camera-eigen zoomgeheugens")
	main.queue_free()
	await _frames(2)


func _snapshot() -> Dictionary:
	var state: Dictionary = actor.get_debug_state()
	var camera_state: Dictionary = _rig().call("get_state")
	var values := {"position": _vector(actor.global_position), "velocity": _vector(actor.velocity), "camera_offset": _vector(_rig().global_position - actor.get_global_transform_interpolated().origin)}
	for key in ["speed", "body_yaw", "posture_index", "launch_speed", "jump_boost", "air_speed_cap", "jump_height", "fatigue"]:
		values[key] = state.get(key)
	for key in ["camera_distance", "camera_actual_distance", "camera_fov", "camera_target_fov", "head_yaw", "head_pitch", "head_relative_yaw", "camera_follow_lag", "camera_inertia_amount"]:
		values[key] = camera_state.get(key)
	return values


func _handle_trace() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--record="):
			var path := argument.trim_prefix("--record=")
			var output := FileAccess.open(path, FileAccess.WRITE)
			if output == null:
				_expect(false, "tracebestand kan worden geschreven: " + path)
			else:
				output.store_string(JSON.stringify(trace, "\t", true, true))
				print("TRACE: ", path)
		elif argument.begins_with("--compare="):
			var path := argument.trim_prefix("--compare=")
			var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			_expect(expected is Dictionary, "baselinebestand bevat een trace: " + path)
			if expected is Dictionary:
				_compare(trace, expected, "trace")
				print("COMPARE: %d numerieke waarden; grootste afwijking %.8f (%s)." % [compared_values, largest_delta, largest_delta_path])


func _compare(actual: Variant, expected: Variant, path: String) -> void:
	if actual is Dictionary and expected is Dictionary:
		_expect(actual.size() == expected.size(), "pariteit sleutelset: " + path)
		for key in expected:
			if actual.has(key):
				_compare(actual[key], expected[key], path + "." + str(key))
			else:
				_expect(false, "pariteit ontbrekende sleutel: " + path + "." + str(key))
	elif actual is Array and expected is Array:
		_expect(actual.size() == expected.size(), "pariteit trajectlengte: " + path)
		for index in mini(actual.size(), expected.size()):
			_compare(actual[index], expected[index], path + "[%d]" % index)
	elif (actual is float or actual is int) and (expected is float or expected is int):
		var tolerance := 0.001
		if path.begins_with("trace.root_camera_exports"):
			tolerance = 0.00001
		elif ".head_" in path or ".body_yaw" in path or ".camera_fov" in path or ".camera_target_fov" in path:
			tolerance = 0.01
		elif ".position[" in path:
			tolerance = 0.0001
		var difference := absf(float(actual) - float(expected))
		compared_values += 1
		if difference > largest_delta:
			largest_delta = difference
			largest_delta_path = path
		_expect(difference <= tolerance, "pariteit %s: %.8f versus %.8f" % [path, float(actual), float(expected)])
	else:
		_expect(actual == expected, "pariteit waarde: " + path)


func _reset() -> void:
	_release_inputs()
	actor.reset_to_spawn()
	actor.camera_speed_fov_enabled = true
	actor.set_controlled(true)
	await _frames(10)


func _legacy_camera(body: Node) -> void:
	# Historische 69a8-trace blijft exact; de nieuwe varianten hebben hun eigen suite.
	for property in body.get_property_list():
		if String(property.name) in ["camera_landing_enabled", "camera_fov_refinement_enabled"]:
			body.set(String(property.name), false)


func _frames(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame


func _release_inputs() -> void:
	for action in ACTIONS:
		Input.action_release(action)


func _horizontal_speed() -> float:
	return Vector2(actor.velocity.x, actor.velocity.z).length()


func _rig() -> Node3D:
	return actor.get_node("CameraPivot") as Node3D


func _camera(body: Node3D) -> Camera3D:
	return body.get_node("CameraPivot/SpringArm3D/Camera3D") as Camera3D


func _vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


func _scroll(button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	root.push_input(event)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event)


func _box(center: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = center
	body.collision_layer = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)
	return body


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
