"""Sovalye E "Koruma Bariyeri" - dostun etrafindaki BARIYERIN KENDISI icin yeni gorunus PROTOTIPLERI (oyuna bagli DEGIL).
Diger E efektleri (Sovalye'nin ustundeki emilim, Yanki Darbesi, kast) degismez.

Bugunku hali (fx_paladin_barrier_link.gd + tools/gen_sovalye_fx.py guard_bubble): 80x80, TEXEL 1.212 yerel birim (= 0,606 dunya,
karakter pikselinin 2/3'u), ic bantta dama dither + 1 px kenar + iki egik yorungede donen serit.

Yeni secenekler (hepsi KARAKTER PIKSELINDE: 1 sanat px = 0,903 dunya = kuklada 1,806 yerel; dither YOK, alfa basamaklari
1 / 0,8 / 0,55 / 0,3; mor-mavi palet Sovalye'nin emilim efektiyle ayni; arka katman karakterin arkasinda, on katman onunde):
  A Donen Kalkanlar : bel hizasinda egik yorungede donen 3 kucuk haclı kalkan (yandan bakinca incelir), ayakta soluk halka.
  B Isik Sutunlari  : ayak cevresindeki elipste donen 4 dikey isik sutunu (basamakli solma), zeminde halka.
  C Kutsal Muhur    : ayak altinda donen muhur (dis halka + 4 hac + ters donen kesikli ic halka) + muhurden yukselen zerreler.
  D Kristal Kabuk   : karakteri saran, yavasca donen koseli (yuzeyli) kristal kure tel kafesi + sabit parlak yay.
Her secenek: "in" (6 kare) + "loop" (18 kare, 12 fps, simetriyle dikissiz) + "out" (5 kare).

Calistir: python -I tools/proto_20261111/sovalye_bariyer/bariyer_proto.py  -> out/sheets/<v>_back.png, <v>_front.png, meta.json
          (+ out/sheets/onizleme.png: her secenekten 3 kare, 4x)
"""
import json
import math
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "out" / "sheets"

W = H = 64
OX, OY = 32, 32          # govde ortasi (kuklada CENTER (0,0))
FEET_Y = 50              # ayak: +33 yerel / 1,806 = +18 px
FPS = 12
N_IN, N_LOOP, N_OUT = 6, 18, 5

B_DEEP = (44, 40, 128)
B_INDIGO = (78, 82, 214)
B_BLUE = (112, 142, 255)
B_LAV = (170, 140, 255)
B_PALE = (206, 216, 255)
B_WHITE = (242, 244, 255)

LEVELS = (1.0, 0.8, 0.55, 0.3)


def q_alpha(a):
    for lv in LEVELS:
        if a >= lv - 0.12:
            return lv
    return 0.0


def put(img, x, y, col, a=1.0, over=False):
    """Tam sayi hucreye boya. over=False: daha opak olan kalir."""
    x, y = int(round(x)), int(round(y))
    if not (0 <= x < img.width and 0 <= y < img.height):
        return
    a = q_alpha(a)
    if a <= 0:
        return
    if not over and img.getpixel((x, y))[3] >= int(255 * a):
        return
    img.putpixel((x, y), col + (int(255 * a),))


def line(img, x0, y0, x1, y1, col, a, over=False):
    x0, y0, x1, y1 = int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1))
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    while True:
        put(img, x0, y0, col, a, over)
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


