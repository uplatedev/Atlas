# Menselijke passen — technisch checkpoint

Vervolg op [onderzoek](gait-research.md), [draaionderzoek](turn-research.md) en [grondproef](ground-trial.md). Eigenaar/scope blijft T-011; dit is een speelcheckpoint zonder volledige menselijke acceptatie. Op 14 oktober 2026 is de bestaande speelversie op expliciet verzoek van de gebruiker via T-012 naar main gebracht; de hieronder beschreven poseproblemen en beoordeling blijven open.

## Gebouwd

Alt gebruikt de rustige wandelmotor op 1,4 m/s, gewone beweging jogt op 3 m/s, sprint blijft 9 m/s. Individuele instance-overrides blijven behouden. Steun, vlucht en beenbereik worden samen gepland uit snelheid, zwaartekracht en gemeten beenlengte; presentatie volgt die motorfase. Wandelen gebruikt dubbele steun en afrol rond een vaste hiel/voorvoet, jog en sprint echte afzonderlijke vlucht. Zijwaarts opent de leidende voet vanuit rust, de andere volgt met een eigen contact.

De pose maakt wandelen en joggen verschillend in voethef, achterbereik, knieherstel, armzwaai en opvang. Overgangen volgen werkelijke deceleratie: Alt kiest geen onhaalbare wandelcyclus terwijl nog sprintmomentum bestaat. Geplante vlakke zolen bewaren hun richting. Een grote snelle stilstaande draai verkort de bestaande bijstap begrensd van circa0,22 naar0,14–0,17s, na hoofd-/borstreserve; rustig omkijken houdt het eerdere tempo. De camera bestuurt geen tweede los pasritme. De bestaande motor-draailimieten zijn op basis van een aparte parameterproef gematigd: Alt240, jog360 en volle sprint240°/s; individuele overrides blijven behouden. Dit helpt vooral abrupte sprintcontacten, maar repareert geen vrije landingsbaan.

## Herhalen

`tools/Check-Atlas.ps1 -CharacterChecks` voert de volledige serie uit. De cadansproef telt werkelijke contacten gedurende acht seconden na twee seconden inlopen op vier verschillende lichaamsverhoudingen; hij roept geen plannertimingfunctie als oracle aan. De voetafrolproef reconstrueert echte zoolpunten uit bottransforms. Beide toetsen fysiek bereik, afzonderlijke contacten en begrensde lokale queries; ze beoordelen geen mooi uiterlijk.

`game/tests/procedural_gait_review_preview.gd` levert echte beelden op 60 physics-ticks per seconde, met precies één tick per PNG. [Grondproef](ground-trial.md) bevat styles/views en de menselijke handelingen. `game/tests/procedural_performance_preview.gd` meet afzonderlijk met de echte renderer zonder fixed-fps/vsync, drie seconden opwarmen en vier seconden meten voor1/4/12 Characters. Deze route wacht niet op een specifieke historische pasfase. Lokale GIF/WebP-beelden en ruwe logs blijven buiten bronhistorie.

## Technisch gecontroleerd op het checkpoint

Bron `5077b719755d224119198bf6cbcd15d9a5c44605`, Character-subtree `c97b9d5a66220d421a69c62a0d1c9415752c64cd`. Godot4.7.2.stable.official.ed1daf0bf, Jolt60Hz: import, korte hoofdscene-start en alle30 suites PASS. Camera-oracle bewaart haar historische5/2m/s en540/300/420°/s:5.169 numerieke waarden met grootste afwijking0. Bestaande startup-, terrein- en contactfixtures zijn voor de nieuwe snelheid/afrol gecorrigeerd; geometrische/pin-grenzen zijn niet versoepeld. [Compacte echte uitvoer en meetresultaten](human-gaits-validation.json).

Werkelijke Artemiscontacten na2s inlopen,8s meten: wandelen144/min met95 dubbele-steunticks en0vlucht; jog180/min met144vluchtticks; sprint257,1/min met343vluchtticks. Jog/sprint hebben geen dubbele steun. Eén tik is1/60s; cadans komt uit geaccepteerde contacten, niet een gewenste plannerwaarde. Links/rechts shuffle heeft twee afzonderlijke contacten per cyclus; contactcadans groeit211,8→318,1→521/min bij Alt/jog/sprintsnelheid. Deze snelle zijgang is een gestileerde proef, geen biomechanisch geaccepteerde sprintshuffle.

