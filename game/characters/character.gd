@tool
class_name AtlasCharacter
extends CharacterBody3D
## Plaatsbare Character-ingang met onafhankelijke instellingen per instance.
## De oorsprong blijft op de voetzool, ook bij wisselen van houding.

enum Posture { STAND, CROUCH, PRONE }

signal jump_accepted(horizontal_velocity: Vector3, walk_limit: float, sprint_limit: float, sneaking: bool)
signal ground_motion_updated(horizontal_velocity: Vector3, walk_limit: float, sprint_limit: float, low_or_sneaking: bool)
signal posture_changed(posture: String)
signal procedural_frame_ready(frame: AtlasCharacterContactFrame)
signal contact_frame_ready(frame: AtlasCharacterContactFrame)

@export_category("Character")
@export_group("Procedurele beweging")
## Echte kleine pasvluchten en de procedurele lichaamspresentatie; uit bewaart de capsuleproef.
@export var procedural_enabled: bool = false:
	set(value):
		procedural_enabled = value
		_refresh_if_ready()
## Eigen lichaamsprofiel per instance, met massa, botkoppelingen en twee onafhankelijke pascurves.
@export var body_profile: AtlasCharacterBodyProfile = AtlasCharacterBodyProfile.new():
	set(value):
		body_profile = value.make_instance_unique() if value != null else AtlasCharacterBodyProfile.new()
		_refresh_if_ready()
@export_group("Naam en uiterlijk")
## Tekst boven alleen dit Character; pas vrij aan per instance.
@export var display_name: String = "Character":
	set(value):
		display_name = value
		_refresh_if_ready()
## Kleur van de capsule van alleen deze instance.
@export var capsule_color: Color = Color(0.18, 0.65, 0.82):
	set(value):
		capsule_color = value
		_refresh_if_ready()
## Toon de naam boven het hoofd; de eigen first-personcamera verbergt hem.
@export var name_visible: bool = true:
	set(value):
		name_visible = value
		_refresh_if_ready()
## Afstand boven de capsule in meters; hoger plaatst de naam hoger.
@export_range(0.05, 2.0, 0.05, "suffix:m") var name_height: float = 0.35:
	set(value):
		name_height = value
		_refresh_if_ready()
## Grootte van de labeltekst; hoger maakt de naam beter leesbaar.
@export_range(16, 96, 1) var name_font_size: int = 42:
	set(value):
		name_font_size = value
		_refresh_if_ready()

@export_group("Lopen")
## Maximum vooruit in m/s; gecombineerde input krijgt één limiet.
@export_range(0.1, 20.0, 0.1, "suffix:m/s") var walk_forward_speed: float = 5.0
## Zijwaartse snelheid als deel van vooruit; 0.8 betekent 80%.
@export_range(0.05, 1.0, 0.01) var walk_side_ratio: float = 0.8
## Achterwaartse snelheid als deel van vooruit; 0.55 betekent 55%.
@export_range(0.05, 1.0, 0.01) var walk_back_ratio: float = 0.55
## Snelheidstoename in m/s²; hoger bereikt de looplimiet eerder.
@export_range(0.1, 80.0, 0.5, "suffix:m/s²") var walk_acceleration: float = 32.0
## Snelheidsafname in m/s²; hoger stopt sneller.
@export_range(0.1, 80.0, 0.5, "suffix:m/s²") var walk_deceleration: float = 40.0
## Maximale lichaamsdraai tijdens lopen in graden/s; hoger volgt sneller.
@export_range(0.0, 1440.0, 5.0, "suffix:°/s") var walk_turn_speed: float = 540.0

@export_group("Sprint")
## Maximum vooruit in m/s; sprint werkt ook op lagere richtingssnelheden.
@export_range(0.1, 30.0, 0.1, "suffix:m/s") var sprint_forward_speed: float = 9.0
## Zijwaartse sprintsnelheid als deel van vooruit; 0.8 betekent 80%.
@export_range(0.05, 1.0, 0.01) var sprint_side_ratio: float = 0.8
## Achterwaartse sprintsnelheid als deel van vooruit; 0.55 betekent 55%.
@export_range(0.05, 1.0, 0.01) var sprint_back_ratio: float = 0.55
## Snelheidstoename bij sprint in m/s²; hoger versnelt sneller.
@export_range(0.1, 80.0, 0.5, "suffix:m/s²") var sprint_acceleration: float = 26.0
## Afremmen vanuit sprint in m/s²; hoger verkort de stopafstand.
@export_range(0.1, 80.0, 0.5, "suffix:m/s²") var sprint_deceleration: float = 36.0
## Maximale lichaamsdraai bij volle sprint in graden/s; lager geeft ruimere bochten.
@export_range(0.0, 1440.0, 5.0, "suffix:°/s") var sprint_turn_speed: float = 300.0
## Maximale automatische sprintopstap in meters; geen klimhoogte.
@export_range(0.0, 1.0, 0.01, "suffix:m") var sprint_step_height: float = 0.35

@export_group("Sneak")
## Maximum vooruit met Alt in m/s; sneak verandert de staande vorm niet.
@export_range(0.1, 20.0, 0.1, "suffix:m/s") var sneak_forward_speed: float = 2.0
## Zijwaartse sneaksnelheid als deel van vooruit; 0.8 betekent 80%.
@export_range(0.05, 1.0, 0.01) var sneak_side_ratio: float = 0.8
## Achterwaartse sneaksnelheid als deel van vooruit; 0.55 betekent 55%.
@export_range(0.05, 1.0, 0.01) var sneak_back_ratio: float = 0.55
## Snelheidstoename bij sneak in m/s²; hoger reageert sneller.
@export_range(0.1, 80.0, 0.5, "suffix:m/s²") var sneak_acceleration: float = 18.0
## Sneakafremming in m/s²; hoger stopt sneller.
@export_range(0.1, 80.0, 0.5, "suffix:m/s²") var sneak_deceleration: float = 28.0
## Maximale lichaamsdraai bij sneak in graden/s; hoger volgt sneller.
@export_range(0.0, 1440.0, 5.0, "suffix:°/s") var sneak_turn_speed: float = 420.0
## Maximale automatische sneakopstap in meters; de vorm moet volledig passen.
@export_range(0.0, 1.0, 0.01, "suffix:m") var sneak_step_height: float = 0.35

@export_group("Kruipen")
## Maximum vooruit bij gewoon kruipen op de grond in m/s; een slide behoudt eerst haar eigen aflopende vaart.
@export_range(0.1, 20.0, 0.1, "suffix:m/s") var crouch_forward_speed: float = 3.0
## Zijwaartse kruipsnelheid als deel van vooruit; 0.8 betekent 80%.
@export_range(0.05, 1.0, 0.01) var crouch_side_ratio: float = 0.8
## Achterwaartse kruipsnelheid als deel van vooruit; 0.55 betekent 55%.
@export_range(0.05, 1.0, 0.01) var crouch_back_ratio: float = 0.55
## Snelheidstoename bij kruipen in m/s²; hoger versnelt sneller.
@export_range(0.1, 80.0, 0.5, "suffix:m/s²") var crouch_acceleration: float = 10.0
## Kruipafremming in m/s²; hoger stopt sneller.
@export_range(0.1, 80.0, 0.5, "suffix:m/s²") var crouch_deceleration: float = 16.0
## Maximale lichaamsdraai in kruip in graden/s, ook vanuit stilstand.
@export_range(0.0, 1440.0, 5.0, "suffix:°/s") var crouch_turn_speed: float = 240.0
## Totale verticale kruipcapsulehoogte in meters; minimaal twee keer de radius.
@export_range(0.2, 3.0, 0.01, "suffix:m") var crouch_capsule_height: float = 1.1:
	set(value):
		crouch_capsule_height = value
		_refresh_if_ready()
## Straal van de kruipcapsule in meters; hoger vraagt bredere doorgangen.
@export_range(0.1, 1.0, 0.01, "suffix:m") var crouch_capsule_radius: float = 0.35:
	set(value):
		crouch_capsule_radius = value
		_refresh_if_ready()
## Maximale kruipopstap in meters; een lagere vorm maakt hogere treden niet geldig.
@export_range(0.0, 1.0, 0.01, "suffix:m") var crouch_step_height: float = 0.35
## Camerahoogte boven de voeten bij kruipen in meters; blijft binnen de vrije hoogte.
@export_range(0.05, 3.0, 0.01, "suffix:m") var crouch_eye_height: float = 0.95
## Maximale slide na C tijdens sprint op de grond of tijdens een sprong in seconden; langer schuift verder. Daarna automatisch de hoogste veilige houding; spatie springt eruit als staan veilig past. 0 schakelt slides uit.
@export_range(0.0, 2.0, 0.01, "suffix:s") var crouch_slide_duration: float = 0.75
## Horizontale slidewrijving in m/s² vanaf de slidestart; lager bewaart meer opgebouwde vaart, zonder extra snelheid te geven.
@export_range(0.0, 100.0, 0.5, "suffix:m/s²") var crouch_slide_deceleration: float = 10.0
## Maximale richtingsbijsturing tijdens de slide in graden/s; bewegen versnelt de slide niet.
@export_range(0.0, 180.0, 1.0, "suffix:°/s") var crouch_slide_steering: float = 35.0
## Onder deze horizontale snelheid in m/s eindigt de slide en richt de capsule veilig op; de ingestelde duur blijft de bovengrens.
@export_range(0.0, 5.0, 0.1, "suffix:m/s") var crouch_slide_end_speed: float = 0.8
## Lichte richtingsbijsturing bij luchtkruip in m/s²; bestaande afzetvaart blijft behouden, binnen hetzelfde afzetbudget.
@export_range(0.0, 10.0, 0.05, "suffix:m/s²") var crouch_air_acceleration: float = 0.75

@export_group("Liggen")
## Maximum vooruit op de grond in lig in m/s; vanaf de landing geldt dit budget voor de horizontale capsule.
@export_range(0.1, 20.0, 0.1, "suffix:m/s") var prone_forward_speed: float = 2.0
## Zijwaartse ligsnelheid als deel van vooruit; 0.8 betekent 80%.
@export_range(0.05, 1.0, 0.01) var prone_side_ratio: float = 0.8
## Achterwaartse ligsnelheid als deel van vooruit; 0.55 betekent 55%.
@export_range(0.05, 1.0, 0.01) var prone_back_ratio: float = 0.55
## Snelheidstoename bij liggen in m/s²; hoger versnelt sneller.
@export_range(0.1, 80.0, 0.5, "suffix:m/s²") var prone_acceleration: float = 6.0
## Ligafremming in m/s²; hoger stopt sneller.
@export_range(0.1, 80.0, 0.5, "suffix:m/s²") var prone_deceleration: float = 10.0
## Maximale lichaamsdraai in lig in graden/s; botsingsruimte kan deze verder beperken.
@export_range(0.0, 1440.0, 5.0, "suffix:°/s") var prone_turn_speed: float = 120.0
## Totale horizontale capsulelengte in meters, inclusief ronde uiteinden.
@export_range(0.2, 3.0, 0.01, "suffix:m") var prone_capsule_length: float = 1.8:
	set(value):
		prone_capsule_length = value
		_refresh_if_ready()
## Straal van de ligcapsule in meters; hoogte en breedte zijn twee keer deze waarde.
@export_range(0.1, 1.0, 0.01, "suffix:m") var prone_capsule_radius: float = 0.35:
	set(value):
		prone_capsule_radius = value
		_refresh_if_ready()
## Maximale ligopstap in meters; hoogte en volledig volume worden opnieuw getoetst.
@export_range(0.0, 1.0, 0.01, "suffix:m") var prone_step_height: float = 0.35
## Camerahoogte boven de voeten bij liggen in meters; moet onder het plafond passen.
@export_range(0.05, 3.0, 0.01, "suffix:m") var prone_eye_height: float = 0.55
## Lichte richtingsbijsturing bij luchtlig in m/s²; afzetvaart blijft behouden en liggen geeft geen landingsslide.
@export_range(0.0, 10.0, 0.05, "suffix:m/s²") var prone_air_acceleration: float = 0.5

@export_group("Draaien en tegensturen")
## Maximale lichaamsdraai bij gewone staande stilstand in graden/s.
@export_range(0.0, 1440.0, 5.0, "suffix:°/s") var idle_turn_speed: float = 720.0
## Relatieve hoofdhoek in graden waarbij een stilstaand lichaam begint bij te draaien; kleiner reageert eerder.
@export_range(0.0, 85.0, 1.0, "suffix:°") var idle_body_turn_start_angle: float = 60.0
## Relatieve hoofdhoek in graden waarbij stilstaand bijdraaien stopt; lager laat het lichaam verder volgen zonder alles recht te trekken.
@export_range(0.0, 85.0, 1.0, "suffix:°") var idle_body_turn_stop_angle: float = 45.0
## Maximale lichaamsdraai in de lucht in graden/s; luchtsturing blijft afzonderlijk begrensd.
@export_range(0.0, 1440.0, 5.0, "suffix:°/s") var air_turn_speed: float = 180.0
## Extra remming bij tegengestelde input; 1.25 remt 25% sterker, zonder extra snelheid.
@export_range(1.0, 3.0, 0.05) var countersteer_brake_factor: float = 1.25

