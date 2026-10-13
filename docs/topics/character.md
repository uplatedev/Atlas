# Character en lokale proef

Eén plaatsbare Character-scene als ingang voor naam, uiterlijk, movement, houdingen, springen en camera. Het goedgekeurde onderzoek staat in [T-003](../work/T-003.md); de eerste uitvoering in [T-004](../work/T-004.md) en verfijning na spelen in [T-005](../work/T-005.md). [WORK](../WORK.md) bewaart centrale status en bronversie; [TESTING](../TESTING.md) beschrijft herhaalbare controles. De nieuwe afstelling wacht opnieuw op menselijke beoordeling.

## Nieuwe proef: movement, hoofd en houdingen

Het aanvullende [juice-/architectuuronderzoek T-006](../work/T-006.md) inventariseert contactaudio, kleine camera-accenten, gerichte FOV-afstemming en separation of concerns. De tijdelijke capsule valt buiten die polishbeoordeling. Het verslag verandert de speelproef niet; effecten en eventuele kleine gameplaytuning zijn voorstellen.

De stapsgewijze uitvoering begint in [T-007](../work/T-007.md): CameraRig wordt de enige eigenaar van camera-uitvoering en -geheugen, met behoud van bestaande instellingen en hetzelfde gedrag. Contactaudio en aanvullende camera-accenten komen in afzonderlijke stappen.

WASD beweegt op de grond relatief aan de werkelijk bereikte lichaamsrichting. Bij beweging volgt het lichaam de hoofd-/camerarichting met zijn ingestelde draaisnelheid. Bij stilstand blijft het lichaam staan totdat de relatieve hoofdhoek groot wordt. Hoofddraai is relatief aan het lichaam begrensd: voorlopig ±85°, met zachte afremming vanaf 60°. Terugkijken reageert direct. De groene pijl toont het hoofd, geel het lichaam, blauw input en oranje de werkelijke beweging. Dit is voorlopig de koppeling voor een later apart bewegend hoofdmodel.

C kiest kruip en schakelt vanuit gewone handmatige kruip terug naar staan; vanuit lig kiest C kruip. Tijdens een actieve slide laat nogmaals C de slide uitlopen en kiest blijvend kruip na afloop. Tijdens alleen de voorbereiding annuleert C die voorbereiding. Z kiest lig, ook rechtstreeks vanuit staan; nogmaals Z keert veilig terug naar de houding vóór lig. Eén spatie brengt handmatig lig terug naar de eigen houding vóór lig: staan→lig→staan of kruip→lig→kruip. Die oprichtdruk veroorzaakt geen sprong; vanuit gewone kruip richt spatie op naar staan. Een onpassende hogere vorm blijft geblokkeerd. Tijdens actieve slide geeft een nieuwe spatie wél een echte sprong, met overgebleven vaart, bestaande hoogte/fatigue en zonder extra bonus. Vasthouden van eerdere spatie veroorzaakt geen herhaling. Alt vasthouden is sneak en Shift vasthouden sprint; Alt heeft staand voorrang. De latere keuze tussen C vasthouden en aan/uit blijft vervolgwerk; voor deze proef is aan/uit bevestigd.

Kruip is een verticale capsule van 1.10 m; lig een horizontale capsule van 1.80 m lang en 0.70 m hoog. Staande voorkeur mag automatisch kruipen, maar niet vervolgens liggen. Alleen bewust gekozen kruip mag automatisch lig worden. Na voldoende vrije ruimte herstelt de hoogste veilige houding, met behoud van een eigen handmatige lage voorkeur. Botsing begrenst ook de lange ligcapsule tijdens draaien. Kruip/lig hebben geen sprong; spatie richt op. Sneak heeft een lage sprong van 0.45 m, met een instelbare minimumhoogte.

Instellingen blijven op de Character-root, met eigen Nederlandse uitleg per veld. De slide-defaults zijn 0,75 s maximale duur, 10 m/s² wrijving, 35°/s sturing en 0,8 m/s einddrempel. Minder wrijving behoudt meer landingsvaart; meer duur geeft langer doorsliden:

