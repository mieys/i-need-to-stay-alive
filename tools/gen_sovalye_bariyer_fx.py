"""Sovalye E "Koruma Bariyeri" - buflanan DOSTUN etrafindaki bariyer: "A5 - Isik Kuyrugu" (madde 581) -> assets/fx/sovalye/

Kullanici secimi (2026-11-11, madde 580 prototipleri): A5 + "izi biraz kis ve yerdeki isik golgelerini de kaldir".
Eski guard_bubble (iki egik serit + dither'li baloncuk, tools/gen_sovalye_fx.py) yerine AYNI dosya adlari:
  guard_bubble_back_sheet.png / guard_bubble_front_sheet.png (+ _frames.tres), kare 72x72, koken (36,36) = govde ortasi.
  "in"  : 8 kare, 20 fps, dongusuz - merkezde 4 kollu yildiz parlamasi + kalkanlar izleriyle sarmal acilir.
  "loop": 90 kare, 20 fps (4,5 sn = TAM TUR; uc kalkan birbirinden bagimsiz nefes alir/zerre doker), dikissiz.
  Kapanis sayfada YOK: fx_paladin_barrier_link.gd dismiss() kodda soldurur (aci bagimsiz).
Cizim: 1 sanat px = karakter pikseli (0,903 dunya; kuklada/oyuncuda kok 0,5 -> 1,806 yerel, fx_paladin_barrier_link.gd TEXEL),
dither YOK, alfa basamaklari 1 / 0,8 / 0,55 / 0,3. Bel hizasinda egik yorungede (rx 22, ry 7) donen 3 hacli kalkan (9x11; bakisa
gore daralir, kenardan isik cizgisi, arkaya donunce soluk hacli isik govde), 2-3 basamakli NEFES ALAN HALE, kalkanin arka kenarindan
baslayan kuyruklu yildiz izi (beyaz 3 px -> mor 1 px, 56 derece), izden dokulup suzulen pariltilar. Yorungenin arka yarisi "back"
(karakterin arkasinda), on yarisi "front" (onunde) sayfasinda. Prototip: tools/proto_20261111/sovalye_bariyer/kalkan_buyu_proto.py A5.

Calistir: python -I tools/gen_sovalye_bariyer_fx.py   (sonra Godot import: editor ya da --headless --import)
"""
import math
import os
import random
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fx", "sovalye")
RES = "res://assets/fx/sovalye/"

W = H = 72
OX, OY = 36, 36
ORBIT_CY = OY + 3
RX, RY = 22, 7
N_IN, N_LOOP, FPS = 8, 90, 20
TRAIL_DEG = 56

B_DEEP = (44, 40, 128)
B_INDIGO = (78, 82, 214)
B_BLUE = (112, 142, 255)
B_LAV = (170, 140, 255)
B_PALE = (206, 216, 255)
B_WHITE = (242, 244, 255)

SHIELD = [
    ".ooooooo.",
    "oHHHWLLLo",
    "oHHHWLLLo",
    "oWWWWWWWo",
    "oLLLWLLLo",
    "oLLLWLLLo",
    "oLLLWLLLo",
    ".oLLWLLo.",
    "..oLWLo..",
    "...oWo...",
    "....o....",
]
PAL_FRONT = {"o": B_DEEP, "H": B_LAV, "W": B_WHITE, "L": B_BLUE}
PAL_FRONT_LIT = {"o": B_INDIGO, "H": B_PALE, "W": B_WHITE, "L": B_LAV}
PAL_BACK = {"o": B_INDIGO, "H": B_BLUE, "W": B_LAV, "L": B_BLUE}
PAL_BACK_LIT = {"o": B_INDIGO, "H": B_LAV, "W": B_PALE, "L": B_LAV}
LEVELS = (1.0, 0.8, 0.55, 0.3)


def q_alpha(a):
    for lv in LEVELS:
        if a >= lv - 0.12:
            return lv
    return 0.0


def put(img, x, y, col, a, over=False):
    x, y = int(round(x)), int(round(y))
    if not (0 <= x < img.width and 0 <= y < img.height):
        return
    a = q_alpha(a)
    if a <= 0:
        return
    if not over and img.getpixel((x, y))[3] >= int(255 * a):
        return
    img.putpixel((x, y), col + (int(255 * a),))