De uiteindelijke bewegende-draaiproef op vier lichamen behoudt pins exact, minste enkelafstand10,36cm, grootste zoolmarkerfout2,39µm en doelfout2,33µm, hoogstens2 lokale voetqueries per tick. OPEN overdracht vrij/contact per tick: WALK30,8/23,1cm, JOG17,8/19,8cm, sprint15,2/2,4cm. Lichaamtranslatie is afgetrokken. Sommige pieken bestaan al vóór een cameradraai; ze mogen geen claim van vloeiendheid krijgen.

Zeven echte rendereropnames zijn bekeken als volledige cyclus en beeldenoverzicht: walk side/front, jog side/front, sprint side en shuffle/shuffle_sprint front. Ieder180 opeenvolgende physics-ticks en180 WebP-frames, exact3s normale afspeeltijd. De slow-GIF speelt alleen3× langzamer. Bron173945 bevat dezelfde gangcode; de latere motor-defaults veranderen uitsluitend draai en houden de rechte vergelijking gelijk. Deze beelden bewijzen geen draai-/omkeerkwaliteit of menselijke acceptatie.

Realtime rendererproef, Windows/RTX5060Ti/Forward+,1280×800,vsync/fixed-fps uit,3s opwarmen en4s meten. Exact dezelfde externe performance-only-hulp op458aa409 en deze kandidaat; geen andere Atlas-engine tegelijk. Frame-intervallen in ms:

| Characters | Oud p95 / piek | Nieuw p95 / piek | Nieuwe grondqueries/s totaal |
| --- | --- | --- | --- |
| 1 | 1.509 / 19.691 | 2.022 / 12.276 | 166.9 |
| 4 | 2.565 / 18.449 | 3.850 / 14.305 | 669.0 |
| 12 | 6.704 / 12.682 | 9.030 / 16.240 | 2004.2 |

De nieuwe contact-/afrolpresentatie heeft meetbare meerkosten; bijvoorbeeld12 Characters p95+2,326ms. Queryaantal blijft gelijk binnen de meetgrens. De querysom omvat bestaande pas-steunprobe en voetmetingen; de lokale voetgrens blijft2. Ruwe Godot-process/physics-monitorwaarden staan afzonderlijk in de JSON en zijn geen geïsoleerde CPU-profiler. Eén korte sequentiële meting bevat OS/GPU-pieken en bewijst geen heel level, lange speelduur of LAN/Steam.

## Grenzen en volgende stap

Technische controles bewijzen het ontspannen loopgevoel of menselijke editorbediening niet. De gebruiker beoordeelt wandeling, jog, shuffle, sprintcadans en snel omkijken op het gepubliceerde checkpoint. De vaste Atlas-map wordt pas na publicatie en controle veilig bijgewerkt. Klimmen, tijdelijke ragdoll en andere traversal blijven latere afzonderlijke proeven.

Een oudere voetposefout bij achteruit bewegen blijft apart open: met een achterwaarts geplaatst enkeldoel en voorwaartse kniepool kan de anatomische enkelbegrenzing de teen door de vloer richten. Een algemene extra hoogtecorrectie lost dat niet betrouwbaar op en wordt niet toegepast. Een mogelijke kleine vervolgaanpak plant het achterwaartse voorvoetcontact en enkelhoek samen, reconstrueert het enkeldoel analytisch en bewaart dat contact bij richtingswissel. De [afzonderlijke algebraproef](backward-forefoot-research.md) is gebouwd en gecontroleerd; hij is nog geen Godot-/meshoplossing of geaccepteerde pose. De huidige twee lokale voetmetingen blijven de grens.

De bestaande vrije-voetbewaking, contactoverdracht en omkeerrichting zijn ook tijdens bewegen gecorrigeerd. Voorspellende vrije voetplaatsing bij snel draaien tijdens beweging is nog een vervolgvoorstel. Abrupte poseoverdracht blijft OPEN, ook wanneer pin-, kruisings- en bereikcontroles slagen. Het [draaionderzoek](turn-research.md) onderscheidt die vraag van de gebouwde snellere stilstaande bijstap en vaste zooloriëntatie. Alleen een gerichte motor-/bottrace rechtvaardigt een extra correctie; geen lineaire muissnelheid→cadansregel.
