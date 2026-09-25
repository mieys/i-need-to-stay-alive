"""Sovalye Adam Q (Kiskirtma) + E (Koruma Bariyeri) pixel-art sprite sayfalari -> assets/fx/sovalye/

Kullanici istegi (2026-09-25): "sovalye adamin Q su R olacak, E si yeni Q, R si de E olacak. E ve Q icin sifirdan ozel
efekt tasarla. E acikken arkadaslarinin etrafinda 2 cizginin donerek koruma baloncugu gibi gorunmesini saglayan daha iyi
bir versiyon, mor-mavi tonlarda; bu efekt acikken sovalye adamda da hasari ustune cekiyormus gibi gorunen bir efekt.
Q icin tum yaratiklarin dikkatini ustune cekiyormus gibi gorunen acik kirmizi bir efekt + yaratiklarin ustunde kiskirtma
durum efekti. Hepsini spritesheete donustur."

Uretilenler (hepsi 1 sanat pikseli = TEXEL 1.212 yerel birim, projedeki FX dili; kareler PNG + SpriteFrames .tres):
  taunt_burst   (176x120, 14 kare, 20 fps, tek sefer): disa yayilan acik kirmizi "savas cigligi" halkalari + her yonden
                Sovalye'ye dogru ICERI kosan oklar (dikkat ona cekiliyor) + basinin ustunde "!" parlamasi.
  taunt_aura    (110x60, 12 kare, 12 fps, dongu): kiskirtma suresince ayak altinda nabiz atan elips + iceri suzulen oklar.
  taunt_status  (16x16, 6 kare, 8 fps, dongu): yaratigin basinin ustunde nabiz atan ofke damari isareti.
  guard_bubble  (80x80, 24 kare, 10 fps, dongu; back + front iki sayfa): dostun etrafinda iki egik yorungede donen
                mor-mavi serit + soluk baloncuk kenari; yorungenin arka yarisi karakterin ARKASINDA, on yarisi ONUNDE cizilir.
  guard_absorb  (100x100, 24 kare, 12 fps, dongu): Sovalye'ye her yonden spiral cizerek akip gogsunde emilen mor-mavi
                zerreler + ayak altinda iceri daralan halka (hasari ustune cekme).

Calistir: python tools/gen_sovalye_fx.py   (sonra Godot editoru import eder; yepyeni sayfalar icin 2 import gerekebilir)
"""

import math
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fx", "sovalye")
RES = "res://assets/fx/sovalye/"

# --- acik kirmizi (Q) ---
R_DEEP = (150, 34, 52)
R_MID = (240, 84, 96)
R_LIGHT = (255, 150, 150)
R_PALE = (255, 212, 206)
R_WHITE = (255, 244, 238)
R_OUT = (70, 14, 28)

# --- mor-mavi (E) ---
B_DEEP = (44, 40, 128)
B_INDIGO = (78, 82, 214)
B_BLUE = (112, 142, 255)
B_LAV = (170, 140, 255)
B_PALE = (206, 216, 255)
B_WHITE = (242, 244, 255)


def ramp(cols, t):
    t = max(0.0, min(1.0, t))
    n = len(cols) - 1
    i = min(n - 1, int(t * n))
    f = t * n - i
    a, b = cols[i], cols[i + 1]
    return tuple(int(round(a[k] + (b[k] - a[k]) * f)) for k in range(3))


def q_alpha(a):
    """Az sayida alfa seviyesi (pixel dili): 0 / .3 / .55 / .8 / 1."""
    for lv in (1.0, 0.8, 0.55, 0.3):
        if a >= lv - 0.12:
            return lv
    return 0.0


def plot(img, x, y, col, a=1.0, keep_brighter=True):
    x, y = int(round(x)), int(round(y))
    if not (0 <= x < img.width and 0 <= y < img.height):
        return
    a = q_alpha(a)
    if a <= 0:
        return
    if keep_brighter:
        old = img.getpixel((x, y))
        if old[3] > int(255 * a):
            return
    img.putpixel((x, y), col + (int(255 * a),))


