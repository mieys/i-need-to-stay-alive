"""Shaman totemleri v2 - SIFIRDAN, gercekten "sihirli totem" gorunumlu pixel-art (kullanici geri bildirimi 2026-09-22:
"totemleri beğenmedim, baştan tasarla, gerçekten sihirli totemlere benzesinler").
Eski tasarim: direk ustunde tabela/kafatasi/kure. Yeni tasarim: oyma AHSAP/TAS totem direkleri, yuz + parlayan runler, havada suzulen
buyulu odak (kristal / yasayan ates / bosluk kuresi), yorungede donen parcalar, halo ve yukselen parcaciklar. 6 karelik dongu.

Kare boyutu 48x64 sanat pikseli (genislik x yukseklik) - dokunun 1 pikseli = oyun texel'i (1.212 px), yani karakter/FX ile ayni yogunluk;
sadece totem daha uzun (77 px) durur ki oyuncudan belirgin buyuk/onemli dursun. Ayak (zemin) kare tabaninda (y=63).
"""
import math
import os
import random

from PIL import Image, ImageDraw

W, H = 48, 64
FRAMES = 6
CX = 24
OUTLINE = (14, 9, 12, 255)


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
        x, y = int(x), int(y)
        if 0 <= x < im.size[0] and 0 <= y < im.size[1]:
            im.putpixel((x, y), col)


def put_alpha(im, x, y, col):
    """Yariseffaf piksel (halo/parcacik): mevcut piksel opaksa uzerine karistirir, bossa alfa ile koyar."""
    x, y = int(x), int(y)
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


def halo(im, cx, cy, r_in, r_out, col, parity=0):
    """Dither (dama) halo: gozu yormayan pixel-art parilti. Sadece bos piksellere yazilir."""
    for y in range(int(cy - r_out), int(cy + r_out) + 1):
        for x in range(int(cx - r_out), int(cx + r_out) + 1):
            d = math.hypot(x - cx, y - cy)
            if r_in <= d <= r_out and ((x + y + parity) & 1) == 0:
                if 0 <= x < W and 0 <= y < H and im.getpixel((x, y))[3] == 0:
                    a = int(col[3] * (1.0 - (d - r_in) / max(1.0, (r_out - r_in))))
                    im.putpixel((x, y), (col[0], col[1], col[2], max(30, a)))


# ------------------------------------------------------------------ paletler
WOOD_D, WOOD_M, WOOD_L, WOOD_H = rgba(38, 24, 18), rgba(84, 54, 34), rgba(128, 88, 54), rgba(170, 124, 78)
STONE_D, STONE_M, STONE_L = rgba(46, 44, 58), rgba(88, 86, 104), rgba(134, 132, 152)
BONE_D, BONE, BONE_L = rgba(150, 134, 108), rgba(222, 208, 176), rgba(248, 240, 216)

B0, B1, B2, B3, B4 = rgba(18, 40, 104), rgba(44, 100, 208), rgba(98, 172, 255), rgba(190, 232, 255), rgba(244, 252, 255)
F0, F1, F2, F3, F4 = rgba(86, 14, 10), rgba(190, 44, 18), rgba(250, 122, 30), rgba(255, 198, 72), rgba(255, 244, 196)
V0, V1, V2, V3, V4 = rgba(28, 12, 52), rgba(84, 40, 152), rgba(152, 86, 232), rgba(216, 164, 255), rgba(250, 238, 255)
MAG = rgba(236, 96, 226)


