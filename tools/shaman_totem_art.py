"""Shaman totemleri v3 - MISTIK (dogal/ruhani) pixel-art totemler.

Kullanici geri bildirimi (2026-09-24): "Shamanin totemlerini mistik totemlerle degistirmeni istiyorum suanki gorunumleri cok
teknolojik." - v2'deki faset kristal, yorungede donen parcalar, isiyan run halkali tas kaide, gezegen halkali bosluk kuresi ve dama
(dither) halolari "teknolojik" duruyordu. v3 tamamen el oymasi ahsap/kemik + boya + tuy + ruh isigi:
  * Kalkan (mavi): oyma BAYKUS ruhu - acik kanatlar, mavi boyali tuy uclari, kanat uclarindan sallanan boncuk+tuy muskalari,
    altta sakin koruyucu yuz; etrafinda suzulen mavi ruh isiklari.
  * Saldiri (kirmizi): koc KAFATASI + kivrik boynuzlar, goz cukurlarinda kor, tepesinde yanan ruh atesi (ates oku buradan cikar,
    bkz. totem_attack.gd BOLT_ORIGIN_OFFSET), deri kayislar, aşı boyasi pence cizgileri, disli oyma yuz.
  * Alan (mor): olu dal direk, tepede soluk oyma HILAL (ay), hilalin uclarindan asili RUH KAPANI (dus kapani) cemberi,
    sarkan tuylar, gozleri kapali dingin yuz, dibinde isiyan mor mantarlar ve ates bocekleri.
Zemin: ucunun de ayni toprak tumsegi + cakil (isiyan kaide/run halkasi YOK).

Kare boyutu 48x64 sanat pikseli (1 piksel = oyun texel'i 1.212) - ayak zemini kare tabaninda; 6 karelik sakin dongu.
Ikonlar (gen_shaman_assets.make_icons) 2. karenin ust 36x36'sini kullanir - tanitici kisimlar (bas/odak) ust bolgede.
"""
import math
import os

from PIL import Image, ImageDraw

W, H = 48, 64
FRAMES = 6
CX = 24
OUTLINE = (20, 12, 12, 255)


def rgba(r, g, b, a=255):
    return (int(r), int(g), int(b), int(a))


def mix(c1, c2, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(round(c1[i] + (c2[i] - c1[i]) * t)) for i in range(4))


def new_canvas():
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))


def outline(layer, col=OUTLINE):
    w, h = layer.size
    px = layer.load()
    out = layer.copy()
    op = out.load()
    for y in range(h):
        for x in range(w):
            if px[x, y][3] > 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] > 0:
                    op[x, y] = col
                    break
    return out


def put(im, pts, col):
    for (x, y) in pts:
        x, y = int(round(x)), int(round(y))
        if 0 <= x < im.size[0] and 0 <= y < im.size[1]:
            im.putpixel((x, y), col)


def put_alpha(im, x, y, col):
    """Yariseffaf piksel (ruh isigi): mevcut piksel opaksa uzerine karistirir, bossa alfa ile koyar."""
    x, y = int(round(x)), int(round(y))
    if not (0 <= x < im.size[0] and 0 <= y < im.size[1]):
        return
    cur = im.getpixel((x, y))
    if cur[3] == 0:
        im.putpixel((x, y), col)
    elif col[3] < 255:
        a = col[3] / 255.0
        im.putpixel((x, y), tuple(int(cur[i] * (1 - a) + col[i] * a) for i in range(3)) + (max(cur[3], col[3]),))
    else:
        im.putpixel((x, y), col)


def mirror(pts):
    """Direk ekseni x=24 etrafinda ayna (sol tarafta cizilen parcayi saga kopyalamak icin)."""
    return [(2 * CX - x, y) for (x, y) in pts]


