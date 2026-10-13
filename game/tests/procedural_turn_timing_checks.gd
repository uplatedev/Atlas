extends SceneTree
## Pure bijstapplanner: geen capsule, renderer, extra voetcontactklok of raycasts.
const DT := 1.0 / 60.0
var failures: Array[String] = []

func _initialize() -> void:
	var slow := _route(30.0,180.0)
	var fast := _route(360.0,180.0)
	_expect(fast.first_two < slow.first_two - 0.035,"snelle grote draai krijgt kortere eerste twee bijstappen")
	for angle in [20.0,68.0,70.0]:
		for direction in [-1.0,1.0]:
			_route(360.0 * direction,180.0 * direction,angle)
	var disabled := _route(360.0,180.0,68.0,0.0)
	_expect(absf(disabled.minimum-0.22) < 0.000001 and absf(disabled.maximum-0.22) < 0.000001,"uitschakelen behoudt exact de gewone bijstapduur")
	_reserve_reversal_and_replant()
	_instances()
	for failure in failures:
		printerr("FAIL: ",failure)
	print("TURN TIMING CHECKS: ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)

func _route(degrees_per_second: float, degrees: float, pair_degrees: float = 68.0, adaptation: float = 1.0) -> Dictionary:
	var planner := AtlasTurnStepPlanner.new()
	planner.max_pair_angle = deg_to_rad(pair_degrees)
	planner.speed_adaptation = adaptation
	planner.reset(0.0)
	var rest: Array[Vector3] = [Vector3(-0.1,0,0),Vector3(0.1,0,0)]
	var contacts: Array[Vector3] = rest.duplicate()
	var durations: Array[float] = []
	var ramp_time := absf(degrees/degrees_per_second)
	var minimum := INF
	var maximum := 0.0
	var max_pair := 0.0
	var max_pin_yaw := 0.0
	var last_duration := 0.22
	for tick in ceili((ramp_time+4.0)/DT):
		var previous_yaws := planner.foot_yaws.duplicate()
		var previous_side := planner.active_side
		var previous_phase := planner.phase
		var previous_index := planner.step_index
		var elapsed := (tick+1)*DT
		var desired := deg_to_rad(degrees_per_second * minf(elapsed,ramp_time))
		planner.advance(DT,desired,true,Vector3.ZERO,rest,contacts,elapsed>=0.12)
		if planner.started_side >= 0:
			durations.append(planner.active_step_duration)
			minimum = minf(minimum,planner.active_step_duration)
			maximum = maxf(maximum,planner.active_step_duration)
			last_duration = planner.active_step_duration
			_expect(planner.phase == 0.0 and planner.step_index == previous_index,"start verzint geen contact of afgelegde voetfase")
		if previous_side >= 0:
			max_pin_yaw = maxf(max_pin_yaw,absf(wrapf(planner.foot_yaws[1-previous_side]-previous_yaws[1-previous_side],-PI,PI)))
			_expect(planner.phase+0.000001 >= previous_phase,"lopende bijstapfase blijft vooruitgaan")
			_expect(is_equal_approx(planner.active_step_duration,last_duration),"draaisnelheidsfilter verandert een lopende bijstapduur niet")
		if planner.landed_side >= 0:
			contacts[planner.landed_side] = planner.destination()
			_expect(planner.phase == 1.0 and planner.step_index == previous_index+1,"één voltooide vrije baan levert precies één bestaand contactevent")
		else:
			_expect(planner.step_index == previous_index,"geen extra contactklok naast de vrije voetfase")
		max_pair = maxf(max_pair,absf(wrapf(planner.foot_yaws[0]-planner.foot_yaws[1],-PI,PI)))
	_expect(durations.size() >= 2,"grote draai verdeelt hoek over meer dan één bijstap")
	_expect(minimum >= 0.14-0.000001 and maximum <= 0.22+0.000001,"gewone/snelle profielduur begrenzen elke stap")
	_expect(max_pair <= deg_to_rad(pair_degrees)+0.000001,"sneller draaien overschrijdt de ingestelde voethoek niet")
	_expect(max_pin_yaw < 0.000001,"steunvoet krijgt geen oriëntatieteleport")
	_expect(planner.active_side == -1 and absf(wrapf(deg_to_rad(degrees)-planner.pose_yaw,-PI,PI)) < planner.max_pair_angle*0.38+0.00001,"draaien eindigt in de bestaande comfortabele asymmetrische reserve")
	var result := {"speed":degrees_per_second,"angle":degrees,"pair":pair_degrees,"adaptation":adaptation,"steps":durations.size(),"minimum":minimum,"maximum":maximum,"first_two":(durations[0]+durations[1])*0.5,"max_pin_yaw":max_pin_yaw}
	print("TURN TIMING ",JSON.stringify(result))
	return result

func _reserve_reversal_and_replant() -> void:
	var planner := AtlasTurnStepPlanner.new()
	planner.reset(0.0)
	var rest: Array[Vector3] = [Vector3(-0.1,0,0),Vector3(0.1,0,0)]
	var contacts: Array[Vector3] = rest.duplicate()
	for tick in 12:
		planner.advance(DT,PI,true,Vector3.ZERO,rest,contacts,false)
	_expect(planner.active_side == -1 and planner.step_index == 0,"ook een snelle grote blik wacht op hoofd/borsttoestemming")
	planner.advance(DT,PI,true,Vector3.ZERO,rest,contacts,true)
	var active := planner.active_side
	var chosen_duration := planner.active_step_duration
	planner.advance(DT,-PI*0.75,true,Vector3.ZERO,rest,contacts,false)
	_expect(planner.active_side == active and planner.phase > 0.0 and planner.active_step_duration == chosen_duration,"plots tegenkijken voltooit de al gekozen begrensde stap")
	planner.reset(0.0)
	planner.request_replant(0,Vector3(-0.12,0,0))
	planner.advance(DT,PI,true,Vector3.ZERO,rest,contacts,false)
	_expect(planner.active_side == 0 and planner.active_step_duration == planner.step_duration,"veilige herplaatsing houdt rustige duur en vraagt geen nieuwe draaitoestemming")
	planner.advance(DT,PI,false,Vector3.ZERO,rest,contacts)
	_expect(planner.active_side == -1 and planner.filtered_yaw_speed == 0.0,"lopen/lucht beëindigt deze stationaire aanpassing zonder loopcadans te sturen")
	planner.reset(deg_to_rad(179.0))
	planner.advance(DT,deg_to_rad(-179.0),true,Vector3.ZERO,rest,contacts,false)
	_expect(planner.filtered_yaw_speed < deg_to_rad(30.0),"yaw rond180 graden meet een kleine echte draai, geen volledige omwenteling")

func _instances() -> void:
	var first := AtlasCharacterBodyProfile.new()
	var second := first.make_instance_unique()
	second.turn_step_fast_duration = 0.1
	second.turn_step_speed_adaptation = 0.0
	_expect(first.turn_step_fast_duration == 0.14 and first.turn_step_speed_adaptation == 1.0,"snelle bijstapinstellingen blijven per Character onafhankelijk")
	var planner := AtlasTurnStepPlanner.new()
	planner.step_duration = 0.1
	planner.fast_step_duration = 0.4
	planner.filtered_yaw_speed = 100.0
	_expect(planner._duration_for_turn(PI,false) <= 0.1,"snelle duur wordt veilig tot de gewone duur begrensd")

func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
