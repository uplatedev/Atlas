@tool
class_name AtlasCharacterFeedback
extends Node3D
## Contactaudio leest fysieke gebeurtenissen; schrijft geen beweging of camera.
## Eén hoorbare route: eigen niet-ruimtelijke audio, andere Characters in 3D.

signal cue_played(kind: String, route: String)

const MAX_ONE_SHOTS: int = 4
const SILENT_DB: float = -80.0

var _character: Node3D
var _property_names: Dictionary = {}
var _controlled: bool = false
var _enabled_last_frame: bool = true
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
var _local_voices: Array[AudioStreamPlayer] = []
var _spatial_voices: Array[AudioStreamPlayer3D] = []
var _voice_gains: Array[float] = []
var _voice_cursor: int = 0
var _last_sample_index: Dictionary = {}
var _slide_local: AudioStreamPlayer
var _slide_spatial: AudioStreamPlayer3D
var _slide_source: AudioStream
var _slide_stream: AudioStream
var _slide_requested: bool = false
var _slide_level: float = 0.0
var _slide_target: float = 0.0
var _slide_volume_db: float = SILENT_DB
var _distance: float = 0.0
var _ever_supported: bool = false
var _last_turn_step_index: int = -1
var _pending_jump: bool = false
var _pending_sneak_jump: bool = false
var _cue_counts: Dictionary = {"step": 0, "jump": 0, "landing": 0, "slide_landing": 0}


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	_random.randomize()
	for index in range(MAX_ONE_SHOTS):
		var local := AudioStreamPlayer.new()
		local.name = "LocalVoice%d" % index
		add_child(local)
		_local_voices.append(local)
		var spatial := AudioStreamPlayer3D.new()
		spatial.name = "SpatialVoice%d" % index
		add_child(spatial)
		spatial.top_level = true
		_spatial_voices.append(spatial)
		_voice_gains.append(0.0)
	_slide_local = AudioStreamPlayer.new()
	_slide_local.name = "SlideLocal"
	add_child(_slide_local)
	_slide_spatial = AudioStreamPlayer3D.new()
	_slide_spatial.name = "SlideSpatial"
	add_child(_slide_spatial)
	_sync_spatial_settings()


func _exit_tree() -> void:
	# Ook een scene die tijdens een cue verdwijnt laat geen playback of loopkopie achter.
	_stop_voices()
	_stop_slide()
	for player in _local_voices:
		if is_instance_valid(player):
			player.stream = null
	for player in _spatial_voices:
		if is_instance_valid(player):
			player.stream = null
	if is_instance_valid(_slide_local):
		_slide_local.stream = null
	if is_instance_valid(_slide_spatial):
		_slide_spatial.stream = null
	_slide_source = null
	_slide_stream = null
	_pending_jump = false
	_pending_sneak_jump = false


func initialize(character: Node3D) -> void:
	_character = character
	_property_names.clear()
	for entry in character.get_property_list():
		_property_names[entry.name] = true
	reset()
	_sync_spatial_settings()


func _value(property_name: String, fallback: Variant) -> Variant:
	if is_instance_valid(_character) and _property_names.has(property_name):
		return _character.get(property_name)
	return fallback


func set_controlled(value: bool) -> void:
	if value == _controlled:
		return
	_controlled = value
	# Een Tab-wissel herhaalt geen oude cue en houdt geen oude route hoorbaar.
	_stop_voices()
	_stop_slide()
	_distance = 0.0
	_pending_jump = false
	_pending_sneak_jump = false


func reset() -> void:
	_stop_voices()
	_stop_slide()
	_distance = 0.0
	_ever_supported = false
	_last_turn_step_index = -1
	_pending_jump = false
	_pending_sneak_jump = false
	_cue_counts = {"step": 0, "jump": 0, "landing": 0, "slide_landing": 0}


func capture_jump(_horizontal: Vector3, _walk_limit: float, _sprint_limit: float, sneaking: bool) -> void:
	if not bool(_value("feedback_enabled", true)):
		return
	_pending_jump = true
	_pending_sneak_jump = sneaking
	_distance = 0.0
	_stop_slide()