def ellipse_pts(cx, cy, rx, ry, step_deg=None):
    circ = 2 * math.pi * max(rx, ry)
    n = max(24, int(circ * 1.4)) if step_deg is None else int(360 / step_deg)
    for i in range(n):
        a = 2 * math.pi * i / n
        yield a, cx + rx * math.cos(a), cy + ry * math.sin(a)


def chevron(img, cx, cy, ang, size, col, a, out=None, hi=None):
    """(cx, cy) ucunda, ang yonunu gosteren 2 piksel kalin 'V' ok ucu (ang = okun gosterdigi yon, radyan)."""
    dx, dy = math.cos(ang), math.sin(ang)
    px, py = -dy, dx
    pts = set()
    for k in range(size + 1):
        for thick in (0, 1):
            for side in (1, -1):
                x = cx - dx * (k + thick) + px * k * side
                y = cy - dy * (k + thick) + py * k * side
                pts.add((int(round(x)), int(round(y))))
    if out is not None:
        for (x, y) in pts:
            for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if (x + ox, y + oy) not in pts:
                    plot(img, x + ox, y + oy, out, a * 0.8)
    for (x, y) in pts:
        plot(img, x, y, col, a, keep_brighter=False)
    if hi is not None:
        plot(img, cx, cy, hi, a, keep_brighter=False)


def sheet(frames):
    w, h = frames[0].size
    s = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        s.paste(f, (i * w, 0))
    return s


def save(name, frames, anim, loop, fps):
    os.makedirs(OUT, exist_ok=True)
    s = sheet(frames)
    s.save(os.path.join(OUT, name + "_sheet.png"))
    w, h = frames[0].size
    write_sprite_frames(os.path.join(OUT, name + "_frames.tres"), RES + name + "_sheet.png", w, h,
                        [(anim, (0, 0), len(frames), loop, fps)])


def ease_out(t):
    return 1 - (1 - t) ** 3


# ====================================================================== Q - taunt_burst
EXCL = [
    ".ooo.",
    "oHLLo",
    "oLLLo",
    "oLLLo",
    "oLLLo",
    ".oLo.",
    ".oLo.",
    "..o..",
    ".....",
    ".ooo.",
    "oLLLo",
    "oLLLo",
    ".ooo.",
]


