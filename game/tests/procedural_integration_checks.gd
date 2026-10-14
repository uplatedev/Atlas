extends SceneTree
## De echte motor, skeletpresentatie, camera en audio samen op dezelfde physicsframes.
const CHARACTER = preload("res://characters/Character.tscn")
const AUDIO_SHUTDOWN = preload("res://tests/test_audio_shutdown.gd")
const DT := 1.0 / 60.0
var failures: Array[String] = []
var world: Node3D
var actors: Array[AtlasCharacter] = []
var frames: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)

func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	_box(Vector3(0, -0.1, 0), Vector3(200, 0.2, 200))
	for index in range(4):
		var actor := CHARACTER.instantiate() as AtlasCharacter
		actor.position = Vector3(index * 5.0, 0.05, 0)
		if index > 0:
			var profile := AtlasCharacterBodyProfile.new()
			profile.test_body = index - 1
			actor.body_profile = profile
		actors.append(actor)
		frames[index] = []
		actor.contact_frame_ready.connect(func(frame: AtlasCharacterContactFrame): frames[index].append(frame))
		var skeleton_builds := [0]
		var count_skeleton := func(node: Node):
			if node is Skeleton3D and actor.is_ancestor_of(node):
				skeleton_builds[0] += 1
		node_added.connect(count_skeleton)
		world.add_child(actor)
		node_added.disconnect(count_skeleton)
		check(skeleton_builds[0] == 1, "lichaam %d bouwt het skelet slechts eenmaal bij spawn" % index)
	await _ticks(12)
	await _check_running()
	await _check_supported_steps()
	await _check_scene_persistence()
	await _check_live_profile()
	await _check_look_handoff()
	world.queue_free()
	await AUDIO_SHUTDOWN.drain(self)
	print("PROCEDURAL INTEGRATION: ", "PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)

func _send(actor: AtlasCharacter, moving: bool, sprint: bool = false) -> void:
	var intent := AtlasCharacterIntent.new()
	intent.movement = Vector2(0, -1) if moving else Vector2.ZERO
	intent.sprint = sprint
	actor.submit_intent(intent)

func _check_running() -> void:
	for actor in actors:
		_send(actor, true, true)
	await _ticks(40)
	var min_body := INF
	var max_body := -INF
	var min_view := INF
	var max_view := -INF
	for index in range(4):
		frames[index].clear()
	for tick in range(180):
		await _ticks(1)
		min_body = minf(min_body, actors[0].position.y)
		max_body = maxf(max_body, actors[0].position.y)
		var view := float(actors[0].get_node("CameraPivot").get("_feet_height"))
		min_view = minf(min_view, view)
		max_view = maxf(max_view, view)
	for index in range(4):
		var actor := actors[index]
		var presentation := actor.get_node("Presentation/ProceduralBody")
		var state: Dictionary = presentation.get_debug_state()
		var liftoffs := 0
		var contacts := 0
		var bad_air_contact := false
		var heavy_landings := 0
		for frame: AtlasCharacterContactFrame in frames[index]:
			liftoffs += 1 if frame.stride_started else 0
			contacts += frame.foot_contacts.size()
			heavy_landings += 1 if frame.landed or frame.jumped else 0
			bad_air_contact = bad_air_contact or (not frame.supported and not frame.foot_contacts.is_empty())
		check(liftoffs >= 5 and contacts >= 5, "lichaam %d heeft echte herhaalde pasvlucht en hoorbare contacten" % index)
		check(not bad_air_contact and heavy_landings == 0, "lichaam %d geeft geen fictieve contact-/sprong-/landingsgebeurtenissen" % index)
		check(state.max_planted_error < 0.025 and state.released_overreach == 0, "lichaam %d bewaart de werkelijke geplante enkel: %s" % [index, state])
		check(state.rays_last_frame <= 2, "maximaal twee lokale voetqueries")
		check(float(actor.get_debug_state().fatigue) == 0.0, "passen kosten geen sprongvermoeidheid")
		var cues: Dictionary = actor.get_node("Feedback").get("_cue_counts")
		check(cues.step >= 5 and cues.jump == 0 and cues.landing == 0, "audio volgt echte voeten zonder sprong-/landingsgeluid")
		print("INTEGRATED BODY ", index, " liftoffs=", liftoffs, " contacts=", contacts, " state=", state)
	check(max_body - min_body > 0.05, "Artemis heeft echte capsulevlucht")
	check(max_view - min_view < (max_body - min_body) * 0.55, "camera dempt alleen het gemeten pasritme")
	print("CAMERA body/view amplitude ", max_body - min_body, "/", max_view - min_view)
	for actor in actors:
		actor.reset_to_spawn()
		_send(actor, false)
	await _ticks(12)
	for actor in actors:
		check(actor.get_debug_state().step_index == 0, "reset wist pasfase")
		check(absf(float(actor.get_node("CameraPivot").get("_stride_view_offset"))) < 0.001, "reset wist pascorrectie camera")

func _check_supported_steps() -> void:
	var actor := actors[0]
	for curve_zero in [true, false]:
		actor.reset_to_spawn()
		var profile := AtlasCharacterBodyProfile.new()
		profile.visual_scene = load("res://assets/characters/artemis_rigged.glb")
		if curve_zero:
			profile.stride_flight_curve.clear_points()
			profile.stride_flight_curve.add_point(Vector2.ZERO)
			profile.stride_flight_curve.add_point(Vector2(1, 0))
		actor.body_profile = profile
		var roof: StaticBody3D
		if not curve_zero:
			roof = _box(Vector3(0, 1.915, -15), Vector3(4, 0.2, 40))
		await _ticks(10)
		frames[0].clear()
		_send(actor, true, true)
		await _ticks(110)
		var contacts := 0
		var planted_steps := 0
		for frame: AtlasCharacterContactFrame in frames[0]:
			contacts += frame.foot_contacts.size()
			planted_steps += 1 if frame.ground_step else 0
		check(contacts >= 4 and planted_steps >= 4, "curve0/plafond behoudt afwisselende gesteunde voeten en geluid")
		print("SUPPORTED STEP zero=", curve_zero, " steps=", planted_steps, " contacts=", contacts)
		_send(actor, false)
		if roof != null:
			roof.queue_free()
		await _ticks(2)
	actor.reset_to_spawn()
	_send(actor, false)
	await _ticks(8)

func _check_scene_persistence() -> void:
	var container := Node3D.new()
	container.name = "TweeCharacters"
	var first := CHARACTER.instantiate() as AtlasCharacter
	var second := CHARACTER.instantiate() as AtlasCharacter
	first.name = "Eerste"
	second.name = "Tweede"
	container.add_child(first)
	container.add_child(second)
	first.owner = container
	second.owner = container
	var original := second.body_profile.stride_flight_curve.get_point_position(3)
	first.body_profile.mass_kg = 123.0
	first.body_profile.stride_flight_curve.set_point_value(3, 0.17)
	first.body_profile.swing_foot_curve.set_point_value(1, 0.6)
	check(second.body_profile.mass_kg == 75 and second.body_profile.stride_flight_curve.get_point_position(3) == original, "twee echte Character-instances delen profiel/curvewijziging niet")
	var packed := PackedScene.new()
	check(packed.pack(container) == OK, "Character-proefscene opslaan")
	var path := "user://t011_actual_character_instances.tscn"
	check(ResourceSaver.save(packed, path) == OK, "schrijven van echte scene")
	container.free()
	var scene := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var reopened := scene.instantiate()
	var a: AtlasCharacter = reopened.get_node("Eerste")
	var b: AtlasCharacter = reopened.get_node("Tweede")
	check(a.body_profile.mass_kg == 123 and b.body_profile.mass_kg == 75, "eigen massa bewaard na heropenen")
	check(is_equal_approx(a.body_profile.stride_flight_curve.get_point_position(3).y, 0.17), "eigen curve bewaard na heropenen")
	a.body_profile.stride_flight_curve.set_point_value(3, 0.20)
	a.body_profile.swing_foot_curve.set_point_value(1, 0.4)
	check(b.body_profile.stride_flight_curve.get_point_position(3) == original and is_equal_approx(b.body_profile.swing_foot_curve.get_point_position(1).y, 1.0), "ook heropende curves blijven onafhankelijk")
	reopened.free()

func _check_live_profile() -> void:
	var actor := actors[3]
	var presentation := actor.get_node("Presentation/ProceduralBody")
	actor.body_profile = AtlasCharacterBodyProfile.new()
	await _ticks(2)
	var before: Node = presentation.get("_visual")
	actor.body_profile.test_body = 1
	await _ticks(2)
	check(presentation.get("_visual") != before and absf(presentation.get_leg_length() - 0.81) < 0.001, "gewijzigd proeflichaam bouwt preview en rustmetingen opnieuw")
	var after: Node = presentation.get("_visual")
	actor.body_profile.arm_swing_degrees = 32
	actor.body_profile.swing_foot_curve.set_point_value(1, 0.75)
	await _ticks(2)
	check(presentation.get("_visual") == after, "stijl/curve veranderen zonder rig opnieuw te maken")
	actor.set_camera_distance(0.0)
	actor.set_controlled(true)
	await _ticks(2)
	var camera: Camera3D = actor.get_node("CameraPivot/SpringArm3D/Camera3D")
	var own_layer := 1 << (actor.get_presentation_layer() - 1)
	var other_layer := 1 << (actors[0].get_presentation_layer() - 1)
	check((camera.cull_mask & own_layer) == 0 and (camera.cull_mask & other_layer) != 0, "first person verbergt alleen eigen lichaam")

func _check_look_handoff() -> void:
	var actor := actors[0]
	actor.reset_to_spawn()
	actor.set_controlled(false)
	var camera := actor.get_node("CameraPivot") as AtlasCharacterCamera
	var intent := AtlasCharacterIntent.new()
	intent.has_look_direction = true
	intent.look_direction = Vector2(0.45, -0.3)
	actor.submit_intent(intent)
	await _ticks(5)
	check(actor.get_look_input().distance_to(intent.look_direction) < 0.0001, "AI-kijkrichting blijft ook na renders behouden")
	check(absf(camera.get_look_yaw() - intent.look_direction.x) < 0.0001, "AI en camera bewaren dezelfde hoek")
	actor.set_controlled(true)
	camera.apply_look_delta(Vector2(100, 50))
	check(actor.get_look_input().distance_to(intent.look_direction) < 0.0001, "muis overschrijft geen actieve AI-intentie")
	actor.use_player_input()
	await _ticks(2)
	check(actor.get_look_input().distance_to(intent.look_direction) < 0.0001, "AI naar speler springt niet terug naar oude kijkhoek")
	camera.apply_look_delta(Vector2(-10, 0))
	var player_look := actor.get_look_input()
	check(player_look.x > intent.look_direction.x, "muis reageert vanaf de overgenomen AI-hoek")
	await _ticks(2)
	check(actor.get_look_input().distance_to(player_look) < 0.0001, "spelerhoek blijft na render behouden")
	actor.set_controlled(false)
	intent.look_direction = Vector2(2.8, 2.0)
	actor.submit_intent(intent)
	await _ticks(2)
	var look := actor.get_look_input()
	check(absf(wrapf(look.x - actor.rotation.y, -PI, PI)) <= deg_to_rad(actor.head_max_yaw) + 0.001, "AI-hoofdgrens blijft geldig")
	check(look.y <= deg_to_rad(actor.camera_max_pitch) + 0.001, "AI-pitchgrens blijft geldig")
	print("AI-look: renderbehoud, muisoverdracht en hoofdgrenzen PASS")

func _box(position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	body.position = position
	world.add_child(body)
	return body

func _ticks(count: int) -> void:
	for tick in range(count):
		await physics_frame
		await process_frame