func consume_contact(frame: AtlasCharacterContactFrame) -> void:
	if not bool(_value("feedback_enabled", true)):
		reset()
		return
	var accepted_jump := frame.jumped or _pending_jump
	var profile := _profile(frame.motion_profile)
	if accepted_jump:
		var jump_profile := _profile("sneak") if _pending_sneak_jump else profile
		_request_cue("jump", "feedback_jump_samples", float(_value("feedback_jump_volume_db", -5.0)) + float(jump_profile.gain), frame.world_position)
		_ever_supported = true
		_pending_jump = false
		_pending_sneak_jump = false
		_distance = 0.0
	var impact := maxf(0.0, -frame.incoming_velocity.y)
	var minimum: float = maxf(0.0, float(_value("landing_min_speed", 0.75)))
	if frame.landed and _ever_supported and not accepted_jump and impact >= minimum:
		var full: float = maxf(minimum + 0.01, float(_value("landing_full_speed", 8.0)))
		var weight := clampf((impact - minimum) / (full - minimum), 0.0, 1.0)
		var gain := lerpf(float(_value("feedback_landing_min_volume_db", -12.0)), float(_value("feedback_landing_max_volume_db", -2.0)), weight)
		_request_cue("slide_landing" if frame.sliding else "landing", "feedback_landing_samples", gain, frame.world_position)
	if frame.supported:
		_ever_supported = true
	var step_minimum: float = maxf(0.0, float(_value("feedback_step_min_speed", 0.10)))
	var may_contact := frame.supported and not accepted_jump and not frame.landed and not frame.sliding and frame.delta > 0.0 and frame.delta <= 0.25
	var may_step := may_contact and frame.horizontal_speed > step_minimum
	var new_turn_contact := frame.turn_step_landed and frame.turn_step_index != _last_turn_step_index
	if frame.turn_step_landed:
		_last_turn_step_index = frame.turn_step_index
	if frame.procedural_enabled and frame.posture == "staan":
		# De stapplanner bewaart echte voetcontacten. Afstandscadans zou bij iedere
		# pasvlucht opnieuw beginnen en kan geen betrouwbare voetplaatsing volgen.
		_distance = 0.0
		# Bijstappen verplaatsen een voet terwijl de capsule stilstaat. Hun eigen
		# contactnummer voorkomt herhaling zonder een kunstmatige loopsnelheid.
		var may_procedural_step := may_contact and new_turn_contact if frame.turn_step_landed else may_step
		if may_procedural_step:
			var turn_gain := -4.0 if frame.turn_step_landed else 0.0
			for contact in frame.foot_contacts.slice(0, 2):
				_request_cue("step", "feedback_footstep_samples", float(_value("feedback_step_volume_db", -2.0)) + float(profile.gain) + turn_gain, contact)
	elif may_step:
		_distance += frame.horizontal_travel.length()
		var stride: float = maxf(0.2, float(profile.distance))
		if _distance >= stride:
			# Geen salvo na een grote frameonderbreking; de pool blijft ook begrensd.
			_distance = fmod(_distance, stride)
			var samples := "feedback_low_contact_samples" if frame.motion_profile in ["kruipen", "liggen"] else "feedback_footstep_samples"
			_request_cue("step", samples, float(_value("feedback_step_volume_db", -2.0)) + float(profile.gain), frame.world_position)
	elif not frame.supported or accepted_jump or frame.landed or frame.sliding:
		_distance = 0.0
	var slide_minimum: float = maxf(0.0, float(_value("slide_min_speed", 0.25)))
	_slide_requested = frame.sliding and frame.supported and not accepted_jump and frame.horizontal_speed > slide_minimum
	if _slide_requested:
		var reference: float = maxf(0.1, float(_value("feedback_slide_reference_speed", 9.0)))
		_slide_target = clampf(frame.horizontal_speed / reference, 0.0, 1.0)
	else:
		_stop_slide()


func _profile(motion: String) -> Dictionary:
	var prefix := "walk"
	var distance := 1.4
	var gain := 0.0
	match motion:
		"sprint":
			prefix = "sprint"
			distance = 1.8
			gain = 1.0
		"sneak":
			prefix = "sneak"
			distance = 1.3
			gain = -12.0
		"kruipen":
			prefix = "crouch"
			distance = 1.2
			gain = -6.0
		"liggen":
			prefix = "prone"
			distance = 1.0
			gain = -10.0
	return {"distance": float(_value(prefix + "_step_distance", distance)), "gain": float(_value(prefix + "_contact_volume_db", gain))}


func _request_cue(kind: String, samples_property: String, gain: float, at: Vector3) -> void:
	_cue_counts[kind] = int(_cue_counts.get(kind, 0)) + 1
	if kind == "slide_landing":
		_cue_counts.landing = int(_cue_counts.landing) + 1
	var samples: Array = _value(samples_property, [])
	var available: Array[AudioStream] = []
	for candidate in samples:
		if candidate is AudioStream:
			available.append(candidate)
	if available.is_empty():
		# Deze diagnostiek meldt semantische cues ook bij bewust lege samplelijsten.
		cue_played.emit(kind, _route())
		return
	var index := _random.randi_range(0, available.size() - 1)
	if available.size() > 1 and index == int(_last_sample_index.get(samples_property, -1)):
		index = (index + 1 + _random.randi_range(0, available.size() - 2)) % available.size()
	_last_sample_index[samples_property] = index
	var voice := _voice_cursor
	for offset in range(MAX_ONE_SHOTS):
		var candidate := (_voice_cursor + offset) % MAX_ONE_SHOTS
		if not _local_voices[candidate].playing and not _spatial_voices[candidate].playing:
			voice = candidate
			break
	_voice_cursor = (voice + 1) % MAX_ONE_SHOTS
	_local_voices[voice].stop()
	_spatial_voices[voice].stop()
	var variation: float = maxf(0.0, float(_value("feedback_volume_variation_db", 1.0)))
	_voice_gains[voice] = gain + _random.randf_range(-variation, variation)
	var pitch_variation: float = clampf(float(_value("feedback_pitch_variation", 0.025)), 0.0, 0.10)
	var pitch := 1.0 + _random.randf_range(-pitch_variation, pitch_variation)
	var total := _voice_gains[voice] + float(_value("feedback_master_volume_db", -6.0))
	if _controlled:
		_local_voices[voice].stream = available[index]
		_local_voices[voice].volume_db = total
		_local_voices[voice].pitch_scale = pitch
		_local_voices[voice].play()
	else:
		_spatial_voices[voice].stream = available[index]
		_spatial_voices[voice].global_position = at + Vector3.UP * 0.08
		_spatial_voices[voice].volume_db = total
		_spatial_voices[voice].pitch_scale = pitch
		_spatial_voices[voice].play()
	cue_played.emit(kind, _route())