def taunt_burst():
    W, H = 176, 120
    gx, gy = 88, 80  # ayak alti (zemin) merkezi
    frames = []
    n = 14
    for f in range(n):
        t = f / (n - 1)
        img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        # 1) disa yayilan iki halka (savas cigligi)
        # ilk karelerde ayak altinda dither'li yari saydam dolgu (cigligin "patlama" ani)
        if t < 0.35:
            rr = 12 + 50 * ease_out(t / 0.35)
            for yy in range(int(gy - rr * 0.5), int(gy + rr * 0.5) + 1):
                for xx in range(int(gx - rr), int(gx + rr) + 1):
                    if ((xx - gx) / rr) ** 2 + ((yy - gy) / (rr * 0.5)) ** 2 <= 1 and (xx + yy) % 2 == 0:
                        plot(img, xx, yy, R_MID, 0.3 * (1 - t / 0.35))
        for delay, thick, base in ((0.0, 3, 1.0), (0.16, 2, 0.85)):
            tt = (t - delay) / (1 - delay)
            if tt <= 0 or tt >= 1:
                continue
            r = 10 + 74 * ease_out(tt)
            a = base * (1 - tt) ** 0.45
            for ang, x, y in ellipse_pts(gx, gy, r, r * 0.5):
                front = math.sin(ang) > 0
                aa = a if front else a * 0.7
                plot(img, x, y, R_WHITE if tt < 0.4 else R_PALE, aa, keep_brighter=False)
                plot(img, x, y + 1, R_LIGHT, aa)
                if thick > 2:
                    plot(img, x, y + 2, R_MID, aa * 0.8)
                    plot(img, x, y - 1, R_MID, aa * 0.55)
        # 2) her yonden Sovalye'ye dogru iceri kosan oklar (dikkat ona cekiliyor)
        k = 10
        for i in range(k):
            ang = 2 * math.pi * i / k + 0.3
            tt = (t - 0.12) / 0.8
            if tt <= 0 or tt >= 1:
                continue
            r = 82 - 64 * (tt ** 1.4)
            x = gx + r * math.cos(ang)
            y = gy + r * 0.5 * math.sin(ang)
            point_to = math.atan2((gy - y) * 2.0, gx - x)  # elipsi daire gibi dusun
            a = min(1.0, tt * 4) * (1 - max(0.0, (tt - 0.75) / 0.25))
            chevron(img, x, y, point_to, 3, R_LIGHT, a, R_OUT, R_WHITE)
        # 3) basinin ustunde "!" (ilk yarida belirip parlar)
        if t < 0.72:
            a = min(1.0, t * 6) * (1 - max(0.0, (t - 0.5) / 0.22))
            bob = -2 if f in (2, 3) else (-1 if f in (1, 4) else 0)
            ex, ey = gx - 2, 4 + bob
            for y, row in enumerate(EXCL):
                for x, ch in enumerate(row):
                    if ch == "o":
                        plot(img, ex + x, ey + y, R_OUT, a)
                    elif ch == "H":
                        plot(img, ex + x, ey + y, R_WHITE, a, keep_brighter=False)
                    elif ch == "L":
                        plot(img, ex + x, ey + y, R_PALE if f in (2, 3) else R_LIGHT, a, keep_brighter=False)
        # 4) ayak altinda ilk karelerde kisa bir parlama
        if t < 0.3:
            a = 1 - t / 0.3
            for ang, x, y in ellipse_pts(gx, gy, 14, 7):
                plot(img, x, y, R_PALE, a)
        frames.append(img)
    save("taunt_burst", frames, "burst", False, 20)


def taunt_aura():
    W, H = 110, 60
    gx, gy = 55, 30
    frames = []
    n = 12
    for f in range(n):
        t = f / n
        img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        pulse = 0.5 + 0.5 * math.cos(2 * math.pi * t)
        # dis elips (sabit, nabiz atan) + ic elips
        for ang, x, y in ellipse_pts(gx, gy, 46, 22):
            front = math.sin(ang) > 0
            if int(math.degrees(ang) + 360 * t / 4) % 24 < 16:  # kesik cizgi, yavasca doner: ritim hissi
                aa = (0.6 + 0.35 * pulse) * (1 if front else 0.65)
                plot(img, x, y, R_LIGHT if front else R_MID, aa)
                plot(img, x, y + 1, R_MID, aa * 0.7)
        for ang, x, y in ellipse_pts(gx, gy, 22, 11):
            plot(img, x, y, R_PALE, 0.3 + 0.3 * pulse)
        # iceri suzulen oklar (periyodik -> kusursuz dongu)
        k = 6
        for i in range(k):
            ang = 2 * math.pi * i / k + (0.5 if i % 2 else 0.0)
            p = (t + i * 0.37) % 1.0
            r = 50 - 26 * p
            x = gx + r * math.cos(ang)
            y = gy + r * 0.48 * math.sin(ang)
            point_to = math.atan2((gy - y) * 2.0, gx - x)
            a = min(1.0, p * 5) * min(1.0, (1 - p) * 4) * 0.9
            chevron(img, x, y, point_to, 2, R_LIGHT, a, R_OUT, R_WHITE)
        frames.append(img)
    save("taunt_aura", frames, "loop", True, 12)


# ====================================================================== taunt_status (ofke damari)
# Ofke damari isaretinin SOL UST ceyregi (7x7, merkez 15x15 izgarada (7,7)); diger 3 ceyrek aynalanir.
#  r govde, h parlama, . bos. Kontur otomatik; merkez satir/sutun (7) bos kalir -> parcalar arasinda arti bosluk.
VEIN_Q = [
    ".......",
    "....h..",
    "...rh..",
    "...rr..",
    ".hrrr..",
    "hrrr...",
    ".......",
]


