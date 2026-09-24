#!/usr/bin/env python3
"""Elara + Korsan yetenek ikonlari (Q / E / R / pasif) -> assets/skills/*.png

Kullanim (repo kokunden):
    python tools/gen_elara_korsan_icons.py      (sonra Godot'ta `--headless --import`)

Kullanici istegi (2026-09-24): "Korsanin ve elaranin skill ikonlarini yeniden tasarlamani istiyorum pixel tarzda 48x48
yetenekleriyle uyumlu ikonlar olmali." Eskiden Elara'nin ikonlari 1254 px boyama (piksel degil), Korsan'inkiler duz 128 px
rozetlerdi; Elara'nin Q (Sivisma) ikonu hic yoktu.

Kurallar (bkz. hafiza: 48x48 piksel yogunlugu, tools/gen_spirit_assets.py):
  - 48x48 sanat izgarasi, 1 px kontur + 1 px parlama, iri 2-3 px bloklar YOK; 3x NEAREST -> 144x144 PNG.
  - KARE ikon (HUD/menu yetenek slotlari kare): koyu kontur + ince isik/golge kenar + her yetenege kendi renginde dikey
    degrade zemin (dither gecisli) + amblemin arkasinda yumusak isik. Ruhani yetenekler yuvarlak madalyon oldugu icin bu
    ikonlar bir bakista onlardan ayrilir.
  - Her yetenegin zemin rengi farkli (HUD'da Q/E/R/pasif bir bakista ayirt edilsin); amblem yetenegin kendisini anlatir.
"""
import math
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "skills")
S = 48
K = 3

OUTL = (22, 12, 8, 255)


def C(h, a=255):
    h = h.lstrip('#')
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3)) + (255,)


def canvas():
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))


def put(layer, pts, col):
    for (x, y) in pts:
        if 0 <= x < S and 0 <= y < S:
            layer.putpixel((int(x), int(y)), col)


def sparkle(layer, cx, cy, core, arm, long_arm=2):
    put(layer, [(cx, cy)], core)
    for i in range(1, long_arm + 1):
        put(layer, [(cx + i, cy), (cx - i, cy), (cx, cy + i), (cx, cy - i)], arm)


def outline(layer, col=OUTL):
    """Amblemin dis kenarina 1 px koyu kontur."""
    px = layer.load()
    out = layer.copy()
    op = out.load()
    for y in range(S):
        for x in range(S):
            if px[x, y][3] > 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < S and 0 <= ny < S and px[nx, ny][3] > 0:
                    op[x, y] = col
                    break
    return out


def tile(top, bottom, glow, rim_hi, rim_lo, glow_center=(24, 23), glow_r=(15, 14)):
    """Kare ikon zemini: yuvarlatilmis koyu kontur, 1 px isik (ust/sol) / golge (alt/sag) kenar, 4 bantli dikey degrade
    (bant gecislerinde 1 satir dama dither), ortada yumusak isik elipsi (kenari dither), koselerde hafif vinyet."""
    im = canvas()
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, S - 1, S - 1), radius=5, fill=OUTL)
    mask = canvas()
    ImageDraw.Draw(mask).rounded_rectangle((1, 1, S - 2, S - 2), radius=4, fill=(255, 255, 255, 255))
    inner = canvas()
    ImageDraw.Draw(inner).rounded_rectangle((2, 2, S - 3, S - 3), radius=3, fill=(255, 255, 255, 255))
    mp, ip = mask.load(), inner.load()
    bands = [mix(top, bottom, t) for t in (0.0, 0.33, 0.66, 1.0)]
    gx, gy = glow_center
    rx, ry = glow_r
    for y in range(S):
        for x in range(S):
            if mp[x, y][3] == 0:
                continue
            if ip[x, y][3] == 0:  # 1 px kenar bandi
                im.putpixel((x, y), rim_hi if (y <= 2 or x <= 2) and not (y >= S - 3 or x >= S - 3) else rim_lo)
                continue
            t = (y - 2) / (S - 5)
            bi = min(3, int(t * 4))
            c = bands[bi]
            if bi < 3 and int(((y - 1) / (S - 5)) * 4) != bi and ((x + y) & 1) == 0:
                c = bands[bi + 1]
            # isik elipsi
            e = ((x + 0.5 - gx) / rx) ** 2 + ((y + 0.5 - gy) / ry) ** 2
            if e < 0.82:
                c = mix(c, glow, 0.55)
            elif e < 1.0 and ((x + y) & 1) == 0:
                c = mix(c, glow, 0.55)
            # vinyet: koselere dogru hafif koyulasma
            v = math.hypot(x + 0.5 - 24, y + 0.5 - 24)
            if v > 27.5 or (v > 25.5 and ((x + y) & 1) == 0):
                c = mix(c, (0, 0, 0, 255), 0.22)
            im.putpixel((x, y), c)
    return im