func _process(delta: float) -> void:
	var enabled: bool = bool(_value("feedback_enabled", true))
	if not enabled:
		if _enabled_last_frame:
			reset()
		_enabled_last_frame = false
		return
	_enabled_last_frame = true
	if not is_instance_valid(_character):
		return
	_sync_spatial_settings()
	var master: float = float(_value("feedback_master_volume_db", -6.0))
	for index in range(MAX_ONE_SHOTS):
		_local_voices[index].volume_db = master + _voice_gains[index]
		_spatial_voices[index].volume_db = master + _voice_gains[index]
	if not _slide_requested:
		return
	var fade: float = maxf(0.0, float(_value("feedback_slide_fade_time", 0.08)))
	var blend := 1.0 if fade <= 0.0 else 1.0 - pow(0.5, maxf(delta, 0.0) / fade)
	_slide_level = lerpf(_slide_level, _slide_target, blend)
	_slide_volume_db = master + float(_value("feedback_slide_volume_db", -8.0)) + linear_to_db(maxf(_slide_level, 0.0001))
	_sync_slide_stream()
	if _slide_stream == null:
		return
	_slide_local.volume_db = _slide_volume_db
	_slide_spatial.volume_db = _slide_volume_db
	if _controlled:
		_slide_spatial.stop()
		if not _slide_local.playing:
			_slide_local.play()
	else:
		_slide_local.stop()
		if not _slide_spatial.playing:
			_slide_spatial.play()


func _sync_slide_stream() -> void:
	var source: AudioStream = _value("feedback_slide_sample", null)
	if source == _slide_source:
		return
	_slide_local.stop()
	_slide_spatial.stop()
	_slide_source = source
	_slide_stream = source.duplicate() as AudioStream if source != null else null
	if _slide_stream is AudioStreamWAV:
		var wav := _slide_stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = maxi(1, int(round(wav.get_length() * wav.mix_rate)))
	elif _slide_stream is AudioStreamOggVorbis:
		(_slide_stream as AudioStreamOggVorbis).loop = true
	elif _slide_stream is AudioStreamMP3:
		(_slide_stream as AudioStreamMP3).loop = true
	_slide_local.stream = _slide_stream
	_slide_spatial.stream = _slide_stream


func _sync_spatial_settings() -> void:
	var maximum: float = maxf(1.0, float(_value("feedback_max_distance", 24.0)))
	var unit: float = maxf(0.1, float(_value("feedback_unit_size", 4.0)))
	for player in _spatial_voices:
		player.max_distance = maximum
		player.unit_size = unit
	if is_instance_valid(_slide_spatial):
		_slide_spatial.max_distance = maximum
		_slide_spatial.unit_size = unit


func _stop_voices() -> void:
	for player in _local_voices:
		if is_instance_valid(player):
			player.stop()
	for player in _spatial_voices:
		if is_instance_valid(player):
			player.stop()


func _stop_slide() -> void:
	_slide_requested = false
	_slide_target = 0.0
	_slide_level = 0.0
	_slide_volume_db = SILENT_DB
	if is_instance_valid(_slide_local):
		_slide_local.stop()
	if is_instance_valid(_slide_spatial):
		_slide_spatial.stop()


func _route() -> String:
	return "local" if _controlled else "3d"


func get_debug_state() -> Dictionary:
	var playing := false
	if is_instance_valid(_slide_local) and is_instance_valid(_slide_spatial):
		playing = _slide_local.playing or _slide_spatial.playing
	return {"cue_counts": _cue_counts.duplicate(), "route": _route(), "accumulated_ground_distance": _distance, "slide_loop_active": _slide_requested, "slide_audio_playing": playing, "slide_volume_db": _slide_volume_db, "max_one_shot_voices": MAX_ONE_SHOTS}
