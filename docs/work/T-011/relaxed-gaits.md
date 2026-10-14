# T-011 — Wandelen, joggen en vrijere poses

De gebruiker bevestigt drie verschillende gangen: Alt wandelt ontspannen, gewone invoer jogt en Shift behoudt de goedgekeurde sprint. Bestaande snelheden en opgeslagen instance-instellingen blijven bestaan: Artemis gebruikt 2/5/9 m/s vooruit. De wandelstijl volgt de lage armen, kleine voethef en rustige schouders uit de [bekeken wandelreferentie van Chris Kundzicz](https://www.instagram.com/chriskundziczart/reel/DYL6KfeObZC/). Er is geen videobestand gekopieerd of precieze timing uit afgeleid.

## Gebouwd

- Alt gebruikt een volledige gesteunde stapcyclus met lage, ontspannen armen. Joggen krijgt een tussenhouding met echte pasvlucht; sprint behoudt de bestaande actieve houding. Instelbare posemenging verzacht gangwissels zonder de besturing te vertragen.
- Zuiver zijwaarts gebruikt een kleine gezamenlijke hup, groter bij sprint. Diagonalen gebruiken de gekozen wandel-/jog-/renstijl langs de bewegingsas. Zie [richtingproef](direction-style.md).
- Hoofd en borst benutten hun reserve vóór grotere draaibijstappen. Eén steunvoet bewaart tijdelijk zijn richting; een comfortabele ongelijke eindstand mag blijven. Zie [bijstappen](quiet-turn.md).
- De knieslide zit lager op de kuiten, berekend uit echte botlengtes en kniegrens. Zie [slidebewijs](deep-slide.md).
- Subtiele ademhaling, knipperen en een incidentele visuele zucht hebben eigen timing per Character. Eén lichte helper, geen extra skeleteigenaar of meshwerk per frame. Zie [idle](idle.md).
- Gangwissels, snel omkeren en stoppen met een grote kijkdraai behouden echte steunpunten. Vrije doelen worden eenmaal vóór IK binnen het gemeten beenbereik gepland. Zie [overgangen](gait-transitions.md) en [bereik/doosproef](bereik-en-beenas.md).

De editoringang blijft Character.tscn. Stijlparameters staan op het lichaamsprofiel; besturing/capsule op de root. Oude interne namen lopen/sneak blijven voor opgeslagen instellingen bestaan; HUD en groepen heten joggen/wandelen. De pasvluchtcurve geldt voor jog/sprint/zijhup. Vooruit en diagonaal wandelen blijven gesteund. Editorvelden en twee instances blijven onafhankelijk instelbaar.

## Technisch gecontroleerd

Gecombineerde codebron **ffea07ecbf7643ae22670af6dbc6b514689e19ed**, Godot **4.7.2.stable.official.ed1daf0bf**, Jolt, 60 Hz. Na deze bron zijn alleen bewijs en documentatie toegevoegd.

- Import, hoofdscene en alle **24 suites PASS**. Bestaande besturing/camera/audio, vier lichaamsverhoudingen, echte enkel-/knie-/scheenmetingen, grondcontacten, plafonds, overgangen, input tijdens pasvlucht, curve-/profielisolatie en idle-cache zijn gecontroleerd. [Compacte uitvoer](relaxed-validation.txt).
- De goedgekeurde voorwaartse sprint blijft over **92.640 waarden** gelijk binnen **0,000000544**. Dit is een numerieke referentiecontrole, geen nieuw menselijk sprintoordeel.
- Richtingswissels: geen pin-drift/noodloslatingen; maximaal twee lokale voetqueries per tick. Nulcurve en plafond ieder 907 gesteunde wissels, vrije route 341 pasvluchten. De extra krappe-doosproef bewaart minimaal 7,99 cm werkelijke enkelafstand en maximaal 1,036 mm doelfout.
- Echte D3D12/Forward+-beelden bekeken: lage wandelarmen en kleine voethef, duidelijk actievere jog/sprint, smalle frontale wandeling. Hieronder enkele representatieve frames; zijhup, draai, slide en idle hebben aanvullende componentbeelden.

[Wandelen van opzij](relaxed-images/walk_side_2.png) · [Wandelen van voren](relaxed-images/walk_front.png) · [Joggen](relaxed-images/jog_side_2.png) · [Sprint](relaxed-images/sprint_side_2.png)

De echte frametijdproef gebruikt dezelfde eenvoudige vloer, RTX 5060 Ti, 1280×800, vsync uit, geen fixed-fps, 3 seconden opwarmen en 4 seconden meten per aantal. Geen andere Godot-processen tijdens de meting. Direct daarna is de behouden c041f65e-bron met hetzelfde script gemeten:

| Echte Artemis-instances | Nieuwe p95 / maximum | Oude c041f65e p95 / maximum |
| --- | --- | --- |
| 1 | 1,234 / 3,203 ms | 0,915 / 2,312 ms |
| 4 | 3,064 / 4,382 ms | 2,252 / 2,972 ms |
| 12 | 7,794 / 9,922 ms | 5,794 / 7,436 ms |

De nieuwe presentatie kost in deze proef circa 2 ms extra p95 bij twaalf Characters. Grondqueryaantallen zijn exact gelijk (8028 bij twaalf). Dit is een korte lokale meting, geen garantie voor een groot level of de laptop. [Nieuwe meting](relaxed-performance.json), [directe oude referentie](relaxed-performance-baseline.json). Menselijke vloeiendheid en prestaties op echte spelgeometrie blijven onderdeel van verdere beoordeling.

## Door de gebruiker beoordeeld

Grondslide c9aeabca en de voorwaartse sprintstijl d1196064 zijn eerder goedgekeurd. De nieuwe wandeling, zijhup, diagonale houding, lossere draaistappen, diepere slide en idle wachten op gericht oordeel. [Speel- en editorproef](ground-trial.md#gerichte-vervolgproef-na-c041f65e).

## Volgende stap

Publiceer dit gecontroleerde broncheckpoint en werk de schone vaste Atlas-map bij. De actuele publicatie-/overdrachtstatus staat op main in WORK. Beoordeel daar vooral Alt-wandelen, zijwaarts huppen en schuin sprinten; daarna draai, slide, idle en de editorvelden. Klimmen, ragdoll, overige traversal en LAN/Steam blijven de afgesproken afzonderlijke vervolgproeven na acceptatie van grondbeweging.
