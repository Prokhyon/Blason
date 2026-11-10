#!/usr/bin/env python3
"""Planche d'exploration : un d10 en forme de blason, sous plein d'angles et de formes.

    python3 explore.py .     → exploration-d10.svg (+ .png si rsvg-convert est là)

Le d10 est un vrai solide (trapézoèdre pentagonal) projeté selon l'angle de vue, puis
dessiné dans le style épuré de l'icône : aplats, interstices entre faces, une face en accent.
Version claire seulement ; les calques d'une variante retenue se font ensuite dans make.py.
"""
import math
import os
import shutil
import subprocess
import sys

BG, INK, INK_LIGHT, ACCENT, ACCENT_LIGHT = "#F4F2EC", "#2C2C2A", "#5F5E5A", "#D85A30", "#F0997B"
GAP = 2.5             # interstice entre faces (grille de 64)
ROUND = 2.0           # arrondi des coins extérieurs

SHIELDS = {           # contours d'écu pour « tailler » le dé (grille de 64)
    "arrondi": "M14 10 H50 V28 C50 41 42 50 32 56 C22 50 14 41 14 28 Z",
    "plat": "M14 10 H50 V30 L32 56 L14 30 Z",
    "normand": "M32 6 C44 6 50 13 50 22 C50 36 42 48 32 58 C22 48 14 36 14 22 C14 13 20 6 32 6 Z",
    "moderne": "M12 12 Q32 6 52 12 V30 C52 42 42 51 32 56 C22 51 12 42 12 30 Z",
}


# Le solide ---------------------------------------------------------------------------------

def d10(zigzag=0.11):
    """Sommets et faces d'un d10 : deux pôles, dix sommets en zigzag autour de l'axe."""
    ring = [(math.cos(math.radians(36 * j)), math.sin(math.radians(36 * j)),
             zigzag if j % 2 == 0 else -zigzag) for j in range(10)]
    # Hauteur des pôles pour que chaque face soit plane : le plan de z0, z1, z2 coupe l'axe.
    p, q, r = ring[0], ring[1], ring[2]
    u = [q[i] - p[i] for i in range(3)]
    v = [r[i] - p[i] for i in range(3)]
    n = (u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0])
    pole = (n[0] * p[0] + n[1] * p[1] + n[2] * p[2]) / n[2]
    verts = ring + [(0, 0, pole), (0, 0, -pole)]
    north, south = 10, 11
    faces = [[north, 2 * k, 2 * k + 1, (2 * k + 2) % 10] for k in range(5)]
    faces += [[south, (2 * k + 3) % 10, (2 * k + 2) % 10, 2 * k + 1] for k in range(5)]
    return verts, faces


def project(view):
    """Faces visibles, projetées et cadrées dans la case de 64.

    view : tilt (inclinaison vers soi, en degrés), yaw (rotation autour de l'axe),
    roll (rotation à l'écran, 180 = pointe en bas), elong (étirement de l'axe), size, dy.
    """
    verts, faces = d10(view.get("zigzag", 0.11))
    # Un zigzag plus profond rehausse les pôles : on garde la hauteur du d10 de référence.
    elong = view.get("elong", 1.0) * d10()[0][10][2] / verts[10][2]
    yaw = math.radians(54 + view.get("yaw", 0))       # 54° : la face 0 regarde le spectateur
    tilt = math.radians(view.get("tilt", 40))
    roll = math.radians(view.get("roll", 0))

    def transform(p):
        x, y, z = p[0], p[1], p[2] * elong
        x, y = x * math.cos(yaw) - y * math.sin(yaw), x * math.sin(yaw) + y * math.cos(yaw)
        y, z = y * math.cos(tilt) + z * math.sin(tilt), -y * math.sin(tilt) + z * math.cos(tilt)
        return (x, y, z)                                # le spectateur est du côté des y positifs

    world = [transform(p) for p in verts]
    visible = []
    for f in faces:
        c = [sum(world[i][k] for i in f) / len(f) for k in range(3)]
        a, b, d = world[f[0]], world[f[1]], world[f[2]]
        u = [b[k] - a[k] for k in range(3)]
        v = [d[k] - a[k] for k in range(3)]
        n = [u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]]
        if sum(n[k] * c[k] for k in range(3)) < 0:      # normale vers l'extérieur
            n = [-x for x in n]
        length = math.sqrt(sum(x * x for x in n))
        n = [x / length for x in n]
        if n[1] > 0.15:              # les faces vues par la tranche font des éclats
            visible.append((f, n))

    def screen(p):
        x, y = p[0], -p[2]
        return (x * math.cos(roll) - y * math.sin(roll), x * math.sin(roll) + y * math.cos(roll))

    pts = {i: screen(world[i]) for f, _ in visible for i in f}
    xs = [p[0] for p in pts.values()]
    ys = [p[1] for p in pts.values()]
    scale = view.get("size", 46) / max(max(xs) - min(xs), (max(ys) - min(ys)) * view.get("squash", 1))
    cx, cy = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2
    sy = view.get("squash", 1)
    wx = view.get("widen", 1)                          # étirement horizontal, après cadrage
    pts = {i: (32 + (p[0] - cx) * scale * wx, 32 + view.get("dy", 0) + (p[1] - cy) * scale * sy)
           for i, p in pts.items()}
    return visible, pts


