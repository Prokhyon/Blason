#!/usr/bin/env python3
"""Calques de l'icône Blason pour Icon Composer, et des planches d'aperçu.

    python3 make.py .

Chaque piste a son dossier avec un SVG par calque, en 1024 × 1024 sur fond transparent : le fond
et les reflets se règlent dans Icon Composer. Les calques sont numérotés dans l'ordre d'empilement
et nommés d'après leur rôle de couleur (encre, accent, accent foncé, accent clair).

Les formes sont calculées (facettes séparées par un interstice, coins arrondis) plutôt que
découpées par des traits, pour que chaque calque soit un aplat simple.
"""
import math
import os
import shutil
import subprocess
import sys

import explore

SCALE = 16            # les formes sont dessinées sur une grille de 64, l'icône fait 1024
GAP = 2.6             # interstice entre facettes (grille de 64)
RADIUS = 1.4          # arrondi des coins des facettes (grille de 64)

# Rôles « chef plat » : les coins entre le fond et le dé, le dé, la face à l'inverse du fond.
APPEARANCES = {
    "Clair": dict(bg="#F4F2EC", ink="#2C2C2A", accent="#D85A30", accent_dark="#993C1D", accent_light="#F0997B",
                  corner="#F0997B", die="#D85A30", face="#712B13"),
    "Sombre": dict(bg="#1F1F1D", ink="#E8E6DF", accent="#F0997B", accent_dark="#D85A30", accent_light="#F5C4B3",
                   corner="#993C1D", die="#D85A30", face="#F5C4B3"),
    "Teinté": dict(bg="#1F1F1D", ink="#B5D4F4", accent="#378ADD", accent_dark="#185FA5", accent_light="#85B7EB",
                   corner="#185FA5", die="#378ADD", face="#B5D4F4"),
}
FILES = {"ink": "encre", "accent": "accent", "accent_dark": "accent-fonce", "accent_light": "accent-clair",
         "corner": "coins", "die": "de", "face": "face"}


# Géométrie --------------------------------------------------------------------------------

def bezier(p0, p1, p2, p3, steps=10):
    """Points d'une courbe de Bézier cubique, sans le premier."""
    pts = []
    for i in range(1, steps + 1):
        t = i / steps
        u = 1 - t
        pts.append((u**3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t**3 * p3[0],
                    u**3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t**3 * p3[1]))
    return pts


def key(p):
    return (round(p[0], 3), round(p[1], 3))


def edges(poly):
    return [(poly[i], poly[(i + 1) % len(poly)]) for i in range(len(poly))]


def edge_count(polys):
    count = {}
    for poly in polys:
        for a, b in edges(poly):
            k = frozenset((key(a), key(b)))
            count[k] = count.get(k, 0) + 1
    return count


def inset(poly, shared, gap=GAP):
    """Rentre chaque arête commune de gap / 2 ; les arêtes du contour ne bougent pas."""
    area = sum(a[0] * b[1] - b[0] * a[1] for a, b in edges(poly))
    sign = 1 if area > 0 else -1
    lines = []
    for a, b in edges(poly):
        dx, dy = b[0] - a[0], b[1] - a[1]
        length = math.hypot(dx, dy)
        nx, ny = -dy / length * sign, dx / length * sign
        d = gap / 2 if frozenset((key(a), key(b))) in shared else 0
        lines.append(((a[0] + nx * d, a[1] + ny * d), (dx, dy)))
    out = []
    for i in range(len(lines)):
        (p, r), (q, s) = lines[i - 1], lines[i]
        cross = r[0] * s[1] - r[1] * s[0]
        if abs(cross) < 1e-9:           # arêtes alignées (courbe échantillonnée)
            out.append(q)
            continue
        t = ((q[0] - p[0]) * s[1] - (q[1] - p[1]) * s[0]) / cross
        out.append((p[0] + r[0] * t, p[1] + r[1] * t))
    return out


def rounded(poly, radius=RADIUS):
    """Chemin SVG du polygone, coins arrondis par des courbes quadratiques."""
    def toward(v, w, d):
        dx, dy = w[0] - v[0], w[1] - v[1]
        length = math.hypot(dx, dy)
        d = min(d, length / 2)
        return (v[0] + dx / length * d, v[1] + dy / length * d)

    n = len(poly)
    parts = []
    for i, v in enumerate(poly):
        a = toward(v, poly[i - 1], radius)
        b = toward(v, poly[(i + 1) % n], radius)
        parts.append(("M" if i == 0 else "L") + fmt(a) + " Q" + fmt(v) + " " + fmt(b))
    return " ".join(parts) + " Z"


def fmt(p):
    return f"{p[0] * SCALE:.1f} {p[1] * SCALE:.1f}"


def flip(poly):
    """Retourne une forme haut-bas (pointe en bas)."""
    return [(x, 64 - y) for x, y in poly]


