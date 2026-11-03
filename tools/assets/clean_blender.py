"""Чистка сирих моделей Meshy в Blender без інтерфейсу → готові .glb для Godot + рендери для перевірки.

Запуск (будь-який з двох):
  python3 tools/assets/clean_blender.py 01 [--only crate] [--method M|S] [--src DIR] [--out DIR]   # з модулем bpy
  blender -b -P tools/assets/clean_blender.py -- 01 [ті самі аргументи]                         # з Blender

Що робить з кожним асетом (параметри — з art/levels/<рівень>/assets.yaml):
  1. імпорт glb зі зварюванням вершин, одна сітка, поворот `rotate`, застосування трансформацій;
  2. decimate до `tris`, якщо трикутників більше;
  3. масштаб до `size` метрів уздовж `fit`, pivot `center` або `bottom`;
  4. текстури ≤ `texture` px, експорт JPEG (кольори й PBR-карти);
  5. колізія: `convex` → опукла оболонка `<id>-convcolonly`, `mesh` → спрощена `<id>-colonly` (Godot сам робить StaticBody3D);
  6. експорт <out>/<id>.glb і рендер 4 ракурсів <renders>/<id>.png зі статистикою.
"""
from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import ROOT, load_manifest, select_assets  # noqa: E402


def reset() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def tri_count(obj) -> int:
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def bbox(obj) -> tuple[Vector, Vector]:
    pts = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    return (Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts))),
            Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts))))


def select_only(objs, active=None) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active or objs[0]


def import_single_mesh(src: Path):
    bpy.ops.import_scene.gltf(filepath=str(src), merge_vertices=True)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in meshes:
        mw = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = mw
    for o in [o for o in bpy.context.scene.objects if o.type != "MESH"]:
        bpy.data.objects.remove(o, do_unlink=True)
    select_only(meshes)
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj


def clean(obj, a: dict) -> dict:
    stats = {"tris_raw": tri_count(obj)}
    rot = a.get("rotate")
    if rot:
        obj.rotation_euler = [math.radians(v) for v in rot]
        select_only([obj])
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    # Нормалі назовні, гладке затінення з гострими ребрами від 50°.
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()
    for p in obj.data.polygons:
        p.use_smooth = True
    try:
        obj.data.set_sharp_from_angle(angle=math.radians(50))
    except Exception:  # noqa: BLE001
        pass
    target = int(a.get("tris", 0))
    tris = tri_count(obj)
    if target and tris > target * 1.15:
        mod = obj.modifiers.new("dec", "DECIMATE")
        mod.ratio = target / tris
        mod.use_collapse_triangulate = True
        select_only([obj])
        bpy.ops.object.modifier_apply(modifier=mod.name)
    # Масштаб і pivot.
    lo, hi = bbox(obj)
    dims = hi - lo
    fit = a.get("fit", "longest")
    ref = {"longest": max(dims), "height": dims.z, "width": dims.x, "depth": dims.y}[fit]
    size = float(a.get("size", 1.0))
    k = size / ref if ref > 1e-6 else 1.0
    obj.scale = (k, k, k)
    select_only([obj])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    lo, hi = bbox(obj)
    c = (lo + hi) * 0.5
    off = Vector((c.x, c.y, lo.z)) if a.get("pivot", "center") == "bottom" else c
    obj.data.transform(Matrix.Translation(-off))
    obj.location = (0, 0, 0)
    lo, hi = bbox(obj)
    stats.update(tris=tri_count(obj), dims=[round(v, 3) for v in (hi - lo)])
    return stats


def shrink_textures(max_px: int) -> list:
    out = []
    for img in bpy.data.images:
        if img.size[0] == 0:
            continue
        w, h = img.size
        if max(w, h) > max_px:
            s = max_px / max(w, h)
            img.scale(max(1, round(w * s)), max(1, round(h * s)))
        out.append([img.name, list(img.size)])
    return out


def add_collision(obj, a: dict):
    kind = a.get("collision", "none")
    if kind not in ("convex", "mesh"):
        return None
    me = obj.data.copy()
    col = bpy.data.objects.new(f"{a['id']}-{'convcolonly' if kind == 'convex' else 'colonly'}", me)
    bpy.context.scene.collection.objects.link(col)
    col.data.materials.clear()
    bm = bmesh.new()
    bm.from_mesh(me)
    if kind == "convex":
        res = bmesh.ops.convex_hull(bm, input=bm.verts)
        bmesh.ops.delete(bm, geom=res.get("geom_interior", []) + res.get("geom_unused", []), context="VERTS")
    bm.to_mesh(me)
    bm.free()
    if kind == "mesh" and tri_count(col) > 1500:
        mod = col.modifiers.new("dec", "DECIMATE")
        mod.ratio = 1500 / tri_count(col)
        select_only([col])
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return col


