extends SceneTree
## Werkelijke contactaudio: afstand/contact, geen hoorbaar kwaliteitsoordeel.
## De component-observer meldt geaccepteerde cues; de controller blijft fysiek.

const CHARACTER = preload("res://characters/Character.tscn")
const AUDIO_SHUTDOWN = preload("res://tests/test_audio_shutdown.gd")
const ACTIONS = ["move_forward", "move_back", "move_left", "move_right", "run", "walk", "crouch", "prone", "jump"]
var failures: Array[String] = []
var world: Node3D
var actor: AtlasCharacter
var feedback: Node
var cue_events: Array[Dictionary] = []
var contacts: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	_box(Vector3(0, -0.1, 0), Vector3(400, 0.2, 400))
	actor = CHARACTER.instantiate() as AtlasCharacter
	actor.procedural_enabled = false
	actor.position = Vector3(0, 0.05, 0)
	world.add_child(actor)
	actor.set_controlled(true)
	feedback = actor.get_node_or_null("Feedback")
	if feedback == null or not feedback.has_method("get_debug_state"):
		printerr("FAIL: Character mist de contactfeedbackcomponent/observer.")
		quit(1)
		return
	feedback.connect("cue_played", _observe_cue)
	actor.connect("contact_frame_ready", _observe_contact)
	await _frames(8)
	await _test_silence()
	await _test_gait_distance()
	await _test_jump_and_contact()
	await _test_slide_and_virtual_support()
	await _test_ground_slide_feedback()
	await _test_turn_contact_feedback()
	await _test_routing_and_instances()
	await _test_physics_independence()
	_release_inputs()
	world.queue_free()
	await process_frame
	await _test_main_tab()
	await AUDIO_SHUTDOWN.drain(self)
	if failures.is_empty():
		print("PASS: contactaudio voor echte afstand/afzet/impact/slide, routing, reset en ongewijzigde physics.")
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: ", failure)
		quit(1)


func _test_turn_contact_feedback() -> void:
	await _reset()
	var frame := AtlasCharacterContactFrame.new()
	frame.delta = 1.0 / 60.0
	frame.procedural_enabled = true
	frame.supported = true
	frame.turn_step_landed = true
	frame.turn_step_index = 1
	frame.foot_contacts.append(actor.global_position)
	var before := _count("step")
	feedback.consume_contact(frame)
	_expect(_count("step") == before + 1, "echt bijstapcontact klinkt eenmaal bij nul capsulesnelheid")
	feedback.consume_contact(frame)
	_expect(_count("step") == before + 1, "hetzelfde bijstapcontactnummer wordt niet herhaald")
	frame.turn_step_index += 1
	frame.foot_contacts.clear()
	feedback.consume_contact(frame)
	_expect(_count("step") == before + 1, "bijstap zonder gevonden voetcontact blijft stil")
	frame.foot_contacts.append(actor.global_position)
	for blocked in ["supported", "sliding", "jumped", "landed"]:
		frame.turn_step_index += 1
		frame.set(blocked, blocked != "supported")
		feedback.consume_contact(frame)
		frame.set(blocked, blocked == "supported")
	_expect(_count("step") == before + 1, "vlucht, slide, sprong en zware landing krijgen geen extra bijstapgeluid")
	frame.turn_step_index += 1
	feedback.consume_contact(frame)
	_expect(_count("step") == before + 2, "volgende veilige bijstap mag opnieuw klinken")
	await _reset()


func _test_silence() -> void:
	_expect(_count("landing") == 0, "startupcontact geeft geen kunstmatige impact")
	await _reset()
	var before := _count("step")
	Input.action_press("run")
	await _frames(90)
	_expect(_count("step") == before, "Shift in stilstand geeft geen stappen")
	var wall := _box(Vector3(0, 2.5, -1), Vector3(8, 5, 0.2))
	Input.action_press("move_forward")
	await _frames(60)
	before = _count("step")
	var position_before := actor.global_position
	await _frames(90)
	_expect(actor.global_position.distance_to(position_before) < 0.002 and _count("step") == before, "W tegen een echte wand geeft geen stappen zonder verplaatsing")
	wall.queue_free()
	await _frames(2)


