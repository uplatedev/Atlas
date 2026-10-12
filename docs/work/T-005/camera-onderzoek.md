# Camera: vloeiend volgen en kleine vertraging

Godots [camera-interpolatiehandleiding](https://docs.godotengine.org/en/4.7/tutorials/physics/interpolation/advanced_physics_interpolation.html) ondersteunt de bestaande basis: volg de weergegeven lichaamspositie in `_process`, los van directe muiskijkrichting en een bewegende parent. De [4.7 SpringArm-bron](https://raw.githubusercontent.com/godotengine/godot/4.7-stable/scene/3d/physics/spring_arm_3d.cpp) schrijft op iedere physics-tick ook de globale transform van zijn kinderen. Daarom beheert de rig nu zelf uitsluitend in het renderframe de camera, inclusief de volledige bolvolumechecks; SpringArm blijft de scene-ingang voor mask, marge en vorm.

De rechtuitmeting op 40 m/s was vóór de aanpassing al vloeiend op 30/60/144 renderframes bij physics60. De valmeting vond wél een concrete fout: maximum ooghoogte werd begrensd met ruwe physics-Y. Daardoor volgde de camera tijdens vallen de physics-stappen. Het verschil met de geïnterpoleerde positie daalde na de correctie van maximaal 0.874 m naar 0.0000032 m. Resterende stilstaande frames zijn na landing. Dit bewijst de beschreven verticale fout; het verklaart niet automatisch alle ervaren schokkerigheid.

Voor de kleine horizontale aanhechting gebruikt de rig een exacte eerste-ordefilter voor een lineair bewegend doel: halveringstijd 0.018 s, maximaal 0.12 m extra achterstand. Bij 2 m/s meet de gerichte proef op 30/60/144 updates dezelfde 0.051937 m. First person heeft standaard 0 s extra vertraging. De lookrotatie is onafhankelijk en direct. De extra achterstand wordt met een volumecheck beperkt bij muren. Een onveilige oude pose valt terug op de actuele veilige oogpositie. Reset en Tab wissen volgachterstand.

Sneak/kruip/lig hebben aanvankelijk -2/-3/-5 graden verticale FOV ten opzichte van de gekozen first-/third-personbasis. Ze gebruiken dezelfde zachte FOV-overgang en nemen geen eerdere sprintbonus mee. F4 schakelt snelheid én houdingsveranderingen van de FOV uit. Dit zijn afstelbare beginwaarden, geen bewijs van prettig gevoel.

Bewijs: [voor](camera-measurements-before.txt), [na](camera-measurements-after.txt), [gerichte controles](camera-validation.txt).

Herhalen met de vastgelegde console-engine, vanuit een gewenste broncheckout:

```powershell
. .\tools\Atlas-Engine.ps1
$atlasEngine = Get-AtlasEngine
$atlasGame = (Resolve-Path .\game).Path
$atlasProbe = (Resolve-Path .\docs\work\T-005\camera_position_probe.gd).Path
& $atlasEngine --headless --path $atlasGame --script $atlasProbe -- --fps=144 --scenario=fall
& $atlasEngine --headless --path $atlasGame --script $atlasProbe -- --fps=30 --scenario=straight
& $atlasEngine --headless --path $atlasGame --script (Resolve-Path .\docs\work\T-005\camera_refinement_checks.gd).Path
```

Gebruik voor vergelijking exact dezelfde probe tegen T-004-bron `49d62546` en de T-005-bron; een extra proefworktree voorkomt het wijzigen van de vaste lokale speelversie. De helpers schrijven alleen testuitvoer naar stdout. Realtime frames hebben kleine deltaschommelingen, dus niet iedere herhaling heeft identieke laatste decimalen. De gerichte filterproef gebruikt expliciete 30/60/144 update-delta en is daardoor exact vergelijkbaar.