def on_edge(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def layers(faces, order, gap=GAP):
    """faces : [(rôle, polygone)] → calques [(fichier, rôle, formes)] dans l'ordre d'empilement."""
    count = edge_count([p for _, p in faces])
    shared = {k for k, n in count.items() if n > 1}
    return [(f"{i + 1}-{FILES[role]}", role, [inset(p, shared, gap) for r, p in faces if r == role])
            for i, role in enumerate(order)]


def add_corners(faces, role="ink"):
    """Ajoute deux coins en haut à gauche et à droite pour donner au dé un chef plat (forme F)."""
    count = edge_count([p for _, p in faces])
    outline = {}
    for k, n in count.items():
        if n == 1:
            a, b = tuple(k)
            outline.setdefault(a, []).append(b)
            outline.setdefault(b, []).append(a)
    apex = min(outline, key=lambda p: (round(p[1], 2), abs(p[0] - 32)))
    corners = []
    for side in (min, max):
        extreme = side(p[0] for p in outline)
        target = min((p for p in outline if abs(p[0] - extreme) < 0.05), key=lambda p: p[1])
        chain, prev = [apex], None
        while chain[-1] != target:
            here = chain[-1]
            step = side((p for p in outline[here] if p != prev), key=lambda p: p[0])
            prev = here
            chain.append(step)
        corners.append((role, [(extreme, apex[1])] + chain))
    return faces + corners


# Pistes -----------------------------------------------------------------------------------

def d10_faces(top, left, right, bottom, kl, kr, mid, pl=None, pr=None, flat=None, curves=None):
    """Écu facetté comme un d10 : [(rôle, polygone)], la face avant en accent.

    top : sommet (ou milieu du chef si `flat` donne ses coins) ; kl, kr, mid : la face avant ;
    pl, pr : point où l'arête des côtés rejoint le contour plus bas (« côtés en pointe ») ;
    curves : points de contrôle des flancs inférieurs (écu arrondi).
    """
    pl, pr = pl or left, pr or right
    lower_left = [pl, kl, mid, bottom]
    lower_right = [pr, bottom, mid, kr]
    if curves:
        lower_left = [pl, kl, mid, bottom] + bezier(bottom, curves[1], curves[0], left)[:-1]
        lower_right = [pr] + bezier(right, curves[2], curves[3], bottom)[:-1] + [bottom, mid, kr]
    upper_left = [top, kl, pl] + ([left] if pl != left else [])
    upper_right = [top, right, pr, kr] if pr != right else [top, right, kr]
    if flat:
        upper_left = [flat[0], top, kl, left]
        upper_right = [top, flat[1], right, kr]
    front = [top, kr, mid, kl]
    return [("ink", upper_left), ("ink", upper_right), ("ink", lower_left), ("ink", lower_right),
            ("accent", front)]


def d10(order=("ink", "accent"), gap=GAP, **shape):
    return layers(d10_faces(**shape), order, gap)


def projected(view):
    """Un vrai d10 projeté (voir explore.py) : [(rôle, polygone)], la face la plus en face en accent."""
    visible, pts = explore.project(view)
    front = max(range(len(visible)), key=lambda i: visible[i][1][1])
    return [("accent" if i == front else "ink", [pts[v] for v in f]) for i, (f, _) in enumerate(visible)]


def recolor(faces, others, main):
    """Toutes les faces du dé dans `others`, la face principale dans `main`."""
    return [(main if r == "accent" else others, p) for r, p in faces]


def chef(faces):
    """Le dé (face principale à part) avec deux coins qui lui donnent un chef plat."""
    return layers(add_corners(recolor(faces, "die", "face"), role="corner"), ["corner", "die", "face"])


def d20_shield():
    """Écu taillé comme un d20 : une face centrale, sept facettes autour."""
    tl, t, tr, r, b, l = (14, 10), (32, 10), (50, 10), (50, 28), (32, 56), (14, 28)
    a, br, bl = (32, 21), (41.5, 37), (22.5, 37)
    left_curve = bezier(b, (22, 50), (14, 41), l)[:-1]
    right_curve = bezier(r, (50, 41), (42, 50), b)[:-1]
    faces = [("ink", [tl, t, a]), ("ink", [t, tr, a]), ("ink", [tl, a, bl, l]), ("ink", [tr, r, br, a]),
             ("ink", [bl, br, b]), ("ink", [l, bl, b] + left_curve), ("ink", [br, r] + right_curve + [b]),
             ("accent", [a, br, bl])]
    return layers(faces, ["ink", "accent"])


def shield_path(radius=2.5):
    poly = [(14, 10), (50, 10), (50, 28)] + bezier((50, 28), (50, 41), (42, 50), (32, 56))[:-1] \
        + [(32, 56)] + bezier((32, 56), (22, 50), (14, 41), (14, 28))[:-1]
    return rounded(poly, radius)


def d10_in_shield(shield_role, die_role):
    """Un écu simple, un petit d10 au milieu ; les interstices du dé laissent voir l'écu."""
    k, cx, cy = 0.6, 32, 30
    s = lambda p: (cx + (p[0] - 32) * k, cy + (p[1] - 32) * k)
    die = d10_faces(**{name: s(p) for name, p in A.items()})
    die = layers([(die_role, p) for _, p in die], [die_role], gap=2.0)
    return [(f"1-{FILES[shield_role]}", shield_role, [shield_path()])] + \
        [(f"2-{FILES[die_role]}", die_role, shapes) for _, _, shapes in die]


def blocks_2b():
    """Écu en blocs : en-tête, deux colonnes (portrait en creux à gauche), pointe."""
    s = lambda x, y: f"{x * SCALE:.1f} {y * SCALE:.1f}"
    r = RADIUS * 2
    def rect(x, y, w, h):
        return (f"M{s(x + r, y)} L{s(x + w - r, y)} Q{s(x + w, y)} {s(x + w, y + r)} "
                f"L{s(x + w, y + h - r)} Q{s(x + w, y + h)} {s(x + w - r, y + h)} "
                f"L{s(x + r, y + h)} Q{s(x, y + h)} {s(x, y + h - r)} L{s(x, y + r)} Q{s(x, y)} {s(x + r, y)} Z")
    left = (f"M{s(14 + r, 22)} L{s(30.5 - r, 22)} Q{s(30.5, 22)} {s(30.5, 22 + r)} L{s(30.5, 37 - r)} "
            f"Q{s(30.5, 37)} {s(30.5 - r, 37)} L{s(27, 37)} C{s(27, 32.4)} {s(17.5, 32.4)} {s(17.5, 37)} "
            f"L{s(14 + r, 37)} Q{s(14, 37)} {s(14, 37 - r)} L{s(14, 22 + r)} Q{s(14, 22)} {s(14 + r, 22)} Z "
            # tête : un trou dans le bloc (règle evenodd)
            f"M{s(22.25 + 2.7, 27.6)} A{2.7 * SCALE} {2.7 * SCALE} 0 1 0 {s(22.25 - 2.7, 27.6)} "
            f"A{2.7 * SCALE} {2.7 * SCALE} 0 1 0 {s(22.25 + 2.7, 27.6)} Z")
    point = (f"M{s(14 + r, 40)} L{s(50 - r, 40)} Q{s(50, 40)} {s(50, 40 + r)} L{s(50, 44)} "
             f"C{s(50, 49)} {s(41, 53)} {s(33.4, 55.4)} Q{s(32, 56)} {s(30.6, 55.4)} "
             f"C{s(23, 53)} {s(14, 49)} {s(14, 44)} L{s(14, 40 + r)} Q{s(14, 40)} {s(14 + r, 40)} Z")
    return [("1-encre", "ink", [left, rect(33.5, 22, 16.5, 15), point]),
            ("2-accent", "accent", [rect(14, 10, 36, 9)])]


A = dict(top=(32, 7), left=(13, 26), right=(51, 26), bottom=(32, 57), kl=(23, 27.5), kr=(41, 27.5), mid=(32, 38))
C = dict(top=(32, 9), left=(12, 28), right=(52, 28), bottom=(32, 55), kl=(22.5, 29.5), kr=(41.5, 29.5), mid=(32, 40))
E = dict(top=(32, 9), left=(10, 33), right=(54, 33), bottom=(32, 56), kl=(20.6, 31), kr=(43.4, 31), mid=(32, 36.5))
SLENDER = dict(tilt=40, elong=1.4, size=46)          # « élancé ×1,4 » de la planche d'exploration


def pointed(shape, t):
    return dict(shape, pl=on_edge(shape["left"], shape["bottom"], t), pr=on_edge(shape["right"], shape["bottom"], t))


DESIGNS = {
    "2b": blocks_2b(),
    "N1-A": d10(**A),
    "N1-B": d10(**pointed(A, 0.3)),
    "N1-H": d10(**pointed(A, 0.1)),      # H, I, J : entre A et B
    "N1-I": d10(**pointed(A, 0.15)),
    "N1-J": d10(**pointed(A, 0.2)),
    "N1-C": d10(**C),
    "N1-D": d10(**pointed(C, 0.3)),
    "N1-E": d10(**E),
    "N1-E-bas": layers([(r, flip(p)) for r, p in d10_faces(**E)], ["ink", "accent"]),
    "N1-F": d10(top=(32, 10), left=(14, 27), right=(50, 27), bottom=(32, 56), kl=(23, 27.5), kr=(41, 27.5),
                mid=(32, 38), flat=((14, 10), (50, 10))),
    "N1-G": d10(top=(32, 10), left=(14, 28), right=(50, 28), bottom=(32, 56), kl=(23, 28), kr=(41, 28),
                mid=(32, 39), flat=((14, 10), (50, 10)), curves=((14, 41), (22, 50), (50, 41), (42, 50))),
    "Bas-25": layers(projected(dict(tilt=25, roll=180, size=46)), ["ink", "accent"]),
    # Chef plat : le dé en couleur, deux coins en haut pour former l'écu.
    "Chef-C": chef(d10_faces(**C)),
    "Chef-Elance": chef(projected(SLENDER)),
    "Chef-E-bas": chef([(r, flip(p)) for r, p in d10_faces(**E)]),
    "Chef-Bas-25": chef(projected(dict(tilt=25, roll=180, size=46))),
    "D20-ecu": d20_shield(),
    "D10-ecu": d10_in_shield("ink", "accent"),
    "D10-ecu-accent": d10_in_shield("accent", "ink"),
}

SHEETS = {
    "planche-selection.svg": ["N1-A", "N1-C", "N1-E-bas", "N1-G", "Bas-25", "D20-ecu", "D10-ecu", "D10-ecu-accent"],
    "planche-chef-plat.svg": ["Chef-C", "Chef-Elance", "Chef-E-bas", "Chef-Bas-25"],
}

# Variantes de Chef-Élancé : moins incliné, le bas du dé s'épaissit ; un zigzag plus profond
# (sommets de la ceinture plus hauts ou plus bas) agrandit aussi les facettes du bas.
ELANCE = {
    "Chef-Elance": ("40° ×1,4", SLENDER),
    "Chef-Elance-2": ("32° ×1,4", dict(tilt=32, elong=1.4)),
    "Chef-Elance-3": ("25° ×1,4", dict(tilt=25, elong=1.4)),
    "Chef-Elance-4": ("32° ×1,7", dict(tilt=32, elong=1.7)),
    "Chef-Elance-5": ("32° ×1,4 zz", dict(tilt=32, elong=1.4, zigzag=0.18)),
    "Chef-Elance-6": ("25° ×1,7 zz", dict(tilt=25, elong=1.7, zigzag=0.18)),
    "Chef-Elance-7": ("36° ×1,2 zzz", dict(tilt=36, elong=1.2, zigzag=0.24)),
    "Chef-Elance-8": ("28° ×2 zz", dict(tilt=28, elong=2.0, zigzag=0.15)),
    "Chef-Elance-34": ("34° ×1,4", dict(tilt=34, elong=1.4)),
    # 32° retenu, élargi un peu
    "Chef-Elance-32-l6": ("32° large 6 %", dict(tilt=32, elong=1.4, widen=1.06)),
    "Chef-Elance-32-l12": ("32° large 12 %", dict(tilt=32, elong=1.4, widen=1.12, dy=2)),   # descendu de 2 (validé)
    "Chef-Elance-32-l18": ("32° large 18 %", dict(tilt=32, elong=1.4, widen=1.18)),
}
for name, (_, view) in ELANCE.items():
    DESIGNS[name] = chef(projected(dict(view, size=46)))
SHEETS["planche-chef-elance.svg"] = list(ELANCE)
SHEETS["planche-chef-elance-32-34.svg"] = ["Chef-Elance-2", "Chef-Elance-34"]
SHEETS["planche-chef-elance-32-large.svg"] = ["Chef-Elance-2", "Chef-Elance-32-l6", "Chef-Elance-32-l12",
                                              "Chef-Elance-32-l18"]
LABELS = {name: label for name, (label, _) in ELANCE.items()}

# Couleurs de la forme retenue. Règles : les coins entre le fond et le dé en luminosité,
# la face principale à l'inverse du fond (foncée en clair, claire en sombre).
CHOSEN = "Chef-Elance-32-l12"


def palette(light, dark):
    """(coins, dé, face) en clair puis en sombre."""
    return {"Clair": dict(zip(("corner", "die", "face"), light)),
            "Sombre": dict(zip(("corner", "die", "face"), dark))}


HUES = {
    "Terre cuite": palette(("#F0997B", "#D85A30", "#712B13"), ("#993C1D", "#D85A30", "#F5C4B3")),
    "Gueules": palette(("#F09595", "#E24B4A", "#791F1F"), ("#A32D2D", "#E24B4A", "#F7C1C1")),
    "Or": palette(("#FAC775", "#EF9F27", "#633806"), ("#854F0B", "#EF9F27", "#FAEEDA")),
    "Sinople": palette(("#97C459", "#639922", "#27500A"), ("#3B6D11", "#639922", "#C0DD97")),
    "Sarcelle": palette(("#5DCAA5", "#1D9E75", "#085041"), ("#0F6E56", "#1D9E75", "#9FE1CB")),
    "Azur": palette(("#85B7EB", "#378ADD", "#0C447C"), ("#185FA5", "#378ADD", "#B5D4F4")),
    "Pourpre": palette(("#AFA9EC", "#7F77DD", "#3C3489"), ("#534AB7", "#7F77DD", "#CECBF6")),
    "Graphite": palette(("#B4B2A9", "#5F5E5A", "#2C2C2A"), ("#444441", "#888780", "#F1EFE8")),
}
CONTRASTS = {
    "Doux": palette(("#F0997B", "#D85A30", "#993C1D"), ("#993C1D", "#D85A30", "#F0997B")),
    "Actuel": HUES["Terre cuite"],
    "Fort": palette(("#F5C4B3", "#D85A30", "#4A1B0C"), ("#712B13", "#D85A30", "#FAECE7")),
    "Coins proches du dé": palette(("#E8805A", "#D85A30", "#712B13"), ("#B5492A", "#D85A30", "#F5C4B3")),
    "Azur et or": palette(("#FAC775", "#378ADD", "#0C447C"), ("#854F0B", "#378ADD", "#FAEEDA")),
    "Gueules et or": palette(("#FAC775", "#E24B4A", "#791F1F"), ("#854F0B", "#E24B4A", "#FAEEDA")),
}


def metal_corners(pal, light, dark):
    """Mêmes dé et face, coins d'un métal héraldique (or, argent)."""
    return {"Clair": dict(pal["Clair"], corner=light), "Sombre": dict(pal["Sombre"], corner=dark)}


GOLD, SILVER = ("#FAC775", "#BA7517"), ("#D3D1C7", "#888780")     # or « +2 » en sombre
# Pas de métal sur métal : la teinte Or prend des coins d'argent dans la série « or ».
HUES_GOLD = {name: metal_corners(pal, *(SILVER if name == "Or" else GOLD)) for name, pal in HUES.items()}
HUES_SILVER = {name: metal_corners(pal, *SILVER) for name, pal in HUES.items()}
PALETTE_SHEETS = {"planche-couleurs-teintes.svg": HUES, "planche-couleurs-contrastes.svg": CONTRASTS,
                  "planche-couleurs-or.svg": HUES_GOLD, "planche-couleurs-argent.svg": HUES_SILVER}

# Essais : un or plus lumineux en sombre, d'autres fonds clairs.
GOLD_DARK_TRIALS = {"actuel": "#854F0B", "+1": "#A66A12", "+2": "#BA7517", "+3": "#D9911F", "+4": "#EF9F27"}
LIGHT_BACKGROUNDS = {"crème (actuel)": "#F4F2EC", "blanc": "#FFFFFF", "parchemin": "#F3EAD8", "ivoire": "#FAF3E1",
                     "gris perle": "#ECEEF0", "teinte claire": None}
HUE_TINTS = {"Terre cuite": "#FAECE7", "Gueules": "#FCEBEB", "Or": "#FAEEDA", "Sinople": "#EAF3DE",
             "Sarcelle": "#E1F5EE", "Azur": "#E6F1FB", "Pourpre": "#EEEDFE", "Graphite": "#F1EFE8"}
GRIDS = {
    "planche-or-sombre.svg": [
        (f"or {label}", "Sombre", lambda name, c, g=gold: c if name == "Or" else dict(c, corner=g))
        for label, gold in GOLD_DARK_TRIALS.items()],
    "planche-fonds-clairs.svg": [
        (label, "Clair", lambda name, c, bg=bg: dict(c, bg=bg or HUE_TINTS[name]))
        for label, bg in LIGHT_BACKGROUNDS.items()],
}


# Sortie -----------------------------------------------------------------------------------

def paths(shapes):
    return [s if isinstance(s, str) else rounded(s) for s in shapes]


def layer_svg(shapes, color):
    body = "".join(f'<path d="{d}" fill="{color}" fill-rule="evenodd"/>' for d in paths(shapes))
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">{body}</svg>\n'


def write(out, designs):
    for name, design in designs.items():
        folder = os.path.join(out, name)
        if os.path.isdir(folder):
            shutil.rmtree(folder)       # dossiers générés : on repart de zéro
        os.makedirs(folder)
        for filename, role, shapes in design:
            with open(os.path.join(folder, f"{filename}.svg"), "w") as f:
                f.write(layer_svg(shapes, APPEARANCES["Clair"][role]))


def sheet(out, designs, names, filename):
    """Planche : une ligne par apparence, une colonne par piste, plus la taille 29 pt."""
    cell, pad, label = 1024, 160, 120
    width = pad + len(names) * (cell + pad)
    height = label + len(APPEARANCES) * (cell + pad) + 600
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width // 8}" height="{height // 8}" '
             f'viewBox="0 0 {width} {height}"><rect width="{width}" height="{height}" fill="#FFFFFF"/>']

    def icon(x, y, size, name, appearance):
        colors = APPEARANCES[appearance]
        g = [f'<g transform="translate({x} {y}) scale({size / 1024})">',
             f'<rect width="1024" height="1024" rx="230" fill="{colors["bg"]}"/>']
        for _, role, shapes in designs[name]:
            g += [f'<path d="{d}" fill="{colors[role]}" fill-rule="evenodd"/>' for d in paths(shapes)]
        return "".join(g) + "</g>"

    for col, name in enumerate(names):
        x = pad + col * (cell + pad)
        parts.append(f'<text x="{x + cell / 2}" y="{label - 20}" font-family="Helvetica" font-size="90" '
                     f'text-anchor="middle" fill="#444441">{LABELS.get(name, name)}</text>')
        for row, appearance in enumerate(APPEARANCES):
            parts.append(icon(x, label + row * (cell + pad), cell, name, appearance))
        parts.append(icon(x + cell / 2 - 116, label + len(APPEARANCES) * (cell + pad) + 100, 232, name, "Clair"))
    parts.append("</svg>\n")
    path = os.path.join(out, filename)
    with open(path, "w") as f:
        f.write("".join(parts))
    if shutil.which("rsvg-convert"):
        subprocess.run(["rsvg-convert", path, "-o", path[:-4] + ".png"], check=True)