func _test_gait_distance() -> void:
	for profile in ["jog", "run", "walk", "crouch", "prone"]:
		await _reset()
		if profile == "crouch":
			actor.request_posture(1)
		elif profile == "prone":
			actor.request_posture(2)
		if profile in ["run", "walk"]:
			Input.action_press(profile)
		await _frames(4)
		var before := _count("step")
		var origin := actor.global_position
		Input.action_press("move_forward")
		await _frames(150)
		var distance := Vector2(actor.global_position.x - origin.x, actor.global_position.z - origin.z).length()
		var steps := _count("step") - before
		var spacing := float(actor.get(profile + "_step_distance"))
		_expect(spacing > 0.0 and steps > 0, "%s geeft echte afstandsgebonden stappen" % profile)
		_expect(absf(float(steps) - distance / maxf(spacing, 0.01)) <= 1.1, "%s-cadans volgt ingestelde meters per stap, inclusief acceleratie" % profile)
		print("MEASURE: %s afstand %.3f m, stappen %d, instelling %.3f m/stap." % [profile, distance, steps, spacing])


func _test_jump_and_contact() -> void:
	await _reset()
	var step := _box(Vector3(0, 0.15, -5), Vector3(8, 0.3, 8))
	var ordinary_contact_before := _count("landing")
	Input.action_press("move_forward")
	await _frames(60)
	_expect(actor.position.y > 0.29 and actor.position.z < -2.0 and _count("landing") == ordinary_contact_before, "geldige grondopstap geeft ondersteunde verplaatsing zonder landingimpact")
	step.queue_free()
	await _frames(2)
	await _reset()
	var jump_before := _count("jump")
	var land_before := _count("landing")
	var steps_before := _count("step")
	Input.action_press("jump")
	await _frames(1)
	_expect(not actor.is_on_floor() and _count("jump") == jump_before + 1, "geaccepteerde afzet geeft exact één jumpcue")
	Input.action_press("move_forward")
	Input.action_press("run")
	await _frames(12)
	_expect(not actor.is_on_floor() and _count("step") == steps_before, "W/Shift in vlucht geven geen grondstappen")
	_release_inputs()
	await _landing()
	_expect(_count("landing") == land_before + 1, "echte vlucht geeft eenmaal landingfeedback")
	var impact := _last_impact()
	_expect(float(impact.get("incoming_y", 0.0)) < -1.0 and absf(actor.velocity.y) < 0.1, "impactdata bewaart neerwaartse vaart van vóór collision")
	await _frames(30)
	_expect(_count("landing") == land_before + 1 and _count("jump") == jump_before + 1, "rust op de vloer herhaalt afzet/landing niet")
	await _reset()
	actor.request_posture(1)
	await _frames(3)
	jump_before = _count("jump")
	await _pulse("jump")
	_expect(actor.is_on_floor() and _count("jump") == jump_before, "gewone lage oprichting geeft geen afzetgeluid")