def export(objs, dst: Path, quality: int = 90) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    select_only(objs)
    kw = dict(filepath=str(dst), export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
              export_image_format="JPEG", export_animations=False, export_cameras=False, export_lights=False)
    props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    kw["export_image_quality" if "export_image_quality" in props else "export_jpeg_quality"] = quality
    bpy.ops.export_scene.gltf(**kw)


def render_sheet(obj, dst: Path, title: str) -> None:
    """4 ракурси (спереду, справа, ззаду, 3/4) у Cycles на CPU → один PNG."""
    from PIL import Image, ImageDraw

    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 24
    scene.render.resolution_x = scene.render.resolution_y = 384
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.55, 0.57, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    scene.world = world
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-35))
    scene.collection.objects.link(sun)
    lo, hi = bbox(obj)
    c = (lo + hi) * 0.5
    r = max((hi - lo).length * 0.5, 1e-3)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.lens = 50
    scene.collection.objects.link(cam)
    scene.camera = cam
    dist = r / math.tan(cam.data.angle * 0.5) * 1.15
    shots = []
    for i, (az, el) in enumerate([(0, 8), (90, 8), (180, 8), (35, 28)]):
        a, e = math.radians(az), math.radians(el)
        d = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
        cam.location = c + d * dist
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        p = dst.with_name(f"{dst.stem}_v{i}.png")
        scene.render.filepath = str(p)
        bpy.ops.render.render(write_still=True)
        shots.append(p)
    sheet = Image.new("RGB", (384 * 4, 384 + 28), (30, 30, 30))
    for i, p in enumerate(shots):
        sheet.paste(Image.open(p).convert("RGB"), (i * 384, 28))
        p.unlink()
    ImageDraw.Draw(sheet).text((8, 7), title, fill=(240, 240, 240))
    sheet.save(dst)


def process(m: dict, a: dict, src: Path, out_glb: Path, renders: Path) -> dict:
    reset()
    obj = import_single_mesh(src)
    obj.name = a["id"]
    obj.data.name = a["id"]
    stats = clean(obj, a)
    stats["textures"] = shrink_textures(int(a.get("texture", 1024)))
    col = add_collision(obj, a)
    export([obj] + ([col] if col else []), out_glb)
    stats["mb"] = round(out_glb.stat().st_size / 1e6, 2)
    if col:
        col.hide_render = True
    title = f"{out_glb.stem}  tris {stats['tris_raw']}->{stats['tris']}  dims {stats['dims']} m  tex {stats['textures'][0][1] if stats['textures'] else '-'}  {stats['mb']} MB"
    render_sheet(obj, renders / f"{out_glb.stem}.png", title)
    return stats


def main() -> None:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("level")
    ap.add_argument("--only")
    ap.add_argument("--group")
    ap.add_argument("--method", choices=["M", "S", "use"], default="use",
                    help="use — метод з маніфесту (use/method); M або S — конкретний (для порівняння в пілоті)")
    ap.add_argument("--src", help="папка з сирими <id>_<M|S>.glb (за замовчуванням source_assets/gen/<рівень>/meshy)")
    ap.add_argument("--out", help="куди класти .glb (за замовчуванням assets/models/<рівень>)")
    ap.add_argument("--renders", help="куди класти рендери (за замовчуванням art/levels/<рівень>/renders)")
    args = ap.parse_args(argv)

    m = load_manifest(args.level)
    src = Path(args.src) if args.src else m["_gen"] / "meshy"
    out = Path(args.out) if args.out else ROOT / "assets" / "models" / m["_dir"].name.split("-")[0]
    renders = Path(args.renders) if args.renders else m["_dir"] / "renders"
    renders.mkdir(parents=True, exist_ok=True)
    report = {}
    for a in select_assets(m, args.only, args.group):
        meths = a.get("methods") or [a.get("method")]
        if args.method == "use":
            chosen = [a.get("use") or meths[0]]
            suffix = False
        else:
            chosen = [args.method] if args.method in meths else []
            suffix = True
        for mm in chosen:
            if mm not in ("M", "S"):
                continue
            raw = src / f"{a['id']}_{mm}.glb"
            if not raw.exists():
                print(f"– {a['id']}_{mm}: нема {raw.name}")
                continue
            dst = out / (f"{a['id']}_{mm}.glb" if suffix else f"{a['id']}.glb")
            try:
                st = process(m, a, raw, dst, renders)
                report[dst.stem] = st
                print(f"✔ {dst.stem}: {st['tris_raw']}→{st['tris']} tris, {st['dims']} m, {st['mb']} MB", flush=True)
            except Exception as e:  # noqa: BLE001
                print(f"✘ {a['id']}_{mm}: {e}", flush=True)
    rp = renders / "clean_report.json"
    old = json.loads(rp.read_text()) if rp.exists() else {}
    old.update(report)
    rp.write_text(json.dumps(old, indent=1, ensure_ascii=False))


if __name__ == "__main__":
    main()