def taunt_status():
    """Ofke damari (anime 'kizgin' isareti): merkeze kose veren 4 ayri kivrik parca, aralarinda arti bicimli bosluk.
    Nabiz: parlaklik artar + 1 piksel yukari ziplar."""
    n = 6
    bright = [0, 1, 2, 1, 0, 0]
    lift = [0, 1, 1, 0, 0, 0]
    frames = []
    for f in range(n):
        img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        cells = {}
        for y, row in enumerate(VEIN_Q):
            for x, ch in enumerate(row):
                if ch == ".":
                    continue
                for (mx, my) in ((x, y), (14 - x, y), (x, 14 - y), (14 - x, 14 - y)):
                    cells[(mx, my)] = ch
        body = [R_MID, R_LIGHT, R_LIGHT][bright[f]]
        hi = [R_LIGHT, R_PALE, R_WHITE][bright[f]]
        oy = 1 - lift[f]
        for (x, y) in cells:
            for ox, o2 in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if (x + ox, y + o2) not in cells:
                    plot(img, x + ox, y + o2 + oy, R_OUT, 1.0)
        for (x, y), ch in cells.items():
            plot(img, x, y + oy, hi if ch == "h" else body, 1.0, keep_brighter=False)
        frames.append(img)
    save("taunt_status", frames, "loop", True, 8)


# ====================================================================== E - guard_bubble (dost)
def guard_bubble():
    W = H = 80
    cx, cy = 40, 40
    R = 34
    n = 24
    backs, fronts = [], []
    orbits = [(math.radians(66), math.radians(24), 0.0), (math.radians(66), math.radians(-24), math.pi)]
    span = math.radians(150)
    for f in range(n):
        th = 2 * math.pi * f / n
        shimmer = 0.5 + 0.5 * math.cos(2 * math.pi * f / n * 2)
        back = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        front = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        # baloncuk: kenara dogru yogunlasan dither'li ic parilti bandi (arka katman) + 2 piksel kenar
        for yy in range(H):
            for xx in range(W):
                d = math.hypot(xx + 0.5 - cx, yy + 0.5 - cy)
                if R - 5 <= d < R - 1 and (xx + yy) % 2 == 0:
                    plot(back, xx, yy, B_LAV if d > R - 3 else B_INDIGO, 0.3)
        for ang, x, y in ellipse_pts(cx, cy, R, R):
            plot(back, x, y, B_BLUE, 0.55)
            plot(back, cx + (R - 1) * math.cos(ang), cy + (R - 1) * math.sin(ang), B_INDIGO, 0.3)
        # sol ust parlama yayi (onde) - baloncuk hissi
        for i in range(48):
            a = math.radians(196 + i * 1.4)
            plot(front, cx + (R - 3) * math.cos(a), cy + (R - 3) * math.sin(a), B_WHITE if 14 < i < 34 else B_PALE,
                 (0.8 if 14 < i < 34 else 0.55) * (0.75 + 0.25 * shimmer))
        # iki egik yorungede donen seritler (3 piksel kalin, bas tarafi parlak)
        for incl, tilt, ph in orbits:
            head = th + ph
            steps = 140
            for s in range(steps + 1):
                u = s / steps               # 0 kuyruk -> 1 bas
                phi = head - span * (1 - u)
                x3 = R * math.cos(phi)
                y3 = R * math.sin(phi) * math.cos(incl)
                z3 = R * math.sin(phi) * math.sin(incl)
                xs = x3 * math.cos(tilt) - y3 * math.sin(tilt)
                ys = x3 * math.sin(tilt) + y3 * math.cos(tilt)
                is_front = z3 > 0
                layer = front if is_front else back
                dep = 1.0 if is_front else 0.6
                core = ramp([B_INDIGO, B_BLUE, B_LAV, B_PALE, B_WHITE], u)
                a = (0.35 + 0.65 * u) * dep
                plot(layer, cx + xs, cy + ys, core, a, keep_brighter=False)
                if u > 0.25:
                    edge = ramp([B_DEEP, B_INDIGO, B_BLUE, B_LAV], u)
                    plot(layer, cx + xs * 0.95, cy + ys * 0.95, edge, a * 0.9)
                    plot(layer, cx + xs * 1.05, cy + ys * 1.05, edge, a * 0.7)
            # bas parlamasi (+ isareti)
            x3 = R * math.cos(head)
            y3 = R * math.sin(head) * math.cos(incl)
            z3 = R * math.sin(head) * math.sin(incl)
            hx = cx + x3 * math.cos(tilt) - y3 * math.sin(tilt)
            hy = cy + x3 * math.sin(tilt) + y3 * math.cos(tilt)
            layer = front if z3 > 0 else back
            for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1), (2, 0), (-2, 0), (0, 2), (0, -2)):
                plot(layer, hx + ox, hy + oy, B_PALE if abs(ox) + abs(oy) == 1 else B_LAV, 0.8 if z3 > 0 else 0.5)
            plot(layer, hx, hy, B_WHITE, 1.0 if z3 > 0 else 0.6, keep_brighter=False)
        backs.append(back)
        fronts.append(front)
    save("guard_bubble_back", backs, "loop", True, 10)
    save("guard_bubble_front", fronts, "loop", True, 10)


