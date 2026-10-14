@tool
class_name AtlasCharacterHeadDebug
extends Node3D
## Tekent de logische hoofdoriëntatie. Camera noch beweging kent deze pijl.

var _character: Node3D
var _orientation: Vector2 = Vector2.ZERO
var _eye_height: float = 1.62


func _ready() -> void:
	# De camera publiceert vóór deze renderupdate: geen extra frame hoofdvertraging.
	process_priority = 101
	if not Engine.is_editor_hint():
		top_level = true
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func initialize(character: Node3D) -> void:
	_character = character
	_update_render_pose()


func set_head_orientation(yaw: float, pitch: float, eye_height: float) -> void:
	_orientation = Vector2(yaw, pitch)
	_eye_height = eye_height
	_update_render_pose()


func _process(_delta: float) -> void:
	_update_render_pose()


func _update_render_pose() -> void:
	if Engine.is_editor_hint() or not is_instance_valid(_character):
		return
	global_rotation = Vector3(_orientation.y, _orientation.x, 0.0)
	global_position = _character.get_global_transform_interpolated().origin + Vector3.UP * _eye_height
