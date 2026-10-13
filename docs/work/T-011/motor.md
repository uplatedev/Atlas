# T-011 — Procedurele capsulemotor

Aanvulling op [T-011](../T-011.md). De motor bezit alle verplaatsing en collision; de presentatie ontvangt het definitieve contactframe en kan alleen voetcontacten voor feedback toevoegen. Godot 4.7.2.stable.official.ed1daf0bf, Jolt, 60 physicsticks per seconde.

## Gebouwd

- `AtlasCharacterIntent` bundelt beweging, sprint/sneak en nieuwe actieknoppen. Speleradapter en `submit_intent()` doorlopen dezelfde beweging. Ingediende beweging blijft gelden, actie-edges worden eenmaal verbruikt; `use_player_input()` schakelt terug.
- `AtlasStrideScheduler` bezit pasfase en voetindex. De Character gebruikt het eigen lichaamsprofiel en gemeten beenlengte voor steunperiode en vluchtboog. Pasvlucht verplaatst echt de capsule, schakelt floorsnap tijdelijk uit en landt uitsluitend op collision. Afzet gebruikt de gemiddelde snelheid van de eerste integratiestap zodat de hoogtecurve werkelijke meters benadert.
- Tijdens geldige pasvlucht blijft de motor strak sturen. Eén korte lokale vloerprobe per physicstick bewaakt steuncontinuïteit; een afgrond, plafondbotsing of impuls trekt dit recht in. De afzet controleert daarnaast de vrije capsuleboog. De probeaantallen hieronder tellen vloerstralen, niet de bestaande posture-/capsulequeries.
- Spatie vanuit steun of geldige pasvlucht kiest één gewone sprong: vervangt verticale snelheid, gebruikt de bestaande bonus/vermoeidheid eenmaal. Passen geven zelf geen sprongbonus, vermoeidheid of impactlanding. `air_kind` onderscheidt `none`, `stride`, `jump` en `fall`; steunvelden blijven de echte uitkomst.
- Een plafond dat staan wel toelaat maar pasvlucht blokkeert, of een nulhoogtecurve, behoudt afwisselende gesteunde stappen. `ground_step` wisselt de voetindex alleen na echte steun; volgende cycli doorlopen de volledige zwaaifase binnen dezelfde begrensde steunperiode. Geen fictieve vlucht of landing.
- `apply_impulse(world_impulse)` verwerkt wereldimpuls in kg*m/s eenmaal op de volgende physicstick; snelheidsverschil is impuls/massa. Externe horizontale vaart verdwijnt geleidelijk door echte remming/botsing, niet onmiddellijk door de gewone snelheidscap. Een bewuste sprong hergebruikt geen eerdere sprongbonus.
- Lage houding stopt verdere staande passen. C tijdens sprintpasvlucht bereidt dezelfde slide voor bij veilige echte landing. Nieuwe C tijdens een actieve slide bewaart timer/vaart en kiest kruip na afloop. Automatische lig mag alleen vanuit handmatig gekozen kruip; automatisch kruipen vanuit staan is geen toestemming voor lig.

`procedural_enabled` is standaard uit voor de bestaande capsuleproef. De gedeelde proefscene kan dit inschakelen. Het rootprofiel kopieert beide curves per instance. `set_procedural_leg_length()` krijgt de gemeten beenlengte van de presentatie; terugvalwaarde is Artemis' 0,673775 m.

Het nieuwe `procedural_frame_ready`-signaal komt vóór `contact_frame_ready`. Het frame bevat lichaamstransform/-snelheid, echte steun, vluchtsoort, pasfase, voetindex, pasafzet/-landing en gesteunde voetwissel. De presentatie schrijft `foot_contacts`; camera/audio bepalen hun eigen feedback. CameraMotion bevat `air_kind` en fysieke `stride_offset_y`. De rootinstelling `camera_stride_follow_ratio` geeft aan welk aandeel de camera volgt; de cameracomponent implementeert de demping.

## Technisch gecontroleerd

De eigen proef is `game/tests/procedural_motor_checks.gd`; uitvoeren met de vastgelegde engine, `--headless --fixed-fps 60 --path game --script res://tests/procedural_motor_checks.gd`.

- Speler-/AI-route: maximaal positie-/snelheidsverschil 0,00000000.
- Standaard Artemis-profiel: lopen 0,0301 m en 6 luchtframes; sprint 0,0804 m en 10 luchtframes. Hogere snelheid levert hogere/langere vlucht; horizontale doelsnelheid behouden. Hoogstens één lokale vloerstraal per tick.
- Sprong op steunfase en twee luchtfasen: eenmaal geaccepteerd, verticale snelheid vervangen, vermoeidheid eenmaal. Geen sprong-/impactcue op gewone passen.
- Sprintpas naar slide, actieve-slide-C, automatische kruip/lig-grens, afgrond, plafondblokkade en nulhoogtecurve slagen met echte CharacterBody3D-collision.
- Impuls 750 Ns bij 75/150 kg geeft 10,000/5,000 m/s. Bestaande sprint plus impuls meet 18,400 m/s na gewone framevertraging; herhaalde sprongen stapelen die vaart niet.
- Import/start, bestaande Character-suite, contactaudioscheiding (180 frames) en camera-accentenscheiding (220 frames) slagen met procedureel uit. De oude camerabasis wijkt uitsluitend af op de bewust aangepaste lage route en de nieuwe camera-export. De gezamenlijke integratie werkt die specifieke verwachtingen bij en draait de volledige zes suites opnieuw.

## Door de gebruiker beoordeeld

De voorafgaande grondslide is goedgekeurd. Pasgevoel, voetcontacten, armzwaai, camerademping en de volledige editorproef zijn nog te beoordelen in de geïntegreerde speelversie. Deze motorproef bewijst geen meshbereik, presentatiekwaliteit of multiplayer.

## Volgende stap

Integreer presentatie/lifecycle en camera/audio, controleer echte geplante voeten bij langdurige sprint en verschillende lichaamsverhoudingen, draai de volledige regressies en bied de gezamenlijke grondproef aan. De presentatie moet `ground_step` naast `stride_landed` als geaccepteerd voetcontact verwerken.