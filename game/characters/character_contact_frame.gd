@tool
class_name AtlasCharacterContactFrame
extends RefCounted
## Definitieve fysieke uitkomst van één bewegingsframe, zonder feedbackbeleid.

var delta: float = 0.0
var horizontal_travel: Vector3 = Vector3.ZERO
var horizontal_speed: float = 0.0
var incoming_velocity: Vector3 = Vector3.ZERO
var supported: bool = false
var real_grounded: bool = false
var motion_profile: String = "lopen"
var posture: String = "staan"
var sliding: bool = false
var jumped: bool = false
var landed: bool = false
var world_position: Vector3 = Vector3.ZERO