| Groep | Zelf af te stellen |
| --- | --- |
| Lopen / Sprint / Sneak | Snelheid, zij-/achterwaartse verhoudingen, acceleratie, afremming en draaisnelheid |
| Kruipen / Liggen | Eigen beweging, opstap, capsulehoogte/-lengte, radius en ooghoogte; kruip-slidewrijving, duur, sturing en einddrempel |
| Draaien en tegensturen | Stilstand-/luchtdraai, start-/stophoek voor noodzakelijk bijdraaien en extra remmen bij tegengestelde input |
| Springen | Vier hoogteprofielen, extra sprintbonus, beperkte luchtacceleratie/-rem, minimumstuur-budget, zwaartekracht, randtolerantie en landingsbuffer |
| Sprongvermoeidheid | Aan/uit, kosten, grondherstel en minimumkracht per sprongtype |
| Botsing en automatisch herstellen | Staande capsule, opstap, vrije-ruimtemarge en herstelstabiliteit |
| Camera: kijken en hoofd | X/Y-gevoeligheid, hoofd-yawgrens, zachte zones, verticale grenzen en beginkijkhoek |
| Camera: zoom en botsing | Afstanden, zoomstap, first-personovergang, camera-volume en veilige volgingstijden |
| Camera: positievolging | Subtiele positievolging voor beide views en maximale achterstand; 0 schakelt de extra vertraging uit |
| Camera: subtiele nawerking | Aan/uit, maximale veeruitslag, hersteltijd, snelheidsdrempels en afzonderlijk first-persongebruik |
| Camera: beeldhoek | Verticale FOV voor beide views, sprintbonus, offsets voor sneak/kruip/lig, lucht-/slidevariant en overgangstijden |
| Camera: landing | Aan/uit, eigen TP-/FP-dip, impactsnelheden, aanzet-/hersteltijd en gezamenlijk budget voor remveer en landing |

De gedeelde vermoeidheid wordt groter na geslaagde sprongen en herstelt uitsluitend op de grond. Herhaald springen geeft lagere sprongen en minder extra sprintafstand. Gewone loopsnelheid blijft gelijk. Een sprongbonus kan ook met vermoeidheid uit nooit opnieuw op de vorige bonus stapelen. De debug toont krachtverlies en het vastgelegde snelheidsbudget.

F4 schakelt de dynamische FOV van de actieve instance aan/uit voor vergelijking; F3 schakelt debug, inclusief slide en luchtrem. De FPS-teller staat rechtsboven. De camera bewaart gewenste zoom los van muurbotsing. Positievolging is subtiel en instelbaar; kijken reageert direct. Snelle rembewegingen geven een heel klein instelbaar doorschietaccent: bij normale sprintstop circa 1,2 cm. First person heeft dat accent standaard uit en verbergt alleen de eigen capsule/naam; andere instances blijven zichtbaar.

De nieuwe `PostureTestArea` staat als normale levelinstance in `PrototypeLevel.tscn`. Route 1 rond x=-6 heeft een kruipopstap en opvolgende ligdoorgang; route 2 rond x=-12 een directe lage ingang; rechts staan een onmogelijke doorgang, smalle ligbocht en rembaan. Selecteer gewone blokken/CollisionShape3D in de editor om afmetingen samen te veranderen. De bestaande metertextures, twee lampen en sky blijven onderdeel van de arena.

## Zelf content plaatsen en aanpassen

Open `game/scenes/main.tscn` en selecteer een Character. A gebruikt Artemis, B lange bovenbenen en C lange onderbenen. B bewaart de eerdere eigen hogere bewegingdefaults. De procedurele instellingen en editorcurves staan in het lichaamsprofiel; zie [de concrete editorproef](../work/T-011/ground-trial.md). Wijzig eigenschappen op de Character-root. Botsingsvorm, mesh, materiaal, naam en camera worden per instance bijgewerkt. Gedeelde Resources mogen de tweede instance niet ongemerkt veranderen.

