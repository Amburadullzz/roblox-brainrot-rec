#!/usr/bin/env python3
"""Render the game's four screenshots from the place's own parts.

    python3 tools/render-shots.py

The scene comes from default.project.json, the same file `rojo build` turns into game.rbxl: every Part
with its position, size, colour, shape and transparency. The brainrots and the player are built from the
same numbers src/shared/Config.luau and src/server/CastModels.luau use, so a pod's creature here is the
creature the game puts there. The HUD is drawn with the same layout, colours and wording as
src/client/Hud.client.luau.

This is a renderer, not Roblox: it draws the world the scripts build, not a Studio capture. Each image is
1280x720 and re-encoded under the bounty's 256 KiB per-file cap.
"""

import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
W, H = 1280, 720
SS = 2  # supersampling factor

FONT_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FONT_BLACK = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FONT_BODY = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"

# The palette the HUD uses (src/client/Hud.client.luau).
HUD_TEXT = (238, 242, 252)
HUD_DIM = (160, 172, 194)
HUD_PANEL = (16, 18, 28)
HUD_ACCENT = (64, 246, 224)
HUD_GOLD = (255, 206, 64)
HUD_DANGER = (255, 96, 96)

RARITY_COLOR = {
    "Common": (168, 172, 180),
    "Uncommon": (96, 214, 108),
    "Rare": (86, 152, 255),
    "Epic": (186, 108, 255),
    "Legendary": (255, 196, 64),
    "Mythic": (255, 92, 92),
    "Secret": (64, 246, 224),
}

# The cast, mirrored from src/shared/Config.luau: id -> (name, rarity, income, cost, build, extra,
# shell colour, face colour). Kept in the same order as the pods.
CAST = [
    ("puddle_goblin", "Puddle Goblin", "Common", 1, 25, "blob", "none", (96, 158, 92), (176, 214, 120)),
    ("squishy_nork", "Squishy Nork", "Common", 2, 45, "blob", "antenna", (232, 132, 168), (255, 208, 224)),
    ("toddler_spoon", "Toddler With A Spoon", "Uncommon", 5, 110, "tall", "spoon", (255, 206, 122), (74, 132, 210)),
    ("waffle_frog", "Chonky Waffle Frog", "Uncommon", 9, 220, "wide", "none", (214, 160, 74), (126, 200, 96)),
    ("auntie_wig", "Auntie Bimbly's Wig", "Rare", 18, 480, "tall", "wig", (198, 112, 206), (255, 236, 176)),
    ("sir_loin", "Sir Loin Of Beef", "Rare", 32, 900, "wide", "crown", (186, 62, 66), (248, 200, 168)),
    ("gronk", "Gronk The Unemployed", "Epic", 60, 1800, "tall", "hat", (122, 156, 232), (52, 66, 112)),
    ("microwave_baby", "Microwave Baby", "Epic", 110, 3600, "wide", "antenna", (226, 228, 232), (120, 124, 132)),
    ("grandma_dentures", "Grandma Gex's Dentures", "Legendary", 220, 7500, "orb", "teeth", (250, 244, 220), (232, 96, 140)),
    ("the_orb", "The Orb That Knows", "Legendary", 400, 14000, "orb", "none", (96, 246, 240), (28, 60, 96)),
    ("pigeon_prophet", "Biblically Accurate Pigeon", "Mythic", 800, 26000, "bird", "wing", (184, 190, 204), (255, 226, 128)),
    ("mosquito_god", "God Of Getting Bit By A Mosquito", "Secret", 1600, 55000, "orb", "horn", (255, 78, 138), (38, 24, 44)),
]
CAST_BY_ID = {row[0]: row for row in CAST}

BODY_PLANS = {
    "blob": dict(torso=(3.6, 3.6, 3.6), head=(2.4, 2.4, 2.4), head_y=1.2, shape="ball"),
    "tall": dict(torso=(2.8, 4.0, 2.4), head=(2.6, 2.6, 2.6), head_y=3.0, shape="block"),
    "wide": dict(torso=(4.8, 2.6, 3.0), head=(2.2, 2.2, 2.2), head_y=1.9, shape="block"),
    "orb": dict(torso=(4.2, 4.2, 4.2), head=(2.0, 2.0, 2.0), head_y=0.4, shape="ball"),
    "bird": dict(torso=(2.4, 2.6, 4.4), head=(2.0, 2.0, 2.0), head_y=1.9, shape="block"),
}