def plinth(im, glow, ring_col, ring_dark, stone=(STONE_D, STONE_M, STONE_L), t=0.0):
    """Zemin: yassi tas kaide + uzerinde nabiz atan run halkasi (ayaklar y=63)."""
    d = ImageDraw.Draw(im)
    sd, sm, sl = stone
    d.ellipse((6, 54, 41, 63), fill=sd)
    d.ellipse((7, 54, 40, 62), fill=sm)
    d.ellipse((9, 55, 38, 60), fill=sd)
    # ust yuz acik kenar (sol ust)
    for x in range(10, 22):
        put(im, [(x, 54 + (1 if x < 12 else 0))], sl)
    # run halkasi (kesikli, donuyor)
    n = 34
    for i in range(n):
        a = 2 * math.pi * i / n + t * 2 * math.pi * 0.5
        x = 23.5 + math.cos(a) * 13.5
        y = 58.0 + math.sin(a) * 3.0
        if (i % 3) != 0:
            put(im, [(round(x), round(y))], mix(ring_dark, ring_col, glow))
    # tas catlaklari / kucuk parcalar
    put(im, [(9, 58), (10, 59), (38, 58), (37, 59)], sd)


def pole(im, x0b, x1b, x0t, x1t, ytop, ybot, cols, glow_cols=None):
    """Oyma direk: hafif daralan gövde, sol acik/sag koyu serit, dikey damar, yatay bantlar."""
    d = ImageDraw.Draw(im)
    dark, mid, light, hi = cols
    d.polygon([(x0t, ytop), (x1t, ytop), (x1b, ybot), (x0b, ybot)], fill=mid)
    d.polygon([(x0t, ytop), (x0t + 2, ytop), (x0b + 2, ybot), (x0b, ybot)], fill=light)
    d.line([(x0t, ytop), (x0b, ybot)], fill=hi)
    d.polygon([(x1t - 2, ytop), (x1t, ytop), (x1b, ybot), (x1b - 2, ybot)], fill=dark)
    rnd = random.Random(7)
    for _ in range(9):
        gy = rnd.randint(ytop + 2, ybot - 3)
        gx = rnd.randint(x0t + 3, x1t - 3)
        put(im, [(gx, gy), (gx, gy + 1), (gx, gy + 2)], dark)


def band(im, y, x0, x1, col_d, col_l):
    d = ImageDraw.Draw(im)
    d.line([(x0, y), (x1, y)], fill=col_d)
    d.line([(x0, y + 1), (x1, y + 1)], fill=col_l)


