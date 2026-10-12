# Werk aan Atlas

Dit is het centrale overzicht. IDs blijven behouden; ideeën zijn geen opdrachten. De gepubliceerde versie op main is leidend. Reserveren en publiceren volgt [AGENTS](../AGENTS.md); herhaalbare controles staan in [TESTING](TESTING.md).

## Actuele focus

De eerste lokale Character-/editorproef is gebouwd en technisch gecontroleerd op de T-002-werkbranch. De volgende stap is de proef in de vaste Atlas-map spelen en de editorinstellingen beoordelen. LAN en Steam volgen na afzonderlijke afstemming over eigenaarschap en synchronisatie.

| ID | Taak | Status | Eigenaar/sessie | Machine | Werkbranch | Volgende stap |
| --- | --- | --- | --- | --- | --- | --- |
| T-000 | Projectbasis opzetten | Afgerond | atlas-bootstrap-20261012-01a12fd0 | STELLAR-FORGE (Windows) | `Smyl3z/T-000-projectbasis` (geïntegreerd; opruiming zie hieronder) | Geen inhoudelijk bootstrapwerk meer; vervolg in T-002 |
| T-001 | Character-fundering bespreken | Besproken en vastgelegd; afgerond | atlas-character-20261012-01a12fd0 | STELLAR-FORGE (Windows) | `Smyl3z/T-001-character-fundering` (lokale documentatiebranch; geheugen op main) | Uitvoering en beoordeling volgen in T-002 |
| T-002 | Lokale Character- en levelproef | Gepubliceerd en lokaal klaar; gebruikersproef en acceptatie open | atlas-T002-20261012-01a12fd0 | STELLAR-FORGE (Windows) | `Smyl3z/T-002-character-proef` | Gevoel en editorbediening laten beoordelen |
| T-003 | Movement, camera en houdingen onderzoeken | Gereserveerd; onderzoek en voorstel vóór gameplaywijzigingen | atlas-T003-20261012-01a12fd0 | STELLAR-FORGE (Windows) | `Smyl3z/T-003-movement-camera-onderzoek` | Primaire bronnen onderzoeken, bunnyhop reproduceren en concrete voorstellen voorleggen |

## T-000 — Projectbasis opzetten

Scope: volledige AGENTS.md, centraal projectgeheugen en lege werkende Godot-basis met open- en controlescript. Geen gameplay of netwerkcode. Opdracht: masterprompt van de gebruiker, 12 oktober 2026.

De exclusieve reservering is gepubliceerd op main in `1456f4123ee5a85f7e0402082a3132d784dcd00c`, vóór implementatie. Eigenaar blijft `atlas-bootstrap-20261012-01a12fd0`.

- **Gebouwd:** README, volledige AGENTS, zes contextdocumenten, bestaande Godot-bronnen onder game met één neutrale hoofdscene, exacte toolchain en twee gebruikersscripts met een kleine gedeelde proceshelper. Bestaande instellingen en bronmetadata behouden; lokale originelen staan buiten de bronhistorie in `.local/original/` op de uitvoerende computer.
- **Technisch gecontroleerd:** 12-10-2026, Godot `4.7.2.stable.official.ed1daf0bf`: echte import en headless-start geslaagd in Windows PowerShell 5.1 en PowerShell 7. Scripts parsen; lokale bestandslinks bestaan; AGENTS stemt overeen met de aangeleverde inhoud. Ontbrekende instelling/bestand, afwijkende versie en ongeldige hoofdscene geven exitcode 1. Paden met spaties en starten vanuit een andere werkmap werken. Native exitcode 7 wordt afgewezen. Genegeerde caches/configuratie/builds gecontroleerd; import-/UID-bronmetadata blijven zichtbaar. Ook grafische editor en runtime startten zonder fouten met D3D12/Forward+; Open-Atlas startte de editor en rondde met exitcode 0 af. De vensterkoppeling leverde geen betrouwbare visuele inspectie; die wordt niet als geslaagd geclaimd. Gepubliceerde bron: `26abbb2da67a88deb5fb2628aaa204396c6e2915`, exact vergeleken met de gecontroleerde bronboom `f2a948017cd90e72ae231f8f7748b7108fab55cf`. Deze integratie wijzigt daarna alleen dit statusdocument.
- **Door de gebruiker beoordeeld:** nog geen gameplay of editorbediening beoordeeld. Deze lege basis voert geen onbesliste spelkeuze in; publicatie ervan is expliciet opgedragen. Een latere menselijke Character-proef blijft noodzakelijk.
- **Volgende stap:** T-001 bespreken. De gebruiker kan de lege scene bekijken met Open-Atlas en F5; er is nog geen Character-ervaring om te beoordelen.

### Publicatieroute en werkplek