# ------------------------------------------------------------------ paletler
WOOD = (rgba(44, 26, 20), rgba(84, 52, 32), rgba(124, 82, 48), rgba(164, 116, 68), rgba(196, 150, 96))
RWOOD = (rgba(46, 20, 18), rgba(88, 38, 28), rgba(128, 60, 38), rgba(166, 92, 56), rgba(196, 126, 80))
DEAD = (rgba(40, 30, 44), rgba(72, 58, 76), rgba(106, 90, 108), rgba(142, 126, 140), rgba(176, 162, 170))
BONE_D, BONE, BONE_L = rgba(150, 132, 106), rgba(218, 204, 170), rgba(244, 236, 212)
EARTH = (rgba(52, 36, 26), rgba(82, 58, 38), rgba(112, 82, 54))
PEBBLE = (rgba(78, 74, 80), rgba(116, 112, 118), rgba(152, 148, 150))
MOSS_D, MOSS, MOSS_L = rgba(46, 84, 42), rgba(78, 124, 56), rgba(122, 164, 76)
LEATHER_D, LEATHER = rgba(70, 40, 24), rgba(122, 76, 44)
FEATHER, FEATHER_D = rgba(236, 228, 208), rgba(176, 164, 146)

B0, B1, B2, B3, B4 = rgba(20, 44, 96), rgba(44, 98, 184), rgba(86, 156, 236), rgba(164, 214, 255), rgba(232, 246, 255)
F0, F1, F2, F3, F4 = rgba(92, 20, 12), rgba(184, 52, 22), rgba(238, 118, 36), rgba(252, 186, 70), rgba(255, 234, 170)
P0, P1, P2, P3, P4 = rgba(40, 18, 64), rgba(94, 50, 158), rgba(150, 92, 224), rgba(204, 160, 255), rgba(244, 230, 255)
OCHRE = rgba(182, 56, 36)
MOON = (rgba(70, 60, 98), rgba(118, 106, 150), rgba(170, 160, 204), rgba(212, 206, 236), rgba(244, 242, 255))


def cyl_col(pal, u):
    """Silindir golgesi (isik sol ustten): u=0 sol kenar .. 1 sag kenar."""
    if u < 0.12:
        return pal[3]
    if u < 0.5:
        return pal[2]
    if u < 0.82:
        return pal[1]
    return pal[0]


def pole(im, x0, x1, y0, y1, pal, wobble=None):
    """Oyma direk (x0..x1 dahil). wobble(y) -> x kaymasi (burulmus dal icin)."""
    for y in range(y0, y1 + 1):
        dx = wobble(y) if wobble else 0
        for x in range(x0, x1 + 1):
            put(im, [(x + dx, y)], cyl_col(pal, (x - x0) / max(1, x1 - x0)))
    # dikey damar (sabit tohumlu, kareler arasi titremesin)
    for (gx, gy, ln) in ((x0 + 3, y0 + 4, 3), (x1 - 3, y0 + 11, 4), (x0 + 5, y1 - 8, 3), (x1 - 2, y1 - 4, 2)):
        if x0 + 1 < gx < x1:
            dx = wobble(gy) if wobble else 0
            put(im, [(gx + dx, gy + k) for k in range(ln)], pal[1] if gx < (x0 + x1) / 2 else pal[0])


def carved_band(im, y, x0, x1, pal):
    """Oyma halka: ustte koyu yarik, altinda acik kenar."""
    put(im, [(x, y) for x in range(x0, x1 + 1)], pal[0])
    put(im, [(x, y + 1) for x in range(x0 + 1, x1)], pal[3])


def ground(im, kind, t):
    """Toprak tumsegi + cakillar + totem turune gore dokunus (yosun / kul-kor / mor mantar icin yer)."""
    d = ImageDraw.Draw(im)
    d.ellipse((9, 56, 38, 63), fill=EARTH[0])
    d.ellipse((10, 56, 37, 62), fill=EARTH[1])
    put(im, [(x, 56) for x in range(15, 30)] + [(x, 57) for x in range(12, 17)], EARTH[2])
    # cakillar
    for (sx, sy) in ((10, 60), (34, 61), (29, 62)):
        put(im, [(sx, sy), (sx + 1, sy), (sx + 2, sy)], PEBBLE[1])
        put(im, [(sx, sy - 1), (sx + 1, sy - 1)], PEBBLE[2])
        put(im, [(sx + 2, sy + 1) if sy < 62 else (sx + 2, sy)], PEBBLE[0])
    if kind == "moss":
        for (mx, my) in ((13, 57), (32, 57), (20, 61)):
            put(im, [(mx, my), (mx + 1, my), (mx + 2, my), (mx + 1, my - 1)], MOSS)
            put(im, [(mx + 1, my - 1)], MOSS_L)
        # cimen tutamlari (hafif sallanir)
        sway = 1 if math.sin(2 * math.pi * t) > 0.3 else 0
        for gx in (11, 36):
            put(im, [(gx, 57), (gx, 56), (gx + sway, 55)], MOSS)
            put(im, [(gx + 1, 57), (gx + 2, 56)], MOSS_D)
    elif kind == "ash":
        put(im, [(x, 57) for x in range(17, 24)] + [(x, 58) for x in range(25, 31)], rgba(66, 58, 58))
        put(im, [(19, 57), (27, 58)], rgba(104, 94, 90))