@export_group("Springen")
## Hoogte boven het afzetpunt in meters vanuit stilstand, vóór vermoeidheid.
@export_range(0.1, 6.0, 0.05, "suffix:m") var standing_jump_height: float = 2.0
## Hoogte boven het afzetpunt in meters bij volle loopsnelheid, vóór vermoeidheid.
@export_range(0.1, 6.0, 0.05, "suffix:m") var walking_jump_height: float = 1.25
## Hoogte boven het afzetpunt in meters bij volle sprint, vóór vermoeidheid.
@export_range(0.1, 6.0, 0.05, "suffix:m") var sprint_jump_height: float = 0.7
## Kleine spronghoogte met sneak in meters; blijft bruikbaar voor een opstapje.
@export_range(0.1, 3.0, 0.01, "suffix:m") var sneak_jump_height: float = 0.45
## Minimum sneakhoogte in meters bij vermoeidheid; nooit hoger dan de ingestelde basishoogte.
@export_range(0.0, 3.0, 0.01, "suffix:m") var sneak_min_jump_height: float = 0.4
## Eenmalige horizontale sprintafzetbonus in m/s; oude bonussen worden nooit opgeteld.
@export_range(0.0, 15.0, 0.1, "suffix:m/s") var sprint_jump_boost: float = 1.5
## Bijstuurversnelling in de lucht in m/s², binnen de vaste totale afzetlimiet.
@export_range(0.0, 30.0, 0.1, "suffix:m/s²") var air_acceleration: float = 3.5
## Geleidelijke horizontale luchtrem in m/s² bij input tegen de werkelijke vaart; ook extra rem tijdens een slide, zonder hoogte te veranderen.
@export_range(0.0, 40.0, 0.25, "suffix:m/s²") var air_brake_acceleration: float = 8.0
## Klein luchtstuur-budget in m/s bij bijna stilstaande afzet of na een wandstop; geeft geen sprint en herstelt verloren sprintmomentum niet.
@export_range(0.0, 3.0, 0.05, "suffix:m/s") var air_min_control_speed: float = 0.8
## Verticale versnelling in m/s²; hoger verkort de vlucht bij dezelfde spronghoogte.
@export_range(1.0, 40.0, 0.5, "suffix:m/s²") var gravity_strength: float = 20.0
## Seconden waarin een nieuwe sprongdruk na een rand nog mag; één afzet per grondcontact.
@export_range(0.0, 0.3, 0.005, "suffix:s") var coyote_time: float = 0.08
## Seconden dat een nieuwe vroege sprongdruk vóór landing geldig blijft; vasthouden herhaalt niet.
@export_range(0.0, 0.3, 0.005, "suffix:s") var jump_buffer_time: float = 0.10

@export_group("Sprongvermoeidheid")
## Maak herhaalde sprongen zwakker; uit laat de onafhankelijke snelheidsgrens volledig actief.
@export var jump_fatigue_enabled: bool = true
## Vermoeidheid toegevoegd na een stilstandsprong; 0.25 is 25 procentpunten.
@export_range(0.0, 1.0, 0.01) var standing_jump_fatigue_cost: float = 0.25
## Vermoeidheid toegevoegd na een loopsprong; 0.30 is 30 procentpunten.
@export_range(0.0, 1.0, 0.01) var walking_jump_fatigue_cost: float = 0.30
## Vermoeidheid toegevoegd na een sprintsprong; 0.40 is 40 procentpunten.
@export_range(0.0, 1.0, 0.01) var sprint_jump_fatigue_cost: float = 0.40
## Vermoeidheid toegevoegd na een sneaksprong; 0.10 is 10 procentpunten.
@export_range(0.0, 1.0, 0.01) var sneak_jump_fatigue_cost: float = 0.10
## Grondseconden voor herstel vanaf 100% stilstandvermoeidheid; lucht telt niet.
@export_range(0.01, 5.0, 0.01, "suffix:s") var standing_jump_recovery_time: float = 0.65
## Grondseconden voor herstel vanaf 100% loopvermoeidheid; kleinere schuld herstelt evenredig sneller.
@export_range(0.01, 5.0, 0.01, "suffix:s") var walking_jump_recovery_time: float = 0.80
## Grondseconden voor herstel vanaf 100% sprintvermoeidheid; de reeks bewaart haar langzaamste duur.
@export_range(0.01, 5.0, 0.01, "suffix:s") var sprint_jump_recovery_time: float = 1.0
## Grondseconden voor herstel vanaf 100% sneakvermoeidheid; wist eerdere sprintschuld niet.
@export_range(0.01, 5.0, 0.01, "suffix:s") var sneak_jump_recovery_time: float = 0.35
## Overblijvend deel van stilstandhoogte bij volle vermoeidheid; 0.6 betekent 60%.
@export_range(0.0, 1.0, 0.01) var standing_jump_min_height_factor: float = 0.60
## Overblijvend deel van loophoogte bij volle vermoeidheid; 0.65 betekent 65%.
@export_range(0.0, 1.0, 0.01) var walking_jump_min_height_factor: float = 0.65
## Overblijvend deel van sprinthoogte bij volle vermoeidheid; 0.65 betekent 65%.
@export_range(0.0, 1.0, 0.01) var sprint_jump_min_height_factor: float = 0.65
## Overblijvend deel van sneakhoogte bij volle vermoeidheid; de absolute minimumhoogte blijft gelden.
@export_range(0.0, 1.0, 0.01) var sneak_jump_min_height_factor: float = 0.90
## Overblijvend deel van extra sprintafstand bij volle vermoeidheid; 0 laat de bonus vervallen.
@export_range(0.0, 1.0, 0.01) var sprint_jump_min_boost_factor: float = 0.0

@export_group("Botsing en automatisch herstellen")
## Straal van de staande capsule in meters; hoger vraagt meer ruimte.
@export_range(0.1, 1.0, 0.01, "suffix:m") var capsule_radius: float = 0.35:
	set(value):
		capsule_radius = value
		_refresh_if_ready()
## Totale staande hoogte in meters inclusief ronde uiteinden; minimaal twee keer de radius.
@export_range(0.3, 3.0, 0.05, "suffix:m") var capsule_height: float = 1.8:
	set(value):
		capsule_height = value
		_refresh_if_ready()
## Maximale automatische loopopstap in meters; het volledige volume moet passen.
@export_range(0.0, 1.0, 0.01, "suffix:m") var step_height: float = 0.35
## Extra vrije meters vereist vóór hoger worden; voorkomt schuren en flikkerende houdingen.
@export_range(0.0, 0.15, 0.005, "suffix:m") var posture_clearance_margin: float = 0.03
## Aaneengesloten veilige grondseconden vóór automatisch hoger worden; handmatige houding blijft bewaard.
@export_range(0.0, 1.0, 0.01, "suffix:s") var posture_restore_time: float = 0.12

@export_group("Camera: kijken en hoofd")
## Horizontale kijkgevoeligheid in graden per schermpixel; hoger draait de camera sneller.
@export_range(0.02, 1.0, 0.01, "suffix:°/px") var look_sensitivity_x: float = 0.12
## Verticale kijkgevoeligheid in graden per schermpixel; onafhankelijk van horizontaal kijken.
@export_range(0.02, 1.0, 0.01, "suffix:°/px") var look_sensitivity_y: float = 0.10
## Grootste hoofddraai links/rechts ten opzichte van het lichaam, in graden. Nooit een volledige omwenteling.
@export_range(1.0, 120.0, 1.0, "suffix:°") var head_max_yaw: float = 85.0
## Vanaf deze relatieve hoofdhoek remt verder cameradraaien geleidelijk af; terugkijken blijft direct.
@export_range(0.0, 120.0, 1.0, "suffix:°") var head_soft_limit_start: float = 60.0
## Laagste verticale hoofd-/kijkhoek in graden; negatieve waarden kijken omlaag.
@export_range(-85.0, 0.0, 1.0, "suffix:°") var camera_min_pitch: float = -65.0
## Hoogste verticale hoofd-/kijkhoek in graden; positieve waarden kijken omhoog.
@export_range(0.0, 85.0, 1.0, "suffix:°") var camera_max_pitch: float = 70.0
## Grootte van de zachte zone vóór beide verticale hoofdgrenzen in graden; terugkijken blijft direct, 0 gebruikt alleen de harde grens.
@export_range(0.0, 30.0, 1.0, "suffix:°") var camera_pitch_soft_limit_range: float = 10.0
## Verticale kijkhoek in graden bij starten/reset; negatief kijkt iets naar beneden.
@export_range(-60.0, 60.0, 1.0, "suffix:°") var camera_start_pitch: float = -12.0

@export_group("Camera: zoom en botsing")
## Gewenste beginafstand vanaf het hoofd in meters; dichtbij de first-persongrens start je in de ogen.
@export_range(0.0, 12.0, 0.1, "suffix:m") var camera_start_distance: float = 4.0
## Grootste instelbare scrollafstand in meters; muurbotsing verandert deze voorkeur niet.
@export_range(0.1, 20.0, 0.1, "suffix:m") var camera_max_distance: float = 8.0
## Gewenste afstandsverandering in meters per scrollstap; hoger zoomt sneller.
@export_range(0.05, 2.0, 0.05, "suffix:m") var camera_zoom_step: float = 0.5
## Onder deze gewenste afstand in meters klikt de zoom naar de ogen; eigen capsule en naam verdwijnen alleen voor de eigen camera.
@export_range(0.0, 1.0, 0.01, "suffix:m") var first_person_threshold: float = 0.45
## Staande ooghoogte boven de voetzool in meters; wordt veilig begrensd binnen de huidige capsule.
@export_range(0.1, 3.0, 0.01, "suffix:m") var camera_eye_height: float = 1.62
## Seconden om de helft van het zoomverschil te overbruggen; 0 maakt zoomen direct.
@export_range(0.0, 0.5, 0.01, "suffix:s") var camera_zoom_half_life: float = 0.06
## Straal van het cameravolume in meters; groter houdt meer afstand. Beeldranden bepalen een veilige minimumstraal; lage houdingen begrenzen een te grote straal.
@export_range(0.05, 0.5, 0.01, "suffix:m") var camera_collision_radius: float = 0.18
## Seconden om de helft van de vrije afstand terug te krijgen na een obstakel; naar binnen gaat altijd direct veilig.
@export_range(0.0, 0.5, 0.01, "suffix:s") var camera_obstacle_return_half_life: float = 0.12
## Halveringstijd in seconden bij veilig omhooggaan na een houdingswissel; lager worden volgt direct voor plafondveiligheid.
@export_range(0.0, 0.5, 0.01, "suffix:s") var camera_eye_half_life: float = 0.08
## Halveringstijd in seconden voor kleine vloeropstapjes; sprongen/val volgen zonder extra vertraging.
@export_range(0.0, 0.5, 0.01, "suffix:s") var camera_step_half_life: float = 0.07

@export_group("Camera: positievolging")
## Halveringstijd van kleine horizontale cameravolging in seconden; 0 volgt direct. De kijkrichting blijft altijd direct.
@export_range(0.0, 0.1, 0.001, "suffix:s") var camera_follow_half_life: float = 0.018
## Extra horizontale volgverzachting in first person, in seconden; standaard 0 voorkomt extra vertraging in de ogen.
@export_range(0.0, 0.1, 0.001, "suffix:s") var camera_first_person_follow_half_life: float = 0.0
## Grootste totale horizontale camera-afwijking in meters, voor volgvertraging en nawerking samen; 0 schakelt beide uit. Botsingen kunnen deze grens verkleinen.
@export_range(0.0, 0.3, 0.01, "suffix:m") var camera_follow_max_lag: float = 0.12

@export_group("Camera: subtiele nawerking")
## Laat de camera na stevig horizontaal afremmen heel kort enkele centimeters doorgaan; kijkrichting blijft direct.
@export var camera_inertia_enabled: bool = true
## Maximale extra veeruitslag in meters. 0,035 is 3,5 cm; de zichtbare doorschieting bij normaal sprintafremmen is kleiner. De totale afwijking blijft ook binnen Camera Follow Max Lag.
@export_range(0.0, 0.08, 0.001, "suffix:m") var camera_inertia_amount: float = 0.035
## Ongeveer de tijd in seconden waarin het remaccent grotendeels tot rust komt. Kleine waarden corrigeren sneller, zonder herhaald heen-en-weer veren.
@export_range(0.05, 2.0, 0.01, "suffix:s") var camera_inertia_recovery_time: float = 0.32
## Onder deze horizontale snelheid in meters per seconde geeft afremmen geen extra nawerking; langzaam bewegen blijft rustig.
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var camera_inertia_min_speed: float = 3.0
## Horizontale snelheid in meters per seconde waarop het remaccent zijn volle sterkte bereikt. Tussen de minimum- en deze snelheid neemt de sterkte geleidelijk toe.
@export_range(0.1, 30.0, 0.1, "suffix:m/s") var camera_inertia_full_speed: float = 9.0
## Gebruik dit extra remaccent ook wanneer bewust naar first person is ingezoomd. Standaard uit voor een stabiel gezichtspunt.
@export var camera_first_person_inertia_enabled: bool = false