# ====================================================================== E - guard_absorb (Sovalye)
def guard_absorb():
    W = H = 100
    cx, cy = 50, 46      # gogus (kokun ~2 sanat pikseli ustu)
    gy = cy + 28         # ayak alti
    n = 24
    motes = 10
    frames = []
    for f in range(n):
        t = f / n
        img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        # ayak altinda iceri daralan halka (her dongude 2 kez)
        for rep in range(2):
            p = (t * 2 + rep * 0.5) % 1.0
            rx = 40 - 26 * p
            a = 0.8 * min(1.0, p * 4) * (1 - p)
            for ang, x, y in ellipse_pts(cx, gy, rx, rx * 0.36):
                front = math.sin(ang) > 0
                plot(img, x, y, B_BLUE if front else B_INDIGO, a * (1 if front else 0.6))
        # spiral cizerek gogse akan zerreler: parlak "+" bas + uzun, incelen iz
        for i in range(motes):
            a0 = 2 * math.pi * i / motes
            for trail in range(9):
                p = (t + i / motes - trail * 0.012) % 1.0
                r = 44 * (1 - p) ** 0.85 + 3
                ang = a0 + 2.4 * p
                x = cx + r * math.cos(ang)
                y = cy + r * 0.82 * math.sin(ang)
                fade = min(1.0, p * 6) * min(1.0, (1 - p) * 7)
                col = ramp([B_INDIGO, B_BLUE, B_LAV, B_WHITE], p)
                a = fade * (1.0 - trail * 0.09)
                plot(img, x, y, col, a)
                if trail == 0:
                    for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        plot(img, x + ox, y + oy, ramp([B_INDIGO, B_BLUE, B_LAV], p), a * 0.8)
                    plot(img, x, y, B_WHITE, a, keep_brighter=False)
        # gogusteki cekirdek: nabiz atan minik kalkan elmasi
        pulse = 0.5 + 0.5 * math.cos(2 * math.pi * t * 2)
        for dx, dy in ((0, -2), (-1, -1), (0, -1), (1, -1), (-2, 0), (-1, 0), (0, 0), (1, 0), (2, 0), (-1, 1), (0, 1), (1, 1), (0, 2)):
            edge = abs(dx) + abs(dy) == 2
            plot(img, cx + dx, cy + dy, B_LAV if edge else B_WHITE, (0.55 + 0.45 * pulse) * (0.8 if edge else 1.0), keep_brighter=False)
        for ang, x, y in ellipse_pts(cx, cy, 5 + 2 * pulse, 5 + 2 * pulse):
            plot(img, x, y, B_BLUE, 0.3 + 0.25 * pulse)
        frames.append(img)
    save("guard_absorb", frames, "loop", True, 12)


if __name__ == "__main__":
    taunt_burst()
    taunt_aura()
    taunt_status()
    guard_bubble()
    guard_absorb()