# Dessin ------------------------------------------------------------------------------------

def colors(visible, view):
    """Couleur de chaque face : l'accent sur la ou les faces les plus en face."""
    order = sorted(range(len(visible)), key=lambda i: -visible[i][1][1])
    mode = view.get("accent", "front")
    if mode == "front":
        accent = set(order[:1])
    elif mode == "two":
        accent = set(order[:2])
    elif mode == "pole":        # toutes les faces visibles autour du pôle avant
        pole = 10 if visible[order[0]][0][0] == 10 else 11
        accent = {i for i, (f, _) in enumerate(visible) if f[0] == pole}
    else:
        accent = set()
    out = []
    for i, (f, n) in enumerate(visible):
        lit = view.get("shade") and (n[0] * -0.5 + n[2] * 0.6 + n[1] * 0.6) > 0.55
        if i in accent:
            out.append(ACCENT_LIGHT if lit and view.get("shade") == "accent" else ACCENT)
        else:
            out.append(INK_LIGHT if lit else INK)
    return out


def icon(view, x0, y0):
    visible, pts = project(view)
    fill = colors(visible, view)
    count = {}
    for f, _ in visible:
        for k in range(len(f)):
            e = frozenset((f[k], f[(k + 1) % len(f)]))
            count[e] = count.get(e, 0) + 1
    silhouette_verts = {v for e, c in count.items() if c == 1 for v in e}
    p = lambda i: f"{pts[i][0]:.2f} {pts[i][1]:.2f}"

    out = [f'<g transform="translate({x0} {y0})">', f'<rect width="64" height="64" rx="14" fill="{BG}"/>']
    clip = view.get("clip")
    if clip:
        cid = f"c{x0}-{y0}"
        out.append(f'<clipPath id="{cid}"><path d="{SHIELDS[clip]}"/></clipPath><g clip-path="url(#{cid})">')
    for (f, _), color in zip(visible, fill):
        d = "M" + " L".join(p(i) for i in f) + " Z"
        out.append(f'<path d="{d}" fill="{color}" stroke="{color}" stroke-width="{ROUND}" stroke-linejoin="round"/>')
    gaps = []
    for e, c in count.items():
        if c != 2:
            continue
        a, b = sorted(e)
        (ax, ay), (bx, by) = pts[a], pts[b]
        dx, dy = bx - ax, by - ay
        length = math.hypot(dx, dy) or 1
        ext = 4 if not clip else 12
        if a in silhouette_verts:
            ax, ay = ax - dx / length * ext, ay - dy / length * ext
        if b in silhouette_verts:
            bx, by = bx + dx / length * ext, by + dy / length * ext
        gaps.append(f"M{ax:.2f} {ay:.2f} L{bx:.2f} {by:.2f}")
    out.append(f'<path d="{" ".join(gaps)}" stroke="{BG}" stroke-width="{GAP}" stroke-linecap="round" fill="none"/>')
    if clip:
        out.append("</g>")
    out.append("</g>")
    return "".join(out)


