extends SceneTree
## Herhaalbare engineproef voor de kleine horizontale camera-remveer.
## --path game --script ../docs/work/T-005/camera_inertia_checks.gd

var failures: int = 0
var rig: Node3D
var actor: Node3D
var camera_script: String = ""


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--camera="):
			camera_script = argument.trim_prefix("--camera=")
	call_deferred("run")


func check(value: bool, message: String) -> void:
	print("PASS " if value else "FAIL ", message)
	if not value:
		failures += 1


func trajectory(rate: int, speed: float, braking: float) -> Dictionary:
	rig.set_distance(4.0)
	actor.global_position = Vector3.ZERO
	actor.reset_physics_interpolation()
	rig.reset_follow_history()
	var delta := 1.0 / float(rate)
	var position := 0.0
	for frame in rate * 2:
		position += speed * delta
		rig._update_follow_position(Vector3(position, 0.0, 0.0), delta, false)
	var velocity := speed
	var peak_front := 0.0
	var peak_offset := 0.0
	var maximum_total := 0.0
	for frame in rate * 2:
		var next_velocity := maxf(0.0, velocity - braking * delta) if braking > 0.0 else 0.0
		# Integraal van de voorgeschreven remming in dit renderinterval.
		position += (velocity + next_velocity) * 0.5 * delta if braking > 0.0 else 0.0
		velocity = next_velocity
		var target := Vector3(position, 0.0, 0.0)
		rig._update_follow_position(target, delta, false)
		var combined: Vector3 = (rig._follow_position - target + rig._inertia_offset).limit_length(actor.camera_follow_max_lag)
		peak_front = maxf(peak_front, combined.x)
		peak_offset = maxf(peak_offset, rig._inertia_offset.length())
		maximum_total = maxf(maximum_total, combined.length())
	return {"front": peak_front, "offset": peak_offset, "total": maximum_total, "remaining": rig._inertia_offset.length()}


