extends SceneTree
## Echte capsule, kijkinvoer en meshbijstappen; geen gesimuleerde contactframes.
const CHARACTER = preload("res://characters/Character.tscn")
const AUDIO_SHUTDOWN = preload("res://tests/test_audio_shutdown.gd")
const DT := 1.0 / 60.0
var world: Node3D
var actor: AtlasCharacter
var presentation: AtlasCharacterPresentation
var failures: Array[String] = []
var frames: Array[AtlasCharacterContactFrame] = []
var previous_targets: Array = []
var previous_locks: Array = []
var max_foot_delta: float = 0.0
var min_separation: float = INF
var max_lift: float = 0.0
var crossing_frames: int = 0
var lock_drift: float = 0.0
var max_queries: int = 0
var stationary_check: bool = true
var serials: Array[int] = []
var sides: Array[int] = []

func _initialize() -> void:
	call_deferred("_run")

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
	await _head_then_body()
	await _head_pitch_during_turn()
	await _quiet_asymmetric_stance()
	for target in [PI * 0.5, -PI * 0.5, PI, -PI]:
		await _turn_to(target)
	for direction in [-1.0, 1.0]:
		await _continuous_turn(direction, TAU)
		await _continuous_turn(direction, TAU * 2.0)
	await _reverse()
	await _walk_transition()
	await _walk_start_alignment()
	for body in range(3):
		var profile := AtlasCharacterBodyProfile.new()
		profile.test_body = body
		actor.body_profile = profile
		await _ticks(3)
		await _turn_to(PI)
	_expect(max_queries <= 2, "bijstappen gebruikt hoogstens de twee bestaande lokale voetmetingen")
	print("TURN METRICS maximum queries=", max_queries)
	world.queue_free()
	await AUDIO_SHUTDOWN.drain(self)
	for failure in failures:
		printerr("FAIL: ", failure)
	print("PROCEDURAL TURN: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)

func _head_then_body() -> void:
	await _reset()
	_send(deg_to_rad(30.0))
	await _ticks(20)
	var state := presentation.get_debug_state()
	_expect(absf(actor.rotation.y) < 0.001 and int(state.turn_step_index) == 0, "kleine blik draait eerst hoofd/romp zonder capsule of voeten")
	_expect(float(state.turn_torso_yaw) > deg_to_rad(12.0) and float(state.turn_torso_yaw) < deg_to_rad(22.0), "romp benut merkbare maar begrensde rotatie vóór bijstappen")
	_expect(absf(float(presentation.get("_head_yaw")) - deg_to_rad(30.0)) < 0.001, "hoofd behoudt gevraagde blik")
	_send(deg_to_rad(100.0))
	await _ticks(90)
	_expect(int(presentation.get_debug_state().turn_step_index) >= 1, "grotere blik volgt met een echte duidelijke bijstap")
	_check_stationary("head-body-foot sequence")

func _quiet_asymmetric_stance() -> void:
	for direction in [-1.0, 1.0]:
		await _reset()
		_send(direction * deg_to_rad(90.0))
		var max_support_rotation := 0.0
		var biggest_step := 0.0
		var previous: Array[float] = [0.0, 0.0]
		for tick in 100:
			await _ticks(1)
			var planner: AtlasTurnStepPlanner = presentation.get("_turn_planner")
			if planner.active_side >= 0:
				var support := 1 - planner.active_side
				max_support_rotation = maxf(max_support_rotation, absf(wrapf(planner.foot_yaws[support] - previous[support], -PI, PI)))
			if planner.started_side >= 0:
				biggest_step = maxf(biggest_step, absf(wrapf(planner.get("_target_yaw") - planner.get("_from_yaw"), -PI, PI)))
			previous.assign(planner.foot_yaws)
		var state := presentation.get_debug_state()
		var feet: Array = state.foot_targets.duplicate()
		var yaw_gap := absf(wrapf(state.turn_foot_yaws[1] - state.turn_foot_yaws[0], -PI, PI))
		var count: int = state.turn_step_index
		for tick in 180:
			_send(direction * deg_to_rad(90.0 + sin(float(tick) * 0.11) * 3.0))
			await _ticks(1)
		_expect(count == 1, "negentig graden kijken vraagt één duidelijke stap in plaats van opruimpasjes")
		_expect(biggest_step >= deg_to_rad(60.0), "de afzonderlijke draaistap heeft een duidelijke grote hoek")
		_expect(yaw_gap >= deg_to_rad(60.0), "comfortabele ongelijke voetrichtingen blijven na de draai bestaan")
		_expect(max_support_rotation < 0.0001, "steunvoet behoudt ook zijn oude oriëntatie tijdens de vrije stap")
		_expect(int(presentation.get_debug_state().turn_step_index) == count, "kleine blikvariatie veroorzaakt geen neutrale correctiestap")
		for side in range(2):
			_expect(Vector3(presentation.get_debug_state().foot_targets[side]).distance_to(feet[side]) < 0.0001, "ruststand bewaart beide echte voetpins")
		print("QUIET TURN direction=", direction, " steps=", count, " step_angle=", rad_to_deg(biggest_step), " resting_spread=", rad_to_deg(yaw_gap), " support_rotation=", max_support_rotation)
		_send(-direction * deg_to_rad(90.0))
		await _ticks(120)
		var reversed := presentation.get_debug_state()
		_expect(int(reversed.turn_active_side) == -1 and absf(float(reversed.turn_body_offset)) < deg_to_rad(actor.body_profile.turn_step_angle_degrees * 0.38 + 0.2), "tegenrichting vanuit scheve rust kiest een bereikbare volgende voet")
		_expect(crossing_frames == 0 and lock_drift < 0.0001 and max_foot_delta < 0.10, "tegenrichting vanuit scheve rust bewaart pins en gescheiden voetbanen")
		print("QUIET REVERSE direction=",direction," contacts=",serials.size()," crossing=",crossing_frames," pin_drift=",lock_drift)

func _head_pitch_during_turn() -> void:
	var max_error := 0.0
	var max_offset := 0.0
	for pitch in [deg_to_rad(25.0), deg_to_rad(-25.0)]:
		await _reset()
		_send(deg_to_rad(150.0), Vector2.ZERO, false, pitch)
		for tick in 36:
			await _ticks(1)
			var skeleton: Skeleton3D = presentation.get("_skeleton")
			var head: int = presentation.get("_head")
			presentation.apply_skeleton_pose(skeleton)
			var actual := (skeleton.global_basis * skeleton.get_bone_global_pose(head).basis * skeleton.get_bone_global_rest(head).basis.inverse()).orthonormalized()
			var yaw: float = actor.rotation.y + float(presentation.get("_head_yaw"))
			var expected := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, actor.get_look_input().y)
			max_error = maxf(max_error, actual.get_rotation_quaternion().angle_to(expected.get_rotation_quaternion()))
			max_offset = maxf(max_offset, absf(float(presentation.get_debug_state().turn_body_offset)))
	_expect(max_offset > deg_to_rad(45.0), "hoofdbasisproef bevat echte grote achterstand tijdens bijstappen")
	_expect(max_error < deg_to_rad(0.2), "op/neer kijken blijft pitch zonder scheef hoofd tijdens bijstappen")
	print("HEAD TURN basis error degrees=", rad_to_deg(max_error), " maximum body offset=", rad_to_deg(max_offset))