func _test_slide_and_virtual_support() -> void:
	await _run_jump()
	var land_before := _count("landing")
	var slide_before := _count("slide_landing")
	await _pulse("crouch")
	_expect(not actor.is_on_floor() and not bool(_state().get("slide_loop_active", true)), "lucht-C start nog geen grondschuurlaag")
	await _landing()
	_expect(_flag("slide_active") and _count("landing") == land_before + 1 and _count("slide_landing") == slide_before + 1 and bool(_last_impact().get("sliding", false)), "slidelanding geeft één samengestelde cue zonder tweede volle landing")
	_expect(bool(_state().get("slide_loop_active", false)), "loop begint pas bij werkelijk ondersteunde actieve slide")
	# process_frame wordt vóór Node._process uitgezonden; laat die audio-update afmaken.
	await _frames(1)
	_expect(bool(_state().get("slide_audio_playing", false)), "slidefeedback speelt een echte schuuraudiostream")
	var peak_volume := float(_state().get("slide_volume_db", -100.0))
	var initial_speed := _speed()
	# De normale fade-in blijft aan. Meet eerst haar echte piek, daarna de afname.
	for frame in 30:
		await _frames(1)
		peak_volume = maxf(peak_volume, float(_state().get("slide_volume_db", -100.0)))
	var final_volume := float(_state().get("slide_volume_db", -100.0))
	_expect(_flag("slide_active") and _speed() < initial_speed and final_volume < peak_volume - 0.01, "schuurlaag zwakt na fade-in af met werkelijk afgebouwde slidevaart")
	print("MEASURE: slide-volume piek/eind %.3f/%.3f dB; vaart begin/eind %.3f/%.3f m/s." % [peak_volume, final_volume, initial_speed, _speed()])
	await _pulse("jump")
	_expect(not actor.is_on_floor() and not bool(_state().get("slide_loop_active", true)), "slidesprong stopt de grondloop meteen")
	actor.reset_to_spawn()
	_expect(not bool(_state().get("slide_loop_active", true)) and not _any_voice_playing(), "respawn stopt oude voices zonder uitgestelde herstart")
	var original_radius := actor.crouch_capsule_radius
	var original_snap := actor.floor_snap_length
	actor.crouch_capsule_radius = 0.15
	actor.floor_snap_length = 0.0
	await _run_jump()
	await _pulse("crouch")
	await _landing()
	land_before = _count("landing")
	var contact_before := contacts.size()
	var step := _box(actor.global_position + Vector3(0, 0.15, -2.6), Vector3(8, 0.3, 4))
	var virtual_only := false
	for frame in 10:
		await _frames(1)
		if actor.get_camera_grounded() and not actor.is_on_floor():
			virtual_only = true
			_expect(_flag("slide_active") and bool(_state().get("slide_loop_active", false)), "virtuele opstapsteun bewaart bestaande slidefeedback")
	_expect(virtual_only, "fixture bereikt aantoonbaar uitsluitend virtuele stepsteun")
	var spurious_impact := false
	for index in range(contact_before, contacts.size()):
		spurious_impact = spurious_impact or bool(contacts[index].landed)
	_expect(_count("landing") == land_before and not spurious_impact, "opstap en terugkeer naar echte vloer geven geen nieuwe impact")
	step.queue_free()
	actor.crouch_capsule_radius = original_radius
	actor.floor_snap_length = original_snap
	await _frames(2)


func _test_ground_slide_feedback() -> void:
	await _reset()
	Input.action_press("move_forward")
	Input.action_press("run")
	await _frames(80)
	var land_before := _count("landing")
	var slide_landing_before := _count("slide_landing")
	var jump_before := _count("jump")
	var steps_before := _count("step")
	var contact_before := contacts.size()
	await _pulse("crouch")
	await _frames(3)
	_expect(_flag("slide_active") and bool(_state().get("slide_loop_active", false)) and bool(_state().get("slide_audio_playing", false)), "rungrondslide start een echte schuurlaag zonder voorafgaande sprong")
	Input.action_press("crouch")
	var uninterrupted := true
	for frame in 12:
		await _frames(1)
		uninterrupted = uninterrupted and _flag("slide_active") and bool(_state().get("slide_loop_active", false)) and bool(_state().get("slide_audio_playing", false))
	Input.action_release("crouch")
	_expect(uninterrupted and str(actor.get_debug_state().manual_posture) == "kruipen", "C tijdens actieve slide laat de echte schuurloop onafgebroken doorspelen")
	var false_landing := false
	for index in range(contact_before, contacts.size()):
		false_landing = false_landing or bool(contacts[index].landed)
	_expect(not false_landing and _count("landing") == land_before and _count("slide_landing") == slide_landing_before and _count("jump") == jump_before, "grondslide geeft geen vals landingcontact, landingcue of afzetcue")
	_expect(_count("step") == steps_before, "actieve rungrondslide speelt schuren zonder gewone stapcues")
	await _pulse("jump")
	_expect(not actor.is_on_floor() and not bool(_state().get("slide_loop_active", true)) and _count("jump") == jump_before + 1, "echte sprong uit grondslide stopt schuren en geeft exact één afzetcue")


