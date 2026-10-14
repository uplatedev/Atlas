extends SceneTree
## Controle van de gedeelde tijdseenheden en bereikgrenzen; echte routes staan in motor/biomechanics checks.
var failures: Array[String] = []

func _initialize() -> void:
	var profile := AtlasCharacterBodyProfile.new()
	_test_timing(profile)
	_test_scheduler_contract()
	_test_gait_selection()
	_test_instance_resources(profile)
	if failures.is_empty():
		print("RHYTHM CONTRACT CHECKS: PASS")
	else:
		for failure in failures:
			printerr("FAIL: ", failure)
	quit(0 if failures.is_empty() else 1)

func _test_timing(profile: AtlasCharacterBodyProfile) -> void:
	for leg in [0.673775, 0.84, 0.91, 0.71]:
		var walk := profile.get_gait_timing(1.4, leg, 20.0, "sneak")
		var jog := profile.get_gait_timing(3.0, leg, 20.0, "lopen")
		var sprint := profile.get_gait_timing(9.0, leg, 20.0, "sprint")
		_expect(walk.y == 0.0 and walk.z == 0.0, "wandelen heeft geen afzet of vlucht")
		_expect(walk.x * 1.4 * (1.0 + profile.walking_double_support_ratio) <= leg * profile.walking_support_distance_ratio + 0.00001, "wandelbereik omvat ook dubbele steun")
		_expect(jog.x * 3.0 <= leg * profile.jogging_support_distance_ratio + 0.00001, "jogcontact past bij gemeten beenlengte")
		_expect(sprint.x * 9.0 <= leg * profile.step_length_ratio + 0.00001, "sprintcontact bewaart begrensde steunafstand")
		_expect(walk.x > jog.x + jog.y and jog.x + jog.y > sprint.x + sprint.y, "cadans neemt toe van wandeling via jog naar sprint")
		_expect(sprint.y > jog.y and sprint.z > jog.z, "standaardcurve geeft snellere passen meer echte vlucht")
		for timing in [jog, sprint]:
			_expect(absf(timing.z - 20.0 * timing.y * timing.y / 8.0) < 0.000001, "vluchtduur en hoogte komen uit dezelfde zwaartekracht")
		print("RHYTHM_PLAN ", JSON.stringify({"leg":leg,"walk_spm":60.0/walk.x,"jog_spm":60.0/(jog.x+jog.y),"sprint_spm":60.0/(sprint.x+sprint.y),"jog_contact":jog.x,"jog_flight":jog.y,"sprint_contact":sprint.x,"sprint_flight":sprint.y}))
	var earth := profile.get_gait_timing(3.0, 0.673775, 9.81, "lopen")
	var game := profile.get_gait_timing(3.0, 0.673775, 20.0, "lopen")
	_expect(is_equal_approx(earth.z, game.z) and earth.y > game.y, "andere echte zwaartekracht wijzigt duur, niet profielhoogte")
	var original := profile.stride_flight_curve
	var zero := Curve.new()
	zero.add_point(Vector2.ZERO)
	zero.add_point(Vector2(1,0))
	profile.stride_flight_curve = zero
	for mode in ["sneak","lopen","sprint"]:
		var timing := profile.get_gait_timing(3.0, 0.673775, 20.0, mode)
		_expect(timing.x > 0.0 and timing.y == 0.0 and timing.z == 0.0, "nulcurve bewaart een echte gesteunde cyclus")
	profile.stride_flight_curve = original
	var side := profile.get_gait_timing(1.12, 0.673775, 20.0, "sneak", 1.0)
	_expect(side.y > 0.0 and side.z > 0.0, "expliciete Alt-zijpas houdt de bevestigde kleine fysieke hup")