## Aandeel van de echte pasvluchthoogte dat de camera volgt: 0 houdt haar rustig, 1 volgt het lichaam volledig.
@export_range(0.0, 1.0, 0.05) var camera_stride_follow_ratio: float = 0.1
@export_group("Camera: landingsaccent")
## Kleine reactie op echte impactlandingen met gedeeld accentbudget; uit bewaart de eerdere remveer exact. Audio staat hier los van.
@export var camera_landing_enabled: bool = true
## Grootste third-persondip in meters; 0 geeft geen positieaccent bij landen.
@export_range(0.0, 0.05, 0.001, "suffix:m") var camera_landing_max_dip: float = 0.01
## Grootste first-persondip in meters; standaard 0 houdt het eigen zicht rustig.
@export_range(0.0, 0.05, 0.001, "suffix:m") var camera_first_person_landing_max_dip: float = 0.0
## Minimale neerwaartse impactsnelheid voor een dip in m/s; normale opstappen tellen niet mee.
@export_range(0.0, 10.0, 0.1, "suffix:m/s") var camera_landing_min_speed: float = 0.75
## Impactsnelheid in m/s waarbij de dip zijn maximum bereikt; hogere impact stapelt geen extra uitslag.
@export_range(0.1, 30.0, 0.1, "suffix:m/s") var camera_landing_full_speed: float = 8.0
## Tijd tot de laagste camerapositie in seconden; een korte zachte aanloop voorkomt een positieklap.
@export_range(0.0, 0.2, 0.005, "suffix:s") var camera_landing_attack_time: float = 0.045
## Volledige terugkeertijd na de dip in seconden; keert eenmaal rustig terug zonder nawippen.
@export_range(0.01, 1.0, 0.01, "suffix:s") var camera_landing_recovery_time: float = 0.20
## Gedeelde 3D-uitslag van remveer en landing in meters wanneer Landing Enabled aan staat; met volglag ook begrensd door Follow Max Lag.
@export_range(0.0, 0.1, 0.001, "suffix:m") var camera_accent_max_offset: float = 0.04

@export_group("Camera: beeldhoek")
## Verticale third-personbeeldhoek in graden; hoger toont meer omgeving. Dit is geen horizontale FOV.
@export_range(30.0, 100.0, 1.0, "suffix:° verticaal") var camera_fov_third_person: float = 70.0
## Verticale first-personbeeldhoek in graden; gebruikt uitsluitend bij bewust naar de ogen zoomen.
@export_range(30.0, 100.0, 1.0, "suffix:° verticaal") var camera_fov_first_person: float = 75.0
## Dynamische FOV voor werkelijke sprint en sneak/kruip/lig; uit houdt de gekozen basisbeeldhoek constant. F4 schakelt dit tijdens spelen.
@export var camera_speed_fov_enabled: bool = true
## Grootste extra verticale beeldhoek in graden bij sprint; sprongbonus vergroot deze waarde niet.
@export_range(0.0, 15.0, 0.5, "suffix:°") var camera_sprint_fov_bonus: float = 6.0
## Extra verticale FOV in graden bij sneak; negatief geeft rustiger/iets nauwer zicht. F4 schakelt ook deze profielverandering uit.
@export_range(-15.0, 15.0, 0.5, "suffix:°") var camera_sneak_fov_offset: float = -2.0
## Extra verticale FOV in graden bij kruipen; negatief versmalt licht. Overgang gebruikt dezelfde FOV-halveringstijden.
@export_range(-15.0, 15.0, 0.5, "suffix:°") var camera_crouch_fov_offset: float = -3.0
## Extra verticale FOV in graden bij liggen; onafhankelijk van sneak en kruip. 0 behoudt de gewone basisbeeldhoek.
@export_range(-15.0, 15.0, 0.5, "suffix:°") var camera_prone_fov_offset: float = -5.0
## Seconden om de helft van een toenemende FOV-afwijking weg te werken; lager reageert sneller.
@export_range(0.0, 1.0, 0.01, "suffix:s") var camera_fov_rise_half_life: float = 0.10
## Seconden om de helft van de FOV-terugkeer weg te werken; hoger maakt afremmen visueel rustiger.
@export_range(0.0, 1.0, 0.01, "suffix:s") var camera_fov_return_half_life: float = 0.18

@export_group("Camera: lucht- en slidebeeldhoek")
## Verfijn FOV met resterende luchtvaart en actieve slide; uit herstelt de eerdere FOV-mapping exact.
@export var camera_fov_refinement_enabled: bool = true
## Extra verticale third-personbeeldhoek bij volle slidevaart, boven de kruipbasis.
@export_range(0.0, 10.0, 0.25, "suffix:°") var camera_slide_fov_bonus: float = 3.0
## Extra verticale first-personbeeldhoek bij volle slidevaart; kleiner houdt het eigen zicht rustiger.
@export_range(0.0, 10.0, 0.25, "suffix:°") var camera_first_person_slide_fov_bonus: float = 1.5
## Werkelijke ondersteunde slidesnelheid in m/s voor de volle bijdrage; stilstand of alleen input geeft geen bonus.
@export_range(0.1, 30.0, 0.1, "suffix:m/s") var camera_slide_fov_reference_speed: float = 9.0

@export_group("Debug")
## Toon lichaams-/hoofd-/input-/bewegingspijlen en de waarden voor afstelling.
@export var debug_enabled: bool = true:
	set(value):
		debug_enabled = value
		_refresh_if_ready()

@export_group("Audio: algemeen")
## Schakel alle Character-contactaudio aan of uit; verandert beweging en camera niet.
@export var feedback_enabled: bool = true
## Totale contactsterkte in dB; 0 houdt de bronsterkte, negatieve waarden klinken zachter.
@export_range(-60.0, 6.0, 0.5, "suffix:dB") var feedback_master_volume_db: float = -6.0
## Verste hoorafstand van andere Characters in meters; eigen contactaudio blijft zoomonafhankelijk.
@export_range(1.0, 100.0, 1.0, "suffix:m") var feedback_max_distance: float = 24.0
## Referentieafstand voor ruimtelijke verzwakking in meters; groter houdt anderen langer duidelijk hoorbaar.
@export_range(0.1, 20.0, 0.1, "suffix:m") var feedback_unit_size: float = 4.0

@export_group("Audio: samples")
## Varianten voor stappen tijdens lopen, sprint en sneak; lege lijst geeft stil contact.
@export var feedback_footstep_samples: Array[AudioStream] = [preload("res://assets/audio/footstep_concrete_000.wav"), preload("res://assets/audio/footstep_concrete_001.wav"), preload("res://assets/audio/footstep_concrete_002.wav"), preload("res://assets/audio/footstep_concrete_003.wav"), preload("res://assets/audio/footstep_concrete_004.wav")]
## Zachtere contactvarianten voor kruip en lig; geen gewone voetstap nodig bij lage houdingen.
@export var feedback_low_contact_samples: Array[AudioStream] = [preload("res://assets/audio/low_contact_carpet_000.wav"), preload("res://assets/audio/low_contact_carpet_001.wav"), preload("res://assets/audio/low_contact_carpet_002.wav")]
## Korte afzetvarianten; spelen uitsluitend wanneer een echte sprong geaccepteerd is.
@export var feedback_jump_samples: Array[AudioStream] = [preload("res://assets/audio/jump_soft_000.wav"), preload("res://assets/audio/jump_soft_001.wav")]
## Landingsvarianten; impact bepaalt sterkte. Slide-landing geeft één cue plus de schuurlaag.
@export var feedback_landing_samples: Array[AudioStream] = [preload("res://assets/audio/landing_soft_000.wav"), preload("res://assets/audio/landing_soft_001.wav")]
## Naadloos schuurfragment voor een actieve slide; de component maakt zijn eigen loopkopie.
@export var feedback_slide_sample: AudioStream = preload("res://assets/audio/slide_scrape_loop.wav")

@export_group("Audio: cadans en intensiteit")
## Werkelijk ondersteunde loopmeters per contact; kleiner geeft meer stappen, nooit door muurdruk.
@export_range(0.2, 4.0, 0.05, "suffix:m") var walk_step_distance: float = 1.8
## Extra contactsterkte tijdens lopen in dB, boven het algemene contactvolume.
@export_range(-30.0, 6.0, 0.5, "suffix:dB") var walk_contact_volume_db: float = 0.0
## Werkelijk ondersteunde sprintmeters per contact; de grotere snelheid bepaalt de uiteindelijke cadans.
@export_range(0.2, 4.0, 0.05, "suffix:m") var sprint_step_distance: float = 2.4
## Extra contactsterkte tijdens sprint in dB.
@export_range(-30.0, 6.0, 0.5, "suffix:dB") var sprint_contact_volume_db: float = 1.0
## Werkelijk ondersteunde sneakmeters per contact; langzaam bewegen klinkt minder vaak.
@export_range(0.2, 4.0, 0.05, "suffix:m") var sneak_step_distance: float = 1.3
## Extra contactsterkte tijdens sneak in dB; negatief geeft zachtere stappen en afzet.
@export_range(-30.0, 6.0, 0.5, "suffix:dB") var sneak_contact_volume_db: float = -12.0
## Werkelijk ondersteunde kruipmeters per laag contactgeluid.
@export_range(0.2, 4.0, 0.05, "suffix:m") var crouch_step_distance: float = 1.2
## Extra contactsterkte tijdens kruipen in dB.
@export_range(-30.0, 6.0, 0.5, "suffix:dB") var crouch_contact_volume_db: float = -6.0
## Werkelijk ondersteunde ligmeters per laag contactgeluid.
@export_range(0.2, 4.0, 0.05, "suffix:m") var prone_step_distance: float = 1.0
## Extra contactsterkte tijdens liggen in dB.
@export_range(-30.0, 6.0, 0.5, "suffix:dB") var prone_contact_volume_db: float = -10.0
## Daaronder geen afstandscadans in m/s; voorkomt contactspam door minieme vloerbeweging.
@export_range(0.0, 1.0, 0.01, "suffix:m/s") var feedback_step_min_speed: float = 0.10
## Basissterkte van afstandscontacten in dB, vóór profiel en kleine variatie.
@export_range(-30.0, 6.0, 0.5, "suffix:dB") var feedback_step_volume_db: float = -2.0
## Willekeurige toonhoogteafwijking als deel van 1; 0,025 is ongeveer 2,5%, 0 schakelt dit uit.
@export_range(0.0, 0.10, 0.005) var feedback_pitch_variation: float = 0.025
## Willekeurige volumeafwijking in dB; klein houdt herhaling natuurlijk zonder grote verschillen.
@export_range(0.0, 3.0, 0.1, "suffix:dB") var feedback_volume_variation_db: float = 1.0

@export_group("Audio: afzet en landing")
## Basissterkte van een geaccepteerde afzet in dB; sneak gebruikt bovendien zijn zachtere profiel.
@export_range(-30.0, 6.0, 0.5, "suffix:dB") var feedback_jump_volume_db: float = -5.0
## Minimale neerwaartse impactsnelheid in m/s voor een landingscue; gewone opstapsteun geeft geen impact.
@export_range(0.0, 10.0, 0.1, "suffix:m/s") var landing_min_speed: float = 0.75
## Neerwaartse impactsnelheid in m/s waarop de landing zijn volle ingestelde sterkte bereikt.
@export_range(0.1, 30.0, 0.1, "suffix:m/s") var landing_full_speed: float = 8.0
## Landingssterkte bij de minimale impact in dB, vóór algemeen volume.
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var feedback_landing_min_volume_db: float = -12.0
## Landingssterkte bij volle impact in dB; sterkere vallen worden niet steeds luider.
@export_range(-30.0, 6.0, 0.5, "suffix:dB") var feedback_landing_max_volume_db: float = -2.0

@export_group("Audio: slideschuurlaag")
## Sterkte van de schuurlaag op referentiesnelheid in dB; deelt het algemene contactvolume.
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var feedback_slide_volume_db: float = -2.0
## Horizontale snelheid in m/s waarop de schuurlaag volledig klinkt; afremmen maakt hem zachter.
@export_range(0.1, 30.0, 0.1, "suffix:m/s") var feedback_slide_reference_speed: float = 9.0
## Daaronder geen schuurlaag in m/s; alleen werkelijk ondersteunde, actieve slide klinkt.
@export_range(0.0, 2.0, 0.05, "suffix:m/s") var slide_min_speed: float = 0.25
## Halveringstijd van de schuursterkte in seconden; 0 schakelt zonder fade, sprong/reset/uit stoppen direct.
@export_range(0.0, 0.5, 0.01, "suffix:s") var feedback_slide_fade_time: float = 0.08

static var _used_presentation_layers: Dictionary = {}

