@tool
class_name AtlasCharacterContactFrame
extends RefCounted
## Definitieve fysieke uitkomst van één bewegingsframe, zonder feedbackbeleid.

var delta: float = 0.0
var horizontal_travel: Vector3 = Vector3.ZERO
var horizontal_speed: float = 0.0
## Blijvende loopinvoer onderscheidt een omkeernulpunt van echte stilstand.
var movement_requested: bool = false
var incoming_velocity: Vector3 = Vector3.ZERO
var supported: bool = false
var real_grounded: bool = false
var motion_profile: String = "lopen"
var posture: String = "staan"
var sliding: bool = false
var jumped: bool = false
var landed: bool = false
var world_position: Vector3 = Vector3.ZERO

## Procedurele pasgegevens; steun blijft de werkelijke collisionuitkomst.
var procedural_enabled: bool = false
var air_kind: String = "none"
var stride_started: bool = false
var stride_landed: bool = false
## Gesteunde voetwissel wanneer plafond of curve de pasvlucht verhindert.
var ground_step: bool = false
var step_index: int = 0
var gait_phase: float = 0.0
var body_velocity: Vector3 = Vector3.ZERO
var body_transform: Transform3D = Transform3D.IDENTITY
## Presentatie voegt echte voetcontacten toe vóór audio/camera dit frame lezen.
var foot_contacts: Array[Vector3] = []
## Alleen presentatie: gesteunde bijstap bij draaien, onafhankelijk van motorpasindex.
var turn_step_landed: bool = false
var turn_step_index: int = 0