# La série ----------------------------------------------------------------------------------

FAMILIES = [
    ("Pointe en haut : l'inclinaison", [
        ("10°", dict(tilt=10)), ("25°", dict(tilt=25)), ("40°", dict(tilt=40)),
        ("55°", dict(tilt=55)), ("70°", dict(tilt=70)), ("85°", dict(tilt=85)),
    ]),
    ("Pointe en bas : la face avant devient l'écu", [
        ("10°", dict(tilt=10, roll=180)), ("25°", dict(tilt=25, roll=180)), ("40°", dict(tilt=40, roll=180)),
        ("55°", dict(tilt=55, roll=180)), ("70°", dict(tilt=70, roll=180)), ("85°", dict(tilt=85, roll=180)),
    ]),
    ("De trois quarts", [
        ("haut 8°", dict(tilt=40, yaw=8)), ("haut 14°", dict(tilt=50, yaw=14)), ("arête", dict(tilt=40, yaw=18)),
        ("bas 8°", dict(tilt=40, yaw=8, roll=180)), ("bas 14°", dict(tilt=40, yaw=14, roll=180)),
        ("bas, arête", dict(tilt=45, yaw=18, roll=180, accent="two")),
    ]),
    ("Proportions", [
        ("trapu ×0,7", dict(tilt=40, elong=0.7)), ("élancé ×1,4", dict(tilt=40, elong=1.4)),
        ("très élancé ×1,9", dict(tilt=40, elong=1.9)), ("bas trapu ×0,7", dict(tilt=45, elong=0.7, roll=180)),
        ("bas élancé ×1,4", dict(tilt=45, elong=1.4, roll=180)), ("bas très élancé ×1,9", dict(tilt=50, elong=1.9, roll=180)),
    ]),
    ("Taillé dans un écu", [
        ("arrondi", dict(tilt=40, size=62, dy=4, clip="arrondi")),
        ("arrondi, bas", dict(tilt=45, size=60, roll=180, dy=-2, clip="arrondi")),
        ("plat, bas", dict(tilt=68, size=62, roll=180, dy=-2, clip="plat")),
        ("normand", dict(tilt=30, size=60, elong=1.5, dy=3, clip="normand")),
        ("normand, bas", dict(tilt=50, size=58, elong=1.3, roll=180, clip="normand")),
        ("moderne, 3/4", dict(tilt=45, yaw=12, size=62, roll=180, clip="moderne")),
    ]),
    ("Styles et tailles", [
        ("ombré", dict(tilt=40, shade="ink")), ("ombré, bas", dict(tilt=45, roll=180, shade="accent")),
        ("faces du pôle", dict(tilt=30, roll=180, accent="pole")), ("sans accent", dict(tilt=45, roll=180, accent="none")),
        ("petit", dict(tilt=40, roll=180, size=32)), ("grand", dict(tilt=40, roll=180, size=56)),
    ]),
]


def sheet():
    cell, gap, title, label = 64, 18, 14, 10
    cols = max(len(items) for _, items in FAMILIES)
    width = gap + cols * (cell + gap)
    parts, y = [], gap
    for name, items in FAMILIES:
        parts.append(f'<text x="{gap}" y="{y + 9}" font-family="Helvetica" font-size="8" fill="#444441">{name}</text>')
        y += title
        for col, (label_text, view) in enumerate(items):
            x = gap + col * (cell + gap)
            parts.append(icon(view, x, y))
            parts.append(f'<text x="{x + cell / 2}" y="{y + cell + 8}" font-family="Helvetica" font-size="5.5" '
                         f'text-anchor="middle" fill="#5F5E5A">{label_text}</text>')
        y += cell + label + gap
    head = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{width * 3}" height="{y * 3}" '
            f'viewBox="0 0 {width} {y}"><rect width="{width}" height="{y}" fill="#FFFFFF"/>')
    return head + "".join(parts) + "</svg>\n"


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    path = os.path.join(out, "exploration-d10.svg")
    with open(path, "w") as f:
        f.write(sheet())
    if shutil.which("rsvg-convert"):
        subprocess.run(["rsvg-convert", path, "-o", path[:-4] + ".png"], check=True)