def palette_sheet(out, design, palettes, filename):
    """Une forme sous plusieurs palettes : une colonne par palette, clair, sombre, puis 29 pt."""
    cell, pad, label = 1024, 160, 120
    rows = ["Clair", "Sombre"]
    width = pad + len(palettes) * (cell + pad)
    height = label + len(rows) * (cell + pad) + 600
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width // 8}" height="{height // 8}" '
             f'viewBox="0 0 {width} {height}"><rect width="{width}" height="{height}" fill="#FFFFFF"/>']

    def icon(x, y, size, colors):
        g = [f'<g transform="translate({x} {y}) scale({size / 1024})">',
             f'<rect width="1024" height="1024" rx="230" fill="{colors["bg"]}"/>']
        for _, role, shapes in design:
            g += [f'<path d="{d}" fill="{colors[role]}" fill-rule="evenodd"/>' for d in paths(shapes)]
        return "".join(g) + "</g>"

    for col, (name, pal) in enumerate(palettes.items()):
        x = pad + col * (cell + pad)
        parts.append(f'<text x="{x + cell / 2}" y="{label - 20}" font-family="Helvetica" font-size="80" '
                     f'text-anchor="middle" fill="#444441">{name}</text>')
        for row, appearance in enumerate(rows):
            parts.append(icon(x, label + row * (cell + pad), cell, {**APPEARANCES[appearance], **pal[appearance]}))
        parts.append(icon(x + cell / 2 - 116, label + len(rows) * (cell + pad) + 100, 232,
                          {**APPEARANCES["Clair"], **pal["Clair"]}))
    parts.append("</svg>\n")
    path = os.path.join(out, filename)
    with open(path, "w") as f:
        f.write("".join(parts))
    if shutil.which("rsvg-convert"):
        subprocess.run(["rsvg-convert", path, "-o", path[:-4] + ".png"], check=True)


