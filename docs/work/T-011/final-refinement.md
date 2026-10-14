# T-011 — gecombineerde grondproef na stijlfeedback

Geteste codebron: `fb7de5f`, Godot `4.7.2.stable.official.ed1daf0bf`, Windows/Jolt/physics 60 Hz. Publicatie voegt hierna uitsluitend dit bewijs en de overdrachtstekst toe; [WORK](../../WORK.md) noemt de concrete gepubliceerde bron.

## Gebouwd en gecontroleerd

De contactveer, bijstappen, rustigere smallere loop, tegenrotatie van borst/heupen en knieslide zitten samen in dezelfde Character. Bij de knieslide zit het bekken terug richting kuiten en leunt de borst voorover. Motor, presentatie, camera en audio houden elk hun eigen taak. De eerder gevraagde C-/Z-regels blijven behouden.

`tools/Check-Atlas.ps1 -CharacterChecks` slaagt volledig: import, hoofdscene en **15 suites**, exitcode 0. Dit omvat de zes bestaande besturings-/camera-/audiosuites en negen procedurele suites: motor, presentatie, integratie, terrein, knie/enkel, compressie, draaien, stijl en contactvrijgave. [Volledige uitvoer](final-validation.txt).

Gerichte regressies bewijzen nu ook dat afremmen de pasfase niet achteruit laat lopen, bijstapgeluid maar eenmaal bij echt contact klinkt, omhoog/omlaag kijken tijdens draaien geen onbedoelde hoofdrol geeft en een gewone afzet niet als noodloslating wordt geteld. Een echte te grote verplaatsing onder steun laat het oude voetpunt nog wel veilig los. Bijstappen en de overgang naar lopen behouden vaste steunpunten en doen maximaal twee voetmetingen per physics-tick. De motor voegt hoogstens één eigen grondmeting toe.

Het oorspronkelijke draai-naar-loopprobleem is met echte huidbeelden gereproduceerd en opgelost: bij 120 graden draaien gevolgd door negen frames gewoon lopen daalt de bekkenachterstand van 75 naar 1,227 graden. Twaalf ±120/180-graden instappen hebben maximaal 3,361 graden achterstand na negen loopframes, geen kruisende enkelbotten en nul steunpuntdrift. Zie [overgangsproef](turn-transition.md), [vooraanzicht](turn-images/walk_fixed_front.png) en [dezelfde camera als het probleembeeld](turn-images/walk_fixed.png).

De vier humanoïde verhoudingen delen dezelfde code. Profielen, curves, opslag/heropening, massaimpulsen en AI-intentie blijven technisch gecontroleerd. De precieze stijl- en huidmetingen staan in [de stijlproef](live-style.md); de veer in [de compressieproef](live-compression.md). Die deelmetingen worden niet als nieuwe meting van ieder samengevoegd frame voorgesteld. De laatste bronreview vond geen concrete integratieblocker.

## Laatste echte renderer- en prestatieproef

De samengevoegde bron is zonder andere Godot-processen gerenderd met D3D12/Forward+ op RTX 5060 Ti. VSync uit, geen fixed-fps, per aantal 3 seconden opwarmen en 4 seconden meten op de eenvoudige meetvloer. Renderinterval in milliseconden:

| Characters | p50 | p95 | max | Physics-monitor p95 |
| --- | ---: | ---: | ---: | ---: |
| 1 | 0,565 | 0,870 | 2,743 | 0,804 |
| 4 | 1,035 | 2,448 | 3,602 | 2,123 |
| 12 | 2,109 | 5,600 | 7,381 | 5,127 |

Circa 167/669/2006 grondqueries per seconde. Dit is een korte gecontroleerde meetvloerproef, geen garantie voor een complete game. De physics-monitor geeft laagfrequente snapshots; renderintervallen zijn rechtstreeks gemeten. Eerdere historische metingen blijven bewaard, inclusief eerder gemelde desktopuitschieters. [Ruwe meetgegevens](final-performance.json), [rendereruitvoer](final-live-validation.txt), [hoofdscene](final-main.png). Renderer exitcode 0.

## Menselijke beoordeling

De oorspronkelijke grondslide is goedgekeurd. De gebruiker vindt de eerdere gecorrigeerde stijl beter en gaf daarna aanvullende feedback op zachtheid, kruisen, breedte, torso en knieslide. Die is verwerkt; de volledige bewegende proef en echte editorbediening zijn nog niet geaccepteerd.

Volgende stap: [korte speel-/editorroute](ground-trial.md) in de vaste Atlas-map. Let vooral op stilstaand kijken → bijstappen → gewoon lopen, zachte landingen, loop-/renbreedte, tegengestelde borstbeweging en knie-slide met de heupen boven de kuiten. Klimmen, tijdelijke ragdoll en verdere traversal/netwerk blijven de afgesproken afzonderlijke vervolgfases na grondbeoordeling.