func _turn_to(target: float) -> void:
	await _reset()
	_send(target)
	await _ticks(130)
	_check_stationary("turn %.0f" % rad_to_deg(target))
	var state := presentation.get_debug_state()
	_expect(absf(float(state.turn_body_offset)) < deg_to_rad(actor.body_profile.turn_step_angle_degrees * 0.38 + 0.2) and int(state.turn_active_side) == -1, "bijstappen eindigen binnen de comfortabele hoekreserve")
	_expect(absf(wrapf(actor.get_look_input().x - target, -PI, PI)) < 0.001, "turnplanner verandert geen logische kijkinvoer")

func _continuous_turn(direction: float, amount: float) -> void:
	await _reset()
	var count := ceili(amount / deg_to_rad(120.0) / DT)
	for tick in count:
		_send(direction * amount * float(tick + 1) / count)
		await _ticks(1)
	await _ticks(140)
	_check_stationary("continuous %.0f" % rad_to_deg(direction * amount))
	var state := presentation.get_debug_state()
	_expect(absf(float(state.turn_body_offset)) < deg_to_rad(actor.body_profile.turn_step_angle_degrees * 0.38 + 0.2) and absf(float(state.turn_pose_yaw)) <= PI + 0.001, "360/720 graden bewaren geen opgetelde draai-offset")
	var completed := int(state.turn_step_index)
	await _ticks(40)
	_expect(int(presentation.get_debug_state().turn_step_index) == completed, "stoppen laat geen wachtrij van oude bijstappen doorlopen")