var _external_intent: AtlasCharacterIntent
var _stride: AtlasStrideScheduler = AtlasStrideScheduler.new()
var _procedural_leg_length: float = 0.673775
var _air_kind: String = "none"
var _stride_jump_available: bool = false
var _queued_impulse: Vector3 = Vector3.ZERO
var _external_speed_allowance: float = 0.0
var _stride_probe_count: int = 0
var _ground_step_requested: bool = false
var _controlled: bool = false
var _spawn_transform: Transform3D
var _look_input: Vector2 = Vector2.ZERO
var _camera_motion: AtlasCharacterCameraMotion = AtlasCharacterCameraMotion.new()
var _presentation_layer: int = 0
var _input_direction: Vector3 = Vector3.ZERO
var _movement_direction: Vector3 = Vector3.ZERO
var _actual_speed: float = 0.0
var _sprint_requested: bool = false
var _sneak_requested: bool = false
var _last_ground_state: String = "lopen"
var _posture: int = Posture.STAND
var _manual_posture: int = Posture.STAND
var _prone_return_posture: int = Posture.STAND
var _auto_posture_demand: int = Posture.STAND
var _auto_probe_distance: float = 0.0
var _posture_changed_this_frame: bool = false
var _manual_changed_this_frame: bool = false
var _restore_clear_time: float = 0.0
var _turn_rate: float = 0.0
var _body_turn_blocked: bool = false
var _idle_realigning: bool = false
var _air_speed_cap: float = 0.0
var _air_min_control_active: bool = false
var _air_braking: bool = false
var _slide_requested_this_frame: bool = false
var _slide_pending: bool = false
var _slide_active: bool = false
var _slide_time_left: float = 0.0
var _slide_ground_exit_pending: bool = false
var _jump_profile: String = "geen"
var _jump_height: float = 0.0
var _launch_speed: float = 0.0
var _jump_boost: float = 0.0
var _fatigue: float = 0.0
var _fatigue_recovery_duration: float = 0.0
var _coyote_remaining: float = 0.0
var _jump_buffer_remaining: float = 0.0
var _ground_jump_available: bool = false
var _jumped_last_frame: bool = false
var _last_step_height: float = 0.0
var _step_support_remaining: float = 0.0
var _step_support_point: Vector3 = Vector3.ZERO
var _step_support_direction: Vector3 = Vector3.ZERO

@onready var _collider: CollisionShape3D = $CollisionShape3D
@onready var _capsule: MeshInstance3D = $Presentation/Capsule
@onready var _name_label: Label3D = $Presentation/NameLabel
@onready var _camera_pivot: AtlasCharacterCamera = $CameraPivot
@onready var _head_debug: AtlasCharacterHeadDebug = $DebugArrows/HeadArrow
@onready var _feedback: AtlasCharacterFeedback = $Feedback
@onready var _procedural_visual: AtlasCharacterPresentation = $Presentation/ProceduralBody
var _observed_body_profile: AtlasCharacterBodyProfile
var _body_rig_signature: Array = []
@onready var _debug_arrows: Node3D = $DebugArrows
@onready var _input_arrow: Node3D = $DebugArrows/InputArrow
@onready var _movement_arrow: Node3D = $DebugArrows/MovementArrow


func _ready() -> void:
	_spawn_transform = global_transform
	if not Engine.is_editor_hint():
		_allocate_presentation_layer()
	_refresh_presentation()
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	procedural_frame_ready.connect(_consume_procedural_frame)
	_head_debug.initialize(self)
	_camera_pivot.look_direction_changed.connect(set_look_input)
	jump_accepted.connect(_camera_pivot.capture_jump)
	ground_motion_updated.connect(_camera_pivot.capture_ground_motion)
	posture_changed.connect(_camera_pivot.capture_posture)
	_camera_pivot.initialize(self)
	_camera_pivot.player_look_enabled = _external_intent == null
	contact_frame_ready.connect(_camera_pivot.capture_contact)
	_feedback.initialize(self)
	_feedback.set_controlled(_controlled)
	jump_accepted.connect(_feedback.capture_jump)
	contact_frame_ready.connect(_feedback.consume_contact)


func _exit_tree() -> void:
	if _presentation_layer > 0:
		_used_presentation_layers.erase(_presentation_layer)


func _refresh_if_ready() -> void:
	if is_node_ready():
		_refresh_presentation()
		update_configuration_warnings()


func _refresh_presentation() -> void:
	var dimensions := _posture_dimensions(_posture)
	var shape := CapsuleShape3D.new()
	shape.radius = dimensions.x
	shape.height = dimensions.y
	_collider.shape = shape
	_collider.position = Vector3(0.0, _posture_vertical_height(_posture) * 0.5, 0.0)
	_collider.rotation = Vector3(PI * 0.5 if _posture == Posture.PRONE else 0.0, 0.0, 0.0)
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = dimensions.x
	capsule_mesh.height = dimensions.y
	_capsule.mesh = capsule_mesh
	_capsule.position = _collider.position
	_capsule.rotation = _collider.rotation
	_capsule.reset_physics_interpolation()
	var material := StandardMaterial3D.new()
	material.albedo_color = capsule_color
	material.roughness = 0.7
	_capsule.material_override = material
	_name_label.text = display_name
	_name_label.position.y = _posture_vertical_height(_posture) + name_height
	_name_label.font_size = name_font_size
	_name_label.visible = name_visible
	_debug_arrows.visible = debug_enabled
	_refresh_procedural_body()


func _refresh_procedural_body(force: bool = false) -> void:
	if not is_instance_valid(_procedural_visual):
		return
	_capsule.visible = not procedural_enabled
	_procedural_visual.visible = procedural_enabled
	_procedural_visual.process_mode = Node.PROCESS_MODE_INHERIT if procedural_enabled else Node.PROCESS_MODE_DISABLED
	if not procedural_enabled:
		return
	if body_profile != _observed_body_profile:
		if _observed_body_profile != null and _observed_body_profile.changed.is_connected(_on_body_profile_changed):
			_observed_body_profile.changed.disconnect(_on_body_profile_changed)
		_observed_body_profile = body_profile
		body_profile.changed.connect(_on_body_profile_changed)
		force = true
	var signature := body_profile.rig_signature()
	if force or signature != _body_rig_signature:
		_body_rig_signature = signature
		_procedural_visual.setup(self, body_profile)


func _on_body_profile_changed() -> void:
	# Een Inspector-edit kan meerdere velden tegelijk zetten. Eén verversing
	# vergelijkt de rigvelden; gewone pas-/curvewaarden worden direct gelezen.
	call_deferred("_refresh_procedural_body")


func _consume_procedural_frame(frame: AtlasCharacterContactFrame) -> void:
	if procedural_enabled:
		_procedural_visual.consume_frame(frame)


func _allocate_presentation_layer() -> void:
	for layer in range(2, 21):
		if not _used_presentation_layers.has(layer):
			_presentation_layer = layer
			_used_presentation_layers[layer] = get_instance_id()
			break
	if _presentation_layer == 0:
		push_warning("Geen vrije Character-renderlayer: eerste-persoonszicht vraagt maximaal 19 Characters.")
		return
	var mask := 1 << (_presentation_layer - 1)
	_capsule.layers = mask
	_name_label.layers = mask
	for arrow in _debug_arrows.get_children():
		for mesh in arrow.get_children():
			if mesh is VisualInstance3D:
				mesh.layers = mask


func get_presentation_layer() -> int:
	return _presentation_layer


func get_eye_height() -> float:
	if _posture == Posture.CROUCH:
		return crouch_eye_height
	if _posture == Posture.PRONE:
		return prone_eye_height
	return camera_eye_height


func get_camera_clearance_height() -> float:
	return _posture_vertical_height(_posture)


func get_camera_motion_profile() -> String:
	return _movement_state()


func get_camera_grounded() -> bool:
	return is_on_floor() or _step_support_remaining > 0.0


func get_camera_motion_sample() -> AtlasCharacterCameraMotion:
	_camera_motion.body_yaw = global_rotation.y
	_camera_motion.motion_profile = _movement_state()
	_camera_motion.grounded = get_camera_grounded()
	_camera_motion.sliding = _slide_active
	_camera_motion.air_kind = _air_kind
	_camera_motion.stride_offset_y = maxf(global_position.y - _stride.takeoff_y, 0.0) if _air_kind == "stride" else 0.0
	_camera_motion.eye_height = get_eye_height()
	_camera_motion.clearance_height = _posture_vertical_height(_posture)
	_camera_motion.horizontal_velocity = Vector3(velocity.x, 0.0, velocity.z)
	_camera_motion.actual_horizontal_velocity = _movement_direction * _actual_speed
	var local := global_basis.inverse() * _camera_motion.actual_horizontal_velocity
	var direction := Vector2(local.x, local.z)
	_camera_motion.walk_speed_limit = direction_speed_limit(direction, false)
	_camera_motion.sprint_speed_limit = direction_speed_limit(direction, true)
	_camera_motion.excluded_body = get_rid()
	_camera_motion.presentation_layer = _presentation_layer
	_camera_motion.standing_radius = capsule_radius
	# De child-rig is eerder ready dan deze root. Fysieke knopen bestaan dan al,
	# maar de root-onreadyvelden zijn nog niet ingevuld.
	var collider := _collider
	if not is_instance_valid(collider):
		collider = get_node_or_null("CollisionShape3D") as CollisionShape3D
	_camera_motion.body_shape = collider.shape if collider != null else null
	_camera_motion.body_shape_transform = collider.global_transform if collider != null else global_transform
	return _camera_motion


func set_look_input(yaw: float, pitch: float) -> void:
	# Logische besturingsinvoer, onafhankelijk van de camera-rendertransform.
	_look_input = Vector2(yaw, pitch)
	_head_debug.set_head_orientation(yaw, pitch, get_eye_height())


func get_look_input() -> Vector2:
	return _look_input


func set_controlled(value: bool) -> void:
	_controlled = value
	if not is_node_ready():
		return
	_camera_pivot.set_controlled(value)
	_feedback.set_controlled(value)
	if not value:
		_input_direction = Vector3.ZERO
		_jump_buffer_remaining = 0.0


func is_controlled() -> bool:
	return _controlled


func reset_to_spawn() -> void:
	_stride.reset()
	_air_kind = "none"
	_stride_jump_available = false
	_queued_impulse = Vector3.ZERO
	_external_speed_allowance = 0.0
	_stride_probe_count = 0
	if _external_intent != null:
		_external_intent.clear_edges()
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	_input_direction = Vector3.ZERO
	_movement_direction = Vector3.ZERO
	_actual_speed = 0.0
	_last_ground_state = "lopen"
	_sprint_requested = false
	_sneak_requested = false
	_posture = Posture.STAND
	_manual_posture = Posture.STAND
	_prone_return_posture = Posture.STAND
	_auto_posture_demand = Posture.STAND
	_auto_probe_distance = 0.0
	_restore_clear_time = 0.0
	_air_speed_cap = 0.0
	_air_min_control_active = false
	_air_braking = false
	_slide_requested_this_frame = false
	_cancel_slide()
	_slide_ground_exit_pending = false
	_idle_realigning = false
	_jump_profile = "geen"
	_jump_height = 0.0
	_launch_speed = 0.0
	_jump_boost = 0.0
	_fatigue = 0.0
	_fatigue_recovery_duration = 0.0
	_coyote_remaining = 0.0
	_jump_buffer_remaining = 0.0
	_ground_jump_available = false
	_jumped_last_frame = false
	_step_support_remaining = 0.0
	_refresh_presentation()
	reset_physics_interpolation()
	_camera_pivot.reset_view(true)
	_feedback.reset()
	_procedural_visual.reset_pose()
	_update_debug_arrows()


func set_camera_distance(distance: float) -> void:
	if is_node_ready():
		_camera_pivot.set_distance(distance)


## Elliptische limiet; Vector2.y < 0 is vooruit, gecombineerde input krijgt geen bonus.
func direction_speed_limit(local_direction: Vector2, sprinting: bool) -> float:
	return direction_speed_limit_for_state(local_direction, "sprint" if sprinting else "lopen")


func direction_speed_limit_for_state(local_direction: Vector2, state: String) -> float:
	var direction := local_direction.normalized()
	if direction.is_zero_approx():
		direction = Vector2(0.0, -1.0)
	var profile := _movement_profile(state)
	var forward_speed: float = profile.speed
	var side_speed := maxf(forward_speed * float(profile.side_ratio), 0.01)
	var longitudinal_speed := maxf(forward_speed * (float(profile.back_ratio) if direction.y > 0.0 else 1.0), 0.01)
	return 1.0 / sqrt(pow(direction.x / side_speed, 2.0) + pow(direction.y / longitudinal_speed, 2.0))


func _movement_profile(state: String) -> Dictionary:
	match state:
		"sprint":
			return {"speed": sprint_forward_speed, "side_ratio": sprint_side_ratio, "back_ratio": sprint_back_ratio, "acceleration": sprint_acceleration, "deceleration": sprint_deceleration, "turn": sprint_turn_speed, "step": sprint_step_height}
		"sneak":
			return {"speed": sneak_forward_speed, "side_ratio": sneak_side_ratio, "back_ratio": sneak_back_ratio, "acceleration": sneak_acceleration, "deceleration": sneak_deceleration, "turn": sneak_turn_speed, "step": sneak_step_height}
		"kruipen":
			return {"speed": crouch_forward_speed, "side_ratio": crouch_side_ratio, "back_ratio": crouch_back_ratio, "acceleration": crouch_acceleration, "deceleration": crouch_deceleration, "turn": crouch_turn_speed, "step": crouch_step_height}
		"liggen":
			return {"speed": prone_forward_speed, "side_ratio": prone_side_ratio, "back_ratio": prone_back_ratio, "acceleration": prone_acceleration, "deceleration": prone_deceleration, "turn": prone_turn_speed, "step": prone_step_height}
	return {"speed": walk_forward_speed, "side_ratio": walk_side_ratio, "back_ratio": walk_back_ratio, "acceleration": walk_acceleration, "deceleration": walk_deceleration, "turn": walk_turn_speed, "step": step_height}


func _movement_state() -> String:
	if _posture == Posture.CROUCH:
		return "kruipen"
	if _posture == Posture.PRONE:
		return "liggen"
	if _sneak_requested:
		return "sneak"
	return "sprint" if _sprint_requested else "lopen"