func _test_routing_and_instances() -> void:
	var saved_variation := float(actor.get("feedback_volume_variation_db"))
	# De vergelijking gaat over zoomrouting; samplevariatie krijgt haar eigen RNG.
	actor.set("feedback_volume_variation_db", 0.0)
	await _reset()
	var other: AtlasCharacter = CHARACTER.instantiate()
	other.procedural_enabled = false
	other.position = Vector3(20, 0.05, 0)
	other.jog_step_distance = actor.jog_step_distance * 2.0
	world.add_child(other)
	await _frames(8)
	var other_feedback: Node = other.get_node("Feedback")
	var other_before: Dictionary = other_feedback.call("get_debug_state")
	_expect(other_feedback != feedback and other.jog_step_distance != actor.jog_step_distance, "instances hebben eigen feedbackcomponent en afzonderlijke Inspectorinstellingen")
	actor.set_camera_distance(0.0)
	await _pulse("jump")
	_expect(_last_route() == "local", "eigen afzet gebruikt zoomonafhankelijke lokale audio")
	var local_voice := _one_shot_voice(false)
	_expect(local_voice != null and bool(local_voice.get("playing")) and local_voice.get("stream") != null, "eigen afzet stuurt een echte audiostream aan")
	var fp_volume := float(local_voice.get("volume_db")) if local_voice != null else -100.0
	await _landing()
	await _reset()
	actor.set_camera_distance(8.0)
	await _pulse("jump")
	_expect(_last_route() == "local", "eigen audio blijft lokaal bij maximale third-personzoom")
	var tp_voice := _one_shot_voice(false)
	var tp_volume := float(tp_voice.get("volume_db")) if tp_voice != null else -100.0
	_expect(absf(tp_volume - fp_volume) < 0.01, "zoom voegt geen afstandsdemping aan eigen one-shot toe")
	actor.set_controlled(false)
	other.set_controlled(true)
	await _landing()
	_expect(_last_route() == "3d", "na controlewisseling landt de andere Character ruimtelijk")
	var spatial_voice := _one_shot_voice(true)
	_expect(spatial_voice != null and bool(spatial_voice.get("playing")) and spatial_voice.get("stream") != null, "andere landing stuurt een echte ruimtelijke audiostream aan")
	_expect(int(other_feedback.call("get_debug_state").get("cue_counts", {}).get("landing", 0)) == int(other_before.get("cue_counts", {}).get("landing", 0)), "een landing van de eerste instance raakt de tweede contactgeschiedenis niet")
	actor.set_controlled(true)
	other.set_controlled(false)
	await _run_jump()
	await _pulse("crouch")
	await _landing()
	actor.set("feedback_enabled", false)
	await _frames(1)
	_expect(not bool(_state().get("slide_loop_active", true)) and not _any_voice_playing(), "feedback uit stopt actieve audio- en schuurvoices")
	var cue_before: Dictionary = _state().get("cue_counts", {}).duplicate(true)
	await _frames(90)
	_expect(_state().get("cue_counts", {}) == cue_before, "feedback uit geeft geen nieuwe cues")
	actor.set("feedback_enabled", true)
	actor.set("feedback_volume_variation_db", saved_variation)
	other.queue_free()
	await _frames(2)


func _test_physics_independence() -> void:
	var enabled: Array = await _physics_trace(true)
	var disabled: Array = await _physics_trace(false)
	var max_difference := 0.0
	for index in mini(enabled.size(), disabled.size()):
		var first: Array = enabled[index]
		var second: Array = disabled[index]
		for component in first.size():
			max_difference = maxf(max_difference, absf(float(first[component]) - float(second[component])))
	_expect(enabled.size() == disabled.size() and max_difference < 0.00001, "feedback aan/uit verandert geen velocity, positie, fatigue, posture, cap of FOV")
	print("MEASURE: audio aan/uit %d physicsframes; grootste verschil %.8f." % [enabled.size(), max_difference])
	actor.set("feedback_enabled", true)


func _physics_trace(enabled: bool) -> Array:
	actor.set("feedback_enabled", enabled)
	await _reset()
	var values: Array = []
	Input.action_press("move_forward")
	Input.action_press("run")
	for frame in 180:
		if frame == 60:
			Input.action_press("jump")
		elif frame == 61:
			Input.action_release("jump")
		elif frame == 68:
			Input.action_press("crouch")
		elif frame == 69:
			Input.action_release("crouch")
		elif frame == 90:
			Input.action_release("move_forward")
			Input.action_press("move_back")
		elif frame == 130:
			_release_inputs()
		await _frames(1)
		var state := actor.get_debug_state()
		values.append([actor.position.x, actor.position.y, actor.position.z, actor.velocity.x, actor.velocity.y, actor.velocity.z, state.fatigue, state.posture_index, state.air_speed_cap, state.camera_fov])
	return values


func _run_jump() -> void:
	await _reset()
	Input.action_press("move_forward")
	Input.action_press("run")
	await _frames(80)
	await _pulse("jump")
	await _frames(6)