func _reverse() -> void:
	await _reset()
	_send(PI * 0.85)
	await _ticks(8)
	_send(-PI * 0.65)
	await _ticks(130)
	_check_stationary("abrupt reversal")
	_expect(absf(float(presentation.get_debug_state().turn_body_offset)) < deg_to_rad(actor.body_profile.turn_step_angle_degrees * 0.38 + 0.2), "plots tegenrichting voltooit begrensde huidige voet en volgt laatste wens")

func _walk_transition() -> void:
	for delay in [2, 7, 12]:
		await _reset()
		_send(PI * 0.8)
		await _ticks(delay)
		stationary_check = false
		max_foot_delta = 0.0
		_send(PI * 0.8, Vector2(0, -1), true)
		for tick in 65:
			await _ticks(1)
			if tick == 0:
				_expect(max_foot_delta < 0.10, "startlopen tijdens bijstap plant geen verre voetvoorspelling")
		var state := presentation.get_debug_state()
		_expect(absf(float(state.turn_body_offset)) < 0.01 and int(state.turn_active_side) == -1, "lopen uit bijstap ruimt visuele draai op")
		_expect(Vector2(actor.velocity.x, actor.velocity.z).length() > 8.0, "bijstappen verandert runmotor niet")
		print("TURN WALK delay=", delay, " largest foot delta=", max_foot_delta)
		max_foot_delta = 0.0
		_send(PI * 0.8)
		await _ticks(100)
		_expect(max_foot_delta < 0.30, "stoppen gebruikt actuele voetposities en geen oude contactteleport")
		print("TURN STOP delay=", delay, " largest foot delta=", max_foot_delta)
		stationary_check = true
		previous_targets.clear()
		previous_locks.clear()
		await _ticks(60)
		_expect(int(presentation.get_debug_state().turn_active_side) == -1, "stoppen na lopen laat bijstappen uitrusten")