func _posture_name(posture: int) -> String:
	return ["staan", "kruipen", "liggen"][clampi(posture, 0, 2)]


func _posture_dimensions(posture: int) -> Vector2:
	match posture:
		Posture.CROUCH:
			return Vector2(crouch_capsule_radius, maxf(crouch_capsule_height, crouch_capsule_radius * 2.0))
		Posture.PRONE:
			return Vector2(prone_capsule_radius, maxf(prone_capsule_length, prone_capsule_radius * 2.0))
	return Vector2(capsule_radius, maxf(capsule_height, capsule_radius * 2.0))


func _posture_vertical_height(posture: int) -> float:
	var dimensions := _posture_dimensions(posture)
	return dimensions.x * 2.0 if posture == Posture.PRONE else dimensions.y


func get_posture() -> int:
	return _posture


## Vraag een veilige handmatige houding. Liggen bewaart de vorige handmatige houding voor oprichten met spatie.
func request_posture(posture: int) -> void:
	var desired := clampi(posture, Posture.STAND, Posture.PRONE)
	if desired == Posture.PRONE and _manual_posture != Posture.PRONE:
		_prone_return_posture = _manual_posture
	_manual_posture = desired
	_slide_ground_exit_pending = _slide_ground_exit_pending or (_slide_active and get_camera_grounded())
	_cancel_slide()
	_auto_posture_demand = _manual_posture
	_auto_probe_distance = 0.0
	_manual_changed_this_frame = true
	_restore_clear_time = 0.0


func _read_posture_input(intent: AtlasCharacterIntent) -> void:
	if intent.crouch_pressed:
		if _slide_active:
			# C tijdens slide bewaart de slide en kiest alleen de houding erna.
			_manual_posture = Posture.CROUCH
			return
		var interrupted_slide := _slide_pending
		# Beoordeel sprint en vaart vóór C de handmatige houding verandert.
		# Wanddruk, een lage houding en alleen Shift leveren geen slidestart op.
		var ground_slide_requested := (
			get_camera_grounded() and _posture == Posture.STAND and _manual_posture == Posture.STAND
			and _sprint_requested and crouch_slide_duration > 0.0
			and _actual_speed > crouch_slide_end_speed
			and Vector2(velocity.x, velocity.z).length() > crouch_slide_end_speed
		)
		var target := Posture.CROUCH if interrupted_slide else (Posture.STAND if _manual_posture == Posture.CROUCH and _posture != Posture.PRONE else Posture.CROUCH)
		request_posture(target)
		_slide_requested_this_frame = not interrupted_slide and target == Posture.CROUCH and ((not get_camera_grounded() and (_air_kind != "stride" or _sprint_requested)) or ground_slide_requested)
	elif intent.prone_pressed:
		if _posture == Posture.PRONE and _manual_posture == Posture.PRONE:
			_return_from_manual_prone()
		else:
			request_posture(Posture.PRONE)
	elif intent.jump_pressed and _posture > Posture.STAND:
		if _posture == Posture.PRONE and _manual_posture == Posture.PRONE:
			_return_from_manual_prone()
		elif not _slide_active:
			request_posture(_posture - 1)
		_jump_buffer_remaining = 0.0


func _return_from_manual_prone() -> void:
	if _prone_return_posture == Posture.STAND:
		# Een geblokkeerde directe terugkeer blijft liggen; geen onverwachte
		# kruipkeuze of latere sprong wanneer de hoofdruimte weer vrij wordt.
		if _posture_transition_clear(Posture.STAND, posture_clearance_margin):
			request_posture(Posture.STAND)
			_apply_posture(Posture.STAND, true)
	else:
		request_posture(Posture.CROUCH)


func _update_posture(input: Vector2, grounded: bool, delta: float) -> void:
	_posture_changed_this_frame = false
	var target := maxi(_manual_posture, _auto_posture_demand)
	if _slide_pending or _slide_active:
		target = maxi(target, Posture.CROUCH)
	if target > _posture:
		var next := Posture.PRONE if _manual_posture == Posture.PRONE else _posture + 1
		if _posture_transition_clear(next):
			_apply_posture(next)
		_restore_clear_time = 0.0
	elif target < _posture and (grounded or _manual_changed_this_frame):
		var next := _posture - 1
		var clear := _posture_transition_clear(next, posture_clearance_margin)
		if clear and not _manual_changed_this_frame and not input.is_zero_approx():
			var direction := (global_basis * Vector3(input.x, 0.0, input.y)).normalized()
			var probe_distance := maxf(_auto_probe_distance, _posture_probe_distance(_posture, direction, delta))
			clear = _higher_path_clear(next, direction * probe_distance, posture_clearance_margin)
		if clear:
			_restore_clear_time += delta
			if _manual_changed_this_frame or _restore_clear_time + 0.00001 >= posture_restore_time:
				_apply_posture(next)
		else:
			_restore_clear_time = 0.0
	else:
		_restore_clear_time = 0.0
	if _posture == _manual_posture and _auto_posture_demand == _manual_posture:
		_auto_probe_distance = 0.0
	if _slide_ground_exit_pending:
		if get_camera_grounded():
			_limit_ground_velocity()
		_slide_ground_exit_pending = false
	# Alleen de nieuwe C-druk mag een veilige kruipvorm in een slide omzetten;
	# een later passende vorm of later opgebouwde sprintvaart doet dat niet.
	if _slide_requested_this_frame and _posture == Posture.CROUCH and _manual_posture == Posture.CROUCH and _shape_fits(Posture.CROUCH, global_transform):
		if grounded:
			# Dezelfde slide als na een landing, met uitsluitend de actuele vaart.
			# De gewone slide-update past deze tick meteen wrijving toe.
			_slide_active = true
			_slide_time_left = crouch_slide_duration
			_air_speed_cap = Vector2(velocity.x, velocity.z).length()
			_air_min_control_active = false
			# Gelijktijdig C/spatie kiest deze slide, zonder latere buffersprong.
			_jump_buffer_remaining = 0.0
		else:
			_slide_pending = crouch_slide_duration > 0.0
		if _slide_pending or _slide_active:
			# Een slide kiest een tijdelijke beweging, geen blijvende kruipvoorkeur.
			_manual_posture = Posture.STAND
			_auto_posture_demand = Posture.STAND
			_auto_probe_distance = 0.0
	_manual_changed_this_frame = false
	_slide_requested_this_frame = false


func _apply_posture(posture: int, manual_prone_return: bool = false) -> void:
	var direct_return := manual_prone_return and _posture == Posture.PRONE and posture == Posture.STAND and _manual_posture == Posture.STAND and _prone_return_posture == Posture.STAND
	assert(absi(posture - _posture) == 1 or (posture == Posture.PRONE and _manual_posture == Posture.PRONE) or direct_return)
	if posture != Posture.CROUCH:
		_slide_ground_exit_pending = _slide_ground_exit_pending or (_slide_active and get_camera_grounded())
		_cancel_slide()
	_posture = posture
	posture_changed.emit(_posture_name(posture))
	_posture_changed_this_frame = true
	_restore_clear_time = 0.0
	_refresh_presentation()


func _posture_transition_clear(next: int, margin: float = 0.0) -> bool:
	if not _shape_fits(next, global_transform, margin):
		return false
	# Bij andere radii is de tussenliggende vorm niet altijd geheel in de eindvorm.
	# Controleer daarom ook enkele mengvormen; de grondanker blijft onveranderd.
	var current := _posture_dimensions(_posture)
	var destination := _posture_dimensions(next)
	for index in range(1, 5):
		var weight := float(index) / 5.0
		var radius := lerpf(current.x, destination.x, weight)
		var length := maxf(lerpf(current.y, destination.y, weight), radius * 2.0)
		var angle := lerpf(PI * 0.5 if _posture == Posture.PRONE else 0.0, PI * 0.5 if next == Posture.PRONE else 0.0, weight)
		# Een capsule is presentatie, geen star lichaam dat eerst omhoog kantelt.
		# Verkort de tussenas zodat lager worden nergens hoger wordt dan de
		# menghoogte. Dit voorkomt een kunstmatige plafondblokkade tijdens kruip->lig.
		var allowed_height := lerpf(_posture_vertical_height(_posture), _posture_vertical_height(next), weight)
		if absf(cos(angle)) > 0.0001:
			length = minf(length, radius * 2.0 + maxf(allowed_height - radius * 2.0, 0.0) / absf(cos(angle)))
		var vertical := radius * 2.0 + (length - radius * 2.0) * absf(cos(angle))
		var shape := CapsuleShape3D.new()
		shape.radius = radius
		shape.height = length
		var transform := global_transform
		transform.basis = global_basis.orthonormalized() * Basis(Vector3.RIGHT, angle)
		transform.origin.y += vertical * 0.5 + 0.003
		if not _query_shape_clear(shape, transform):
			return false
	return true


func _shape_query(posture: int, feet: Transform3D, margin: float = 0.0) -> PhysicsShapeQueryParameters3D:
	var dimensions := _posture_dimensions(posture)
	var shape := CapsuleShape3D.new()
	shape.radius = dimensions.x + (margin * 0.5 if posture == Posture.PRONE else 0.0)
	shape.height = dimensions.y + margin
	var transform := feet
	transform.basis = feet.basis.orthonormalized()
	if posture == Posture.PRONE:
		transform.basis *= Basis(Vector3.RIGHT, PI * 0.5)
	transform.origin.y += (_posture_vertical_height(posture) + margin) * 0.5 + 0.003
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = transform
	query.margin = 0.0
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	return query


func _query_shape_clear(shape: Shape3D, transform: Transform3D) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = transform
	query.margin = 0.0
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _shape_fits(posture: int, feet: Transform3D, margin: float = 0.0) -> bool:
	return get_world_3d().direct_space_state.intersect_shape(_shape_query(posture, feet, margin), 1).is_empty()


func _shape_sweep_clear(posture: int, feet: Transform3D, motion: Vector3, margin: float = 0.0) -> bool:
	var space := get_world_3d().direct_space_state
	var query := _shape_query(posture, feet, margin)
	if not space.intersect_shape(query, 1).is_empty():
		return false
	query.motion = motion
	var fraction := space.cast_motion(query)
	if fraction[0] < 0.9999:
		return false
	var destination := feet
	destination.origin += motion
	return _shape_fits(posture, destination, margin)


func _shape_collision_normal(posture: int, feet: Transform3D, motion: Vector3) -> Vector3:
	if motion.is_zero_approx():
		return Vector3.ZERO
	var space := get_world_3d().direct_space_state
	var query := _shape_query(posture, feet)
	query.motion = motion
	var fraction := space.cast_motion(query)
	if fraction[0] >= 0.9999:
		return Vector3.ZERO
	# cast_motion geeft fracties, geen normaal. Toets hetzelfde volume op het
	# eerste contact; get_rest_info leest alleen deze echte contactpositie.
	query.transform.origin += motion * minf(1.0, float(fraction[1]) + 0.002 / motion.length())
	query.motion = Vector3.ZERO
	query.margin = 0.001
	var contact := space.get_rest_info(query)
	return Vector3.ZERO if contact.is_empty() else Vector3(contact.normal)


func _turn_body(grounded: bool, delta: float, input: Vector2 = Vector2.ZERO) -> void:
	_body_turn_blocked = false
	var state := _movement_state()
	_turn_rate = float(_movement_profile(state).turn)
	if _posture == Posture.STAND:
		if not grounded:
			_turn_rate = air_turn_speed
		elif _sneak_requested:
			_turn_rate = sneak_turn_speed
		elif _actual_speed < 0.10 and input.is_zero_approx():
			_turn_rate = idle_turn_speed
		else:
			_turn_rate = lerpf(walk_turn_speed, sprint_turn_speed, _sprint_mix(Vector3(velocity.x, 0.0, velocity.z)))
	var current := global_rotation.y
	var target := _look_input.x
	var difference := wrapf(target - current, -PI, PI)
	if input.is_zero_approx() and _actual_speed < 0.10:
		var start_angle := minf(idle_body_turn_start_angle, head_max_yaw)
		var stop_angle := minf(idle_body_turn_stop_angle, start_angle)
		if not _idle_realigning and absf(difference) >= deg_to_rad(start_angle):
			_idle_realigning = true
		if _idle_realigning and absf(difference) <= deg_to_rad(stop_angle) + 0.0001:
			_idle_realigning = false
		if not _idle_realigning:
			_turn_rate = 0.0
			return
		difference -= signf(difference) * deg_to_rad(stop_angle)
	else:
		_idle_realigning = false
	var turn := clampf(difference, -deg_to_rad(_turn_rate) * delta, deg_to_rad(_turn_rate) * delta)
	if _posture != Posture.PRONE:
		global_rotation.y = current + turn
		return
	# Volledige capsule langs de draai toetsen, niet alleen de vrije eindhoek.
	var increments := maxi(1, ceili(absf(turn) / deg_to_rad(1.0)))
	var dimensions := _posture_dimensions(Posture.PRONE)
	var half_axis := maxf(dimensions.y * 0.5 - dimensions.x, 0.0)
	for index in range(1, increments + 1):
		var next := current + turn * float(index) / float(increments)
		var midpoint := next - turn / float(increments) * 0.5
		var guard := half_axis * sin(absf(turn / float(increments)) * 0.5)
		var query_shape := CapsuleShape3D.new()
		query_shape.radius = dimensions.x + guard
		query_shape.height = dimensions.y + guard * 2.0
		var guarded := Transform3D(Basis(Vector3.UP, midpoint) * Basis(Vector3.RIGHT, PI * 0.5), global_position + Vector3.UP * (dimensions.x + guard + 0.003))
		var end_transform := Transform3D(Basis(Vector3.UP, next), global_position)
		if not _query_shape_clear(query_shape, guarded) or not _shape_fits(Posture.PRONE, end_transform):
			_body_turn_blocked = true
			break
		global_rotation.y = next