def icon_group(x, y, size, design, colors):
    g = [f'<g transform="translate({x} {y}) scale({size / 1024})">',
         f'<rect width="1024" height="1024" rx="230" fill="{colors["bg"]}"/>']
    for _, role, shapes in design:
        g += [f'<path d="{d}" fill="{colors[role]}" fill-rule="evenodd"/>' for d in paths(shapes)]
    return "".join(g) + "</g>"


def grid(out, design, columns, rows, filename):
    """Une forme : une colonne par palette, une ligne par essai (rows : libellé, apparence, retouche)."""
    cell, pad, label, left = 1024, 160, 120, 760
    width = left + len(columns) * (cell + pad)
    height = label + len(rows) * (cell + pad)
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width // 8}" height="{height // 8}" '
             f'viewBox="0 0 {width} {height}"><rect width="{width}" height="{height}" fill="#FFFFFF"/>']
    for col, name in enumerate(columns):
        x = left + col * (cell + pad)
        parts.append(f'<text x="{x + cell / 2}" y="{label - 20}" font-family="Helvetica" font-size="80" '
                     f'text-anchor="middle" fill="#444441">{name}</text>')
    for row, (row_label, appearance, adjust) in enumerate(rows):
        y = label + row * (cell + pad)
        parts.append(f'<text x="{left - 60}" y="{y + cell / 2 + 28}" font-family="Helvetica" font-size="80" '
                     f'text-anchor="end" fill="#444441">{row_label}</text>')
        for col, (name, pal) in enumerate(columns.items()):
            colors = adjust(name, {**APPEARANCES[appearance], **pal[appearance]})
            parts.append(icon_group(left + col * (cell + pad), y, cell, design, colors))
    parts.append("</svg>\n")
    path = os.path.join(out, filename)
    with open(path, "w") as f:
        f.write("".join(parts))
    if shutil.which("rsvg-convert"):
        subprocess.run(["rsvg-convert", path, "-o", path[:-4] + ".png"], check=True)


