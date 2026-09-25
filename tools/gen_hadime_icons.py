#!/usr/bin/env python3
"""Suriyeli Hadime (karakter 14) yetenek ikonlari -> assets/skills/hadime_*_icon.png

Kullanim (repo kokunden):
    python tools/gen_hadime_icons.py      (sonra Godot'ta `--headless --import`)

Kullanici istegi (2026-09-25): yeni karakter Suriyeli Hadime. Ikonlar diger karakterlerin 48x48 kare karo diliyle
(tools/gen_elara_korsan_icons.py yardimcilari: tile/finish/sparkle - 1 px kontur, 1 px parlama, 3x NEAREST = 144 px).
Renkler Hadime'nin kendi paletinden: siyah basortu/mor-kahve cubbe, yesil gozler; lanet yesil-mor, emilen kalkan mavi.
  Q  Lanet Kitabi : acik kara kitaptan yukari firlayan yesil lanet kureleri
  E  Kara Delik   : kara kure + egik mor birikim diski + bukulen isik halkasi, iceri akan zerreler (2026-09-25 ikinci
                    istek: eski Kara Buyu ikonu silindi)
  R  Karabasan    : karanlik basortulu siluet, parlayan yesil gozler, alttan uzanan golge pencelerı
  Pasif Ruh Gocu  : yerde yatan beden + ustunde yukselen yari saydam Hadime silueti
"""
import math
import os
import sys

from PIL import ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_elara_korsan_icons import C, canvas, finish, mix, put, sparkle, tile  # noqa: E402

G_DEEP, G_MID, G_LIGHT, G_WHITE = C('#226022'), C('#6fdc4a'), C('#c8ff9a'), C('#f0ffe2')
V_DEEP, V_MID, V_LIGHT = C('#2a0f3a'), C('#5b2a86'), C('#9a5ccc')
B_DEEP, B_MID, B_LIGHT, B_WHITE = C('#1e2d7a'), C('#4f7dff'), C('#b9d4ff'), C('#eef5ff')
HOOD, HOOD_HI = C('#19191e'), C('#34343c')
SKIN, SKIN_D = C('#f0ccb4'), C('#e2ab83')
ROBE, ROBE_HI = C('#3a2d38'), C('#584258')