func _sprint_mix(horizontal: Vector3) -> float:
	var local := global_basis.inverse() * horizontal
	var direction := Vector2(local.x, local.z)
	var walk_limit := direction_speed_limit(direction, false)
	var sprint_limit := direction_speed_limit(direction, true)
	if sprint_limit <= walk_limit:
		return 0.0
	return clampf((horizontal.length() - walk_limit) / (sprint_limit - walk_limit), 0.0, 1.0)


## Werkelijke snelheid kiest het profiel; Shift alleen verandert deze berekening niet.
func jump_parameters(horizontal_velocity: Vector3) -> Dictionary:
	var horizontal := Vector3(horizontal_velocity.x, 0.0, horizontal_velocity.z)
	var speed := horizontal.length()
	var local := global_basis.inverse() * horizontal
	var direction := Vector2(local.x, local.z)
	var walk_limit := direction_speed_limit(direction, false)
	var walk_weight := clampf(speed / maxf(walk_limit, 0.01), 0.0, 1.0)
	var sprint_weight := _sprint_mix(horizontal)
	var height := lerpf(lerpf(standing_jump_height, walking_jump_height, walk_weight), sprint_jump_height, sprint_weight)
	var cost := lerpf(lerpf(standing_jump_fatigue_cost, walking_jump_fatigue_cost, walk_weight), sprint_jump_fatigue_cost, sprint_weight)
	var recovery := lerpf(lerpf(standing_jump_recovery_time, walking_jump_recovery_time, walk_weight), sprint_jump_recovery_time, sprint_weight)
	var floor_factor := lerpf(lerpf(standing_jump_min_height_factor, walking_jump_min_height_factor, walk_weight), sprint_jump_min_height_factor, sprint_weight)
	var profile := "stilstand"
	if sprint_weight > 0.01:
		profile = "sprint"
	elif walk_weight > 0.01:
		profile = "lopen"
	if _sneak_requested:
		profile = "sneak"
		height = sneak_jump_height
		cost = sneak_jump_fatigue_cost
		recovery = sneak_jump_recovery_time
		floor_factor = sneak_jump_min_height_factor
		sprint_weight = 0.0
	var fatigue := _fatigue if jump_fatigue_enabled else 0.0
	height *= lerpf(1.0, floor_factor, fatigue)
	if profile == "sneak":
		height = minf(sneak_jump_height, maxf(height, sneak_min_jump_height))
	var boost := sprint_jump_boost * sprint_weight * lerpf(1.0, sprint_jump_min_boost_factor, fatigue)
	return {"profile": profile, "height": height, "vertical_speed": sqrt(2.0 * gravity_strength * height), "horizontal_boost": boost, "launch_speed": speed + boost, "walk_weight": walk_weight, "sprint_weight": sprint_weight, "fatigue_cost": cost, "recovery_time": recovery}


## AI en proefbesturing leveren dezelfde intent als de toetsenbordadapter.
## Vastgehouden beweging blijft gelden; afzonderlijke actie-edges worden eenmaal verbruikt.
func submit_intent(intent: AtlasCharacterIntent) -> void:
	if intent == null:
		use_player_input()
		return
	var next := intent.copy()
	if _external_intent != null:
		next.jump_pressed = next.jump_pressed or _external_intent.jump_pressed
		next.crouch_pressed = next.crouch_pressed or _external_intent.crouch_pressed
		next.prone_pressed = next.prone_pressed or _external_intent.prone_pressed
	_external_intent = next
	if is_node_ready():
		_camera_pivot.player_look_enabled = false


func use_player_input() -> void:
	_external_intent = null
	if is_node_ready():
		_camera_pivot.player_look_enabled = true


func set_procedural_leg_length(value: float) -> void:
	if is_finite(value):
		_procedural_leg_length = maxf(value, 0.05)


## Wereldimpuls in kg*m/s; massa verandert uitsluitend de ontvangen snelheidsverandering.
## De eerstvolgende physicstick verwerkt samengevoegde impulsen één keer.
func apply_impulse(world_impulse: Vector3) -> void:
	if world_impulse.is_finite():
		_queued_impulse += world_impulse


func _consume_intent() -> AtlasCharacterIntent:
	var intent: AtlasCharacterIntent
	if _external_intent != null:
		intent = _external_intent.copy()
		_external_intent.clear_edges()
	else:
		intent = AtlasCharacterIntent.new()
		var allowed := _controlled and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or DisplayServer.get_name() == "headless")
		if allowed:
			intent.movement = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
			intent.sprint = Input.is_action_pressed("sprint")
			intent.sneak = InputMap.has_action("sneak") and Input.is_action_pressed("sneak")
			intent.jump_pressed = Input.is_action_just_pressed("jump")
			intent.crouch_pressed = InputMap.has_action("crouch") and Input.is_action_just_pressed("crouch")
			intent.prone_pressed = InputMap.has_action("prone") and Input.is_action_just_pressed("prone")
	if intent.has_look_direction:
		_camera_pivot.set_look_direction(intent.look_direction)
	return intent


func _consume_impulse() -> bool:
	if _queued_impulse.is_zero_approx():
		return false
	var change := _queued_impulse / maxf(body_profile.mass_kg, 0.01)
	_queued_impulse = Vector3.ZERO
	var before := Vector2(velocity.x, velocity.z).length()
	velocity += change
	var after := Vector2(velocity.x, velocity.z).length()
	_external_speed_allowance = maxf(0.0, _external_speed_allowance + after - before)
	_air_speed_cap = maxf(_air_speed_cap, after)
	_air_min_control_active = false
	if _air_kind == "stride":
		_lose_stride_privilege()
	if change.y > 0.0:
		_air_kind = "fall"
		_step_support_remaining = 0.0
		_ground_jump_available = false
		_coyote_remaining = 0.0
		return true
	return false


func _lose_stride_privilege() -> void:
	_air_kind = "fall"
	_stride_jump_available = false
	_ground_jump_available = false
	_coyote_remaining = 0.0
	_stride.cancel()


func _stride_has_local_support(before_takeoff: bool = false) -> bool:
	_stride_probe_count += 1
	var depth := 0.08 if before_takeoff else clampf(_stride.height * 2.0 + 0.08, 0.08, 0.5)
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.025, global_position - Vector3.UP * depth, collision_mask, [get_rid()])
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or Vector3(hit.normal).dot(Vector3.UP) < cos(floor_max_angle):
		return false
	# Een verre vloer onder een rand geeft geen oneindig pas-sprongticket.
	return before_takeoff or Vector3(hit.position).y >= _stride.takeoff_y - 0.08


func _try_start_stride(delta: float, supported: bool) -> bool:
	if not procedural_enabled:
		return false
	if _air_kind == "stride":
		return false
	if not supported or _posture != Posture.STAND or _slide_active or _slide_pending:
		_stride.cancel()
		return false
	var speed := Vector2(velocity.x, velocity.z).length()
	var moving := speed > 0.10 and _actual_speed > 0.10
	var duration := body_profile.get_support_duration(speed, _procedural_leg_length, _sneak_requested)
	if not _stride.support_tick(delta, duration, moving):
		return false
	var height := body_profile.get_flight_height(speed / maxf(body_profile.reference_speed, 0.1), _procedural_leg_length, _sneak_requested)
	if height <= 0.000001:
		_ground_step_requested = true
		return false
	if not _stride_has_local_support(true):
		_stride.cancel()
		return false
	# Ook een heel kleine ingestelde pas krijgt bij 60 Hz een echte luchtframe.
	height = maxf(height, 0.5 * gravity_strength * delta * delta)
	if not _shape_sweep_clear(Posture.STAND, global_transform, Vector3.UP * (height + 0.003)):
		_ground_step_requested = true
		return false
	# Gebruik de gemiddelde verticale snelheid van de eerste integratiestap.
	# Zo meet de curve echte hoogte in plaats van een extra Euler-afzetframe.
	velocity.y = _stride.take_off(global_position.y, height, gravity_strength) - 0.5 * gravity_strength * delta
	_air_kind = "stride"
	_stride_jump_available = true
	_ground_jump_available = false
	_coyote_remaining = 0.0
	_step_support_remaining = 0.0
	_air_speed_cap = maxf(speed, air_min_control_speed)
	_air_min_control_active = speed < air_min_control_speed
	return true

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_stride_probe_count = 0
	_ground_step_requested = false
	var intent := _consume_intent()
	var input := intent.movement
	_sneak_requested = intent.sneak
	_sprint_requested = intent.sprint and not _sneak_requested
	var external_lift := _consume_impulse()
	if _air_kind == "stride":
		if not procedural_enabled or is_on_ceiling() or not _stride_has_local_support():
			_lose_stride_privilege()
	var real_grounded := is_on_floor() and not _jumped_last_frame and not external_lift
	var was_grounded := real_grounded or (_step_support_remaining > 0.0 and not _jumped_last_frame and not external_lift)
	var slide_jump_requested := _slide_active and intent.jump_pressed
	_update_jump_timing(intent.jump_pressed, was_grounded, real_grounded, delta)
	_read_posture_input(intent)
	var stride_control := _air_kind == "stride" and _stride_jump_available and _posture == Posture.STAND
	_turn_body(was_grounded or stride_control, delta, input)
	var input_basis := global_basis
	if not was_grounded and not stride_control:
		input_basis = Basis(Vector3.UP, _look_input.x)
	_input_direction = input_basis * Vector3(input.x, 0.0, input.y)
	if was_grounded:
		_update_auto_posture_demand(input, delta)
	else:
		_auto_posture_demand = _manual_posture
	_update_posture(input, was_grounded, delta)
	if _posture != Posture.STAND:
		_stride_jump_available = false
		stride_control = false
	var jumped := slide_jump_requested and _try_slide_jump(delta)
	if not jumped:
		_update_horizontal_velocity(input, was_grounded, delta, stride_control)
		var jump_support := (_ground_jump_available and (was_grounded or _coyote_remaining > 0.0)) or (_air_kind == "stride" and _stride_jump_available)
		if _posture == Posture.STAND and _jump_buffer_remaining > 0.0 and jump_support:
			_start_jump()
			jumped = true
		elif was_grounded:
			velocity.y = -0.1
		else:
			velocity.y -= gravity_strength * delta
	var stride_started := not jumped and not external_lift and _try_start_stride(delta, was_grounded)
	var before := global_position
	_last_step_height = 0.0
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	# Een geldige pasvlucht behoudt dezelfde veilige opstapmogelijkheid.
	# Zonder dit pad wist de wandcollision eerst alle horizontale pasvaart.
	var stride_step := _air_kind == "stride" and _stride_jump_available and _posture == Posture.STAND
	var maximum_step_floor := _stride.takeoff_y + _step_limit_for_posture(_posture) + 0.003 if stride_step else INF
	var stepped := (was_grounded or stride_step) and not jumped and _try_step_up(horizontal * delta, maximum_step_floor, velocity * delta if stride_step else horizontal * delta)
	if stepped:
		if stride_step:
			stride_started = false
			_stride.cancel()
			_stride_jump_available = false
			_air_kind = "none"
			_ground_step_requested = true
			velocity.y = -0.1
		velocity.x = 0.0
		velocity.z = 0.0
	var incoming_velocity := velocity
	var snap := floor_snap_length
	if _air_kind == "stride":
		# De kleine pasvlucht eindigt door echt vloercontact, niet door afstandsnap.
		floor_snap_length = 0.0
	move_and_slide()
	floor_snap_length = snap
	if stepped:
		velocity.x = horizontal.x
		velocity.z = horizontal.z
	var travel := global_position - before
	var real_horizontal := Vector3(travel.x, 0.0, travel.z) / delta
	_actual_speed = real_horizontal.length()
	_movement_direction = real_horizontal.normalized()
	_external_speed_allowance = minf(_external_speed_allowance, Vector2(velocity.x, velocity.z).length())
	var stride_landed := false
	if _air_kind == "stride":
		_stride.flight_tick(delta)
		if is_on_ceiling():
			_lose_stride_privilege()
		elif is_on_floor():
			if stride_started:
				# Een helling kan de opwaartse stap direct weer opvangen.
				# Dan was er geen echte vlucht en publiceren we die ook niet.
				stride_started = false
				_ground_step_requested = true
			else:
				stride_landed = true
				_stride.touch_down()
			_stride_jump_available = false
			_air_kind = "none"
	elif get_camera_grounded() and not jumped and not external_lift:
		_air_kind = "none"
	elif _air_kind == "none":
		_air_kind = "fall"
	var ground_step := _ground_step_requested and get_camera_grounded() and _actual_speed > 0.10
	if ground_step:
		_stride.supported_step()
	elif _ground_step_requested:
		_stride.cancel()
	if _slide_active and (not get_camera_grounded() or _actual_speed < 0.02):
		_finish_slide()
	if _slide_pending and not was_grounded and is_on_floor():
		_slide_pending = false
		if _posture == Posture.CROUCH:
			var landing_velocity := Vector3(velocity.x, 0.0, velocity.z).limit_length(_air_speed_cap)
			velocity.x = landing_velocity.x
			velocity.z = landing_velocity.z
			_slide_active = landing_velocity.length() > crouch_slide_end_speed and crouch_slide_duration > 0.0
			_slide_time_left = crouch_slide_duration if _slide_active else 0.0
	if not was_grounded and is_on_floor() and _posture != Posture.STAND and not _slide_active:
		# Een lage landing zonder C-slide geeft geen verborgen lange glijfase.
		# Pas het grondbudget pas bij contact toe, nooit op de afzetvaart in vlucht.
		_limit_ground_velocity()
	var contact := AtlasCharacterContactFrame.new()
	contact.delta = delta
	contact.horizontal_travel = Vector3(travel.x, 0.0, travel.z)
	contact.horizontal_speed = _actual_speed
	contact.incoming_velocity = incoming_velocity
	contact.supported = get_camera_grounded() and not jumped and not stride_started and not external_lift
	contact.real_grounded = is_on_floor() and not jumped and not stride_started and not external_lift
	contact.motion_profile = _movement_state()
	contact.posture = _posture_name(_posture)
	contact.sliding = _slide_active
	contact.jumped = jumped
	contact.landed = not was_grounded and is_on_floor() and not jumped and not stepped and not stride_landed
	contact.world_position = global_position
	contact.procedural_enabled = procedural_enabled
	contact.air_kind = _air_kind
	contact.stride_started = stride_started
	contact.stride_landed = stride_landed
	contact.ground_step = ground_step
	contact.step_index = _stride.step_index
	contact.gait_phase = _stride.phase
	contact.body_velocity = velocity
	contact.body_transform = global_transform
	# Eén pose-eigenaar kan hier voetcontacten toevoegen voordat audio ze leest.
	procedural_frame_ready.emit(contact)
	contact_frame_ready.emit(contact)
	_jumped_last_frame = jumped or stride_started or external_lift
	_update_debug_arrows()
	if global_position.y < -20.0:
		reset_to_spawn()

