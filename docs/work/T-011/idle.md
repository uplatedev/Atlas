# T-011 — Losse idlebeweging en Artemis-knipper

- **Gebouwd:** idle is geïntegreerd in de bestaande `AtlasCharacterPresentation`: setup/reset, één physics-update vóór de posecache, additive borst/hoofd/schouders en de bestaande ene skeletmodifier. `AtlasIdleMotion` in `game/characters/procedural/idle_motion.gd`, Eyes-only shader en de exportgroep **Idle** op het lichaamsprofiel. Eigen RNG/timing en materiaal per instance. Ademcyclus 4–5 s, knipperpauze 3–7 s, zuchtpauze 20–40 s; veilige grenzen worden ook tijdens uitvoering toegepast. Visuele zucht gebruikt borst/schouders, nooit jaw of audio. Originele Blender/GLB en de 53 deformbotten blijven ongewijzigd.
- **Technisch gecontroleerd:** Godot 4.7.2 import; `procedural_idle_checks.gd` headless en echte D3D12/Forward+ PASS. Twee minuten gesimuleerde helperupdates: 447 frames verschillende knipperwaarden, elk 23 knippers en 3 zuchten; grootste borstoffset 1,7868°. De twee voorbeelden hebben verschillende reproduceerbare testseeds; productie randomiseert per helper. Alle acht huidinvloeden, topologie, geometrie en LOD-data behouden. Andere materialen blijven dezelfde Resources. Op hetzelfde model opnieuw setup of live idle-afstelling geeft geen model-/meshherbouw. Profielkopieën, modellen zonder Eyes, reset, uitgezette idle en omgekeerde/buitenbereik intervallen gecontroleerd. Twintig updates na deactivatie geven exact nul op alle additivewaarden. De echte close-ups hieronder zijn bekeken: open→half→dunne sluitlijn, passende huidkleur, ook bij hoofd-yaw/pitch.
- **Door de gebruiker beoordeeld:** nog open. Dit is ontwikkelaarscontrole van knipperen en helperwaarden. De volledige adem-/zuchtpose is met twee echte Characters technisch gecontroleerd en in Godot bekeken; dit is nog geen gebruikersacceptatie.
- **Volgende stap:** de gebruiker laat in de gewone Character-scene twee Characters stilstaan, vertrekken en weer stoppen; beoordeel of ademhaling, incidentele zucht en knipperen rustig genoeg blijven. WALK/SIDE/DIAG/slide blijven prioriteit houden.

## Integratie voor de bestaande pose-eigenaar

1. Maak één `AtlasIdleMotion.new()` per `AtlasCharacterPresentation`. Roep `setup(_visual, _profile)` alleen na het aanmaken van het model aan. De helper zoekt uitsluitend vlakke materiaalcombinaties **Eyes** + **Skin** zonder albedotextuur; andere modellen krijgen geen shader. Er komt geen extra node, skeletmodifier of animatiespeler bij.
2. Roep `reset()` aan vanuit `reset_pose()`. Na modelvervanging bewaart de helper geen oude nodeverwijzingen; alleen het nieuwe model-ID en de eigen materialen. `setup` is idempotent voor hetzelfde model-ID.
3. Roep `advance(frame.delta, active)` precies eenmaal vanuit `consume_frame` vóór `_cache_physics_pose`. `active` hoort bij echt ondersteunde, stilstaande STAND, zonder slide/sprong/actieve bijstap. De helper mengt in/uit over 0,25 s. Timers starten uitsluitend wanneer idle actief en ingeschakeld is; bestaande gebeurtenissen lopen begrensd uit. Roep deze helper niet vanuit renderinterpolatie aan.
4. Uitvoer: `chest_pitch` en `head_pitch` zijn radialen; `shoulder_lift` is een fractie van beenlengte; `blink_amount` is 0–1 en wordt al door de helper naar zijn eigen Eyes-materialen geschreven. Positieve borstpitch om lichaamsrechts helt licht achterover (inademing). `head_pitch` is een kleine tegengestelde pitch om de **motor-/blikrechtsas vóór head-yaw**, niet de al gedraaide visuele as. Schouderheffing hoort langs wereld-UP: vermenigvuldig met gemeten beenlengte en zet naar de lokale ruimte van het schouder-/bovenarm-parent om. Wijzig alleen de bestaande botposes vóór hun physics-cache; voeten, bekkenhoogte, contactframe en capsule blijven leidend zoals voorheen.
5. De helper wijzigt geen rig_signature. De exportvelden zijn scalars/Vector2-waarden; `make_instance_unique()` kopieert ze zonder extra mutable Resources of nodeverwijzingen. De shader is gedeeld en onveranderlijk, ShaderMaterial en meshkopie zijn per model uniek. Dit kost eenmalig een meshkopie bij setup; `advance` verricht geen mesh- of raywerk.