func _test_scheduler_contract() -> void:
	var initial := AtlasStrideScheduler.new()
	initial.configure_timing(0.4, 0.0, 0.18)
	initial.support_tick(0.1, 0.4, true, 0.5, Vector2(0,-1.4), true)
	_expect(is_equal_approx(initial.get_step_duration(), 0.2), "eerste steun duurt korter vanuit neutrale voeten")
	initial.supported_step(Vector2(0,-1.4))
	_expect(is_equal_approx(initial.get_step_duration(), 0.4), "nieuwe contactplaatsing krijgt volle toekomstige steun, geen oude startduur")
	var scheduler := AtlasStrideScheduler.new()
	scheduler.configure_timing(0.2, 0.1, 0.0)
	_expect(is_equal_approx(scheduler.get_step_duration(), 0.3), "steun plus vlucht is één links-rechtsstap")
	_expect(is_equal_approx(scheduler.get_support_fraction(), 2.0/3.0), "steunfractie is van één stap, niet de dubbele voetcyclus")
	_expect(not scheduler.support_tick(0.1, 0.2, true), "halve steun is nog geen afzet")
	_expect(is_equal_approx(scheduler.phase, 0.25), "bestaand fasecontract blijft steun0tot0,5")
	_expect(scheduler.support_tick(0.1, 0.2, true), "volledige steun vraagt afzet")
	scheduler.take_off(0.0, 0.025, 20.0)
	scheduler.flight_tick(0.05)
	_expect(is_equal_approx(scheduler.phase, 0.75), "fysieke halve vlucht is fase0,75")
	scheduler.flight_tick(0.2)
	_expect(scheduler.step_index == 0 and scheduler.phase < 1.0, "verstreken vluchttijd verzint nooit contact")
	scheduler.touch_down(Vector2(0,-3))
	_expect(scheduler.step_index == 1 and scheduler.phase == 0.0, "werkelijk contact sluit één stap af")
	scheduler.configure_timing(0.4, 0.0, 0.18)
	scheduler.support_tick(0.2, 0.4, true, 1.0, Vector2(0,-1.4), true)
	_expect(scheduler.is_supported_cycle() and scheduler.get_support_fraction() == 1.0 and is_equal_approx(scheduler.phase, 0.5), "WALK gebruikt volledige uniforme gesteunde fase")
	scheduler.configure_timing(0.2, 0.1, 0.0)
	_expect(not scheduler.support_tick(0.05,0.2,true,1.0,Vector2(0,-3)), "gangwissel behoudt de nog lopende steun")
	_expect(scheduler.phase > 0.5 and scheduler.defer_flight_until_next_step(), "oude gesteunde cyclus eerst sluiten vóór vlucht")
	scheduler.supported_step(Vector2(0,-3))
	_expect(scheduler.step_index == 2 and not scheduler.is_supported_cycle(), "volgende cyclus mag vluchten zonder dubbel contact")

func _test_gait_selection() -> void:
	var actor := AtlasCharacter.new()
	actor._sneak_requested = true
	_expect(actor._gait_motion_profile(Vector3(0,0,-8)) == "lopen", "Alt met sprintmomentum blijft effectief joggen")
	_expect(actor._gait_motion_profile(Vector3(0,0,-1.4)) == "sneak", "haalbare wandelvaart gebruikt WALK")
	_expect(actor._gait_motion_profile(Vector3(0,0,1.0)) == "lopen", "achterwaarts gebruikt eigen lagere wandellimiet")
	actor.sneak_forward_speed = 2.1
	actor.walk_forward_speed = 6.5
	actor.sprint_forward_speed = 11.0
	_expect(actor._gait_motion_profile(Vector3(0,0,-2.1)) == "sneak" and actor._gait_motion_profile(Vector3(0,0,-2.3)) == "lopen", "instancegrens komt uit eigen Alt-snelheid, niet jog/sprint-defaults")
	actor._stride.configure_timing(0.2,0.1,0.0)
	actor._stride.support_tick(0.1,0.2,true)
	_expect(actor._gait_motion_profile(Vector3(0,0,-1.4)) == "lopen", "lopende vluchtcyclus wacht op werkelijk contact voor WALK")
	actor._stride.support_tick(0.01,0.4,true,1.0,Vector2(0,-1.4),true)
	_expect(not actor._stride.is_supported_cycle() and actor._stride.phase < 0.5, "Alt verdubbelt lopende halve steunfase niet")
	_expect(actor._gait_motion_profile(Vector3(1.12,0,0)) == "sneak", "lage zijshuffle houdt eigen stijl tijdens steun en vlucht")
	actor._stride.touch_down(Vector2(0,-1.4))
	actor._stride.configure_timing(0.4,0.0,0.18)
	actor._stride.begin_supported_cycle()
	_expect(actor._stride.is_supported_cycle() and actor._stride.get_support_fraction() == 1.0 and actor._stride.phase == 0.0, "nieuwe WALK-contactframe publiceert coherente volle grondcyclus")
	actor.free()


func _test_instance_resources(profile: AtlasCharacterBodyProfile) -> void:
	var other := profile.make_instance_unique()
	other.jogging_cadence = 200.0
	other.walking_double_support_ratio = 0.25
	other.stride_flight_curve.set_point_value(1, 0.02)
	_expect(profile.jogging_cadence == 176.0 and profile.walking_double_support_ratio == 0.18, "ritme-instellingen blijven per instance")
	_expect(profile.stride_flight_curve.get_point_position(1).y != other.stride_flight_curve.get_point_position(1).y, "vluchtcurve blijft werkelijk onafhankelijk")

func _expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
