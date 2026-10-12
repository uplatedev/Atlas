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

Controleer dat Atlas geopend is, open `scenes/main.tscn` en bekijk de ene neutrale `Main`-node. F5 toont een leeg venster, F8 stopt. Dit is de volledige huidige proef; er valt nog geen Character te bedienen. Opnieuw importeren mag geen onverwachte bronwijzigingen achterlaten. `.godot/` is cache; `.uid`-bestanden en importinstellingen zijn niet algemeen genegeerd.

Bij wijzigingen aan de helpers: controleer ook een ontbrekend pad, versieverschil, ongeldige hoofdscene en engine-/projectpaden met spaties. Gebruik tijdelijke kopieën voor foutproeven en herstel lokale instellingen. Maak geen scaffold-unittests die alleen de bestanden nabootsen.

## Latere proeven: nog niet uitgevoerd

Deze aanpak is afgesproken; de benodigde functionaliteit bestaat nog niet:

1. **Editor:** plaats twee Characters vanuit één herkenbare ingang. Stel verschillende snelheid, acceleratie en deceleratie in; wijzig er één en controleer dat de andere gelijk blijft. Leg vast welke scene wat bevat, wat veilig aangepast kan worden en hoe nieuwe content ontstaat.
2. **LAN:** spreek vóór implementatie eigenaarschap, plaatsen/spawnen, individuele instellingen en synchronisatie af. Gebruik één geselecteerde schone Windows-export op beide pc's, van een al gepushte broncheckpoint. Genereer bij export zichtbare build-ID/broncommit, exacte Godot-versie en verbindingswijze; zet geen toekomstige eigen commit-hash in de broncommit. Binaries blijven buiten gewone bronhistorie. Laat die testbuild vaststaan terwijl elders ontwikkeling doorgaat.
3. **Bediening:** beschrijf bij die proef de werkelijke eenvoudige host/join-handelingen. Noteer technische synchronisatie afzonderlijk van het oordeel van de gebruiker over instellen, bediening en gevoel, steeds met build-ID en wat er werkelijk op beide pc's gebeurde.
4. **Steam:** bewijs vroeg met dezelfde beperkte gameplay en editorwerkwijze de Windows-export, actuele engine-/plugincompatibiliteit, sessiontoegang, identiteit, eigenaarschap en toestandsoverdracht. Een andere transportklasse alleen bewijst dit niet. Kies de plugin pas na actuele verificatie. AppID 480 hoort bij Spacewar-ontwikkeling en is geen definitieve Atlas-identiteit; gebruik bij gelijktijdige proeven twee verschillende Steam-accounts en houd Atlas-projectidentiteit/versie apart herkenbaar.

Er is nog geen Windows-testexport, LAN-proef, beoordeling van speelgevoel of Steamproef uitgevoerd. De noodzakelijke Character-bespreking staat in [WORK](WORK.md).