func _walk_start_alignment() -> void:
	for degrees in [120.0, -120.0, 180.0, -180.0]:
		for delay in [2, 6, 12]:
			await _reset()
			_send(deg_to_rad(degrees))
			await _ticks(delay)
			stationary_check = false
			max_foot_delta = 0.0
			var smallest_gap := INF
			var smallest_bone_gap := INF
			var smallest_old_axis_gap := INF
			var lag_after_nine := 0.0
			var planted_drift := 0.0
			var sole_error := 0.0
			var sole_drift := 0.0
			var rolling_samples := 0
			var previous_soles: Array[Vector3] = []
			var previous_pivots: Array[int] = []
			_send(deg_to_rad(degrees), Vector2(0, -1))
			for tick in 30:
				var before: Dictionary = presentation.get_debug_state()
				var before_contacts: Array = presentation._contacts.duplicate()
				await _ticks(1)
				var state := presentation.get_debug_state()
				var old_right := Basis(Vector3.UP, float(state.turn_pose_yaw)).x
				smallest_old_axis_gap = minf(smallest_old_axis_gap, (Vector3(state.foot_targets[1]) - Vector3(state.foot_targets[0])).dot(old_right))
				var skeleton: Skeleton3D = presentation.get("_skeleton")
				presentation.apply_skeleton_pose(skeleton)
				var legs: Array = presentation.get("_legs")
				# Meet dwars op de echte heupen: diagonale gangen hebben een eigen yaw
				# boven op de bijstaprichting. De capsule-/turn-as is dan verouderd.
				var left_hip := skeleton.global_transform * skeleton.get_bone_global_pose(legs[0][0]).origin
				var right_hip := skeleton.global_transform * skeleton.get_bone_global_pose(legs[1][0]).origin
				var right := (right_hip - left_hip).normalized()
				smallest_gap = minf(smallest_gap, (Vector3(state.foot_targets[1]) - Vector3(state.foot_targets[0])).dot(right))
				var left := skeleton.global_transform * skeleton.get_bone_global_pose(legs[0][2]).origin
				var right_ankle := skeleton.global_transform * skeleton.get_bone_global_pose(legs[1][2]).origin
				smallest_bone_gap = minf(smallest_bone_gap, (right_ankle - left).dot(right))
				var soles: Array[Vector3] = []
				var pivots: Array[int] = []
				for side in 2:
					var foot_pose := skeleton.get_bone_global_pose(legs[side][2])
					var ankle := skeleton.global_transform * foot_pose.origin
					var rolling := absf(presentation._foot_roll[side]) > 0.00001
					var pivot := (1 if presentation._foot_roll[side] > 0.0 else -1) if rolling else 0
					var pivot_z: float = presentation._toe_lengths[side] * (0.25 if pivot == 1 else -1.0) if rolling else 0.0
					# De echte zool wordt uit het voetbot gereconstrueerd: de enkel mag om dit punt rollen.
					var rest_offset: Vector3 = presentation._rest_foot_basis[side].inverse() * Vector3(0, -presentation._ankle_height, pivot_z)
					var sole := ankle + skeleton.global_basis * foot_pose.basis * rest_offset
					soles.append(sole)
					pivots.append(pivot)
					if state.locked_feet[side]:
						var ground: Vector3 = presentation._foot_pivots[side] if rolling else presentation._contacts[side]
						sole_error = maxf(sole_error, sole.distance_to(ground))
						rolling_samples += 1 if rolling else 0
						if before.locked_feet[side] and frames[-1].foot_contacts.is_empty() and not previous_soles.is_empty() and previous_pivots[side] == pivot:
							sole_drift = maxf(sole_drift, sole.distance_to(previous_soles[side]))
				previous_soles.assign(soles)
				previous_pivots.assign(pivots)
				skeleton.reset_bone_poses()
				if tick == 0:
					_expect(max_foot_delta < 0.10, "eerste loopframe plant bijstapvoet zonder verre sprong")
				if tick == 8:
					lag_after_nine = absf(rad_to_deg(float(state.turn_body_offset)))
					_expect(lag_after_nine < 5.0, "bekken sluit binnen negen loopframes aan na grote draai")
				if tick > 0 and frames[-1].foot_contacts.is_empty():
					for side in range(2):
						if before.locked_feet[side] and state.locked_feet[side]:
							planted_drift = maxf(planted_drift, Vector3(before_contacts[side]).distance_to(presentation._contacts[side]))
			_expect(smallest_gap > 0.015 and smallest_bone_gap > 0.015, "vrije voet en werkelijk enkelbot kruisen steunbeen niet bij loopoverdracht")
			_expect(planted_drift < 0.0001, "overdracht corrigeert alleen vrije voeten en bewaart bestaand steuncontact")
			_expect(rolling_samples > 0 and sole_error < 0.003 and sole_drift < 0.003, "echte zoolpivot blijft wereldvast tijdens afrol na bijstapoverdracht")
			_expect(max_foot_delta < 0.25, "hele loopoverdracht houdt voetverplaatsing begrensd")
			_expect(absf(float(presentation.get_debug_state().turn_body_offset)) < 0.001, "overdracht bewaart geen blijvende visuele draai")
			print("TURN START degrees=", degrees, " delay=", delay, " lag9=", lag_after_nine, " target_gap=", smallest_gap, " ankle_gap=", smallest_bone_gap, " old_axis_gap=", smallest_old_axis_gap, " planted_drift=", planted_drift, " sole_error=", sole_error, " sole_drift=", sole_drift, " rolls=", rolling_samples, " foot_delta=", max_foot_delta)
			await _ticks(30)
			_expect(float(presentation.get("_turn_release_remaining")) == 0.0, "loopoverdracht eindigt en laat de gewone pasplanner volledig vrij")
