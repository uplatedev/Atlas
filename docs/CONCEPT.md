# Concept van Atlas

Bron: door de gebruiker opgedragen masterprompt, agentafspraken en Character-bespreking met vervolgantwoorden, 12 oktober 2026. Dit document beschrijft de gewenste ervaring en werkwijze; bestaande code staat er niet automatisch als ontwerpbesluit in.

## Vaststaande uitgangspunten

- Atlas moet prettig zijn om te spelen én om zelf content voor te maken.
- De gebruiker praat vrijuit over doelen, ideeën en ervaringen. Agents onderhouden bruikbaar geheugen zonder administratiewerk terug te leggen bij hem.
- De Godot-editor is onderdeel van het product. Een Character heeft één herkenbare ingang: plaatsen, aanklikken en begrijpelijk instellen. Interne samenwerking blijft overzichtelijk vanuit die ingang.
- De gebruiker moet een testbaar checkpoint direct vanuit zijn vaste lokale Atlas-map kunnen proberen. De uitvoerende agent houdt die testplek bij per opgeleverd checkpoint, inclusief nog te beoordelen werkbranchproeven, en bewaart gebruikerswijzigingen. De gebruiker hoeft geen worktrees of branches te beheren. Dit is onderdeel van actieve uitvoering, geen ongevraagde achtergrondsynchronisatie.
- Characters, vrienden en blokken moeten plaatsbaar en varieerbaar worden zonder gewone programmeerhandelingen of losse netwerkcode.
- Twee instances kunnen onafhankelijk verschillen. Gedeelde Resources mogen een individuele wijziging niet ongemerkt op andere Characters toepassen.
- Bij een wezenlijk nieuw systeem eerst samen ervaring, editorbediening en kleinste bewijsbare proef bespreken. Na bevestiging bouwen agents zelfstandig binnen de afgesproken grenzen.
- Technische tests bewijzen techniek; korte menselijke proeven beoordelen gevoel en uiterlijk. Beide soorten bewijs blijven herkenbaar.
- De twee computers draaien Windows. GitHub verbindt hun projecttoestand; een verslag maakt de andere computer niet bereikbaar of actueel.

## Les uit Artemis

Bewegingsvrijheid was belangrijk in het vorige hobbyproject Artemis. Daar werd bij klimmen te vroeg ingezet op IK-solvers en fysieke reacties. Voor Atlas onderzoeken we eerst welke eenvoudige besturing en overtuigende visuele voorstelling de gewenste ervaring opleveren. Een capsule langs geometrie was bij de bootstrap alleen een voorbeeld. De gebruiker heeft de capsule inmiddels voor de eerste Character-proef gekozen; daarmee is nog geen klimsysteem gekozen.

## Eerste latere proef

