# Character en eerste proeflevel

Bron: gebruikerswensen en vier beantwoorde besturingsvragen op 12 oktober 2026. Centraal beleid: [CONCEPT](../CONCEPT.md), [besluiten](../DECISIONS.md) en [AGENTS](../../AGENTS.md). Status en eigenaarschap staan uitsluitend in [WORK](../WORK.md); herhaalbare proeven staan in [TESTING](../TESTING.md#lokale-character-proef-nog-niet-gebouwd).

Dit is de gewenste eerste proef en de eenvoudige voorgestelde uitvoering. Er is nog geen Character-scene, bewegingscode of level gebouwd.

## Door de gebruiker bevestigd

| Onderdeel | Gewenst gedrag |
| --- | --- |
| Vorm en naam | Voorlopig een capsule, met een eenvoudig instelbare naam boven het hoofd. |
| Camera | Begin in third person. Scrollen zoomt in/uit; zoominstellingen zijn aanpasbaar in de editor. Helemaal inzoomen kan naar first person, met vrij zicht door het eigen Character. |
| Besturing | WASD bewegen, muis kijken, Shift vasthouden voor sprint, spatie voor springen. Het Character draait mee met de horizontale camerarichting: A/D zijn zijwaarts en S is achteruit. |
| Lopen | Instelbare snelheid, acceleratie en afremming. Vooruit het snelst, zijwaarts ertussenin, achteruit het langzaamst. De onduidelijke oorspronkelijke vergelijking is door de gebruiker zo verduidelijkt. |
| Sprint | Eigen instelbare snelheid, acceleratie en afremming. Sprint mag ook zijwaarts en achteruit, met lagere snelheden dan vooruit. |
| Gecombineerde input | Twee inputs mogen snelheden niet bovenop elkaar zetten. Diagonaal bewegen levert geen snelheidsbonus op. |
| Debug | Richting bijhouden en zichtbaar maken in een debugweergave. |
| Opstappen | Instelbare hoogte voor over lage obstakels stappen. |
| Springen | Stilstand: hoge sprong. Lopen: middelhoge sprong. Sprint: lage sprong met extra afstand. De werkelijke snelheid bij het afzetten bepaalt de sprong, met beperkte luchtsturing. |
| Level | Twee lampen met edge-/fillfunctie. Vloeren én muren gebruiken echte prototype-textures met strepen/raster die afstand leesbaar maken. Geen strepen uit losse geometrie of een procedureel lijnenpatroon in de levelcode. Skybox rond zonsondergang. |

Alle Character-instellingen moeten per instance kunnen verschillen. De afgesproken proef houdt twee Characters in dezelfde scene; aan één instance wijzigen mag de andere niet veranderen.

## Eenvoudige uitvoering binnen deze fundering

Eén plaatsbare `Character.tscn` als herkenbare ingang, met eenvoudige botsingsbesturing, capsulepresentatie, naamlabel, camera en debug. Een `CharacterBody3D` met capsulebotsing is hiervoor het technische voorstel; geen IK, klimsysteem of fysieke lichaamssimulatie. De capsule maakt bewegingsgedrag snel testbaar en kan later een andere visuele voorstelling krijgen.

Voorgestelde Inspectorgroepen:

| Groep | Veilig te variëren instellingen |
| --- | --- |
| Naam | Weergavenaam, hoogte boven het hoofd, zichtbaarheid en leesbare labelgrootte |
| Lopen | Voorwaartse snelheid, zijwaartse/achterwaartse verhouding, acceleratie en afremming |
| Sprint | Eigen voorwaartse snelheid, zijwaartse/achterwaartse verhouding, acceleratie en afremming |
| Springen | Hoogte voor stilstand/lopen/sprint, extra horizontale sprintimpuls en beperkte luchtsturing |
| Botsing | Capsuleafmetingen en opstaphoogte |
| Camera | Beginafstand, maximale afstand, zoomstap, first-personovergang, ooghoogte, muisgevoeligheid en kijkgrenzen |
| Debug | Richtingsweergave en bewegingswaarden aan/uit |

Concrete waarden zijn afstelbare proefdefaults, geen door de gebruiker opgegeven getallen. Uitleg en eenheden moeten in de editor begrijpelijk zijn. De interne samenwerking en gedeelde assets mogen individuele instellingen niet ongemerkt koppelen.

### Beweging, richting en debug

Combineer input tot één begrensde bewegingsvector vóór de snelheid wordt bepaald. Pas daarop de richtingsafhankelijke limieten toe; tel geen aparte voorwaartse en zijwaartse snelheden bij elkaar op. Ook tijdens sprinten en richtingwissels geldt dit. Van sprint naar lopen gaat via de gekozen afremming naar de lagere limiet.

De debugweergave toont als uitvoeringsvoorstel de kijkrichting, gewenste invoerrichting, werkelijke horizontale bewegingsrichting, snelheid en loop-/sprint-/luchtstatus. Tijdens uitrollen kan de capsule nog bewegen zonder input; die twee richtingen moeten onderscheidbaar zijn. Een richtingpijl voorkomt dat de ronde capsule zijn oriëntatie verbergt.

### Camera en lokaal zicht

Gebruik één camera-opstelling met een instelbare afstand tot het Character en een scrollovergang tot ooghoogte. Voorkom dat de camera bij muren achter de geometrie terechtkomt. Bij first person verbergt alleen de eigen camera de eigen capsule en het eigen naamlabel, zodat die het zicht niet blokkeren. Andere Characters blijven zichtbaar; een latere tweede speler moet de eerste capsule nog gewoon kunnen zien. Botsing en bewegingsgedrag blijven gelijk bij zoomen. Dit is een lokale presentatiekeuze, geen gedeelde onzichtbaarheid of globale transparantiewijziging.

### Sprong en opstap

Bepaal het sprongprofiel uit de werkelijke horizontale snelheid bij afzetten, afgezet tegen zowel de loop- als sprintgrens voor die richting. Gebruik niet alleen de momenteel actieve snelheidslimiet: bij dezelfde werkelijke snelheid mag alleen Shift omschakelen geen ander sprongprofiel opleveren. Zo geeft Shift vanuit rust niet automatisch de lage sprintsprong, en kan ook een zijwaartse/achterwaartse sprint passend beoordeeld worden. Leg de afzetwaarden voor die sprong vast. Beperkte luchtsturing mag de boog bijsturen, maar niet halverwege het sprongtype vervangen of snelheid onbeperkt opstapelen.

Stilstand/lopen/sprint vormen drie instelbare ankerpunten voor hoogte en afstand; een overgang op basis van afzetsnelheid voorkomt een harde sprong bij minimale beweging. Bij sprint is zo nodig een extra horizontale afzetimpuls nodig: minder hoogte betekent minder vliegtijd en garandeert op zichzelf geen grotere afstand. Die bewuste sprongimpuls staat los van de verboden bonus door diagonale input.

Opstappen gebruikt een kleine gecontroleerde botsingsproef tot de ingestelde hoogte. Geen automatisch beklimmen van hoge muren; controleer ook vrije ruimte boven de capsule. De latere proef beoordeelt treden en randen rond de gekozen grens, inclusief lage plafonds.

## Prototypelevel en assets

De eerste levelopzet ondersteunt gericht meten: vlakke loopbanen, referentiemuren, enkele treden rond de opstapgrens en ruimte voor drie soorten sprongen. Dit is een proefomgeving, geen besluit over de uiteindelijke spelwereld.

Gebruik twee herkenbaar benoemde lampen: `EdgeLight` voor de rand/silhouet en `FillLight` om de schaduwzijde leesbaar te houden. De sunset komt uit de skybox; het voorstel voegt daarvoor geen derde zonlamp toe. Richt de edge-verlichting passend bij de sky. Kleur, intensiteit en plaatsing worden visueel beoordeeld.

Assetselectie wordt bij implementatie uit de officiële bronnen opgehaald en gecontroleerd. Voorkeur: een bestaand texturebestand met prototypepatroon en een panoramische sunset-sky. Geen in code of geometrie opgebouwde strepen. Stel de UV-schaal zo in dat een duidelijk hoofdvak een echte bekende wereldafstand voorstelt, bijvoorbeeld 1 meter; een plaatje met raster is op zichzelf nog geen afstandsmeting. Controleer vloeren én muren op dezelfde schaal en voorkom uitrekking op verschillende vlakafmetingen.

Gecontroleerde kandidaten uit officiële bronnen (12-10-2026):

- [Kenney — Prototype Textures](https://kenney.nl/assets/prototype-textures): bestaande prototype-gridtextures. De [officiële downloadpagina](https://kenney-assets.itch.io/prototype-textures) vermeldt 1024×1024 en CC0. Kies een rustige rastervariant en kalibreer de UV-schaal op echte wereldmaten; eventuele tekst/cijfers in het plaatje bewijzen de schaal niet.
- [Poly Haven — Belfast Sunset (Pure Sky)](https://polyhaven.com/a/belfast_sunset_puresky): sunset-panorama zonder gefotografeerd terrein in de achtergrond. HDR/EXR, onder de [CC0-licentie van Poly Haven](https://polyhaven.com/license). Voorstel: beginnen met 2K als skybox en alleen de twee afgesproken lampen gebruiken.

Definitieve assetbestanden, gebruikte varianten, licentie en bron worden bij import samen vastgelegd. In deze documentatiestap zijn nog geen textures of skybestanden gedownload of geïmporteerd.

## Volgorde van de proeven

Eerst de kleine lokale Character-/editorproef met twee verschillend ingestelde instances. Lokaal wisselen tussen de twee bestuurde instances is een praktische voorgestelde testhulp; tegelijk over het netwerk spelen hoort bij de volgende fase. Na technische controle beoordeelt de gebruiker bewegen, sprongen, camera en editorbediening. Vervolgens vóór LAN eigenaarschap, spawnen en synchronisatie afspreken; daarna de al afgesproken beperkte Steamcompatibiliteitsproef. Het level en lokale bewegen leggen geen nieuw netwerkframework vast.
