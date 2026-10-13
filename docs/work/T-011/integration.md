# T-011 — gezamenlijke grondproef

De hoofdscene gebruikt dezelfde plaatsbare `Character.tscn` met Artemis en twee proeflichamen. De integratiesuite gebruikt daarnaast het gemiddelde proeflichaam. Character bezit capsule/snelheid en levert een contactframe; presentatie verwerkt het vóór de afzonderlijke audio-/cameralaag. De profielresource en beide curves zijn per instance onafhankelijk. De scope en menselijke route staan in [T-011](../T-011.md) en [ground-trial](ground-trial.md).

## Technisch bewijs

`game/tests/procedural_integration_checks.gd` stuurt echte Characters door de motor. De proef controleert herhaalde sprintpasvlucht op vier lichamen, wereldvaste werkelijke enkels, geen voetcontactcue tijdens lucht, geen gewone sprong-/impactcue of vermoeidheid door pasvlucht, en maximaal twee lokale voetstralen. Nulhoogtecurve en laag plafond geven gesteunde voetwissels met bijbehorend geluid. Dit is ander bewijs dan de losse componentproef, die vooraf samengestelde contactframes gebruikt.

De camera gebruikt de fysieke pashoogte met een gedempte bijdrage. Op de gecontroleerde sprintbasis was de lichaamsamplitude 0,08044 m en de camera-amplitude 0,01428 m. Eerste-persoonzicht verbergt uitsluitend de eigen presentatie. Echte sprong/val en camerabotsing behouden hun bestaande uitvoering.

Een echte PackedScene met twee Characters is opgeslagen en herladen. Massa, voetcurve en vluchtcurve blijven afzonderlijk, ook bij wijzigingen na heropening. Een model-/botwijziging vernieuwt het model en de rustlengtes; een gewone stijl-/curvewijziging bouwt het skelet niet opnieuw. Elke spawn bouwt precies één Skeleton3D; procedureel uit zet ook de verborgen botuitvoering uit.

De speler en AI gebruiken dezelfde intentie. Naast de motorpariteit wordt kijkoverdracht na meerdere physics- én renderupdates gecontroleerd: AI-yaw/pitch blijven behouden, actieve AI-invoer verhindert muisoverschrijving, terugkeer naar speler springt niet naar een oude hoek, en de hoofd-/pitchgrenzen blijven gelden. De camera bewaart daarvoor dezelfde begrensde kijkhoek die zij aan de motor publiceert. Een onafhankelijke bronreview vond na de correctie geen resterende fout in deze overdracht of de dubbele modelopbouw.

`procedural_terrain_checks.gd` controleert de actuele botpresentatie op acht bewegingsroutes, treden, hellingen, plafondfasen en randen. De gerichte tredecorrectie bewaart 5/9 m/s, terwijl te hoge treden en bewuste sprongen/vallen geen extra opstap krijgen. [Terreinbewijs](terrain.md) noemt de exacte grenzen en querykosten; één motorvloerstraal en twee voetstralen zijn geen telling van alle bestaande capsulequeries.

## Regressie en beoordeling

De zes bestaande suites behouden hun oude capsuleproef door procedureel expliciet uit te zetten. Ze vervangen uitsluitend de achterhaalde actieve-slideannulering en automatische ligroute; de resterende 5.169 camerawaarden vergelijken zonder afwijking. De hoofdscenetest houdt rekening met drie plaatsbare Characters. De volledige herhaalroute staat in `tools/Check-Atlas.ps1 -CharacterChecks`.

Technische controles bewijzen geen natuurlijk loopgevoel. De gebruiker keurde de historische grondslide goed, meldde onjuiste knieën en gaf daarna een rencyclusreferentie plus feedback over voorwaartse armen en mildere enkelbuiging. De gecorrigeerde visuele proef en metingen horen bij [live-visual](live-visual.md); menselijke beoordeling van de volledige beweging en editorhandelingen blijft open.
