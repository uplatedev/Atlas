# T-011 — Terrein en momentum

Aanvulling op [motor](motor.md) en [T-011](../T-011.md). Proefbasis is geïntegreerde bron `2be5a56`, met Artemis, dezelfde contactframes, presentatie, camera en audio. Engine: Godot 4.7.2.stable.official.ed1daf0bf, Jolt, 60 Hz.

## Gebouwd

`game/tests/procedural_terrain_checks.gd` probeert voorwaarts, zijwaarts, achterwaarts en diagonaal lopen/sprinten, richtingomkeer, echte treden, 15° stijgen/dalen, een afgrond en lage plafonds vanuit vijf verschillende pasfasen. Hij controleert ook handmatige kruipvoorkeur na slidesprong en overgang van externe impulsvaart naar lopen, kruipen, slide en springen.

De proef reproduceerde een echte fout: bij bepaalde pasfasen verloor een Character tegen een geldige trede zijn volledige 5 of 9 m/s voordat de volgende grondframe hem alsnog optilde. Tijdens pasvlucht werd de bestaande veilige opstapcontrole overgeslagen. Bovendien kan een dalend capsuleframe eerst de vloer en daarna de trede raken; alleen horizontaal vooruit toetsen mist dat tweede contact.

De correctie laat uitsluitend lokaal geldige pasvlucht dezelfde veilige opstap gebruiken. De toegestane tredehoogte blijft gemeten vanaf de pasafzetvloer, zodat de pasvluchthoogte geen extra opstapbudget geeft. Een geaccepteerde opstap wordt een gesteunde voetwissel; geen fictieve sprong of impactlanding. De bestaande controle gebruikt tijdens pasvlucht maximaal drie korte capsulevoorspellingen: horizontaal, zo nodig de werkelijke framebeweging, en uitsluitend na voorspelde vloerlanding de resterende horizontale beweging. Gewone sprongen en vallen krijgen dit recht niet. Er is geen nieuwe zoeklus of onbeperkte probe.

## Technisch gecontroleerd

Na assetimport draaien met de vastgelegde engine:

```text
--headless --fixed-fps 60 --path game --script res://tests/procedural_terrain_checks.gd
--headless --fixed-fps 60 --path game --script res://tests/procedural_motor_checks.gd
--headless --fixed-fps 60 --path game --script res://tests/procedural_integration_checks.gd
```

Alle drie slagen op de terreinwijziging. Import/start slaagt eveneens.

- Acht richting-/snelheidscombinaties houden hun ingestelde snelheid; omkeren gebruikt begrensde profielremming. Werkelijke geplante enkelafwijking blijft onder 0,025 m, zonder vrijgave door overbereik.
- Twaalf trederoutes: 0,30 m met de standaard 0,35 m opstaplimiet en 0,45 m met expliciet 0,50 m limiet, beide bij lopen/sprinten en drie aankomstfasen. Voor correctie zakten tien routes kort tot 0 m/s. Na correctie is de minimale horizontale snelheid bij de trede exact 5,000 of 9,000 m/s; alle routes bereiken de bovenzijde.
- 0,40 en 0,45 m bij de standaard 0,35 m limiet blijven geblokkeerd. Geen automatische opstap; maximale pashoogte 0,0806 m. Bewuste sprong (53 luchtframes) en val (12 luchtframes) krijgen nul automatische lucht-opstappen.
- 15° helling op en af slaagt voor lopen en sprinten. Vijf plafondroutes komen aan op fasen 0,546–0,732, behouden gesteunde voetwissels en blijven binnen de vrije hoogte. Een afgrond wordt echte val met camera-pasoffset nul.
- Nieuwe C tijdens actieve slide bewaart kruipvoorkeur. Spatie richt veilig op en springt met exact dezelfde resterende horizontale vaart; vanaf de volgende luchtframe keert de handmatig gekozen kruiphouding terug, ook na landing. Zonder nieuwe C blijft de voorkeur staan. Dit gedrag is gemeten, geen nieuwe bediening ontworpen.
- Een externe 750 Ns-impuls geeft sprintvaart 18,4000 m/s na de gewone framevertraging. De volgende overgang meet: lopen 17,7333; kruipen 18,1333; slide 18,2333; sprong 19,3000 m/s. Alleen afgesproken profielremming/eenmalige sprongbonus verandert de vaart.
- Maximaal één lokale motorvloerstraal en twee voetstralen per frame; nul voetcontacten tijdens echte lucht. Deze telling is geen totaal van alle capsule-/posturequeries.
- De integratiesuite herbevestigt vier lichaamsverhoudingen, geplante voeten, camera en audio. Artemis lichaams-/camera-amplitude: 0,08044/0,01428 m. De motorproef houdt exacte speler/AI-bewegingspariteit, hoogteopbouw en massaimpulsen.

## Door de gebruiker beoordeeld

Deze terreinproef is technisch beoordeeld; het gevoel van pasvlucht en opstappen blijft onderdeel van de gezamenlijke speelproef. De technische voetmetingen vervangen geen beoordeling van het bewegende model.

## Volgende stap

Integreer de gerichte correctie, herhaal de gezamenlijke controles op de geselecteerde speelversie en laat de gebruiker treden/hellingen plus een slide met C gevolgd door spatie proberen. AI-kijkrichting en editor-/presentatielevenscyclus worden in hun afzonderlijke integratiestap behandeld.