# Atlas

Atlas is een nieuw Godot-gameproject. Deze werkbranch bevat de eerste [lokale Character-proef](docs/topics/character.md): twee individueel instelbare capsules, camera met zoom van third person naar first person en een meetbaar prototypelevel. Technische controle en gebruikersoordeel staan in [WORK](docs/WORK.md). De verdere spelwereld staat open.

## Openen en controleren op Windows

Gebruik Godot **4.7.2 Standard**, exact `4.7.2.stable.official.ed1daf0bf`. Pak de [officiële portable Windows-versie](https://godotengine.org/download/archive/4.7.2-stable/) uit en stel eenmalig het enginepad in zoals beschreven in [TESTING](docs/TESTING.md#lokale-engine-instellen).

Voer vanuit deze map in PowerShell uit:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Open-Atlas.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Check-Atlas.ps1
```

De tijdelijke execution policy geldt alleen voor die aanroep. De editor opent [game/project.godot](game/project.godot). Open `scenes/main.tscn` en druk op F5 om de proef te spelen; F8 stopt het project. De controle importeert de bronnen en start de hoofdscene kort zonder venster. Met `-CharacterChecks` voert Check-Atlas ook de fysieke proeven uit.

WASD beweegt, de muis kijkt, Shift sprint, Alt is sneak, Ctrl schakelt kruip aan/uit, Z kiest lig en scroll zoomt tot first person. Spatie springt vanuit staan of actieve slide; gewone lage houdingen richt je ermee op. Vanuit staan gekozen lig keert met één spatie direct veilig naar staan terug, zonder tegelijk te springen. Tab wisselt tussen de Characters; R brengt ze terug naar hun start. F3 schakelt de richtingsdebug en pijlen; F4 vergelijkt dynamische FOV; F6 schakelt contactaudio van de actieve instance aan/uit. Esc geeft de muis vrij; klik in het spel om verder te spelen.

Kies Ctrl tijdens een sprong om bij landing te sliden. Na de slide sta je automatisch op als dat past; onder een laag plafond blijf je automatisch kruipen. Een volgende nog lagere doorgang kan kruip naar lig laten overgaan. De vluchtvaart blijft behouden; Z-lig en Ctrl op de grond geven geen slide. S remt tegen voorwaartse vlucht of slide geleidelijk af. De FPS-teller staat rechtsboven.

De Character heeft gevarieerde contactaudio voor lopen/sprint/sneak/kruip/lig, afzet, impactlanding en een aparte slideschuurlaag. Stappen volgen echte grondafstand; W tegen een wand geeft geen contactspam. De Audio-groepen op de Character-root bevatten volume, cadans, variatie en vervangbare samples met korte beschrijvingen. Eigen audio blijft even duidelijk bij zoomen; andere Characters zijn ruimtelijk hoorbaar.

Selecteer `Characters/AtlasA` of `Characters/AtlasB` in de hoofdscene om naam, kleur, beweging, springen, opstap en camera in de Inspector te wijzigen. Open [Character.tscn](game/characters/Character.tscn) om die ingang te bekijken. Je kunt deze scene onder `Characters` plaatsen of een bestaande instance dupliceren; Tab neemt die extra instance automatisch mee. Zie [de editorwerkwijze](docs/topics/character.md#zelf-content-plaatsen-en-aanpassen).

Deze Atlas-map is de vaste lokale testplek. Bij ieder technisch gecontroleerd, testbaar checkpoint zet de uitvoerende agent hier de geselecteerde bronversie klaar en vermeldt wat je kunt proberen. Je blijft hetzelfde `game/project.godot` openen. Ook een nog te beoordelen werkbranchproef wordt zo lokaal beschikbaar; die hoeft daarvoor nog niet naar main. De agent bewaart jouw editorwijzigingen en lokale instellingen en verandert een lopende proef niet tussendoor. Zie [de werkwijze](docs/TESTING.md#vaste-lokale-testplek).

## Samen werken

Vertel een agent gewoon wat je wilt ervaren, bouwen of veranderen. Je hoeft geen taaklabels, bestandsnamen of administratie aan te leveren. De agent onderhoudt de passende context, vraagt door bij wezenlijke keuzes en volgt [AGENTS.md](AGENTS.md).

| Waar | Wat je er vindt |
| --- | --- |
| [CONCEPT](docs/CONCEPT.md) | Gewenste ervaring, editorwerkwijze en grenzen |
| [WORK](docs/WORK.md) | Actueel werk, eigenaarschap, resultaten en open feedback |
| [INBOX](docs/INBOX.md) | Alleen informatie waarvan betekenis of bestemming nog onduidelijk is |
| [IDEAS](docs/IDEAS.md) | Mogelijkheden zonder uitvoeringsopdracht |
| [DECISIONS](docs/DECISIONS.md) | Betekenisvolle keuzes, herkomst en gevolgen |
| [TESTING](docs/TESTING.md) | Herhaalbare controles en menselijke proeven |

## Gepubliceerd werk vinden

[GitHub: uplatedev/Atlas](https://github.com/uplatedev/Atlas) is de gedeelde toestand. `main` bevat het gepubliceerde geheugen en geïntegreerde resultaten. Nog te beoordelen proeven staan op de in WORK genoemde gepushte werkbranch; een lokale wijziging is nog niet gedeeld. Bekijk de bronversie met `git log -1 --oneline` en de toestand met `git status --short --branch`.

Op een tweede computer: clone de repo, stel daar het eigen enginepad in en voer Check-Atlas uit. Voor een bestaande checkout eerst lokale wijzigingen controleren en bewaren, daarna fetch en uitsluitend een passende fast-forward-update. Werk nooit stilzwijgend over lopend werk heen. Taakreservering en gelijktijdig schrijven volgen het protocol in AGENTS.