def ellipse_cells(cx, cy, rx, ry):
    """Midpoint elips: temiz 1 px 8 komsulu kenar. [(x, y, aci)] - aci: 0 = sag, +pi/2 = asagi (izleyiciye yakin)."""
    pts = set()
    x, y = 0, ry
    rx2, ry2 = rx * rx, ry * ry
    px, py = 0, 2 * rx2 * y
    p = ry2 - rx2 * ry + 0.25 * rx2
    while px < py:
        pts.update({(x, y), (-x, y), (x, -y), (-x, -y)})
        x += 1
        px += 2 * ry2
        if p < 0:
            p += ry2 + px
        else:
            y -= 1
            py -= 2 * rx2
            p += ry2 + px - py
    p = ry2 * (x + 0.5) ** 2 + rx2 * (y - 1) ** 2 - rx2 * ry2
    while y >= 0:
        pts.update({(x, y), (-x, y), (x, -y), (-x, -y)})
        y -= 1
        py -= 2 * rx2
        if p > 0:
            p += rx2 - py
        else:
            x += 1
            px += 2 * ry2
            p += rx2 - py + px
    return [(cx + a, cy + b, math.atan2(b / max(ry, 1), a / max(rx, 1))) for a, b in pts]


def blank():
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))


def ease_out(t):
    return 1 - (1 - t) ** 3


def phases():
    """(kare turu, ilerleme 0..1, dongu acisi kesri 0..1) dizisi: in + loop + out."""
    seq = []
    for i in range(N_IN):
        seq.append(("in", (i + 1) / N_IN, i / N_LOOP - N_IN / N_LOOP))
    for i in range(N_LOOP):
        seq.append(("loop", 1.0, i / N_LOOP))
    for i in range(N_OUT):
        seq.append(("out", (i + 1) / (N_OUT + 1), i / N_LOOP))
    return seq


# ------------------------------------------------------------------ A - Donen Kalkanlar
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
SHIELD_BACK = {"o": B_DEEP, "H": B_INDIGO, "W": B_INDIGO, "L": B_INDIGO}
SHIELD_FRONT = {"o": B_DEEP, "H": B_LAV, "W": B_WHITE, "L": B_BLUE}


def stamp_shield(img, cx, cy, facing, front, alpha):
    sw = len(SHIELD[0])
    w = max(3, int(round(sw * (0.35 + 0.65 * facing))))
    pal = SHIELD_FRONT if front else SHIELD_BACK
    x0 = int(round(cx - w / 2))
    y0 = int(round(cy - len(SHIELD) / 2))
    for r, row in enumerate(SHIELD):
        for i in range(w):
            ch = row[min(sw - 1, int((i + 0.5) * sw / w))]
            if ch == ".":
                continue
            col = pal[ch]
            if w <= 4 and ch != "o":
                col = pal["L"] if front else B_INDIGO
            put(img, x0 + i, y0 + r, col, alpha, over=True)


def draw_a(kind, k, turn):
    back, front = blank(), blank()
    rx, ry, cy = 22, 7, OY + 3
    if kind == "in":
        rad, a_mul, spin = 0.25 + 0.75 * ease_out(k), (0.3 if k < 0.4 else 0.55 if k < 0.75 else 1.0), (1 - k) * 0.6
    elif kind == "out":
        rad, a_mul, spin = 1.0 + 0.35 * k, (0.8 if k < 0.35 else 0.55 if k < 0.7 else 0.3), 0.0
    else:
        rad, a_mul, spin = 1.0, 1.0, 0.0
    base = 2 * math.pi * (turn / 3.0) + spin * 2 * math.pi
    # zeminde soluk halka (dostun korundugu alan)
    ring_a = 0.55 * (1.0 if kind == "loop" else a_mul)
    for x, y, _ in ellipse_cells(OX, FEET_Y, 16, 5):
        put(back, x, y, B_LAV, ring_a)
    # her kalkanin arkasinda yorunge boyunca kisa soluk iz (donus okunsun)
    for s in range(3):
        for j in range(1, 7):
            phi = base + s * 2 * math.pi / 3 - j * 0.07
            x = OX + rx * rad * math.cos(phi)
            y = cy + ry * rad * math.sin(phi)
            put(front if math.sin(phi) > 0 else back, x, y + 2, B_PALE if j < 3 else B_LAV, 0.55 * a_mul if j < 4 else 0.3 * a_mul)
    order = []
    for s in range(3):
        phi = base + s * 2 * math.pi / 3
        order.append((math.sin(phi), phi))
    for z, phi in sorted(order):
        x = OX + rx * rad * math.cos(phi)
        y = cy + ry * rad * math.sin(phi)
        facing = abs(math.sin(phi))
        is_front = z > 0
        stamp_shield(front if is_front else back, x, y, facing, is_front, (1.0 if is_front else 0.8) * a_mul)
    return back, front


