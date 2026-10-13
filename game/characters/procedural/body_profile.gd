@tool
class_name AtlasCharacterBodyProfile
extends Resource
## Proporties komen uit de rustbotten. Dit profiel bepaalt alleen koppelingen en stijl.

@export_group("Lichaam")
## Zichtbaar model met Skeleton3D; leeg gebruikt het eenvoudige proeflichaam.
@export var visual_scene: PackedScene:
	set(value):
		if visual_scene == value:
			return
		visual_scene = value
		emit_changed()
## Massa voor impulsen; verandert geen zwaartekracht of gewenste loopsnelheid.
@export_range(1.0, 300.0, 1.0, "suffix:kg") var mass_kg: float = 75.0
## Drie echte verhoudingen voor de proef zonder eigen model.
@export_enum("Gemiddeld", "Lange bovenbenen", "Korte bovenbenen") var test_body: int = 0:
	set(value):
		if test_body == value:
			return
		test_body = value
		emit_changed()
## Kleur van het eenvoudige proeflichaam.
@export var test_color: Color = Color(0.28, 0.63, 0.82):
	set(value):
		if test_color == value:
			return
		test_color = value
		emit_changed()
@export_group("Pas")
## Snelheid die bij het rechter uiteinde van de pasvluchtcurve hoort.
@export_range(0.1, 30.0, 0.1, "suffix:m/s") var reference_speed: float = 9.0
## Standbreedte ten opzichte van de gemeten rustvoeten; verandert alleen de voetdoelen.
@export_range(0.5, 1.8, 0.05) var stance_width_ratio: float = 1.0
## Versterking van de begrensde rompleun bij snelheid en versnellen; nul houdt de romp recht.
@export_range(0.0, 2.0, 0.05) var torso_lean_scale: float = 1.0
## Hielhoogte tijdens achterste sprintzwaai als deel van beenlengte; rustige passen schalen vanzelf terug.
@export_range(0.05, 0.7, 0.01) var heel_recovery_ratio: float = 0.50
## Maximale actieve enkeluitslag bij sprint: afzet, teenhef en vlak voorbereiden op contact.
@export_range(0.0, 45.0, 1.0, "suffix:°") var ankle_swing_degrees: float = 10.0
## Extra voorwaartse ruimte voor de handzwaai als deel van armlengte; beïnvloedt geen loopbesturing.
@export_range(0.0, 0.3, 0.01) var arm_forward_ratio: float = 0.12
## Voetspoorbreedte bij sprint als deel van rustbreedte; steunvoeten blijven op hun contactpunt.
@export_range(0.5, 1.0, 0.01) var running_stance_ratio: float = 0.65
## Voetspoorbreedte tijdens rustig lopen als deel van de rustbreedte; wordt geleidelijk smaller bij sprint.
@export_range(0.5, 1.0, 0.01) var walking_stance_ratio: float = 0.75
## Voet- en hielheffing bij rustig lopen als deel van de renstijl; houdt rustige passen dicht bij de grond.
@export_range(0.1, 0.6, 0.01) var walking_lift_ratio: float = 0.25
## Zijwaartse bekkenrol bij lopen; de borst rolt tegengesteld en het hoofd blijft recht.
@export_range(0.0, 6.0, 0.5, "suffix:°") var body_roll_degrees: float = 3.0
## Kleine gewichtsverplaatsing naar het steunbeen, als deel van beenlengte; alleen zichtbaar lichaam.
@export_range(0.0, 0.05, 0.001) var weight_shift_ratio: float = 0.015
## Mediale beweging van alleen de voorwaarts zwaaiende hand, als deel van armlengte.
@export_range(0.0, 0.3, 0.01) var arm_inward_ratio: float = 0.20
## Tegengestelde bekken-/schouderdraai bij sprint; het hoofd behoudt de gevraagde blik.
@export_range(0.0, 14.0, 0.5, "suffix:°") var body_twist_degrees: float = 8.0
## Ruimte voor knievolume bij de knieslide als deel van beenlengte; helpt bij andere modeldiktes.
@export_range(0.04, 0.18, 0.005) var slide_knee_clearance_ratio: float = 0.09
## Kleine bekken-/kniecompressie per werkelijk voetcontact, als deel van beenlengte; nul zet het pasaccent uit.
@export_range(0.0, 0.06, 0.001) var step_compression_ratio: float = 0.025
## Grootste extra compressie bij een bewuste sprong/val; de echte impactsnelheid schaalt de sterkte.
@export_range(0.0, 0.18, 0.005) var landing_compression_ratio: float = 0.12
## Tijd tot de piek van de gedempte presentatieveer; korter reageert steviger, langer zachter.
@export_range(0.025, 0.12, 0.005, "suffix:s") var compression_peak_time: float = 0.055
## Maximale teenhef ten opzichte van het onderbeen tijdens de vrije zwaai.
@export_range(5.0, 35.0, 1.0, "suffix:°") var ankle_dorsiflex_degrees: float = 20.0
## Maximale strekking van de voet ten opzichte van het onderbeen tijdens de vrije zwaai.
@export_range(20.0, 65.0, 1.0, "suffix:°") var ankle_plantarflex_degrees: float = 45.0
## Steunafstand als deel van gemeten beenlengte.
@export_range(0.2, 1.5, 0.01) var step_length_ratio: float = 0.72
## Maximale voetheffing tijdens zwaaien als deel van beenlengte.
@export_range(0.0, 0.5, 0.01) var foot_lift_ratio: float = 0.18
## X is zwaaivoortgang, Y is relatieve voetheffing. Eindpunten blijven op de grond.
@export var swing_foot_curve: Curve = _default_swing_curve()
## X is snelheid/referentiesnelheid; Y is pasvluchthoogte als deel van beenlengte.
@export var stride_flight_curve: Curve = _default_flight_curve()
## Maximale armzwaai bij referentiesnelheid in graden.
@export_range(0.0, 85.0, 1.0) var arm_swing_degrees: float = 48.0
@export_group("Gewrichtsgrenzen")
## Kleinste kniebuiging; nul is volledig gestrekt. Een kleine marge voorkomt doorslaan.
@export_range(0.0, 170.0, 1.0) var knee_min_flex_degrees: float = 5.0
## Grootste kniebuiging; bereik wordt op deze hoek begrensd.
@export_range(1.0, 175.0, 1.0) var knee_max_flex_degrees: float = 155.0
## Kleinste elleboogbuiging; de vaste buigrichting voorkomt omklappen.
@export_range(0.0, 170.0, 1.0) var elbow_min_flex_degrees: float = 5.0
## Grootste elleboogbuiging; geldt ook bij sprint- en sprongposes.
@export_range(1.0, 175.0, 1.0) var elbow_max_flex_degrees: float = 140.0
@export_group("Botten midden")
## Bekkenbot dat de lichaamshoogte en lage houding draagt.
@export var pelvis_bone: StringName = &"hips":
	set(value):
		if pelvis_bone == value:
			return
		pelvis_bone = value
		emit_changed()