Twee Characters in dezelfde scène, ieder via de editor afzonderlijk instelbaar, waaronder snelheid, acceleratie en deceleratie. Die scène moet gelijktijdig op beide Windows-computers speelbaar worden, met behoud van de individuele instellingen. Eerst via LAN, daarna vroeg een beperkte Steamproef met dezelfde gameplay en editorwerkwijze. Zie [TESTING](TESTING.md#latere-proeven-nog-niet-uitgevoerd).

## Eerste Character en proeflevel

De gebruiker heeft voor de eerste proef een capsule gekozen, met een instelbare naam boven het hoofd. De camera begint in third person en kan met instelbaar scrollzoomen naar first person; de eigen capsule mag het zicht daar niet blokkeren. Het Character draait horizontaal met de camera mee. WASD beweegt, de muis kijkt, Shift vasthouden sprint en spatie springt.

Lopen en sprinten hebben afzonderlijk instelbare snelheid, acceleratie en afremming. Vooruit is sneller dan zijwaarts, zijwaarts sneller dan achteruit; ook sprinten mag in alle richtingen met die lagere zij-/achterwaartse snelheden. Gecombineerde input mag geen extra snelheid opleveren. Een debugweergave maakt de richting zichtbaar en de opstaphoogte is instelbaar.

Een stilstaande sprong gaat hoog, een lopende sprong zit ertussenin en een sprintsprong blijft laag maar gaat extra ver. De werkelijke snelheid bij het afzetten bepaalt de sprong; er is beperkte luchtsturing.

Het proeflevel heeft twee lampen met edge-/fillfunctie, echte prototype-textures met afstandsmarkeringen op vloeren en muren en een skybox rond zonsondergang. De eerste uitvoering staat op de T-002-werkbranch en wacht op beoordeling van gevoel en editorbediening. De gedetailleerde werkwijze, instellingen en assetbronnen staan in [Character en proeflevel](topics/character.md); resultaten en beperkingen staan in WORK.

### Vervolg na de eerste speelervaring

De gebruiker vraagt korte uitleg bij iedere instelbare eigenschap en afzonderlijke draaisnelheden per bewegingsstaat. De camera kijkt direct; het lichaam draait begrensd bij. Sneak krijgt eigen instellingen en een lage sprong voor een hoger opstapje. De laatste besturingskeuze is Ctrl voor kruipen aan/uit en Shift voor sprint; Alt voor sneak is bevestigd. Later moet vasthouden versus aan/uit een setting worden. Kruipen gebruikt voorlopig een kortere verticale capsule, liggen een horizontale capsule. Beide krijgen eigen bewegings- en vorminstellingen. De aanvankelijke proef gebruikte alleen aangrenzende houdingen; de nieuwe T-005-keuze hieronder vervangt die beperking voor handmatig Z.

Bij een geldige opstap automatisch lager worden als de huidige vorm niet past. Na de doorgang automatisch de hoogste veilige houding herstellen, met behoud van een handmatig gekozen kruip-/lighouding. De arena krijgt gerichte doorgangen om dit te proberen. De gemelde stapeling van sprintsprongsnelheid is in de bestaande proef gereproduceerd en moet worden verholpen.

De gebruiker heeft na het grondige movement-/cameraonderzoek het [T-003-voorstel](work/T-003.md) bevestigd voor implementatie. De volgende proef gebruikt geleidelijk krachtverlies bij herhaald springen, grondherstel, lichaamsrelatieve WASD, Alt voor sneak en Z voor liggen. De concrete waarden blijven afstelbare proefdefaults. Uitvoering en resultaten staan in [T-004](work/T-004.md).

Hoofd-/kijkrichting en lichaamsrichting worden afzonderlijk bijgehouden voor een later zelfstandig bewegend hoofd. De hoofddraai ten opzichte van het lichaam is begrensd; bij die grens moet cameradraai afremmen. Dit vervangt geheel vrij rondkijken als het lichaam niet verder kan draaien. Binnen het bereik blijft kijken direct. Bij stilstand volgt het lichaam pas als de hoofdhoek te groot dreigt te worden; bij beweging draait het met de ingestelde limiet naar de kijkrichting.

Na de T-004-speelproef verfijnt T-005 de bediening en het gevoel. Ctrl kiest kruip; Z kiest handmatig lig, ook rechtstreeks vanuit staan. Eén spatie brengt handmatig lig veilig terug naar de voorgaande eigen houding: staan→lig keert direct naar staan terug, kruip→lig naar kruip. Gewone kruip richt met spatie op naar staan; oprichtinput springt niet tegelijk. Automatisch verlagen gaat opeenvolgend: staan → kruip → lig. Ook automatisch kruip mag bij een lagere doorgang verder naar lig; rechtstreeks automatisch staan → lig blijft uitgesloten. Na de doorgang herstelt de hoogste veilige houding, met behoud van een handmatige kruip-/ligkeuze. Deze laatste feedback vervangt de eerdere beperking tot handmatig kruip.

Sprongafstand moet ook bij een korte aanloop op echte snelheid berusten; vrijwel gelijktijdig Shift/W/spatie mag geen volle sprintafstand geven. De sprintbonus wordt kleiner. Kruip of lig kiezen in de lucht bewaart de vluchtvaart. Alleen handmatig Ctrl-kruip tijdens de sprong bereidt bij landing een slide voor, met de overgebleven vaart en instelbare wrijving, duur en beperkte sturing. De slide geeft geen boost en is een aparte beweging: na afloop automatisch staan, of kruipen zolang de ruimte staan verhindert. Een expliciet gekozen lage houding blijft bewaard. De gebruiker vraagt minder wrijving en langer doorsliden, zodat meer landingsvaart behouden blijft. Z-lig en Ctrl op de grond starten geen slide. Tegeninput, bij een voorwaartse sprong S, kan de luchtvaart geleidelijk terugnemen om dichterbij te landen; S kan de slide extra afremmen. Dit vervangt de precisie-stop. A/D en camera geven lichte luchtsturing. Kruip en lig worden sneller. FOV reageert ook op sneak/kruip/lig en de camera krijgt een nauwelijks voelbare, instelbare positievertraging. Bij abrupt stoppen na snelle beweging mag de camera heel licht doorschieten en terugveren; het effect blijft klein en instelbaar. Haperingen en schuine/verhoogde lage doorgangen worden technisch onderzocht en daarna opnieuw lokaal beoordeeld.

Een nieuwe spatie tijdens een actieve slide mag die onderbreken met een echte sprong vanuit de overgebleven vaart. Deze sprong voegt geen horizontale bonus toe en gebruikt de bestaande snelheidsafhankelijke spronghoogte en vermoeidheid. Alleen veilig oprichten laat de poging doorgaan; blokkade mag geen onverwachte latere sprong veroorzaken.

## Afgeronde bootstrap

Alleen werkstructuur, volledige [agentafspraken](../AGENTS.md), een lege werkende Godot-basis en kleine open-/controlehulpmiddelen. Geen Character, bewegingscontroller, networking, IK, klimmechaniek, Steam-integratie, lobby, netwerkabstractie of multiplayerlauncher. Ook geen lege gameplaycomponenten als voorschot.

## Nog open

De verdere spelwereld en mechanics staan open. De exacte waarden en het gevoel van de afgesproken beweging, sprongen en camera worden met een kleine lokale proef afgestemd. Eigenaarschap, spawnen en precieze synchronisatie moeten vóór de LAN-implementatie expliciet worden afgesproken. De eerste proef blijft daarom lokaal. Voortgang en afhankelijkheden staan in [WORK](WORK.md); voorstellen voor latere systemen worden niet stilzwijgend besluiten.