# Versions finales ---------------------------------------------------------------------------

def final_sets():
    """Les huit teintes, unies et avec des coins en métal (or, ou argent pour la teinte Or)."""
    sets = {}
    for name in HUES:
        slug = name.replace(" ", "-")
        sets[slug] = (name, "unie", HUES[name])
        sets[f"{slug}-{'argent' if name == 'Or' else 'or'}"] = (name, "coins argent" if name == "Or" else "coins or",
                                                                HUES_GOLD[name])
    return sets


def write_final(out):
    """Finale/<teinte>/ : les calques aux couleurs claires, et deux aperçus complets."""
    base = os.path.join(out, "Finale")
    if os.path.isdir(base):
        shutil.rmtree(base)
    design = DESIGNS[CHOSEN]
    rows = []
    for slug, (name, kind, pal) in final_sets().items():
        folder = os.path.join(base, slug)
        os.makedirs(folder)
        for filename, role, shapes in design:
            with open(os.path.join(folder, f"{filename}.svg"), "w") as f:
                f.write(layer_svg(shapes, pal["Clair"][role]))
        for appearance in ("Clair", "Sombre"):
            colors = {**APPEARANCES[appearance], **pal[appearance]}
            with open(os.path.join(folder, f"apercu-{appearance.lower()}.svg"), "w") as f:
                f.write('<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">'
                        + icon_group(0, 0, 1024, design, colors) + "</svg>\n")
        c, d = pal["Clair"], pal["Sombre"]
        rows.append(f"| `{slug}` | {name}, {kind} | `{c['corner']}` / `{d['corner']}` | "
                    f"`{c['die']}` / `{d['die']}` | `{c['face']}` / `{d['face']}` |")
    light, dark = APPEARANCES["Clair"]["bg"], APPEARANCES["Sombre"]["bg"]
    readme = f"""# Icône Blason : versions finales

Généré par `make.py` (ne pas modifier à la main) : forme `{CHOSEN}`, une version par teinte.

Les documents Icon Composer complets, prêts à l'emploi, sont dans `../Icones`. Les dossiers ci-dessous
servent à reconstruire une icône à la main.

## Essayer dans Icon Composer

Dans le dossier d'une teinte, glisser dans l'ordre :

1. `1-coins.svg` (tout en bas),
2. `2-de.svg`,
3. `3-face.svg` (au-dessus).

Les calques portent les couleurs de l'apparence claire. Pour l'apparence sombre, changer la couleur de
chaque calque d'après le tableau ; le fond se règle dans Icon Composer : `{light}` en clair, `{dark}` en sombre.
L'apparence teintée se calcule seule. `apercu-clair.svg` et `apercu-sombre.svg` montrent le résultat attendu,
sans le verre.

## Couleurs (clair / sombre)

| Dossier | Teinte | Coins | Dé | Face |
|---|---|---|---|---|
""" + "\n".join(rows) + "\n"
    with open(os.path.join(base, "README.md"), "w") as f:
        f.write(readme)


