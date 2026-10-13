# Procedurele grondproef gebruiken

Open de vaste Atlas-map met `game/project.godot`, daarna `scenes/main.tscn` en F5. De HUD toont de geselecteerde gepubliceerde bronversie; [WORK](../../WORK.md) bewaart acceptatie en overdracht. De proef is lokaal, zonder netwerk of ragdoll.

## Spelen en beoordelen

1. Loop en sprint met WASD/Shift, wissel richting en stop. Bekijk in third person de kniebuiging, tegengestelde armzwaai en vaste steunvoet. Iedere gewone pas heeft een korte echte vlucht; hogere snelheid geeft meer hoogte en tijd. Alt is sneak met veel kleinere vlucht. Tab wisselt tussen Artemis en twee verschillende beenverhoudingen; de technische suite gebruikt daarnaast het gemiddelde proeflichaam.
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

De rustigere voetbreedte is instelbaar met **Walking Stance Ratio** en **Idle Stance Ratio**. **Walk Start Support Ratio** verkort alleen de eerste gewone steun bij starten, hervatten en omkeren; sprint behoudt zijn cadans. Kleine waarden laten de volgende stap eerder beginnen. Probeer ook schuin lopen, omkeren en stoppen terwijl je omkijkt.
