# T-011 — Bijstappen bij stilstaand draaien

Aansluiting op het [Character-ontwerp](../T-011.md). Gebouwd vanaf bron `a39ce9574e1fa8e6a49b4f78139bde63cf59475e`, op `Smyl3z/T-011-bijstappen`, onder dezelfde T-011-claim. Dit is een afzonderlijk te integreren vervolg op de gebruikersfeedback dat benen kruisen bij stilstaand ronddraaien.

## Gebouwd

`turn_step_planner.gd` plant hoogstens één vrije voet tegelijk. Het hoofd kijkt eerst, de borst volgt een beetje (maximaal 16 graden); grotere richtingsverandering wordt met afwisselende voetlift en grondcontact opgelost. De andere voet blijft wereldvast. De vrije voet draait langs de buitenkant om de capsule, niet door het andere been. Bekken en voeten mogen kort visueel achter de snelle capsule-yaw blijven; de vertraging blijft begrensd en verdwijnt na stoppen of lopen. De logische kijkinvoer, camera, capsulemotor en motorpasindex blijven ongewijzigd.

Er is geen verzameling achterstallige stappen: na de huidige stap telt de actuele richting. Bij nieuwe loopinvoer draagt de bijstap zijn actuele voetpositie direct over aan de loopplanner. De visuele yaw sluit gedempt aan; de vrije voet wordt kort buiten het bestaande steunbeen begeleid. Zie de [gerichte overgangscorrectie](turn-transition.md). De eerste loopplaatsing begint bij de bereikte voetpositie. Bij stoppen begint een vrije voet eveneens bij zijn actuele positie, niet op een oud contact ver achter de capsule.

De presentatie gebruikt de bestaande maximaal twee lokale grondqueries per frame. Een geaccepteerd gesteund bijstapcontact vult `foot_contacts` en geeft `turn_step_landed` met een eigen `turn_step_index`; de centrale motorpas en vluchtfase worden niet aangepast. Contactaudio kan dit afzonderlijk consumeren. Dit checkpoint wijzigt geen audio, veer, loopstijl of motorplanner; die vervolgwijzigingen worden apart geïntegreerd.

In de bestaande Character-ingang staat onder **Body Profile > Bijstappen**:

- **Turn Step Duration:** standaard 0,15 s per vrije bijstap, instelbaar van 0,08 tot 0,40 s.
- **Turn Step Angle Degrees:** maximaal richtingsverschil tussen voeten, standaard 54 graden, instelbaar van 20 tot 70 graden. Kleiner geeft meer, kleinere stappen.

Deze velden worden tijdens spelen gelezen en volgen de bestaande onafhankelijke instance-profielen. Een nieuw model gebruikt dezelfde helper en gemeten beenverhoudingen.

## Technisch gecontroleerd

Godot **4.7.2.stable.official.ed1daf0bf**, Windows, echte Character/capsule, Artemis en drie testlichamen. De nieuwe `game/tests/procedural_turn_checks.gd` controleert hoofd-eerst, rechts/links 90/180 graden, doorlopend 360/720 graden, plots tegenrichting, starten met sprint in drie bijstapfasen en weer stoppen. De log in [turn-validation.txt](turn-validation.txt) bevat de meetwaarden van deze bronwijziging.

- Geen kruisframes, geen drift van een geplante voet, geen blijvende yaw-offset en geen doorlopende wachtrij na stoppen.
- Artemis: 180 graden in vijf bijstappen; grootste verplaatsing van een voetdoel tijdens stilstaand draaien 0,05551 m per physicsframe; voetlift 0,05972 m. De capsule blijft op dezelfde plek. Werkelijk geplante voeten blijven binnen 1 cm van hun wereldcontact.
- Eerste frame van lopen uit een draai blijft onder 0,10 m verplaatsing per voetdoel; sprint bereikt vervolgens meer dan 8 m/s. Over de hele sprint is de grootste bestaande voetdoelverplaatsing 0,26957 m; tijdens uitlopen 0,17533 m. Dit bewijst geen perfecte visuele overgang en wordt niet als nulbeweging gepresenteerd.
- Eigen contactserienummers lopen eenmaal op per geaccepteerde stap en wisselen links/rechts af. Hoogstens twee grondqueries per frame.
- Bestaande `procedural_presentation_checks`, `procedural_integration_checks` en `procedural_terrain_checks` slagen met deze helper. De laatste kleine aanscherping (gewone/stride-landing eerst normaal plaatsen voor idle-bijstappen overnemen) is daarna met de volledige nieuwe draaiproef op alle vier lichamen gecontroleerd.

Herhalen vanuit PowerShell met de lokale engineconfig:

```powershell
. ./tools/Atlas-Engine.ps1
$atlasEngine = Get-AtlasEngine
Invoke-AtlasEngine -Engine $atlasEngine -Arguments @('--headless', '--path', 'game', '--script', 'res://tests/procedural_turn_checks.gd')
```

De headless proeven bewijzen geen realtime beeldsnelheid of natuurlijk gevoel.

## Door de gebruiker beoordeeld

De wens hoofd, romp, dan bijstappen is bevestigd; deze concrete uitvoering is nog niet bekeken. Na integratie in de vaste testmap: blijf stilstaan, kijk een klein stuk links/rechts, draai vervolgens halve en volledige rondjes, keer plots om en ga direct lopen. Let op volgorde, anatomische rust en of de korte visuele volgvertraging prettig blijft. Dezelfde handelingen op de andere Characters controleren het gedeelde gedrag.

## Volgende stap

Parent integreert dit checkpoint met de afzonderlijke veer-/loopstijlwijziging, motorfasecorrectie en eigen bijstapgeluid. Daarna geïntegreerde controle en de gerichte menselijke proef; deze branch publiceert zelf geen main of lokale testmap.