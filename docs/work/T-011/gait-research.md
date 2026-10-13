# T-011 — Referenties en ritme vóór de pascorrectie

Onderzoek op 13 oktober 2026 na gebruikersfeedback op `458aa409`. Geen gameplayresultaat wordt hiermee geaccepteerd. Eigenaar blijft `atlas-T011-20261013-01a1340e`, STELLAR-FORGE Windows. D-049/D-050 leggen de beantwoorde keuzes vast. De bestaande capsule/presentatie-fundering en editoringang blijven behouden.

## Wat de bronnen laten zien

Wandelen gebruikt dubbele steun en beweegt rustig over het steunbeen; bij rennen zakt het lichaamszwaartepunt eerst tijdens opvang en volgt afzet naar vlucht. Bekkenhoogte is een visuele benadering, geen directe meting van het zwaartepunt. [Lee & Farley, oorspronkelijk onderzoek](https://journals.biologists.com/jeb/article/201/21/2935/7897/Determinants-of-the-center-of-mass-trajectory-in). De [BioMotionLab-wandelviewer](https://www.biomotionlab.ca/Demos/bmlwalker/) is werkelijk als bewegende lijnfiguur bekeken; hij helpt de losse arm-beenfasering en kleine tegengestelde rompbeweging beoordelen.

[Willer et al. 2024, tabel 1](https://onlinelibrary.wiley.com/doi/full/10.1111/sms.14690) meten elf getrainde mannen:

| Snelheid | Stappen/min, beide voeten geteld | Contact per voet | Vlucht tussen contacten |
| --- | --- | --- | --- |
| 2,78 m/s | 164 | 0,228 s | 0,139 s |
| 5 m/s | 180 | 0,162 s | 0,174 s |
| 8,33 m/s | 238 | 0,111 s | 0,142 s |

Dit zijn vergelijkingswaarden, geen universele Atlasdefaults. Hun tabel 3 toont bij versnellen vooral grotere kniebuiging tijdens herstel en meer voorwaartse kniehef. Steunafstand, heupextensie en hielherstel zijn verschillende dingen. Meer achterwaarts zichtbaar bereik mag niet alleen een verder achteruit gestrekt been betekenen. Vluchtduur groeit bij mensen niet onbeperkt met sprinttempo. Atlas behoudt de gevraagde begrensde groei als stilering; ritme, bereik en zwaartekracht moeten daarbij samen kloppen.

Een volledige voetcyclus is linkscontact tot volgend linkscontact; één links-rechtsstap is de helft. Bij rennen geldt staptijd = contactduur + vluchtduur. Bij gelijke grondhoogte is h = g × vluchtduur² / 8. Wandelen heeft overlappende voetsteun en vraagt een eigen contactverdeling. Onderzoeken kunnen niet blind worden gekopieerd: Artemis' boven-/onderbeenketen is 0,674 m en de motor gebruikt g=20 m/s². [Open wandeldata, inclusief 1,40 m/s](https://figshare.com/articles/dataset/Biomechanics_dataset_of_healthy_human_walking_at_various_conditions/16530939) bieden een passende snelheidsreferentie.

Wandelarmen zijn doorgaans langer/ontspannener, renarmen sterker gebogen; tegengestelde fasering helpt de rotatie door benen compenseren. [Yegian et al. 2019](https://pubmed.ncbi.nlm.nih.gov/31289110/), [Collins et al. 2009](https://pmc.ncbi.nlm.nih.gov/articles/PMC2817299/). Een contactpunt kan vast blijven terwijl hiel/voorvoet afrollen en de enkel beweegt; enkelvast is een te sterke beperking. [Onderzoek naar hielheffing](https://pmc.ncbi.nlm.nih.gov/articles/PMC11260980/).

De [officiële 20-seconden shuffle-instructie](https://www.dvidshub.net/video/558578/lateral-shuffle) is in de browser afgespeeld: gebogen knieën, borst omhoog, openen en aansluiten. Geen precieze timing uit beelden afgeleid. [Yamashita et al. 2017](https://pubmed.ncbi.nlm.nih.gov/28454909/) meten asymmetrische beenrollen met dubbele steun én vlucht. [Kuntze et al. 2009, pagina 6](https://www.jssm.org/volume08/iss1/cap/jssm-08-1.pdf#page=6) beschrijven opvang door de volgende voet, gewichtsverplaatsing naar de leidende voet en diens afzet. Bij opstart opent de leidende voet eerst; bij gevestigde snelle gallop kan de volgende voet juist als eerste na de vlucht landen. 9 m/s zijwaarts ligt buiten deze onderzochte shufflebereiken en blijft spelmatige stilering.

## Diagnose op de bestaande proef

De bestaande 210-tickmeting (3,5 s, inclusief versnellen) telt voor Artemis 11 wandel-, 17 jog- en 14 sprintcontacten. Dit is geen zuivere stationaire cadansmeting, maar bevestigt dat de jog vaker stapt dan de sprint. Steuntijd en vluchthoogte worden onafhankelijk gekozen. De presentatie vermengt voor jog grotendeels wandel-/sprintuitslagen; beide zijvoeten krijgen dezelfde hupfase. De enkel blijft vast tijdens steun. Geometrische bekkenverlaging en aparte contactcompressie komen bovenop capsulevlucht. Dat verklaart als werkhypothese de stijfheid en het trillen; alleen een hoogteparameter verlagen bewijst geen oplossing. Alle 24 oude technische suites slagen, maar toetsen geen menselijk overtuigend ritme.

## Uitvoering binnen de bevestigde scope

Eén gedeelde scheduler koppelt cadence, steun, vlucht en lichaamsbereik. Stijlgebonden contactfasen sturen voeten, bekken, borst en armen. Wandelen: korte dubbele steun, lage herstelvoet en kleine afrol. Jog: opvang op één been, compact opvouwen, gebogen actieve armen en één rustige afzetboog. Sprint: de bestaande sterke herstelstijl met gecontroleerde timing. Shuffle: onderscheiden leidende/volgende voet en afzonderlijke landingen, zonder kruisende doelen. Beperkte lokale grondmetingen en analytische IK blijven; geen spierfysica of wereldzoeksolver.

Controleer stationair ritme, volledige voetcycli, onafhankelijke voetcontacten, bereik en overgangen op vier verhoudingen. Bekijk op normale en vertraagde snelheid van opzij en voren. Publiceer een gecontroleerde speelproef op de werkbranch vóór de vaste map wordt bijgewerkt. Menselijk oordeel over wandelen, jog en shuffle blijft vereist; overige traversal/ragdoll en LAN blijven latere proeven.
