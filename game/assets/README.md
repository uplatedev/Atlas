# Geïmporteerde proefassets

Bronnen gecontroleerd en gedownload op 12 oktober 2026. Dit zijn bestaande rasterbestanden, geen in code gegenereerde strepen. De gekozen bestanden zijn ongewijzigd overgenomen; alleen de lokale naam is verduidelijkt.

## Prototype-textures

Maker: Kenney. Pack **Prototype Textures 1.0**, uitgegeven 8 april 2020. [Officiële assetpagina](https://kenney.nl/assets/prototype-textures), [officiële download](https://kenney.nl/media/pages/assets/prototype-textures/a88c69fa18-1677578307/kenney_prototype-textures.zip). Licentie **CC0 1.0**, originele packtekst: [Kenney-LICENSE.txt](prototype/Kenney-LICENSE.txt).

| Lokaal bestand | Origineel in pack | Grootte | SHA-256 |
| --- | --- | --- | --- |
| `prototype/kenney_dark_grid.png` | `PNG/Dark/texture_02.png` | 1024 × 1024 | `1fedc9bd7ca804d1543900dfe2a8ddb3c98a5367baab5230acbadc0f337438d6` |
| `prototype/kenney_light_grid.png` | `PNG/Light/texture_02.png` | 1024 × 1024 | `72bb9b3cb2743de3f0eaba2188c931370085572e627168821310008f46dafccd` |
| `prototype/kenney_orange_grid.png` | `PNG/Orange/texture_02.png` | 1024 × 1024 | `2feb000e710018176b7df63ab6a7a19e38ef9b22b2367267c7758b88a6e044f8` |

`texture_02` heeft hoofdstrepen aan de rand en halverwege de afbeelding: twee hoofdvakken per volledige texturebreedte. In `PrototypeLevel.tscn` gebruikt ieder rastermateriaal world-space triplanar mapping met `uv1_scale = Vector3(0.5, 0.5, 0.5)`: de volledige texture herhaalt iedere **2 meter**, waardoor ieder hoofdvak **1 meter** is. De dunste onderverdeling is **0.25 meter**. Diezelfde instelling op vloer, muren en treden houdt de schaal gelijk bij verschillende BoxMesh-afmetingen; de UVs worden niet uitgerekt tot de afmetingen van één box. Godot-eenheid is hier één meter.

## Sunset-panorama

**Belfast Sunset (Pure Sky)** van Poly Haven. Fotografie Dimitrios Savva, verwerking Greg Zaal, sky-bewerking Jarod Guest. [Officiële assetpagina](https://polyhaven.com/a/belfast_sunset_puresky), [bestandsmetadata](https://api.polyhaven.com/files/belfast_sunset_puresky), [CC0-licentieverklaring](https://polyhaven.com/license). De CC0-tekst is lokaal bewaard in [CC0-1.0.txt](sky/CC0-1.0.txt), afkomstig van [Creative Commons](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt).

Bestand: `sky/belfast_sunset_puresky_2k.hdr`, 2048 × 1024, **4.563.204 bytes**. [Officiële download](https://dl.polyhaven.org/file/ph-assets/HDRIs/hdr/2k/belfast_sunset_puresky_2k.hdr).

- SHA-256: `273003109ca1cfb798ce6b96e09ac8440f763d0ef0c376bbe77492613540b4a3`
- MD5: `4bb56d6163ef1c7ec762e4a7ef8ede81`, gelijk aan de officiële Poly Haven-bestandsmetadata.

`WorldEnvironment` gebruikt dit echte HDR-panorama via `PanoramaSkyMaterial`. Het levert de zonsondergang en zachte omgevingsverlichting. De scene bevat precies twee lampen: de warme `EdgeLight` en de koele `FillLight`.

## Level aanpassen in de editor

Open `game/levels/PrototypeLevel.tscn`. `Floor` ligt met de bovenkant op y=0; één scene-eenheid is één meter. De vier named `Step`-nodes hebben ieder een eigen BoxMesh en BoxShape3D met gelijke afmetingen. Wie een trede aanpast, past de hoogte van beide resources én de halve hoogte als y-positie aan. De opstapwaarden staan in de namen en labels; pas die mee aan.

De `JumpMeasure`-labels staan iedere twee meter langs de vrije baan vanaf z=6 naar -Z. Dit is een afstandsreferentie, geen vooraf gemeten sprongafstand. `LowClearance` heeft een plafondonderkant op 1.95 m; boven de 0.30 m-opstap blijft 1.65 m vrije hoogte over. Zo kan de Character-proef ook controleren of de capsule genoeg hoofdruimte heeft.

De named lampen, `WorldEnvironment`, meshes, botsingsvormen en Label3D-teksten zijn gewone editorcontent. Er is geen levelscript nodig. De Characters, camera en spel-UI worden door de hoofdscene geplaatst.
