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

Deze instructies gelden voor het geselecteerde [T-002-proefcheckpoint](https://github.com/uplatedev/Atlas/tree/Smyl3z/T-002-character-proef), dat op de actieve computer in de vaste testmap klaarstaat. De gameplay en de `-CharacterChecks`-optie zitten op die werkbranch; main blijft het gedeelde geheugen totdat de noodzakelijke gebruikersbeoordeling rond is.

De [Character-beschrijving](topics/character.md) beschrijft de instellingen en editorwerkwijze. Open `game/scenes/main.tscn` en druk op F5. WASD/muis/Shift/spatie besturen, scroll zoomt, Tab wisselt Character, R reset beide, F3 wisselt debug, Esc geeft de muis vrij en klik hervat. Resultaten van controles staan bij T-002 in WORK; menselijke beoordeling van het gevoel blijft nodig.

Herhaalbare technische proef vanuit de Atlas-root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Check-Atlas.ps1 -CharacterChecks
```

Deze optionele suite draait echte Character-physics met een vloer, treden en plafond, meet snelheid/spronghoogte/afstand en controleert de echte hoofdscene, individuele Resources en camera-layers. Het duurt ongeveer een halve minuut. De gewone Check-Atlas-aanroep blijft een korte import-/startcontrole.

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

De lokale Character-proef is gebouwd op de T-002-werkbranch. Er is nog geen Windows-testexport, LAN-proef, gebruikersbeoordeling van speelgevoel of Steamproef uitgevoerd. Technische resultaten en vervolgafstemming staan in [WORK](WORK.md).