def finish(base, emblem, fx, name):
    """Amblem konturlanir, zemine basilir; fx katmani (parilti/iz/rüzgar) KONTURSUZ en uste; 3x NEAREST kaydedilir."""
    base.alpha_composite(outline(emblem))
    if fx is not None:
        base.alpha_composite(fx)
    big = base.resize((S * K, S * K), Image.NEAREST)
    path = os.path.join(OUT, name)
    big.save(path)
    print("  ", os.path.relpath(path, ROOT))


# ============================================================== ELARA
LEATHER = (C('#c98a52'), C('#a0643a'), C('#6e3f22'))  # isik, orta, golge
WOOD = (C('#d9a46a'), C('#a8703e'), C('#6b4122'))
STEEL = (C('#eef2f8'), C('#b4bccb'), C('#6c7486'))


def elara_sivisma():
    """Q - Sivisma: kanatli elf cizmesi (hiz + hafiflik) + arkasinda ruzgar izleri (sivisip gecme)."""
    base = tile(C('#2a7078'), C('#0d2a30'), C('#3f9aa0'), C('#5fc0c4'), C('#0a1c20'))
    e = canvas()
    d = ImageDraw.Draw(e)
    L, M, Dk = LEATHER
    # cizme govdesi: kivrik topuk, one dogru egilen ust, ucu kalkik sivri burun
    d.polygon([(19, 13), (29, 13), (29, 29), (33, 30), (36, 31), (38, 30), (40, 28), (40, 32), (38, 35), (36, 37),
               (17, 37), (17, 29), (19, 25)], fill=M)
    d.line((19, 14, 19, 25), fill=L)                     # sol isik
    d.line((18, 27, 18, 34), fill=L)
    d.line((28, 15, 28, 28), fill=Dk)                    # on golge
    d.line((29, 30, 36, 32), fill=L)                     # ayak ustu isik
    put(e, [(39, 29), (38, 31)], L)                      # kalkik burun parlamasi
    d.rectangle((17, 36, 37, 37), fill=Dk)               # taban
    d.rectangle((17, 34, 21, 37), fill=Dk)               # topuk
    for y in range(16, 28, 3):                           # capraz bagcik
        put(e, [(24, y), (25, y + 1), (26, y + 1), (27, y)], L)
    # katlanmis konc agzi (tirtikli alt kenar) + yesil serit (Elara'nin kiyafeti)
    d.polygon([(17, 8), (31, 8), (30, 14), (18, 14)], fill=L)
    d.line((18, 12, 30, 12), fill=C('#4f9a4a'))
    for x in (19, 22, 25, 28):
        put(e, [(x, 14)], M)
    d.line((18, 8, 30, 8), fill=C('#f0c890'))
    # kanat: 4 tuy, konc agzinin arkasindan geriye/yukariya
    W = [C('#fbfdff'), C('#e4f5f8'), C('#bfe6ee'), C('#94d0dc')]
    feathers = [
        [(18, 11), (9, 2), (14, 2), (20, 9)],
        [(18, 14), (5, 6), (9, 4), (20, 11)],
        [(18, 17), (4, 11), (7, 8), (20, 14)],
        [(18, 20), (6, 16), (7, 13), (20, 17)],
    ]
    for poly, col in zip(feathers, W):
        d.polygon(poly, fill=col)
    WS = C('#6aa9b8')
    d.line((10, 3, 18, 10), fill=WS)
    d.line((7, 6, 18, 13), fill=WS)
    d.line((6, 11, 18, 16), fill=WS)
    put(e, [(11, 2), (12, 3), (6, 7)], C('#ffffff'))
    fx = canvas()
    fd = ImageDraw.Draw(fx)
    wind, wind_d = C('#b8f4f2'), C('#5fc0c4')
    fd.line((4, 26, 14, 26), fill=wind)
    fd.line((6, 30, 15, 30), fill=wind_d)
    fd.line((3, 34, 14, 34), fill=wind)
    put(fx, [(1, 26), (3, 30), (1, 38), (2, 38), (3, 38)], wind_d)
    sparkle(fx, 39, 9, C('#ffffff'), C('#b8f4f2'), 2)
    sparkle(fx, 43, 20, C('#ffffff'), C('#7fd6d8'), 1)
    finish(base, e, fx, "elara_sivisma_icon.png")


