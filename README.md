# Atlas

Atlas is een nieuw Godot-gameproject. Deze basis bevat een lege startscene en afspraken waarmee we samen verder kunnen bouwen. De gewenste spelwereld, camera en Character-fundering staan nog open.

## Openen en controleren op Windows

Gebruik Godot **4.7.2 Standard**, exact `4.7.2.stable.official.ed1daf0bf`. Pak de [officiële portable Windows-versie](https://godotengine.org/download/archive/4.7.2-stable/) uit en stel eenmalig het enginepad in zoals beschreven in [TESTING](docs/TESTING.md#lokale-engine-instellen).

Voer vanuit deze map in PowerShell uit:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Open-Atlas.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Check-Atlas.ps1
```

De tijdelijke execution policy geldt alleen voor die aanroep. De editor opent [game/project.godot](game/project.godot). Met F5 start je een leeg venster; F8 stopt het project. De controle importeert de bronnen en start de hoofdscene kort zonder venster. Er is nog geen speelbaar Character.

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
