# Atlas controleren en proberen

Controle-instructies staan hier; resultaten per bronversie staan bij de taak in [WORK](WORK.md). Een geslaagde headless-start bewijst geen speelgevoel, beeldkwaliteit of multiplayerwerking.

## Toolchain

[tools/toolchain.json](../tools/toolchain.json) bevat de exacte vereiste `--version`-uitvoer: `4.7.2.stable.official.ed1daf0bf`, Godot Standard voor Windows x86_64. De bestaande portable installatie is gecontroleerd tegen de [officiële 4.7.2-release](https://godotengine.org/download/archive/4.7.2-stable/). Een latere versie overstappen vraagt een expliciete toolchainwijziging en nieuwe controles.

## Lokale engine instellen

Pak de officiële Windows Standard-download uit. Er is geen globale installatie nodig. Maak lokaal `tools/godot.local.json` met het volledige pad naar de console-exe; dit bestand wordt niet gecommit:

```json
{
  "godotPath": "C:/jouw map/Godot/Godot_v4.7.2-stable_win64_console.exe"
}
```

Of stel in de huidige PowerShell-sessie de projectvariabele in:

```powershell
$env:ATLAS_GODOT = 'C:\jouw map\Godot\Godot_v4.7.2-stable_win64_console.exe'
```

`ATLAS_GODOT` gaat voor het lokale bestand. Verwijder een oude sessiewaarde met `Remove-Item Env:ATLAS_GODOT` om weer het bestand te gebruiken. Gebruik op iedere computer en in iedere worktree het eigen lokale pad. Bewaar nooit machinepaden of credentials in de gedeelde toolchain.

## Bootstrapcontrole

Vanuit de Atlas-root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Check-Atlas.ps1
```

PowerShell 5.1 en PowerShell 7 worden ondersteund. De scripts bepalen de projectmap vanuit hun eigen locatie en ondersteunen spaties. `Check-Atlas.ps1` controleert achtereenvolgens de exacte engineversie, import met `--headless --path <game> --import` en de ingestelde hoofdscene met `--headless --path <game> --quit-after 10`. De flags zijn gecontroleerd met de geïnstalleerde engine en de [officiële commandoreferentie](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html).

Succes geeft exitcode 0. Ontbrekende engine, verkeerde versie, mislukte import/start, gemelde enginefout of overschreden wachttijd geven een duidelijke melding en exitcode 1. De interne [Atlas-Engine.ps1](../tools/Atlas-Engine.ps1) deelt alleen padresolutie, versiecontrole en procesafhandeling tussen de twee gebruikersscripts.

Open daarna de editor:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Open-Atlas.ps1
```

Controleer dat Atlas geopend is, open `scenes/main.tscn` en start de actuele hoofdscene met F5; F8 stopt. Tijdens de bootstrap was dit een lege scene met één neutrale Main-node. De T-002-werkbranch bevat nu de Character-proef hieronder. Opnieuw importeren mag geen onverwachte bronwijzigingen achterlaten. `.godot/` is cache; `.uid`-bestanden en importinstellingen zijn niet algemeen genegeerd.

Bij wijzigingen aan de helpers: controleer ook een ontbrekend pad, versieverschil, ongeldige hoofdscene en engine-/projectpaden met spaties. Gebruik tijdelijke kopieën voor foutproeven en herstel lokale instellingen. Maak geen scaffold-unittests die alleen de bestanden nabootsen.

## Vaste lokale testplek

De gebruiker opent steeds `game/project.godot` vanuit zijn vaste Atlas-checkout op de actieve computer. Bij ieder opgeleverd, technisch gecontroleerd testcheckpoint houdt de agent deze map bij. Tussentijdse onvoltooide edits blijven in de eigen ontwikkelworktree; tijdens een lopende menselijke proef blijft de geselecteerde versie vaststaan.

De overdracht verloopt zo:

1. Controleer en publiceer de samenhangende proef op de werkbranch volgens AGENTS. Noteer broncommit en korte handelingen voor de gebruiker. Een proef die nog menselijk oordeel nodig heeft, blijft op de werkbranch tot de vereiste acceptatie rond is.
2. Controleer de actuele toestand van de vaste testcheckout én eventueel open Godot-project voordat bestanden veranderen. Bewaar wijzigingen aan scenes, instellingen en assets. Laat niet-opgeslagen editorwerk eerst opslaan; leid afwezigheid daarvan niet alleen uit een schone Git-status af. Niet stilzwijgend resetten, stashen, conflicten overschrijven of de editor sluiten.
3. Zet de schone testcheckout op exact het geselecteerde gepushte checkpoint. Gebruik waar nodig een afzonderlijke lokale testbranch; een werkbranch kan niet tegelijk in de ontwikkelworktree en testcheckout uitgecheckt zijn. Meld de versieovergang. Behoud genegeerde lokale engine-instellingen en gebruikersbestanden. Bij bewaarwerk of conflicten blijft de huidige proef beschikbaar tot die veilig zijn opgelost.
4. Controleer import/start op deze werkelijke testlocatie, vergelijk de bronversie en geef aan welke scene te openen en wat met F5 te proberen. Wanneer Godot nog openstaat, zorg voor een gecontroleerde herlaad-/heropenstap nadat het editorwerk is opgeslagen. De gebruiker hoeft niet zelf met branches of worktrees te werken.
5. Na beoordeling volgt eventuele main-integratie volgens AGENTS. Houd de testplek bij die volgende overdracht opnieuw coherent. Een andere computer wordt niet vanzelf bijgewerkt; dat gebeurt in een actieve sessie op die machine. Een geselecteerde tweepc-testbuild blijft apart vaststaan zoals hieronder beschreven.

## Lokale Character-proef

Deze instructies gelden voor de geselecteerde [T-005-proefbranch](https://github.com/uplatedev/Atlas/tree/Smyl3z/T-005-character-verfijnen). De actuele broncommit en lokale overdracht staan in WORK. Gameplay en de `-CharacterChecks`-optie zitten op die werkbranch; main blijft het gedeelde geheugen totdat de noodzakelijke gebruikersbeoordeling rond is.

De [Character-beschrijving](topics/character.md) beschrijft de instellingen en editorwerkwijze. Open `game/scenes/main.tscn` en druk op F5. WASD/muis/Shift/spatie besturen, Alt is sneak, Ctrl kruip aan/uit, Z lig, spatie één houding omhoog of springen vanuit staan, scroll zoomt, Tab wisselt Character, R reset beide, F3 wisselt debug en F4 dynamische FOV. Esc geeft de muis vrij en klik hervat. Resultaten van controles staan bij T-004 in WORK; menselijke beoordeling van het gevoel blijft nodig.

Herhaalbare technische proef vanuit de Atlas-root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Check-Atlas.ps1 -CharacterChecks
```

Deze optionele suite draait de oorspronkelijke scene-/physicscontroles, movementregressies en T-005-verfijningsproeven. Ze meet echte Character-physics en controleert onder meer twaalf herhaalsprongen per richting, vermoeidheid, timing, lage doorgangen, hoofd-/lichaamsdraai en camera. De headless-suite gebruikt vaste renderdelta op 60 FPS zonder realtime wachten; de physics blijft 60 Hz. De gewone Check-Atlas-aanroep blijft een korte import-/startcontrole.

1. Plaats twee instances en geef ze andere namen en duidelijk verschillende loop-/sprintwaarden. Wijzig één instance en controleer dat de andere gelijk blijft; doe dit ook voor camera, sprong en opstap. Laat de gebruiker zelf plaatsen, aanklikken en instellen.
2. Vergelijk na uitaccelereren vooruit, zijwaarts en achteruit, zowel lopend als sprintend. Controleer de afgesproken volgorde en de toepasselijke limiet. Combineer twee inputs: geen diagonale bonus, ook niet bij sprinten of richtingwissels. Tegengestelde inputs mogen geen snelheid opstapelen.
3. Meet versnellen, uitrollen na loslaten en overgang van sprint naar lopen met de afzonderlijke acceleratie-/afremwaarden. Debug toont invoer en werkelijke beweging onderscheidbaar, ook wanneer er tijdens afremmen geen input meer is.
4. Draai de muis: hoofd/camera kijken direct binnen het bereik; het lichaam draait begrensd bij. Bekijk beide debugpijlen, zachte hoofdzone, direct terugkijken en een liglichaam dat niet verder door de tunnel kan draaien. A/D strafen en S loopt achteruit ten opzichte van het lichaam. Zoom via scroll naar first person en terug; test aangepaste zoomgrenzen/-stap, muren en lage plafonds. Eigen capsule/naam blokkeren het zicht niet; andere instances blijven zichtbaar.
5. Vergelijk werkelijke spronghoogte en landingsafstand vanuit stilstand, uitgeaccelereerd lopen en uitgeaccelereerd sprinten. Stilstand het hoogst, lopen ertussenin, sprint het laagst maar extra ver. Controleer ook zij-/achterwaartse sprint, Shift vanuit rust, diagonale afzet en beperkte luchtsturing: geen onbeperkte snelheidsopbouw of wisseling van het afzetprofiel midden in de lucht.
6. Test opstappen vlak onder, op en boven de ingestelde grens. Loop links route 1 binnen: 0.30 m trede met 1.20 m vrije ruimte geeft automatisch kruip. Zonder eigen houdingkeuze blokkeert de 0.80 m lage vervolgroute. Kies Ctrl-kruip om automatische lig toe te staan; na de open uitgang herstelt kruip. Spatie richt je daarna op. Kies handmatig kruip/lig en controleer dat de uitgang die keuze bewaart. Kies Z om handmatig direct lig te proberen bij de lage ingang; probeer ook, onmogelijke 0.65 m doorgang en smalle ligbocht. Boven de opstapgrens blijft het een obstakel.
7. Controleer echte texturebestanden en bekende rasterafstand op vloeren én muren; geen uitrekking of verkeerde schaal. Beoordeel de capsule, naam en markeringen onder precies de twee edge-/fill-lampen met de sunset-skybox.

Leg bij T-002 bronversie, technische resultaten en het afzonderlijke gebruikersoordeel vast. Numerieke defaults zijn afstelbaar; technisch correcte waarden bewijzen nog geen prettig bewegingsgevoel.

### Bekende beperking en T-003-diagnose

De gebruiker meldde stapelende sprintsprongen in T-002. De toenmalige suite reset vóór losse sprongen en miste de herhaalreeks. [T-003](work/T-003.md#diagnose-van-de-huidige-proef) bevat de reproductie op oude bron `c23038f4a97836773fbcbfe897b82b4b9e141e77`, inclusief script/log en kandidaatvormqueries. T-004 bouwt de fix, vermoeidheid, nieuwe camera en houdingscontroller; resultaten staan bij die taak. De oude reproductie moet op de genoemde oude bron worden gedraaid.

De diagnosebestanden staan buiten game. Gebruik de Godot-versie uit de toolchain en een geïmporteerde T-002-gamecheckout van die exacte bron; main alleen bevat het benodigde Character nog niet. Laad de bestaande proceshelper vanuit de documentatiecheckout en wijs een afzonderlijke T-002-proefmap aan:

```powershell
. .\tools\Atlas-Engine.ps1
$engine = Get-AtlasEngine
$proefRoot = 'PAD-NAAR-DE-T-002-CHECKOUT'
$proefGame = Join-Path $proefRoot 'game'
$hopScript = [IO.Path]::GetFullPath('docs/work/T-003/bunnyhop_repro.gd')
$vormScript = [IO.Path]::GetFullPath('docs/work/T-003/stance_shape_probe.gd')
Invoke-AtlasEngine -Engine $engine -Arguments @('--headless', '--path', $proefGame, '--script', $hopScript)
Invoke-AtlasEngine -Engine $engine -Arguments @('--headless', '--path', $proefGame, '--script', $vormScript)
```

De eerste harness geeft exitcode 0 als de oude fout daadwerkelijk is gereproduceerd, met oplopende snelheden in de log. De tweede geeft exitcode 0 voor zes geslaagde volumequeries. Dit is geen vervanging voor een latere regressietest die juist géén stapeling verwacht. Gebruik een afzonderlijke proefmap als de gebruiker in de vaste map speelt; de diagnose verandert geen gameplaybron.

### Nieuwe regressies en menselijke vervolgproef

`game/tests/movement_checks.gd` controleert directe herhaalsprongen in alle richtingen, geen stapeling met vermoeidheid uit, zwakker worden en grondherstel, geen reset via profielwissel, minimale sneakhoogte en één uitvoering per druk. De suite controleert ook landingsbuffer/randtolerantie, veilige houdingsovergangen, behoud van handmatige houding, hoofdgrenzen en de ligvorm in een smalle tunnel.

Laat de gebruiker dezelfde loop-/sprint-/rem-/draairoute spelen met snelheid-FOV uit en aan, third en first person, en snelle cameradraai met begrensd lichaam. Test camera op verschillende renderframerates, Tab/reset, eigen zicht en het verschil tussen gevraagde zoom en muurcompressie. Vergelijk volle en opeenvolgende sprongen en terugkeer naar volle kracht na grondrust. De arena-/defaultdetails staan in T-003; resultaten komen pas na werkelijke uitvoering in WORK.

## T-005 opnieuw op gevoel proberen

Start dezelfde hoofdscene met F5. Vergelijk een zeer korte aanloop (bijna tegelijk W/Shift/spatie) met volledig uitaccelereren. Doe dit ook lopend. Kies tijdens een sprintsprong Ctrl of Z: horizontaal moet je direct sterk stoppen, terwijl de verticale sprong doorgaat. Probeer hiermee precies op een metermarkering of post te landen.

Z kiest lig; Ctrl kiest kruip. Druk vanuit lig twee keer afzonderlijk spatie: eerst kruip, dan staan, zonder sprong. Een derde nieuwe druk springt. Onder een plafond blijft oprichten veilig geblokkeerd. Als route 1 je automatisch laat kruipen, kies Ctrl om kruip zelf vast te leggen en automatische lig verderop toe te staan. Zonder die eigen keuze mag staan nooit automatisch lig worden.

Kijk vanuit stilstand een kleine hoek opzij: het lichaam blijft staan. Begin te bewegen of kijk ver opzij: het lichaam draait met zijn ingestelde limiet bij. Probeer de verhoogde post vóór de linker kruipingang en benader schuin. Vergelijk cameravolging bij lopen, sprinten en vallen; vergelijk FOV met F4 bij sprint/sneak/kruip/lig. Alle extra cameraverzachting is per Character instelbaar en kan op nul.

`refinement_checks.gd` meet de korte en volle afzet, maximale luchtsnelheid, horizontale precisierem met behoud van verticale snelheid, expliciete houdingknoppen, Ctrl na automatische kruip, hoek-/wandbenaderingen en lichaams-/luchtsturing. Het bijbehorende [T-005-verslag](work/T-005.md) bevat bronversie en werkelijk uitgevoerde resultaten. Een technisch geslaagde proef bewijst het nieuwe gevoel nog niet.

## Latere proeven: nog niet uitgevoerd

Deze aanpak is afgesproken; de benodigde functionaliteit bestaat nog niet:

1. **Editor:** plaats twee Characters vanuit één herkenbare ingang. Stel verschillende snelheid, acceleratie en deceleratie in; wijzig er één en controleer dat de andere gelijk blijft. Leg vast welke scene wat bevat, wat veilig aangepast kan worden en hoe nieuwe content ontstaat.
2. **LAN:** spreek vóór implementatie eigenaarschap, plaatsen/spawnen, individuele instellingen en synchronisatie af. Gebruik één geselecteerde schone Windows-export op beide pc's, van een al gepushte broncheckpoint. Genereer bij export zichtbare build-ID/broncommit, exacte Godot-versie en verbindingswijze; zet geen toekomstige eigen commit-hash in de broncommit. Binaries blijven buiten gewone bronhistorie. Laat die testbuild vaststaan terwijl elders ontwikkeling doorgaat.
3. **Bediening:** beschrijf bij die proef de werkelijke eenvoudige host/join-handelingen. Noteer technische synchronisatie afzonderlijk van het oordeel van de gebruiker over instellen, bediening en gevoel, steeds met build-ID en wat er werkelijk op beide pc's gebeurde.
4. **Steam:** bewijs vroeg met dezelfde beperkte gameplay en editorwerkwijze de Windows-export, actuele engine-/plugincompatibiliteit, sessiontoegang, identiteit, eigenaarschap en toestandsoverdracht. Een andere transportklasse alleen bewijst dit niet. Kies de plugin pas na actuele verificatie. AppID 480 hoort bij Spacewar-ontwikkeling en is geen definitieve Atlas-identiteit; gebruik bij gelijktijdige proeven twee verschillende Steam-accounts en houd Atlas-projectidentiteit/versie apart herkenbaar.

De lokale Character-proef is gebouwd op de T-002-werkbranch. Er is nog geen Windows-testexport, LAN-proef, gebruikersbeoordeling van speelgevoel of Steamproef uitgevoerd. Technische resultaten en vervolgafstemming staan in [WORK](WORK.md).