## Oogtechniek en begrenzing

Artemis heeft twee achthoekige donkere oogvlakken (16 vertices), geen ooglidbotten/morphs en lege oog-UVs. De helper leidt eenmaal UV.y af uit de rusthoogte op een nieuwe ArrayMesh, met dezelfde LODs/blendvormen en acht huidinvloeden. De ondoorzichtige shader vult de boven-/onderzijde met Skin-albedo én Skin-roughness en bewaart een dun donker sluitlijntje. Er is geen discard/alpha-gat en geen doorlopende CPU-huidbewerking. Dit is gericht op Artemis' vlakke stijl; het is geen algemene ooglidoplossing voor textured/realistische gezichten. Kaakbeweging is bewust afwezig: Artemis' oogpunten hebben circa 11–18% jaw-gewicht.

API-bron voor behoud van meshdata: [ArrayMesh](https://docs.godotengine.org/en/stable/classes/class_arraymesh.html) en [RenderingServer mesh_get_surface](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html#class-renderingserver-method-mesh-get-surface).

## Herhalen

`godot --headless --path game --script res://tests/procedural_idle_checks.gd`

Voor echte ogen, voeg een renderer en uitvoermap toe (zonder `--headless`):
`godot --path game --script res://tests/procedural_idle_checks.gd -- --idle-captures=<absolute uitvoermap>`

[Open](idle-images/front_0.0.png) · [Half dicht](idle-images/front_0.55.png) · [Gesloten naast open instance](idle-images/front_1.0.png) · [Gedraaid hoofd, gesloten](idle-images/side_closed_look.png)
## Geïntegreerde volledige lichaamsproef

Bronbasis `feedb0e` met de bijbehorende idle-posewijziging. `procedural_idle_pose_checks.gd` gebruikt twee echte `Character.tscn`-instances met dezelfde input en afzonderlijke profielen: één idle aan, één uit. De test omvat tien seconden stilstand met echte knipper-/zuchtgebeurtenissen, vertrekken, doorlopen, stoppen en herplanten, afzonderlijke knippertiming en Character-reset. Timers lopen uitsluitend in physics; vier extra renderpasses veranderen de ademfase niet. Model- en skelet-ID blijven gelijk, één oogmeshkopie per spawn.

Godot 4.7.2: headless én D3D12/Forward+ PASS. Maximale verschillen tussen de motoren: positie/snelheid exact 0; contact-/voetdoelen 0,000000267 m; gaitfase 0,0000000095 (wereldcoördinatenprecisie). Alle discrete contact-/sprong-/bijstapvelden blijven gelijk. Werkelijke botposes meten maximaal 1,0393° borst, 0,1897° hoofd en 3,7476 mm extra schouderbeweging. Schouderafwijking van wereld-UP < 0,000000008 m. Extra borstverandering per physics-frame maximaal 0,0792°; hiervoor wordt de gewone loopkanteling van het gelijktijdige referentiecharacter afgetrokken. De opgeslagen posecache is exact gelijk aan de gemeten botposes. Na uitmengen tijdens lopen zijn alle gecachete botposes gelijk aan de instance met idle uit. Dit meet echte bottransforms, niet alleen helperwaarden of voetdoelen.

De aparte helperproef blijft PASS: twee minuten timing, ogenmesh/acht huidgewichten/LODs, materiaal- en profielisolatie, modellen zonder Eyes, live afstellen zonder rig-herbouw en begrensde instellingen.

Herhalen:

`godot --headless --path game --fixed-fps 60 --script res://tests/procedural_idle_pose_checks.gd`

Voor de volledige echte Godot-beelden, zonder `--headless`:

`godot --path game --fixed-fps 60 --script res://tests/procedural_idle_pose_checks.gd -- --idle-pose-captures=<absolute uitvoermap>`

In deze beelden staat **rechts idle aan** en **links idle uit**. De opnames gebruiken natuurlijke helperupdates, geen geforceerde bot- of shaderposes: [ademhaling](idle-images/body_breath.png), [zucht](idle-images/body_sigh.png), [knipper](idle-images/body_blink.png). De lichte borst-/schouderbeweging en dunne oogsluitlijn zijn visueel gecontroleerd; de stilstaande voetpositie blijft gelijk. Logs: [idle-validation.txt](idle-validation.txt).