# ------------------------------------------------------------------ 1) KALKAN TOTEMI (mavi kristal muhafiz)
def totem_shield(f):
    t = f / FRAMES
    glow = 0.5 + 0.5 * math.sin(2 * math.pi * t)
    im = new_canvas()
    d = ImageDraw.Draw(im)
    plinth(im, glow, B2, B0, t=t)
    pole(im, 18, 30, 19, 29, 28, 57, (WOOD_D, WOOD_M, WOOD_L, WOOD_H))
    # govde bantlari (tas + mavi)
    band(im, 43, 17, 30, STONE_D, STONE_L)
    band(im, 54, 17, 30, STONE_D, STONE_L)
    # kalkan omuzlar (ahsap plaka + parlayan mavi kenar)
    for sign in (-1, 1):
        cx = CX + sign * 14
        pts = [(cx - 5 * sign * -1 if False else cx, 0)]
        left = [(4, 37), (13, 34), (13, 51), (8, 55), (4, 50)]
        right = [(44 - 4, 37 + 0), ]  # placeholder (asagida gercek koordinatlar)
    d.polygon([(3, 37), (13, 34), (13, 51), (8, 56), (3, 51)], fill=WOOD_D)
    d.polygon([(4, 38), (12, 35), (12, 50), (8, 54), (4, 50)], fill=WOOD_M)
    d.polygon([(4, 38), (8, 36), (8, 53), (4, 50)], fill=WOOD_L)
    d.polygon([(45, 37), (35, 34), (35, 51), (40, 56), (45, 51)], fill=WOOD_D)
    d.polygon([(44, 38), (36, 35), (36, 50), (40, 54), (44, 50)], fill=WOOD_M)
    d.polygon([(36, 35), (40, 36), (44, 38), (44, 41), (36, 38)], fill=WOOD_L)
    rim = mix(B1, B3, glow)
    for pts in ([(5, 39), (11, 37), (11, 49), (8, 52), (5, 49)], [(43, 39), (37, 37), (37, 49), (40, 52), (43, 49)]):
        d.polygon(pts, outline=rim)
    put(im, [(8, 43), (8, 44), (7, 44), (9, 44), (8, 45)], mix(B2, B4, glow))
    put(im, [(40, 43), (40, 44), (39, 44), (41, 44), (40, 45)], mix(B2, B4, glow))
    # bas: genis oyma blok + tas tac
    d.polygon([(14, 26), (34, 26), (36, 33), (34, 42), (14, 42), (12, 33)], fill=WOOD_D)
    d.polygon([(15, 27), (33, 27), (35, 33), (33, 41), (15, 41), (13, 33)], fill=WOOD_M)
    d.polygon([(15, 27), (19, 27), (17, 41), (15, 41), (13, 33)], fill=WOOD_L)
    d.rectangle((13, 24, 35, 27), fill=STONE_D)
    d.rectangle((14, 24, 34, 26), fill=STONE_M)
    d.line([(14, 24), (34, 24)], fill=STONE_L)
    for x in (16, 24, 32):
        put(im, [(x, 25)], mix(B1, B3, glow))
    # yuz: kaslar, parlayan gozler, burun, kucuk azi disleri
    d.line([(16, 31), (22, 33)], fill=WOOD_D)
    d.line([(32, 31), (26, 33)], fill=WOOD_D)
    eye = mix(B2, B4, glow)
    d.rectangle((17, 33, 21, 35), fill=B0)
    d.rectangle((27, 33, 31, 35), fill=B0)
    d.rectangle((18, 34, 21, 34), fill=eye)
    d.rectangle((27, 34, 30, 34), fill=eye)
    put(im, [(19, 33), (29, 33)], B3 if glow > 0.6 else B2)
    d.rectangle((23, 34, 25, 38), fill=WOOD_D)
    d.line([(24, 34), (24, 37)], fill=WOOD_M)
    d.rectangle((19, 39, 29, 39), fill=WOOD_D)
    put(im, [(20, 40), (28, 40)], BONE)
    # govde runu: parlayan elmas + cizgiler
    rune = mix(B1, B4, glow)
    rc = (24, 48)
    put(im, [(rc[0], rc[1] - 4), (rc[0] - 1, rc[1] - 3), (rc[0] + 1, rc[1] - 3), (rc[0] - 2, rc[1] - 2), (rc[0] + 2, rc[1] - 2),
             (rc[0] - 3, rc[1] - 1), (rc[0] + 3, rc[1] - 1), (rc[0] - 2, rc[1] + 1), (rc[0] + 2, rc[1] + 1), (rc[0] - 1, rc[1] + 2),
             (rc[0] + 1, rc[1] + 2), (rc[0], rc[1] + 3)], rune)
    put(im, [(24, 47), (24, 48), (24, 49)], mix(B3, B4, glow))
    im = outline(im)
    # yuzen buyu kristali
    bob = math.sin(2 * math.pi * t) * 1.5
    cy = 12 + bob
    cyi = int(round(cy))
    # kristal <-> bas enerji seridi
    for y in range(cyi + 12, 24):
        if (y + f) % 2 == 0:
            put(im, [(24, y)], mix(B1, B3, glow))
    halo(im, CX, cy, 11, 17, rgba(98, 172, 255, 150), parity=f)
    cd = ImageDraw.Draw(im)
    cd.polygon([(24, cyi - 12), (32, cyi), (24, cyi + 12), (16, cyi)], fill=OUTLINE)
    cd.polygon([(24, cyi - 10), (30, cyi), (24, cyi + 10), (18, cyi)], fill=B1)
    cd.polygon([(24, cyi - 10), (24, cyi + 10), (18, cyi)], fill=mix(B2, B3, 0.35))
    cd.polygon([(24, cyi - 10), (30, cyi), (24, cyi)], fill=mix(B2, B4, 0.25 + 0.35 * glow))
    cd.polygon([(24, cyi), (30, cyi), (24, cyi + 10)], fill=B0)
    cd.line([(24, cyi - 10), (24, cyi + 10)], fill=mix(B3, B4, glow))
    put(im, [(21, cyi - 4), (21, cyi - 3), (22, cyi - 5)], B4)
    # yorungede donen 3 kucuk kristal
    for k in range(3):
        a = 2 * math.pi * (t + k / 3.0)
        x = CX + math.cos(a) * 15
        y = cy + math.sin(a) * 4.5
        front = math.sin(a) > 0
        col = B3 if front else B1
        for (dx, dy) in ((0, -2), (0, -1), (-1, 0), (0, 0), (1, 0), (0, 1), (0, 2)):
            put_alpha(im, round(x) + dx, round(y) + dy, col)
        put_alpha(im, round(x), round(y) - 1, B4 if front else B2)
    # yukselen mavi parcaciklar
    for k in range(4):
        ph = (t + k / 4.0) % 1.0
        x = CX + math.sin(ph * 6.0 + k * 1.7) * 11
        y = 50 - ph * 40
        put_alpha(im, round(x), round(y), rgba(140, 210, 255, int(255 * (1 - ph))))
    return im