def curse_orb(d, e, cx, cy, r, trail):
    """Yesil cekirdekli, mor kenarli lanet kuresi + asagi uzanan kivilcimli iz."""
    for i in range(1, trail + 1):
        put(e, [(cx + (1 if i % 2 else -1) * (i // 3), cy + r + i)], G_MID if i < trail // 2 + 1 else V_LIGHT)
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=V_MID)
    d.ellipse((cx - r + 1, cy - r + 1, cx + r - 1, cy + r - 1), fill=G_MID)
    if r >= 3:
        d.ellipse((cx - r + 2, cy - r + 2, cx + r - 2, cy + r - 2), fill=G_LIGHT)
    put(e, [(cx - 1, cy - 1)], G_WHITE)


def hadime_lanet_kitabi():
    base = tile(C('#3a1650'), C('#10061a'), C('#3c2a5a'), C('#8a5cb4'), C('#0a0412'), glow_center=(24, 20))
    e = canvas()
    d = ImageDraw.Draw(e)
    # acik kitap (alt orta): koyu kahve kapak + krem sayfalar, ortada sirt
    COVER, COVER_D = C('#5a3222'), C('#351c12')
    PAGE, PAGE_D = C('#eee2c8'), C('#c7b391')
    d.polygon([(7, 36), (24, 39), (41, 36), (41, 41), (24, 44), (7, 41)], fill=COVER)
    d.line((7, 41, 24, 44), fill=COVER_D)
    d.line((24, 44, 41, 41), fill=COVER_D)
    d.polygon([(9, 32), (23, 35), (23, 40), (9, 37)], fill=PAGE)
    d.polygon([(25, 35), (39, 32), (39, 37), (25, 40)], fill=PAGE)
    for k in range(3):   # satirlar
        d.line((11, 34 + k, 21, 36 + k), fill=PAGE_D)
        d.line((27, 36 + k, 37, 34 + k), fill=PAGE_D)
    d.line((24, 35, 24, 41), fill=COVER_D)
    # sayfalardan yukselen yesil pus
    put(e, [(22, 33), (24, 32), (26, 33), (23, 31), (25, 30)], G_MID)
    # yukari firlayan uc lanet kuresi (ortadaki en buyuk ve en yuksekte)
    curse_orb(d, e, 24, 12, 5, 9)
    curse_orb(d, e, 13, 21, 3, 6)
    curse_orb(d, e, 35, 19, 3, 6)
    fx = canvas()
    sparkle(fx, 24, 12, G_WHITE, G_LIGHT, 1)
    sparkle(fx, 40, 8, C('#ffffff'), G_LIGHT, 1)
    sparkle(fx, 7, 11, C('#ffffff'), V_LIGHT, 1)
    finish(base, e, fx, "hadime_lanet_kitabi_icon.png")


def hadime_kara_delik():
    """E - Kara Delik: kara kure + egik mor birikim diski (arka yarisi kurenin arkasinda) + ustte bukulen isik halkasi,
    disaridan iceri sarmal cizerek akan zerreler."""
    base = tile(C('#2a1858'), C('#0a0616'), C('#6a48b8'), C('#8a6ad8'), C('#05030b'), glow_center=(24, 20), glow_r=(13, 11))
    e = canvas()
    d = ImageDraw.Draw(e)
    HOT, PINK = C('#ffdefa'), C('#de80ec')
    cx, cy = 24, 25
    # arka disk yarisi (kurenin arkasinda)
    for rr, col in ((16, V_MID), (14, V_LIGHT), (12, PINK)):
        d.arc((cx - rr, cy - rr // 2, cx + rr, cy + rr // 2), 180, 360, fill=col)
    # bukulen isik halkasi (kurenin ustunde)
    d.arc((cx - 10, cy - 14, cx + 10, cy + 4), 200, 340, fill=V_LIGHT)
    # kure
    d.ellipse((cx - 8, cy - 11, cx + 8, cy + 5), fill=C('#050308'))
    d.arc((cx - 8, cy - 11, cx + 8, cy + 5), 200, 330, fill=PINK)
    # on disk yarisi (kurenin onunde) - ic kenar en sicak
    for rr, col in ((16, V_MID), (15, V_LIGHT), (13, PINK), (12, HOT)):
        d.arc((cx - rr, cy - rr // 2, cx + rr, cy + rr // 2), 0, 180, fill=col)
    fx = canvas()
    # iceri akan zerreler (sarmal)
    for j in range(7):
        th0 = 2 * math.pi * j / 7
        for s_ in range(4):
            u = 0.15 + 0.12 * s_
            r = 22 - 13 * u
            th = th0 + 2.2 * u
            x, y = round(cx + r * math.cos(th)), round(cy + r * math.sin(th) * 0.55)
            put(fx, [(x, y)], PINK if s_ >= 2 else V_LIGHT)
    sparkle(fx, 40, 8, C('#ffffff'), V_LIGHT, 1)
    finish(base, e, fx, "hadime_kara_delik_icon.png")


def hadime_karabasan():
    base = tile(C('#2e1440'), C('#08040c'), C('#6a2a6e'), C('#8a4a9a'), C('#050207'), glow_center=(24, 20), glow_r=(17, 15))
    e = canvas()
    d = ImageDraw.Draw(e)
    SIL, SIL_HI = C('#0c0712'), C('#5a3470')
    # alttan uzanan golge pencelerı (sol-alt / sag-alt)
    for side in (-1, 1):
        x0 = 24 + side * 8
        pts = [(x0, 46), (24 + side * 14, 40), (24 + side * 19, 33), (24 + side * 21, 27)]
        d.line(pts, fill=SIL_HI, width=3)
        d.line(pts, fill=SIL)
        tx, ty = pts[-1]
        for f in (-1, 0, 1):
            d.line((tx, ty, tx + side * 2 + f, ty - 3), fill=SIL_HI)
    # omuzlar + basortulu bas (koyu siluet, kenarinda soluk mor isik)
    d.polygon([(10, 46), (13, 36), (19, 32), (29, 32), (35, 36), (38, 46)], fill=SIL)
    d.line((13, 36, 19, 32), fill=SIL_HI)
    d.ellipse((13, 8, 35, 34), fill=SIL)
    d.arc((13, 8, 35, 34), 170, 300, fill=SIL_HI)
    d.arc((14, 9, 34, 33), 190, 270, fill=C('#34204a'))
    # yuz boslugu (karanlik) + parlayan yesil gozler
    d.ellipse((17, 15, 31, 30), fill=C('#050308'))
    for ex in (20, 26):
        d.rectangle((ex, 21, ex + 2, 22), fill=G_MID)
        put(e, [(ex + 1, 21)], G_WHITE)
    fx = canvas()
    # goz parlamasi (konturdan etkilenmesin diye fx katmaninda)
    for ex in (21, 27):
        put(fx, [(ex, 20), (ex, 23)], mix(G_MID, (0, 0, 0, 255), 0.35))
    sparkle(fx, 41, 9, C('#ffffff'), V_LIGHT, 1)
    finish(base, e, fx, "hadime_karabasan_icon.png")


def hadime_pasif():
    base = tile(C('#123a3a'), C('#07141a'), C('#1e5a56'), C('#6ab8b0'), C('#040c0e'), glow_center=(24, 18))
    e = canvas()
    d = ImageDraw.Draw(e)
    # yerde yatan beden (koyu basortu + cubbe)
    d.ellipse((6, 36, 16, 45), fill=HOOD)
    d.rounded_rectangle((14, 38, 42, 44), radius=2, fill=ROBE)
    d.line((15, 38, 41, 38), fill=ROBE_HI)
    put(e, [(10, 40), (11, 40), (10, 41)], SKIN)
    fx = canvas()
    # yukselen YARI SAYDAM Hadime (basortu + yuz + omuzlar) - dama desenli saydamlik, kontursuz (fx katmani)
    GH, GH_HI, GH_SKIN, GH_EYE = C('#8fb7c8'), C('#d8f0f6'), C('#f4e2d8'), G_MID

    def ghost_px(x, y, col):
        if ((x + y) & 1) == 0 or col in (GH_HI, GH_EYE):
            put(fx, [(x, y)], col)
    for y in range(6, 34):
        for x in range(12, 37):
            dx, dy = x + 0.5 - 24, y + 0.5 - 15
            head = (dx / 8.5) ** 2 + (dy / 9.0) ** 2 <= 1.0
            face = (dx / 5.0) ** 2 + ((dy - 1.5) / 6.0) ** 2 <= 1.0
            body = 22 <= y and abs(dx) <= 4 + (y - 22) * 0.9 and y <= 33
            if face:
                ghost_px(x, y, GH_SKIN)
            elif head or body:
                ghost_px(x, y, GH)
    for (x, y) in ((17, 10), (18, 8), (20, 7), (22, 6)):
        put(fx, [(x, y)], GH_HI)
    for ex in (21, 26):
        put(fx, [(ex, 16), (ex + 1, 16)], GH_EYE)
    # bedenden yukselen ruh ipi
    for (x, y) in ((24, 35), (23, 36), (24, 37), (25, 38)):
        put(fx, [(x, y)], GH_HI)
    sparkle(fx, 40, 10, C('#ffffff'), GH_HI, 1)
    sparkle(fx, 7, 24, C('#ffffff'), GH, 1)
    finish(base, e, fx, "hadime_passive_icon.png")


if __name__ == "__main__":
    print("Suriyeli Hadime ikonlari:")
    hadime_lanet_kitabi()
    hadime_kara_delik()
    hadime_karabasan()
    hadime_pasif()
