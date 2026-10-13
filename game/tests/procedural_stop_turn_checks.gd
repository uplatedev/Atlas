extends "res://tests/procedural_torso_checks.gd"
## Stoppen mag een neutrale herplaatsing starten, maar geen borstreserve overslaan.
func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(200, 0.2, 200)
	collision.shape = shape
	floor_body.position.y = -0.1
	floor_body.add_child(collision)
	world.add_child(floor_body)
	actor = CHARACTER.instantiate() as AtlasCharacter
	actor.position = Vector3(0, 0.05, 0)
	world.add_child(actor)
	actor.set_controlled(true)
	presentation = actor.get_node("Presentation/ProceduralBody")
	actor.contact_frame_ready.connect(_capture)
	await _ticks(12)
	_neutral_replant_contract()
	for direction in [-1.0, 1.0]:
		for look_delay in [0, 3, 6, 9, 12]:
			await _stop_and_look(direction, look_delay)
	world.queue_free()
	await AUDIO_SHUTDOWN.drain(self)
	for failure in failures:
		printerr("FAIL: ", failure)
	print("PROCEDURAL STOP TURN: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)

func _neutral_replant_contract() -> void:
	var planner := AtlasTurnStepPlanner.new()
	planner.reset(0.0)
	var rest: Array[Vector3] = [Vector3(-0.1, 0, 0), Vector3(0.1, 0, 0)]
	var contacts: Array[Vector3] = [Vector3(-0.1, 0, 0.3), rest[1]]
	planner.request_replant(0)
	var greatest_waiting_yaw := 0.0
	var neutral_contacts := 0
	for tick in 35:
		planner.advance(DT, deg_to_rad(120.0), true, Vector3.ZERO, rest, contacts, false)
		if tick == 0:
			_expect(planner.destination().distance_to(rest[0]) < 0.0001, "herplantdoel ligt op de huidige yaw en niet op de nieuwe blikrichting")
		greatest_waiting_yaw = maxf(greatest_waiting_yaw, absf(planner.pose_yaw))
		if planner.landed_side >= 0:
			contacts[planner.landed_side] = planner.destination()
			neutral_contacts += 1
	_expect(neutral_contacts > 0, "vrije voet kan neutraal herplaatsen terwijl de borst nog wacht")
	_expect(greatest_waiting_yaw < 0.001, "neutrale herplaatsing geeft geen toestemming voor een draaibijstap")
	for tick in 30:
		planner.advance(DT, deg_to_rad(120.0), true, Vector3.ZERO, rest, contacts, true)
		if planner.landed_side >= 0:
			contacts[planner.landed_side] = planner.destination()
	_expect(absf(planner.pose_yaw) > deg_to_rad(40.0), "na borsttoestemming kan de nieuwe draai doorgaan")
	print("STOP REPLANT neutral_contacts=", neutral_contacts, " yaw_while_waiting=", rad_to_deg(greatest_waiting_yaw))

func _stop_and_look(direction: float, look_delay: int) -> void:
	await _reset()
	stationary_check = false
	_send(0.0, Vector2(0, -1))
	await _ticks(30)
	_send(0.0)
	var violations := 0
	var neutral_steps := 0
	var turning_steps := 0
	var first_chest := -1.0
	var started_turn := false
	for tick in 120:
		if tick == look_delay:
			_send(direction * deg_to_rad(120.0))
		await _ticks(1)
		var planner: AtlasTurnStepPlanner = presentation.get("_turn_planner")
		if planner.started_side < 0:
			continue
		var yaw_change := absf(wrapf(planner.get("_target_yaw") - planner.get("_from_yaw"), -PI, PI))
		if yaw_change < deg_to_rad(1.0):
			neutral_steps += 1
			continue
		turning_steps += 1
		if not started_turn:
			var skeleton: Skeleton3D = presentation.get("_skeleton")
			presentation.apply_skeleton_pose(skeleton)
			first_chest = absf(wrapf(_bone_yaw(skeleton, presentation.get("_spine")) - _bone_yaw(skeleton, presentation.get("_pelvis")), -PI, PI))
			if first_chest < deg_to_rad(23.5):
				violations += 1
			started_turn = true
	_expect(violations == 0, "stoppen plus grote blik bewaart borstreserve vóór de eerste nieuwe draaibijstap")
	_expect(absf(float(presentation.get_debug_state().turn_body_offset)) < deg_to_rad(actor.body_profile.turn_step_angle_degrees * 0.38 + 0.2), "stop-en-draai eindigt met begrensde comfortabele asymmetrie")
	print("STOP LOOK direction=", direction, " delay=", look_delay, " neutral_steps=", neutral_steps, " turning_steps=", turning_steps, " first_turn_chest=", rad_to_deg(first_chest), " violations=", violations)