Plaats `game/characters/Character.tscn` onder `Characters`, of dupliceer een bestaande instance. Geef naam, positie en settings; de hoofdscene verzamelt directe Character-children automatisch voor Tab. F5 speelt de hoofdscene, F8 stopt. Een losse Character-scene heeft geen eigen proefvloer.

De stand-, kruip- en ligcapsules houden hun voetzool als grondanker. Totale capsulehoogte/-lengte omvat beide ronde uiteinden en moet minstens twee keer de radius zijn. Atlas behoudt de radius bij een onmogelijke verhouding en vergroot de maat tot dat minimum; de Inspector waarschuwt. Houd het bereik staan hoger dan kruip hoger dan lig. Ooghoogte en cameravolume worden veilig binnen de ruimte begrensd.

Vooruit > zijwaarts > achteruit is de standaardvolgorde voor iedere beweging. Twee inputs tellen geen snelheden op. Alle houdingen starten met opstapgrens 0.35 m; een eigen lagere grens kan een anders geldige trede voor die houding blokkeren. Opstappen is geen automatisch klimmen over hoge muren.

Een stilstaande sprong gaat hoog, een lopende middelhoog en een sprint laag maar extra ver. Werkelijke afzetsnelheid bepaalt het profiel, ook wanneer Shift net is losgelaten; een korte aanloop geeft minder afstand. Luchtinput bouwt geen volle sprint op vanuit een trage afzet. A/D en camerahoek sturen licht binnen het oorspronkelijke snelheidsbudget. Handmatig kruip/lig kiezen bewaart de vluchtvaart; tegeninput (S bij voorwaartse vlucht) remt geleidelijk en verlaagt ook het resterende snelheidsbudget. C tijdens een sprong bereidt de landingsslide voor. Een nieuwe C-druk tijdens staand sprinten start diezelfde slide direct bij veilige grond- of opstapsteun. Beide bewaren de actuele bewegingsrichting en vaart zonder boost. Gewoon lopen, stilstand, sneak, Z-lig en automatisch verlagen starten geen grondslide; een geblokkeerde poging wordt niet later uitgevoerd. Na slide automatisch staan als dat veilig past; onder een laag plafond blijft de capsule automatisch kruipen en richt later veilig op. De eerste slide-ingang legt geen blijvende kruipvoorkeur vast; een nieuwe C tijdens de actieve slide kiest die voorkeur voor na afloop. Een lage landing zonder slide gebruikt meteen de eigen kruip-/liglimiet. Wrijving, duur, sturing en einddrempel zijn onafhankelijk instelbaar; de nieuwste proef verlaagt wrijving en verlengt duur. Tegeninputrem staat op 8 m/s². Dit vervangt de eerste T-005-luchtstop. Sneak is een eigen lage sprong. Kosten en minimumkracht van sprongvermoeidheid staan als factoren: 0.25 is 25 procentpunten. Hersteltijd is grondtijd vanaf 100% vermoeidheid; een kleinere schuld herstelt evenredig sneller. Een nog niet herstelde reeks bewaart haar langzaamste herstelinstelling.

## Camera-accenten en vergelijking

[T-009](../work/T-009.md) voegt een kleine contactreactie en een afzonderlijke lucht-/slide-FOV-variant toe. F7 schakelt de landing van de actieve instance; F9 vergelijkt alleen de nieuwe FOV-mapping. F4 behoudt de eerdere vergelijking van alle dynamische FOV. De HUD toont de actieve keuzes. CameraRig bezit de effecten; fysieke contactdata sturen ze onafhankelijk van audio.

TP heeft maximaal 1 cm landingsdip, FP standaard 0. Het is één kort neerwaarts accent met rustig herstel, samen met de bestaande remveer begrensd tot 4 cm en met alle volglag binnen de bestaande totale 12 cm. De veilige camerasphere kan het effect verder beperken. Een geldige opstap en eerste spawncontact geven geen dip. De Inspector heeft eigen sterktes, impactdrempels, tijden en een schakelaar; nul sterkte schakelt verplaatsing eveneens uit.