func _update_jump_timing(jump_pressed: bool, grounded: bool, real_grounded: bool, delta: float) -> void:
	_jump_buffer_remaining = maxf(_jump_buffer_remaining - delta, 0.0)
	if grounded:
		_ground_jump_available = true
		_coyote_remaining = coyote_time
	else:
		_coyote_remaining = maxf(_coyote_remaining - delta, 0.0)
		if _coyote_remaining <= 0.0:
			_ground_jump_available = false
	if jump_pressed:
		_jump_buffer_remaining = maxf(jump_buffer_time, delta) if _posture == Posture.STAND else 0.0
	if real_grounded and _fatigue > 0.0:
		_fatigue = maxf(_fatigue - delta / maxf(_fatigue_recovery_duration, 0.01), 0.0)
		if _fatigue <= 0.00001:
			_fatigue = 0.0
			_fatigue_recovery_duration = 0.0


func _update_horizontal_velocity(input: Vector2, grounded: bool, delta: float, stride_control: bool = false) -> void:
	_air_braking = false
	if grounded and _slide_active:
		_update_slide(input, delta)
		return
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var state := _movement_state()
	var profile := _movement_profile(state)
	var target := Vector3.ZERO
	if not input.is_zero_approx():
		target = _input_direction.normalized() * direction_speed_limit_for_state(input, state) * minf(input.length(), 1.0)
	if grounded or stride_control:
		var brake_profile := profile

		if input.is_zero_approx() and _posture == Posture.STAND and not _sneak_requested:
			brake_profile = _movement_profile(_last_ground_state)
		elif not input.is_zero_approx():
			_last_ground_state = state
		var opposing := horizontal.dot(target) < -0.001
		var slowing := target.length_squared() < horizontal.length_squared() or opposing
		var rate: float = brake_profile.deceleration if slowing else profile.acceleration
		if opposing:
			rate *= countersteer_brake_factor
		horizontal = horizontal.move_toward(target, rate * delta)
		_air_speed_cap = maxf(horizontal.length(), air_min_control_speed)
		_air_min_control_active = horizontal.length() < air_min_control_speed
		var local_ground := global_basis.inverse() * horizontal
		var ground_direction := Vector2(local_ground.x, local_ground.z)
		var sprint_limit := direction_speed_limit(ground_direction, true)
		_external_speed_allowance = minf(_external_speed_allowance, maxf(horizontal.length() - sprint_limit, 0.0))
		if grounded:
			ground_motion_updated.emit(horizontal, direction_speed_limit(ground_direction, false), sprint_limit, _posture != Posture.STAND or _sneak_requested)
	else:
		if not input.is_zero_approx():
			var acceleration := air_acceleration
			if _posture == Posture.CROUCH:
				acceleration = crouch_air_acceleration
			elif _posture == Posture.PRONE:
				acceleration = prone_air_acceleration
			if horizontal.is_zero_approx() and not _air_min_control_active:
				# Na een frontale wandstop blijft lichte zijsturing mogelijk;
				# het verloren sprintmomentum mag daarbij niet terugkomen.
				_air_speed_cap = minf(_air_speed_cap, air_min_control_speed)
				_air_min_control_active = true
			var desired := _input_direction.normalized()
			var opposition := _input_opposition(horizontal, desired)
			if opposition > 0.01 and air_brake_acceleration > 0.0:
				_air_braking = true
				var heading := horizontal.normalized()
				var speed := maxf(horizontal.length() - air_brake_acceleration * opposition * minf(input.length(), 1.0) * delta, 0.0)
				horizontal = heading * speed
				# Afgebouwde vaart kan niet via W opnieuw naar de oude bonus groeien.
				_air_speed_cap = minf(_air_speed_cap, maxf(speed, air_min_control_speed))
				var lateral := desired.slide(heading)
				if not lateral.is_zero_approx() and speed > 0.0:
					horizontal = _steer_horizontal(horizontal, lateral, acceleration / speed * delta)
			elif _air_min_control_active:
				target = desired * _air_speed_cap * minf(input.length(), 1.0)
				horizontal = horizontal.move_toward(target, acceleration * delta)
			elif not horizontal.is_zero_approx():
				# Richting veranderen zonder het afzetbudget naar een sprintdoel op te trekken.
				horizontal = _steer_horizontal(horizontal, desired, acceleration / horizontal.length() * delta)
		horizontal = horizontal.limit_length(_air_speed_cap)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func _input_opposition(horizontal: Vector3, desired: Vector3) -> float:
	return 0.0 if horizontal.is_zero_approx() else maxf(-horizontal.normalized().dot(desired.normalized()), 0.0)


func _steer_horizontal(horizontal: Vector3, desired: Vector3, maximum_angle: float) -> Vector3:
	if horizontal.is_zero_approx() or desired.is_zero_approx():
		return horizontal
	var heading := atan2(-horizontal.x, -horizontal.z)
	var target := atan2(-desired.x, -desired.z)
	var turn := clampf(wrapf(target - heading, -PI, PI), -maximum_angle, maximum_angle)
	return -Basis(Vector3.UP, heading + turn).z * horizontal.length()


