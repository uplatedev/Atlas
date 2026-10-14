extends SceneTree
## Controleert de publieke naamgrens en echte opslag/herlading van instancewaarden.
const CHARACTER = preload("res://characters/Character.tscn")
const MAIN = preload("res://scenes/main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var character: AtlasCharacter = CHARACTER.instantiate()
	var groups: Array[String] = []
	for property in character.get_property_list():
		var key := String(property.name)
		if int(property.usage) & PROPERTY_USAGE_GROUP and key in ["Walk", "Jog", "Run"]:
			groups.append(key)
		if int(property.usage) & PROPERTY_USAGE_STORAGE:
			_expect(not key.contains("sneak") and not key.contains("sprint") and not key.begins_with("walking_jump"), "oude Character-opslagnaam: " + key)
	_expect(groups == ["Walk", "Jog", "Run"], "Inspector toont Walk/Jog/Run in die volgorde")
	_expect(InputMap.has_action("walk") and InputMap.has_action("run"), "canonieke Walk/Run-input bestaat")
	_expect(not InputMap.has_action("sneak") and not InputMap.has_action("sprint"), "oude inputnamen verdwenen")
	_expect(_has_key("walk", KEY_ALT) and _has_key("run", KEY_SHIFT), "Alt/Shift-toetsen behouden")
	_expect(is_equal_approx(character.walk_forward_speed, 1.4) and is_equal_approx(character.jog_forward_speed, 3.0) and is_equal_approx(character.run_forward_speed, 9.0), "bestaande snelheidsdefaults blijven 1,4/3/9")
	var main: Node = MAIN.instantiate()
	var other: AtlasCharacter = main.get_node("Characters/AtlasB")
	_expect(is_equal_approx(other.walk_forward_speed, 1.4) and is_equal_approx(other.jog_forward_speed, 6.5) and is_equal_approx(other.run_forward_speed, 11.0), "bestaande sceneoverride blijft Walk1,4/Jog6,5/Run11")
	_expect(is_equal_approx(other.jog_acceleration, 40.0) and is_equal_approx(other.run_acceleration, 32.0) and is_equal_approx(other.jog_turn_speed, 600.0) and is_equal_approx(other.run_turn_speed, 360.0), "opgeslagen acceleratie-/draaiwaarden behouden")
	main.free()
	var settings := {"walk_forward_speed": 1.7, "jog_forward_speed": 4.2, "run_forward_speed": 10.3, "walk_jump_height": 0.6, "jog_jump_height": 1.35, "run_jump_height": 0.75, "camera_walk_fov_offset": -3.0, "camera_run_fov_bonus": 7.0, "walk_contact_volume_db": -9.0, "jog_contact_volume_db": -1.0, "run_contact_volume_db": 2.0}
	for key in settings:
		character.set(key, settings[key])
	character.body_profile = character.body_profile.make_instance_unique()
	character.body_profile.walk_cadence = 130.0
	character.body_profile.jog_cadence = 185.0
	character.body_profile.run_cadence = 270.0
	var packed := PackedScene.new()
	_expect(packed.pack(character) == OK, "instelbare Character kan worden gepackt")
	var save_path := "user://t013-movement-names.tscn"
	_expect(ResourceSaver.save(packed, save_path) == OK, "echte Character-scene opgeslagen")
	var saved: PackedScene = ResourceLoader.load(save_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
	var restored: AtlasCharacter = saved.instantiate()
	for key in settings:
		_expect(is_equal_approx(float(restored.get(key)), float(settings[key])), "herladen waarde blijft behouden: " + key)
	_expect(is_equal_approx(restored.body_profile.walk_cadence, 130.0) and is_equal_approx(restored.body_profile.jog_cadence, 185.0) and is_equal_approx(restored.body_profile.run_cadence, 270.0), "alle drie opgeslagen pasritmes herladen")
	var independent: AtlasCharacter = CHARACTER.instantiate()
	_expect(is_equal_approx(independent.walk_forward_speed, 1.4) and is_equal_approx(independent.body_profile.walk_cadence, 120.0), "opslag wijzigt geen andere instance of bronresource")
	character.free()
	restored.free()
	independent.free()
	DirAccess.remove_absolute(save_path)
	for failure in failures:
		printerr("FAIL: ", failure)
	print("MOVEMENT NAMES CHECKS: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)

func _has_key(action: String, key: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and (event.physical_keycode == key or event.keycode == key):
			return true
	return false

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