# Position verticale ---------------------------------------------------------------------------
# Le dé est centré sur sa boîte, mais le chef plat et la pointe le font paraître haut :
# on le descend de quelques unités (grille de 64 ; 1 = 16 px dans l'icône de 1024).

CHOSEN_VIEW = dict(tilt=32, elong=1.4, widen=1.12, size=46)   # sans dy : la planche le fait varier
POSITIONS = (0, 1, 2, 3, 4)
POSITION_DESIGNS = {dy: chef(projected(dict(CHOSEN_VIEW, dy=dy))) for dy in POSITIONS}


def position_sheet(out, filename, pal):
    """Chaque décalage en clair et en sombre, avec les axes du centre de l'icône."""
    cell, pad, label = 1024, 160, 120
    width = pad + len(POSITIONS) * (cell + pad)
    height = label + 2 * (cell + pad) + 600
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width // 8}" height="{height // 8}" '
             f'viewBox="0 0 {width} {height}"><rect width="{width}" height="{height}" fill="#FFFFFF"/>']
    for col, dy in enumerate(POSITIONS):
        x = pad + col * (cell + pad)
        design = POSITION_DESIGNS[dy]
        parts.append(f'<text x="{x + cell / 2}" y="{label - 20}" font-family="Helvetica" font-size="80" '
                     f'text-anchor="middle" fill="#444441">+{dy} ({dy * 16} px)</text>')
        for row, appearance in enumerate(("Clair", "Sombre")):
            y = label + row * (cell + pad)
            parts.append(icon_group(x, y, cell, design, {**APPEARANCES[appearance], **pal[appearance]}))
            parts.append(f'<path d="M{x + 512} {y} V{y + 1024} M{x} {y + 512} H{x + 1024}" '
                         f'stroke="#378ADD" stroke-width="3" stroke-dasharray="16 12" opacity="0.6"/>')
        parts.append(icon_group(x + cell / 2 - 116, label + 2 * (cell + pad) + 100, 232, design,
                                {**APPEARANCES["Clair"], **pal["Clair"]}))
    parts.append("</svg>\n")
    path = os.path.join(out, filename)
    with open(path, "w") as f:
        f.write("".join(parts))
    if shutil.which("rsvg-convert"):
        subprocess.run(["rsvg-convert", path, "-o", path[:-4] + ".png"], check=True)


# Exemples à plusieurs couches -------------------------------------------------------------------
# Icon Composer donne à chaque groupe de calques du verre, des reflets, une ombre et de la
# profondeur. Ces exemples séparent davantage les calques ; l'aperçu simule grossièrement le verre
# (ombre portée, reflet en haut, transparence), le vrai rendu se voit dans Icon Composer.

LAYERED_DY = 2


def raw_chosen(dy=LAYERED_DY):
    return add_corners(recolor(projected(dict(CHOSEN_VIEW, dy=dy)), "die", "face"), role="corner")


def outline(faces):
    """Contour extérieur de l'ensemble des faces, dans l'ordre."""
    count = edge_count([p for _, p in faces])
    nxt = {}
    for k, n in count.items():
        if n == 1:
            a, b = tuple(k)
            nxt.setdefault(a, []).append(b)
            nxt.setdefault(b, []).append(a)
    start = next(iter(nxt))
    loop, prev = [start], None
    while True:
        here = loop[-1]
        step = next(p for p in nxt[here] if p != prev)
        if step == start:
            return loop
        prev = here
        loop.append(step)