func _update_slide(input: Vector2, delta: float) -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var heading := horizontal.normalized()
	var desired := _input_direction.normalized()
	var opposition := _input_opposition(horizontal, desired) * minf(input.length(), 1.0)
	var deceleration := crouch_slide_deceleration + air_brake_acceleration * opposition
	horizontal = heading * maxf(horizontal.length() - deceleration * delta, 0.0)
	if not input.is_zero_approx():
		if opposition > 0.01:
			desired = desired.slide(heading)
		horizontal = _steer_horizontal(horizontal, desired, deg_to_rad(crouch_slide_steering) * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	_air_speed_cap = minf(_air_speed_cap, horizontal.length())
	_slide_time_left = maxf(_slide_time_left - delta, 0.0)
	if _slide_time_left <= 0.00001 or horizontal.length() <= crouch_slide_end_speed:
		_finish_slide()
		_limit_ground_velocity()


func _limit_ground_velocity() -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var local := global_basis.inverse() * horizontal
	var limit := direction_speed_limit_for_state(Vector2(local.x, local.z), _movement_state()) + _external_speed_allowance
	horizontal = horizontal.limit_length(limit)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	_air_speed_cap = minf(_air_speed_cap, horizontal.length())


func _cancel_slide() -> void:
	_slide_pending = false
	_slide_active = false
	_slide_time_left = 0.0


func _finish_slide() -> void:
	_cancel_slide()
	_auto_posture_demand = _manual_posture
	_auto_probe_distance = 0.0
	_restore_clear_time = 0.0
	_slide_ground_exit_pending = _slide_ground_exit_pending or get_camera_grounded()
	# Volgend physicsframe oprichten zodra volume en route veilig zijn. In de
	# lucht blijft de automatische oprichting wachten op nieuwe grondsteun.
	_manual_changed_this_frame = get_camera_grounded()


func _try_slide_jump(delta: float) -> bool:
	# Een nieuwe druk krijgt één poging; een geblokkeerde poging blijft geen
	# verborgen sprongbuffer en onderbreekt de bestaande slide niet.
	if not _slide_active or _posture != Posture.CROUCH or not get_camera_grounded() or not _ground_jump_available:
		return false
	if not _posture_transition_clear(Posture.STAND, posture_clearance_margin):
		return false
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if not _higher_path_clear(Posture.STAND, horizontal * delta, posture_clearance_margin):
		return false
	_apply_posture(Posture.STAND)
	_auto_posture_demand = Posture.STAND
	_auto_probe_distance = 0.0
	_start_jump(true)
	return true


func _start_jump(preserve_slide_momentum: bool = false) -> void:
	_stride.cancel()
	_stride_jump_available = false
	_air_kind = "jump"
	_cancel_slide()
	_slide_ground_exit_pending = false
	_step_support_remaining = 0.0
	_jump_buffer_remaining = 0.0
	_coyote_remaining = 0.0
	_ground_jump_available = false
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var local := global_basis.inverse() * horizontal
	var direction := Vector2(local.x, local.z)
	# Gewone grondafzet verwijdert de oude bonus vóór het profiel. Vanuit slide
	# blijft alleen de echte resterende vaart behouden, zonder een nieuwe bonus.
	var ground_limit := direction_speed_limit_for_state(direction, "sneak" if _sneak_requested else "sprint")
	horizontal = horizontal.limit_length(_air_speed_cap if preserve_slide_momentum else ground_limit + _external_speed_allowance)
	var parameters := jump_parameters(horizontal)
	_jump_profile = parameters.profile
	_jump_height = parameters.height
	_jump_boost = 0.0 if preserve_slide_momentum else float(parameters.horizontal_boost)
	_launch_speed = horizontal.length() + _jump_boost
	# Geaccepteerde afzet vóór horizontale bonus: presentatie bepaalt eigen FOV.
	jump_accepted.emit(horizontal, direction_speed_limit(direction, false), direction_speed_limit(direction, true), _sneak_requested)
	if not horizontal.is_zero_approx():
		horizontal += horizontal.normalized() * _jump_boost
	velocity = horizontal + Vector3.UP * float(parameters.vertical_speed)
	_air_speed_cap = maxf(horizontal.length(), air_min_control_speed)
	_air_min_control_active = horizontal.length() < air_min_control_speed
	if jump_fatigue_enabled:
		_fatigue = minf(_fatigue + float(parameters.fatigue_cost), 1.0)
		_fatigue_recovery_duration = maxf(_fatigue_recovery_duration, float(parameters.recovery_time))


func _step_limit_for_posture(posture: int) -> float:
	if posture == Posture.CROUCH:
		return crouch_step_height
	if posture == Posture.PRONE:
		return prone_step_height
	return float(_movement_profile("sneak" if _sneak_requested else ("sprint" if _sprint_requested else "lopen")).step)


func _step_plan(horizontal_motion: Vector3, posture: int, minimum_probe_distance: float = 0.0, margin: float = 0.0) -> Dictionary:
	var limit := _step_limit_for_posture(posture)
	if limit <= 0.0 or horizontal_motion.is_zero_approx():
		return {}
	var direction := horizontal_motion.normalized()
	var dimensions := _posture_dimensions(posture)
	var local := global_basis.inverse() * direction
	var extent := dimensions.x
	if posture == Posture.PRONE:
		extent += maxf(dimensions.y * 0.5 - dimensions.x, 0.0) * absf(local.z)
	# De fysieke aanrijframe kan de capsulerand al tegen een trede brengen
	# voordat de voeten dichtbij staan. Een expliciete lookahead bevat dit al.
	var frame_reach := horizontal_motion.length() if minimum_probe_distance <= 0.0 else 0.0
	var probe_distance := maxf(maxf(horizontal_motion.length(), extent + frame_reach + 0.04), minimum_probe_distance)
	var contact_normal := _shape_collision_normal(posture, global_transform, direction * maxf(probe_distance, 1.5))
	var flat_normal := Vector3(contact_normal.x, 0.0, contact_normal.z).normalized()
	if not flat_normal.is_zero_approx():
		var plane_extent := dimensions.x
		if posture == Posture.PRONE:
			plane_extent += maxf(dimensions.y * 0.5 - dimensions.x, 0.0) * absf((-global_basis.z).dot(flat_normal))
		# Een schuine aanloop moet verder langs zijn richting om dezelfde
		# trederand te bereiken; radius+.04 alleen mist de bovenkant bij 30/45°.
		probe_distance = maxf(probe_distance, minf((plane_extent + 0.04) / maxf(absf(direction.dot(flat_normal)), 0.15) + frame_reach, 2.0))
	var probe_motion := direction * probe_distance
	var ray_from := global_position + probe_motion + Vector3.UP * (limit + 0.03)
	var ray_to := global_position + probe_motion - Vector3.UP * 0.03
	var side := Vector3(-direction.z, 0.0, direction.x) * dimensions.x * 0.6
	# Aan een buitenhoek raakt de middenray nog de gewone vloer terwijl de
	# capsulerand al op de trede kan rusten. Toets iedere steun afzonderlijk.
	for offset in [Vector3.ZERO, side, -side]:
		var ray := PhysicsRayQueryParameters3D.create(ray_from + offset, ray_to + offset, collision_mask, [get_rid()])
		ray.hit_from_inside = true
		var landing := get_world_3d().direct_space_state.intersect_ray(ray)
		if landing.is_empty() or Vector3(landing.normal).dot(Vector3.UP) < cos(floor_max_angle):
			continue
		var rise := Vector3(landing.position).y - global_position.y
		if rise <= 0.005 or rise > limit + 0.005:
			continue
		var lift := Vector3.UP * (rise + 0.003)
		if not _shape_sweep_clear(posture, global_transform, lift, margin):
			continue
		var raised := global_transform
		raised.origin += lift
		if not _shape_sweep_clear(posture, raised, probe_motion, margin):
			continue
		var actual_destination := global_position + horizontal_motion
		actual_destination.y = Vector3(landing.position).y + 0.001
		var actual := global_transform
		actual.origin.y = actual_destination.y
		if not _shape_sweep_clear(posture, actual, horizontal_motion, margin):
			continue
		return {"destination": actual_destination, "support": Vector3(landing.position) + Vector3.UP * 0.001, "direction": direction, "remaining": maxf(probe_distance - horizontal_motion.length(), 0.0), "rise": rise}
	return {}


func _try_step_up(horizontal_motion: Vector3, maximum_floor_y: float = INF, collision_motion: Vector3 = Vector3.ZERO) -> bool:
	if _step_limit_for_posture(_posture) <= 0.0 or horizontal_motion.is_zero_approx():
		_step_support_remaining = 0.0
		return false
	if _step_support_remaining > 0.0:
		return _continue_step(horizontal_motion)
	var collision := KinematicCollision3D.new()
	# Dalende pasvlucht kan de afgeronde trederand raken terwijl de horizontale
	# straal er nog net bovenlangs gaat. Toets daarom haar echte framebeweging.
	var blocked := test_move(global_transform, horizontal_motion, collision) and collision.get_normal().dot(Vector3.UP) < cos(floor_max_angle)
	if not blocked and not collision_motion.is_zero_approx() and not collision_motion.is_equal_approx(horizontal_motion):
		var diagonal_hit := test_move(global_transform, collision_motion, collision)
		blocked = diagonal_hit and collision.get_normal().dot(Vector3.UP) < cos(floor_max_angle)
		if diagonal_hit and not blocked and collision_motion.y < 0.0:
			# Dezelfde tick kan eerst landen en daarna de trede raken. Toets één
			# overblijvende horizontale sweep vanaf dat bewezen vloercontact.
			var landed_transform := global_transform
			landed_transform.origin += collision.get_travel()
			var remainder := collision.get_remainder()
			remainder.y = 0.0
			blocked = not remainder.is_zero_approx() and test_move(landed_transform, remainder, collision) and collision.get_normal().dot(Vector3.UP) < cos(floor_max_angle)
	if not blocked:
		return false
	for option in _clearance_motion_options(_posture, horizontal_motion, false):
		var plan := _step_plan(option, _posture)
		if plan.is_empty() or Vector3(plan.destination).y > maximum_floor_y:
			continue
		global_position = plan.destination
		_step_support_point = plan.support
		_step_support_direction = plan.direction
		_step_support_remaining = plan.remaining
		_last_step_height = plan.rise
		return true
	return false


func _continue_step(horizontal_motion: Vector3) -> bool:
	var support_ray := PhysicsRayQueryParameters3D.create(_step_support_point + Vector3.UP * 0.05, _step_support_point - Vector3.UP * 0.05, collision_mask, [get_rid()])
	var support := get_world_3d().direct_space_state.intersect_ray(support_ray)
	if support.is_empty() or Vector3(support.normal).dot(Vector3.UP) < cos(floor_max_angle):
		_step_support_remaining = 0.0
		return false
	for option in _clearance_motion_options(_posture, horizontal_motion, false):
		if option.normalized().dot(_step_support_direction) < 0.7:
			continue
		var actual_destination := global_position + option
		actual_destination.y = _step_support_point.y
		if test_move(global_transform, actual_destination - global_position):
			continue
		_last_step_height = maxf(actual_destination.y - global_position.y, 0.0)
		global_position = actual_destination
		_step_support_remaining = maxf(_step_support_remaining - option.length(), 0.0)
		return true
	_step_support_remaining = 0.0
	return false


func _posture_probe_distance(posture: int, direction: Vector3, delta: float) -> float:
	var dimensions := _posture_dimensions(posture)
	var extent := dimensions.x
	if posture == Posture.PRONE:
		extent += maxf(dimensions.y * 0.5 - dimensions.x, 0.0) * absf((-global_basis.z).dot(direction))
	var local := global_basis.inverse() * direction
	var manual_state := "kruipen" if _manual_posture == Posture.CROUCH else ("sneak" if _sneak_requested else ("sprint" if _sprint_requested else "lopen"))
	var requested_speed := direction_speed_limit_for_state(Vector2(local.x, local.z), manual_state)
	var speed := maxf(Vector2(velocity.x, velocity.z).length(), requested_speed)
	return extent + 0.12 + speed * delta * 2.0


func _clearance_motion_options(posture: int, motion: Vector3, normalize_length: bool = true) -> Array[Vector3]:
	var options: Array[Vector3] = [motion]
	var current := motion
	for index in 2:
		var normal := _shape_collision_normal(posture, global_transform, current)
		if normal.is_zero_approx() or absf(normal.y) > 0.5:
			break
		var slid := current.slide(normal)
		slid.y = 0.0
		if slid.length() < 0.02 or slid.normalized().dot(motion.normalized()) < 0.1:
			break
		if normalize_length:
			slid = slid.normalized() * motion.length()
		if slid.normalized().dot(current.normalized()) > 0.999:
			break
		options.append(slid)
		current = slid
	return options


func _clearance_path_passable(posture: int, motion: Vector3, margin: float = 0.0) -> bool:
	if _shape_sweep_clear(posture, global_transform, motion, margin):
		return true
	return not _step_plan(motion, posture, motion.length(), margin).is_empty()


func _higher_path_clear(posture: int, motion: Vector3, margin: float) -> bool:
	for option in _clearance_motion_options(_posture, motion):
		if _clearance_path_passable(posture, option, margin):
			return true
	return false


func _update_auto_posture_demand(input: Vector2, delta: float) -> void:
	if input.is_zero_approx() or _manual_posture == Posture.PRONE:
		_auto_posture_demand = _manual_posture
		return
	# Eén gedeelde vooruitblik bewaakt zowel verlagen als herstellen. Zo kan
	# automatische kruip verder naar lig zonder een te late tweede ingangstest.
	var direction := _input_direction.normalized()
	var probe_distance := maxf(_auto_probe_distance, _posture_probe_distance(Posture.PRONE, direction, delta))
	var approach := direction * probe_distance
	var previous := _auto_posture_demand
	_auto_posture_demand = _manual_posture
	# Alleen eigen kruipkeuze geeft toestemming om automatisch verder te liggen.
	var lowest := Posture.PRONE if _manual_posture == Posture.CROUCH else Posture.CROUCH
	for candidate in range(_manual_posture, lowest + 1):
		for option in _clearance_motion_options(candidate, approach):
			if not _clearance_path_passable(candidate, option):
				continue
			# De vraag mag twee stappen lager liggen; de echte collider verandert
			# hoogstens één aangrenzende automatische houding per physicsframe.
			var next := mini(candidate, _posture + 1)
			if candidate > _posture and not _posture_transition_clear(next):
				continue
			_auto_posture_demand = candidate
			if candidate > _manual_posture:
				_auto_probe_distance = probe_distance
			return
	if previous > _manual_posture:
		_auto_posture_demand = previous
		_auto_probe_distance = probe_distance


func _update_debug_arrows() -> void:
	_debug_arrows.visible = debug_enabled
	_update_arrow(_input_arrow, _input_direction)
	_update_arrow(_movement_arrow, _movement_direction)


func _update_arrow(arrow: Node3D, world_direction: Vector3) -> void:
	arrow.visible = not world_direction.is_zero_approx()
	if arrow.visible:
		var local_direction := global_basis.inverse() * world_direction
		arrow.rotation.y = atan2(-local_direction.x, -local_direction.z)


func get_debug_state() -> Dictionary:
	var motion := _movement_state()
	if _slide_active:
		motion = "slide"
	elif not is_on_floor() and _step_support_remaining <= 0.0:
		motion = "lucht"
	elif _actual_speed < 0.02:
		motion = "stilstand"
	var local_input := global_basis.inverse() * _input_direction
	var state := {"display_name": display_name, "speed": _actual_speed, "motion_mode": motion, "posture": _posture_name(_posture), "posture_index": _posture, "manual_posture": _posture_name(_manual_posture), "input_direction": _input_direction, "movement_direction": _movement_direction, "facing_direction": -global_basis.z, "body_direction": -global_basis.z, "body_yaw": rad_to_deg(global_rotation.y), "turn_rate": _turn_rate, "body_turn_blocked": _body_turn_blocked, "speed_limit": direction_speed_limit_for_state(Vector2(local_input.x, local_input.z), _movement_state()), "jump_profile": _jump_profile, "jump_height": _jump_height, "launch_speed": _launch_speed, "jump_boost": _jump_boost, "air_speed_cap": _air_speed_cap, "fatigue": _fatigue, "fatigue_recovery_time": _fatigue_recovery_duration, "coyote_remaining": _coyote_remaining, "jump_buffer_remaining": _jump_buffer_remaining, "ground_jump_available": _ground_jump_available, "step_height": _step_limit_for_posture(_posture), "last_step_height": _last_step_height, "debug_enabled": debug_enabled}
	state.merge({"air_braking": _air_braking, "slide_pending": _slide_pending, "slide_active": _slide_active, "slide_time_left": _slide_time_left, "slide_speed": Vector2(velocity.x, velocity.z).length() if _slide_active else 0.0, "prone_return_posture": _posture_name(_prone_return_posture)})
	state.merge({"air_kind": _air_kind, "gait_phase": _stride.phase, "step_index": _stride.step_index, "stride_jump_available": _stride_jump_available, "stride_probe_count": _stride_probe_count, "external_speed_allowance": _external_speed_allowance, "mass_kg": body_profile.mass_kg})
	state.merge(_camera_pivot.get_state(), true)
	return state


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if capsule_height < capsule_radius * 2.0 or crouch_capsule_height < crouch_capsule_radius * 2.0 or prone_capsule_length < prone_capsule_radius * 2.0:
		warnings.append("Elke capsulemaat moet minstens twee keer de radius zijn. Atlas bewaart de radius en vergroot een ongeldige lengte/hoogte tot dat minimum.")
	for state in ["lopen", "sprint", "sneak", "kruipen", "liggen"]:
		var profile := _movement_profile(state)
		if float(profile.back_ratio) >= float(profile.side_ratio) or float(profile.side_ratio) >= 1.0:
			warnings.append("%s: gebruik achterwaarts < zijwaarts < vooruit voor de afgesproken richtingssnelheden." % state)
	if sprint_forward_speed <= walk_forward_speed:
		warnings.append("Sprint moet sneller zijn dan lopen om een apart sprint-spronganker te bereiken.")
	if crouch_capsule_height >= capsule_height or prone_capsule_radius * 2.0 >= crouch_capsule_height:
		warnings.append("Gebruik staan hoger dan kruip, en kruip hoger dan lig, voor de veilige houdingsvolgorde.")
	if sneak_min_jump_height > sneak_jump_height:
		warnings.append("Minimum sneakhoogte is hoger dan de basis. Atlas houdt de ingestelde basis aan; verhoog die zelf voor een bruikbaar opstapje.")
	if camera_eye_height >= _posture_vertical_height(Posture.STAND) or crouch_eye_height >= _posture_vertical_height(Posture.CROUCH) or prone_eye_height >= _posture_vertical_height(Posture.PRONE):
		warnings.append("Plaats iedere ooghoogte binnen de eigen capsulehoogte. De camera begrenst een onveilige hoogte voor de doorgang.")
	if idle_body_turn_stop_angle >= idle_body_turn_start_angle and idle_body_turn_start_angle > 0.0:
		warnings.append("Laat stilstaand bijdraaien stoppen bij een kleinere hoofdhoek dan de starthoek; dat voorkomt flikkeren rond de grens.")
	if idle_body_turn_start_angle > head_max_yaw:
		warnings.append("De stilstaande draaistart ligt voorbij de hoofdlimiet; Atlas begint uiterlijk bij de hoofdlimiet.")
	return warnings