# ------------------------------------------------------------------ 1) KALKAN TOTEMI - baykus ruhu (mavi)
def _shield_wing(im, pal):
    """Sol kanat (sonra aynalanir): yukari kalkik uc, alt kenari 4 tuy tarakli."""
    d = ImageDraw.Draw(im)
    wing = [(19, 29), (14, 27), (9, 24), (4, 20), (2, 21), (3, 24), (5, 27), (7, 30), (10, 32), (13, 34), (16, 36), (19, 37)]
    for pts in (wing, mirror(wing)):
        d.polygon(pts, fill=pal[2])
    for side in (1, -1):
        def m(p):
            return p if side == 1 else (2 * CX - p[0], p[1])
        # ust kenar parlakligi
        put(im, [m(p) for p in ((18, 29), (17, 28), (16, 28), (15, 27), (14, 27), (13, 26), (12, 26), (11, 25), (10, 25),
                                (9, 24), (8, 23), (7, 22), (6, 22), (5, 21), (4, 21))], pal[4])
        put(im, [m(p) for p in ((17, 29), (15, 28), (13, 27), (11, 26), (9, 25), (7, 23), (5, 22))], pal[3])
        # tuy ayrim oymalari (koyu capraz cizgiler) - her tuy alt kenarda bir tarak ucu
        for (sx, sy, ln) in ((17, 31, 6), (14, 29, 5), (11, 27, 5), (8, 25, 4)):
            put(im, [m((sx - k * 0.35, sy + k)) for k in range(ln)], pal[1])
        # tuy uclari: mavi boya (alt kenar)
        tips = ((18, 36), (17, 36), (16, 35), (15, 35), (14, 34), (13, 33), (12, 33), (11, 32), (10, 31), (9, 31), (8, 30),
                (7, 29), (6, 28), (5, 27), (4, 25), (3, 24), (3, 23))
        put(im, [m(p) for p in tips], B1)
        put(im, [m(p) for p in ((17, 35), (14, 33), (11, 31), (8, 29), (5, 26))], B2)


