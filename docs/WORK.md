# Werk aan Atlas

Dit is het centrale overzicht. IDs blijven behouden; ideeën zijn geen opdrachten. De gepubliceerde versie op main is leidend. Reserveren en publiceren volgt [AGENTS](../AGENTS.md); herhaalbare controles staan in [TESTING](TESTING.md).

## Actuele focus

De gecontroleerde lege basis is gereed. De eerste Character-wensen, besturing en proefomgeving zijn besproken en vastgelegd. De volgende stap is de kleine lokale Character-/editorproef; er is nog geen Character-code gebouwd. LAN en Steam volgen na afzonderlijke afstemming over eigenaarschap en synchronisatie.

| ID | Taak | Status | Eigenaar/sessie | Machine | Werkbranch | Volgende stap |
| --- | --- | --- | --- | --- | --- | --- |
| T-000 | Projectbasis opzetten | Afgerond | atlas-bootstrap-20261012-01a12fd0 | STELLAR-FORGE (Windows) | `Smyl3z/T-000-projectbasis` (geïntegreerd; opruiming zie hieronder) | Geen inhoudelijk bootstrapwerk meer; vervolg in T-002 |
| T-001 | Character-fundering bespreken | Besproken en vastgelegd; afgerond | atlas-character-20261012-01a12fd0 | STELLAR-FORGE (Windows) | `Smyl3z/T-001-character-fundering` (lokale documentatiebranch; geheugen op main) | Uitvoering en beoordeling volgen in T-002 |
| T-002 | Lokale Character- en levelproef | Klaar voor uitvoering; nog niet gestart | Niet geclaimd | Nog niet bepaald | Nog niet aangemaakt | Claimen, kleine lokale proef bouwen en gericht laten beoordelen |

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

- **Gebouwd:** nog niets; alleen de beschreven fundering is beschikbaar.
- **Technisch gecontroleerd:** nog niet uitgevoerd. De gerichte [proefinstructies](TESTING.md#lokale-character-proef-nog-niet-gebouwd) liggen klaar.
- **Door de gebruiker beoordeeld:** de gewenste eigenschappen zijn besproken; editorbediening, cameragedrag, bewegen, sprongen en uiterlijk moeten na de bouw nog worden geprobeerd.
- **Volgende stap:** reserveer de taak vanaf actuele main, bouw de kleinste lokale proef en publiceer het controleerbare resultaat op de werkbranch. Vraag daarna gericht gebruikersoordeel; pas na noodzakelijke technische controles en menselijke beoordeling naar main.
