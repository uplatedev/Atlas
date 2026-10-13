# Achterwaarts voorvoetcontact — beperkte algebraïsche proef

De gangcorrectie vond een oudere achterwaartse posefout: het enkeldoel blijft achter het bekken, de voorwaartse kniepool buigt de knie en de begrensde enkel richt de teen door de vloer. Alleen het enkeldoel omhoog duwen verhelpt dat niet betrouwbaar. Deze proef staat los van de spelcode en menselijke gangacceptatie; hij is nog geen Godot-/meshoplossing.

In het sagittale vlak worden het onderbeen en de geroteerde enkel→voorvoetvector bij een toegestane relatieve enkelhoek q tot één effectief segment w gecombineerd:

`w = (0, -onderbeenlengte) + R(q) * (voorvoetlengte, -enkelhoogte)`

Los heup→knie→voorvoet met de gewone analytische tweebotsconstructie op, met de lengte van w. Corrigeer de kniegrenzen eerst voor de hoek tussen w en het echte onderbeen. Roteer het gevonden segment terug en reconstrueer de echte enkel, voetpitch en knie. Onbereikbaar contact wordt afgewezen; het bewezen wereldpunt wordt niet verplaatst. Geen iteratieve zoeklus of wereldquery.

[Herhaalbare Node-proef](https://github.com/uplatedev/Atlas/blob/64fcf41a169eaad05b59f0d0672213db12a46038/docs/work/T-011/backward-forefoot-probe.mjs): voer `node docs/work/T-011/backward-forefoot-probe.mjs` uit vanaf de checkpointroot. Een optioneel tweede pad ontvangt JSON; standaard schrijft de proef niets. Vier bestaande beenverhoudingen, 720 synthetische combinaties per lichaam: 2.086 oplossingen en 794 afgewezen doelen. Grootste lengte-/contact-/gewone IK-terugoplossingsfout 7,42e-16m; kniegrenzen5–155 en15–100 graden en bestaande enkelgrenzen−45..20 blijven behouden. Dit bewijst alleen de algebra voor bereikbare doelen, niet dat alle bewegingen daarmee correct ogen.

De illustratie is geïnspireerd op een capture maar mist de echte rootvlucht-/lean-/bekkenoffsets. Daar wordt voorvoet−46,2mm op nul gebracht door de enkel tegelijk50,3mm hoger en24,4mm voorwaarts te reconstrueren. Dat getal is geen enginevergelijking. De huidige centrale zoolmarker benadert de mesh; soms blijft de resulterende wereldpitch fors. Nog nodig: 3D-bank/toe-out, echte skin-clearance, veilige contactoverdracht bij een richtingswissel en vergelijking van daadwerkelijke Godotposes op vier lichamen. Het gekozen botlokale voorvoetpunt moet daarvoor expliciet vaststaan.