# ------------------------------------------------------------------ B - Isik Sutunlari
PILLAR_H = 30
PILLAR_BANDS = [(6, 1.0, B_WHITE, B_PALE), (10, 0.8, B_PALE, B_LAV), (8, 0.55, B_LAV, B_BLUE), (6, 0.3, B_BLUE, B_INDIGO)]


def draw_pillar(img, x, y_base, height, front, a_mul):
    y = y_base
    left = int(round(x))
    drawn = 0
    for n, a, core, side in PILLAR_BANDS:
        for _ in range(n):
            if drawn >= height:
                return
            aa = a * a_mul * (0.8 if front else 0.55)
            put(img, left, y, core if front else side, aa, over=True)
            put(img, left + 1, y, side if front else B_INDIGO, aa * 0.8, over=True)
            y -= 1
            drawn += 1


def draw_b(kind, k, turn):
    back, front = blank(), blank()
    rx, ry = 19, 6
    if kind == "in":
        h_mul, a_mul = ease_out(k), 1.0
    elif kind == "out":
        h_mul, a_mul = 1.0 - k, (0.8 if k < 0.5 else 0.55)
    else:
        h_mul, a_mul = 1.0, 1.0
    # zemin halkasi: koyu dis hat + acik halka (cimenin ustunde okunsun)
    for x, y, _ in ellipse_cells(OX, FEET_Y, rx + 1, ry + 1):
        put(back, x, y, B_DEEP, 0.3 * a_mul)
    for x, y, _ in ellipse_cells(OX, FEET_Y, rx, ry):
        put(back, x, y, B_BLUE, 0.8 * a_mul, over=True)
    base = 2 * math.pi * (turn / 4.0)
    for s in range(4):
        phi = base + s * math.pi / 2
        x = OX + rx * math.cos(phi) - 0.5
        yb = FEET_Y + ry * math.sin(phi)
        is_front = math.sin(phi) > 0.05
        # ayak dibinde parlak taban noktasi
        put(front if is_front else back, x, yb, B_WHITE, a_mul, over=True)
        draw_pillar(front if is_front else back, x, yb - 1, int(round(PILLAR_H * h_mul)), is_front, a_mul)
    return back, front


# ------------------------------------------------------------------ C - Kutsal Muhur
N_MOTES = 6
MOTE_RISE = 26


def plus(img, x, y, col_c, col_arm, a):
    x, y = int(round(x)), int(round(y))
    put(img, x, y, col_c, a, over=True)
    for ox, oy in ((1, 0), (-1, 0), (0, -1), (0, 1)):
        put(img, x + ox, y + oy, col_arm, a * 0.8, over=True)