De GitHub-koppeling `uplate` is geverifieerd als `uplatedev` met schrijf- en beheerrechten op `https://github.com/uplatedev/Atlas`. Main is niet beschermd en er waren geen repositoryregels die normale publicatie blokkeren. Instellingen zijn niet veranderd. De lokale GitHub CLI was bij controle aangemeld als `Smillesii55`; dat is geen Atlas-schrijfroute in deze uitvoering.

Publicatie gebeurt via GitHub Git-data: bomen/commits en ref-updates met `force: false` en gecontroleerde vorige SHA. Dat bewaart dezelfde fast-forward-eis als een gewone Git-push. Daarna wordt origin opnieuw gefetcht en gecontroleerd. De connector maakt eigen commitmetadata; lokale Git-auteur is afzonderlijk repo-lokaal ingesteld op Up Late met de noreply-identiteit van het geverifieerde account. Geen globale account- of Git-wijzigingen.

Bij aanvang was deze Atlas-map geen eigen Git-checkout; de bovenliggende Git-root hoorde bij de gebruikersmap en is ongemoeid gelaten. De bestaande Atlas-remote is opgehaald en een eigen checkout ingericht. Het beheerde worktree-hulpmiddel gebruikte nog de oude bovenliggende root en vond origin/main niet; daarom zijn fysieke Git-worktrees onder de lokale, genegeerde `.local/worktrees/` gebruikt.

Opruiming: de geïntegreerde remote-werkbranch kan veilig worden verwijderd na controle van zijn actuele head en main-integratie. De huidige connector biedt geen branchverwijdering; lokale Git/CLI heeft alleen het andere account en de in-app-browser is niet aangemeld. Daarom blijft deze branch voorlopig als geïntegreerd checkpoint staan. Gebruik later een geverifieerde uplatedev-route voor uitsluitend deze branch. Dit blokkeert het gebruik van de gepubliceerde main-basis niet.

## T-001 — Character-fundering bespreken

De documentatie-/besprekingstaak is gereserveerd in main-commit `28f7ad14515a17e40d5b13a9686831d8ea52f006` onder `atlas-character-20261012-01a12fd0`. Bron: gebruikersbericht en vervolgantwoorden op 12 oktober 2026. Dit checkpoint verwerkt het gedeelde geheugen; het implementeert geen gameplay.

- **Gebouwd:** inhoudelijke documentatie voor Character en proeflevel in [topics/character.md](topics/character.md), met duidelijke scheiding tussen bevestigde ervaring en eenvoudige technische uitvoering. CONCEPT, DECISIONS en TESTING zijn bijgewerkt; game/tools zijn ongewijzigd.
- **Technisch gecontroleerd:** documentinhoud op onderlinge samenhang en lokale links gecontroleerd; assetkandidaten tegen officiële bronnen gecontroleerd. Er is geen nieuwe engineproef uitgevoerd voor deze documentatiewijziging en er zijn nog geen Character-testresultaten.
- **Door de gebruiker beoordeeld:** capsule, instelbare naam, third-personcamera met instelbare zoom tot first person, eigen zicht vrij van de capsule, WASD/muis/Shift/spatie en meedraaiende horizontale richting vastgelegd. Vooruit > zijwaarts > achteruit bevestigd; sprint in alle richtingen met lagere zij-/achterwaartse snelheden. Beperkte luchtsturing en de werkelijke afzetsnelheid als basis voor de sprong bevestigd. De richtingdebug, instelbare opstap, drie sprongkarakters, echte prototype-textures, twee edge-/fill-lampen en sunset-skybox komen uit de gebruikerswensen. Er is nog geen speelgevoel beoordeeld.
- **Volgende stap:** T-002 uitvoeren. Geen resterende funderingsvraag voor de eerste lokale proef; exacte waarden worden instelbare defaults en daarna op gevoel afgestemd. Netwerkeigenaarschap, spawnen en synchronisatie blijven een aparte bespreking vóór LAN.

## T-002 — Lokale Character- en levelproef

Scope: twee plaatsbare, individueel instelbare capsules volgens [de Character-beschrijving](topics/character.md), met naam, loop-/sprintinstellingen, begrensde gecombineerde input, richtingdebug, opstap, drie snelheidsafhankelijke sprongkarakters, beperkte luchtsturing en zoomcamera tot first person. Daarbij een klein meetbaar prototypelevel met echte rastertextures, twee lampen en sunset-skybox. Geen LAN, Steam, IK of klimarchitectuur in deze eerste stap.

