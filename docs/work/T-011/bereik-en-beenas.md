# T-011 — beenas, vrije doelen en omkeernulpunten

Gebouwd op productiecommit `bf86cc2`, vanaf `fcde0c7` met motoroverdracht `d4928a2`, omkeersteun `b99a0bd` en overgangproeven `1ff4cbf`. De hoofdtaak integreert deze afzonderlijke commits en verzorgt publicatie. Zie [T-011](../T-011.md) voor scope en menselijke acceptatie.

## Gebouwd

Vrije voetdoelen worden eenmaal per physicsframe vóór IK binnen de echte minimale/maximale knieafstand gepland. De gekozen bekkenverlaging blijft in dezelfde posecache; renderinterpolatie en herhaald toepassen plannen niets opnieuw. Diagonale vrije herstel-lift is begrensd op 2,5% beenlengte. Vaste wereldcontacten en capsulebeweging veranderen niet.

Bij overgang van zijhup naar gesteund Alt-lopen vervalt de tweede hup-pin zodra de motor volledige eenbenige steun gebruikt. Een feitelijk `movement_requested`-veld voorkomt dat een kort omkeernulpunt een rustherplant start. Langdurig geblokkeerde invoer mag na 0,12 s werkelijk stilstaan weer bijstappen. Een werkelijk nog over te dragen draai van motor naar visuele pose blijft direct toegestaan, zodat de bijbehorende vrije voet veilig kan landen.

De kruistesten meten nu langs de werkelijke heupbot-as, inclusief diagonale gang-yaw. De oude turn-as blijft als diagnose in de turnlog staan. De fysieke scheenafstand, doelfout, pin-drift en bereikgrenzen blijven ongewijzigd. De stoptest verlangt een comfortabele, werkelijk geplante asymmetrische voetstand; exact terugkeren naar neutraal was door de recentere gebruikerswens vervangen.

## Technisch gecontroleerd

Godot `4.7.2.stable.official.ed1daf0bf`, headless, 60 Hz. Herhaal de scripts onder `game/tests` met `--headless --path game --fixed-fps 60 --script res://tests/<naam>.gd`.

- `procedural_free_target_checks`: drie gangen × dertien richtingssegmenten × vier lichamen; PASS. Maximaal 20,25 mm expliciete vrije correctie, werkelijk enkeldoel maximaal 0,039 mm fout, pin-drift/noodloslatingen nul. Herhaald toepassen heeft exact nul verschil in voetdoelen én alle gecachte botposes. Geblokkeerde loopinvoer plus 180° blik: twaalf echte bijstappen over vier lichamen, minimaal 87,9 mm enkelasafstand, maximaal twee queries.
- `procedural_turn_checks`: PASS, inclusief links/rechts/180/360/720 en starten na verschillende draaifases. Het oorspronkelijke -180°/zes-ticks-geval meet circa -24 mm langs de oude turn-as, maar +90,1 mm langs de werkelijke heupas; echte enkels komen exact bij hun doelen.
- `procedural_walk_contacts_checks`: PASS. Bij het lichaam met kort bovenbeen daalt eerste diagonale jog-dip van 81,6 naar 71,0 mm; latere gewone passen maximaal 62,0 mm. Geen extra voetquery, pinverschuiving of noodrelease.
- `procedural_gait_transition_checks`: PASS. Vrije omkeerroute 341 pasvluchten; nulcurve en plafond ieder 907 gesteunde wissels zonder vlucht. Maximaal 1,27 µm werkelijk enkeldoelfout; pin-drift/noodloslatingen nul. Modifiers tijdens springen veranderen de eenmaal gekozen baan niet.
- Goedgekeurde voorwaartse RUN-referentie: PASS, 92.640 waarden, maximale afwijking `5.4389238e-7`; gelijk aan de gemeten afwijking vóór deze correctie.

Bewijs: `bounds-validation.txt`, `bounds-free-target-metrics.json`, `bounds-walk-contact-metrics.json`. De RUN-vergelijking gebruikt het lokale eerder vastgelegde referentiebestand; dat machinepad blijft buiten gedeelde instructies.

## Door de gebruiker beoordeeld

Nog geen nieuwe menselijke beoordeling van dit integratieresultaat. Technische bereikcontroles zijn geen oordeel over loopgevoel. De eerder goedgekeurde voorwaartse RUN blijft behouden.

## Gerichte guardregressie opgelost

De afzonderlijke krappe-doosproef (binnenmaat 1,0 m, ingedrukte W, daarna blik ±180°) liet in de eerste guardversie een negatieve heupasafstand van circa -15,7 cm zien. Op de echte baseline `fcde0c7` bleef de afstand positief (7,90–9,96 cm). Het was dus een nieuwe guardregressie, niet een bewezen ouder probleem: de wachttijd hield een nodige vrije-voetlanding tegen terwijl er werkelijk 15–30 cm beweging en een grote kijkdraai plaatsvonden.

De guard blijft nu uitsluitend wachten wanneer er geen werkelijke draai over te dragen is. De bestaande planner mag bij meer dan 0,01 rad verschil tussen motor en visuele pose direct handelen. Dit voegt geen solver, query of pinverschuiving toe.

`procedural_free_target_checks` bewaakt permanent beide doosvarianten en beide grote draairichtingen. Binnenmaat 0,70 m geeft echte voortdurende blokkade: minimaal 8,79 cm enkelasafstand en twaalf bijstappen over vier lichamen. Binnenmaat 1,0 m geeft de korte loop→stop-overdracht: minimaal 7,99 cm enkelasafstand, maximaal 1,036 mm werkelijke enkeldoelfout, nul pin-drift/noodloslatingen en maximaal twee queries. De afzonderlijke plafond-/nulcurveomkeerproef moet daarnaast groen blijven; deze is geen vervanging daarvan.

Vervolg is de gecombineerde hoofdtaakcontrole, renderer/performance en menselijke beoordeling van het volledige stijlcheckpoint. Bewijs voor deze aanvulling staat in `bounds-guard-validation.txt`; de baseline en kandidaat zijn afzonderlijk gemeten.