def elara_gercek_hasar():
    """E - Gercek Hasar: kalkani delip gecen, ucu kizil parlayan ok; kalkanda catlaklar ve kopan parcalar."""
    base = tile(C('#7a1c2c'), C('#2e0a14'), C('#a83040'), C('#d8606a'), C('#1c060c'))
    e = canvas()
    d = ImageDraw.Draw(e)
    SL, SM, SD = STEEL
    # kalkan (heater)
    d.polygon([(8, 15), (28, 15), (28, 28), (18, 40), (8, 28)], fill=SM)
    d.polygon([(10, 17), (26, 17), (26, 27), (18, 37), (10, 27)], fill=C('#8f98aa'))
    d.line((9, 16, 9, 28), fill=SL)
    d.line((9, 16, 27, 16), fill=SL)
    d.line((27, 17, 27, 28), fill=SD)
    d.line((27, 28, 18, 39), fill=SD)
    put(e, [(12, 19), (13, 19), (12, 20)], SL)
    # catlaklar: delinme noktasindan (18, 30) disari
    crack = C('#2a2e3a')
    for pts in (((18, 30), (15, 25), (12, 21)), ((18, 30), (22, 25), (24, 19)), ((18, 30), (13, 33))):
        d.line(pts, fill=crack)
    # kopan kalkan parcalari
    d.polygon([(30, 31), (33, 30), (32, 34)], fill=SM)
    d.polygon([(34, 36), (37, 35), (36, 38)], fill=SD)
    # ok: sol-alttan sag-uste (y = 48 - x hatti)
    d.line((6, 42, 34, 14), fill=WOOD[2], width=3)
    d.line((6, 41, 33, 14), fill=WOOD[1], width=1)
    d.line((7, 41, 34, 14), fill=WOOD[0], width=1)
    # tuyler
    d.polygon([(4, 40), (9, 39), (7, 44)], fill=C('#e8e2d0'))
    d.polygon([(8, 44), (9, 39), (12, 45)], fill=C('#c4403a'))
    # kizgin ok ucu
    d.polygon([(42, 6), (32, 11), (37, 16)], fill=C('#ff5a4a'))
    d.polygon([(41, 7), (35, 11), (37, 13)], fill=C('#ffd2b8'))
    fx = canvas()
    fd = ImageDraw.Draw(fx)
    # kalkanin ardinda kizil iz + delinme parlamasi
    fd.line((22, 27, 31, 18), fill=C('#ff8a6a'))
    for (x, y) in ((18, 30), (19, 29)):
        put(fx, [(x, y)], C('#fff4e0'))
    put(fx, [(16, 29), (20, 31), (18, 27), (17, 32)], C('#ff9a7a'))
    sparkle(fx, 40, 16, C('#ffffff'), C('#ff9a7a'), 2)
    finish(base, e, fx, "elara_gercek_hasar_icon.png")


