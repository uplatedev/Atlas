@tool
class_name AtlasIdleMotion
extends RefCounted
## Per-instance idle values. The existing presentation remains the only pose owner.
const EYE_SHADER = preload("res://characters/procedural/idle_eyes.gdshader")
const SIGH_DURATION := 2.6

var chest_pitch: float = 0.0
var head_pitch: float = 0.0
var shoulder_lift: float = 0.0
var blink_amount: float = 0.0
var weight: float = 0.0
var blink_count: int = 0
var sigh_count: int = 0
var mesh_builds: int = 0
var _profile: AtlasCharacterBodyProfile
var _model_id: int = 0
var _rng := RandomNumberGenerator.new()
var _materials: Array[ShaderMaterial] = []
var _breath_phase: float = 0.0
var _breath_duration: float = 4.5
var _blink_wait: float = 0.0
var _blink_time: float = -1.0
var _sigh_wait: float = 0.0
var _sigh_time: float = -1.0

func _init() -> void:
	_rng.randomize()

func setup(model: Node3D, profile: AtlasCharacterBodyProfile) -> void:
	_profile = profile
	if model.get_instance_id() == _model_id:
		return
	_model_id = model.get_instance_id()
	_materials.clear()
	_install_eyes(model)
	reset()

func reset() -> void:
	weight = 0.0
	chest_pitch = 0.0
	head_pitch = 0.0
	shoulder_lift = 0.0
	blink_amount = 0.0
	blink_count = 0
	sigh_count = 0
	_breath_phase = _rng.randf()
	_breath_duration = _interval(_profile.idle_breath_seconds, 2.0, 12.0) if _profile != null else 4.5
	_blink_wait = _interval(_profile.idle_blink_seconds, 0.5, 30.0) if _profile != null else 5.0
	_sigh_wait = _interval(_profile.idle_sigh_seconds, 5.0, 120.0) if _profile != null else 30.0
	_blink_time = -1.0
	_sigh_time = -1.0
	_update_eyes()

func advance(delta: float, active: bool) -> void:
	if _profile == null:
		return
	var dt := clampf(delta, 0.0, 0.2)
	var enabled := active and _profile.idle_enabled
	weight = move_toward(weight, 1.0 if enabled else 0.0, dt / 0.25)
	_breath_phase += dt / _breath_duration
	if _breath_phase >= 1.0:
		_breath_phase = fmod(_breath_phase, 1.0)
		_breath_duration = _interval(_profile.idle_breath_seconds, 2.0, 12.0)
	if enabled:
		_blink_wait -= dt
		_sigh_wait -= dt
		if _blink_wait <= 0.0 and _blink_time < 0.0 and _profile.idle_blink_enabled:
			_blink_time = 0.0
			blink_count += 1
		if _sigh_wait <= 0.0 and _sigh_time < 0.0 and _profile.idle_sigh_degrees > 0.0:
			_sigh_time = 0.0
			sigh_count += 1
	var blink := 0.0
	if _blink_time >= 0.0:
		_blink_time += dt
		var phase := _blink_time / clampf(_profile.idle_blink_duration, 0.1, 0.5)
		blink = smoothstep(0.0, 0.35, phase) * (1.0 - smoothstep(0.45, 1.0, phase))
		if phase >= 1.0:
			_blink_time = -1.0
			_blink_wait = _interval(_profile.idle_blink_seconds, 0.5, 30.0)
	var sigh := 0.0
	if _sigh_time >= 0.0:
		_sigh_time += dt
		var phase := _sigh_time / SIGH_DURATION
		if phase < 0.25:
			sigh = 0.5 * smoothstep(0.0, 0.25, phase)
		elif phase < 0.65:
			sigh = lerpf(0.5, -1.0, smoothstep(0.25, 0.65, phase))
		else:
			sigh = lerpf(-1.0, 0.0, smoothstep(0.65, 1.0, phase))
		if phase >= 1.0:
			_sigh_time = -1.0
			_sigh_wait = _interval(_profile.idle_sigh_seconds, 5.0, 120.0)
	var breath := sin(_breath_phase * TAU)
	chest_pitch = weight * (breath * deg_to_rad(clampf(_profile.idle_breath_degrees, 0.0, 2.0)) + sigh * deg_to_rad(clampf(_profile.idle_sigh_degrees, 0.0, 4.0)))
	head_pitch = -chest_pitch * 0.18
	shoulder_lift = weight * (breath + sigh * 1.5) * clampf(_profile.idle_shoulder_lift_ratio, 0.0, 0.015)
	blink_amount = blink * weight if _profile.idle_blink_enabled else 0.0
	_update_eyes()

