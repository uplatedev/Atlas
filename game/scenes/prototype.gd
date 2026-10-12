extends Node3D
## Lokale movementproef: Tab wisselt tussen zelfstandig instelbare Characters.

## Leg de muis meteen vast bij starten. Uit is handig voor screenshots en tests.
@export var capture_mouse_on_start := true

var characters: Array[AtlasCharacter] = []
@onready var character_label: Label = $UI/Info/Margin/Rows/Character
@onready var values_label: Label = $UI/Info/Margin/Rows/Values
@onready var debug_label: Label = $UI/Info/Margin/Rows/Debug
@onready var version_label: Label = $UI/Version
@onready var mouse_hint: Label = $UI/MouseHint

var active_index := 0
var debug_visible := true


func _ready() -> void:
	for child in $Characters.get_children():
		if child is AtlasCharacter:
			characters.append(child)
	if characters.is_empty():
		push_error("Plaats minstens één Character onder de Characters-node.")
		return
	set_active_character(0)
	if capture_mouse_on_start and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	version_label.text = _version_text()


func set_active_character(index: int) -> void:
	if characters.is_empty():
		return
	active_index = posmod(index, characters.size())
	for i in characters.size():
		characters[i].set_controlled(i == active_index)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_TAB:
				set_active_character(active_index + 1)
				get_viewport().set_input_as_handled()
			KEY_R:
				for character in characters:
					character.reset_to_spawn()
				get_viewport().set_input_as_handled()
			KEY_F3:
				debug_visible = not debug_visible
				for character in characters:
					character.debug_enabled = debug_visible
			KEY_F4:
				if not characters.is_empty():
					var character := characters[active_index]
					var enabled: Variant = character.get("camera_speed_fov_enabled")
					if enabled is bool:
						character.set("camera_speed_fov_enabled", not enabled)
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	if characters.is_empty():
		return
	var character := characters[active_index]
	var state := character.get_debug_state()
	var head_limit: Variant = character.get("head_max_yaw")
	character_label.text = "%s  ·  %d / %d" % [character.display_name, active_index + 1, characters.size()]
	var speed_fov: Variant = character.get("camera_speed_fov_enabled")
	values_label.text = "%s · %s · %.2f m/s\nZoom %.1f / vrij %.1f m · FOV %.1f° · snelheid %s" % [
		str(state.get("posture", "staan")),
		str(state.get("motion_mode", "lopen")),
		float(state.get("speed", 0.0)),
		float(state.get("camera_distance", 0.0)),
		float(state.get("camera_actual_distance", state.get("camera_distance", 0.0))),
		float(state.get("fov", 75.0)),
		"aan" if speed_fov == true else "uit",
	]
	debug_label.visible = debug_visible
	debug_label.text = "Hoofd  %s\nLichaam  %s\nInput  %s\nBeweging  %s\nHoofd t.o.v. lichaam  %+.1f° / ±%.0f°\nSprong %s · %.2f m hoog · cap %.2f m/s\nVermoeidheid %.0f%%" % [
		_direction_text(state.get("head_direction", state.get("facing_direction", Vector3.FORWARD))),
		_direction_text(state.get("body_direction", state.get("facing_direction", Vector3.FORWARD))),
		_direction_text(state.get("input_direction", Vector3.ZERO)),
		_direction_text(state.get("movement_direction", Vector3.ZERO)),
		float(state.get("head_relative_yaw", 0.0)),
		float(head_limit) if head_limit is float or head_limit is int else 85.0,
		str(state.get("jump_profile", "—")),
		float(state.get("jump_height", 0.0)),
		float(state.get("air_speed_cap", 0.0)),
		clampf(float(state.get("fatigue", 0.0)), 0.0, 1.0) * 100.0,
	]
	mouse_hint.visible = Input.mouse_mode != Input.MOUSE_MODE_CAPTURED


func _direction_text(value: Variant) -> String:
	if value is Vector3:
		return "(%+.2f, %+.2f, %+.2f)" % [value.x, value.y, value.z]
	if value is Vector2:
		return "(%+.2f, %+.2f)" % [value.x, value.y]
	return str(value)


func _version_text() -> String:
	var version := "T-004 · lokale proef"
	var path := "res://test-version.local.json"
	if FileAccess.file_exists(path):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary and data.has("source_commit"):
			version = "Bron %s · lokale proef" % str(data.source_commit).left(8)
	return "%s\nGodot %s" % [version, Engine.get_version_info().string]
