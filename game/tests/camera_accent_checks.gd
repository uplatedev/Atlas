extends SceneTree
## T-009: echte contacten/vaart, veilige view en ongewijzigde logische besturing.

const CHARACTER = preload("res://characters/Character.tscn")
const AUDIO_SHUTDOWN = preload("res://tests/test_audio_shutdown.gd")
const ACTIONS = ["move_forward", "move_back", "move_left", "move_right", "sprint", "sneak", "crouch", "prone", "jump"]
var failures: Array[String] = []
var world: Node3D
var actor: AtlasCharacter
var launch: Dictionary = {}
var supported_contact: AtlasCharacterContactFrame
var landing_contact: AtlasCharacterContactFrame


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	_box(Vector3(0, -0.1, 0), Vector3(400, 0.2, 400))
	actor = CHARACTER.instantiate() as AtlasCharacter
	actor.position = Vector3(0, 0.05, 0)
	world.add_child(actor)
	actor.set_controlled(true)
	actor.jump_accepted.connect(_observe_jump)
	actor.contact_frame_ready.connect(_observe_contact)
	var startup_peak := 0.0
	for frame in 8:
		await _frames(1)
		startup_peak = maxf(startup_peak, float(_state().camera_landing_amount))
	_expect(startup_peak < 0.000001, "eerste startupcontactframes geven geen valse pulse")
	await _test_landing_envelope()
	await _test_supported_transitions()
	await _test_air_view_resets()
	await _test_render_pulse_rates()
	await _test_pulse_interruptions()
	await _test_fov_profiles()
	await _test_ground_slide_view()
	await _test_collision_volume()
	await _test_history_and_instances()
	_test_saved_overrides()
	await _test_physics_and_look()
	_release_inputs()
	world.queue_free()
	await process_frame
	await _test_main_toggles()
	await AUDIO_SHUTDOWN.drain(self)
	if failures.is_empty():
		print("PASS: landingsaccent, actuele lucht-/slide-FOV, collisionvolume, histories, opgeslagen overrides en physics/kijkpariteit.")
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: ", failure)
		quit(1)


func _test_landing_envelope() -> void:
	_expect(absf(float(actor.get("camera_first_person_landing_max_dip"))) < 0.000001, "first-personaccent is standaard nul")
	for first_person in [false, true]:
		await _reset()
		actor.set_camera_distance(0.0 if first_person else 4.0)
		await _frames(40)
		await _pulse("jump")
		await _landing()
		var amounts: Array[float] = []
		var peak := 0.0
		var peak_index := 0
		for frame in 36:
			await _frames(1)
			var state := _state()
			var amount := float(state.camera_landing_amount)
			amounts.append(amount)
			if amount > peak:
				peak = amount
				peak_index = frame
			_expect(Vector3(state.camera_accent_offset).length() <= float(actor.get("camera_accent_max_offset")) + 0.00001, "gecombineerd accent blijft binnen zijn meterbudget")
			_expect(Vector3(state.camera_total_pose_offset).length() <= actor.camera_follow_max_lag + 0.00001, "vrije totale camerapose blijft binnen volg-/accentbudget")
			_expect(Vector3(state.camera_landing_offset).y <= 0.000001, "landing beweegt alleen kort neerwaarts")
		if first_person:
			_expect(peak < 0.000001, "echte first-personlanding voegt standaard geen dip toe")
		else:
			_expect(peak > 0.001 and peak <= float(actor.get("camera_landing_max_dip")) + 0.00001, "echte TP-impact bereikt een klein begrensd accent")
			for index in range(peak_index + 1, amounts.size()):
				_expect(amounts[index] <= amounts[index - 1] + 0.000001, "herstel na attackpiek verloopt zonder nieuwe overshoot")
			_expect(amounts[-1] < 0.00001, "landing keert zonder blijvende verschuiving terug")
		print("MEASURE: %s landingpiek %.6f m, piekframe %d, eind %.6f m." % ["FP" if first_person else "TP", peak, peak_index, amounts[-1]])


