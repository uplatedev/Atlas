# T-011 — Procedurele presentatie en lichaamsprofielen

Dit onderdeel valt onder de T-011-claim en de [centrale afspraken](../../DECISIONS.md). Het past geen capsulepositie of motorsnelheid aan. De motor levert afgeronde pas- en bewegingsgegevens; de presentatie plant voeten, verwerkt hoofd/kijkrichting en schrijft uitsluitend skeletposes.

## Gebouwd

`AtlasCharacterBodyProfile` bevat modelscene, botkoppelingen, massa, knie-/ellebooggrenzen, pasinstellingen en twee bewerkbare Curve-resources. `make_instance_unique()` kopieert profiel en beide curves expliciet; het modelbestand blijft gedeeld. De Character-root gebruikt dit om een eigen bewerkbaar profiel per instance te leveren. De voetcurve regelt relatieve heffing gedurende de zwaai; de pasvluchtcurve regelt hoogte als deel van gemeten beenlengte. Het eerste/laatste punt van een zwaai wordt veilig nul behandeld. Massa bepaalt geen zwaartekracht of gewenste snelheid.

`AtlasCharacterPresentation.setup(character, profile)` instantieert het model, meet de rustbotten en meldt de beenlengte terug via `set_procedural_leg_length`. `consume_frame` ontvangt de echte motoruitkomst en vult `foot_contacts` voordat feedback dezelfde frame leest. De motor bepaalt fase, pasindex en luchtsoort. `reset_pose` verwijdert oude contacten bij herstart. Een `SkeletonModifier3D` voert een analytische oplossing met twee segmenten uit, met vaste knie-/elleboogbuigrichting en instelbare flexgrenzen. Er is geen iteratieve solver of zoektocht over meshes.

Steunvoeten bewaren een wereldpunt; echte pasvlucht laat beide voeten los. Een extreem buiten bereik verplaatst lichaam laat het contact expliciet los. Normale steun herplant een voet niet stiekem. Bekkenverlaging maakt grondcontact bereikbaar; maximale steunperiode schaalt met beenlengte en snelheid. Armzwaai is tegengesteld, wordt groter bij snelheid en krijgt meer elleboogbuiging; sprong en landing mengen kort naar/van de gezamenlijke sprongpose. Hoofd volgt de bestaande look-input. Kruip, lig en slide hebben eenvoudige lage poses.

Maximaal twee lokale voetmetingen per bewegingsframe; stabiele stilstand hergebruikt bestaande contacten. Physicsqueries gebeuren in de motorframe-consumer, niet in renderupdates. Raycasts en pose-IK zijn los van capsulebesturing.

Drie opgeslagen proefprofielen staan onder `game/characters/procedural/profiles`: gemiddelde benen (.38/.38 m, 75 kg), lange bovenbenen (.49/.32 m, 90 kg), lange onderbenen (.27/.44 m, 55 kg). Eén dezelfde planner en skeletoplosser bedienen deze lichamen en Artemis (.334538/.339238 m). De eenvoudige proeflichamen worden uit een rustskelet en zichtbare segmenten opgebouwd; zij zijn geen nieuwe uiteindelijke artassets.

## Technisch gecontroleerd

Op Godot `4.7.2.stable.official.ed1daf0bf`, Jolt, met de gerepareerde Artemis-GLB uit rigcommit `c39473d`: import/parsercontrole en `res://tests/procedural_presentation_checks.gd` slagen. Die echte SceneTree/physics/skeletproef meet de drie verschillende segmentverhoudingen en Artemis, wereldvaste voetsteun, twee vrije voeten in vlucht, precies één contactcue na motorlanding, maximaal twee rays, capsule-onafhankelijkheid en eindige lage poses. Werkelijke enkelafstand tot het geplante wereldpunt is in deze beperkte proef kleiner dan 0.000001 m; ook analytische afstandsfout blijft onder 0.000001 m. Extra kniegrenzen 55–85° en ellebooggrenzen 50–80° worden op de gemeten botposes gecontroleerd. Hoofdrotatie en geleidelijke sprongpose zijn gecontroleerd.

Een profielscene is werkelijk gepackt, opgeslagen en opnieuw geladen; twee instances hebben afzonderlijke profielen en beide curves. Een wijziging aan de eerste heropende curve verandert de tweede niet. De geïntegreerde Character-root moet afzonderlijk op diezelfde menselijke editorwerkwijze worden gecontroleerd.

De lokale vierlichaamproef meet ongeveer 20–100 microseconden voor de voetplanner per frame, inclusief twee rays, op deze machine. Dit is geen complete gameframetijd en sluit skelet-/rendererwerk uit; geïntegreerde metingen horen bij de rootproef. [Controle-uitvoer](presentation-validation.txt) bewaart de werkelijke waarden.

`res://tests/procedural_presentation_preview.gd` rendert vier lichamen met dezelfde frames via Windows/OpenGL Compatibility. [Steunfase](presentation-stride.png) en [luchtfase](presentation-flight.png) zijn visueel geïnspecteerd op grove vervorming en been-/armrichting. Dit is componentbewijs met gesimuleerde motorframes, geen bewijs van goed loopgevoel of de complete besturing.

## Herhalen en beoordelen

Na import: start Godot met `--headless --path game --script res://tests/procedural_presentation_checks.gd`. De grafische preview gebruikt dezelfde projectmap met `--script res://tests/procedural_presentation_preview.gd`; PNGs worden lokaal onder Godot `user://` geschreven. Beide vereisen de gerepareerde Artemis-asset.

Via de Character-root: wijzig bij één instance het lichaamsprofiel, de voetcurve of kniegrenzen. Speel lopen/sprint/achteruit/zijwaarts en spatie, Ctrl en slide; bekijk ook het andere lichaam. Sla de scène op, heropen en controleer dat de instellingen apart blijven. Gewenst menselijk oordeel: armzwaai, beenritme, zweeffase, lage houdingen, modelhanden en begrijpelijkheid van de profielvelden.

## Grenzen en volgende stap

Gebruikersbeoordeling is nog open. De componentproef vervangt geen geïntegreerde sprint-/trede-/randproef, camerameting of werkelijke editorbediening. Modelscene met uniform geschaald skelet is het ondersteunde startpunt; uiteenlopende proporties zitten in de rustbotten, niet in niet-uniforme objectscale. Vaste geometrie is ondersteund; bewegende steunobjecten, ragdoll, klimmen en multiplayer blijven latere afzonderlijke proeven. Geen afzonderlijke netwerk- of gameplayautoriteit is in deze presentatie toegevoegd.
