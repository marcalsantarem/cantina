"""Renderiza icones 256x256 (fundo transparente) dos glTF do KayKit.

Uso:
  blender -b -P tools/blender/render_icons.py -- [opcoes] <modelo|padrao> ...
Opcoes:
  --src DIR      pasta dos glTF (padrao: KayKit_Restaurant_Bits_1.0_FREE/Assets/gltf)
  --out DIR      pasta de saida (padrao: assets/icons)
  --size N       lado em px (padrao: 256)
  --engine E     eevee (padrao, cores fieis) | workbench (rapido, mais escuro)
  --mosaic       gera <out>/_preview.png com todos os PNGs da pasta de saida
Modelos aceitam padroes glob (ex.: 'food_*'). Saida: <out>/<nome>.png
"""
import bpy, sys, os, glob, math, time
import numpy as np
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []

opts = {"src": os.path.join(ROOT, "KayKit_Restaurant_Bits_1.0_FREE", "Assets", "gltf"),
        "out": os.path.join(ROOT, "assets", "icons"), "size": "256", "engine": "eevee"}
names, mosaic = [], False
i = 0
while i < len(argv):
    a = argv[i]
    if a == "--mosaic":
        mosaic = True
    elif a.startswith("--") and a[2:] in opts:
        opts[a[2:]] = argv[i + 1]; i += 1
    else:
        names.append(a)
    i += 1
SIZE = int(opts["size"])
MARGIN = 0.10            # margem por lado
ELEV, AZIM = 35.0, 45.0  # 3/4 de cima, frente-direita


def resolve(patterns):
    out = []
    for p in patterns:
        hits = sorted(glob.glob(os.path.join(opts["src"], p + ".gltf")))
        if not hits:
            print("AVISO: nenhum modelo para", p)
        for h in hits:
            n = os.path.splitext(os.path.basename(h))[0]
            if n not in out:
                out.append(n)
    return out


def setup_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    r = sc.render
    r.resolution_x = r.resolution_y = SIZE
    r.resolution_percentage = 100
    r.film_transparent = True
    r.image_settings.file_format = "PNG"
    r.image_settings.color_mode = "RGBA"
    r.image_settings.color_depth = "8"
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    if opts["engine"] == "eevee":
        r.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in [e.identifier for e in
                   bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE_NEXT"
        w = bpy.data.worlds.new("w"); sc.world = w
        w.use_nodes = True
        bg = w.node_tree.nodes.get("Background")
        bg.inputs[0].default_value = (1, 1, 1, 1); bg.inputs[1].default_value = 0.5
        sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
        sun.data.energy = 2.0; sun.data.use_shadow = False
        sun.rotation_euler = (math.radians(40), 0, math.radians(30))
        sc.collection.objects.link(sun)
        sc.eevee.taa_render_samples = 16
    else:
        r.engine = "BLENDER_WORKBENCH"
        s = sc.display.shading
        s.light = "STUDIO"
        s.color_type = "TEXTURE"
        s.show_shadows = False
        s.show_cavity = False
        s.show_object_outline = False
        s.show_specular_highlight = False
        sc.display.render_aa = "16"
    return sc


def frame_camera(sc, objs):
    el, az = math.radians(ELEV), math.radians(AZIM)
    d = Vector((math.cos(el) * math.sin(az), -math.cos(el) * math.cos(az), math.sin(el)))
    rot = (-d).to_track_quat("-Z", "Y")
    right, up = rot @ Vector((1, 0, 0)), rot @ Vector((0, 1, 0))
    dg = bpy.context.evaluated_depsgraph_get()
    pts = []
    for o in objs:
        if o.type != "MESH":
            continue
        oe = o.evaluated_get(dg)
        m = oe.to_mesh()
        mw = o.matrix_world
        pts += [mw @ v.co for v in m.vertices]
        oe.to_mesh_clear()
    xs = [p.dot(right) for p in pts]; ys = [p.dot(up) for p in pts]; zs = [p.dot(d) for p in pts]
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    ext = max(max(xs) - min(xs), max(ys) - min(ys))
    depth = max(zs) - min(zs)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = ext / (1 - 2 * MARGIN)
    cam.location = right * cx + up * cy + d * (max(zs) + 1.0)
    cam.rotation_mode = "QUATERNION"; cam.rotation_quaternion = rot
    cam.data.clip_start = 0.01; cam.data.clip_end = depth + 2.0
    sc.collection.objects.link(cam); sc.camera = cam


def render(name):
    sc = setup_scene()
    bpy.ops.import_scene.gltf(filepath=os.path.join(opts["src"], name + ".gltf"))
    frame_camera(sc, list(sc.objects))
    sc.render.filepath = os.path.join(opts["out"], name + ".png")
    bpy.ops.render.render(write_still=True)


def make_mosaic():
    files = sorted(f for f in glob.glob(os.path.join(opts["out"], "*.png"))
                   if not os.path.basename(f).startswith("_"))
    if not files:
        return
    t = SIZE; cols = min(8, len(files)); rows = math.ceil(len(files) / cols)
    W, H = cols * t, rows * t
    yy, xx = np.mgrid[0:H, 0:W]
    chk = np.where(((xx // 16) + (yy // 16)) % 2 == 0, 0.80, 0.60)[..., None]  # xadrez p/ ver o alfa
    canvas = np.concatenate([np.repeat(chk, 3, axis=2), np.ones((H, W, 1))], axis=2)
    for k, f in enumerate(files):
        img = bpy.data.images.load(f)
        w, h = img.size
        px = np.empty(w * h * 4, dtype=np.float32); img.pixels.foreach_get(px)
        px = px.reshape(h, w, 4)[:t, :t]
        r, c = divmod(k, cols)
        y0 = H - (r + 1) * t; x0 = c * t   # pixels do Blender comecam embaixo
        reg = canvas[y0:y0 + px.shape[0], x0:x0 + px.shape[1]]
        a = px[..., 3:4]
        reg[..., :3] = px[..., :3] * a + reg[..., :3] * (1 - a)
        bpy.data.images.remove(img)
    out = bpy.data.images.new("preview", W, H, alpha=True)
    out.pixels.foreach_set(canvas.astype(np.float32).ravel())
    out.filepath_raw = os.path.join(opts["out"], "_preview.png"); out.file_format = "PNG"
    out.save()
    print("MOSAICO:", out.filepath_raw, len(files), "icones")


os.makedirs(opts["out"], exist_ok=True)
t0 = time.time()
models = resolve(names)
for n in models:
    render(n)
print("RENDER: %d icones em %.1fs" % (len(models), time.time() - t0))
if mosaic:
    make_mosaic()