func _test_supported_transitions() -> void:
	_release_inputs()
	actor.reset_to_spawn()
	actor.set_controlled(true)
	var respawn_peak := 0.0
	for frame in 24:
		await _frames(1)
		respawn_peak = maxf(respawn_peak, float(_state().camera_landing_amount))
	_expect(respawn_peak < 0.000001, "alle eerste respawncontactframes blijven zonder valse pulse")
	var step := _box(Vector3(0, 0.15, -5), Vector3(8, 0.3, 8))
	Input.action_press("move_forward")
	var peak := 0.0
	for frame in 60:
		await _frames(1)
		peak = maxf(peak, float(_state().camera_landing_amount))
	_expect(actor.position.y > 0.29 and actor.position.z < -2.0 and peak < 0.000001, "echte grondopstap geeft geen valse impactdip")
	step.queue_free()
	await _frames(2)
	var radius := actor.crouch_capsule_radius
	var snap := actor.floor_snap_length
	actor.crouch_capsule_radius = 0.15
	actor.floor_snap_length = 0.0
	await _sprint_jump(80)
	await _pulse("crouch")
	await _landing()
	_rig().call("reset_follow_history")
	step = _box(actor.position + Vector3(0, 0.15, -2.6), Vector3(8, 0.3, 4))
	var virtual_only := false
	peak = 0.0
	for frame in 10:
		await _frames(1)
		virtual_only = virtual_only or (actor.get_camera_grounded() and not actor.is_on_floor())
		peak = maxf(peak, float(_state().camera_landing_amount))
	_expect(virtual_only and peak < 0.000001, "uitsluitend virtuele opstapsteun en vloerterugkeer geven geen nieuwe dip")
	step.queue_free()
	actor.crouch_capsule_radius = radius
	actor.floor_snap_length = snap
	await _frames(2)


func _test_air_view_resets() -> void:
	for reset_kind in ["view", "follow", "control"]:
		await _reset()
		await _pulse("jump")
		_expect(not actor.is_on_floor(), "viewresetfixture is werkelijk in vlucht")
		if reset_kind == "view":
			_rig().call("reset_view")
		elif reset_kind == "follow":
			_rig().call("reset_follow_history")
		else:
			actor.set_controlled(false)
			await _frames(2)
			actor.set_controlled(true)
		await _landing()
		await _frames(3)
		_expect(float(_state().camera_landing_amount) > 0.001, "%s reset in vlucht behoudt de eerstvolgende echte landingsreactie" % reset_kind)


func _test_render_pulse_rates() -> void:
	await _reset()
	await _pulse("jump")
	await _landing()
	_expect(supported_contact != null and landing_contact != null and landing_contact.incoming_velocity.y < -1.0, "renderproef gebruikt echt vastgelegde contact-/impactgegevens")
	actor.set_physics_process(false)
	_rig().set_process(false)
	actor.reset_physics_interpolation()
	var traces: Dictionary = {}
	for rate in [30, 60, 144]:
		_rig().call("reset_view", true)
		_rig().call("capture_contact", supported_contact)
		_rig().call("capture_contact", landing_contact)
		var elapsed := 0.0
		var samples: Array[float] = []
		var peak := 0.0
		for sample_time in [0.05, 0.10, 0.20, 0.30, 0.50]:
			while elapsed < sample_time - 0.00000001:
				var delta := minf(1.0 / float(rate), sample_time - elapsed)
				_rig().call("_process", delta)
				elapsed += delta
				var state := _state()
				peak = maxf(peak, float(state.camera_landing_amount))
				_expect(Vector3(state.camera_accent_offset).length() <= float(actor.get("camera_accent_max_offset")) + 0.00001 and Vector3(state.camera_total_pose_offset).length() <= actor.camera_follow_max_lag + 0.00001, "renderpulse %d Hz bewaart beide 3D-budgets" % rate)
			samples.append(float(_state().camera_landing_amount))
		traces[rate] = samples
		_expect(peak > 0.001 and peak <= float(actor.get("camera_landing_max_dip")) + 0.00001 and samples[-1] < 0.00001, "renderpulse %d Hz heeft begrensde piek en volledig herstel" % rate)
		print("MEASURE: landingspulse %d Hz piek %.6f m; samples %s." % [rate, peak, str(samples)])
	for rate in [30, 144]:
		for index in traces[60].size():
			_expect(absf(float(traces[rate][index]) - float(traces[60][index])) < 0.00001, "nieuwe pulse op %d Hz volgt dezelfde tijdcurve als 60 Hz" % rate)
	actor.set_physics_process(true)
	_rig().set_process(true)
	await _reset()


