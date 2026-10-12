# Atlas — afspraken voor agents

Atlas is een gameproject van de gebruiker. Help hem een prettige game én een prettige manier van content maken te ontwikkelen. Gewenste speelervaring, menselijke editorbediening en een eenvoudige, uitbreidbare oplossing sturen technische keuzes.

## Begin van een opdracht

1. Lees `README.md`, `docs/CONCEPT.md` en `docs/WORK.md`. Bekijk relevante open inboxpunten. Lees daarna alleen de besluiten, testinstructies en onderwerpnotities die de opdracht nodig heeft.
2. Controleer de echte checkout, branch, lokale wijzigingen en remote. De bedoelde repository is `https://github.com/uplatedev/Atlas`. Controleer bij schrijven de gebruikte GitHub-identiteit en toegang. Een commitnaam of openbare leestoegang bewijst geen authenticatie.
3. Fetch de actuele remote voordat je gedeeld werk kiest of publiceert. Lees daarna de actuele `CONCEPT`, `WORK` en relevante besluiten vanaf `origin/main`; lokale documenten op een werkbranch kunnen achterlopen. Eigen branchnotities zijn nog niet geïntegreerde aanvullingen. Bewaar onvoltooid werk; reset, stash, wissel branches of overschrijf bestanden niet stilzwijgend.
4. Gebruik een eigen fysieke worktree per gelijktijdige schrijver. Gebruik daarnaast, waar nodig, een afzonderlijke worktree voor wijzigingen aan het gedeelde geheugen op main. Deel geen werkdirectory met een andere actieve agent.
5. Controleer de vastgelegde Godot-versie en lokale instellingen. Machinepaden en credentials blijven lokaal. Een verslag van de andere pc is informatie over een eerder moment, geen bewijs van zijn huidige toestand.

## Informatie verwerken zonder administratie voor de gebruiker

De gebruiker mag normaal praten, losse ideeën noemen en van gedachten veranderen. Laat hem geen bestandsnamen, labels of taakformaten invullen.

- `CONCEPT.md` bevat de gewenste ervaring, menselijke werkwijze en overeengekomen grenzen. Het is geen beschrijving van alle bestaande code.
- `WORK.md` is het centrale overzicht van doelen, uitvoerbaar werk, eigenaarschap en open feedback. Geef taken blijvende IDs; hergebruik die niet.
- `INBOX.md` vangt alleen informatie op waarvan betekenis of bestemming nog onduidelijk is. Duidelijke informatie gaat rechtstreeks naar de juiste plaats.
- `IDEAS.md` bevat mogelijkheden zonder uitvoeringsopdracht. Een idee wordt niet door opslag vanzelf een taak.
- `DECISIONS.md` bewaart betekenisvolle keuzes, hun reden, gevolgen en herkomst: door de gebruiker bevestigd, binnen gedelegeerde ruimte gekozen, of nog voorgesteld. Maak vervangen besluiten herkenbaar.
- `TESTING.md` beschrijft hoe iemand controles en menselijke proeven herhaalt. Resultaten van een specifieke taak staan bij die taak.
- Maak `docs/topics/<onderwerp>.md` pas wanneer een onderwerp terugkerende eigen context heeft. Maak `docs/work/<taak-ID>.md` wanneer een actieve taak meer detail nodig heeft dan het werkoverzicht. Deze bestanden linken naar centraal beleid en besluiten; ze krijgen geen eigen inbox of parallelle takenadministratie.

Bewaar nuttige context tijdens de actieve opdracht, uiterlijk vóór een afgeronde werkstap. Verwerk relevante inboxinformatie, voeg herhalingen samen en houd echte onduidelijkheid zichtbaar. Behoud betekenis en nuance; kopieer geen volledige gesprekken zonder reden. Sla geen tokens of andere credentials op in het project.

Gedeeld geheugen is de gepubliceerde versie op main. Nog niet geïntegreerde code en taakresultaten staan op de betreffende gepushte werkbranch. Verwijs naar die branch of commit zodat de gebruiker ze kan vinden. Doe geen uitspraken over verwerking op de achtergrond zonder werkelijk actieve uitvoering.

## Eerst samen de fundering, daarna zelfstandig uitvoeren

Begin bij ieder wezenlijk nieuw systeem met een korte inhoudelijke verkenning. Stel maximaal drie gerichte vragen per ronde, alleen over zaken die de oplossing echt veranderen:

- Wat moet de speler ervaren, en welke overtuigende illusie is voldoende?
- Wat wil de gebruiker zelf plaatsen, instellen, variëren en uitbreiden in de Godot-editor?
- Wat is de kleinste proef die de belangrijkste onzekerheid oplost, inclusief relevant multiplayergedrag?

Beschrijf vervolgens een eenvoudige aanpak, de belangrijkste afweging en wat de proef moet bewijzen. Maak open keuzes expliciet. Begin pas aan de onbesliste fundering nadat de gebruiker die heeft bevestigd. Stilte is geen bevestiging.