def rnd(x):
    return int(math.floor(x + 0.5))


def ease_out(t):
    return 1 - (1 - t) ** 3


def shield_cells(phi, lit):
    front = math.sin(phi) > 0
    facing = abs(math.sin(phi))
    sw = len(SHIELD[0])
    w = max(3, rnd(sw * (0.35 + 0.65 * facing)))
    pal = (PAL_FRONT_LIT if lit else PAL_FRONT) if front else (PAL_BACK_LIT if lit else PAL_BACK)
    x0 = rnd(-w / 2)
    y0 = -len(SHIELD) // 2
    cells = {}
    for r, row in enumerate(SHIELD):
        for i in range(w):
            ch = row[min(sw - 1, int((i + 0.5) * sw / w))]
            if ch == ".":
                continue
            col = pal[ch]
            if w <= 4 and ch != "o":   # kenardan bakis: isik cizgisi
                col = (B_WHITE if i == w // 2 else B_PALE) if front else (B_LAV if i == w // 2 else B_BLUE)
            cells[(x0 + i, y0 + r)] = col
    return cells


def ring_of(cells, n_steps):
    taken = set(cells)
    rings = []
    cur = set(cells)
    for _ in range(n_steps):
        nxt = set()
        for (x, y) in cur:
            for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                k = (x + ox, y + oy)
                if k not in taken:
                    nxt.add(k)
        taken |= nxt
        rings.append(nxt)
        cur = nxt
    return rings


def draw_shield(img, cx, cy, phi, lit, halo_a, a_mul=1.0):
    ix, iy = rnd(cx), rnd(cy)
    cells = shield_cells(phi, lit)
    front = math.sin(phi) > 0
    r1, r2, r3 = ring_of(cells, 3)
    strong = halo_a >= 0.8
    if front:
        rings = [(r1, B_WHITE if lit else B_PALE, 0.8 if strong else 0.55), (r2, B_LAV, 0.55 if strong else 0.3)]
        if lit:
            rings.append((r3, B_LAV, 0.3))
    else:
        rings = [(r1, B_LAV, 0.55 if strong else 0.3)]
    for ring, col, a in reversed(rings):
        for (x, y) in ring:
            put(img, ix + x, iy + y, col, a * a_mul, over=True)
    for (x, y), col in cells.items():
        put(img, ix + x, iy + y, col, a_mul, over=True)


def star4(img, x, y, size, a):
    x, y = rnd(x), rnd(y)
    put(img, x, y, B_WHITE, a, over=True)
    for k in range(1, size + 1):
        col = B_PALE if k < size else B_LAV
        aa = a if k < size else a * 0.55
        for ox, oy in ((k, 0), (-k, 0), (0, k), (0, -k)):
            put(img, x + ox, y + oy, col, aa, over=True)


def shield_phi(s, t, spin=0.0):
    return 2 * math.pi * t + s * 2 * math.pi / 3 + spin


def orbit_pt(phi, rad=1.0):
    return OX + RX * rad * math.cos(phi), ORBIT_CY + RY * rad * math.sin(phi)


def layer_for(back, front, phi):
    return front if math.sin(phi) > 0 else back


def comet_trail(back, front, phi, rad, length_deg, a_mul):
    step = math.radians(2.0)
    n = int(length_deg / 2.0)
    w_half = (4.5 * (0.35 + 0.65 * abs(math.sin(phi))) + 1.5) / max(4.0, RX * rad * abs(math.sin(phi)) + RY * rad * abs(math.cos(phi)))
    for j in range(0, n):
        u = j / n
        p = phi - w_half - j * step
        x, y = orbit_pt(p, rad)
        thick = 3 if u < 0.5 else 2 if u < 0.8 else 1
        if u < 0.2:
            col, side, a = B_WHITE, B_PALE, 1.0
        elif u < 0.45:
            col, side, a = B_PALE, B_LAV, 0.8
        elif u < 0.75:
            col, side, a = B_LAV, B_BLUE, 0.55
        else:
            col, side, a = B_BLUE, B_BLUE, 0.3
        img = layer_for(back, front, p)
        xi, yi = rnd(x), rnd(y)
        put(img, xi, yi, col, a * a_mul, over=True)
        if thick >= 2:
            put(img, xi, yi + 1, side, max(0.3, a - 0.25) * a_mul)
        if thick >= 3:
            put(img, xi, yi - 1, side, max(0.3, a - 0.25) * a_mul)


class Mote:
    def __init__(self, s, tb, life, rng):
        self.s, self.tb, self.life = s, tb, life
        self.dx = rng.uniform(-3.5, 3.5)
        self.dy = rng.uniform(-4, 4)
        self.drift = rng.uniform(-2, 2)
        self.kind = rng.random()


def make_motes(per_shield, life, seed):
    rng = random.Random(seed)
    out = []
    for s in range(3):
        for e in range(per_shield):
            out.append(Mote(s, (e + rng.uniform(0, 0.6)) / per_shield, life, rng))
    return out


MOTES = make_motes(9, 0.11, 5)


def breath(s, t, cycles=3):
    return 0.5 + 0.5 * math.sin(2 * math.pi * cycles * t + s * 2.1)


def draw(back, front, t, rad, a_mul, spin):
    intro = spin != 0.0
    for s in range(3):
        comet_trail(back, front, shield_phi(s, t, spin), rad, TRAIL_DEG, a_mul)
    if not intro:
        for m in MOTES:
            a = (t - m.tb) % 1.0
            if a >= m.life:
                continue
            age = a / m.life
            phi_b = shield_phi(m.s, m.tb)
            x, y = orbit_pt(phi_b, rad)
            x += m.dx * 0.4 + m.drift * age
            y += m.dy * 0.4 + 9 * age
            img = layer_for(back, front, phi_b)
            if age < 0.3:
                star4(img, x, y, 1, 0.8 * a_mul)
            elif age < 0.65:
                put(img, rnd(x), rnd(y), B_PALE, 0.8 * a_mul, over=True)
            else:
                put(img, rnd(x), rnd(y), B_LAV, 0.55 * a_mul, over=True)
    for s in sorted(range(3), key=lambda k: math.sin(shield_phi(k, t, spin))):
        phi = shield_phi(s, t, spin)
        x, y = orbit_pt(phi, rad)
        b = breath(s, t)
        draw_shield(layer_for(back, front, phi), x, y + round(math.sin(2 * math.pi * 2 * t + s * 2.1)), phi,
                    b > 0.7, 0.8 if b > 0.5 else 0.55, a_mul)


def frame(kind, i):
    back = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    front = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    if kind == "in":
        e = ease_out((i + 1) / N_IN)
        if i < 5:
            star4(front, OX, OY - 2, [2, 4, 5, 4, 2][i], [1.0, 1.0, 0.8, 0.55, 0.3][i])
        spin = -(1 - e) * math.pi * 1.1
        draw(back, front, (i - N_IN) / N_LOOP, 0.12 + 0.88 * e, 0.55 if i == 0 else 1.0, spin if spin != 0.0 else -1e-6)
    else:
        draw(back, front, i / N_LOOP, 1.0, 1.0, 0.0)
    return back, front


def save(name, frames):
    os.makedirs(OUT, exist_ok=True)
    s = Image.new("RGBA", (W * len(frames), H), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        s.paste(fr, (i * W, 0))
    s.save(os.path.join(OUT, name + "_sheet.png"))
    write_sprite_frames(os.path.join(OUT, name + "_frames.tres"), RES + name + "_sheet.png", W, H,
                        [("in", (0, 0), N_IN, False, FPS), ("loop", (N_IN, 0), N_LOOP, True, FPS)])


def main():
    backs, fronts = [], []
    for i in range(N_IN):
        b, f = frame("in", i)
        backs.append(b)
        fronts.append(f)
    for i in range(N_LOOP):
        b, f = frame("loop", i)
        backs.append(b)
        fronts.append(f)
    save("guard_bubble_back", backs)
    save("guard_bubble_front", fronts)
    print("guard_bubble_back/front:", len(backs), "kare", W, "x", H)


if __name__ == "__main__":
    main()