func _test_pulse_interruptions() -> void:
	await _reset()
	await _pulse("jump")
	await _landing()
	await _frames(3)
	_expect(float(_state().camera_landing_amount) > 0.001, "uitschakelproef begint tijdens een werkelijke pulse")
	actor.set("camera_landing_enabled", false)
	await _frames(2)
	_expect(float(_state().camera_landing_amount) < 0.000001, "uitschakelen stopt de lopende pulse")
	actor.set("camera_landing_enabled", true)
	await _frames(2)
	_expect(float(_state().camera_landing_amount) < 0.000001, "opnieuw aan hervat een gewiste oude pulse niet")
	await _reset()
	await _pulse("jump")
	await _landing()
	await _frames(3)
	actor.global_position += Vector3(5, 0, 0)
	actor.reset_physics_interpolation()
	await _frames(2)
	_expect(float(_state().camera_landing_amount) < 0.000001, "echte teleport wist de oude impactgeschiedenis")
	var audio_enabled := bool(actor.get("feedback_enabled"))
	actor.set("feedback_enabled", false)
	await _reset()
	await _pulse("jump")
	await _landing()
	await _frames(3)
	_expect(float(_state().camera_landing_amount) > 0.001, "audio uit onderdrukt een echte camera-impact niet")
	actor.set("feedback_enabled", audio_enabled)
	await _reset()


func _test_fov_profiles() -> void:
	await _sprint_jump(16)
	var mix := clampf((float(launch.speed) - float(launch.walk)) / (float(launch.sprint) - float(launch.walk)), 0.0, 1.0)
	_expect(float(actor.get_debug_state().jump_boost) > 0.0 and _speed() > float(launch.speed), "gedeeltelijke sprintafzet bevat een echte horizontale bonus")
	_expect(absf(float(_state().camera_air_launch_mix) - mix) < 0.00001 and float(_state().camera_air_fov_mix) <= mix + 0.00001, "lucht-FOV gebruikt afzet vóór bonus en overschrijdt die mix niet")
	await _sprint_jump(80)
	var fov_before := float(_state().camera_fov)
	var speed_before := _speed()
	Input.action_release("move_forward")
	Input.action_press("move_back")
	await _frames(18)
	_expect(not actor.is_on_floor() and _speed() < speed_before and float(_state().camera_air_fov_mix) < float(_state().camera_air_launch_mix), "echte S-luchtrem bouwt de FOV-mix af")
	_expect(float(_state().camera_fov) < fov_before - 0.1, "lens keert tijdens luchtrem vloeiend smaller terug")
	await _sprint_jump(80)
	await _pulse("crouch")
	await _landing()
	await _frames(1)
	var slide_offset := float(_state().camera_slide_fov_offset)
	_expect(_flag("slide_active") and slide_offset > 0.1 and slide_offset <= float(actor.get("camera_slide_fov_bonus")) + 0.001 and float(_state().camera_target_fov) > 67.0, "snelle echte slide voegt begrensde vaart-FOV toe boven kruipbasis")
	actor.camera_speed_fov_enabled = false
	await _frames(1)
	_expect(absf(float(_state().camera_target_fov) - 70.0) < 0.001, "FOV-uit houdt volledige TP-basis zonder profielaccenten")
	actor.camera_speed_fov_enabled = true
	actor.set("camera_fov_refinement_enabled", false)
	await _frames(1)
	_expect(absf(float(_state().camera_target_fov) - 67.0) < 0.001, "refinement-uit bewaart oude slide/kruip-FOV")
	actor.set("camera_fov_refinement_enabled", true)
	await _frames(12)
	_expect(float(_state().camera_slide_fov_offset) < slide_offset, "slide-FOV zwakt af met de werkelijke grondvaart")
	actor.set_camera_distance(0.0)
	await _frames(1)
	_expect(float(_state().camera_slide_fov_offset) > 0.0 and float(_state().camera_slide_fov_offset) <= float(actor.get("camera_first_person_slide_fov_bonus")) + 0.001, "FP-slide heeft zijn eigen kleinere bonus")


