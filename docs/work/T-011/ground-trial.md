# Procedurele grondproef gebruiken

Open de vaste Atlas-map met `game/project.godot`, daarna `scenes/main.tscn` en F5. De HUD toont de geselecteerde gepubliceerde bronversie; [WORK](../../WORK.md) bewaart acceptatie en overdracht. De proef is lokaal, zonder netwerk of ragdoll.

## Spelen en beoordelen

1. Loop en sprint met WASD/Shift, wissel richting en stop. Bekijk in third person de kniebuiging, tegengestelde armzwaai en vaste steunvoet. Alt wandelt zonder pasvlucht; gewoon bewegen jogt en Shift sprint. Jog en sprint hebben korte echte pasvlucht; hogere snelheid geeft begrensd meer hoogte. Tab wisselt tussen Artemis en twee verschillende beenverhoudingen; de technische suite gebruikt daarnaast het gemiddelde proeflichaam.
2. Spring met spatie op verschillende pasmomenten. Er hoort één bewuste sprong te volgen, zonder gestapelde bonus. Loop over treden en hellingen, tegen lage plafonds en van de rand. De camera dempt het kleine pasritme; echte sprongen en vallen blijven zichtbaar. Scroll tot first person en controleer het eigen zicht.
3. Sprint en druk C, zowel met als zonder sprong. Druk tijdens de actieve slide nog eens C: de slide moet doorgaan en daarna kruip blijven. Zonder die tweede druk richt je veilig op. Spatie uit een slide springt; S remt. Houd C vast: geen herstart.
4. Loop staand de lage route bij x=-6 in: automatisch kruip mag, de opvolgende ligdoorgang moet blokkeren. Kies bewust C en ga opnieuw: nu mag kruip automatisch lig worden. Z kiest lig; nogmaals Z keert veilig terug naar de eigen vorige houding.
5. Druk I terwijl je steunt en tijdens vlucht. Dezelfde wereldimpuls werkt sterker op een lichtere massa. Het is een beperkte motorproef, zonder lichaamsbotsimulatie. F3 toont massa, vluchtsoort en pasindex. R reset alle Characters.

Beoordeel afzonderlijk: besturingsgevoel, knieën/voetcontact, beide voeten los, armzwaai, lage poses, camerademping en geluid. De gebruiker meldde tijdens een ontwikkelpreview onjuist bewegende knieën; dat is negatieve visuele feedback, geen geaccepteerd uiterlijk. De actuele correctie en bewijs staan bij de visuele proef. De eerder goedgekeurde grondslide blijft als historisch checkpoint `c9aeabca` bewaard.

Vergelijk vooral de zijaanzichten met de [aangeleverde rencyclus](../../../source_assets/characters/references/running-poses.png): gevouwen achterbeen, kniehef, tegengestelde armen en voetstand per pasfase. Voeten horen niet voortdurend naar beneden te wijzen. Op het eerste aangepaste beeld vroeg de gebruiker de armen verder naar voren en minder ver gebogen voeten; ook die afstelling blijft in beweging te beoordelen. De referentie bepaalt de stijl; de drie verschillende lichaamsverhoudingen hoeven niet exact hetzelfde silhouet te krijgen.

Bekijk ook de [voor- en achterreferentie](../../../source_assets/characters/references/running-front-back.jpg): beoordeel voetbreedte tijdens rennen, armen langs de romp, kleine tegengestelde schouder-/bekkendraai en hoofdbeweging. De visuele afstelling blijft afzonderlijk van motorpositie en camera.

Extra gerichte proef na feedback: blijf staan en kijk langzaam links/rechts, draai vervolgens verder en keer plots om. Eerst hoort het hoofd te volgen, dan de torso, daarna verplaatsen de voeten zich met bijstappen. De benen mogen niet kruisen. Begin daarna te lopen. Vergelijk lopen en rennen op stapbreedte, rustiger loopbeen, zachte voetlanding en lichte tegengestelde kanteling van heupen/borst. Gebruik de extra [loopreferentie](../../../source_assets/characters/references/walk-hips-chest.jpg) en [hoogtevergelijking](../../../source_assets/characters/references/walk-run-height.avif).