func _interval(interval: Vector2, lower: float, upper: float) -> float:
	return _rng.randf_range(clampf(minf(interval.x, interval.y), lower, upper), clampf(maxf(interval.x, interval.y), lower, upper))

func _update_eyes() -> void:
	for material in _materials:
		material.set_shader_parameter("blink_amount", blink_amount)

func _install_eyes(model: Node3D) -> void:
	var nodes: Array[Node] = [model]
	nodes.append_array(model.find_children("*", "MeshInstance3D", true, false))
	for node in nodes:
		var instance := node as MeshInstance3D
		if instance == null or not instance.mesh is ArrayMesh or instance.material_override != null:
			continue
		var original := instance.mesh as ArrayMesh
		var skin: BaseMaterial3D
		var eyes: Array[int] = []
		for surface in range(original.get_surface_count()):
			var material := instance.get_active_material(surface) as BaseMaterial3D
			if material == null or material.albedo_texture != null:
				continue
			if material.resource_name == "Skin":
				skin = material
			elif material.resource_name == "Eyes":
				eyes.append(surface)
		if eyes.is_empty() or skin == null:
			continue
		var mesh := _copy_with_eye_uv(original, eyes)
		instance.mesh = mesh
		mesh_builds += 1
		for surface in eyes:
			var eye := instance.get_active_material(surface) as BaseMaterial3D
			var material := ShaderMaterial.new()
			material.resource_local_to_scene = true
			material.shader = EYE_SHADER
			material.set_shader_parameter("eye_color", eye.albedo_color)
			material.set_shader_parameter("skin_color", skin.albedo_color)
			material.set_shader_parameter("eye_roughness", eye.roughness)
			material.set_shader_parameter("skin_roughness", skin.roughness)
			instance.set_surface_override_material(surface, material)
			_materials.append(material)

func _copy_with_eye_uv(original: ArrayMesh, eyes: Array[int]) -> ArrayMesh:
	var result := ArrayMesh.new()
	result.resource_name = original.resource_name + " Idle"
	result.blend_shape_mode = original.blend_shape_mode
	result.custom_aabb = original.custom_aabb
	result.shadow_mesh = original.shadow_mesh
	for index in range(original.get_blend_shape_count()):
		result.add_blend_shape(original.get_blend_shape_name(index))
	for surface in range(original.get_surface_count()):
		var arrays := original.surface_get_arrays(surface)
		if eyes.has(surface):
			var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var low := INF
			var high := -INF
			for point in positions:
				low = minf(low, point.y)
				high = maxf(high, point.y)
			var uv := PackedVector2Array()
			for point in positions:
				uv.append(Vector2(0.5, (point.y - low) / maxf(high - low, 0.0001)))
			arrays[Mesh.ARRAY_TEX_UV] = uv
		# Keep imported LODs, morphs and all eight skin influences intact.
		var data := RenderingServer.mesh_get_surface(original.get_rid(), surface)
		var lods: Dictionary = {}
		for lod in data.get("lods", []):
			var bytes: PackedByteArray = lod.index_data
			var stride := 2 if int(data.vertex_count) <= 65536 else 4
			var indices := PackedInt32Array()
			for offset in range(0, bytes.size(), stride):
				indices.append(bytes.decode_u16(offset) if stride == 2 else bytes.decode_u32(offset))
			lods[lod.edge_length] = indices
		result.add_surface_from_arrays(original.surface_get_primitive_type(surface), arrays, original.surface_get_blend_shape_arrays(surface), lods, original.surface_get_format(surface))
		result.surface_set_material(surface, original.surface_get_material(surface))
		result.surface_set_name(surface, original.surface_get_name(surface))
	return result