func run() -> void:
	actor = load("res://characters/Character.tscn").instantiate()
	rig = actor.get_node("CameraPivot")
	if not camera_script.is_empty():
		rig.set_script(load(camera_script))
	root.add_child(actor)
	actor.set_physics_process(false)
	rig.set_process(false)
	var normal_peaks: Array[float] = []
	var hard_peaks: Array[float] = []
	for rate in [30, 60, 144]:
		for speed in [2.0, 5.0, 9.0]:
			for brake in [0.0, 36.0]:
				var result := trajectory(rate, speed, brake)
				print("MEASURE inertia fps=%d speed=%.1f brake=%.1f front=%.6fm offset=%.6fm total=%.6fm remaining=%.9fm" % [rate, speed, brake, result.front, result.offset, result.total, result.remaining])
				check(result.offset <= 0.03501 and result.total <= 0.12001 and result.remaining < 0.00001, "begrensde uitslag en rustig herstel %d fps, %.1fm/s, rem %.1f" % [rate, speed, brake])
				if speed <= 2.0:
					check(result.offset < 0.000001, "sneaksnelheid geeft geen remaccent bij %d fps" % rate)
				if speed == 9.0:
					if brake > 0.0:
						normal_peaks.append(result.front)
					else:
						hard_peaks.append(result.front)
	check(normal_peaks.min() > 0.008 and normal_peaks.max() < 0.02, "normaal sprintloslaten geeft ongeveer 1–2cm echte doorschieting")
	check(hard_peaks.min() > 0.02 and hard_peaks.max() < 0.035, "abrupte sprintstop blijft onder 3,5cm echte doorschieting")
	check(normal_peaks.max() - normal_peaks.min() < 0.002 and hard_peaks.max() - hard_peaks.min() < 0.002, "30/60/144 fps piekverschil onder 2mm")
	rig.reset_view()
	var look: float = rig.get_look_yaw()
	rig._inertia_offset = Vector3(0.02, 0.0, 0.0)
	rig.apply_look_delta(Vector2(-10.0, 0.0))
	check(absf(rig.get_look_yaw() - look - deg_to_rad(1.2)) < 0.00001, "kijkrichting reageert direct tijdens camera-nawerking")
	rig.reset_follow_history()
	rig._update_inertia(Vector3(9.0, 0.0, 0.0), 1.0 / 60.0)
	rig._update_inertia(Vector3(0.0, 0.0, 9.0), 1.0 / 60.0)
	check(rig._inertia_offset.length() < 0.000001, "haakse bocht op gelijke snelheid geeft geen remimpuls")
	var maximum_offset := 0.0
	for frame in 1200:
		rig._update_inertia(Vector3(40.0, 0.0, 0.0) if frame % 2 == 0 else Vector3.ZERO, 1.0 / 144.0)
		maximum_offset = maxf(maximum_offset, rig._inertia_offset.length())
	check(maximum_offset <= 0.03501, "veel opeenvolgende harde remacties stapelen niet boven 3,5cm: %.6fm" % maximum_offset)
	for frame in 144:
		rig._update_inertia(Vector3.ZERO, 1.0 / 144.0)
	check(rig._inertia_offset.length() < 0.00001, "ook na herhaald afremmen verdwijnt nawerking zonder blijvende druk")
	rig.set_distance(0.0)
	rig._update_inertia(Vector3(9.0, 0.0, 0.0), 1.0 / 60.0)
	rig._update_inertia(Vector3.ZERO, 1.0 / 60.0)
	check(rig._inertia_offset.is_zero_approx(), "first person heeft standaard geen remaccent")
	rig.set_distance(4.0)
	rig._update_inertia(Vector3.ZERO, 1.0 / 60.0)
	check(rig._inertia_offset.is_zero_approx(), "terugzoomen veroorzaakt geen bewaarde remimpuls")
	rig._update_inertia(Vector3(9.0, 0.0, 0.0), 1.0 / 60.0)
	rig._update_inertia(Vector3.ZERO, 1.0 / 60.0)
	rig._update_follow_position(Vector3(100.0, 0.0, 100.0), 1.0 / 60.0, false)
	check(rig._inertia_offset.is_zero_approx() and rig._previous_follow_velocity.is_zero_approx(), "teleport wist remgeschiedenis zonder valse doorschieting")
	rig._inertia_offset = Vector3(0.03, 0.0, 0.0)
	rig._inertia_velocity = Vector3(1.0, 0.0, 0.0)
	rig.reset_follow_history()
	check(rig._inertia_offset.is_zero_approx() and rig._inertia_velocity.is_zero_approx(), "reset/Tab wist veerpositie en veersnelheid")
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.2, 3.0, 3.0)
	collider.shape = shape
	wall.add_child(collider)
	wall.position = Vector3(0.30, 1.5, 0.0)
	root.add_child(wall)
	await physics_frame
	await physics_frame
	rig._inertia_offset = Vector3(0.035, 0.0, 0.0)
	rig._inertia_velocity = Vector3(0.3, 0.0, 0.0)
	rig._refresh_transform(1.0 / 144.0)
	var camera: Camera3D = rig.get_node("SpringArm3D/Camera3D")
	var camera_query = rig._camera_query(camera.global_position)
	check(root.get_world_3d().direct_space_state.intersect_shape(camera_query, 1).is_empty(), "echte camera-sphere blijft buiten zijwand tijdens doorschieting")
	check(rig.global_position.x <= 0.016 and rig._inertia_offset.is_zero_approx() and rig._inertia_velocity.is_zero_approx(), "wand begrenst doorschieting direct en wist veerdruk: %.6fm" % rig.global_position.x)
	var settings := ["camera_inertia_enabled", "camera_inertia_amount", "camera_inertia_recovery_time", "camera_inertia_min_speed", "camera_inertia_full_speed", "camera_first_person_inertia_enabled"]
	var editor_settings: Array[String] = []
	for entry in actor.get_property_list():
		if entry.name in settings and entry.usage & PROPERTY_USAGE_EDITOR:
			editor_settings.append(entry.name)
	if editor_settings.size() == settings.size():
		check(true, "alle zes nawerkingsinstellingen staan op de echte Character-root voor de Inspector")
		var other: Node3D = load("res://characters/Character.tscn").instantiate()
		actor.set("camera_inertia_amount", 0.010)
		check(absf(other.get("camera_inertia_amount") - 0.035) < 0.000001, "tweede Character behoudt eigen nawerkingsinstellingen")
		other.free()
		var smaller := trajectory(60, 9.0, 0.0)
		check(smaller.offset <= 0.01001 and smaller.offset > 0.009, "aangepaste rootuitslag verandert echte rigwerking")
		actor.set("camera_inertia_enabled", false)
		var disabled := trajectory(60, 9.0, 0.0)
		check(disabled.offset < 0.000001, "uitzetten op Character-root verwijdert extra remaccent")
		actor.set("camera_inertia_enabled", true)
		actor.set("camera_first_person_inertia_enabled", true)
		rig.set_distance(0.0)
		rig._update_inertia(Vector3(9.0, 0.0, 0.0), 1.0 / 60.0)
		rig._update_inertia(Vector3.ZERO, 1.0 / 60.0)
		check(rig._inertia_offset.length() > 0.0001, "first-personaccent is bewust afzonderlijk inschakelbaar")
	else:
		print("INFO rootexports nog niet in deze deelcheckout; rig-defaults getest. Herhaal tegen geïntegreerde Character-root.")
	print("CAMERA INERTIA CHECKS failures=", failures)
	quit(0 if failures == 0 else 1)