Voorkom de Artemis-fout: bouw geen complexe letterlijke simulatie omdat die technisch mogelijk is. Onderzoek eerst of eenvoudige besturing en een overtuigende visuele representatie de gewenste ervaring opleveren. Een capsule met afzonderlijke presentatie is een voorbeeld om te overwegen, geen vooraf verplicht ontwerp voor ieder systeem.

Na bevestiging implementeer je zelfstandig binnen de afgesproken ervaring, editorwerkwijze, scope en kwaliteitsgrenzen. Routinekeuzes vereisen geen nieuwe bevestiging. Bespreek opnieuw wanneer een keuze die grenzen verandert, een nieuwe systeemfundering bepaalt of de gebruiker anders moet leren werken.

## De Godot-editor is onderdeel van het product

Een Character heeft voor de gebruiker één herkenbare ingang, bijvoorbeeld een plaatsbare scene met overzichtelijke instellingen. Interne componenten mogen bestaan, maar hun samenwerking blijft begrijpelijk vanuit die ingang.

- Relevant gedrag en uiterlijk zijn via de editor instelbaar, met bruikbare namen, groepen, defaults en korte uitleg waar nodig.
- Twee instances moeten afzonderlijk instelbaar zijn. Gedeelde Resources mogen individuele aanpassingen niet ongemerkt op alle Characters toepassen.
- De gebruiker kan content plaatsen en variëren zonder daarvoor gewone programmeer- of netwerkhandelingen te moeten verrichten.
- Leg per systeem vast wat een scene bevat, wat veilig aangepast kan worden en hoe de gebruiker nieuwe content maakt.
- Beoordeel de menselijke handelingen met een kleine echte proef. Alleen werkende code is onvoldoende bewijs van een bruikbare editorwerkwijze.

## Feedback en voortgang

Houd bij actief werk vier korte onderdelen bij:

1. **Gebouwd:** wat er daadwerkelijk bestaat en waar het staat.
2. **Technisch gecontroleerd:** welke relevante controle is uitgevoerd, met resultaat en herkenbare bronversie.
3. **Door de gebruiker beoordeeld:** welke ervaring is gespeeld of bekeken, of welke gerichte feedback nog nodig is.
4. **Volgende stap:** de concrete actie en eventuele afhankelijkheid.

Schrijf zinvolle technische tests wanneer ze werkelijk iets bewijzen. Gebruik voor gevoel en uiterlijk een korte menselijke proef wanneer die meer oplevert: wat openen, welke handeling doen, waarop letten, welke versie gebruiken. Een technische controle bewijst geen goed gevoel; menselijke feedback bewijst geen betrouwbare synchronisatie.

Als noodzakelijke feedback ontbreekt, bewaar de vraag en ga verder met ander al afgesproken, onafhankelijk werk. Neem geen onbevestigde keuze als uitgangspunt. Als dat andere werk op is, geef een duidelijke overdracht. Een taak blijft open zolang noodzakelijke acceptatie of controles ontbreken.

## Gelijktijdig werken op pc en laptop

Gebruik GitHub als gedeelde toestand. Een lokale bestandsregel is geen reservering. Een taak wordt pas exclusief geclaimd door een geslaagde publicatie op main:

1. Fetch en lees het actuele `WORK.md` vanaf `origin/main`. Kies alleen afgesproken werk dat vrij is en waarvan afhankelijkheden zijn opgelost.
2. Maak in je eigen administratieve worktree, vanaf precies die main-snapshot, een commit die uitsluitend de taak reserveert. Vermeld taak-ID, unieke agent/sessie-ID, machine, scope en beoogde werkbranch. Houd je claimidentiteit gelijk gedurende deze uitvoering. Gebruik standaard `Smyl3z/<taak-ID>-<korte-naam>`.
3. Push die nieuwe commit met een gewone fast-forward push naar main. Begin uitvoering pas nadat deze push aantoonbaar is geslaagd. Een lokale claim of uitsluitend een werkbranchpush telt niet als reservering.
4. Bij een afgewezen push: fetch opnieuw en lees de taak opnieuw. Is die inmiddels door iemand anders geclaimd, kies ander werk. Is die nog vrij, maak de reservering opnieuw vanaf de nieuwe main-snapshot. Rebase of merge de oude claim nooit blind. Bij een onduidelijke pushuitkomst controleer je op de remote of je eigen claimidentiteit en commit toch gepubliceerd zijn; begin pas wanneer je eigenaarschap aantoonbaar is.
5. Maak daarna de werkbranch en implementeer in een eigen worktree. Voer en integreer de taak alleen wanneer de eigenaar op actuele main overeenkomt met jouw claimidentiteit. Controleer dit en relevante nieuwe afspraken vóór voortgangspushes en integratie. Bij een afwijking stop je dit werk en bewaar je bestaande resultaten.
6. Publiceer stabiele voortgang op de werkbranch. Werk gedeelde status en noodzakelijke context bij via korte administratieve commits vanaf actuele main, met dezelfde regel: bij afwijzing opnieuw lezen en betekenis opnieuw beoordelen.
7. Integreer een klaar resultaat vanaf actuele main. Controleer eigenaarschap, scope, nieuwe besluiten en samenhang. Werk code en bijbehorende context gezamenlijk bij. Gebruik een gewone fast-forward push. Bij concurrente wijzigingen bereid je de integratie opnieuw voor; herhaal controles wanneer die wijzigingen het geteste resultaat beïnvloeden.

