# Werk aan Atlas

Dit is het centrale overzicht. IDs blijven behouden; ideeën zijn geen opdrachten. De gepubliceerde versie op main is leidend. Reserveren en publiceren volgt [AGENTS](../AGENTS.md); herhaalbare controles staan in [TESTING](TESTING.md).

## Actuele focus

De lege basis controleren en publiceren; daarna samen de eerste Character-fundering bespreken. Er is geen toestemming om die onbesliste fundering alvast te implementeren.

| ID | Taak | Status | Eigenaar/sessie | Machine | Werkbranch | Volgende stap |
| --- | --- | --- | --- | --- | --- | --- |
| T-000 | Projectbasis opzetten | Technisch gecontroleerd; editorstart en publicatie afronden | atlas-bootstrap-20261012-01a12fd0 | STELLAR-FORGE (Windows) | `Smyl3z/T-000-projectbasis` | Editor openen, checkpoint publiceren en main-integratie verifiëren |
| T-001 | Character-fundering bespreken | Klaar voor bespreking; implementatie niet vrijgegeven | Niet geclaimd | Nog niet van toepassing | Nog niet aangemaakt | Antwoorden bespreken en eenvoudigste proef ter bevestiging voorstellen |

## T-000 — Projectbasis opzetten

Scope: volledige AGENTS.md, centraal projectgeheugen en lege werkende Godot-basis met open- en controlescript. Geen gameplay of netwerkcode. Opdracht: masterprompt van de gebruiker, 12 oktober 2026.

De exclusieve reservering is gepubliceerd op main in `1456f4123ee5a85f7e0402082a3132d784dcd00c`, vóór implementatie. Eigenaar blijft `atlas-bootstrap-20261012-01a12fd0`.

- **Gebouwd:** README, volledige AGENTS, zes contextdocumenten, bestaande Godot-bronnen onder game met één neutrale hoofdscene, exacte toolchain en twee gebruikersscripts met een kleine gedeelde proceshelper. Bestaande instellingen en bronmetadata behouden; lokale originelen staan buiten de bronhistorie in `.local/original/` op de uitvoerende computer.
- **Technisch gecontroleerd:** 12-10-2026, Godot `4.7.2.stable.official.ed1daf0bf`: echte import en headless-start geslaagd in Windows PowerShell 5.1 en PowerShell 7. Scripts parsen; lokale bestandslinks bestaan; AGENTS stemt overeen met de aangeleverde inhoud. Ontbrekende instelling/bestand, afwijkende versie en ongeldige hoofdscene geven exitcode 1. Paden met spaties en starten vanuit een andere werkmap werken. Native exitcode 7 wordt afgewezen. Genegeerde caches/configuratie/builds gecontroleerd; import-/UID-bronmetadata blijven zichtbaar. Bron: de game- en tools-inhoud van dit bootstrapcheckpoint; de concrete gepubliceerde hash wordt na publicatie toegevoegd.
- **Door de gebruiker beoordeeld:** nog geen gameplay of editorbediening beoordeeld. Deze lege basis voert geen onbesliste spelkeuze in; publicatie ervan is expliciet opgedragen. Een latere menselijke Character-proef blijft noodzakelijk.
- **Volgende stap:** editorstart verifiëren, deze gecontroleerde basis publiceren, bronversie en uiteindelijke status vastleggen; dan T-001 bespreken.

### Publicatieroute en werkplek

De GitHub-koppeling `uplate` is geverifieerd als `uplatedev` met schrijf- en beheerrechten op `https://github.com/uplatedev/Atlas`. Main is niet beschermd en er waren geen repositoryregels die normale publicatie blokkeren. Instellingen zijn niet veranderd. De lokale GitHub CLI was bij controle aangemeld als `Smillesii55`; dat is geen Atlas-schrijfroute in deze uitvoering.

Publicatie gebeurt via GitHub Git-data: bomen/commits en ref-updates met `force: false` en gecontroleerde vorige SHA. Dat bewaart dezelfde fast-forward-eis als een gewone Git-push. Daarna wordt origin opnieuw gefetcht en gecontroleerd. De connector maakt eigen commitmetadata; lokale Git-auteur is afzonderlijk repo-lokaal ingesteld op Up Late met de noreply-identiteit van het geverifieerde account. Geen globale account- of Git-wijzigingen.

Bij aanvang was deze Atlas-map geen eigen Git-checkout; de bovenliggende Git-root hoorde bij de gebruikersmap en is ongemoeid gelaten. De bestaande Atlas-remote is opgehaald en een eigen checkout ingericht. Het beheerde worktree-hulpmiddel gebruikte nog de oude bovenliggende root en vond origin/main niet; daarom zijn fysieke Git-worktrees onder de lokale, genegeerde `.local/worktrees/` gebruikt.

## T-001 — Character-fundering bespreken

Vaststaand: twee Characters in dezelfde scene, individueel in de editor instelbare snelheid, acceleratie en deceleratie; later tegelijk op twee Windows-pc's, eerst LAN en vroeg daarna een beperkte Steamproef. Zie [CONCEPT](CONCEPT.md).

Open vragen voor de eerstvolgende bespreking:

1. Vanuit welke camera wil je de proef beleven: door de ogen van het Character, achter/om het Character, of van boven/opzij?
2. Hoe moet bewegen aanvoelen: direct en precies, of met merkbare opbouw en uitloop?
3. Wil je op elke pc één eigen Character met toetsenbord/muis bedienen, of wil je voor het testen ook eenvoudig lokaal tussen de twee kunnen wisselen?

Voorstel, nog niet bevestigd: één plaatsbare Character-scene met overzichtelijke instance-instellingen, eenvoudige botsingsbesturing en een afzonderlijke visuele voorstelling. Eerst de kleinste editor-/bewegingsproef; vóór LAN ook eigenaarschap en synchronisatie afspreken. De antwoorden bepalen camera, dimensie en precieze aanpak. Niet bouwen voordat de gebruiker de fundering heeft bevestigd.
