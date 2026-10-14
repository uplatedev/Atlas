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
var motion_profile: String = "jog"
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
## Steun 0..0,5 en vlucht 0,5..1; een geheel gesteunde cyclus gebruikt uniforme 0..1.
var gait_phase: float = 0.0
## Actuele geplande steunfractie; kan binnen een stap veranderen bij versnellen/omkeren.
## Gebruik voor een poseklok alleen met faseoverdracht. Geheel gesteunde passen gebruiken 1.
var support_fraction: float = 1.0
## Eén motorcyclus in seconden: vooruit/diagonaal één afwisselende stap;
## zijwaarts één lead/follow-shuffle met twee voetcontacten. Botsingen kunnen dit verkorten.
var step_duration: float = 0.0
## Fractie dubbele steun van een volledige wandelcyclus; presentatie beheert zoolcontacten.
var double_support_ratio: float = 0.0
## Wandel-, nulcurve- of plafondcyclus: de gehele fase 0..1 blijft werkelijk ondersteund.
var gait_supported_cycle: bool = false
var body_velocity: Vector3 = Vector3.ZERO
var body_transform: Transform3D = Transform3D.IDENTITY
## Presentatie voegt echte voetcontacten toe vóór audio/camera dit frame lezen.
var foot_contacts: Array[Vector3] = []
## Alleen presentatie: gesteunde bijstap bij draaien, onafhankelijk van motorpasindex.
var turn_step_landed: bool = false
var turn_step_index: int = 0
