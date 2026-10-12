# Character en lokale proef

Eén plaatsbare Character-scene als ingang voor naam, uiterlijk, movement, houdingen, springen en camera. Het goedgekeurde onderzoek staat in [T-003](../work/T-003.md); de eerste uitvoering in [T-004](../work/T-004.md) en verfijning na spelen in [T-005](../work/T-005.md). [WORK](../WORK.md) bewaart centrale status en bronversie; [TESTING](../TESTING.md) beschrijft herhaalbare controles. De nieuwe afstelling wacht opnieuw op menselijke beoordeling.

## Nieuwe proef: movement, hoofd en houdingen

WASD beweegt op de grond relatief aan de werkelijk bereikte lichaamsrichting. Bij beweging volgt het lichaam de hoofd-/camerarichting met zijn ingestelde draaisnelheid. Bij stilstand blijft het lichaam staan totdat de relatieve hoofdhoek groot wordt. Hoofddraai is relatief aan het lichaam begrensd: voorlopig ±85°, met zachte afremming vanaf 60°. Terugkijken reageert direct. De groene pijl toont het hoofd, geel het lichaam, blauw input en oranje de werkelijke beweging. Dit is voorlopig de koppeling voor een later apart bewegend hoofdmodel.

Ctrl kiest kruip en schakelt vanuit kruip terug naar staan; vanuit lig kiest Ctrl kruip. Z kiest lig, ook rechtstreeks vanuit staan; nogmaals Z bewaart lig. Spatie richt precies één houding op: lig → kruip → staan. Die druk veroorzaakt geen sprong; opnieuw spatie terwijl je staat springt. Een onpassende hogere vorm blijft geblokkeerd. Alt vasthouden is sneak en Shift vasthouden sprint; Alt heeft staand voorrang. De latere keuze tussen Ctrl vasthouden en aan/uit blijft vervolgwerk; voor deze proef is aan/uit bevestigd.

Kruip is een verticale capsule van 1.10 m; lig een horizontale capsule van 1.80 m lang en 0.70 m hoog. Automatisch verlagen vanuit handmatig staan kiest maximaal kruip. Alleen handmatig kruip geeft toestemming voor automatische lig bij een doorgang. Na voldoende vrije ruimte herstelt de eigen gewenste houding. Botsing begrenst ook de lange ligcapsule tijdens draaien. Kruip/lig hebben geen sprong; spatie richt op. Sneak heeft een lage sprong van 0.45 m, met een instelbare minimumhoogte.

Instellingen blijven op de Character-root, met eigen Nederlandse uitleg per veld:

| Groep | Zelf af te stellen |
| --- | --- |
| Lopen / Sprint / Sneak | Snelheid, zij-/achterwaartse verhoudingen, acceleratie, afremming en draaisnelheid |
| Kruipen / Liggen | Eigen beweging, opstap, capsulehoogte/-lengte, radius en ooghoogte |
| Draaien en tegensturen | Stilstand-/luchtdraai, start-/stophoek voor noodzakelijk bijdraaien en extra remmen bij tegengestelde input |
| Springen | Vier hoogteprofielen, extra sprintbonus, onafhankelijke luchtacceleratie, zwaartekracht, randtolerantie en landingsbuffer |
| Sprongvermoeidheid | Aan/uit, kosten, grondherstel en minimumkracht per sprongtype |
| Botsing en automatisch herstellen | Staande capsule, opstap, vrije-ruimtemarge en herstelstabiliteit |
| Camera: kijken en hoofd | X/Y-gevoeligheid, hoofd-yawgrens, zachte zones, verticale grenzen en beginkijkhoek |
| Camera: zoom en botsing | Afstanden, zoomstap, first-personovergang, camera-volume en veilige volgingstijden |
| Camera: positievolging | Subtiele positievolging voor beide views en maximale achterstand; 0 schakelt de extra vertraging uit |
| Camera: beeldhoek | Verticale FOV voor beide views, sprintbonus, offsets voor sneak/kruip/lig en overgangstijden |

De gedeelde vermoeidheid wordt groter na geslaagde sprongen en herstelt uitsluitend op de grond. Herhaald springen geeft lagere sprongen en minder extra sprintafstand. Gewone loopsnelheid blijft gelijk. Een sprongbonus kan ook met vermoeidheid uit nooit opnieuw op de vorige bonus stapelen. De debug toont krachtverlies en het vastgelegde snelheidsbudget.

F4 schakelt de dynamische FOV van de actieve instance aan/uit voor vergelijking; F3 schakelt debug. De camera bewaart gewenste zoom los van muurbotsing. Positievolging is subtiel en instelbaar; kijken reageert direct. First person verbergt alleen de eigen capsule/naam; andere instances blijven zichtbaar.