def elara_cift_tetik():
    """R - Cift Tetik (ULTI): gerilmis yayda YAN YANA iki ok - her atis iki kez tetiklenir; uclarda altin parilti."""
    base = tile(C('#5a347e'), C('#1c0f2e'), C('#7f56a8'), C('#a88ad0'), C('#120920'))
    e = canvas()
    d = ImageDraw.Draw(e)
    WL, WM, WD = WOOD
    # yay: sagda, saga dogru bombeli
    d.arc((20, 4, 40, 44), start=-78, end=78, fill=WD, width=4)
    d.arc((21, 5, 39, 43), start=-74, end=74, fill=WM, width=2)
    d.arc((22, 6, 38, 42), start=-60, end=0, fill=WL, width=1)
    # kavrama (orta) sargisi
    d.rectangle((37, 21, 40, 27), fill=C('#4f9a4a'))
    put(e, [(38, 22), (38, 24)], C('#8fd07a'))
    # yay uclari (hafif kivrik)
    put(e, [(30, 4), (29, 3), (30, 44), (29, 45)], WD)
    # iki ok (paralel, hafif acili), cenlerde tuy
    for (y0, y1) in ((20, 16), (28, 32)):
        d.line((8, y0, 42, y1), fill=WD, width=1)
        d.line((8, y0 - 1, 42, y1 - 1), fill=WL, width=1)
        # tuyler
        d.polygon([(6, y0 - 3), (11, y0 - 1), (6, y0)], fill=C('#e8e2d0'))
        d.polygon([(6, y0 + 2), (11, y0), (6, y0)], fill=C('#c4403a'))
    # altin ok uclari
    d.polygon([(46, 15), (40, 13), (41, 18)], fill=C('#f2c440'))
    d.polygon([(46, 33), (41, 30), (40, 35)], fill=C('#f2c440'))
    put(e, [(44, 15), (44, 32)], C('#fff2b0'))
    fx = canvas()
    fd = ImageDraw.Draw(fx)
    # gergin kiris: yay uclarindan ok gezine (sola cekili)
    fd.line((30, 5, 9, 24), fill=C('#efe8d6'))
    fd.line((30, 43, 9, 24), fill=C('#efe8d6'))
    sparkle(fx, 44, 8, C('#ffffff'), C('#ffe08a'), 2)
    sparkle(fx, 44, 40, C('#ffffff'), C('#ffe08a'), 2)
    sparkle(fx, 16, 9, C('#ffffff'), C('#c8a8f0'), 1)
    finish(base, e, fx, "elara_cift_tetik_icon.png")


def elara_pasif():
    """Pasif - seviye basina saldiri hizi: egik, ok dolu deri sadak + yukari yesil cift ok (artis)."""
    base = tile(C('#3a7a3e'), C('#10301a'), C('#5aa050'), C('#88c878'), C('#0a1e10'))
    e = canvas()
    d = ImageDraw.Draw(e)
    L, M, Dk = LEATHER
    WL, WM, WD = WOOD
    # sadaktan cikan 3 ok (tuy uclari yukarida)
    for (bx, by, tx, ty, col) in ((20, 12, 16, 4, C('#e8e2d0')), (25, 13, 23, 3, C('#c4403a')), (29, 15, 30, 5, C('#f2c440'))):
        d.line((bx, by, tx, ty + 3), fill=WM)
        d.polygon([(tx - 2, ty), (tx + 2, ty), (tx + 2, ty + 5), (tx - 2, ty + 5)], fill=col)
        d.line((tx, ty + 1, tx, ty + 5), fill=mix(col, (0, 0, 0, 255), 0.35))
    # egik deri govde
    d.polygon([(19, 12), (32, 16), (23, 42), (10, 38)], fill=M)
    d.line((19, 13, 10, 37), fill=L)                     # sol isik
    d.line((18, 15, 11, 34), fill=L)
    d.line((31, 17, 22, 41), fill=Dk)                    # sag golge
    # agiz bandi + dip kapak
    d.polygon([(18, 10), (33, 15), (32, 18), (17, 13)], fill=Dk)
    d.line((18, 10, 33, 15), fill=L)
    d.polygon([(10, 36), (23, 40), (22, 43), (9, 39)], fill=Dk)
    # yesil kemer + altin toka
    d.polygon([(14, 24), (28, 28), (27, 31), (13, 27)], fill=C('#4f9a4a'))
    d.line((14, 24, 28, 28), fill=C('#8fd07a'))
    d.rectangle((19, 26, 21, 28), fill=C('#f2c440'))
    # dikis noktalari
    put(e, [(22, 19), (21, 22), (18, 32), (17, 35)], C('#e6b07a'))
    # yukari cift ok (artis) - sag alt
    G, GL, GD = C('#78d84a'), C('#c6f59a'), C('#3f8a28')
    for oy in (0, 8):
        d.polygon([(32, 36 - oy), (38, 30 - oy), (44, 36 - oy), (44, 39 - oy), (38, 33 - oy), (32, 39 - oy)], fill=G)
        d.line((33, 36 - oy, 38, 31 - oy), fill=GL)
        d.line((39, 32 - oy, 43, 36 - oy), fill=GD)
    fx = canvas()
    sparkle(fx, 40, 11, C('#ffffff'), C('#c6f59a'), 2)
    sparkle(fx, 6, 22, C('#ffffff'), C('#88c878'), 1)
    finish(base, e, fx, "elara_passive_icon.png")