Bekijk de renpas ook schuin van voren en achteren: de borst hoort tegengesteld aan het bekken te draaien, zodat schouders afwisselend voor- en achteruit komen. Start vervolgens sprint + C: de slide steunt op de knieën, met voeten achter je. Nogmaals C laat dezelfde slide uitlopen en houdt je daarna gekruipt. Herhaal met de andere lichaamsverhoudingen via Tab.

## Eén editoringang

Selecteer `Characters/AtlasA` in de hoofdscene. De Character-root bevat de groep voor procedureel lichaam en het lichaamsprofiel. Klap dat profiel open: model/botkoppelingen, massa, pasverhoudingen, armzwaai en gewrichtsgrenzen horen bij dit lichaam. Bewegingssnelheid, botsingscapsule en camera blijven rootinstellingen. Een ander model moet een humanoïde Skeleton3D met passende botnamen hebben; lengtes komen uit zijn rusthouding. Gebruik uniforme objectscale. De botsingscapsule verandert niet automatisch met een ander uiterlijk: controleer de passende rootvorm zelf.

De twee Curve-velden zijn gewone Godot-curves. Bij de voetcurve is X de voortgang van de zwaai en Y de relatieve voetheffing; de uiteinden blijven op contacthoogte. Bij de pasvluchtcurve is X snelheid gedeeld door referentiesnelheid en Y hoogte als deel van de gemeten beenlengte. Duur volgt uit die hoogte en zwaartekracht. Nulhoogte gebruikt gesteunde passen. Een plafond kan vlucht eveneens verhinderen.

Kleine echte editorproef: dupliceer een Character, wijzig alleen diens massa, voetcurve en pasvluchtcurve, sla de hoofdscene op en heropen hem. Controleer dat het andere Character dezelfde waarden heeft als daarvoor; speel daarna de twee verschillende gangen. Profiel en beide curves worden per instance gekopieerd. Model-/botwijzigingen vernieuwen de rustmeting; stijl-/curvewijzigingen bouwen het skelet niet opnieuw. Scripts controleren opslaan/herladen, maar de begrijpelijkheid van deze handelingen vraagt menselijke beoordeling.

Voor de nieuwe stijl staan in hetzelfde profiel loop-/renbreedte, loophefhoogte, borst-/heupdraai en kanteling, contactcompressie en kniemarge bij de slide. De groep **Bijstappen** bevat pasduur en maximale voetdraaihoek. Verander één waarde op één Character en vergelijk via Tab. De kleine contactveer en deze posewaarden veranderen de capsulebesturing niet; de pasvluchtcurve doet dat bewust wel. Bij een ander model moet de kniemarge bij zijn zichtbare meshdikte passen.

Nieuwe content maak je door `game/characters/Character.tscn` onder `Characters` te plaatsen of een instance te dupliceren. Tab neemt directe Character-children automatisch mee. Voor AI gebruikt dezelfde motor `submit_intent(AtlasCharacterIntent)`; de intentie bevat bewegingswens en eenmalige actieknoppen. Dat is geen editorhandeling voor gewoon plaatsen of variëren.

## Grenzen en herhalen

`tools/Check-Atlas.ps1 -CharacterChecks` importeert en controleert de bestaande besturing/camera/audio en de procedurele motor, presentatie, integratie en terreinen. De afzonderlijke rigproef gebruikt een echte renderer om meshvervorming te bakken. [Rig](rig.md), [motor](motor.md) en [presentatie](presentation.md) beschrijven hun beperkte deelbewijs.

De motor bezit capsule en snelheid. De planner doet hoogstens twee lokale voetmetingen per tick; IK stuurt alleen botten. Impulsen schalen met massa. Klimmen, tijdelijke ragdoll, zwemmen, balanceren, vaulten, ziplines, bouncepads en LAN/Steam volgen de eerder vastgelegde aparte proeven na beoordeling van deze grondbeweging.