De nieuwe `PostureTestArea` staat als normale levelinstance in `PrototypeLevel.tscn`. Route 1 rond x=-6 heeft een kruipopstap en opvolgende ligdoorgang; route 2 rond x=-12 een directe lage ingang; rechts staan een onmogelijke doorgang, smalle ligbocht en rembaan. Selecteer gewone blokken/CollisionShape3D in de editor om afmetingen samen te veranderen. De bestaande metertextures, twee lampen en sky blijven onderdeel van de arena.

## Zelf content plaatsen en aanpassen

Open `game/scenes/main.tscn` en selecteer `Characters/AtlasA` of `AtlasB`. A gebruikt de proefdefaults; B heeft een andere naam, kleur, hogere snelheid, sterkere acceleratie/remming en andere draaisnelheden. Wijzig eigenschappen op de Character-root. Botsingsvorm, mesh, materiaal, naam en camera worden per instance bijgewerkt. Gedeelde Resources mogen de tweede instance niet ongemerkt veranderen.

Plaats `game/characters/Character.tscn` onder `Characters`, of dupliceer een bestaande instance. Geef naam, positie en settings; de hoofdscene verzamelt directe Character-children automatisch voor Tab. F5 speelt de hoofdscene, F8 stopt. Een losse Character-scene heeft geen eigen proefvloer.

De stand-, kruip- en ligcapsules houden hun voetzool als grondanker. Totale capsulehoogte/-lengte omvat beide ronde uiteinden en moet minstens twee keer de radius zijn. Atlas behoudt de radius bij een onmogelijke verhouding en vergroot de maat tot dat minimum; de Inspector waarschuwt. Houd het bereik staan hoger dan kruip hoger dan lig. Ooghoogte en cameravolume worden veilig binnen de ruimte begrensd.

Vooruit > zijwaarts > achteruit is de standaardvolgorde voor iedere beweging. Twee inputs tellen geen snelheden op. Alle houdingen starten met opstapgrens 0.35 m; een eigen lagere grens kan een anders geldige trede voor die houding blokkeren. Opstappen is geen automatisch klimmen over hoge muren.

Een stilstaande sprong gaat hoog, een lopende middelhoog en een sprint laag maar extra ver. Werkelijke afzetsnelheid bepaalt het profiel, ook wanneer Shift net is losgelaten; een korte aanloop geeft minder afstand. Luchtinput bouwt geen volle sprint op vanuit een trage afzet. A/D en camerahoek sturen licht binnen het oorspronkelijke snelheidsbudget. Een geslaagde handmatige kruip-/ligkeuze tijdens de vlucht stopt horizontaal abrupt; verticale beweging blijft behouden. Eigen behoudfactor en luchtrem/sturing maken die precisiehandeling instelbaar. Sneak is een eigen lage sprong. Kosten en minimumkracht van sprongvermoeidheid staan als factoren: 0.25 is 25 procentpunten. Hersteltijd is grondtijd vanaf 100% vermoeidheid; een kleinere schuld herstelt evenredig sneller. Een nog niet herstelde reeks bewaart haar langzaamste herstelinstelling.

## Level en assets

`PrototypeLevel.tscn` en `PostureTestArea.tscn` gebruiken gewone editor-zichtbare meshes, CollisionShape3D en labels. Houd mesh- en botsingsmaten gelijk bij aanpassen. De hoofdscene instantieert het level en de Characters; daarvoor is geen netwerkhandeling nodig.

De vloer en muren gebruiken echte Kenney Prototype Textures. De volledige tile herhaalt per 2 m; twee hoofdvakken per tile betekenen 1 m per hoofdvak en 0.25 m per klein vak. De sunset is het ongewijzigde 2K Belfast Sunset (Pure Sky)-panorama van Poly Haven. Exact twee DirectionalLights: warm EdgeLight en koel FillLight. Licenties, hashes, brondownloads en schaal staan in [de assetuitleg op de proefbranch](https://github.com/uplatedev/Atlas/blob/Smyl3z/T-005-character-verfijnen/game/assets/README.md).

## Grenzen van deze proef

Dit is een lokale speel-/editorproef met één bestuurd Character tegelijk; Tab is de testhulp. Eigen camerarenderlayers ondersteunen voorlopig maximaal 19 Characters. Capsule en naam blijven zichtbaar voor andere Character-camera's. LAN, Steam, modellen en animatie zijn nog niet gebouwd. Een echte hoofdjoint kan later de afzonderlijke hoofd-/lichaamsrichting gebruiken.

Ligrotatie gebruikt een conservatieve controle langs het volledige draaipad. Bij vrijwel exact passende plafondhoogte kan die iets eerder blokkeren; de arena biedt 0.80 m vrije hoogte voor de 0.70 m ligvorm. Gevoel en editorbediening beoordeelt de gebruiker na de technische proef; zie WORK.