def zero_glyph(face):
    """Un « 0 » de dé, centré sur la face principale."""
    xs, ys = [p[0] for p in face], [p[1] for p in face]
    cx, cy = (min(xs) + max(xs)) / 2, min(ys) + (max(ys) - min(ys)) * 0.42
    rx, ry = (max(xs) - min(xs)) * 0.2, (max(ys) - min(ys)) * 0.22
    t = rx * 0.45
    def ellipse(a, b):
        return (f"M{(cx + a) * SCALE:.1f} {cy * SCALE:.1f} A{a * SCALE:.1f} {b * SCALE:.1f} 0 1 0 "
                f"{(cx - a) * SCALE:.1f} {cy * SCALE:.1f} A{a * SCALE:.1f} {b * SCALE:.1f} 0 1 0 "
                f"{(cx + a) * SCALE:.1f} {cy * SCALE:.1f} Z")
    return ellipse(rx, ry) + " " + ellipse(rx - t, ry - t)


def layered_examples():
    """{nom: [(fichier, rôle, formes, effets)]} ; effets : opacité, ombre, reflet."""
    faces = raw_chosen()
    base = layers(faces, ["corner", "die", "face"])
    corners, die, face = base
    glass = dict(shadow=True, highlight=True)
    face_poly = face[2][0]
    plaque = ("1-plaque", "corner", [rounded(outline(faces), 2.0)], dict(opacity=0.55, highlight=True))
    return {
        "Plat": [(f, r, s, {}) for f, r, s in base],
        "Verre": [(f, r, s, glass) for f, r, s in base],
        "Chiffre": [(f, r, s, glass) for f, r, s in base] + [("4-chiffre", "corner", [zero_glyph(face_poly)], glass)],
        "Coins-depolis": [(corners[0], "corner", corners[2], dict(opacity=0.45, highlight=True)),
                          (die[0], "die", die[2], glass), (face[0], "face", face[2], glass)],
        "Plaque": [plaque, ("2-de", "die", die[2], glass), ("3-face", "face", face[2], glass)],
    }


def glass_group(x, y, size, layers_fx, colors, uid):
    k = size / 1024
    g = [f'<g transform="translate({x} {y}) scale({k})">',
         f'<rect width="1024" height="1024" rx="230" fill="{colors["bg"]}"/>']
    for i, (_, role, shapes, fx) in enumerate(layers_fx):
        ds = paths(shapes)
        if fx.get("shadow"):
            g += [f'<path d="{d}" fill="#000000" opacity="0.28" filter="url(#ombre)" fill-rule="evenodd"/>' for d in ds]
        g += [f'<path d="{d}" fill="{colors[role]}" opacity="{fx.get("opacity", 1)}" fill-rule="evenodd"/>' for d in ds]
        if fx.get("highlight"):
            g += [f'<path d="{d}" fill="url(#reflet)" fill-rule="evenodd"/>' for d in ds]
            g += [f'<path d="{d}" fill="none" stroke="#FFFFFF" stroke-opacity="0.35" stroke-width="5" '
                  f'fill-rule="evenodd"/>' for d in ds]
    return "".join(g) + "</g>"


def layered_sheet(out, examples, pal, filename):
    cell, pad, label = 1024, 160, 120
    width = pad + len(examples) * (cell + pad)
    height = label + 2 * (cell + pad) + 600
    defs = ('<defs><filter id="ombre" x="-20%" y="-20%" width="140%" height="140%">'
            '<feGaussianBlur stdDeviation="14"/><feOffset dy="14"/></filter>'
            '<linearGradient id="reflet" x1="0" y1="0" x2="0" y2="1">'
            '<stop offset="0" stop-color="#FFFFFF" stop-opacity="0.45"/>'
            '<stop offset="0.55" stop-color="#FFFFFF" stop-opacity="0"/></linearGradient></defs>')
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width // 8}" height="{height // 8}" '
             f'viewBox="0 0 {width} {height}">{defs}<rect width="{width}" height="{height}" fill="#FFFFFF"/>']
    for col, (name, layers_fx) in enumerate(examples.items()):
        x = pad + col * (cell + pad)
        parts.append(f'<text x="{x + cell / 2}" y="{label - 20}" font-family="Helvetica" font-size="80" '
                     f'text-anchor="middle" fill="#444441">{name}</text>')
        for row, appearance in enumerate(("Clair", "Sombre")):
            colors = {**APPEARANCES[appearance], **pal[appearance]}
            parts.append(glass_group(x, label + row * (cell + pad), cell, layers_fx, colors, f"{col}{row}"))
        parts.append(glass_group(x + cell / 2 - 116, label + 2 * (cell + pad) + 100, 232, layers_fx,
                                 {**APPEARANCES["Clair"], **pal["Clair"]}, f"{col}p"))
    parts.append("</svg>\n")
    path = os.path.join(out, filename)
    with open(path, "w") as f:
        f.write("".join(parts))
    if shutil.which("rsvg-convert"):
        subprocess.run(["rsvg-convert", path, "-o", path[:-4] + ".png"], check=True)


def write_layered(out, examples, pal):
    """Couches/<exemple>/ : les calques à importer, un groupe par calque dans Icon Composer."""
    base = os.path.join(out, "Couches")
    if os.path.isdir(base):
        shutil.rmtree(base)
    for name, layers_fx in examples.items():
        if name == "Plat":
            continue
        folder = os.path.join(base, name)
        os.makedirs(folder)
        for filename, role, shapes, _ in layers_fx:
            with open(os.path.join(folder, f"{filename}.svg"), "w") as f:
                f.write(layer_svg(shapes, pal["Clair"][role]))


# Icônes Icon Composer ---------------------------------------------------------------------------
# Icones/Blason-<teinte>.icon : un document Icon Composer complet par teinte (calques, couleurs
# claires et sombres, fond), prêt à glisser dans Xcode. Le teinté est calculé par le système.
# Si Icon Composer est installé, ictool en tire le vrai rendu Liquid Glass.