## Gerichte vervolgproef na d1196064

De gebruiker vindt de run op die versie goed. Beoordeel de nieuwe correctie daarom apart: kijk stilstaand langzaam én plotseling opzij en let op de borst vóór de eerste voetverplaatsing. Loop daarna vanuit stilstand vooruit, links en rechts, keer van links naar rechts om en stop. De borst mag eerst meedraaien, de benen mogen zijwaarts niet kruisen, het lichaam mag bij weglopen niet plots naar beneden zakken en de voeten horen bij lopen en stoppen dichter bijeen te komen. Vergelijk via Tab de andere beenverhoudingen. Controleer aansluitend dat de vertrouwde renstijl behouden voelt. De technische referentievergelijking bewijst geen volledige acceptatie van dit gevoel.

Voor de torsovolgorde staan onder **Body Profile > Bijstappen** ook **Turn Torso Max Degrees** en **Turn Torso Before Step Degrees**. De eerste bepaalt hoeveel de borst mag draaien; de tweede hoeveel daarvan vóór de eerste bijstap wordt benut. Een onhaalbare combinatie wordt veilig begrensd. Probeer dit op één instance en controleer dat de andere gelijk blijft.

De rustigere voetbreedte is instelbaar met **Walking Stance Ratio** en **Idle Stance Ratio**. **Walk Start Support Ratio** verkort de eerste gewone steun bij starten en hervatten. Bij werkelijk omkeren wordt ook sprintsteun verkort; de zijshuffle gebruikt deze startverhouding eveneens. Kleine waarden laten de volgende stap eerder beginnen. Probeer ook schuin lopen, omkeren en stoppen terwijl je omkijkt.

## Gerichte vervolgproef na c041f65e

De bevestigde indeling is nu **Alt = wandelen**, **WASD = joggen**, **Shift = sprinten**. Op dit historische checkpoint gebruikte Artemis 2/5/9 m/s vooruit; de vervolgproef na 458aa409 gebruikt de nieuw bevestigde defaults 1,4/3/9 m/s. Bewuste instancewaarden blijven behouden. Wandelarmen hangen laag, voeten heffen weinig en er blijft steeds grondsteun. Jog en sprint hebben pasvlucht. Vergelijk vooruit, schuin vooruit en schuin achteruit: het lijf neemt de bewegingsas over terwijl de blik bestuurbaar blijft. Zuiver zijwaarts gebruikt een kleine hup, groter met sprint. Probeer ook wisselen tussen modifiers midden in de pas en spatie op verschillende pasmomenten.

Draai stilstaand langzaam en plotseling, ook terug naar de andere kant. Hoofd en borst nemen eerst ruimte; daarna volgen minder, grotere voetstappen. Eén voet bewaart tijdelijk zijn oude richting. De uiteindelijke ongelijke stand mag blijven staan. Begin vanuit zo'n stand te wandelen of joggen en controleer op kruisen of een plotselinge dip.

Sprint + C gebruikt de diepere knieslide: het bekken zit lager richting kuiten en de borst helt voorwaarts. Nogmaals C laat de slide uitlopen en blijft daarna gekruipt. Blijf tot slot ongeveer 40 seconden staan: ademhaling is klein, ogen knipperen afzonderlijk getimed en af en toe volgt een grotere visuele inademing/zucht. Daar zit geen nieuw zuchtgeluid bij.

De Character blijft één editoringang. In **Body Profile > Wandelen en joggen** staan armzwaai, armstrekking, jogmengverhouding en overgangsduur. **Bijstappen** bewaart duur, voetdraaihoek en borstreserve; **Slide Sit Degrees** regelt zitdiepte binnen de kniegrens. **Idle** bevat aan/uit, sterkte en intervallen. Pas iets aan op één gedupliceerde Character, sla op en heropen: het andere exemplaar moet gelijk blijven. Alleen Artemis' vlakke Eyes/Skin-materialen krijgen de knippershader; andere modellen behouden hun eigen uiterlijk.

