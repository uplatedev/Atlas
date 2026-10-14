@tool
class_name AtlasCharacterCameraMotion
extends RefCounted
## Fysieke gegevens voor de view; bevat geen FOV, zoom of camerageschiedenis.
## Character vult deze sample, de camera leest hem zonder scene-knooppaden.

var body_yaw: float = 0.0
var motion_profile: String = "lopen"
var grounded: bool = false
var sliding: bool = false
var eye_height: float = 1.62
var clearance_height: float = 1.8
var horizontal_velocity: Vector3 = Vector3.ZERO
var actual_horizontal_velocity: Vector3 = Vector3.ZERO
var walk_speed_limit: float = 5.0
var sprint_speed_limit: float = 9.0
var body_shape: Shape3D
var body_shape_transform: Transform3D = Transform3D.IDENTITY
var excluded_body: RID
var presentation_layer: int = 0
var standing_radius: float = 0.35

var air_kind: String = "none"
var stride_offset_y: float = 0.0