Tijdens staan in de lucht blijft de oorspronkelijke afzetmix de bovengrens; afgenomen vaart neemt de FOV rustig terug, zonder nieuwe bijdrage uit de sprongbonus of cameradraaien. Actieve slides krijgen maximaal +3° TP / +1,5° FP boven kruipbasis, bij 9 m/s of meer. Onder die referentie neemt de bijdrage met de echte slidevaart af. Gewone kruip krijgt geen slidebonus. De bestaande FOV-overgangstijden blijven gelden; de refinement-schakelaar uit geeft de vroegere lucht-/slidemapping terug. Dit zijn afstelbare proefdefaults, nog geen beoordeeld ideaal gevoel.

## Contactaudio en vergelijking

[T-008](../work/T-008.md) voegt een eigen contactfeedbackcomponent toe. Stappen volgen echt afgelegde ondersteunde meters; W tegen een wand, stilstaande Shift en vlucht geven geen stappen. Sneak klinkt zachter; kruip/lig hebben zachte contactvarianten. Afzet klinkt alleen bij een geaccepteerde sprong. Landing gebruikt impact vóór de botsing; gewone opstapsteun krijgt geen dreun. Een C-landingsslide geeft één gezamenlijke aanzet; een grondslide geeft geen valse landing. Beide gebruiken dezelfde snelheidsafhankelijke schuurloop. Spatie uit slide, afloop, reset en audio uit stoppen die loop.

Selecteer dezelfde Character-root en open de Audio-groepen voor volume, vijf cadansen/profielsterktes, variatie, afzet/landing, slide en vervangbare samples. Eigen audio is onafhankelijk van camerazoom; anderen klinken ruimtelijk. F6 vergelijkt audio aan/uit voor de actieve instance en de HUD toont de keuze. Geluidsbestanden zijn gedeelde bronassets; de feedback maakt voor slide een eigen loopkopie. Settings, cadence en variatiegeheugen zijn per instance. Dit is een uniforme prototypeset zonder materiaalherkenning per vloer; nieuwe oppervlakken zijn nog geen systeem.

## Level en assets

`PrototypeLevel.tscn` en `PostureTestArea.tscn` gebruiken gewone editor-zichtbare meshes, CollisionShape3D en labels. Houd mesh- en botsingsmaten gelijk bij aanpassen. De hoofdscene instantieert het level en de Characters; daarvoor is geen netwerkhandeling nodig.

De vloer en muren gebruiken echte Kenney Prototype Textures. De volledige tile herhaalt per 2 m; twee hoofdvakken per tile betekenen 1 m per hoofdvak en 0.25 m per klein vak. De sunset is het ongewijzigde 2K Belfast Sunset (Pure Sky)-panorama van Poly Haven. Exact twee DirectionalLights: warm EdgeLight en koel FillLight. Licenties, hashes, brondownloads en schaal staan in [de assetuitleg op de proefbranch](https://github.com/uplatedev/Atlas/blob/Smyl3z/T-005-character-verfijnen/game/assets/README.md).

## Grenzen van deze proef

Dit is een lokale speel-/editorproef met één bestuurd Character tegelijk; Tab is de testhulp. Eigen camerarenderlayers ondersteunen voorlopig maximaal 19 Characters. Capsule en naam blijven zichtbaar voor andere Character-camera's. Artemis en eenvoudige proeflichamen gebruiken nu procedurele botposes; het hoofd volgt de afzonderlijke kijkrichting. LAN en Steam zijn nog niet gebouwd.

Ligrotatie gebruikt een conservatieve controle langs het volledige draaipad. Bij vrijwel exact passende plafondhoogte kan die iets eerder blokkeren; de arena biedt 0.80 m vrije hoogte voor de 0.70 m ligvorm. Gevoel en editorbediening beoordeelt de gebruiker na de technische proef; zie WORK.
