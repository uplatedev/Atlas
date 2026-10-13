# Artemis — herstelde rig voor T-011

Onderdeel van [T-011](../T-011.md), eigenaar `atlas-T011-20261013-01a1340e`. Dit checkpoint herstelt het aangeleverde model; de capsulemotor en de bestaande speelproef worden hierdoor niet gewijzigd.

## Gebouwd

- [Artemis-rigged.blend](../../../source_assets/characters/Artemis/working/Artemis-rigged.blend) is de bewerkbare werkkopie. Het aangeleverde `Artemis.blend` blijft ongewijzigd; bron-SHA-256 `d64a5403849374566a27a4791e52ce556390486efed3177195f70a3c3a0f3381`. De eerder bewaarde originele FBX en GLB zijn niet overschreven.
- [artemis_rigged.glb](../../../game/assets/characters/artemis_rigged.glb) is de nieuwe runtime-export: één werkelijk geskinnde mesh, vijf oorspronkelijke materialen, 53 deformbotten, geen animatieclips, IK-controls, camera's of lampen. Maximaal zeven bestaande gewichten per vertex blijven via maximaal acht exportinvloeden behouden; de export normaliseert ze.
- [repair_artemis.py](../../../tools/repair_artemis.py) voert het herstel vanuit de oorspronkelijke Blender-bron opnieuw uit, exporteert en maakt optioneel dezelfde controlebeelden. Het script bewaakt de bronhash, verwachte ongewogen vertices en behouden botlengtes.

Gerichte reparaties: de ontbrekende Armature-modifier koppelt de bestaande gewichten daadwerkelijk aan het skelet. De acht ongewogen vertices zijn exact de twee afzonderlijke `Brows`-quads; die krijgen uitsluitend `head` met gewicht 1. De andere vertexgroepen en gewichten zijn behouden, zonder automatische herweging.

Rechts zijn de ontbrekende arm-/been-IK en hand-/voetrotatieconstraints hersteld met de al aanwezige controls. Alleen een tekenflip van de linker pole-angle bleek onjuist: de eigen lokale botassen verschillen. Het script kalibreert de rechter pole-angle daarom tegen de bestaande elleboog-/kniepositie, zonder een deformbot te verplaatsen. Uitkomst: `forearm.r` −2,621794°, `calf.r` 167,803705°. De rechter hand-/voetcontrols volgen de eigen rustoriëntatie; de controlebotlengtes blijven behouden. De maximale afwijking van een deformgewricht in neutrale IK-pose is 0,000000952 m.

De bestaande ontspannen A-rusthouding blijft behouden. Beide restdatasets zijn samen 180° om Blender-Z gedraaid zodat de Y-up-export in Godot naar −Z kijkt. Er is geen schaalfactor, clip of gewijzigde anatomie toegepast. De oorspronkelijke rig heeft kleine links/rechts verschillen in gewrichtsrichting; die zijn niet gladgestreken.

## Runtime-interface en maten

Oorsprong aan de voeten, Godot-Y omhoog, −Z vooruit, schaal 1 en meters. Meshhoogte 1,738555 m, breedte 0,806033 m. De import bevat één `Skeleton3D`; zoek botten bij naam, niet bij index. `hips` is het eerste runtimebot; de niet-vervormende Blender-`root` en alle `IK*`-botten zijn niet geëxporteerd.

| Keten | Namen | Rustlengtes |
| --- | --- | --- |
| Romp | `hips → spine.001 → spine.002 → spine.003 → neck → head`; `jaw` onder `head` | Exacte waarden in het JSON-rapport |
| Arm links/rechts | `shoulder.l/r → upperarm.l/r → forearm.l/r → hand.l/r` | Bovenarm 0,239253 m; onderarm 0,237519 m; hand 0,073730 m |
| Been links/rechts | `thigh.l/r → calf.l/r → foot.l/r → toes.l/r` | Bovenbeen 0,334538 m; onderbeen 0,339238 m; voet 0,123427 m; tenen 0,080533 m |
| Vingers | `thumb`, `index`, `middle`, `ring`, `pinky`, telkens basis + `.001` + `.002`, gevolgd door `.l` of `.r` | Exacte waarden in het JSON-rapport |

De heupgewrichten (`thigh`) liggen op Y 0,755858 m; het `hips`-bot begint op Y 0,694616 m. De enkelgewrichten liggen op Y 0,097054 m. Lees de werkelijke globale rusttransforms voor bereik en IK; neem de naam van een bot niet als maat van het volledige lichaam. Links heeft bij −Z-front negatieve X.

## Technisch gecontroleerd

