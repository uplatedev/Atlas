# T-011 — Meer borstrotatie vóór bijstappen

Gebruikersfeedback op `d1196064`: de torso moet merkbaar verder kunnen meedraaien voordat de voeten bijstappen. Deze afstelling vertrekt van bytegelijke native bron `9ca0c5c`, op `Smyl3z/T-011-torso-ruimte`, onder dezelfde T-011-claim.

- **Gebouwd:** stilstaande borstrotatie benut nu 65% van de relatieve blik, begrensd op standaard35 graden. Een nieuwe draai begint pas bij standaard24 graden werkelijk opgebouwde borstrotatie. Een lopende bijstap/uitlijning maakt af; neutraal herplaatsen blijft mogelijk. De helper houdt de echte motor-yaw bij, zodat directe loopinvoer dezelfde geteste overdracht gebruikt. De nekgrens geldt ten opzichte van de gedraaide borst en blijft85 graden bij de bestaande Character-default. Logische blik, motor, camera, voetbaan, breedte en RUN zijn niet aangepast.
- **Technisch gecontroleerd:** echte botbasissen reproduceren vóór de correctie slechts15,41 graden borstrotatie bij rustig kijken en4,15 graden bij plots120 graden kijken. Na de correctie is dit respectievelijk33,63 en24,46 graden; de abrupte eerste bijstap begint na acht in plaats van twee physicsframes. Nekrotatie maximaal85,00002 graden. Beide draairichtingen, vaste voetcontacten, geen kruisende voeten, volledige afloop en live profielinstellingen slagen. Bestaande draai- en geïntegreerde bewegingstests slagen; hoofd-pitch-basisfout blijft0,040 graden en de loopoverdracht behoudt positieve enkelafstand. [Voor/na-bewijs](torso-validation.txt).
- **Door de gebruiker beoordeeld:** de wens is expliciet; deze concrete waarden zijn nog niet gespeeld. Drie echte D3D12/Forward+ beelden zijn bekeken: blik30 met borst18,53; blik55 met borst34,84 terwijl motor en voeten op0 graden blijven; daarna de eerste losse bijstap. Geen nieuwe visuele afwijking gezien in deze drie houdingen. Dit is geen menselijke acceptatie van gevoel.
- **Volgende stap:** root combineert dit met de afzonderlijke smallere rust-/loopsporen en WALK-correctie. De invoerbreedte van de turnplanner moet dezelfde profielhelper gebruiken als de andere voetplanner. Deze branch laat die ene rest.x-regel bewust ongewijzigd zodat hij zelfstandig compileert; de breedtebranch levert de wijziging. Daarna één gecombineerde lokale proef.

Onder **Body Profile > Bijstappen** zijn twee live instelbare velden toegevoegd:

- **Turn Torso Max Degrees:** grootste borstrotatie bij stilstaand kijken, standaard35 graden (0–50; 0 schakelt de borstreserve uit).
- **Turn Torso Before Step Degrees:** opgebouwde borsthoek vóór een nieuwe bijstap, standaard24 graden (5–40). Een hoger ingestelde wachthoek dan het maximum wordt intern begrensd op85% van dat maximum, zodat de voeten altijd kunnen volgen.

De profielen blijven onafhankelijk. Een gerichte proef verandert het maximum live naar20 en de wachthoek naar40: de echte borst bereikt19,90 graden, de modelinstance blijft dezelfde, een andere profielkopie blijft35/24 en de bijstappen lopen volledig af. Ook maximum0 of1 met wachthoek40 blokkeert niet; het echte borstmaximum blijft behouden.

Herhalen met de lokale Godot-configuratie:

```powershell
. ./tools/Atlas-Engine.ps1
$atlasEngine = Get-AtlasEngine
Invoke-AtlasEngine -Engine $atlasEngine -Arguments @('--headless', '--path', 'game', '--fixed-fps', '60', '--script', 'res://tests/procedural_torso_checks.gd')
```

De vaste60-Hz-proef controleert gedrag en botposes, geen realtime prestaties. Echte PNG's en reproduceerscript zijn lokaal bewaard in de taakvisualisaties onder `t011-torso`: `head30.png`, `chest55.png`, `first_step.png` en `preview.gd`.