MUTATIONS = {
    "normal": (1.0, None),
    "shiny": (1.75, (130, 226, 255)),
    "golden": (2.5, (255, 202, 64)),
    "radioactive": (3.2, (126, 255, 96)),
    "cursed": (4.5, (162, 62, 220)),
}


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def norm(v):
    v = np.array(v, dtype=np.float64)
    n = np.linalg.norm(v)
    return v / n if n > 1e-9 else v


# ---------------------------------------------------------------- geometry


def box_mesh(center, size):
    """Six quads of an axis-aligned box, each as (4 corners, normal)."""
    cx, cy, cz = center
    sx, sy, sz = (s / 2.0 for s in size)
    x0, x1 = cx - sx, cx + sx
    y0, y1 = cy - sy, cy + sy
    z0, z1 = cz - sz, cz + sz
    quads = [
        ([(x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)], (0, 1, 0)),
        ([(x0, y0, z1), (x1, y0, z1), (x1, y0, z0), (x0, y0, z0)], (0, -1, 0)),
        ([(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0)], (0, 0, -1)),
        ([(x1, y0, z1), (x0, y0, z1), (x0, y1, z1), (x1, y1, z1)], (0, 0, 1)),
        ([(x0, y0, z1), (x0, y0, z0), (x0, y1, z0), (x0, y1, z1)], (-1, 0, 0)),
        ([(x1, y0, z0), (x1, y0, z1), (x1, y1, z1), (x1, y1, z0)], (1, 0, 0)),
    ]
    return quads


def ball_mesh(center, size, segments=14, rings=8):
    """A lat-long sphere as quads."""
    rx, ry, rz = (s / 2.0 for s in size)
    cx, cy, cz = center
    quads = []
    for i in range(rings):
        t0 = math.pi * i / rings
        t1 = math.pi * (i + 1) / rings
        for j in range(segments):
            p0 = 2 * math.pi * j / segments
            p1 = 2 * math.pi * (j + 1) / segments
            pts = []
            for t, p in ((t0, p0), (t0, p1), (t1, p1), (t1, p0)):
                pts.append((
                    cx + rx * math.sin(t) * math.cos(p),
                    cy + ry * math.cos(t),
                    cz + rz * math.sin(t) * math.sin(p),
                ))
            # Face normal from the quad's own plane, pointing away from the centre.
            a, b, c = (np.array(pts[0]), np.array(pts[1]), np.array(pts[3]))
            n = np.cross(b - a, c - a)
            if np.linalg.norm(n) < 1e-9:
                continue
            n = norm(n)
            mid = np.mean([np.array(p) for p in pts], axis=0)
            if np.dot(n, mid - np.array(center)) < 0:
                n = -n
            quads.append((pts, tuple(n)))
    return quads