## Gerichte vervolgproef na 458aa409

Gebruik de gepubliceerde bronversie uit WORK/HUD en open hetzelfde game/project.godot in de vaste Atlas-map. Begin met ArtemisA; B bewaart zijn eigen hogere snelheden. F5 starten, Tab wisselt Character, R zet terug. De eerdere grondslide-/ruimte-/curveproeven blijven gelden.

1. **Alt-wandelen:** houd Alt+W; laat los en vertrek opnieuw. Let op losse armen, kleine voethef, hiel-naar-voorvoetafrol en een rustige hoogteboog zonder startdip. Kijk ook van voren: smalle voetsporen, geen kruisende knieën.
2. **Joggen:** W zonder modifier, daarna afwisselend Alt/W en Shift/W. Jog moet herkenbaar op één been opvangen en met beide voeten kort vrij komen; het mag geen versnelde wandeling of trillende reeks minipasjes zijn. Armehouding en voetbaan mogen bij wisselen niet springen.
3. **Zijwaarts:** D/A vanuit stilstand; daarna met Shift. De voet aan de bewegingskant opent, de andere volgt zonder kruisen of samen landen. Bij hogere snelheid is korte vlucht toegestaan. Wissel naar W+D en W+A: die horen de voorwaartse gang onder een hoek te tonen.
4. **Overgangen:** keer W→S/A→D om, draai tijdens starten/stoppen, loop over treden/hellingen en spring op verschillende pasmomenten. Oude steun moet veilig overgedragen worden; geen spookcontact, voetglij of herhaalde sprongbonus.
5. **Draaien:** vergelijk rustig en snel 90/180 graden omkijken bij stilstand en tijdens wandelen/joggen/sprinten. Houd W met Alt, zonder modifier en met Shift vast en keer de blik snel om. Abrupte vrije-voet- en contactovergangen blijven OPEN: been-/contactveiligheid is gecontroleerd, vloeiendheid niet geaccepteerd. Geplante zolen houden hun richting; snelle grote stilstaande draaien mogen de bestaande bijstap verkorten. Hoofd/borstreserve en comfortabele asymmetrie blijven. Loopcadans krijgt geen rechtstreekse muissnelheidsvermenigvuldiging. De nieuwe motor-defaults zijn Alt240/jog360/sprint240°/s; vergelijk het ruimere draaien met de vorige proef. B houdt bewust eigen hogere overrides. Stilstaand blijven hoofd-/borstreserve en idle-limiet gelijk.
6. **Editor:** plaats twee Character-instances, wijzig bij één cadans en wandelafrol en bij de ander een vluchtcurve. Bewaar/heropen. Beide instellingen moeten onafhankelijk blijven en de Character-root blijft de herkenbare ingang. De gewenste cadans mag door fysiek bereik of lange vlucht worden begrensd.

De herhaalbare beeldenhulp is game/tests/procedural_gait_review_preview.gd. Start vanuit de repositoryroot met de ingestelde Godot-console-exe en --path game --fixed-fps 60 --script res://tests/procedural_gait_review_preview.gd -- --style=walk --view=side; andere styles jog/sprint/shuffle/shuffle_sprint en views front/rear. Deze beelden tonen rechte constante gangen, geen draai- of omkeerovergangen; beoordeel die in de hoofdscene. Dezelfde echte motorroute levert 180 PNGs per combinatie in user://t011_gait_review, op 60 beelden/s; de opname controleert precies één physics-tick per beeld en mist zo geen kort shufflecontact. Gebruik deze vaste tijdstap alleen voor de beeldproef, nooit voor performance. Een vertraagde weergave verandert alleen afspeelsnelheid, niet de physics. De meetcamera volgt dezelfde interpolatie als het model. Technische contact-/cadansmetingen staan in de nieuwe biomechanics- en rhythm-suites; een PASS bewijst geen ontspannen of overtuigend uiterlijk.
