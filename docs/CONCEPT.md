# Concept van Atlas

Bron: door de gebruiker opgedragen masterprompt en agentafspraken, 12 oktober 2026. Dit document beschrijft de gewenste ervaring en werkwijze; bestaande code staat er niet automatisch als ontwerpbesluit in.

## Vaststaande uitgangspunten

- Atlas moet prettig zijn om te spelen én om zelf content voor te maken.
- De gebruiker praat vrijuit over doelen, ideeën en ervaringen. Agents onderhouden bruikbaar geheugen zonder administratiewerk terug te leggen bij hem.
- De Godot-editor is onderdeel van het product. Een Character heeft één herkenbare ingang: plaatsen, aanklikken en begrijpelijk instellen. Interne samenwerking blijft overzichtelijk vanuit die ingang.
- Characters, vrienden en blokken moeten plaatsbaar en varieerbaar worden zonder gewone programmeerhandelingen of losse netwerkcode.
- Twee instances kunnen onafhankelijk verschillen. Gedeelde Resources mogen een individuele wijziging niet ongemerkt op andere Characters toepassen.
- Bij een wezenlijk nieuw systeem eerst samen ervaring, editorbediening en kleinste bewijsbare proef bespreken. Na bevestiging bouwen agents zelfstandig binnen de afgesproken grenzen.
- Technische tests bewijzen techniek; korte menselijke proeven beoordelen gevoel en uiterlijk. Beide soorten bewijs blijven herkenbaar.
- De twee computers draaien Windows. GitHub verbindt hun projecttoestand; een verslag maakt de andere computer niet bereikbaar of actueel.

## Les uit Artemis

Bewegingsvrijheid was belangrijk in het vorige hobbyproject Artemis. Daar werd bij klimmen te vroeg ingezet op IK-solvers en fysieke reacties. Voor Atlas onderzoeken we eerst welke eenvoudige besturing en overtuigende visuele voorstelling de gewenste ervaring opleveren. Een capsule langs geometrie is een mogelijk voorbeeld, geen al gekozen Character-ontwerp.

## Eerste latere proef

Twee Characters in dezelfde scène, ieder via de editor afzonderlijk instelbaar, waaronder snelheid, acceleratie en deceleratie. Die scène moet gelijktijdig op beide Windows-computers speelbaar worden, met behoud van de individuele instellingen. Eerst via LAN, daarna vroeg een beperkte Steamproef met dezelfde gameplay en editorwerkwijze. Zie [TESTING](TESTING.md#latere-proeven-nog-niet-uitgevoerd).

## Grens van de bootstrap

Alleen werkstructuur, volledige [agentafspraken](../AGENTS.md), een lege werkende Godot-basis en kleine open-/controlehulpmiddelen. Geen Character, bewegingscontroller, networking, IK, klimmechaniek, Steam-integratie, lobby, netwerkabstractie of multiplayerlauncher. Ook geen lege gameplaycomponenten als voorschot.

## Nog open

Spelwereld, camera, 2D/3D-besturing, bewegingsgevoel, verdere mechanics en Character-architectuur. Ook eigenaarschap, spawnen en precieze synchronisatie moeten voor de eerste multiplayerproef expliciet worden afgesproken. De neutrale root van de lege scene beslist hierover niets. De bespreking staat in [WORK](WORK.md#t-001--character-fundering-bespreken); voorstellen worden pas na bevestiging uitgangspunten.