def subdivide(quads, center, size):
    """Split a big quad into a grid, so a part straddling the camera plane keeps the half in front."""
    span = max(size)
    if span <= 60:
        return quads
    steps = max(2, int(span // 30))
    out = []
    for pts, normal in quads:
        p0, p1, p2, p3 = (np.array(p) for p in pts)
        for a in range(steps):
            for b in range(steps):
                u0, u1 = a / steps, (a + 1) / steps
                v0, v1 = b / steps, (b + 1) / steps

                def lerp(u, v):
                    top = p0 + (p1 - p0) * u
                    bottom = p3 + (p2 - p3) * u
                    return tuple(top + (bottom - top) * v)

                out.append(([lerp(u0, v0), lerp(u1, v0), lerp(u1, v1), lerp(u0, v1)], normal))
    return out


# ---------------------------------------------------------------- camera


class Camera:
    def __init__(self, position, target, fov=62.0):
        self.pos = np.array(position, dtype=np.float64)
        forward = norm(np.array(target, dtype=np.float64) - self.pos)
        right = norm(np.cross(forward, np.array([0.0, 1.0, 0.0])))
        up = np.cross(right, forward)
        self.f = forward
        self.r = right
        self.u = up
        self.focal = (H * SS / 2.0) / math.tan(math.radians(fov) / 2.0)
        self.cx = W * SS / 2.0
        self.cy = H * SS / 2.0

    def project(self, p):
        v = np.array(p, dtype=np.float64) - self.pos
        x = float(np.dot(v, self.r))
        y = float(np.dot(v, self.u))
        z = float(np.dot(v, self.f))
        if z <= 0.15:
            return None
        return (self.cx + x / z * self.focal, self.cy - y / z * self.focal, z)


# ---------------------------------------------------------------- the scene


def load_parts(path):
    project = json.load(open(path))
    workspace = project["tree"]["Workspace"]
    parts = []
    for name, node in workspace.items():
        if name.startswith("$"):
            continue
        cls = node.get("$className")
        if cls not in ("Part", "SpawnLocation"):
            continue
        props = node.get("$properties", {})
        size = props.get("Size", [1, 1, 1])
        cf = props.get("CFrame", [0, 0, 0])
        color = props.get("Color", [0.64, 0.64, 0.64])
        parts.append({
            "name": name,
            "pos": (cf[0], cf[1], cf[2]),
            "size": tuple(size),
            "color": tuple(int(round(c * 255)) for c in color),
            "shape": props.get("Shape", "Block"),
            "material": props.get("Material", "SmoothPlastic"),
            "transparency": float(props.get("Transparency", 0.0)),
        })
    return parts


def brainrot_parts(entry_id, position, mutation="normal", yaw=0.0, scale=1.0):
    """The parts of one brainrot, standing with its feet at `position`."""
    _, name, rarity, income, cost, build, extra, shell, face = CAST_BY_ID[entry_id]
    mult, tint = MUTATIONS.get(mutation, MUTATIONS["normal"])
    if tint is not None:
        shell = mix(shell, tint, 0.55)
        face = mix(face, tint, 0.35)
    plan = BODY_PLANS[build]
    torso_size = tuple(s * scale for s in plan["torso"])
    head_size = tuple(s * scale for s in plan["head"])
    tx, ty, tz = torso_size
    hx, hy, hz = head_size
    head_y = (plan["head_y"] + plan["head"][1] / 2 + plan["torso"][1] / 2) * scale
    out = []
    out.append({"pos": (0, ty / 2, 0), "size": torso_size, "color": shell, "shape": plan["shape"], "material": "SmoothPlastic"})
    out.append({"pos": (0, head_y, 0), "size": head_size, "color": face, "shape": "Block", "material": "SmoothPlastic"})
    out.append({"pos": (-0.55 * scale, head_y + 0.2 * scale, hz / 2 + 0.05), "size": (0.45 * scale, 0.55 * scale, 0.2), "color": (24, 24, 30), "shape": "Block"})
    out.append({"pos": (0.55 * scale, head_y + 0.2 * scale, hz / 2 + 0.05), "size": (0.45 * scale, 0.55 * scale, 0.2), "color": (24, 24, 30), "shape": "Block"})
    out.append({"pos": (-0.9 * scale, 0.3, 0), "size": (0.9 * scale, 0.6 * scale, 1.2 * scale), "color": face, "shape": "Block"})
    out.append({"pos": (0.9 * scale, 0.3, 0), "size": (0.9 * scale, 0.6 * scale, 1.2 * scale), "color": face, "shape": "Block"})

    if extra == "hat":
        out.append({"pos": (0, head_y + 1.5 * scale, 0), "size": (3.0 * scale, 0.5 * scale, 3.0 * scale), "color": face, "shape": "Block"})
        out.append({"pos": (0, head_y + 2.4 * scale, 0), "size": (1.8 * scale, 1.4 * scale, 1.8 * scale), "color": shell, "shape": "Block"})
    elif extra == "spoon":
        out.append({"pos": (1.9 * scale, head_y + 0.4 * scale, 0), "size": (0.3 * scale, 3.2 * scale, 0.3 * scale), "color": (206, 210, 220), "shape": "Block"})
        out.append({"pos": (1.9 * scale, head_y + 2.1 * scale, 0), "size": (1.1 * scale, 0.5 * scale, 1.1 * scale), "color": (226, 230, 238), "shape": "ball"})
    elif extra == "wig":
        out.append({"pos": (0, head_y + 1.1 * scale, 0.2 * scale), "size": (3.4 * scale, 1.4 * scale, 3.4 * scale), "color": shell, "shape": "Block"})
        out.append({"pos": (-1.5 * scale, head_y + 0.6 * scale, 1.2 * scale), "size": (1.2 * scale, 1.2 * scale, 1.2 * scale), "color": face, "shape": "ball"})
    elif extra == "horn":
        out.append({"pos": (-0.8 * scale, head_y + 1.5 * scale, 0), "size": (0.5 * scale, 1.8 * scale, 0.5 * scale), "color": face, "shape": "Block"})
        out.append({"pos": (0.8 * scale, head_y + 1.5 * scale, 0), "size": (0.5 * scale, 1.8 * scale, 0.5 * scale), "color": face, "shape": "Block"})
    elif extra == "crown":
        out.append({"pos": (0, head_y + 1.4 * scale, 0), "size": (2.8 * scale, 0.7 * scale, 2.8 * scale), "color": (255, 206, 64), "shape": "Block", "material": "Neon"})
    elif extra == "antenna":
        out.append({"pos": (0, head_y + 1.6 * scale, 0), "size": (0.25 * scale, 1.8 * scale, 0.25 * scale), "color": (90, 96, 110), "shape": "Block"})
        out.append({"pos": (0, head_y + 2.5 * scale, 0), "size": (0.7 * scale, 0.7 * scale, 0.7 * scale), "color": face, "shape": "ball", "material": "Neon"})
    elif extra == "teeth":
        out.append({"pos": (0, head_y - 0.2 * scale, 1.1 * scale), "size": (2.0 * scale, 0.5 * scale, 0.4 * scale), "color": (252, 252, 248), "shape": "Block"})
        out.append({"pos": (0, head_y - 0.9 * scale, 1.1 * scale), "size": (2.0 * scale, 0.5 * scale, 0.4 * scale), "color": (252, 252, 248), "shape": "Block"})
    elif extra == "wing":
        out.append({"pos": (-2.0 * scale, 0.6 * scale, 0), "size": (2.6 * scale, 0.3 * scale, 1.6 * scale), "color": face, "shape": "Block"})
        out.append({"pos": (2.0 * scale, 0.6 * scale, 0), "size": (2.6 * scale, 0.3 * scale, 1.6 * scale), "color": face, "shape": "Block"})

    # Move from the model's own frame into the world.
    cy, sy = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    world = []
    for part in out:
        px, py, pz = part["pos"]
        wx = position[0] + px * cy - pz * sy
        wz = position[2] + px * sy + pz * cy
        world.append(dict(part, pos=(wx, position[1] + py, wz)))
    return world


def avatar_parts(position, yaw=0.0):
    """A blocky R6 avatar: yellow head with a face, blue torso, green legs, yellow arms."""
    skin = (245, 205, 48)
    shirt = (32, 108, 196)
    pants = (46, 160, 78)
    body = [
        ((0, 1.0, 0), (2.0, 2.0, 1.0), shirt),
        ((0, 2.5, 0), (2.0, 1.0, 1.0), skin),
        ((-1.5, 1.0, 0), (1.0, 2.0, 1.0), skin),
        ((1.5, 1.0, 0), (1.0, 2.0, 1.0), skin),
        ((-0.5, -1.0, 0), (1.0, 2.0, 1.0), pants),
        ((0.5, -1.0, 0), (1.0, 2.0, 1.0), pants),
        ((-0.35, 2.6, -0.51), (0.28, 0.28, 0.06), (30, 30, 36)),
        ((0.35, 2.6, -0.51), (0.28, 0.28, 0.06), (30, 30, 36)),
    ]
    cy, sy = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    out = []
    for (px, py, pz), size, color in body:
        wx = position[0] + px * cy - pz * sy
        wz = position[2] + px * sy + pz * cy
        out.append({"pos": (wx, position[1] + py + 2.0, wz), "size": size, "color": color, "shape": "Block"})
    return out


# ---------------------------------------------------------------- rendering

LIGHT = norm((-0.42, 0.86, -0.38))


def render(parts, camera, background):
    img = background.copy()
    zbuf = np.full((H * SS, W * SS), np.inf, dtype=np.float64)
    opaque = [p for p in parts if p.get("transparency", 0.0) < 0.5]
    clear = [p for p in parts if p.get("transparency", 0.0) >= 0.5]

    def draw(part, alpha):
        if part["shape"] == "ball":
            quads = ball_mesh(part["pos"], part["size"])
        else:
            quads = box_mesh(part["pos"], part["size"])
            quads = subdivide(quads, part["pos"], part["size"])
        base = np.array(part["color"], dtype=np.float64) / 255.0
        for pts, normal in quads:
            proj = [camera.project(p) for p in pts]
            if any(p is None for p in proj):
                continue
            n = np.array(normal, dtype=np.float64)
            lam = max(0.0, float(np.dot(n, LIGHT)))
            sky = 0.10 * max(0.0, float(n[1]))
            if part.get("material") == "Neon":
                shade = 1.0
                color = np.clip(base * 1.12 + 0.06, 0.0, 1.0)
            else:
                shade = 0.55 + 0.45 * lam + sky
                color = np.clip(base * shade, 0.0, 1.0)
            # Distance fog, the place's Lighting FogStart/FogEnd.
            depth = sum(p[2] for p in proj) / 4.0
            fog = min(1.0, max(0.0, (depth - 260.0) / (620.0 - 260.0))) * 0.85
            color = color * (1 - fog) + np.array([0.62, 0.78, 0.92]) * fog
            tri_a = (proj[0], proj[1], proj[2])
            tri_b = (proj[0], proj[2], proj[3])
            for tri in (tri_a, tri_b):
                raster(img, zbuf, tri, color, alpha)

    for part in sorted(opaque, key=lambda p: -p["pos"][2]):
        draw(part, 1.0)
    for part in sorted(clear, key=lambda p: -p["pos"][2]):
        draw(part, 0.45)
    return img


def raster(img, zbuf, tri, color, alpha):
    (x0, y0, z0), (x1, y1, z1), (x2, y2, z2) = tri
    minx = max(int(math.floor(min(x0, x1, x2))), 0)
    maxx = min(int(math.ceil(max(x0, x1, x2))), W * SS - 1)
    miny = max(int(math.floor(min(y0, y1, y2))), 0)
    maxy = min(int(math.ceil(max(y0, y1, y2))), H * SS - 1)
    if minx > maxx or miny > maxy:
        return
    area = (x1 - x0) * (y2 - y0) - (x2 - x0) * (y1 - y0)
    if abs(area) < 1e-9:
        return
    xs = np.arange(minx, maxx + 1) + 0.5
    ys = np.arange(miny, maxy + 1) + 0.5
    gx, gy = np.meshgrid(xs, ys)
    w0 = ((x1 - gx) * (y2 - gy) - (x2 - gx) * (y1 - gy)) / area
    w1 = ((x2 - gx) * (y0 - gy) - (x0 - gx) * (y2 - gy)) / area
    w2 = 1.0 - w0 - w1
    mask = (w0 >= 0) & (w1 >= 0) & (w2 >= 0)
    if not mask.any():
        return
    depth = w0 * z0 + w1 * z1 + w2 * z2
    region = zbuf[miny:maxy + 1, minx:maxx + 1]
    hit = mask & (depth < region)
    if not hit.any():
        return
    if alpha >= 1.0:
        region[hit] = depth[hit]
        img[miny:maxy + 1, minx:maxx + 1][hit] = color
    else:
        pixels = img[miny:maxy + 1, minx:maxx + 1]
        pixels[hit] = pixels[hit] * (1 - alpha) + color * alpha


def background():
    top = np.array([0.22, 0.45, 0.82])
    bottom = np.array([0.74, 0.87, 0.97])
    rows = np.linspace(0, 1, H * SS)[:, None]
    sky = top[None, None, :] + (bottom - top)[None, None, :] * rows[:, :, None]
    return np.repeat(sky, W * SS, axis=1).astype(np.float64)


def to_image(array):
    small = array.reshape(H, SS, W, SS, 3).mean(axis=(1, 3))
    return Image.fromarray(np.clip(small * 255.0, 0, 255).astype(np.uint8), "RGB")


# ---------------------------------------------------------------- the HUD


def font(path, size):
    return ImageFont.truetype(path, size)


def text(draw, xy, s, size, color, font_path=FONT_BOLD, anchor="la", stroke=3):
    f = font(font_path, size)
    if stroke:
        for dx, dy in ((-stroke, 0), (stroke, 0), (0, -stroke), (0, stroke), (-stroke, -stroke), (stroke, stroke), (-stroke, stroke), (stroke, -stroke)):
            draw.text((xy[0] + dx, xy[1] + dy), s, font=f, fill=(6, 8, 14), anchor=anchor)
    draw.text(xy, s, font=f, fill=color, anchor=anchor)


def panel(draw, box, color=HUD_PANEL, radius=14, alpha=230):
    draw.rounded_rectangle(box, radius=radius, fill=(color[0], color[1], color[2]))


def billboard(draw, camera, world_pos, title, subtitle, color, min_size=11, max_size=20, max_width=238):
    """A name plate over a brainrot, as CastModels.label hangs one: the name in its rarity's colour and
    what it pays under it, scaled by how far away it is and cut to a width two plates never share."""
    pr = camera.project(world_pos)
    if pr is None:
        return
    x, y = pr[0] / SS, pr[1] / SS
    if not (-40 <= x <= W + 40 and -20 <= y <= H + 20):
        return
    scale = min(max(1500.0 / max(pr[2], 1.0), 0.62), 2.0)
    size = int(min(max(19 * scale, min_size), max_size))
    text(draw, (x, y), fit(draw, title, size, max_width), size, color, FONT_BOLD, anchor="mb", stroke=max(2, size // 8))
    text(draw, (x, y + size * 0.35), fit(draw, subtitle, int(size * 0.72), max_width), int(size * 0.72), (236, 240, 250), FONT_BOLD, anchor="ma", stroke=max(2, size // 9))


def fit(draw, s, size, width):
    """Cut a label at the last word that fits, with an ellipsis, the way the HUD's TextTruncate does."""
    f = font(FONT_BOLD, size)
    if draw.textlength(s, font=f) <= width:
        return s
    while s and draw.textlength(s + "…", font=f) > width:
        s = s[:-1]
    return s.rstrip(" ,.") + "…"


def hud(draw, state):
    # Wallet, top middle: cash, then what the base pays.
    panel(draw, (470, 12, 810, 104))
    text(draw, (640, 38), state["cash"], 44, HUD_TEXT, FONT_BOLD, anchor="mm")
    text(draw, (640, 82), state["rate"], 19, HUD_ACCENT, FONT_BOLD, anchor="mm")

    # Rebirths, top right.
    panel(draw, (1072, 12, 1262, 76))
    text(draw, (1167, 32), "REBIRTH " + str(state["rebirths"]), 18, HUD_GOLD, FONT_BOLD, anchor="mm")
    text(draw, (1167, 60), state["mult"], 15, HUD_DIM, FONT_BOLD, anchor="mm")

    # The base's six slots, down the left side, clear of Roblox's menu corner.
    panel(draw, (14, 150, 306, 450))
    text(draw, (26, 160), state["base_title"], 16, HUD_ACCENT, FONT_BOLD)
    for index in range(6):
        y = 186 + index * 42
        draw.rounded_rectangle((22, y, 298, y + 38), radius=8, fill=(28, 32, 46))
        entry = state["slots"][index] if index < len(state["slots"]) else None
        if entry:
            name, rarity, rate = entry
            text(draw, (32, y + 19), fit(draw, "%d. %s" % (index + 1, name), 15, 190), 15, RARITY_COLOR[rarity], FONT_BOLD, anchor="lm", stroke=2)
            text(draw, (288, y + 19), rate, 14, HUD_ACCENT, FONT_BOLD, anchor="rm", stroke=2)
        else:
            text(draw, (32, y + 19), "%d. — empty —" % (index + 1), 15, HUD_DIM, FONT_BOLD, anchor="lm", stroke=2)

    if state.get("carrying"):
        name, rarity = state["carrying"]
        draw.rounded_rectangle((360, 566, 920, 610), radius=12, fill=(26, 30, 44))
        text(draw, (640, 588), "CARRYING  %s  —  RUN IT HOME" % name, 22, RARITY_COLOR[rarity], FONT_BOLD, anchor="mm")

    # The keys, bottom middle.
    panel(draw, (310, 668, 970, 706), radius=10)
    text(draw, (640, 687), "[E] buy · place   [L] padlock   [R] rebirth   [F] steal", 15, HUD_TEXT, FONT_BOLD, anchor="mm")

    if state.get("wave"):
        label, hot = state["wave"]
        draw.rounded_rectangle((360, 112, 920, 158), radius=12, fill=(120, 24, 30) if hot else (24, 96, 150))
        text(draw, (640, 135), label, 22, (255, 236, 236), FONT_BOLD, anchor="mm")

    for index, (message, color) in enumerate(reversed(state.get("toasts", [])[-3:])):
        y = 656 - 34 - index * 40
        draw.rounded_rectangle((14, y, 444, y + 34), radius=8, fill=(22, 26, 38))
        text(draw, (24, y + 17), fit(draw, message, 13, 412), 13, color, FONT_BOLD, anchor="lm", stroke=2)


def title_screen(img, subtitle):
    """The title card over the world, as the client's TitleScreen frame draws it: a dim wash, then the
    name, the tagline, the button and the controls."""
    overlay = Image.new("RGBA", (W, H), (8, 10, 18, 130))
    img.paste(overlay, (0, 0), overlay)
    draw = ImageDraw.Draw(img)
    text(draw, (640, 214), "BRAINROT BAZAAR", 78, (255, 226, 128), FONT_BLACK, anchor="mm", stroke=5)
    text(draw, (640, 306), "Catch a brainrot. Carry it home. Cash it before the tide.", 24, HUD_TEXT, FONT_BOLD, anchor="mm", stroke=3)
    draw.rounded_rectangle((490, 382, 790, 444), radius=14, fill=HUD_ACCENT)
    text(draw, (640, 413), "CLICK TO PLAY", 30, (8, 16, 20), FONT_BLACK, anchor="mm", stroke=0)
    text(draw, (640, 486), "E buy at a pod · E place on your base · L padlock · R rebirth · F steal a neighbour's brainrot", 16, HUD_DIM, FONT_BODY, anchor="mm", stroke=2)
    if subtitle:
        text(draw, (640, 664), subtitle, 15, (150, 200, 220), FONT_BOLD, anchor="mm", stroke=2)
    return draw


# ---------------------------------------------------------------- scenes


def pod_position(index):
    ring = 18 if index < 6 else 28
    angle = ((index % 6) / 6.0) * math.pi * 2
    return (math.sin(angle) * ring, 3.6, math.cos(angle) * ring)


def hide_wave(parts):
    """The tsunami wall waits off the north shore; unless a scene is about it, it is out of the picture."""
    for part in parts:
        if part["name"] in ("TsunamiWall", "TsunamiCrest"):
            part["transparency"] = 1.0


def scene_parts(extra):
    return extra


def build_scene(name):
    parts = load_parts(os.path.join(ROOT, "default.project.json"))
    actors = []

    if name == "1-cover":
        hide_wave(parts)
        camera = Camera((44, 27, 66), (0, 11, -8), fov=60)
        # The pod line, each creature standing on its own pad, so the cover is the cast.
        for index, row in enumerate(CAST):
            pad = pod_position(index)
            actors += brainrot_parts(row[0], (pad[0], 4.0, pad[2]), "normal", yaw=18 * index)
        actors += avatar_parts((-7, 1.6, 30), yaw=195)
        state = {
            "cash": "$1,240", "rate": "$96/s  ·  plot 3", "rebirths": 1, "mult": "x1.25 income  ·  next $9K",
            "base_title": "YOUR BASE  3/6",
            "slots": [("Puddle Goblin", "Common", "$1/s"), ("Chonky Waffle Frog", "Uncommon", "$9/s"), ("The Orb That Knows", "Legendary", "$500/s")],
            "carrying": ("Golden Microwave Baby", "Epic"),
            "wave": None,
            "toasts": [],
        }
        return parts + actors, camera, state, "start"

    if name == "2-bazaar":
        hide_wave(parts)
        # Pod 3 sells the Toddler With A Spoon: the player stands at it, wallet open, prompt up.
        pod = pod_position(2)
        camera = Camera((30, 11, 10), (pod[0] - 1, 5.4, pod[2] + 2), fov=64)
        actors += avatar_parts((pod[0] + 2.2, 1.6, pod[2] + 8.5), yaw=-16)
        actors += brainrot_parts("toddler_spoon", (pod[0], 4.0, pod[2]), "normal", yaw=24)
        actors += brainrot_parts("waffle_frog", pod_position(3), "normal", yaw=60)
        state = {
            "cash": "$214", "rate": "$11/s  ·  plot 3", "rebirths": 0, "mult": "x1.00 income  ·  next $9K",
            "base_title": "YOUR BASE  2/6",
            "slots": [("Puddle Goblin", "Common", "$1/s"), ("Squishy Nork", "Common", "$2/s")],
            "carrying": None,
            "wave": ("TSUNAMI IN 11.4s — GET HOME", True),
            "toasts": [("Plot 3 is yours. Buy at a pod, carry it home, put it down.", HUD_ACCENT)],
            "labels": [
                ((pod[0], 9.2, pod[2]), "Toddler With A Spoon", "Uncommon · $110 · $5/s", RARITY_COLOR["Uncommon"]),
            ],
        }
        return parts + actors, camera, state, "play"

    if name == "3-base":
        hide_wave(parts)
        # The base from the west, so the sign post does not stand in front of the slots.
        camera = Camera((-10, 14, 134), (0, 5.5, 99), fov=60)
        actors += brainrot_parts("puddle_goblin", (-10, 1.6, 100), "normal", yaw=8)
        actors += brainrot_parts("waffle_frog", (0, 1.6, 100), "normal", yaw=-14)
        actors += brainrot_parts("the_orb", (10, 1.6, 100), "golden", yaw=30)
        actors += avatar_parts((16, 1.6, 113), yaw=210)
        state = {
            "cash": "$8,940", "rate": "$511/s  ·  plot 6", "rebirths": 2, "mult": "x1.50 income  ·  next $29K",
            "base_title": "YOUR BASE  3/6",
            "slots": [("Puddle Goblin", "Common", "$1/s"), ("Chonky Waffle Frog", "Uncommon", "$14/s"), ("Golden The Orb That Knows", "Legendary", "$1.5K/s")],
            "carrying": None,
            "wave": None,
            "toasts": [("Golden The Orb That Knows is on slot 3, paying $1.5K/s.", HUD_GOLD)],
            "labels": [
                ((-10, 5.8, 100), "Puddle Goblin", "Common · $1/s", RARITY_COLOR["Common"]),
                ((0, 7.8, 100), "Chonky Waffle Frog", "Uncommon · $14/s", RARITY_COLOR["Uncommon"]),
                ((10, 9.6, 100), "The Orb That Knows", "Golden · Legendary · $1.5K/s", RARITY_COLOR["Legendary"]),
            ],
        }
        return parts + actors, camera, state, "play"

    if name == "4-tsunami":
        # The wall mid-island, the player sprinting south with the catch still on their head.
        for part in parts:
            if part["name"] == "TsunamiWall":
                part["pos"] = (0, 14, -6)
            if part["name"] == "TsunamiCrest":
                part["pos"] = (0, 30, -6)
        camera = Camera((-26, 14, 56), (2, 10, 4), fov=64)
        actors += avatar_parts((2, 1.6, 24), yaw=186)
        actors += brainrot_parts("sir_loin", (2, 5.4, 24), "normal", yaw=0)
        actors += brainrot_parts("gronk", (-13, 1.6, 10), "normal", yaw=40)
        state = {
            "cash": "$3,310", "rate": "$92/s  ·  plot 2", "rebirths": 0, "mult": "x1.00 income  ·  next $9K",
            "base_title": "YOUR BASE  1/6",
            "slots": [("Sir Loin Of Beef", "Rare", "$32/s")],
            "carrying": ("Sir Loin Of Beef", "Rare"),
            "wave": ("THE TIDE IS HERE — HOLD ON TO NOTHING", False),
            "toasts": [("You lifted a Sir Loin Of Beef. Run it home to your base.", RARITY_COLOR["Rare"])],
            "labels": [((2, 12.4, 24), "Sir Loin Of Beef", "Rare · $32/s", RARITY_COLOR["Rare"])],
        }
        return parts + actors, camera, state, "play"

    raise SystemExit("unknown scene: " + name)


def encode(image, path):
    """JPEG under the bounty's 256 KiB cap, at most 1280 on the long side."""
    for quality in (90, 86, 82, 78, 74, 70, 64, 58):
        image.save(path, "JPEG", quality=quality, subsampling=0, optimize=True)
        if os.path.getsize(path) <= 262144:
            return quality, os.path.getsize(path)
    raise SystemExit("could not get %s under 256 KiB" % path)


def main():
    scenes = ["1-cover", "2-bazaar", "3-base", "4-tsunami"]
    outdir = os.path.join(ROOT, "screenshots")
    os.makedirs(outdir, exist_ok=True)
    for name in scenes:
        parts, camera, state, kind = build_scene(name)
        img = to_image(render(parts, camera, background()))
        draw = ImageDraw.Draw(img)
        for world_pos, title, subtitle, color in state.get("labels", []):
            billboard(draw, camera, world_pos, title, subtitle, color)
        hud(draw, state)
        if kind == "start":
            title_screen(img, "a brainrot collector for Roblox")
        path = os.path.join(outdir, name + ".jpg")
        quality, size = encode(img, path)
        print("%s  %dx%d  q%d  %d bytes" % (name + ".jpg", W, H, quality, size))
        # A quick sanity check that the frame is a picture of the world, not a flat panel.
        array = np.asarray(img, dtype=np.float64)
        sky = np.array([0.55, 0.72, 0.92]) * 255.0
        flat = (np.abs(array - sky).max(axis=2) < 26).mean()
        print("    mean rgb %s  unique colours %d  near-sky share %.2f" % (
            tuple(int(v) for v in array.reshape(-1, 3).mean(axis=0)),
            len(np.unique(array.reshape(-1, 3).astype(np.uint8), axis=0)),
            flat,
        ))


if __name__ == "__main__":
    main()
