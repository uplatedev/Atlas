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

## Afgeronde bootstrap

Alleen werkstructuur, volledige [agentafspraken](../AGENTS.md), een lege werkende Godot-basis en kleine open-/controlehulpmiddelen. Geen Character, bewegingscontroller, networking, IK, klimmechaniek, Steam-integratie, lobby, netwerkabstractie of multiplayerlauncher. Ook geen lege gameplaycomponenten als voorschot.

## Nog open

De verdere spelwereld en mechanics staan open. De exacte waarden en het gevoel van de afgesproken beweging, sprongen en camera worden met een kleine lokale proef afgestemd. Eigenaarschap, spawnen en precieze synchronisatie moeten vóór de LAN-implementatie expliciet worden afgesproken. De eerste proef blijft daarom lokaal. Voortgang en afhankelijkheden staan in [WORK](WORK.md); voorstellen voor latere systemen worden niet stilzwijgend besluiten.