Blender 5.2.2 LTS en Godot `4.7.2.stable.official.ed1daf0bf` op Windows, 13 oktober 2026. [rig-report.json](rig-report.json) bevat bron/exporthashes, alle rustlengtes en gemeten Blender-meshvervorming. De oorspronkelijke 811 vertices blijven behouden. Export en import hebben aantoonbaar een skinbinding en joints/weights, anders dan de oorspronkelijke exports.

Godot import/start slaagt. [artemis_rig_checks.gd](../../../game/tests/artemis_rig_checks.gd) evalueert de daadwerkelijke geïmporteerde huid met `bake_mesh_from_current_skeleton_pose`, controleert alle gewichtsommen, botlengtes, schaal, oriëntatie en gerichte poses. Hiervoor is een echte renderer nodig; de headless dummy-renderer registreert geen skin. Deze afzonderlijke rigcontrole is daarom geen onderdeel van de headless physicsuites.

[Godot-bewijs](rig-godot-validation.txt), exitcode 0, OpenGL Compatibility: 53 botten, 5 surfaces, 3.110 rendervertices (UV-/normaal-/materiaalgrenzen splitsen de 811 bronvertices). Een rotatie van 35° vervormt per zijde daadwerkelijk 709 rendervertices via de bovenarm, 413 via de hand, 107 via het tweede wijsvingerbot en 364 via de kuit. Hoofdrotatie vervormt 708 rendervertices inclusief de wenkbrauwen. Rustbounds: `(−0,403017; ≈0; −0,252620)` tot `(0,403016; 1,738555; 0,095183)`.

De Blenderbeelden zijn bekeken: [rust](rig-rest.png), [beide armen met IK](rig-arms.png), [beide benen met IK](rig-knees.png), [linkerhand rust](rig-hand-l-rest.png)/[gebogen](rig-hand-l-flex.png), [rechterhand rust](rig-hand-r-rest.png)/[gebogen](rig-hand-r-flex.png). Handen en vingers vervormen mee; de grove bestaande handtopologie en gewichten geven bij sterke buiging hoekige palmplooien. Dat is zichtbaar bewijs, geen acceptatie van definitieve grijpkwaliteit. Er is geen ongefundeerde volledige herweging toegepast. [Godot rust](rig-godot-rest.png) en [Godot gebogen pose](rig-godot-flex.png) bewijzen ook de werkelijke runtimeweergave.

## Herhalen en bewerken

Gebruik de lokaal ingestelde Blender-executable, en geef het oorspronkelijke bronbestand expliciet mee; machinepaden horen niet in Git:

```powershell
& $blenderPath --background --factory-startup --disable-autoexec --python-exit-code 1 --python tools/repair_artemis.py -- --source $artemisSourcePath --render
powershell -NoProfile -ExecutionPolicy Bypass -File tools/Check-Atlas.ps1
& $godotPath --path game --rendering-method gl_compatibility --script res://tests/artemis_rig_checks.gd
```

De laatste controle moet zonder `--headless` draaien. Voeg desgewenst `-- --rig-captures=<absolute-uitvoermap>` toe om de twee Godot-controlebeelden te schrijven. Het Blender-script overschrijft alleen zijn drie afgesproken uitgangen (werkkopie, nieuwe GLB, bewijsbestanden); geef de werkkopie zelf niet als oorspronkelijke bron mee.

Open voor verdere rig-/gewichtsaanpassingen de werkkopie. Arm-/beencontrols zijn `IK_arm.l/r` en `IK_leg.l/r`; hun pole-controls zijn `IKT_arm.l/r` en `IKT_leg.l/r`. De export bevat alleen het resultaat, geen Blender-constraintlogica. Een aangepast model opnieuw als geselecteerde mesh + armature exporteren met alleen deformbotten, rusthouding, skinning, maximaal acht gewichten en zonder animaties/camera's/lampen. Controleer daarna opnieuw de Godot-import en gerichte huidposes. Verander botnamen of restverhoudingen alleen samen met het bijbehorende lichaamsprofiel en de profielcontrole.

## Beoordeling en volgende stap

- **Gebouwd:** bewerkbare herstelde rig, nieuwe GLB/import, reproduceerbaar herstel en afzonderlijke echte skincontrole.
- **Technisch gecontroleerd:** bovenstaande Blender-/Godot-controles en bekeken beelden; geen motorwijziging of multiplayerclaim.
- **Door de gebruiker beoordeeld:** nog geen nieuwe visuele of editorproef beoordeeld. Vooral pols-/vingerbuiging, schouders en uitstraling tijdens de procedurele beweging blijven te bekijken.
- **Volgende stap:** deze export aan de afzonderlijke procedurele presentatie koppelen, rustverhoudingen uit het skelet lezen en de drie humanoïde verhoudingen met dezelfde planner beoordelen.