# ------------------------------------------------------------------ 2) SALDIRI TOTEMI (savas totemi, yasayan alev)
def totem_attack(f):
    t = f / FRAMES
    pulse = 0.5 + 0.5 * math.sin(2 * math.pi * t + 1.0)
    im = new_canvas()
    d = ImageDraw.Draw(im)
    CHAR = (rgba(30, 22, 26), rgba(56, 40, 44), rgba(96, 72, 72))
    plinth(im, pulse, F2, F0, stone=CHAR, t=t)
    RW = (rgba(48, 20, 18), rgba(102, 40, 32), rgba(154, 66, 44), rgba(196, 96, 60))
    pole(im, 18, 30, 19, 29, 28, 57, RW)
    band(im, 44, 17, 30, rgba(30, 22, 26), rgba(96, 72, 72))
    band(im, 54, 17, 30, rgba(30, 22, 26), rgba(96, 72, 72))
    # savas boyasi zigzag runleri (kor gibi nabiz atar)
    zig = mix(F1, F3, pulse)
    for y0 in (46, 50):
        put(im, [(20, y0 + 1), (21, y0), (22, y0 + 1), (23, y0), (24, y0 + 1), (25, y0), (26, y0 + 1), (27, y0), (28, y0 + 1)], zig)
    # omuz kemik dikenleri
    d.polygon([(17, 47), (8, 41), (10, 46), (7, 49), (16, 51)], fill=BONE_D)
    d.polygon([(31, 47), (40, 41), (38, 46), (41, 49), (32, 51)], fill=BONE_D)
    put(im, [(10, 42), (11, 43), (9, 45)], BONE)
    put(im, [(38, 42), (37, 43), (39, 45)], BONE)
    # kafa: geniş oyma maske
    d.polygon([(13, 27), (35, 27), (37, 35), (33, 44), (15, 44), (11, 35)], fill=rgba(40, 18, 16))
    d.polygon([(14, 28), (34, 28), (36, 35), (32, 43), (16, 43), (12, 35)], fill=rgba(112, 44, 34))
    d.polygon([(14, 28), (19, 28), (17, 43), (16, 43), (12, 35)], fill=rgba(160, 70, 46))
    # boynuzlar (kemik, yukari kivrik)
    d.polygon([(15, 30), (10, 27), (7, 20), (7, 13), (10, 18), (12, 22), (17, 26)], fill=BONE_D)
    d.polygon([(16, 29), (11, 26), (8, 20), (8, 15), (10, 19), (13, 23)], fill=BONE)
    d.polygon([(33, 30), (38, 27), (41, 20), (41, 13), (38, 18), (36, 22), (31, 26)], fill=BONE_D)
    d.polygon([(32, 29), (37, 26), (40, 20), (40, 15), (38, 19), (35, 23)], fill=BONE_L)
    # yuz: ofkeli kaslar, parlayan gozler, kuru burun
    d.polygon([(15, 32), (23, 35), (23, 32), (15, 30)], fill=rgba(30, 12, 12))
    d.polygon([(33, 32), (25, 35), (25, 32), (33, 30)], fill=rgba(30, 12, 12))
    eye = mix(F3, F4, pulse)
    d.polygon([(17, 34), (22, 35), (22, 37), (18, 36)], fill=F1)
    d.polygon([(31, 34), (26, 35), (26, 37), (30, 36)], fill=F1)
    put(im, [(19, 35), (20, 35), (21, 36), (29, 35), (28, 35), (27, 36)], eye)
    d.polygon([(23, 37), (25, 37), (24, 40)], fill=rgba(30, 12, 12))
    # agiz: kemik disleri + ic kor
    d.rectangle((18, 40, 30, 43), fill=rgba(24, 8, 8))
    d.rectangle((19, 41, 29, 42), fill=mix(F1, F3, pulse))
    for x in (18, 20, 22, 24, 26, 28):
        put(im, [(x, 40), (x + 1, 40), (x, 41)], BONE)
    for x in (19, 22, 26, 29):
        put(im, [(x, 43), (x, 42)], BONE_D)
    im = outline(im)
    # tepede kemik kafes pencerelerine tutunmus YASAYAN ALEV
    d2 = ImageDraw.Draw(im)
    for sign in (-1, 1):
        cxl = CX + sign * 4
        d2.polygon([(CX + sign * 3, 27), (CX + sign * 8, 20), (CX + sign * 7, 14), (CX + sign * 4, 19), (CX + sign * 3, 23)], fill=BONE_D)
        put(im, [(CX + sign * 7, 15), (CX + sign * 7, 16), (CX + sign * 6, 18)], BONE)
    cy = 12
    halo(im, CX, cy + 1, 9, 17, rgba(250, 122, 30, 150), parity=f)
    # alev gövdesi: katmanli damla + titreyen dil ucu
    flick = math.sin(2 * math.pi * t * 2) * 1.0
    fd = ImageDraw.Draw(im)
    fd.polygon([(CX - 7, cy + 6), (CX - 8, cy), (CX - 4, cy - 6), (CX + flick, cy - 13), (CX + 4, cy - 6), (CX + 8, cy), (CX + 7, cy + 6), (CX, cy + 9)], fill=F1)
    fd.polygon([(CX - 5, cy + 6), (CX - 5, cy + 1), (CX - 2, cy - 5), (CX + flick * 0.6, cy - 10), (CX + 3, cy - 5), (CX + 5, cy + 1), (CX + 5, cy + 6), (CX, cy + 8)], fill=F2)
    fd.polygon([(CX - 3, cy + 6), (CX - 3, cy + 2), (CX - 1, cy - 3), (CX + flick * 0.4, cy - 6), (CX + 2, cy - 2), (CX + 3, cy + 2), (CX + 3, cy + 6), (CX, cy + 7)], fill=F3)
    fd.polygon([(CX - 1, cy + 5), (CX - 1, cy + 1), (CX + flick * 0.3, cy - 2), (CX + 1, cy + 1), (CX + 1, cy + 5)], fill=F4)
    # yan kucuk dil
    for sign, ph in ((-1, 0.0), (1, 0.5)):
        h = 4 + int(round(2 * math.sin(2 * math.pi * (t + ph))))
        fd.polygon([(CX + sign * 6, cy + 2), (CX + sign * 9, cy + 2 - h), (CX + sign * 8, cy + 4)], fill=F2)
    put(im, [(CX - 2, cy - 4), (CX - 2, cy - 3)], F4)
    # yukselen kor
    for k in range(5):
        ph = (t + k / 5.0) % 1.0
        x = CX + math.sin(ph * 7.0 + k * 2.1) * 9
        y = cy - 6 - ph * 14
        c = F4 if ph < 0.3 else (F3 if ph < 0.6 else F2)
        put_alpha(im, round(x), round(y), (c[0], c[1], c[2], int(255 * (1 - ph * 0.8))))
    return im


