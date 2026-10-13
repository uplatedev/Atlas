extends SceneTree
## Werkelijke physicsproeven voor de lokale Character-controller.

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
	_add_box(Vector3(0, -0.1, 0), Vector3(120, 0.2, 120))
	character = CHARACTER.instantiate() as AtlasCharacter
	character.procedural_enabled = false
	character.position = Vector3(0, 0.05, 0)
	world.add_child(character)
	character.set_controlled(true)
	await _frames(8)
	await _test_movement()
	await _test_jumps()
	await _test_steps()
	_release_inputs()
	world.queue_free()
	await process_frame
	await _test_main_scene()
	await AUDIO_SHUTDOWN.drain(self)
	if failures.is_empty():
		print("PASS: alle Character-physics- en scenecontroles geslaagd.")
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: ", failure)
		quit(1)


func _test_movement() -> void:
	var forward: float = await _speed(["move_forward"])
	var side: float = await _speed(["move_right"])
	var back: float = await _speed(["move_back"])
	var diagonal: float = await _speed(["move_forward", "move_right"])
	_expect(absf(forward - character.walk_forward_speed) < 0.06, "lopen bereikt ingestelde voorwaartse snelheid")
	_expect(forward > side and side > back and back > 0.0, "lopen: vooruit > zijwaarts > achteruit")
	_expect(diagonal <= forward + 0.06, "diagonale loopinput geeft geen snelheidsbonus")
	var sprint_forward: float = await _speed(["move_forward", "sprint"])
	var sprint_side: float = await _speed(["move_right", "sprint"])
	var sprint_back: float = await _speed(["move_back", "sprint"])
	var sprint_diagonal: float = await _speed(["move_forward", "move_right", "sprint"])
	_expect(absf(sprint_forward - character.sprint_forward_speed) < 0.06, "sprint bereikt ingestelde voorwaartse snelheid")
	_expect(sprint_forward > sprint_side and sprint_side > sprint_back and sprint_back > back, "sprint werkt in alle richtingen met lagere zij-/achterwaartse snelheden")
	_expect(sprint_diagonal <= sprint_forward + 0.06, "diagonale sprintinput geeft geen snelheidsbonus")
	var opposing: float = await _speed(["move_forward", "move_back", "move_left", "move_right"])
	_expect(opposing < 0.01, "tegengestelde inputs heffen elkaar op")
	await _reset()
	Input.action_press("move_forward")
	# Twee ticks tonen de opbouw ook met de nieuwe 3 m/s-joglimiet;
	# zes ticks bereikten die al volledig en bewezen geen onmiddellijke versnelling.
	await _frames(2)
	var accelerating := _horizontal_speed()
	_expect(accelerating > 0.0 and accelerating < forward - 0.1, "acceleratie bouwt snelheid op")
	_release_inputs()
	await _frames(6)
	_expect(_horizontal_speed() < accelerating, "loslaten remt af")
	await _speed(["move_forward", "sprint"])
	Input.action_release("sprint")
	Input.action_press("move_forward")
	await _frames(50)
	_expect(_horizontal_speed() <= forward + 0.06, "sprint naar lopen keert terug naar looplimiet")
	print("MEASURE: walk %.3f / side %.3f / back %.3f / diagonal %.3f; sprint %.3f / %.3f / %.3f / %.3f" % [forward, side, back, diagonal, sprint_forward, sprint_side, sprint_back, sprint_diagonal])