def totem_shield(f):
    t = f / FRAMES
    glow = 0.5 + 0.5 * math.sin(2 * math.pi * t)
    im = new_canvas()
    ground(im, "moss", t)
    pole(im, 19, 29, 30, 58, WOOD)
    carved_band(im, 52, 19, 29, WOOD)
    # --- alt yuz: sakin koruyucu (direk uzerine oyma) ---
    put(im, [(x, 39) for x in range(20, 29)], WOOD[3])          # alin cikintisi
    put(im, [(x, 40) for x in (20, 21, 22, 23, 25, 26, 27, 28)], WOOD[0])  # kaslar
    eye = mix(B2, B4, glow)
    for ex in (21, 26):
        put(im, [(ex, 41), (ex + 1, 41), (ex, 42), (ex + 1, 42)], WOOD[0])
        put(im, [(ex + (1 if ex < 24 else 0), 41)], eye)
    put(im, [(24, y) for y in range(41, 46)], WOOD[3])           # burun sirti
    put(im, [(25, y) for y in range(42, 46)], WOOD[1])
    put(im, [(23, 46), (25, 46)], WOOD[0])
    put(im, [(x, 48) for x in range(21, 28)], WOOD[0])           # agiz
    put(im, [(x, 49) for x in range(22, 27)], WOOD[3])
    # mavi savas boyasi: goz altindan inen iki cizgi
    put(im, [(20, 43), (20, 44), (20, 45), (28, 43), (28, 44), (28, 45)], B1)
    put(im, [(20, 43), (28, 43)], B2)
    # alt govde: mavi boyali zikzak bant
    for i, x in enumerate(range(20, 29)):
        put(im, [(x, 55 + (i % 2))], B1)
    # --- gogus tuyleri (V oymalari) ---
    for y in (32, 35):
        put(im, [(21, y), (22, y + 1), (23, y + 2), (24, y + 2), (25, y + 2), (26, y + 1), (27, y)], WOOD[1])
    # --- kanatlar ---
    _shield_wing(im, WOOD)
    # --- baykus basi ---
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((16, 13, 32, 30), radius=5, fill=WOOD[2])
    d.polygon([(16, 17), (15, 9), (21, 14)], fill=WOOD[2])      # kulak tuyleri
    d.polygon([(32, 17), (33, 9), (27, 14)], fill=WOOD[2])
    put(im, [(16, 10), (16, 11), (17, 12), (16, 13), (17, 14)], WOOD[4])
    put(im, [(32, 11), (31, 12), (32, 13)], WOOD[1])
    put(im, [(x, 14) for x in range(21, 28)], WOOD[3])
    put(im, [(17, y) for y in range(16, 28)], WOOD[3])           # sol kenar isik
    put(im, [(31, y) for y in range(16, 28)], WOOD[1])           # sag kenar golge
    # yuz diski: iki buyuk halka goz
    for ex in (20, 28):
        d.ellipse((ex - 3, 16, ex + 3, 22), fill=WOOD[4])
        d.ellipse((ex - 2, 17, ex + 2, 21), fill=WOOD[0])
        iris = mix(B1, B3, glow)
        d.ellipse((ex - 1, 18, ex + 1, 20), fill=iris)
        put(im, [(ex, 19)], mix(B3, B4, glow))
        put(im, [(ex - 1, 18)], B4)
    # gaga (kemik)
    put(im, [(23, 22), (24, 22), (25, 22), (23, 23), (24, 23), (25, 23), (24, 24), (24, 25)], BONE)
    put(im, [(25, 23), (24, 25)], BONE_D)
    put(im, [(23, 22)], BONE_L)
    # alin boyasi (mavi V)
    put(im, [(21, 15), (22, 16), (23, 17), (24, 17), (25, 17), (26, 16), (27, 15)], B1)
    # yuz alt tuyleri
    put(im, [(20, 26), (21, 27), (27, 27), (28, 26), (24, 28)], WOOD[1])
    im = outline(im)
    # --- kanat uclarindan sallanan boncuk + tuy muskalari (ip kontursuz) ---
    for side, ph in ((1, 0.0), (-1, 0.5)):
        sw = math.sin(2 * math.pi * (t + ph))
        bx = 4 if side == 1 else 44
        tx = bx + (1 if sw > 0.35 else (-1 if sw < -0.35 else 0))
        put(im, [(bx, 26), (bx, 27), (bx, 28)], LEATHER_D)
        put(im, [(bx, 29)], B3)
        put(im, [(tx, 30), (tx, 31), (tx, 32), (tx, 33), (tx, 34)], FEATHER)
        put(im, [(tx - side, 31), (tx - side, 32), (tx - side, 33)], FEATHER_D)
        put(im, [(tx, 35)], B1)
        put(im, [(tx + side, 31), (tx + side, 32), (tx + side, 33)], OUTLINE)
    # --- suzulen mavi ruh isiklari (yumusak, dama yok) ---
    for k in range(3):
        ph = (t + k / 3.0) % 1.0
        x = CX + math.sin(ph * 2 * math.pi + k * 2.1) * (13 + k * 2)
        y = 46 - ph * 38
        a = int(230 * math.sin(ph * math.pi))
        put_alpha(im, x, y, (B3[0], B3[1], B3[2], a))
        put_alpha(im, x, y + 1, (B2[0], B2[1], B2[2], a // 2))
    return im


# ------------------------------------------------------------------ 2) SALDIRI TOTEMI - koc kafatasi + ruh atesi (kirmizi)
HORN_D, HORN, HORN_L = rgba(96, 72, 54), rgba(150, 118, 84), rgba(190, 160, 118)


def _ram_horn(im, side):
    """Koc boynuzu: kafatasinin ust kosesinden cikip disari-asagi kivrilan, incelen sarmal (halka cizgili)."""
    cx, cy = (12.5, 22.5) if side == 1 else (2 * CX - 12.5, 22.5)
    steps = 60
    pts = []
    for i in range(steps + 1):
        u = i / steps
        th = math.radians(-40 - 300 * u) if side == 1 else math.radians(-140 + 300 * u)
        r = 6.6 - 3.4 * u
        pts.append((cx + math.cos(th) * r, cy + math.sin(th) * r, 1.9 - 1.0 * u, u))
    for (x, y, rad, u) in pts:
        for yy in range(int(y - rad - 1), int(y + rad + 2)):
            for xx in range(int(x - rad - 1), int(x + rad + 2)):
                if (xx + 0.5 - x) ** 2 + (yy + 0.5 - y) ** 2 <= rad * rad:
                    # isik sol ustten: sarmalin dis ust kenari acik, ic alt kenari koyu
                    nx, ny = (xx + 0.5 - x), (yy + 0.5 - y)
                    lit = -(nx * (1 if side == 1 else 0.3) + ny) / max(rad, 0.5)
                    col = HORN_L if lit > 0.45 else (HORN if lit > -0.35 else HORN_D)
                    put(im, [(xx, yy)], col)
    # halka cizgileri (boynuz sirti)
    for k in range(1, 9):
        x, y, rad, u = pts[int(k * steps / 9.5)]
        th = math.atan2(y - cy, x - cx)
        for s in (-1, 0):
            put(im, [(x + math.cos(th) * (rad + s * 0.7), y + math.sin(th) * (rad + s * 0.7))], HORN_D)


def totem_attack(f):
    t = f / FRAMES
    pulse = 0.5 + 0.5 * math.sin(2 * math.pi * t + 1.0)
    im = new_canvas()
    ground(im, "ash", t)
    pole(im, 20, 28, 30, 58, RWOOD)
    carved_band(im, 51, 20, 28, RWOOD)
    # deri kayis caprazlari
    for y in (53, 55):
        put(im, [(20, y), (21, y), (22, y + 1), (23, y + 1), (24, y), (25, y), (26, y + 1), (27, y + 1), (28, y)], LEATHER)
    # --- disli oyma yuz (direk ortasi) ---
    put(im, [(21, 38), (22, 39), (23, 40), (25, 40), (26, 39), (27, 38)], RWOOD[0])   # ofkeli kaslar (V)
    ember = mix(F2, F4, pulse)
    put(im, [(22, 41), (23, 41), (25, 41), (26, 41)], RWOOD[0])
    put(im, [(22, 41), (26, 41)], ember)
    put(im, [(24, y) for y in range(41, 45)], RWOOD[3])
    put(im, [(23, 45), (25, 45)], RWOOD[0])
    put(im, [(x, 47) for x in range(21, 28)], rgba(30, 10, 10))
    put(im, [(x, 48) for x in range(21, 28)], rgba(30, 10, 10))
    put(im, [(21, 47), (21, 48), (27, 47), (27, 48), (23, 47), (25, 47)], BONE)   # azi disleri
    put(im, [(21, 49), (27, 49)], BONE_D)
    # aşı boyasi: uc pence cizigi (direk ust kismi)
    for k in range(3):
        put(im, [(21 + 2 * k + j * 0.5, 32 + j) for j in range(4)], OCHRE)
    # --- boynuzlar (kafatasinin arkasinda) ---
    _ram_horn(im, 1)
    _ram_horn(im, -1)
    # --- koc kafatasi: kubbe alin, genis goz hizasi, uzun daralan burun ---
    d = ImageDraw.Draw(im)
    skull = [(20, 15), (28, 15), (30, 17), (30, 22), (29, 25), (27, 28), (27, 32), (25, 34), (23, 34), (21, 32), (21, 28),
             (19, 25), (18, 22), (18, 17)]
    d.polygon(skull, fill=BONE)
    put(im, [(20, 15), (21, 15), (22, 15), (19, 16), (18, 17), (18, 18), (18, 19), (18, 20)], BONE_L)
    put(im, [(30, 19), (30, 20), (30, 21), (29, 24), (28, 26), (27, 29), (27, 30), (26, 32), (25, 33)], BONE_D)
    for ex in (20, 26):   # goz cukurlari + kor
        put(im, [(ex, 20), (ex + 1, 20), (ex + 2, 20), (ex, 21), (ex + 1, 21), (ex + 2, 21), (ex + 1, 22)], rgba(34, 12, 12))
        put(im, [(ex + 1, 21)], ember)
        put(im, [(ex + 1, 20)], mix(F1, F2, pulse))
    put(im, [(24, 17), (24, 18)], BONE_D)                        # alin catlagi
    put(im, [(23, 28), (25, 28), (24, 29), (23, 29), (25, 29)], rgba(34, 12, 12))   # burun deligi
    put(im, [(23, 32), (25, 32)], BONE_D)
    # alin boyasi (aşı boyasi)
    put(im, [(22, 17), (26, 17), (22, 24), (26, 24)], OCHRE)
    im = outline(im)
    # --- boynuz uclarindan sarkan kirmizi tuyler ---
    for side, ph in ((1, 0.0), (-1, 0.5)):
        sw = math.sin(2 * math.pi * (t + ph))
        bx = 8 if side == 1 else 40
        tx = bx + (1 if sw > 0.35 else (-1 if sw < -0.35 else 0))
        put(im, [(bx, 28), (bx, 29), (bx, 30)], LEATHER_D)
        put(im, [(bx, 31)], BONE)
        put(im, [(tx, 32), (tx, 33), (tx, 34), (tx, 35)], F1)
        put(im, [(tx - side, 33), (tx - side, 34)], rgba(128, 30, 18))
        put(im, [(tx, 36)], OUTLINE)
        put(im, [(tx + side, 33), (tx + side, 34)], OUTLINE)
    # --- kafatasinin tepesinde yanan ruh atesi (bolt cikis noktasi ~y12) ---
    fd = ImageDraw.Draw(im)
    cy = 12
    fl = [0, 1, 0, -1, 0, 1][f]
    fd.polygon([(CX - 5, cy + 4), (CX - 6, cy), (CX - 3, cy - 5), (CX + fl, cy - 11), (CX + 3, cy - 5), (CX + 6, cy), (CX + 5, cy + 4)], fill=F1)
    fd.polygon([(CX - 3, cy + 4), (CX - 4, cy + 1), (CX - 2, cy - 3), (CX + fl, cy - 8), (CX + 2, cy - 3), (CX + 4, cy + 1), (CX + 3, cy + 4)], fill=F2)
    fd.polygon([(CX - 2, cy + 4), (CX - 2, cy + 1), (CX + fl, cy - 4), (CX + 2, cy + 1), (CX + 2, cy + 4)], fill=F3)
    put(im, [(CX, cy + 1), (CX, cy + 2), (CX, cy + 3)], F4)
    for side, ph in ((-1, 0.0), (1, 0.5)):   # yan diller
        h = 3 + int(round(2 * math.sin(2 * math.pi * (t + ph))))
        fd.polygon([(CX + side * 4, cy + 3), (CX + side * 7, cy + 3 - h), (CX + side * 6, cy + 4)], fill=F2)
    # yukselen korlar
    for k in range(4):
        ph = (t + k / 4.0) % 1.0
        x = CX + math.sin(ph * 6.0 + k * 2.3) * 6
        y = cy - 8 - ph * 10
        c = F4 if ph < 0.3 else (F3 if ph < 0.6 else F2)
        put_alpha(im, x, y, (c[0], c[1], c[2], int(255 * (1 - ph * 0.7))))
    return im


# ------------------------------------------------------------------ 3) ALAN TOTEMI - hilal + ruh kapani (mor)
def totem_area(f):
    t = f / FRAMES
    glow = 0.5 + 0.5 * math.sin(2 * math.pi * t)
    im = new_canvas()
    ground(im, "none", t)
    pole(im, 20, 28, 27, 58, DEAD)
    carved_band(im, 31, 20, 28, DEAD)
    carved_band(im, 53, 20, 28, DEAD)
    # olu dal catlaklari + budak
    put(im, [(27, 36), (27, 37), (26, 38)], DEAD[0])
    put(im, [(21, 48), (21, 49), (22, 50)], DEAD[1])
    put(im, [(26, 56), (27, 56), (26, 57)], DEAD[0])
    # --- gozleri kapali dingin yuz ---
    put(im, [(x, 37) for x in range(21, 28)], DEAD[3])            # alin cikintisi
    for ex in (21, 25):
        put(im, [(ex, 38), (ex + 1, 39), (ex + 2, 39), (ex + 3, 38)], DEAD[0])   # kapali goz kavsi
        put(im, [(ex + 1, 40), (ex + 2, 40)], DEAD[4])
    put(im, [(24, y) for y in range(39, 44)], DEAD[3])
    put(im, [(25, y) for y in range(40, 44)], DEAD[1])
    put(im, [(22, 46), (23, 47), (24, 47), (25, 47), (26, 46)], DEAD[0])     # hafif gulumseme
    # mor boya: goz altindan inen ince cizgiler + alinda nokta
    paint = mix(P1, P2, glow)
    put(im, [(21, 41), (21, 42), (21, 43), (27, 41), (27, 42), (27, 43)], paint)
    put(im, [(24, 35)], mix(P2, P4, glow))
    put(im, [(23, 35), (25, 35), (24, 34), (24, 36)], P1)
    # --- tepe: oyma hilal (ay) ---
    cy, Ro, Ri, off = 16.0, 11.0, 9.3, 4.2
    for y in range(3, 30):
        for x in range(10, 39):
            dxo, dyo = x + 0.5 - CX, y + 0.5 - cy
            dxi, dyi = x + 0.5 - CX, y + 0.5 - (cy - off)
            if dxo * dxo + dyo * dyo <= Ro * Ro and dxi * dxi + dyi * dyi > Ri * Ri:
                u = (x - 13) / 22.0
                col = MOON[4] if (dxo < -6 and dyo < 3 and dxo * dxo + dyo * dyo > (Ro - 1.4) ** 2) else cyl_col(MOON, u)
                put(im, [(x, y)], col)
    # hilal ic kenari (oyma yiv) + mor boya noktalari
    for a_deg in range(20, 161, 6):
        a = math.radians(a_deg)
        put(im, [(CX + math.cos(a) * (Ri + 0.6), cy - off + math.sin(a) * (Ri + 0.6))], MOON[1])
    for a_deg in (50, 90, 130):
        a = math.radians(a_deg)
        put(im, [(CX + math.cos(a) * (Ro - 2.2) - 0.5, cy + math.sin(a) * (Ro - 2.2) - 0.5)], mix(P2, P3, glow))
    im = outline(im)
    # --- hilalin icinde asili ruh kapani cemberi (hafif sallanir) ---
    sw = [0, 0, 1, 0, 0, -1][f]
    hx, hy, R = CX + sw, 13, 5
    put(im, [(16, 7), (17, 8), (18, 8), (19, 9), (20, 9), (21, 9)], LEATHER_D)   # uclardan inen ipler (V)
    put(im, [(32, 7), (31, 8), (30, 8), (29, 9), (28, 9), (27, 9)], LEATHER_D)
    hd = ImageDraw.Draw(im)
    hd.ellipse((hx - R - 1, hy - R - 1, hx + R + 1, hy + R + 1), outline=OUTLINE)
    hd.ellipse((hx - R, hy - R, hx + R, hy + R), outline=LEATHER)
    put(im, [(hx - 3, hy - 4), (hx - 4, hy - 3), (hx - 5, hy - 1)], rgba(176, 122, 72))
    # ag: 6 kollu yildiz + ic halka, ortada isiyan boncuk
    web = mix(rgba(170, 146, 204), P3, 0.4 * glow)
    for k in range(6):
        a = k * math.pi / 3 + math.pi / 6
        for r in (2, 3, 4):
            put(im, [(hx + math.cos(a) * r, hy + math.sin(a) * r)], web)
    bead = mix(P2, P4, glow)
    put(im, [(hx - 1, hy), (hx + 1, hy), (hx, hy - 1), (hx, hy + 1)], P1)
    put(im, [(hx, hy)], bead)
    # cemberden sarkan uc kisa tuy
    for k, ox in enumerate((-3, 0, 3)):
        fx = hx + ox
        fy0 = hy + R - (1 if ox else 0)
        ln = 5 if ox == 0 else 4
        tip = 1 if math.sin(2 * math.pi * (t + k * 0.33)) > 0.5 else 0
        put(im, [(fx, fy0 + 1)], P2)
        pts = [(fx + (tip if j == ln - 1 else 0), fy0 + 2 + j) for j in range(ln)]
        put(im, pts, FEATHER)
        put(im, [(p[0] + 1, p[1]) for p in pts[1:-1]], FEATHER_D)
        put(im, [(pts[-1][0], pts[-1][1] + 1)], P1)
    # --- dipte isiyan mor mantarlar ---
    for (mx, my, big) in ((14, 58, True), (32, 59, False), (35, 57, False)):
        cap = mix(P2, P3, glow)
        put(im, [(mx, my), (mx, my - 1)], BONE)
        if big:
            put(im, [(mx - 2, my - 2), (mx - 1, my - 2), (mx, my - 2), (mx + 1, my - 2), (mx + 2, my - 2),
                     (mx - 1, my - 3), (mx, my - 3), (mx + 1, my - 3)], cap)
            put(im, [(mx - 1, my - 3)], P4)
            put(im, [(mx - 3, my - 2), (mx + 3, my - 2), (mx - 2, my - 3), (mx + 2, my - 3), (mx - 1, my - 4), (mx, my - 4),
                     (mx + 1, my - 4)], OUTLINE)
        else:
            put(im, [(mx - 1, my - 2), (mx, my - 2), (mx + 1, my - 2), (mx, my - 3)], cap)
            put(im, [(mx - 2, my - 2), (mx + 2, my - 2), (mx - 1, my - 3), (mx + 1, my - 3), (mx, my - 4)], OUTLINE)
    # --- ates bocekleri (mor ruh isiklari) ---
    for k in range(4):
        ph = (t + k / 4.0) % 1.0
        x = CX + math.sin(ph * 2 * math.pi + k * 1.6) * (11 + 3 * (k % 2))
        y = 52 - ph * 30 - k * 3
        a = int(235 * math.sin(ph * math.pi))
        put_alpha(im, x, y, (P3[0], P3[1], P3[2], a))
    return im


TOTEM_FUNCS = (("shield", totem_shield), ("attack", totem_attack), ("area", totem_area))


def make_totems(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    sheets = {}
    for name, fn in TOTEM_FUNCS:
        sheet = Image.new("RGBA", (W * FRAMES, H), (0, 0, 0, 0))
        for f in range(FRAMES):
            sheet.paste(fn(f), (f * W, 0))
        sheet.save(os.path.join(out_dir, "totem_%s_idle.png" % name))
        sheets[name] = sheet
    return sheets


def preview(sheets, path, scale=4):
    """Uc totemin 6 karesi, cimen zeminde (x4)."""
    pad = 8
    cw, ch = W * scale, H * scale
    out = Image.new("RGBA", (pad + FRAMES * (cw + pad), pad + 3 * (ch + pad)), (52, 92, 44, 255))
    for r, (name, _fn) in enumerate(TOTEM_FUNCS):
        for f in range(FRAMES):
            fr = sheets[name].crop((f * W, 0, (f + 1) * W, H)).resize((cw, ch), Image.NEAREST)
            out.alpha_composite(fr, (pad + f * (cw + pad), pad + r * (ch + pad)))
    out.save(path)


if __name__ == "__main__":
    import sys
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if len(sys.argv) > 1 and sys.argv[1] == "--preview-only":
        sh = {}
        for name, fn in TOTEM_FUNCS:
            sheet = Image.new("RGBA", (W * FRAMES, H), (0, 0, 0, 0))
            for f in range(FRAMES):
                sheet.paste(fn(f), (f * W, 0))
            sh[name] = sheet
        preview(sh, sys.argv[2])
    else:
        sh = make_totems(os.path.join(root, "assets", "shaman"))
        if len(sys.argv) > 1:
            preview(sh, sys.argv[1])
        print("totems ->", os.path.join(root, "assets", "shaman"))