Oplevering: zet ieder testbaar checkpoint volgens [de lokale testwerkwijze](TESTING.md#vaste-lokale-testplek) klaar in de vaste Atlas-checkout. Alleen een remote-branch of verwijzing naar een tijdelijke worktree is geen volledige lokale testoverdracht. Houd die versie tijdens de gebruikersproef vast en bewaar diens eigen editorwijzigingen.

De reservering is gepubliceerd op main in `63e9b0b42199041d2493c36bd01d6d80d88e5ef5`, eigenaar `atlas-T002-20261012-01a12fd0`, vóór implementatie. Controller, level/assets en integratie zijn in afzonderlijke fysieke worktrees gebouwd onder deze claim; de subbranches zijn lokale onderdelen van deze taak.

Gepubliceerd proefcheckpoint: [`c23038f4a97836773fbcbfe897b82b4b9e141e77`](https://github.com/uplatedev/Atlas/commit/c23038f4a97836773fbcbfe897b82b4b9e141e77), werkbranch `Smyl3z/T-002-character-proef`. De daadwerkelijke vaste Atlas-checkout op STELLAR-FORGE staat op exact die commit via de lokale testbranch `Smyl3z/lokaal-testen`; game/tools/bronnen zijn vergeleken met de remote. De volledige import/start/physicsuite is daar opnieuw foutvrij uitgevoerd, inclusief de laatste cameramargecorrectie. Lokaal HUD-bronmetadata is na publicatie gegenereerd en genegeerd. Andere pc niet automatisch bijgewerkt. Main bevat deze status/documentatie, niet de nog te beoordelen gameplay.

- **Gebouwd:** `game/characters/Character.tscn` als editoringang met eigen naam/kleur/Resources, lopen en sprint in alle richtingen, onafhankelijke acceleratie/afremming, drie sprongankers op werkelijke afzetsnelheid, beperkte luchtsturing, veilige opstap, zoom tot first person en richtingpijlen. De hoofdscene bevat twee verschillend ingestelde instances, HUD en Tab-wisseling. Nieuwe directe Character-instances onder `Characters` doen automatisch mee. Prototypelevel met echte Kenney-rastertextures op meterschaal, twee lampen, 2K Belfast Sunset-sky, vier treden en plafondproef. Bronnen/licenties/hashes staan in game/assets/README.md.
- **Technisch gecontroleerd:** Godot `4.7.2.stable.official.ed1daf0bf` importeert en start de geïntegreerde scene foutvrij. De echte physicsuite meet lopen vooruit/zijwaarts/achteruit/diagonaal op 5.000/4.000/2.750/4.417 m/s en sprint op 9.000/7.200/4.950/7.951 m/s. Gemeten spronghoogtes 2.075/1.309/0.744 m en afstanden 0/3.667/7.700 m voor stilstand/lopen/sprint. Trede 0.30 m passeert bij opstapgrens 0.35 m; 0.45 m en onvoldoende hoofdruimte blokkeren. Instance-Resources, naamwijziging, camera-maskers, zoomgrenzen en reset zijn gecontroleerd. Grafische Windows-renders met D3D12/Forward+ tonen echte hoofdscene en vrij first-personzicht. Documentlinks en bronmetadata worden bij publicatie gecontroleerd. Dit verslag hoort bij het proefcheckpoint; de definitieve gepubliceerde broncommit staat in de overdracht/main-status en wordt lokaal na publicatie in de HUD geladen.
- **Door de gebruiker beoordeeld:** eigenschappen en fundering zijn bevestigd; nog geen speelgevoel of daadwerkelijke editorbediening door de gebruiker beoordeeld. Richtingsdebug, raster, naamlabels en lichtbeeld zijn technisch/rendermatig bekeken. Het resultaat blijft op de werkbranch totdat noodzakelijk gebruikersoordeel rond is.
- **Volgende stap:** laat de gebruiker de klaargezette proef spelen en de twee instances zelf aanpassen. Verwerk daarna gericht feedback; geen nieuwe afhankelijke netwerkfase starten vóór die beoordeling.

### Eerste menselijke proef

Open `game/project.godot`, vervolgens `scenes/main.tscn`, druk F5. Begin met WASD en Shift, spring vanuit stilstand/lopen/sprint, scroll helemaal in en terug, wissel met Tab en vergelijk rustig/vlot. R zet beide terug; Esc maakt de muis vrij. Selecteer in de editor `Characters/AtlasA` en `AtlasB`, wijzig alleen de eerste naam of loopsnelheid en controleer dat de tweede gelijk blijft. Probeer rechts de treden met labels; links staat de lage-hoofdruimteproef.

Nog nodig: oordeel over acceleratie/afremmen, de hoge/middel/lage-verre sprong, beperkte luchtsturing, cameragevoeligheid/zoom, leesbaarheid en de Inspector-ingang. Numerieke defaults mogen na die proef bijgesteld worden. Maximaal 19 Characters voor de huidige lokale renderlayeraanpak; dit is een beperkte proef, geen bewezen LAN/Steam-oplossing.
