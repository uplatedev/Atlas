# Atlas

Atlas is een nieuw Godot-gameproject. Main bevat nu de [procedurele Character-proef](docs/topics/character.md): Artemis en twee eenvoudige lichamen met andere beenverhoudingen, wandelen, joggen en sprinten, voet-IK en camera van third person naar first person. Het nieuwste speelcheckpoint `64fcf41a` is op expliciet verzoek van de gebruiker geïntegreerd; de open bewegings-/editorbeoordeling en bekende voetposeproblemen staan in [WORK](docs/WORK.md). De verdere spelwereld staat open.

## Openen en controleren op Windows

Gebruik Godot **4.7.2 Standard**, exact `4.7.2.stable.official.ed1daf0bf`. Pak de [officiële portable Windows-versie](https://godotengine.org/download/archive/4.7.2-stable/) uit en stel eenmalig het enginepad in zoals beschreven in [TESTING](docs/TESTING.md#lokale-engine-instellen).

Voer vanuit deze map in PowerShell uit:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Open-Atlas.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Check-Atlas.ps1
```

De tijdelijke execution policy geldt alleen voor die aanroep. De editor opent [game/project.godot](game/project.godot). Open `scenes/main.tscn` en druk op F5 om de proef te spelen; F8 stopt het project. De controle importeert de bronnen en start de hoofdscene kort zonder venster. Met `-CharacterChecks` voert Check-Atlas ook de fysieke proeven uit.

De vaste bewegingsnamen zijn **Walk**, **Jog** en **Run**: Alt kiest Walk, gewone WASD kiest Jog en Shift kiest Run. De muis kijkt, C schakelt kruip aan/uit, Z schakelt lig aan/uit en scroll zoomt tot first person. Spatie springt vanuit staan of actieve slide; gewone lage houdingen richt je ermee op. Vanuit staan gekozen lig keert met één spatie direct veilig naar staan terug, zonder tegelijk te springen. Tab wisselt tussen de Characters; R brengt ze terug naar hun start. F3 schakelt de richtingsdebug en pijlen; F4 vergelijkt dynamische FOV; F6 schakelt contactaudio van de actieve instance aan/uit; F7 vergelijkt het kleine landingsaccent, F9 de nieuwe lucht-/slide-FOV met de eerdere mapping. Esc geeft de muis vrij; klik in het spel om verder te spelen.

Code, Inspector, HUD en Input Map gebruiken dezelfde namen. De Character heeft eigen `walk_*`, `jog_*` en `run_*`-instellingen; bestaande scene-/resourcewaarden zijn tegelijk omgezet. De naamwijziging op main behield het bestaande strafen. De bevestigde vervanging wordt als [T-014-speelproef](docs/work/T-014.md) gedeeld op `Smyl3z/T-014-directionele-strafe`: rustige Walk-zijpassen, compact Jog en meer onderlichaamsdraai bij Run, met dezelfde snelheden. De geselecteerde proef staat in de vaste lokale werkmap; menselijke beoordeling volgt vóór gameplay-integratie op main.

Kies C tijdens sprinten op de grond om direct te sliden, of tijdens een sprong/pasvlucht om bij landing te sliden. Beide gebruiken de werkelijk opgebouwde vaart, zonder extra boost. Nogmaals C tijdens de slide laat hem uitlopen en houdt je daarna gekruipt. Anders sta je na afloop op als dat past. Staand kan je automatisch kruipen, maar automatisch lig vereist dat je zelf eerst kruip koos. Gewoon lopen of stilstaan + C blijft kruipen; Z-lig start geen slide. S remt tegen voorwaartse vlucht of slide geleidelijk af. De FPS-teller staat rechtsboven.

De Character heeft gevarieerde contactaudio voor joggen/sprint/wandelen/kruip/lig, afzet, impactlanding en een aparte slideschuurlaag. Staande procedurele stappen volgen echte voetcontacten; lage houdingen gebruiken grondafstand. W tegen een wand geeft geen contactspam. De Audio-groepen op de Character-root bevatten volume, cadans, variatie en vervangbare samples met korte beschrijvingen. Eigen audio blijft even duidelijk bij zoomen; andere Characters zijn ruimtelijk hoorbaar.

De nieuwe cameravariant heeft een kleine TP-landingsdip (maximaal 1 cm; FP standaard nul) en een snelheidsbijdrage voor actieve slides. Tijdens luchtremmen neemt sprint-FOV rustig af. De Camera-groepen op de Character-root bevatten de sterkte, tijden en schakelaars met korte uitleg. Zie [de camera-vergelijking](docs/work/T-009.md#vergelijking-voor-de-gebruiker).

Selecteer een Character in de hoofdscene om lichaam, massa, pascurves, beweging en camera in de Inspector te wijzigen. A gebruikt Artemis (75 kg), B lange bovenbenen (90 kg), C lange onderbenen (55 kg). Tab wisselt tussen hen; I geeft dezelfde testimpuls. Open [Character.tscn](game/characters/Character.tscn) om die ene ingang te bekijken. Je kunt deze scene onder `Characters` plaatsen of een bestaande instance dupliceren. Zie [de editor- en speelproef](docs/work/T-011/ground-trial.md).

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
