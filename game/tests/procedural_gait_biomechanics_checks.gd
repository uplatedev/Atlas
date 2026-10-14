extends "res://tests/procedural_knee_checks.gd"
## Onafhankelijke uitkomstproef: echt contactritme, zoolpivot en directionele zijpas.
## Geen aanroep van get_gait_timing of FootPhase als verwachte uitkomst.
const SAMPLE_TICKS := 480
const DT := 1.0 / 60.0
var reports: Array = []

func _run() -> void:
	for mode in ["walk", "jog", "run"]:
		for direction in [Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0)]:
			await _route(mode, direction)
	var output := FileAccess.open("user://t011_gait_biomechanics_metrics.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(reports, "\t"))
	output.close()
	await AUDIO_SHUTDOWN.drain(self)
	print("GAIT BIOMECHANICS CHECKS: ", "PASS" if failures.is_empty() else "FAIL " + str(failures))
	quit(0 if failures.is_empty() else 1)

func _route(mode: String, direction: Vector2) -> void:
	_build(4, true)
	for actor in actors:
		actor.body_profile.idle_enabled = false
	await _ticks(30)
	for actor in actors:
		var intent := AtlasCharacterIntent.new()
		intent.movement = direction
		intent.walk = mode == "walk"
		intent.run = mode == "run"
		actor.submit_intent(intent)
	# De eerste twee seconden zijn versnellen/startsteun, geen stationaire cadans.
	await _ticks(120)
	var states: Array = []
	for index in 4:
		states.append({"events": [], "last": {}, "time": 0.0, "travel": 0.0,
			"speed_error": 0.0, "period_sum": 0.0, "overlap_sum": 0.0, "support_sum": 0.0, "air": 0, "single": 0, "double": 0,
			"max_ankle_error": 0.0, "pivot_error": 0.0, "pivot_height": 0.0, "pivot_drift": 0.0,
			"min_gap": INF, "min_shin_gap": INF, "opening": 0, "closing": 0,
			"open_travel": 0.0, "close_travel": 0.0, "min_width": INF, "max_width": 0.0,
			"roll_stage": [0, 0], "complete_rolls": [0, 0], "max_queries": 0})
	for tick in SAMPLE_TICKS:
		await _ticks(1)
		for index in 4:
			_measure(index, states[index], mode, direction)
	for index in 4:
		_check_route(index, states[index], mode, direction)
		reports.append({"mode": mode, "direction": str(direction), "body": index, "measured": states[index]})
		var summary: Dictionary = states[index].duplicate()
		summary.erase("events")
		print("GAIT BIOMECHANICS ", mode, " ", direction, " body=", index, " ", JSON.stringify(summary))
	world.queue_free()
	actors.clear()
	frames.clear()
	await _ticks(3)

func _measure(index: int, state: Dictionary, mode: String, direction: Vector2) -> void:
	var actor := actors[index]
	var view: AtlasCharacterPresentation = actor.get_node("Presentation/ProceduralBody")
	var frame: AtlasCharacterContactFrame = frames[index]
	var debug := view.get_debug_state()
	var side_route := direction.x != 0.0
	state.time += frame.delta
	state.travel += frame.horizontal_travel.length()
	state.period_sum += frame.step_duration
	state.overlap_sum += frame.double_support_ratio
	state.support_sum += frame.support_fraction
	var expected_speed := actor.direction_speed_limit_for_state(direction, "walk" if mode == "walk" else ("run" if mode == "run" else "jog"))
	state.speed_error = maxf(state.speed_error, absf(frame.horizontal_speed - expected_speed))
	state.max_queries = maxi(state.max_queries, view._rays_last_frame)
	_expect(not frame.jumped and not frame.landed, "gangen maken geen bewuste sprong of zware landing")
	_expect(debug.foot_contact_sides.size() == frame.foot_contacts.size(), "ieder gepubliceerd contact heeft een zichtbare voetzijde")
	_expect(debug.foot_contact_sides.size() <= 1, "een directionele stap landt niet met beide voeten tegelijk")
	for contact_index in debug.foot_contact_sides.size():
		var side: int = debug.foot_contact_sides[contact_index]
		_expect(view._locked[side] and frame.supported, "contactevent komt uitsluitend van een werkelijk gesteunde voet")
		state.events.append({"time": state.time, "side": side, "point": frame.foot_contacts[contact_index], "body": actor.global_position})
	var locks := int(view._locked[0]) + int(view._locked[1])
	state.single += int(locks == 1)
	state.double += int(locks == 2)
	state.air += int(frame.air_kind == "stride")
	if frame.air_kind == "stride":
		_expect(locks == 0 and frame.foot_contacts.is_empty() and not frame.supported, "echte pasvlucht heeft geen zoolsteun of verborgen contactcue")
	if mode == "walk":
		_expect(frame.supported and locks >= 1 and frame.air_kind == "none", "wandelen heeft onafgebroken echte steun")
	view.apply_skeleton_pose(view._skeleton)
	var feet: Array[Vector3] = []
	var knees: Array[Vector3] = []
	var pivots: Array[Vector3] = []
	var pivot_kinds: Array[int] = []
	for side in 2:
		var points := _joint_points(view, actor.body_profile.leg_bones(side))
		feet.append(points[2])
		knees.append(points[1])
		state.max_ankle_error = maxf(state.max_ankle_error, points[2].distance_to(view._targets[side]))
		var foot := view._legs[side][2]
		var world_basis := view._skeleton.global_basis * view._skeleton.get_bone_global_pose(foot).basis
		var anatomical_basis := actor.global_basis.inverse() * world_basis * view._rest_foot_basis[side].inverse()
		var pitch := atan2(anatomical_basis.y.z, anatomical_basis.y.y)
		var rolling := mode in ["walk", "jog"] and view._locked[side]
		var pivot_kind := (1 if view._foot_roll[side] >= 0.0 else -1) if rolling else 0
		var pivot_z: float = (view._toe_lengths[side] * 0.25 if pivot_kind == 1 else -view._toe_lengths[side]) if rolling else 0.0
		# Echte voetbotmatrix en een rustoffset: de enkel zelf is geen zoolpin.
		var rest_offset: Vector3 = view._rest_foot_basis[side].inverse() * Vector3(0, -view._ankle_height, pivot_z)
		var actual_pivot := points[2] + world_basis * rest_offset
		pivots.append(actual_pivot)
		pivot_kinds.append(pivot_kind)
		if view._locked[side]:
			state.pivot_height = maxf(state.pivot_height, absf(actual_pivot.y))
			if rolling:
				state.pivot_error = maxf(state.pivot_error, actual_pivot.distance_to(view._foot_pivots[side]))
				if pitch > deg_to_rad(2.0) and state.roll_stage[side] == 0:
					state.roll_stage[side] = 1
				elif absf(pitch) < deg_to_rad(1.0) and state.roll_stage[side] == 1:
					state.roll_stage[side] = 2
				elif pitch < -deg_to_rad(2.0) and state.roll_stage[side] == 2:
					state.roll_stage[side] = 3
			if not state.last.is_empty() and state.last.locked[side] and state.last.kinds[side] == pivot_kind and view._contacts[side].distance_to(state.last.contacts[side]) < 0.00001:
				state.pivot_drift = maxf(state.pivot_drift, actual_pivot.distance_to(state.last.pivots[side]))
		else:
			if state.roll_stage[side] == 3:
				state.complete_rolls[side] += 1
			state.roll_stage[side] = 0
	var right := view._body_transform.basis.x
	var width := (feet[1] - feet[0]).dot(right)
	state.min_gap = minf(state.min_gap, width)
	state.min_width = minf(state.min_width, width)
	state.max_width = maxf(state.max_width, width)
	var nearest := Geometry3D.get_closest_points_between_segments(knees[0], feet[0], knees[1], feet[1])
	state.min_shin_gap = minf(state.min_shin_gap, nearest[0].distance_to(nearest[1]))
	state.last = {"locked": view._locked.duplicate(), "contacts": view._contacts.duplicate(), "pivots": pivots, "kinds": pivot_kinds, "width": width}
	view._skeleton.reset_bone_poses()

func _check_route(index: int, state: Dictionary, mode: String, direction: Vector2) -> void:
	var suffix := "%s/%s/lichaam%d" % [mode, direction, index]
	var view: AtlasCharacterPresentation = actors[index].get_node("Presentation/ProceduralBody")
	var side_route := direction.x != 0.0
	_expect(state.speed_error < 0.06, "werkelijke stabiele vaart volgt de ingestelde richtingssnelheid " + suffix)
	var configured := [actors[index].walk_forward_speed, actors[index].jog_forward_speed, actors[index].run_forward_speed]
	_expect(absf(configured[0]-1.4) < 0.00001 and absf(configured[1]-3.0) < 0.00001 and absf(configured[2]-9.0) < 0.00001, "nieuwe drie gangen zijn 1,4/3/9 m/s")
	_expect(state.max_queries <= 2 and state.max_ankle_error < 0.003, "bereikbare echte enkels binnen twee lokale voetmetingen " + suffix)
	_expect(state.min_gap > 0.03 and state.min_shin_gap > 0.03, "zichtbare enkels en schenen kruisen niet " + suffix)
	_expect(state.pivot_error < 0.003 and state.pivot_height < 0.003 and state.pivot_drift < 0.003, "werkelijk gereconstrueerde zoolpivot blijft op de vloer en wereldvast " + suffix)
	_expect(state.events.size() >= 8, "voldoende werkelijke contacten voor stationaire meting " + suffix)
	var intervals: Array[float] = []
	var strides: Array[float] = []
	var contact_speeds: Array[float] = []
	var last_by_side: Dictionary = {}
	var previous: Dictionary = {}
	for event in state.events:
		if not previous.is_empty():
			_expect(event.side != previous.side, "echte contacten wisselen links/rechts zonder dubbele voetcue " + suffix)
			intervals.append(event.time - previous.time)
		if last_by_side.has(event.side):
			var last: Dictionary = last_by_side[event.side]
			var interval: float = event.time - last.time
			strides.append(interval)
			contact_speeds.append(Vector3(event.point-last.point).slide(Vector3.UP).length() / interval)
		last_by_side[event.side] = event
		previous = event
	var period: float = state.period_sum / SAMPLE_TICKS
	var observed_period := _mean(intervals)
	state.mean_step_seconds = _mean(intervals)
	state.mean_same_foot_seconds = _mean(strides)
	state.contacts_per_minute = 60.0 / maxf(_mean(intervals), DT)
	state.mean_contact_speed = _mean(contact_speeds)
	_expect(absf(observed_period-period) < DT*2.1, "staptijd is gemeten tussen contacten, geen halve of dubbele cyclus " + suffix)
	var speed: float = state.travel / state.time
	_expect(absf(_mean(contact_speeds)-speed) < 0.08, "zelfde-voetcontactafstand en interval passen bij echte capsulevaart " + suffix)
	if mode == "walk":
		_expect(absf(float(state.double)/SAMPLE_TICKS-state.overlap_sum/SAMPLE_TICKS) < DT*2.0/period+0.02, "gemeten dubbele steun past bij gedeelde wandelcontactduur " + suffix)
		_expect(state.air == 0 and state.single > 20 and state.double > 20, "WALK bevat enkele en dubbele steun zonder vlucht " + suffix)
		_expect(state.complete_rolls[0] >= 3 and state.complete_rolls[1] >= 3, "beide echte voeten tonen hiel-vlak-voorvoet vóór loslaten " + suffix)
	else:
		_expect(state.air > 20 and state.single > 20 and state.double == 0, "JOG/SPRINT hebben afwisselende enkelsteun en echte vlucht " + suffix)
	state.erase("last")

func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += value
	return total / values.size()
func _expect(value: bool, message: String) -> void:
	if not value and not failures.has(message):
		failures.append(message)
		push_error(message)