## Rompbot voor lichte helling en versnellingreactie.
@export var spine_bone: StringName = &"spine.002":
	set(value):
		if spine_bone == value:
			return
		spine_bone = value
		emit_changed()
## Hoofdbot van het model; rustoriëntatie blijft behouden.
@export var head_bone: StringName = &"head":
	set(value):
		if head_bone == value:
			return
		head_bone = value
		emit_changed()
@export_group("Botten links")
## Linker dijbeen: eerste gewricht van de beenketen.
@export var left_upper_leg_bone: StringName = &"thigh.l":
	set(value):
		if left_upper_leg_bone == value:
			return
		left_upper_leg_bone = value
		emit_changed()
## Linker onderbeen: kniegewricht van de beenketen.
@export var left_lower_leg_bone: StringName = &"calf.l":
	set(value):
		if left_lower_leg_bone == value:
			return
		left_lower_leg_bone = value
		emit_changed()
## Linker voet: enkeldoel voor plaatsing en grondoriëntatie.
@export var left_foot_bone: StringName = &"foot.l":
	set(value):
		if left_foot_bone == value:
			return
		left_foot_bone = value
		emit_changed()
## Linker bovenarm: schoudergewricht van de armketen.
@export var left_upper_arm_bone: StringName = &"upperarm.l":
	set(value):
		if left_upper_arm_bone == value:
			return
		left_upper_arm_bone = value
		emit_changed()
## Linker onderarm: ellebooggewricht van de armketen.
@export var left_lower_arm_bone: StringName = &"forearm.l":
	set(value):
		if left_lower_arm_bone == value:
			return
		left_lower_arm_bone = value
		emit_changed()
## Linker hand: polsdoel van de armketen.
@export var left_hand_bone: StringName = &"hand.l":
	set(value):
		if left_hand_bone == value:
			return
		left_hand_bone = value
		emit_changed()
@export_group("Botten rechts")
## Rechter dijbeen: eerste gewricht van de beenketen.
@export var right_upper_leg_bone: StringName = &"thigh.r":
	set(value):
		if right_upper_leg_bone == value:
			return
		right_upper_leg_bone = value
		emit_changed()
## Rechter onderbeen: kniegewricht van de beenketen.
@export var right_lower_leg_bone: StringName = &"calf.r":
	set(value):
		if right_lower_leg_bone == value:
			return
		right_lower_leg_bone = value
		emit_changed()
## Rechter voet: enkeldoel voor plaatsing en grondoriëntatie.
@export var right_foot_bone: StringName = &"foot.r":
	set(value):
		if right_foot_bone == value:
			return
		right_foot_bone = value
		emit_changed()