func _test_ground_slide_view() -> void:
	await _reset()
	actor.set_camera_distance(4.0)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(80)
	await _pulse("crouch")
	await _frames(1)
	var initial_offset := float(_state().camera_slide_fov_offset)
	_expect(_flag("slide_active") and initial_offset > 0.1 and initial_offset <= float(actor.get("camera_slide_fov_bonus")) + 0.001, "sprintgrondslide gebruikt direct dezelfde begrensde vaart-FOV")
	var peak := 0.0
	for frame in 12:
		await _frames(1)
		peak = maxf(peak, float(_state().camera_landing_amount))
	_expect(_flag("slide_active") and float(_state().camera_slide_fov_offset) < initial_offset, "grondslide-FOV neemt af met de werkelijke geremde vaart")
	_expect(peak < 0.000001, "grondslide vanuit blijvende steun geeft geen valse camera-landingsdip")


func _test_collision_volume() -> void:
	var saved: Dictionary = {}
	var settings := {"camera_eye_height": 0.1, "camera_start_pitch": 0.0, "camera_collision_radius": 0.01, "camera_fov_third_person": 100.0, "camera_fov_first_person": 100.0, "camera_landing_max_dip": 0.04}
	for key in settings:
		saved[key] = actor.get(key)
		actor.set(key, settings[key])
	await _reset()
	var wall := _box(Vector3(0, 2.5, 1.0), Vector3(10, 5, 0.1))
	await _pulse("jump")
	var unsafe := false
	var protected_near_plane := true
	for frame in 110:
		await _frames(1)
		unsafe = unsafe or not _camera_volume_clear()
		var camera := _camera()
		var aspect := root.get_visible_rect().size.x / maxf(root.get_visible_rect().size.y, 1.0)
		var half_height := camera.near * tan(deg_to_rad(camera.fov * 0.5))
		var corner_radius := Vector3(half_height * aspect, half_height, camera.near).length()
		var sphere := actor.get_node("CameraPivot/SpringArm3D").shape as SphereShape3D
		protected_near_plane = protected_near_plane and sphere.radius >= corner_radius
	_expect(not unsafe and protected_near_plane, "grote FOV en kleine gewenste radius beschermen beeldrand/grond/wand tijdens jump en landing")
	wall.queue_free()
	await _reset()
	actor.request_posture(2)
	await _frames(3)
	var roof := _box(Vector3(0, 0.9, 0), Vector3(8, 0.2, 12))
	unsafe = false
	for frame in 60:
		await _frames(1)
		unsafe = unsafe or not _camera_volume_clear()
	_expect(actor.get_posture() == 2 and not unsafe, "lage ligdoorgang houdt de grote-FOV-camera buiten vloer en plafond")
	roof.queue_free()
	for key in saved:
		actor.set(key, saved[key])
	await _reset()


