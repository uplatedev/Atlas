# Draaien, kijktempo en voetoverdracht

Vervolg op de [gangproef](gait-research.md) binnen T-011. De gebruiker meldt op 13 oktober 2026: rustig stilstaand omkijken voelt goed, zeer snel draaien verplaatst de voeten te ver zonder bijstap; lopend/rennend gebeurt dat minder. Hij vraagt het verband met staptempo per snelheid te onderzoeken.

## Wat menselijke metingen ondersteunen

[Earhart & Hong 2006](https://www.sciencedirect.com/science/article/abs/pii/S0361923005004600) onderzochten vrijwillig ter plaatse draaien bij drie snelheden. Hoofd, romp en daarna voet blijven de volgorde; bij snel draaien duren de eerste twee stappen samen korter. Dat ondersteunt een begrensd snellere bijstap bij een echte snelle lichaamsdraai, met behoud van de bestaande hoofd-/borstreserve.

[Madrid et al. 2024](https://www.frontiersin.org/journals/human-neuroscience/articles/10.3389/fnhum.2024.1269772/full) vonden bij loopbochten van 90, 180 en 360 graden ongeveer dezelfde cadans binnen dezelfde snelheidsconditie: normaal circa 113/111/112 stappen per minuut, langzamer circa 93/92/94. Grotere bochten hadden meer en kortere passen en minder voortgangssnelheid. Meer draaihoek betekent dus niet vanzelf een hogere cadans.

[Yamaguchi et al. 2017](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0179817) onderscheiden step en spin turns, met verschillende steunstrategieën. Hogere loopsnelheid vraagt meer zijwaartse wrijving/centripetale belasting. Een zoolpivot is een expliciete contactstrategie. Deze loopstudies bewijzen geen sprintinstellingen voor Atlas op 9 m/s.

## Broncontrole en technische vertaling

Op codebron 6f75c2d gebruikte de stilstaande planner een vaste 0,22 seconden per stap. Bestemming en doelhoek stonden tijdens de stap vast; hoeksnelheid werd niet gemeten. Tijdens voortbewegen staat deze planner uit. Bovendien behield presentatie een geplante contactrichting alleen bij niet-nul afrol: een vlakke voet kon met de lichaamsbasis roteren zonder bijstap of expliciete pivot.

De eerste concrete correctie bewaart de oriëntatie van iedere geplante zool, ook bij afrol nul. Expliciete draaibijstappen blijven hun eigen vrije voet bewegen. Daarna gebruikt stilstaand draaien gefilterde werkelijke lichaamsdraaisnelheid en resterende hoek voor een begrensde kortere bijstap; kleine blikjes houden de goedgekeurde torsoreserve en asymmetrische ruststand. Dit is een afstelling van de bestaande visuele planner, zonder wijziging aan capsule, massa of momentum.

Tijdens WALK/JOG/SPRINT blijft de fysieke motorfase leidend. Een vervolgaanpassing moet eerst voorspelde draai tot het volgende contact benutten bij plaatsing van de vrije voet. Alleen blijvend te grote hoek per stap rechtvaardigt beperkte timingcorrectie op een echte voetwissel. Geen extra contact tijdens vlucht en geen directe verhouding muissnelheid → cadence. Voorspellende plaatsing en aanvullende cadanscorrectie zijn nog voorstellen. Wel gebouwd: de bestaande vrije-voetbewaking geldt voor alle bewegende gangen, nieuwe contactdoelen blijven aan de juiste kant van de andere steunvoet, oude dubbele steun wordt pas na echte nieuwe steun losgelaten en richtingwissels behouden contactinformatie. Dit herstelt kruisings-/bereikveiligheid zonder extra klok of grondmetingen. Abrupte voetovergangen blijven OPEN; vaste contactpunten bewijzen geen vloeiende vrije voetbaan.

## Gerichte proef

Vergelijk dezelfde 90/180 graden draai rustig en snel bij stilstand en bij 1,4/3/9 m/s. Controleer echte zoolpunten en oriëntatie, hoek per contact, afzonderlijke landingen en behouden motorfase. Bekijk vervolgens of snelle bijstappen de draai leesbaar dragen zonder trappelen. Menselijke beoordeling blijft vereist; verdere locomotiedraaitiming wordt niet op basis van brononderzoek alleen geaccepteerd.
## Bestaande lichaamsbegrenzing samen met de pose

De gebruiker stelt aansluitend voor de bestaande snelheidsafhankelijke lichaamsdraailimiet samen met de houding te gebruiken: wat voeten en romp niet overtuigend kunnen dragen, blijft begrensd. De motor had al jog540°/s, aflopend naar sprint300°/s, en Alt420°/s. Gewone sprong/val gebruikt air180; echte pasvlucht bewaart de bijbehorende grondsturing. Niet iedere snelheid heeft dus dezelfde draaihoek gedurende een contact.

Een parameterproef op de26635 vergelijkt dezelfde bestaande moving_turn- en muur/landing-oracles bij drie afstellingen. Grootste voetverplaatsing in één physics-tick na aftrek van capsuletranslatie, over vier lichamen:

| Alt / jog / sprint °/s | WALK vrij / contact cm | JOG vrij / contact cm | Sprint vrij / contact cm |
| --- | --- | --- | --- |
| 420 / 540 / 300 | 31,8 / 32,2 | 20,0 / 19,0 | 28,1 / 63,1 |
| 240 / 360 / 240 | 30,8 / 23,1 | 17,8 / 19,8 | 15,2 / 2,4 |
| 180 / 300 / 240 | 31,2 / 19,0 | 17,5 / 19,0 | 16,2 / 2,4 |

Alle gevallen behouden de bestaande contact-, kruis-, bereik- en querygrenzen. Geen faseterugsprong, extra impactlanding of versnelling buiten het bestaande budget. De eerste rechte60ticks houden capsule/fase/doelen gelijk binnen5,33e-15. De ruime sprintbocht behoudt in deze route meer vaart (minimum5,51→6,93m/s) doordat minder tegenrem nodig is. [Compacte meetuitvoer](turn-cap-comparison.json).

De gematigde afstelling240/360/240 is gekozen als nieuwe proefdefault binnen de bestaande instellingen; instance-overrides blijven behouden. De hoofdscene-B heeft bewust eigen hogere snelheden en draailimieten. Stilstaande hoofd-/borstreserve en idle-draailimiet veranderen niet. Verdere vertraging geeft weinig extra winst en kan de vrije voetbaan verslechteren. Dit is een reviewbare afstelling, geen door onderzoek bewezen ideale waarde of door de gebruiker geaccepteerd draaigevoel.

OPEN: verschillende maxima ontstaan al bij de eerste rechte landing vóór iedere cameradraai. Op Artemis blijft JOG-contact16,9cm en WALK-contact14,8cm in de gematigde proef; de draailimiet repareert die doeloverdracht niet. Een kleine vervolgproef kan één landingsbaan per vrije voet bewaren, uit de werkelijk bereikte positie en bestaande fase, met korte voorspelling vanuit de reeds begrensde capsulebeweging. De contactoverdracht neemt dan hetzelfde voorbereide doel over in plaats van een nieuw doel te berekenen. Bereik-/scheidingscorrecties gaan vóór die baan. Dit voorstel is nog niet gebouwd; geen extra motorfeedback, klok of ray. Onhaalbare late omkeringen mogen geen vaste pin verplaatsen of een contact stilzwijgend vervroegen.