# ============================================================== KORSAN
IRON = (C('#b4b8c6'), C('#3c3d48'), C('#1e1e26'))


def bomb(d, e, cx, cy, r):
    """Yuvarlak demir bomba: govde + sol-ust hilal parlama + sag-alt golge."""
    IL, IM, ID = IRON
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=IM)
    d.ellipse((cx - r + 3, cy - r + 3, cx + r, cy + r), fill=ID)
    d.ellipse((cx - r + 1, cy - r + 1, cx + r - 2, cy + r - 2), fill=IM)
    d.arc((cx - r + 2, cy - r + 2, cx + r - 3, cy + r - 3), start=190, end=250, fill=IL, width=1)
    put(e, [(cx - r + 4, cy - r + 5)], C('#d8dae4'))


def korsan_patlat():
    """Q - Patlat: el fuenyesi (T kollu tahta kutu, kablo) basilmis; arkada patlama."""
    base = tile(C('#a8461a'), C('#3c1408'), C('#e08a30'), C('#f0a860'), C('#240a04'))
    e = canvas()
    d = ImageDraw.Draw(e)
    # arkadaki patlama (emblem katmaninda, konturlanir)
    cx, cy = 32, 15
    pts = []
    for i in range(16):
        a = math.radians(i * 22.5 - 90)
        rr = 12 if i % 2 == 0 else 6.5
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    d.polygon(pts, fill=C('#f28a1e'))
    pts2 = []
    for i in range(16):
        a = math.radians(i * 22.5 - 90 + 11)
        rr = 8 if i % 2 == 0 else 4.5
        pts2.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    d.polygon(pts2, fill=C('#ffd24a'))
    d.ellipse((cx - 3, cy - 3, cx + 3, cy + 3), fill=C('#fff6d8'))
    # fuenye kutusu
    WL, WM, WD = WOOD
    d.rectangle((6, 28, 28, 42), fill=WM)
    d.line((6, 29, 28, 29), fill=WL)
    d.line((7, 29, 7, 41), fill=WL)
    d.line((27, 30, 27, 42), fill=WD)
    d.line((6, 35, 28, 35), fill=WD)                     # tahta derzi
    d.rectangle((6, 41, 28, 42), fill=WD)
    d.rectangle((10, 32, 24, 34), fill=C('#b8322a'))     # kirmizi ikaz bandi
    put(e, [(12, 33), (15, 33), (18, 33), (21, 33)], C('#f2e0c0'))
    # T kolu (basili: kutuya yakin)
    d.rectangle((16, 20, 18, 28), fill=IRON[0])
    d.line((16, 20, 16, 27), fill=C('#c8cad4'))
    d.rectangle((9, 18, 25, 21), fill=WD)
    d.line((9, 18, 25, 18), fill=WL)
    # kablo: kutudan saga
    d.line((28, 38, 34, 38), fill=C('#b8322a'), width=2)
    d.line((34, 38, 38, 34), fill=C('#b8322a'), width=2)
    d.line((38, 34, 43, 36), fill=C('#b8322a'), width=2)
    fx = canvas()
    sparkle(fx, 44, 29, C('#ffffff'), C('#ffd24a'), 2)
    put(fx, [(22, 7), (41, 4), (43, 22), (25, 22)], C('#ffd24a'))
    finish(base, e, fx, "korsan_patlat_icon.png")