func _test_jumps() -> void:
	var standing: Dictionary = await _jump([])
	var walking: Dictionary = await _jump(["move_forward"])
	var sprinting: Dictionary = await _jump(["move_forward", "sprint"])
	_expect(standing.height > walking.height and walking.height > sprinting.height, "gemeten spronghoogte: stilstand > lopen > sprint")
	_expect(sprinting.distance > walking.distance + 0.5, "gemeten sprintsprong gaat extra ver")
	var same_velocity := Vector3(0, 0, -character.walk_forward_speed)
	Input.action_release("sprint")
	var before := character.jump_parameters(same_velocity)
	Input.action_press("sprint")
	var after := character.jump_parameters(same_velocity)
	_expect(is_equal_approx(float(before.height), float(after.height)), "alleen Shift verandert sprongprofiel niet bij dezelfde snelheid")
	Input.action_release("sprint")
	var stationary := character.jump_parameters(Vector3.ZERO)
	_expect(float(stationary.height) > float(before.height), "stationaire sprong blijft hoog")
	print("MEASURE: jumps standing %.3fm / %.3fm range; walk %.3fm / %.3fm; sprint %.3fm / %.3fm" % [standing.height, standing.distance, walking.height, walking.distance, sprinting.height, sprinting.distance])


func _test_steps() -> void:
	character.step_height = 0.35
	var low := _add_box(Vector3(0, 0.15, -2.5), Vector3(3, 0.3, 3))
	var climb: Dictionary = await _walk_over_obstacle()
	_expect(climb.max_y > 0.26 and climb.final_z < -4.1, "lage trede wordt werkelijk opgestapt")
	low.queue_free()
	await _frames(2)
	var high := _add_box(Vector3(0, 0.225, -2.5), Vector3(3, 0.45, 3))
	var blocked: Dictionary = await _walk_over_obstacle()
	_expect(blocked.max_y < 0.15 and blocked.final_z > -1.4, "trede boven opstapgrens blijft obstakel")
	high.queue_free()
	await _frames(2)
	low = _add_box(Vector3(0, 0.15, -2.5), Vector3(3, 0.3, 3))
	var ceiling := _add_box(Vector3(0, 2.05, -2.5), Vector3(3, 0.2, 3))
	var headroom: Dictionary = await _walk_over_obstacle(300)
	_expect(headroom.max_y > 0.26 and headroom.final_z < -4.1, "geldige trede onder laag plafond passeert met automatisch lagere houding")
	low.queue_free()
	ceiling.queue_free()
	print("MEASURE: steps low %.3f / z %.3f; high %.3f / z %.3f; ceiling %.3f / z %.3f" % [climb.max_y, climb.final_z, blocked.max_y, blocked.final_z, headroom.max_y, headroom.final_z])