def draw_c(kind, k, turn):
    back, front = blank(), blank()
    rx, ry = 20, 7
    if kind == "in":
        s_mul, a_mul = 0.4 + 0.6 * ease_out(k), (0.55 if k < 0.5 else 1.0)
    elif kind == "out":
        s_mul, a_mul = 1.0, (0.8 if k < 0.35 else 0.55 if k < 0.7 else 0.3)
    else:
        s_mul, a_mul = 1.0, 1.0
    orx, ory = int(round(rx * s_mul)), max(2, int(round(ry * s_mul)))
    irx, iry = int(round(14 * s_mul)), max(1, int(round(5 * s_mul)))
    rot = 2 * math.pi * (turn / 4.0)
    # dis halka: koyu alt hat + acik halka
    for x, y, _ in ellipse_cells(OX, FEET_Y + 1, orx, ory):
        put(back, x, y, B_DEEP, 0.3 * a_mul)
    for x, y, _ in ellipse_cells(OX, FEET_Y, orx, ory):
        put(back, x, y, B_LAV, 0.8 * a_mul, over=True)
    # ic halka: ters donen kesikli (8 kesik)
    for x, y, ang in ellipse_cells(OX, FEET_Y, irx, iry):
        u = ((ang + rot * 1.5) / (2 * math.pi) * 8) % 1.0
        if u < 0.55:
            put(back, x, y, B_BLUE, 0.55 * a_mul)
    # 4 hac (dis halkada, muhurle doner)
    for s in range(4):
        phi = rot + s * math.pi / 2
        plus(back, OX + orx * math.cos(phi), FEET_Y + ory * math.sin(phi), B_WHITE, B_PALE, a_mul)
    # yukselen zerreler (sadece dongude + giriste/cikista soluk)
    for m in range(N_MOTES):
        life = (turn + m / N_MOTES) % 1.0
        ang = rot + m * 2 * math.pi / N_MOTES + math.pi / N_MOTES
        x = OX + (orx - 2) * math.cos(ang)
        y = FEET_Y + (ory - 1) * math.sin(ang) - MOTE_RISE * life
        a = (1.0 if life < 0.35 else 0.8 if life < 0.6 else 0.55 if life < 0.8 else 0.3) * a_mul
        if kind == "in":
            a *= k
        img = front if math.sin(ang) > 0 else back
        put(img, x, y, B_PALE if life < 0.6 else B_LAV, a, over=True)
        put(img, x, y + 1, B_LAV, a * 0.55, over=True)
    return back, front


# ------------------------------------------------------------------ D - Kristal Kabuk
TILT = math.radians(22)
LATS = [math.radians(v) for v in (-48, -12, 24, 58)]
N_LON = 6
BODY_HALF_W = 9   ## on yuz cizgileri govdenin ustune binmesin (karakter ~14 px genis)


def sphere_pt(lat, lon, rx, ry, cx, cy):
    x = math.cos(lat) * math.sin(lon)
    y = -math.sin(lat)
    z = math.cos(lat) * math.cos(lon)
    # x ekseni etrafinda egim: ust kutup izleyiciye biraz donsun (yukaridan bakis)
    y2 = y * math.cos(TILT) - z * math.sin(TILT)
    z2 = y * math.sin(TILT) + z * math.cos(TILT)
    return cx + rx * x, cy + ry * y2, z2