func _test_history_and_instances() -> void:
	await _reset()
	var other: AtlasCharacter = CHARACTER.instantiate()
	other.position = Vector3(20, 0.05, 0)
	other.set("camera_landing_max_dip", 0.007)
	world.add_child(other)
	await _frames(8)
	await _pulse("jump")
	await _landing()
	await _frames(3)
	_expect(float(_state().camera_landing_amount) > 0.0 and float(other.get_node("CameraPivot").call("get_state").camera_landing_amount) == 0.0, "landingsgeschiedenis en instellingen zijn per instance afzonderlijk")
	actor.set_controlled(false)
	other.set_controlled(true)
	_expect(float(other.get_node("CameraPivot").call("get_state").camera_landing_amount) == 0.0, "controlewisseling erft geen landingsdip van de vorige view")
	other.set_controlled(false)
	actor.set_controlled(true)
	_expect(float(_state().camera_landing_amount) == 0.0, "terugwisselen hergebruikt geen oude impact")
	actor.reset_to_spawn()
	_expect(float(_state().camera_landing_amount) == 0.0 and Vector3(_state().camera_accent_offset).is_zero_approx(), "spawnreset wist effectgeschiedenis")
	other.queue_free()
	await _frames(2)


func _test_saved_overrides() -> void:
	var holder := Node3D.new()
	for index in 2:
		var child: AtlasCharacter = CHARACTER.instantiate()
		child.name = "Actor%d" % index
		holder.add_child(child)
		child.owner = holder
		child.set("camera_landing_max_dip", 0.007 if index == 0 else 0.014)
		child.set("camera_slide_fov_bonus", 2.2 if index == 0 else 4.1)
		child.set("camera_fov_refinement_enabled", index == 0)
	var packed := PackedScene.new()
	var path := "user://T009-camera-overrides-%d.tscn" % OS.get_process_id()
	_expect(packed.pack(holder) == OK and ResourceSaver.save(packed, path) == OK, "twee camera-overrides zijn als scene op te slaan")
	holder.free()
	var reloaded := load(path) as PackedScene
	if reloaded != null:
		var scene := reloaded.instantiate()
		var first := scene.get_node("Actor0")
		var second := scene.get_node("Actor1")
		_expect(absf(float(first.get("camera_landing_max_dip")) - 0.007) < 0.000001 and absf(float(second.get("camera_landing_max_dip")) - 0.014) < 0.000001 and float(first.get("camera_slide_fov_bonus")) != float(second.get("camera_slide_fov_bonus")) and bool(first.get("camera_fov_refinement_enabled")) != bool(second.get("camera_fov_refinement_enabled")), "herladen bewaart verschillende rootinstellingen")
		first.set("camera_landing_max_dip", 0.02)
		_expect(absf(float(second.get("camera_landing_max_dip")) - 0.014) < 0.000001, "wijzigen na herladen raakt alleen gekozen instance")
		scene.free()
	else:
		_expect(false, "opgeslagen camera-overrides kunnen worden herladen")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_physics_and_look() -> void:
	var enabled: Array = await _physics_trace(true)
	var disabled: Array = await _physics_trace(false)
	var maximum := 0.0
	for index in mini(enabled.size(), disabled.size()):
		for component in enabled[index].size():
			maximum = maxf(maximum, absf(float(enabled[index][component]) - float(disabled[index][component])))
	_expect(enabled.size() == disabled.size() and maximum < 0.00001, "effecten aan/uit veranderen geen physics, fatigue, houding, jumpcap of logische hoofd/bodyrichting")
	print("MEASURE: cameraeffecten aan/uit %d frames, grootste physics/kijkverschil %.8f." % [enabled.size(), maximum])


func _physics_trace(enabled: bool) -> Array:
	actor.set("camera_landing_enabled", enabled)
	actor.set("camera_fov_refinement_enabled", enabled)
	await _reset(false)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	var values: Array = []
	for frame in 220:
		if frame == 15:
			_rig().call("apply_look_delta", Vector2(-200, 45))
		elif frame == 60:
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
		values.append([actor.position.x, actor.position.y, actor.position.z, actor.velocity.x, actor.velocity.y, actor.velocity.z, state.fatigue, state.posture_index, state.air_speed_cap, state.head_yaw, state.head_pitch, state.body_yaw])
	return values