func _test_main_scene() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var main := scene.instantiate()
	main.set("capture_mouse_on_start", false)
	root.add_child(main)
	await _frames(6)
	var first := main.get_node("Characters/AtlasA") as AtlasCharacter
	var second := main.get_node("Characters/AtlasB") as AtlasCharacter
	_expect(first.display_name != second.display_name and first.walk_forward_speed != second.walk_forward_speed, "twee onafhankelijke editorinstellingen aanwezig")
	var second_speed := second.walk_forward_speed
	first.walk_forward_speed += 0.5
	_expect(is_equal_approx(second.walk_forward_speed, second_speed), "instancewijziging blijft lokaal")
	_expect(first.get_node("CollisionShape3D").shape != second.get_node("CollisionShape3D").shape, "capsulebotsingen hebben eigen Resources")
	_expect(first.get_node("Presentation/Capsule").material_override != second.get_node("Presentation/Capsule").material_override, "capsulematerialen hebben eigen Resources")
	first.display_name = "Alleen eerste naam gewijzigd"
	_expect(second.get_node("Presentation/NameLabel").text == second.display_name, "naamwijziging raakt tweede instance niet")
	first.set_camera_distance(0.0)
	await _frames(45)
	_expect(bool(first.get_debug_state().first_person), "camera kan naar first person zoomen")
	var first_mesh := first.get_node("Presentation/Capsule") as MeshInstance3D
	var second_mesh := second.get_node("Presentation/Capsule") as MeshInstance3D
	var first_camera := first.get_node("CameraPivot/SpringArm3D/Camera3D") as Camera3D
	_expect((first_camera.cull_mask & first_mesh.layers) == 0, "first-personcamera verbergt uitsluitend eigen capsule")
	_expect((first_camera.cull_mask & second_mesh.layers) != 0, "andere capsule blijft zichtbaar voor first-personcamera")
	first.set_camera_distance(1000.0)
	_expect(first.get_debug_state().camera_distance <= first.camera_max_distance, "zoom blijft binnen instelbare maximale afstand")
	main.call("set_active_character", 1)
	await _frames(2)
	_expect(second.get_debug_state().get("camera_distance", 0.0) > 0.0, "tweede instance houdt eigen camerafstand")
	var second_camera := second.get_node("CameraPivot/SpringArm3D/Camera3D") as Camera3D
	_expect((second_camera.cull_mask & first_mesh.layers) != 0, "camera van tweede Character ziet de eerste capsule")
	first.global_position += Vector3(2, 2, 2)
	first.reset_to_spawn()
	_expect(first.global_position.distance_to(Vector3(-2, 0.05, 6)) < 0.01, "reset keert terug naar eigen startpositie")
	main.call("set_active_character", 0)
	var wall := _add_box(Vector3(-2, 1.5, 6.6), Vector3(3, 3, 0.2), main)
	await _frames(10)
	_expect(float(first.get_debug_state().camera_actual_distance) < 0.5, "camera-arm comprimeert werkelijk bij een nabije muur")
	_expect((first_camera.cull_mask & first_mesh.layers) == 0, "gecomprimeerde camera blijft vrij van eigen capsule")
	wall.queue_free()
	await _frames(60)
	_expect((first_camera.cull_mask & first_mesh.layers) != 0, "eigen capsule wordt zichtbaar zodra de camera weer vrij is")
	first.camera_max_distance = 0.3
	first.set_camera_distance(0.0)
	first.set_camera_distance(0.3)
	_expect(float(first.get_debug_state().camera_distance) > 0.0, "kleine ingestelde maximale zoomafstand blijft bruikbaar")
	var lights := _count_lights(main.get_node("PrototypeLevel"))
	_expect(lights == 2, "prototypelevel bevat precies twee lampen")
	main.queue_free()
	await process_frame


func _speed(actions: Array) -> float:
	await _reset()
	for action in actions:
		Input.action_press(action)
	await _frames(100)
	var measured := _horizontal_speed()
	_release_inputs()
	return measured


func _jump(actions: Array) -> Dictionary:
	await _reset()
	for action in actions:
		Input.action_press(action)
	if not actions.is_empty():
		await _frames(100)
	var start := character.global_position
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	var apex := character.global_position.y
	var seen_airborne := not character.is_on_floor()
	for i in 240:
		await _frames(1)
		apex = maxf(apex, character.global_position.y)
		seen_airborne = seen_airborne or not character.is_on_floor()
		if seen_airborne and character.is_on_floor():
			break
	var distance := Vector2(character.global_position.x - start.x, character.global_position.z - start.z).length()
	_release_inputs()
	_expect(seen_airborne and character.is_on_floor(), "sprong komt los en landt weer")
	return {"height": apex - start.y, "distance": distance}


func _walk_over_obstacle(frames: int = 100) -> Dictionary:
	await _reset()
	Input.action_press("move_forward")
	var max_y := character.global_position.y
	for i in frames:
		await _frames(1)
		max_y = maxf(max_y, character.global_position.y)
	_release_inputs()
	return {"max_y": max_y, "final_z": character.global_position.z}


func _reset() -> void:
	_release_inputs()
	character.reset_to_spawn()
	await _frames(8)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame


func _horizontal_speed() -> float:
	return Vector2(character.velocity.x, character.velocity.z).length()


func _release_inputs() -> void:
	for action in ACTIONS:
		Input.action_release(action)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)


func _add_box(position_value: Vector3, size: Vector3, parent: Node = null) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	if parent != null:
		parent.add_child(body)
	else:
		world.add_child(body)
	body.position = position_value
	return body


func _count_lights(node: Node) -> int:
	var result := 1 if node is Light3D else 0
	for child in node.get_children():
		result += _count_lights(child)
	return result