func _test_main_tab() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	for body in main.get_node("Characters").get_children():
		body.procedural_enabled = false
	main.set("capture_mouse_on_start", false)
	root.add_child(main)
	await _frames(8)
	var first: AtlasCharacter = main.get_node("Characters/AtlasA")
	var second: AtlasCharacter = main.get_node("Characters/AtlasB")
	Input.action_press("move_forward")
	await _frames(60)
	var before: Dictionary = first.get_node("Feedback").call("get_debug_state")
	var first_steps := int(before.get("cue_counts", {}).get("step", 0))
	var event := InputEventKey.new()
	event.physical_keycode = KEY_TAB
	event.pressed = true
	root.push_input(event)
	await _frames(1)
	_expect(not first.is_controlled() and second.is_controlled(), "echte Tab draagt Charactercontrole over")
	_expect(String(first.get_node("Feedback").call("get_debug_state").get("route", "")) == "3d" and String(second.get_node("Feedback").call("get_debug_state").get("route", "")) == "local", "Tab draagt alleen lokale audiorouting over, met eigen histories")
	_expect(first_steps > 0 and int(first.get_node("Feedback").call("get_debug_state").get("cue_counts", {}).get("step", 0)) >= first_steps and int(second.get_node("Feedback").call("get_debug_state").get("cue_counts", {}).get("step", 0)) == 0, "Tab wist of kopieert de opgebouwde stapgeschiedenis niet")
	var first_enabled := bool(first.get("feedback_enabled"))
	var second_enabled := bool(second.get("feedback_enabled"))
	var toggle := InputEventKey.new()
	toggle.physical_keycode = KEY_F6
	toggle.pressed = true
	root.push_input(toggle)
	await _frames(1)
	_expect(bool(first.get("feedback_enabled")) == first_enabled and bool(second.get("feedback_enabled")) != second_enabled, "F6 schakelt alleen feedback van het actieve Character")
	root.push_input(toggle)
	await _frames(1)
	_expect(bool(second.get("feedback_enabled")) == second_enabled, "een volgende F6 herstelt de eigen feedbackinstelling")
	_release_inputs()
	main.queue_free()
	await _frames(2)


func _observe_cue(kind: String, route: String) -> void:
	cue_events.append({"kind": kind, "route": route})


func _observe_contact(frame: RefCounted) -> void:
	contacts.append({"landed": bool(frame.get("landed")), "sliding": bool(frame.get("sliding")), "incoming_y": Vector3(frame.get("incoming_velocity")).y})


func _last_impact() -> Dictionary:
	for index in range(contacts.size() - 1, -1, -1):
		if bool(contacts[index].landed):
			return contacts[index]
	return {}


func _last_route() -> String:
	return String(cue_events[-1].route) if not cue_events.is_empty() else ""


func _one_shot_voice(spatial: bool) -> Node:
	var prefix := "SpatialVoice" if spatial else "LocalVoice"
	for voice in feedback.get_children():
		if String(voice.name).begins_with(prefix) and bool(voice.get("playing")):
			return voice
	return null


func _any_voice_playing() -> bool:
	for voice in feedback.get_children():
		if (voice is AudioStreamPlayer or voice is AudioStreamPlayer3D) and bool(voice.get("playing")):
			return true
	return false


func _landing() -> void:
	for frame in 180:
		await _frames(1)
		if actor.is_on_floor():
			return
	_expect(false, "fixture moet werkelijk op de vloer landen")


func _reset() -> void:
	_release_inputs()
	actor.reset_to_spawn()
	actor.set_controlled(true)
	await _frames(8)


func _state() -> Dictionary:
	return feedback.call("get_debug_state")


func _count(kind: String) -> int:
	return int(_state().get("cue_counts", {}).get(kind, 0))


func _flag(key: String) -> bool:
	return bool(actor.get_debug_state().get(key, false))


func _speed() -> float:
	return Vector2(actor.velocity.x, actor.velocity.z).length()


func _pulse(action: String) -> void:
	Input.action_press(action)
	await _frames(1)
	Input.action_release(action)
	await _frames(1)


func _frames(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame


func _release_inputs() -> void:
	for action in ACTIONS:
		Input.action_release(action)


func _box(position_at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = position_at
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