# ------------------------------------------------------------------ 3) ALAN TOTEMI (bosluk gozu)
def totem_area(f):
    t = f / FRAMES
    glow = 0.5 + 0.5 * math.sin(2 * math.pi * t)
    im = new_canvas()
    d = ImageDraw.Draw(im)
    OB = (V0, rgba(52, 36, 88), rgba(92, 72, 138))
    plinth(im, glow, V3, V1, stone=OB, t=t)
    # obsidyen stel: alta genis, uste daralir + omuzda sivri kesim
    d.polygon([(15, 57), (33, 57), (31, 28), (17, 28)], fill=V0)
    d.polygon([(16, 57), (32, 57), (30, 29), (18, 29)], fill=rgba(52, 36, 88))
    d.polygon([(16, 57), (20, 57), (20, 29), (18, 29)], fill=rgba(92, 72, 138))
    d.polygon([(28, 57), (32, 57), (30, 29), (28, 29)], fill=rgba(30, 20, 56))
    d.polygon([(17, 28), (31, 28), (29, 24), (19, 24)], fill=rgba(52, 36, 88))
    d.line([(19, 24), (29, 24)], fill=rgba(112, 92, 158))
    band(im, 55, 15, 32, V0, rgba(92, 72, 138))
    # parlayan catlaklar
    crack = mix(V1, MAG, glow)
    put(im, [(24, 45), (23, 46), (23, 47), (24, 48), (24, 49), (25, 50), (25, 51), (24, 52)], crack)
    put(im, [(20, 50), (21, 51), (21, 52), (20, 53)], mix(V1, V3, glow))
    put(im, [(28, 49), (27, 50), (27, 52), (28, 53)], mix(V1, V3, glow))
    # spiral runler (ust ve alt)
    rr = mix(V1, V3, glow)
    put(im, [(19, 31), (20, 30), (21, 30), (22, 31), (22, 32), (21, 33), (20, 33)], rr)
    put(im, [(29, 31), (28, 30), (27, 30), (26, 31), (26, 32), (27, 33), (28, 33)], rr)
    # dev goz
    eyeb = [(13, 39), (18, 35), (24, 33), (30, 35), (35, 39), (30, 43), (24, 45), (18, 43)]
    d.polygon(eyeb, fill=OUTLINE)
    d.polygon([(15, 39), (19, 36), (24, 35), (29, 36), (33, 39), (29, 42), (24, 43), (19, 42)], fill=rgba(20, 8, 36))
    iris = mix(V2, V4, glow * 0.8)
    d.ellipse((20, 36, 28, 42), fill=V1)
    d.ellipse((21, 37, 27, 41), fill=iris)
    d.line([(24, 36), (24, 42)], fill=OUTLINE)
    put(im, [(22, 38), (22, 37)], V4)
    d.line([(15, 39), (19, 36), (24, 35), (29, 36), (33, 39)], fill=mix(V1, V3, glow))
    im = outline(im)
    # yuzen taş levhalar (kollar) - zit fazda inip cikar
    for sign, ph in ((-1, 0.0), (1, 0.5)):
        by = math.sin(2 * math.pi * (t + ph)) * 1.6
        x0 = 4 if sign < 0 else 37
        y0 = int(round(38 + by))
        sd = ImageDraw.Draw(im)
        sd.polygon([(x0, y0 + 2), (x0 + 3, y0), (x0 + 7, y0 + 1), (x0 + 7, y0 + 13), (x0 + 3, y0 + 16), (x0, y0 + 13)], fill=OUTLINE)
        sd.polygon([(x0 + 1, y0 + 3), (x0 + 3, y0 + 1), (x0 + 6, y0 + 2), (x0 + 6, y0 + 12), (x0 + 3, y0 + 15), (x0 + 1, y0 + 12)], fill=rgba(52, 36, 88))
        sd.line([(x0 + 1, y0 + 3), (x0 + 1, y0 + 12)], fill=rgba(92, 72, 138))
        put(im, [(x0 + 3, y0 + 5), (x0 + 3, y0 + 6), (x0 + 3, y0 + 8), (x0 + 3, y0 + 9)], mix(V1, V3, glow))
    # bosluk kuresi + halka
    bob = math.sin(2 * math.pi * t) * 1.5
    cy = 12 + bob
    cyi = int(round(cy))
    halo(im, CX, cy, 10, 17, rgba(152, 86, 232, 150), parity=f)
    ring_a = [2 * math.pi * i / 40 for i in range(40)]
    # halka ARKA yarisi (kureden once)
    for a in ring_a:
        if math.sin(a) < 0:
            put_alpha(im, round(CX + math.cos(a) * 15), round(cy + math.sin(a) * 4.5), mix(V1, V3, 0.35))
    od = ImageDraw.Draw(im)
    od.ellipse((CX - 9, cyi - 9, CX + 9, cyi + 9), fill=OUTLINE)
    od.ellipse((CX - 8, cyi - 8, CX + 8, cyi + 8), fill=V1)
    od.ellipse((CX - 7, cyi - 7, CX + 7, cyi + 7), fill=rgba(12, 4, 24))
    # parlak hilal (ust-sol)
    for y in range(cyi - 8, cyi + 9):
        for x in range(CX - 8, CX + 9):
            dd = math.hypot(x - CX, y - cyi)
            if 5.0 < dd <= 8.0 and (x - CX) + (y - cyi) < 2:
                put(im, [(x, y)], mix(V2, V3, (8.0 - dd) / 3.0))
    # girdap kollari (donuyor)
    for arm in range(3):
        for i in range(12):
            a = arm * 2 * math.pi / 3 + i * 0.5 - 2 * math.pi * t
            r = 1.0 + i * 0.5
            put(im, [(CX + round(math.cos(a) * r), cyi + round(math.sin(a) * r))], mix(V1, V4, i / 12.0))
    put(im, [(CX - 4, cyi - 5), (CX - 3, cyi - 6)], V4)
    # halka ON yarisi
    for a in ring_a:
        if math.sin(a) >= 0:
            put(im, [(round(CX + math.cos(a) * 15), round(cy + math.sin(a) * 4.5))], mix(V2, V4, 0.5 + 0.3 * glow))
    # halkada donen 3 tas parca
    for k in range(3):
        a = 2 * math.pi * (t + k / 3.0)
        x = CX + math.cos(a) * 15
        y = cy + math.sin(a) * 4.5
        front = math.sin(a) > 0
        col = rgba(92, 72, 138) if front else rgba(52, 36, 88)
        put(im, [(round(x) - 1, round(y)), (round(x), round(y)), (round(x) + 1, round(y)), (round(x), round(y) - 1), (round(x), round(y) + 1)], col)
        put(im, [(round(x), round(y) - 1)], V3 if front else V1)
    # yukselen mor parcaciklar
    for k in range(4):
        ph = (t + k / 4.0) % 1.0
        x = CX + math.sin(ph * 6.0 + k * 1.3) * 12
        y = 52 - ph * 42
        put_alpha(im, round(x), round(y), rgba(216, 164, 255, int(255 * (1 - ph))))
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
    """Uc totemin 6 karesi, koyu ve cimen zeminde (x4)."""
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
    sh = make_totems(os.path.join(root, "assets", "shaman"))
    if len(sys.argv) > 1:
        preview(sh, sys.argv[1])
    print("totems ->", os.path.join(root, "assets", "shaman"))