ICTOOL = "/Applications/Icon Composer.app/Contents/Executables/ictool"
RENDITIONS = {"clair": "Default", "sombre": "Dark", "teinte": "TintedDark", "transparent": "ClearLight"}


def srgb(color):
    r, g, b = (int(color[i:i + 2], 16) / 255 for i in (1, 3, 5))
    return f"srgb:{r:.5f},{g:.5f},{b:.5f},1.00000"


def specialized(light, dark, key="solid"):
    return [{"value": {key: srgb(light)}}, {"appearance": "dark", "value": {key: srgb(dark)}}]


def icon_document(design, pal):
    """icon.json : un groupe par calque, le plus haut d'abord (comme la liste d'Icon Composer)."""
    groups = []
    for filename, role, _ in reversed(design):
        layer = {"blend-mode": "normal", "glass": True, "hidden": False,
                 "fill-specializations": specialized(pal["Clair"][role], pal["Sombre"][role]),
                 "image-name": f"{filename}.svg", "name": filename.split("-", 1)[1],
                 "position": {"scale": 1, "translation-in-points": [0, 0]}}
        groups.append({"blur-material": None, "hidden": False, "layers": [layer], "lighting": "individual",
                       "shadow": {"kind": "neutral", "opacity": 0.5}, "specular": True,
                       "translucency": {"enabled": True, "value": 0.5}})
    return {"fill-specializations": specialized(APPEARANCES["Clair"]["bg"], APPEARANCES["Sombre"]["bg"]),
            "groups": groups,
            "supported-platforms": {"circles": ["watchOS"], "squares": "shared"}}


MAIN_ICON = "Terre-cuite"                                  # l'icône de l'app ; les autres sont alternatives
APP = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "Blason")


def write_icon_bundle(bundle, design, pal):
    import json
    if os.path.isdir(bundle):
        shutil.rmtree(bundle)
    os.makedirs(os.path.join(bundle, "Assets"))
    for filename, role, shapes in design:
        with open(os.path.join(bundle, "Assets", f"{filename}.svg"), "w") as f:
            f.write(layer_svg(shapes, pal["Clair"][role]))
    with open(os.path.join(bundle, "icon.json"), "w") as f:
        json.dump(icon_document(design, pal), f, indent=2, ensure_ascii=False)
        f.write("\n")


def alternate_names():
    return [f"AppIcon-{slug}" for slug in final_sets() if slug != MAIN_ICON]


def write_icons(out):
    base = os.path.join(out, "Icones")
    if os.path.isdir(base):
        shutil.rmtree(base)
    design = DESIGNS[CHOSEN]
    renders = os.path.join(base, "Rendus")
    os.makedirs(renders)
    for slug, (_, _, pal) in final_sets().items():
        bundle = os.path.join(base, f"Blason-{slug}.icon")
        write_icon_bundle(bundle, design, pal)
        if os.path.exists(ICTOOL):
            for suffix, rendition in RENDITIONS.items():
                subprocess.run([ICTOOL, bundle, "--export-image", "--output-file",
                                os.path.join(renders, f"{slug}-{suffix}.png"), "--platform", "iOS",
                                "--rendition", rendition, "--width", "1024", "--height", "1024", "--scale", "1"],
                               check=True, capture_output=True)
    if os.path.exists(ICTOOL):
        render_sheet(out, renders)


def install_icons(app=APP):
    """Dans l'app : AppIcon.icon (MAIN_ICON) et AppIcons/AppIcon-<teinte>.icon (les alternatives,
    listées dans ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES du projet)."""
    if not os.path.isdir(app):
        return
    design = DESIGNS[CHOSEN]
    alternates = os.path.join(app, "AppIcons")
    if os.path.isdir(alternates):
        shutil.rmtree(alternates)
    for slug, (_, _, pal) in final_sets().items():
        name = "AppIcon" if slug == MAIN_ICON else f"AppIcon-{slug}"
        write_icon_bundle(os.path.join(app if slug == MAIN_ICON else alternates, f"{name}.icon"), design, pal)


def render_sheet(out, renders):
    """planche-icones.png : les rendus d'ictool, une colonne par teinte."""
    from PIL import Image, ImageDraw, ImageFont
    slugs = list(final_sets())
    cell, pad = 256, 32
    rows = list(RENDITIONS)
    sheet = Image.new("RGB", (pad + len(slugs) * (cell + pad), pad + len(rows) * (cell + pad) + 40), "#FFFFFF")
    font = ImageFont.load_default(size=18)
    draw = ImageDraw.Draw(sheet)
    for col, slug in enumerate(slugs):
        x = pad + col * (cell + pad)
        draw.text((x + cell / 2, pad / 2 + 4), slug, fill="#444441", font=font, anchor="mm")
        for row, suffix in enumerate(rows):
            img = Image.open(os.path.join(renders, f"{slug}-{suffix}.png")).convert("RGBA").resize((cell, cell))
            sheet.paste(img, (x, pad + 40 + row * (cell + pad)), img)
    sheet.save(os.path.join(out, "planche-icones.png"))


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    write(out, DESIGNS)
    sheet(out, DESIGNS, list(DESIGNS)[:8], "planche.svg")
    for filename, names in SHEETS.items():
        sheet(out, DESIGNS, names, filename)
    for filename, palettes in PALETTE_SHEETS.items():
        palette_sheet(out, DESIGNS[CHOSEN], palettes, filename)
    for filename, rows in GRIDS.items():
        grid(out, DESIGNS[CHOSEN], HUES_GOLD, rows, filename)
    write_final(out)
    position_sheet(out, "planche-position.svg", HUES_GOLD["Gueules"])
    examples = layered_examples()
    layered_sheet(out, examples, HUES_GOLD["Gueules"], "planche-couches.svg")
    write_layered(out, examples, HUES_GOLD["Gueules"])
    write_icons(out)
    install_icons()