Alle agents volgen dit protocol. Zo winnen twee concurrerende reserveringen niet allebei: hun verschillende commits vertrekken vanaf dezelfde main-snapshot en slechts één kan normaal worden gepubliceerd. Er is geen extra lockdienst nodig.

Administratieve main-commits veranderen geen onbesliste gameplay of systeemfundering. Werk mag alleen naar main wanneer de vereiste technische controles én noodzakelijke menselijke beoordeling voor dat resultaat rond zijn. Een nog te beoordelen speelproef mag wel op de werkbranch worden gepusht.

Neem een bezette taak niet automatisch over omdat de eigenaar lang stil is. Gebruik een expliciete overdracht of bevestiging dat de eerdere uitvoering is gestopt; bewaar diens bestaande werk. Zonder bereikbare remote kun je geen nieuwe exclusieve gedeelde taak claimen. Meld problemen met publicatie concreet.

## Zelf checkpoints publiceren

De gebruiker heeft zelfstandige commits, pushes en beheer van benodigde werkbranches toegestaan. Herken een checkpoint zonder daarvoor steeds toestemming te vragen:

- Er is een samenhangende, uitlegbare stap voltooid.
- De relevante controles zijn gedaan of een open beperking is eerlijk vermeld.
- De editorwerkwijze en de toestand van de proef zijn begrijpelijk.
- Noodzakelijke documentatie, assets en overdracht horen bij de wijziging.

Commit en push zo'n stap op de werkbranch, ook als gericht menselijk oordeel nog openstaat. Noem wat aantoonbaar gedeeld is; een mislukte push is geen overdracht naar de andere pc. Start geen nieuw afhankelijk werk op basis van een onbevestigde proef.

Schrijf korte, menselijke commitonderwerpen in het Nederlands, bijvoorbeeld `Character: snelheid per instance instelbaar`. Beschrijf reden en relevante controle in de commitbody wanneer dat helpt. Vermijd inhoudsloze berichten zoals `updates`.

Verwijder eigen taakbranches wanneer hun resultaat veilig is geïntegreerd en er geen nieuw of onovergedragen werk op staat. Controleer daarvoor de actuele remote-head en integratie. Bewaar waardevol onafgerond werk. Verwijder geen main of andermans actieve branch en herschrijf geen bestaande remote-geschiedenis. Verander globale Git-instellingen, repo-beveiliging of accounts niet als neveneffect van projectwerk.

## Multiplayer en herhaalbare proeven

Begin met Windows en het lokale netwerk. Houd verbinding/sessiontoegang gescheiden van gameplayregels en editorinstellingen. Leg voor de eerste proef eigenaarschap, plaatsen/spawnen, individuele instellingen en synchronisatie expliciet vast. Een transportwissel lost die afspraken niet op.

De latere Steam-route is een ontwerpeis. Bouw eerst een kleine concrete LAN-route, geen algemeen framework voor alle toekomstige netwerken. Bewijs vervolgens vroeg met dezelfde beperkte gameplay dat de gekozen Steam-integratie en Windows-export passen. Verifieer actuele Godot/plugincompatibiliteit voordat je versies vastzet; vertrouw niet op een oude tutorial.

Gebruik voor een tweepc-proef dezelfde geselecteerde, schone Windows-testbuild. Toon een herkenbare build-ID/broncommit, Godot-versie en verbindingswijze. Publiceer de broncheckpoint voordat je de proef deelt. Genereer de buildmetadata tijdens export; schrijf niet de toekomstige hash van een commit in diezelfde commit.

Maak starten en verbinden eenvoudig voor de gebruiker en beschrijf de handelingen in `TESTING.md`. De testbuild blijft vast terwijl ontwikkeling op andere branches doorgaat. Houd binaries en lokale configuratie buiten de gewone bronhistorie. Claim geen geslaagde tweepc- of Steam-proef als die niet werkelijk is uitgevoerd.

Steam AppID 480 is een ontwikkelvoorbeeld voor Spacewar, geen definitieve Atlas-identiteit. Bewaar projectidentiteit en versiecontrole daarnaast expliciet. Voor gelijktijdige Steam-proeven moeten de twee spelers verschillende Steam-accounts gebruiken.

## Afsluiten of overdragen

Werk de vaste informatieplekken bij, publiceer het geschikte checkpoint en geef een korte menselijke terugkoppeling: wat klaar is, wat is gecontroleerd, wat de gebruiker kan proberen en wat nog openstaat. Verwijs naar echte bestanden, branches en commits. Bewaar voldoende context om op de andere machine verder te gaan zonder dit gesprek opnieuw te reconstrueren.
