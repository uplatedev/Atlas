"""Repair the supplied Artemis rig without changing the original .blend.

Run with Blender 5.2.2:
  blender --background --factory-startup --disable-autoexec --python tools/repair_artemis.py -- --source /path/to/Artemis.blend --render
Outputs are relative to this repository; the source must be a separate file.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / "source_assets/characters/Artemis/working/Artemis-rigged.blend"
EXPORT = ROOT / "game/assets/characters/artemis_rigged.glb"
EVIDENCE = ROOT / "docs/work/T-011"
EYEBROWS = {305, 306, 307, 308, 697, 698, 699, 700}


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def update():
    bpy.context.view_layer.update()


def reset_pose(armature, constraints=True):
    for bone in armature.pose.bones:
        bone.matrix_basis = Matrix.Identity(4)
        for constraint in bone.constraints:
            constraint.mute = not constraints
    update()


def vertices(mesh):
    update()
    evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
    return [evaluated.matrix_world @ vertex.co for vertex in evaluated.data.vertices]


def measure_deformation(mesh, armature):
    """Use actual evaluated Armature-modifier output, not joint transforms alone."""
    reset_pose(armature, False)
    baseline = vertices(mesh)
    result = {}
    for name in ["upperarm.l", "upperarm.r", "hand.l", "hand.r", "index.001.l", "index.001.r", "calf.l", "calf.r", "head"]:
        reset_pose(armature, False)
        armature.pose.bones[name].rotation_quaternion = Quaternion((1, 0, 0), math.radians(35))
        moved = [(a - b).length for a, b in zip(vertices(mesh), baseline)]
        result[name] = {"moved_vertices": sum(value > 0.00001 for value in moved), "maximum_m": max(moved)}
        assert result[name]["moved_vertices"] >= 4 and result[name]["maximum_m"] > 0.005, (name, result[name])
    reset_pose(armature)
    return result


def copy_right_constraints(armature):
    pairs = [("forearm.l", "forearm.r"), ("hand.l", "hand.r"), ("calf.l", "calf.r"), ("foot.l", "foot.r")]
    for left_name, right_name in pairs:
        source = armature.pose.bones[left_name].constraints
        target = armature.pose.bones[right_name].constraints
        assert not target, f"Expected missing right constraints: {right_name}"
        for original in source:
            copied = target.new(original.type)
            for prop in original.bl_rna.properties:
                key = prop.identifier
                if prop.is_readonly or key in {"rna_type", "type", "is_override_data", "active"}:
                    continue
                try:
                    setattr(copied, key, getattr(original, key))
                except (AttributeError, TypeError):
                    pass
            copied.subtarget = original.subtarget.replace(".l", ".r")
            if copied.type == "IK":
                copied.pole_subtarget = original.pole_subtarget.replace(".l", ".r")
                copied.pole_angle = -original.pole_angle
    update()


def calibrate_controls(armature):
    # Control bones do not deform the mesh. Align the missing right-hand/foot
    # authoring controls to their own rest joints, retaining each control length.
    bpy.context.view_layer.objects.active = armature
    armature.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for part, target in [("hand.r", "IK_arm.r"), ("foot.r", "IK_leg.r")]:
        control = armature.data.edit_bones[target]
        length = control.length
        control.matrix = armature.data.edit_bones[part].matrix.copy()
        control.length = length
    bpy.ops.object.mode_set(mode="OBJECT")
    reset_pose(armature)
    angles = {}
    # Mirrored local bone axes have different rolls. Fit only the pole angle
    # against the existing elbow/knee position; never move a deform rest bone.
    for name in ["forearm.r", "calf.r"]:
        bone = armature.pose.bones[name]
        constraint = next(c for c in bone.constraints if c.type == "IK")
        wanted = armature.data.bones[name].head_local.copy()
        def error(angle):
            constraint.pole_angle = (angle + math.pi) % (2 * math.pi) - math.pi
            update()
            return (bone.head - wanted).length_squared
        step = math.tau / 72
        best = min((-math.pi + index * step for index in range(72)), key=error)
        low, high = best - step, best + step
        for _ in range(30):
            left = low + (high - low) / 3
            right = high - (high - low) / 3
            if error(left) <= error(right):
                high = right
            else:
                low = left
        error((low + high) / 2)
        angles[name] = math.degrees(constraint.pole_angle)
    reset_pose(armature)
    residual = max((bone.head - bone.bone.head_local).length for bone in armature.pose.bones if bone.bone.use_deform)
    assert residual < 0.00002, f"Authoring IK changes neutral rest pose: {residual}m"
    return {"right_pole_angles_degrees": angles, "neutral_joint_max_error_m": residual}

def inspect_glb(path):
    data = path.read_bytes()
    size = struct.unpack_from("<I", data, 12)[0]
    gltf = json.loads(data[20:20 + size])
    nodes = gltf["nodes"]
    meshes = [node for node in nodes if "mesh" in node]
    assert len(meshes) == 1 and "skin" in meshes[0], "Export has no bound skin"
    primitives = gltf["meshes"][0]["primitives"]
    assert all("JOINTS_0" in primitive["attributes"] and "WEIGHTS_0" in primitive["attributes"] for primitive in primitives)
    names = [nodes[index]["name"] for index in gltf["skins"][0]["joints"]]
    assert not any(name.startswith("IK") for name in names), names
    assert not gltf.get("cameras") and not gltf.get("animations")
    return {"joints": names, "joint_count": len(names), "primitive_count": len(primitives), "skin_bound": True, "animations": 0, "cameras": 0}


def aim(object, target):
    object.rotation_euler = (Vector(target) - object.location).to_track_quat("-Z", "Y").to_euler()


def render_setup():
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 1000
    scene.render.resolution_y = 1000
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.dither_intensity = 0.0
    scene.view_settings.view_transform = "Standard"
    scene.world = bpy.data.worlds.new("Rig audit world")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.19, 0.21, 0.25, 1)
    scene.world.node_tree.nodes["Background"].inputs[1].default_value = 0.7
    for name, location, energy, size in [("Audit key", (-3, 4, 5), 500, 4), ("Audit fill", (3, 1, 3), 250, 3), ("Audit rim", (0, -3, 4), 350, 3)]:
        data = bpy.data.lights.new(name, "AREA")
        data.energy = energy
        data.shape = "DISK"
        data.size = size
        light = bpy.data.objects.new(name, data)
        scene.collection.objects.link(light)
        light.location = location
        aim(light, (0, 0, 0.9))
    data = bpy.data.cameras.new("Audit camera")
    camera = bpy.data.objects.new("Audit camera", data)
    scene.collection.objects.link(camera)
    data.type = "ORTHO"
    scene.camera = camera
    return camera


def render_pose(camera, name, target=(0, 0, 0.87), location=(2.4, 5, 2.1), scale=2.05):
    camera.location = location
    camera.data.ortho_scale = scale
    aim(camera, target)
    update()
    bpy.context.scene.render.filepath = str(EVIDENCE / f"rig-{name}.png")
    bpy.ops.render.render(write_still=True)


def rotate_world_axis(armature, name, axis, degrees):
    local_axis = armature.data.bones[name].matrix_local.to_3x3().inverted() @ Vector(axis)
    armature.pose.bones[name].rotation_quaternion = Quaternion(local_axis.normalized(), math.radians(degrees))


def render_checks(mesh, armature):
    camera = render_setup()
    reset_pose(armature)
    render_pose(camera, "rest")
    for side, sign in [("l", -1), ("r", 1)]:
        control = armature.pose.bones[f"IK_arm.{side}"]
        control.matrix = Matrix.Translation((sign * 0.025, 0.22, 0.20)) @ control.matrix
    update()
    render_pose(camera, "arms")
    reset_pose(armature)
    for side in ["l", "r"]:
        control = armature.pose.bones[f"IK_leg.{side}"]
        control.matrix = Matrix.Translation((0, 0.16, 0.14)) @ control.matrix
    update()
    render_pose(camera, "knees", location=(3.5, 4, 1.8))
    for side, inward in [("l", 1), ("r", -1)]:
        reset_pose(armature, False)
        hand = armature.data.bones[f"hand.{side}"]
        target = (hand.head_local + hand.tail_local) / 2 + Vector((0, 0, -0.045))
        location = target + Vector((inward * 0.7, 1, 0.20))
        render_pose(camera, f"hand-{side}-rest", target, location, 0.34)
        rotate_world_axis(armature, f"hand.{side}", (0, -inward, 0), 15)
        for finger in ["index", "middle", "ring", "pinky"]:
            rotate_world_axis(armature, f"{finger}.001.{side}", (0, -inward, 0), 55)
            rotate_world_axis(armature, f"{finger}.002.{side}", (0, -inward, 0), 35)
        render_pose(camera, f"hand-{side}-flex", target, location, 0.34)
    reset_pose(armature)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--render", action="store_true")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    source = args.source.resolve()
    assert source != WORK.resolve(), "Never overwrite the input source"
    source_hash = sha256(source)
    bpy.ops.wm.open_mainfile(filepath=str(source), use_scripts=False)
    mesh = bpy.data.objects["Artemis"]
    armature = bpy.data.objects["Armature"]
    assert mesh.type == "MESH" and armature.type == "ARMATURE"
    assert not mesh.modifiers, "Unexpected source modifiers; inspect before repair"
    assert all(max(abs(value) for row in (bone.matrix_basis - Matrix.Identity(4)) for value in row) < 0.00001 for bone in armature.pose.bones), "Expected neutral source pose"
    lengths = {bone.name: bone.length for bone in armature.data.bones}
    missing = {vertex.index for vertex in mesh.data.vertices if not any(group.weight > 0 for group in vertex.groups)}
    assert missing == EYEBROWS, f"Unexpected unweighted vertices: {missing}"
    eyebrow_faces = [polygon for polygon in mesh.data.polygons if any(index in missing for index in polygon.vertices)]
    assert len(eyebrow_faces) == 2 and all(set(polygon.vertices).issubset(missing) and mesh.material_slots[polygon.material_index].name == "Brows" for polygon in eyebrow_faces)
    mesh.vertex_groups["head"].add(sorted(missing), 1.0, "REPLACE")
    modifier = mesh.modifiers.new("Artemis skin", "ARMATURE")
    modifier.object = armature
    modifier.use_vertex_groups = True
    modifier.use_bone_envelopes = False
    # The source faces Blender -Y. Bake one 180-degree Z rotation into both
    # rest data sets so the GLB Y-up conversion yields Godot -Z forward.
    rotation = Matrix.Rotation(math.pi, 4, "Z")
    mesh.data.transform(rotation)
    armature.data.transform(rotation)
    copy_right_constraints(armature)
    authoring_controls = calibrate_controls(armature)
    assert all(abs(bone.length - lengths[bone.name]) < 0.000001 for bone in armature.data.bones), "Rest lengths changed"
    max_influences = max(sum(group.weight > 0 for group in vertex.groups) for vertex in mesh.data.vertices)
    assert max_influences <= 8, f"More than eight influences need explicit export policy: {max_influences}"
    deformation = measure_deformation(mesh, armature)
    report = {"blender": bpy.app.version_string, "source_name": source.name, "source_sha256": source_hash, "mesh_vertices": len(mesh.data.vertices), "unweighted_vertices_before": sorted(missing), "unweighted_vertices_after": 0, "repaired_parts": "Two Brows quads assigned to head; modifier; mirrored right arm/leg constraints", "max_influences": max_influences, "forward": "Godot -Z; Blender +Y", "height_m": max(vertex.co.z for vertex in mesh.data.vertices) - min(vertex.co.z for vertex in mesh.data.vertices), "rest_lengths_m": lengths, "evaluated_deformation": deformation, "authoring_controls": authoring_controls}
    for output in [WORK, EXPORT, EVIDENCE / "rig-report.json"]:
        output.parent.mkdir(parents=True, exist_ok=True)
    # Save the useful authoring rig before creating diagnostic lights/cameras.
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1.0
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(WORK), check_existing=False)
    bpy.ops.object.select_all(action="DESELECT")
    mesh.select_set(True)
    armature.select_set(True)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.export_scene.gltf(filepath=str(EXPORT), export_format="GLB", use_selection=True, export_cameras=False, export_lights=False, export_animations=False, export_skins=True, export_def_bones=True, export_leaf_bone=False, export_rest_position_armature=True, export_influence_nb=8, export_yup=True, export_materials="EXPORT")
    report["export"] = inspect_glb(EXPORT)
    report["export_sha256"] = sha256(EXPORT)
    if args.render:
        render_checks(mesh, armature)
    assert sha256(source) == source_hash, "Source changed"
    (EVIDENCE / "rig-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("ATLAS_RIG_REPAIR", json.dumps(report))


if __name__ == "__main__":
    main()