## Rechter bovenarm: schoudergewricht van de armketen.
@export var right_upper_arm_bone: StringName = &"upperarm.r":
	set(value):
		if right_upper_arm_bone == value:
			return
		right_upper_arm_bone = value
		emit_changed()
## Rechter onderarm: ellebooggewricht van de armketen.
@export var right_lower_arm_bone: StringName = &"forearm.r":
	set(value):
		if right_lower_arm_bone == value:
			return
		right_lower_arm_bone = value
		emit_changed()
## Rechter hand: polsdoel van de armketen.
@export var right_hand_bone: StringName = &"hand.r":
	set(value):
		if right_hand_bone == value:
			return
		right_hand_bone = value
		emit_changed()

@export_group("Bijstappen")
## Duur van één vrije bijstap bij draaien in seconden; lager draait sneller, zonder de capsule te sturen.
@export_range(0.08, 0.4, 0.01, "suffix:s") var turn_step_duration: float = 0.15
## Grootste richtingsverschil tussen de twee voeten tijdens bijdraaien; lager geeft meer, kleinere stappen.
@export_range(20.0, 70.0, 1.0, "suffix:°") var turn_step_angle_degrees: float = 54.0

func _init() -> void:
	resource_local_to_scene = true

## Alleen velden die model, rustmeting of previewgeometrie veranderen.
## De root bewaart de vorige waarde en bouwt uitsluitend bij verschil opnieuw.
func rig_signature() -> Array:
	return [visual_scene, test_body, test_color, pelvis_bone, spine_bone, head_bone,
		left_upper_leg_bone, left_lower_leg_bone, left_foot_bone,
		left_upper_arm_bone, left_lower_arm_bone, left_hand_bone,
		right_upper_leg_bone, right_lower_leg_bone, right_foot_bone,
		right_upper_arm_bone, right_lower_arm_bone, right_hand_bone]

func make_instance_unique() -> AtlasCharacterBodyProfile:
	var result := duplicate() as AtlasCharacterBodyProfile
	result.resource_local_to_scene = true
	result.swing_foot_curve = swing_foot_curve.duplicate() as Curve if swing_foot_curve != null else _default_swing_curve()
	result.stride_flight_curve = stride_flight_curve.duplicate() as Curve if stride_flight_curve != null else _default_flight_curve()
	result.swing_foot_curve.resource_local_to_scene = true
	result.stride_flight_curve.resource_local_to_scene = true
	return result

func get_flight_height(normalized_speed: float, leg_length: float, sneaking: bool) -> float:
	var curve := stride_flight_curve
	var ratio := curve.sample_baked(clampf(normalized_speed, 0.0, 1.0)) if curve != null else 0.12 * clampf(normalized_speed, 0.0, 1.0)
	return clampf(ratio, 0.0, 0.22) * maxf(leg_length, 0.05) * (0.1 if sneaking else 1.0)

func get_support_duration(speed: float, leg_length: float, sneaking: bool) -> float:
	return clampf(maxf(leg_length, 0.05) * step_length_ratio / maxf(speed, 0.2), 0.035, 0.34) * (1.3 if sneaking else 1.0)

func get_swing_lift(progress: float) -> float:
	if progress <= 0.0 or progress >= 1.0:
		return 0.0
	return clampf(swing_foot_curve.sample_baked(progress) if swing_foot_curve != null else sin(progress * PI), 0.0, 1.5)

func get_flexion_limits(arm: bool) -> Vector2:
	var minimum := clampf(elbow_min_flex_degrees if arm else knee_min_flex_degrees, 0.0, 170.0)
	var maximum := clampf(elbow_max_flex_degrees if arm else knee_max_flex_degrees, minimum + 0.1, 175.0)
	return Vector2(deg_to_rad(minimum), deg_to_rad(maximum))

func leg_bones(side: int) -> Array[StringName]:
	return [left_upper_leg_bone, left_lower_leg_bone, left_foot_bone] if side == 0 else [right_upper_leg_bone, right_lower_leg_bone, right_foot_bone]

func arm_bones(side: int) -> Array[StringName]:
	return [left_upper_arm_bone, left_lower_arm_bone, left_hand_bone] if side == 0 else [right_upper_arm_bone, right_lower_arm_bone, right_hand_bone]

static func _default_swing_curve() -> Curve:
	var curve := Curve.new()
	curve.resource_local_to_scene = true
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.45, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	return curve

static func _default_flight_curve() -> Curve:
	var curve := Curve.new()
	curve.resource_local_to_scene = true
	curve.max_value = 0.25
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.10, 0.005))
	curve.add_point(Vector2(0.55, 0.045))
	curve.add_point(Vector2(1.0, 0.12))
	return curve
