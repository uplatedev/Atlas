# T-011 — Losse grotere draaibijstappen

Vervolg op gebruikersfeedback over c041f65e. De planner wil niet langer beide voeten tot op de laatste graad en centimeter uitlijnen. Na ieder contact volgt een nieuwe beslissing; binnen een comfortabele hoekreserve blijven positie en richting van beide voeten staan. De bestaande borstreserve blijft gelden. Een draaiende vrije voet krijgt een duidelijke hoek, standaard met maximaal68 graden tussen beide voetrichtingen en0,22 seconde zwaaiduur; deze bestaande Inspectorvelden blijven afzonderlijk instelbaar.

Een vrije voet na lopen landt veilig bij zijn bereikte horizontale positie. Alleen een daadwerkelijk te ver steunpunt vraagt een neutrale veiligheidsherplaatsing. Bij een plots tegengestelde blik mag de achterblijvende voet opnieuw als vrije voet worden gekozen: daarmee vermijdt de planner een klein kruisend tussenpasje. Er is steeds één vaste steunvoet en hoogstens één geplande vrije voet. Camera, capsule en loop-/renmotor veranderen niet.

## Gecontroleerd

De drie gerichte echte Character-suites voor draaien, borstreserve en stoppen+kijken slagen met Godot4.7.2. [Uitvoer](quiet-turn-validation.txt). Oude eisen dat de uiteindelijke pose exact de capsule-yaw moet bereiken zijn vervangen door de nu gevraagde comfortabele asymmetrie; de loopoverdracht moet nog altijd volledig aansluiten.

- ±90 graden kijken: één stap van68 graden; de steunvoet draait0 graden mee. Daarna180 frames kleine blikvariatie zonder correctiestap of voetdrift.
- ±180 graden: drie stappen op alle vier lichamen. Doorlopend±360: tien stappen; ±720:22. De eerdere geregistreerde proef gebruikte respectievelijk vijf,17 en35 stappen.
- Geen kruisingen of steunpuntdrift; maximaal twee voetqueries. De werkelijke hoofdbasis blijft binnen0,040 graden van de verwachte richting. Abrupte eerste stap begint pas bij24,46 graden borstrotatie; langzaam kijken benut34,69 graden.
- Twaalf loopstarts na een draai behouden de pin en positieve echte enkelafstand; na negen loopframes maximaal3,49 graden achterstand. Kleine/live borstmaxima blokkeren de planner niet.

## Beoordeling en volgende stap

De gebruiker heeft minder, grotere stappen en blijvende ongelijke voetstand gevraagd. De concrete uitvoering moet nog visueel en in de gecombineerde speelproef beoordeeld worden. Root integreert dit met de afzonderlijke WALK-/SIDEDIAG-correcties. Slide volgt als afzonderlijke posewijziging.
