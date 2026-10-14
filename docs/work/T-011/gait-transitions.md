# Gangovergangen en spronginvoer

Bronbasis `fcde0c7`; kleine motorcorrectie op `Smyl3z/T-011-gang-audit`.

De eerste overgang Alt → jog/sprint gebruikte nog de volle gesteunde fase, maar zette bij afzet dezelfde stap terug naar fase 0,5. Artemis ging bijvoorbeeld van 0,98258 naar 0,58421. De bestaande echte gesteunde voetwissel rondt die cyclus nu eerst af; de volgende stap gebruikt weer steun plus vlucht. Capsulevaart, spronginvoer en collision blijven door dezelfde motor bepaald.

`procedural_gait_transition_checks.gd` controleert 24 overgangen met vier lichaamsverhoudingen: Alt, een nulcurve en laag plafond naar jog/sprint, vooruit, diagonaal en beide zijden. Geen teruggaande fase, pinverplaatsing, dubbel contacttype, extra sprong of impactlanding. Dezelfde suite controleert 18 sprongroutes met vier verhoudingen en Alt/Shift/jog-wissels in de bewuste lucht: één sprong per invoer, nul extra horizontale boost, maximale verticale afrondingsfout 0,000000159 m/s. Bestaande `procedural_motor_checks.gd` slaagt inclusief sprint+C, gewone sprongen, randen, plafonds en massa-impulsen.

De onafhankelijke uitgebreidere audit vond daarnaast onbereikbare vrije doelen bij enkele Alt-zij→voor-overgangen en echte steunproblemen bij snelle sprintomkering met afwijkende beenverhoudingen. Die zijn in de gecombineerde bron gericht hersteld: werkelijke contactrichting bepaalt de kortere omkeersteun, vrije doelen worden eenmaal vóór IK binnen het echte bereik gepland en korte omkeernulpunten starten geen neutrale rustherplant. Zie [bereik- en draai-overdracht](bereik-en-beenas.md). De uitgebreide suite controleert dezelfde dertien richtingssegmenten met vier lichamen: 341 echte pasvluchten op vrije grond, en ieder 907 gesteunde wissels bij nulcurve en plafond. Maximaal 1,27 µm werkelijk enkeldoelfout, nul pin-drift/noodloslatingen en maximaal twee queries. Technische correctheid is geen visuele acceptatie.

Herhalen vanuit `game`: Godot headless met `--script res://tests/procedural_gait_transition_checks.gd --fixed-fps 60`. Meetbestand: `user://t011_gait_transition_metrics.json`.