func _check_stationary(label: String) -> void:
	var state := presentation.get_debug_state()
	_expect(crossing_frames == 0, "voeten kruisen niet tijdens " + label)
	_expect(lock_drift < 0.0001, "geplante steunvoet blijft wereldvast tijdens " + label)
	_expect(max_foot_delta < 0.10, "bijstap heeft geen zichtbare doelteleport tijdens " + label)
	_expect(max_lift > 0.02 and serials.size() >= 1, "bijstap heft en plant voeten aantoonbaar tijdens " + label)
	_expect(actor.position.distance_to(Vector3(0, actor.position.y, 0)) < 0.001 and actor.is_on_floor(), "stationaire draai verplaatst de capsule niet")
	_expect(float(state.max_planted_error) < 0.01, "werkelijke steunvoet blijft binnen bereik bij " + label)
	for index in range(1, serials.size()):
		_expect(serials[index] == serials[index - 1] + 1, "bijstapcontact heeft één eigen oplopend serienummer")
		_expect(sides[index] != sides[index - 1], "bijstap wisselt links/rechts af")
	print("TURN ", label, " steps=", serials.size(), " crossing=", crossing_frames, " min_side=", min_separation, " foot_delta=", max_foot_delta, " lift=", max_lift, " lock_drift=", lock_drift, " offset=", state.turn_body_offset)

func _capture(frame: AtlasCharacterContactFrame) -> void:
	frames.append(frame)
	var state := presentation.get_debug_state()
	max_queries = maxi(max_queries, int(state.rays_last_frame))
	var targets: Array = state.foot_targets
	var locks: Array = state.locked_feet
	if stationary_check and frame.supported and frame.horizontal_speed < 0.1:
		var inverse := Basis(Vector3.UP, float(state.turn_pose_yaw)).inverse()
		for side in range(2):
			var relative: Vector3 = inverse * (Vector3(targets[side]) - actor.position)
			var signed_x := relative.x * (-1.0 if side == 0 else 1.0)
			min_separation = minf(min_separation, signed_x)
			crossing_frames += 1 if signed_x < 0.01 else 0
			max_lift = maxf(max_lift, Vector3(targets[side]).y - float(presentation.get("_ankle_height")))
		_expect(locks[0] or locks[1], "bijstap bewaart altijd minstens één echte steunvoet")
	if previous_targets.size() == 2:
		for side in range(2):
			max_foot_delta = maxf(max_foot_delta, Vector3(targets[side]).distance_to(previous_targets[side]))

			if stationary_check and bool(locks[side]) and bool(previous_locks[side]) and not frame.turn_step_landed:
				lock_drift = maxf(lock_drift, Vector3(targets[side]).distance_to(previous_targets[side]))
	previous_targets = targets.duplicate()
	previous_locks = locks.duplicate()
	if frame.turn_step_landed:
		_expect(frame.supported and frame.foot_contacts.size() == 1 and not frame.stride_landed and not frame.jumped, "bijstap cue volgt één geaccepteerd gesteund voetcontact")
		serials.append(frame.turn_step_index)
		sides.append(int(presentation.get("_turn_planner").landed_side))

func _reset() -> void:
	_send(0.0)
	actor.reset_to_spawn()
	actor.set_look_input(0.0, 0.0)
	await _ticks(15)
	frames.clear()
	serials.clear()
	sides.clear()
	previous_targets.clear()
	previous_locks.clear()
	max_foot_delta = 0.0
	min_separation = INF
	max_lift = 0.0
	crossing_frames = 0
	lock_drift = 0.0
	stationary_check = true

func _send(yaw: float, movement: Vector2 = Vector2.ZERO, run: bool = false, pitch: float = 0.0) -> void:
	var intent := AtlasCharacterIntent.new()
	intent.movement = movement
	intent.run = run
	intent.has_look_direction = true
	intent.look_direction = Vector2(yaw, pitch)
	actor.submit_intent(intent)

func _ticks(count: int) -> void:
	for tick in count:
		await physics_frame
		await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