def draw_d(kind, k, turn):
    back, front = blank(), blank()
    if kind == "in":
        s_mul, a_mul = 0.55 + 0.45 * ease_out(k), (0.55 if k < 0.5 else 1.0)
    elif kind == "out":
        s_mul, a_mul = 1.0 + 0.12 * k, (0.8 if k < 0.35 else 0.55 if k < 0.7 else 0.3)
    else:
        s_mul, a_mul = 1.0, 1.0
    rx, ry = 22 * s_mul, 23 * s_mul
    cx, cy = OX, OY + 1
    rot = 2 * math.pi * (turn / N_LON)
    lons = [rot + i * 2 * math.pi / N_LON for i in range(N_LON)]
    grid = [[sphere_pt(la, lo, rx, ry, cx, cy) for lo in lons] for la in LATS]
    top = sphere_pt(math.pi / 2, 0, rx, ry, cx, cy)
    bot = sphere_pt(-math.pi / 2, 0, rx, ry, cx, cy)
    segs = []
    for r, row in enumerate(grid):
        for i in range(N_LON):
            segs.append((row[i], row[(i + 1) % N_LON]))
            if r + 1 < len(grid):
                segs.append((row[i], grid[r + 1][(i + (r % 2)) % N_LON]))   # zikzak: kosegen yuzeyler (ucgen hissi)
                segs.append((row[i], grid[r + 1][i]))
    for i in range(N_LON):
        segs.append((bot, grid[0][i]))
        segs.append((grid[-1][i], top))
    # once arka, sonra on: arka kenarlar soluk indigo (karakterin arkasinda), on kenarlar acik ama saydam (yuzu kapatmasin)
    for p, q in segs:
        z = (p[2] + q[2]) * 0.5
        if z <= 0:
            line(back, p[0], p[1], q[0], q[1], B_INDIGO, 0.55 * a_mul)
    for p, q in segs:
        z = (p[2] + q[2]) * 0.5
        if z > 0 and abs((p[0] + q[0]) * 0.5 - OX) > BODY_HALF_W:
            line(front, p[0], p[1], q[0], q[1], B_PALE if z > 0.55 else B_LAV, 0.55 * a_mul)
        elif z > 0:
            line(back, p[0], p[1], q[0], q[1], B_LAV, 0.3 * a_mul)
    # on yuzdeki koseler: kucuk parilti
    for row in grid:
        for p in row:
            if p[2] > 0.45 and abs(p[0] - OX) > BODY_HALF_W:
                put(front, p[0], p[1], B_WHITE, 0.8 * a_mul, over=True)
    # siluet kenari + sol ust sabit parlak yay (kure hissi)
    for x, y, ang in ellipse_cells(int(round(cx)), int(round(cy)), int(round(rx)), int(round(ry))):
        put(front, x, y, B_BLUE, 0.55 * a_mul)
        deg = math.degrees(ang) % 360
        if 200 <= deg <= 250:
            put(front, x, y, B_WHITE, 1.0 * a_mul, over=True)
        elif 185 <= deg <= 265:
            put(front, x, y, B_PALE, 0.8 * a_mul, over=True)
    return back, front


VARIANTS = {"a": draw_a, "b": draw_b, "c": draw_c, "d": draw_d}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    meta = {}
    seq = phases()
    for v, fn in VARIANTS.items():
        backs, fronts = [], []
        for kind, k, turn in seq:
            b, f = fn(kind, k, turn % 1.0)
            backs.append(b)
            fronts.append(f)
        for name, frames in (("back", backs), ("front", fronts)):
            s = Image.new("RGBA", (W * len(frames), H), (0, 0, 0, 0))
            for i, fr in enumerate(frames):
                s.paste(fr, (i * W, 0))
            s.save(OUT / f"{v}_{name}.png")
        meta[v] = {"w": W, "h": H, "ox": OX, "oy": OY, "in": N_IN, "loop": N_LOOP, "out": N_OUT, "fps": FPS}
    (OUT / "meta.json").write_text(json.dumps(meta, indent=1), encoding="utf-8")
    # onizleme: secenek basina in son karesi + 2 dongu karesi + 1 cikis karesi (arka + on ust uste, koyu cimen zemin), 4x
    picks = [N_IN - 1, N_IN + 4, N_IN + 11, N_IN + N_LOOP + 2]
    sc = 4
    prev = Image.new("RGBA", (len(picks) * W * sc, len(VARIANTS) * H * sc), (96, 140, 66, 255))
    for r, v in enumerate(VARIANTS):
        bs = Image.open(OUT / f"{v}_back.png")
        fs = Image.open(OUT / f"{v}_front.png")
        for c, fi in enumerate(picks):
            tile = Image.new("RGBA", (W, H), (96, 140, 66, 255))
            # karakter yeri (gri govde kutusu) - katman sirasini gormek icin
            body = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            for yy in range(OY - 20, FEET_Y):
                for xx in range(OX - 6, OX + 6):
                    body.putpixel((xx, yy), (60, 54, 70, 255))
            tile.alpha_composite(bs.crop((fi * W, 0, fi * W + W, H)))
            tile.alpha_composite(body)
            tile.alpha_composite(fs.crop((fi * W, 0, fi * W + W, H)))
            prev.paste(tile.resize((W * sc, H * sc), Image.NEAREST), (c * W * sc, r * H * sc))
    prev.save(OUT / "onizleme.png")
    print("tamam", OUT)


if __name__ == "__main__":
    main()
