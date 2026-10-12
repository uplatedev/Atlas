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

## Lokale Character-proef: nog niet gebouwd

De [Character-fundering](topics/character.md) beschrijft de gewenste instellingen en aanpak. Deze controles zijn het plan voor de eerste implementatie; er zijn nog geen Character-testresultaten.

1. Plaats twee instances en geef ze andere namen en duidelijk verschillende loop-/sprintwaarden. Wijzig één instance en controleer dat de andere gelijk blijft; doe dit ook voor camera, sprong en opstap. Laat de gebruiker zelf plaatsen, aanklikken en instellen.
2. Vergelijk na uitaccelereren vooruit, zijwaarts en achteruit, zowel lopend als sprintend. Controleer de afgesproken volgorde en de toepasselijke limiet. Combineer twee inputs: geen diagonale bonus, ook niet bij sprinten of richtingwissels. Tegengestelde inputs mogen geen snelheid opstapelen.
3. Meet versnellen, uitrollen na loslaten en overgang van sprint naar lopen met de afzonderlijke acceleratie-/afremwaarden. Debug toont invoer en werkelijke beweging onderscheidbaar, ook wanneer er tijdens afremmen geen input meer is.
4. Draai de muis: het Character draait horizontaal mee, A/D strafen en S loopt achteruit. Zoom via scroll van third person naar first person en terug; test aangepaste zoomgrenzen/-stap, muren en lage plafonds. Eigen capsule/naam blokkeren het first-personzicht niet; de andere instance blijft zichtbaar. Later in LAN moet ook de andere speler de lokaal verborgen capsule blijven zien.
5. Vergelijk werkelijke spronghoogte en landingsafstand vanuit stilstand, uitgeaccelereerd lopen en uitgeaccelereerd sprinten. Stilstand het hoogst, lopen ertussenin, sprint het laagst maar extra ver. Controleer ook zij-/achterwaartse sprint, Shift vanuit rust, diagonale afzet en beperkte luchtsturing: geen onbeperkte snelheidsopbouw of wisseling van het afzetprofiel midden in de lucht.
6. Test opstappen vlak onder, op en boven de ingestelde grens, met hoge wanden en lage plafonds. Geen doorsnijden of ongewenst omhoog verplaatsen. Boven de grens blijft het een obstakel.
7. Controleer echte texturebestanden en bekende rasterafstand op vloeren én muren; geen uitrekking of verkeerde schaal. Beoordeel de capsule, naam en markeringen onder precies de twee edge-/fill-lampen met de sunset-skybox.

Leg bij T-002 bronversie, technische resultaten en het afzonderlijke gebruikersoordeel vast. Numerieke defaults zijn afstelbaar; technisch correcte waarden bewijzen nog geen prettig bewegingsgevoel.

## Latere proeven: nog niet uitgevoerd

Deze aanpak is afgesproken; de benodigde functionaliteit bestaat nog niet:

1. **Editor:** plaats twee Characters vanuit één herkenbare ingang. Stel verschillende snelheid, acceleratie en deceleratie in; wijzig er één en controleer dat de andere gelijk blijft. Leg vast welke scene wat bevat, wat veilig aangepast kan worden en hoe nieuwe content ontstaat.
2. **LAN:** spreek vóór implementatie eigenaarschap, plaatsen/spawnen, individuele instellingen en synchronisatie af. Gebruik één geselecteerde schone Windows-export op beide pc's, van een al gepushte broncheckpoint. Genereer bij export zichtbare build-ID/broncommit, exacte Godot-versie en verbindingswijze; zet geen toekomstige eigen commit-hash in de broncommit. Binaries blijven buiten gewone bronhistorie. Laat die testbuild vaststaan terwijl elders ontwikkeling doorgaat.
3. **Bediening:** beschrijf bij die proef de werkelijke eenvoudige host/join-handelingen. Noteer technische synchronisatie afzonderlijk van het oordeel van de gebruiker over instellen, bediening en gevoel, steeds met build-ID en wat er werkelijk op beide pc's gebeurde.
4. **Steam:** bewijs vroeg met dezelfde beperkte gameplay en editorwerkwijze de Windows-export, actuele engine-/plugincompatibiliteit, sessiontoegang, identiteit, eigenaarschap en toestandsoverdracht. Een andere transportklasse alleen bewijst dit niet. Kies de plugin pas na actuele verificatie. AppID 480 hoort bij Spacewar-ontwikkeling en is geen definitieve Atlas-identiteit; gebruik bij gelijktijdige proeven twee verschillende Steam-accounts en houd Atlas-projectidentiteit/versie apart herkenbaar.

Er is nog geen Character-proef, Windows-testexport, LAN-proef, beoordeling van speelgevoel of Steamproef uitgevoerd. De Character-bespreking is vastgelegd; implementatie en vervolgafstemming staan in [WORK](WORK.md).