def korsan_saatli_bomba():
    """E - Saatli Bomba: yanan fitilli bomba, uzerinde saat kadrani (zamanlayici)."""
    base = tile(C('#2e4a7e'), C('#0c1630'), C('#46699e'), C('#7a9ad0'), C('#070d1e'))
    e = canvas()
    d = ImageDraw.Draw(e)
    bomb(d, e, 22, 29, 14)
    # kapak
    d.rectangle((18, 12, 26, 16), fill=IRON[1])
    d.line((18, 12, 26, 12), fill=IRON[0])
    d.line((26, 13, 26, 16), fill=IRON[2])
    # fitil
    FUSE = C('#c8a068')
    d.line((23, 11, 25, 7), fill=FUSE, width=2)
    d.line((25, 7, 30, 5), fill=FUSE, width=2)
    put(e, [(24, 9), (27, 6)], C('#8a6a3a'))
    # saat kadrani
    d.ellipse((14, 21, 30, 37), fill=C('#d8a83c'))        # altin cerceve
    d.ellipse((15, 22, 29, 36), fill=C('#f4ecd4'))        # kadran
    d.arc((15, 22, 29, 36), start=200, end=260, fill=C('#ffffff'), width=1)
    for (x, y) in ((22, 23), (28, 29), (22, 35), (16, 29)):
        put(e, [(x, y)], C('#4a3a2a'))
    d.line((22, 29, 22, 24), fill=C('#2a2020'))           # yelkovan (12)
    d.line((22, 29, 26, 31), fill=C('#b8322a'))           # akrep
    put(e, [(22, 29)], C('#b8322a'))
    fx = canvas()
    # fitil ucundaki kivilcim
    sparkle(fx, 31, 4, C('#fff6d8'), C('#ffb03a'), 2)
    put(fx, [(34, 3), (33, 7), (35, 5), (29, 2)], C('#ff7a2a'))
    # tik-tak cizgileri
    fd = ImageDraw.Draw(fx)
    fd.line((38, 18, 41, 16), fill=C('#9fc0f0'))
    fd.line((39, 23, 43, 23), fill=C('#9fc0f0'))
    fd.line((38, 28, 41, 30), fill=C('#9fc0f0'))
    finish(base, e, fx, "korsan_saatli_bomba_icon.png")


def korsan_bombardiman():
    """R - Bombardiman: yukaridan capraz dusen gulleler (izli) + yerde hedef halkasi ve ilk carpma patlamasi."""
    ## Zemin gun batimi turuncusu: koyu demir gulleler koyu kirmizi zeminde kayboluyordu (ilk deneme).
    base = tile(C('#d0652e'), C('#4a140a'), C('#f0a050'), C('#f7b27a'), C('#1a0604'), glow_center=(26, 17), glow_r=(18, 13))
    e = canvas()
    d = ImageDraw.Draw(e)
    # hedef halkasi (zeminde, perspektif elips) - emblem: konturlanir
    d.ellipse((7, 33, 41, 45), fill=C('#e84a3a'))
    d.ellipse((9, 35, 39, 43), fill=(0, 0, 0, 0))
    # halkanin icini oyduk: ImageDraw saydam boyar -> tekrar zemine birakmak icin maske ile sil
    px = e.load()
    for y in range(35, 44):
        for x in range(9, 40):
            if ((x + 0.5 - 24) / 15.0) ** 2 + ((y + 0.5 - 39) / 4.0) ** 2 < 1.0:
                px[x, y] = (0, 0, 0, 0)
    # gulleler
    for (cx, cy, r) in ((13, 12, 4), (27, 7, 4), (35, 20, 4)):
        bomb(d, e, cx, cy, r)
    fx = canvas()
    fd = ImageDraw.Draw(fx)
    trail, trail_d = C('#ffb07a'), C('#d8704a')
    for (cx, cy) in ((13, 12), (27, 7), (35, 20)):
        fd.line((cx + 3, cy - 4, cx + 7, cy - 9), fill=trail)
        fd.line((cx + 5, cy - 3, cx + 8, cy - 7), fill=trail_d)
    # halka ici artilar + ilk carpma patlamasi
    for (x, y) in ((24, 36), (24, 42), (16, 39), (32, 39)):
        put(fx, [(x, y)], C('#ffe0c8'))
    for (dx, dy, col) in ((0, 0, C('#fff6d8')), (-1, 0, C('#ffd24a')), (1, 0, C('#ffd24a')), (0, -1, C('#ffd24a')),
                          (0, -2, C('#f28a1e')), (-2, 0, C('#f28a1e')), (2, 0, C('#f28a1e')), (-1, -1, C('#f28a1e')),
                          (1, -1, C('#f28a1e')), (0, -3, C('#e05a1e')), (-3, 0, C('#e05a1e')), (3, 0, C('#e05a1e'))):
        put(fx, [(24 + dx, 39 + dy)], col)
    sparkle(fx, 42, 9, C('#ffffff'), C('#ffb07a'), 1)
    finish(base, e, fx, "korsan_bombardiman_icon.png")