func _test_main_toggles() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.set("capture_mouse_on_start", false)
	root.add_child(main)
	await _frames(8)
	var first: Node = main.get_node("Characters/AtlasA")
	var second: Node = main.get_node("Characters/AtlasB")
	await _pulse("jump")
	_expect(not first.is_on_floor(), "echte Tab-proef begint met een vliegend eerste Character")
	_key(KEY_TAB)
	await _frames(2)
	_key(KEY_TAB)
	await _frames(1)
	for frame in 180:
		await _frames(1)
		if first.is_on_floor():
			break
	await _frames(3)
	_expect(first.is_on_floor() and float(first.get_node("CameraPivot").call("get_state").camera_landing_amount) > 0.001, "Tab terug naar vliegende instance behoudt de volgende echte impact")
	_key(KEY_TAB)
	await _frames(1)
	for setting in {KEY_F7: "camera_landing_enabled", KEY_F9: "camera_fov_refinement_enabled"}:
		var field := String({KEY_F7: "camera_landing_enabled", KEY_F9: "camera_fov_refinement_enabled"}[setting])
		var before_first := bool(first.get(field))
		var before_second := bool(second.get(field))
		_key(setting)
		await _frames(1)
		_expect(bool(first.get(field)) == before_first and bool(second.get(field)) != before_second, "proeftoets %d wijzigt alleen de actieve camera-instelling" % setting)
		_key(setting)
		await _frames(1)
		_expect(bool(second.get(field)) == before_second, "volgende proeftoets herstelt de camera-instelling")
	main.queue_free()
	await _frames(2)


func _camera_volume_clear() -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = actor.get_node("CameraPivot/SpringArm3D").shape
	query.transform = Transform3D(Basis.IDENTITY, _camera().global_position)
	query.collision_mask = 3
	query.exclude = [actor.get_rid()]
	query.collide_with_areas = false
	return world.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _observe_jump(horizontal: Vector3, walk_limit: float, sprint_limit: float, _sneaking: bool) -> void:
	launch = {"speed": horizontal.length(), "walk": walk_limit, "sprint": sprint_limit}


func _observe_contact(frame: AtlasCharacterContactFrame) -> void:
	if not frame.landed and (not frame.supported or frame.jumped):
		return
	var copy := AtlasCharacterContactFrame.new()
	for field in ["delta", "horizontal_travel", "horizontal_speed", "incoming_velocity", "supported", "real_grounded", "motion_profile", "posture", "sliding", "jumped", "landed", "world_position"]:
		copy.set(field, frame.get(field))
	if frame.landed:
		landing_contact = copy
	else:
		supported_contact = copy


func _sprint_jump(frames: int) -> void:
	await _reset()
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(frames)
	await _pulse("jump")


func _landing() -> void:
	for frame in 180:
		await _frames(1)
		if actor.is_on_floor():
			return
	_expect(false, "fixture moet werkelijk landen")


func _reset(enable_variants: bool = true) -> void:
	_release_inputs()
	actor.reset_to_spawn()
	actor.set_controlled(true)
	actor.camera_speed_fov_enabled = true
	if enable_variants:
		actor.set("camera_landing_enabled", true)
		actor.set("camera_fov_refinement_enabled", true)
	await _frames(8)


func _state() -> Dictionary:
	return _rig().call("get_state")


func _rig() -> Node3D:
	return actor.get_node("CameraPivot") as Node3D


func _camera() -> Camera3D:
	return actor.get_node("CameraPivot/SpringArm3D/Camera3D") as Camera3D


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


func _key(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	root.push_input(event)


func _box(center: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = center
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