def korsan_pasif():
    """Pasif - oldurmelerde altin sansi: kafatasi damgali korsan dublonu (+ arkasinda ikinci para)."""
    base = tile(C('#1e6a72'), C('#082628'), C('#2e8a88'), C('#5ab8b0'), C('#041416'))
    e = canvas()
    d = ImageDraw.Draw(e)
    RIM, FACE, IN, HI, ENG = C('#a86c14'), C('#f0bc3c'), C('#d49a28'), C('#fff0a8'), C('#8a5a10')
    # arkadaki kucuk para
    d.ellipse((30, 30, 44, 44), fill=RIM)
    d.ellipse((31, 31, 43, 43), fill=IN)
    d.arc((31, 31, 43, 43), start=200, end=260, fill=HI, width=1)
    # ana dublon
    d.ellipse((7, 7, 37, 37), fill=RIM)
    d.ellipse((8, 8, 36, 36), fill=FACE)
    d.ellipse((11, 11, 33, 33), fill=IN)
    d.ellipse((12, 12, 32, 32), fill=FACE)
    d.arc((8, 8, 36, 36), start=195, end=265, fill=HI, width=1)
    # capraz kemikler
    d.line((14, 28, 30, 16), fill=ENG, width=2)
    d.line((14, 16, 30, 28), fill=ENG, width=2)
    for (x, y) in ((13, 28), (13, 15), (31, 15), (31, 28)):
        d.rectangle((x - 1, y - 1, x + 1, y + 1), fill=ENG)
    # kafatasi
    d.ellipse((16, 13, 28, 24), fill=C('#fff4d0'))
    d.rectangle((18, 23, 26, 27), fill=C('#fff4d0'))
    d.rectangle((18, 17, 20, 19), fill=ENG)               # gozler
    d.rectangle((24, 17, 26, 19), fill=ENG)
    put(e, [(22, 21)], ENG)                               # burun
    d.line((19, 26, 25, 26), fill=ENG)                    # disler
    put(e, [(20, 25), (22, 25), (24, 25)], ENG)
    put(e, [(18, 14), (19, 14)], C('#ffffff'))
    fx = canvas()
    sparkle(fx, 36, 8, C('#ffffff'), C('#fff0a8'), 2)
    sparkle(fx, 6, 38, C('#ffffff'), C('#ffe08a'), 1)
    sparkle(fx, 42, 27, C('#ffffff'), C('#ffe08a'), 1)
    finish(base, e, fx, "korsan_passive_icon.png")


if __name__ == "__main__":
    print("Elara + Korsan ikonlari:")
    elara_sivisma()
    elara_gercek_hasar()
    elara_cift_tetik()
    elara_pasif()
    korsan_patlat()
    korsan_saatli_bomba()
    korsan_bombardiman()
    korsan_pasif()
