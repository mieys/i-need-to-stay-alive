#!/usr/bin/env python3
"""Ruhani yetenek (8) + Vampir Cocuk (Q/E/R/pasif) ikonlari -> assets/skills/*.png

Kullanim (repo kokunden):
    python tools/gen_spirit_vampir_icons.py      (sonra Godot'ta `--headless --import`)

Kullanici istegi (2026-09-25): "tum ruhani buyulerin ikonlarini ve vampir cocugun skill ikonlarini yeniden pixel tarzda
48x48 tasarlamani istiyorum". Eskiden ruhani ikonlar kalin halkali yuvarlak madalyonlardi (tools/gen_spirit_assets.py,
sade amblemler), Vampir'in ikonlari 32x32'den 4x buyutulmustu (iri pikselli, bulanik gorunen koyu daireler -
tools/gen_vampir_assets.py). Bu iki eski ureticinin ikon kismi SILINDI (tekrar calistirilirsa bu ikonlari ezmesin).

Kurallar (bkz. hafiza: 48x48 piksel yogunlugu; tools/gen_elara_korsan_icons.py ile AYNI dil ve AYNI yardimcilar):
  - 48x48 sanat izgarasi, amblemde 1 px kontur + 1 px parlama, iri bloklar YOK; 3x NEAREST -> 144x144 PNG.
  - KARE karo: koyu kontur, 4 bantli dikey degrade (dither gecisli), amblemin arkasinda yumusak isik, koselerde vinyet;
    her yetenegin zemin rengi farkli.
  - Ruhani ikonlar karakter yeteneklerinden bir bakista ayrilsin diye hepsinde AYNI soluk mor "ruhani" kenar + dort
    kosede kucuk run elmaslari var (HUD'daki mor ruhani slotuyla ayni aile). Vampir ikonlari karakter ikonu: normal kenar.
"""
import math
import os
import sys

from PIL import ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_elara_korsan_icons import C, canvas, finish, mix, put, sparkle, tile  # noqa: E402

SPIRIT_RIM_HI = C('#efe2ff')
SPIRIT_RIM_LO = C('#3b2458')
RUNE = C('#d9c2ff')
RUNE_CORE = C('#ffffff')

GOLD = (C('#fff1a8'), C('#f2c440'), C('#c88a1c'), C('#7e4c0c'))   # parlama, acik, orta, golge
STEEL = (C('#f4f7fb'), C('#c3cbd8'), C('#8a93a6'), C('#4c5366'))
BLOOD = (C('#ff8a8a'), C('#e0283a'), C('#a8101e'), C('#5e0610'))
WOODC = (C('#d9a46a'), C('#a8703e'), C('#6b4122'))


def spirit_tile(top, bottom, glow, glow_center=(24, 23), glow_r=(15, 14)):
    im = tile(top, bottom, glow, SPIRIT_RIM_HI, SPIRIT_RIM_LO, glow_center, glow_r)
    for (x, y) in ((4, 4), (43, 4), (4, 43), (43, 43)):
        put(im, [(x, y - 1), (x - 1, y), (x + 1, y), (x, y + 1)], RUNE)
        put(im, [(x, y)], RUNE_CORE)
    return im


def coin(d, e, cx, cy, rx=5, ry=2, thick=2):
    """Yandan gorunen altin para (elips yuz + kalinlik)."""
    L, A, M, D = GOLD
    d.ellipse((cx - rx, cy - ry + thick, cx + rx, cy + ry + thick), fill=D)
    d.rectangle((cx - rx, cy, cx + rx, cy + thick), fill=M)
    d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=A)
    d.line((cx - rx + 2, cy - ry, cx + rx - 2, cy - ry), fill=L)
    put(e, [(cx - rx + 1, cy)], L)


def front_coin(d, e, cx, cy, r=5):
    """Onden gorunen altin para: rim + ic halka + ortada parilti."""
    L, A, M, D = GOLD
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=M)
    d.ellipse((cx - r + 1, cy - r + 1, cx + r - 1, cy + r - 1), fill=A)
    d.arc((cx - r + 2, cy - r + 2, cx + r - 2, cy + r - 2), 200, 340, fill=L)
    d.arc((cx - r + 2, cy - r + 2, cx + r - 2, cy + r - 2), 20, 160, fill=M)
    put(e, [(cx, cy - 1), (cx, cy), (cx, cy + 1), (cx - 1, cy), (cx + 1, cy)], D)
    put(e, [(cx - r + 2, cy - 2)], L)


def heart(d, e, cx, cy, s, cols):
    """Piksel kalp: iki daire + ucgen. cols = (parlama, acik, orta, golge)."""
    L, A, M, D = cols
    r = s
    d.ellipse((cx - 2 * r, cy - r, cx, cy + r), fill=A)
    d.ellipse((cx, cy - r, cx + 2 * r, cy + r), fill=A)
    d.polygon([(cx - 2 * r, cy + 1), (cx + 2 * r, cy + 1), (cx, cy + 2 * r + 2)], fill=A)
    # sag/alt golge
    d.line((cx + 2 * r, cy, cx + 1, cy + 2 * r + 1), fill=M)
    d.line((cx + 2 * r - 1, cy - 1, cx + 2 * r - 1, cy + 1), fill=M)
    d.line((cx + 1, cy + 2 * r + 1, cx, cy + 2 * r + 2), fill=D)
    # sol ust parlama
    d.arc((cx - 2 * r + 1, cy - r + 1, cx - 1, cy + r - 1), 190, 260, fill=L)
    put(e, [(cx - 2 * r + 2, cy - 1), (cx - 2 * r + 3, cy - 2)], L)


def blood_drop(d, e, cx, cy, h=9, w=4):
    """Parlak kan damlasi: sivri tepe, yuvarlak alt, sol-ust parlama."""
    L, A, M, D = BLOOD
    d.polygon([(cx, cy - h), (cx + w, cy - 1), (cx - w, cy - 1)], fill=A)
    d.ellipse((cx - w, cy - w, cx + w, cy + w), fill=A)
    d.arc((cx - w, cy - w, cx + w, cy + w), 0, 110, fill=M)
    d.line((cx + 1, cy - h + 2, cx + w - 1, cy - 2), fill=M)
    put(e, [(cx - 2, cy - 1), (cx - 2, cy), (cx - 1, cy - 3)], L)
    put(e, [(cx, cy + w)], D)


def bat(d, e, cx, cy, span, up, body, mem, eye=C('#ff3040'), bone=None):
    """Onden yarasa: iki kanat (ucu yukari/asagi), govde, kulaklar, kirmizi gozler."""
    tip = -span // 2 if up else span // 3
    for sx in (-1, 1):
        def X(dx):
            return cx + sx * dx
        pts = [(X(1), cy - 1), (X(span // 3), cy - 2 + tip // 2), (X(span), cy - 1 + tip), (X(span - 1), cy + 2 + tip // 2),
               (X(span * 2 // 3), cy + 2), (X(span // 2), cy + 1), (X(span // 3), cy + 3), (X(1), cy + 2)]
        d.polygon(pts, fill=mem)
        if bone is not None:
            d.line((X(1), cy - 1, X(span // 3), cy - 2 + tip // 2, X(span), cy - 1 + tip), fill=bone)
    d.ellipse((cx - 2, cy - 2, cx + 2, cy + 3), fill=body)
    put(e, [(cx - 2, cy - 3), (cx + 2, cy - 3)], body)
    put(e, [(cx - 1, cy - 1), (cx + 1, cy - 1)], eye)


MINI_BAT_UP = [
    "m.........m",
    "hm..b.b..mh",
    "mmh.bbb.hmm",
    "mmmmbebmmmm",
    ".mmmbbbmmm.",
    "..m.bbb.m..",
    ".....b.....",
]
MINI_BAT_DOWN = [
    "....b.b....",
    "....bbb....",
    "hhhmbebmhhh",
    "mmmmbbbmmmm",
    "mm.mbbbm.mm",
    "m...mbm...m",
    ".....b.....",
]


def mini_bat(e, cx, cy, up, mem, mem_hi, body, eye):
    """11x7 piksel mini yarasa (desen), merkezi (cx, cy)."""
    rows = MINI_BAT_UP if up else MINI_BAT_DOWN
    pal = {'m': mem, 'h': mem_hi, 'b': body, 'e': eye}
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in pal:
                put(e, [(cx - 5 + x, cy - 3 + y)], pal[ch])


# ============================================================== RUHANİ YETENEKLER
def spirit_para():
    """PASİF - Para: agzi acik deri kese + tasan altinlar + havada donen para (her 10 sn altin, dukkan indirimi)."""
    base = spirit_tile(C('#7c5212'), C('#2a1604'), C('#c08a24'))
    e = canvas()
    d = ImageDraw.Draw(e)
    L, M, Dk = C('#c98a52'), C('#9a5e32'), C('#62371a')
    # kese govdesi (tombul, alti genis)
    d.ellipse((5, 18, 31, 42), fill=M)
    d.polygon([(12, 20), (24, 20), (21, 15), (15, 15)], fill=M)
    d.arc((6, 19, 30, 41), 110, 200, fill=L)
    d.arc((6, 19, 30, 41), 300, 60, fill=Dk)
    d.arc((6, 19, 30, 41), 60, 110, fill=Dk)
    put(e, [(8, 27), (8, 28), (9, 25), (9, 24)], L)
    for (x0, y0, x1, y1) in ((15, 21, 13, 27), (21, 21, 23, 27)):   # buzgu kirisiklari
        d.line((x0, y0, x1, y1), fill=Dk)
    # buzgu ipi + sarkan dugum
    d.line((14, 15, 22, 15), fill=C('#e8c070'))
    put(e, [(23, 16), (24, 17), (24, 18), (23, 19)], C('#e8c070'))
    put(e, [(24, 19), (22, 16)], C('#b8883a'))
    # ustte uc dilimli firfir (kesenin agzi)
    d.polygon([(12, 14), (24, 14), (27, 8), (23, 10), (18, 7), (13, 10), (9, 8)], fill=L)
    put(e, [(9, 8), (18, 7), (27, 8)], C('#e8b884'))
    d.line((13, 13, 23, 13), fill=M)
    # kesenin ustunde altin simgesi (dikis)
    front_coin(d, e, 18, 31, 4)
    # sag tarafta para yigini
    for i, y in enumerate((38, 35, 32, 29)):
        coin(d, e, 34 + (1 if i % 2 else 0), y, 6, 2, 2)
    # havadaki para (onden) - kesenin agzindan firlamis
    front_coin(d, e, 33, 13, 5)
    fx = canvas()
    sparkle(fx, 40, 8, C('#ffffff'), C('#fff0a8'), 2)
    sparkle(fx, 26, 6, C('#ffffff'), C('#ffe08a'), 1)
    put(fx, [(28, 9), (29, 11), (30, 17)], C('#ffe08a'))
    finish(base, e, fx, "spirit_para_icon.png")


def spirit_can():
    """Can: takima yayilan iyilesme - artili buyuk kalp, arkasinda kalkan halesi, yukselen minik kalpler/artilar."""
    base = spirit_tile(C('#1f7048'), C('#07261a'), C('#40b070'))
    e = canvas()
    d = ImageDraw.Draw(e)
    # arkada kalkan (%15 kalkan): ince mavi hale-kalkan
    SH = (C('#dff4ff'), C('#8cc8ff'), C('#4a8ad8'), C('#23508c'))
    d.polygon([(9, 9), (39, 9), (39, 24), (24, 42), (9, 24)], fill=SH[2])
    d.polygon([(11, 11), (37, 11), (37, 23), (24, 39), (11, 23)], fill=C('#2f6ab4'))
    d.line((10, 10, 38, 10), fill=SH[1])
    d.line((10, 10, 10, 24), fill=SH[1])
    # kalp (+%8 can)
    heart(d, e, 24, 21, 6, (C('#ffd0d8'), C('#f0405a'), C('#c02040'), C('#780c20')))
    # beyaz arti
    d.rectangle((22, 18, 26, 29), fill=C('#ffffff'))
    d.rectangle((19, 21, 29, 25), fill=C('#ffffff'))
    d.line((27, 21, 29, 21), fill=C('#ffd8e0'))
    put(e, [(26, 29), (29, 25)], C('#ffd8e0'))
    fx = canvas()
    # yukselen minik kalpler (takim arkadaslari) + artilar
    for (x, y) in ((6, 12), (40, 14)):
        put(fx, [(x, y), (x + 2, y), (x - 1, y + 1), (x, y + 1), (x + 1, y + 1), (x + 2, y + 1), (x + 3, y + 1),
                 (x, y + 2), (x + 1, y + 2), (x + 2, y + 2), (x + 1, y + 3)], C('#ff90a8'))
    for (x, y) in ((8, 33), (41, 30), (34, 5)):
        put(fx, [(x, y - 1), (x - 1, y), (x, y), (x + 1, y), (x, y + 1)], C('#c8ffd8'))
    sparkle(fx, 13, 5, C('#ffffff'), C('#c8ffe0'), 2)
    finish(base, e, fx, "spirit_can_icon.png")


def spirit_adc():
    """Adc: art arda ucan uc kizgin ok (saldiri hizi + kalkan delme), onde gidenin ucunda kan damlasi (can emme)."""
    base = spirit_tile(C('#8a2c12'), C('#2a0804'), C('#d05a24'))
    e = canvas()
    d = ImageDraw.Draw(e)
    SL, SA, SM, SD = STEEL
    shaft, shaft_d = C('#c08850'), C('#7a4c24')
    fl, fl_d = C('#ffd070'), C('#e0782a')

    def arrow(x0, y0, length):
        # 45 derece sag-yukari
        x1, y1 = x0 + length, y0 - length
        d.line((x0, y0, x1, y1), fill=shaft)
        d.line((x0 + 1, y0, x1, y1 + 1), fill=shaft_d)
        # uc (celik ok ucu)
        d.polygon([(x1 + 3, y1 - 3), (x1 - 3, y1 - 1), (x1 + 1, y1 + 3)], fill=SA)
        put(e, [(x1 + 2, y1 - 2), (x1, y1 - 1)], SL)
        put(e, [(x1, y1 + 2)], SM)
        # tuyler
        d.polygon([(x0, y0), (x0 - 4, y0 - 1), (x0 - 2, y0 - 3), (x0 + 2, y0 - 2)], fill=fl)
        d.polygon([(x0, y0), (x0 + 1, y0 + 4), (x0 + 3, y0 + 2), (x0 + 2, y0 - 2)], fill=fl_d)

    # uc paralel ok (dik aralik ~8 px), ortadaki onde - art arda atislar
    arrow(7, 29, 14)
    arrow(13, 38, 19)
    arrow(22, 42, 14)
    # onde gidenin ucunda kan damlasi (can emme)
    blood_drop(d, e, 40, 14, 6, 3)
    fx = canvas()
    fd = ImageDraw.Draw(fx)
    # hiz izleri (turuncu) - her okun tuylerinin arkasinda
    for (x, y) in ((7, 29), (13, 38), (22, 42)):
        fd.line((x - 7, y + 7, x - 4, y + 4), fill=C('#ff9a40'))
        put(fx, [(x - 9, y + 9)], C('#ffc070'))
    sparkle(fx, 43, 7, C('#ffffff'), C('#ffd070'), 2)
    sparkle(fx, 33, 42, C('#ffffff'), C('#ff9a60'), 1)
    finish(base, e, fx, "spirit_adc_icon.png")


def spirit_tank():
    """Tank: dikenli kule kalkani; ustune carpan oklar geri sekiyor (hasar yansitma) - altin kabara (kalkan yenilenmesi)."""
    base = spirit_tile(C('#2c4c7c'), C('#0a1424'), C('#5078b0'))
    e = canvas()
    d = ImageDraw.Draw(e)
    SL, SA, SM, SD = STEEL
    L, A, M, D = GOLD
    # kenar dikenleri (yansitma)
    for (x, y, dx, dy) in ((10, 12, -4, -3), (38, 12, 4, -3), (8, 22, -5, 0), (40, 22, 5, 0), (12, 32, -4, 3), (36, 32, 4, 3)):
        d.polygon([(x, y - 2), (x, y + 2), (x + dx, y + dy)], fill=SM)
        put(e, [(x + dx, y + dy)], SL)
    # kalkan govdesi
    d.polygon([(11, 8), (37, 8), (38, 12), (38, 25), (24, 42), (10, 25), (10, 12)], fill=SA)
    d.polygon([(13, 10), (35, 10), (36, 13), (36, 24), (24, 39), (12, 24), (12, 13)], fill=C('#6f7f9c'))
    d.line((11, 9, 11, 25), fill=SL)
    d.line((12, 8, 36, 8), fill=SL)
    d.line((37, 12, 37, 25), fill=SD)
    d.line((37, 25, 24, 41), fill=SD)
    # altin haç seridi + kabara
    d.rectangle((22, 11, 26, 36), fill=M)
    d.rectangle((14, 19, 34, 23), fill=M)
    d.line((22, 11, 22, 36), fill=A)
    d.line((14, 19, 34, 19), fill=A)
    d.ellipse((20, 17, 28, 25), fill=A)
    d.ellipse((22, 19, 26, 23), fill=L)
    put(e, [(27, 24), (28, 22)], D)
    fx = canvas()
    fd = ImageDraw.Draw(fx)
    # geri seken oklar (kirik, egri iz)
    for (x0, y0, x1, y1) in ((2, 6, 8, 12), (46, 8, 40, 13)):
        fd.line((x0, y0, x1, y1), fill=C('#ffe08a'))
    put(fx, [(1, 5), (2, 5), (1, 6), (46, 7), (45, 7), (46, 8)], C('#ffffff'))
    # carpma kivilcimlari
    sparkle(fx, 9, 13, C('#ffffff'), C('#ffe08a'), 1)
    sparkle(fx, 39, 14, C('#ffffff'), C('#ffe08a'), 1)
    sparkle(fx, 24, 45, C('#ffffff'), C('#9cc8ff'), 1)
    finish(base, e, fx, "spirit_tank_icon.png")


def spirit_taktik():
    """Taktiksel: soldaki portaldan firlayip ileri isinlanan kalin ok; arkada kesik kesik iz (isinlanma + hiz)."""
    base = spirit_tile(C('#16687a'), C('#04202a'), C('#34b4c4'), glow_center=(28, 24))
    e = canvas()
    d = ImageDraw.Draw(e)
    # giris portali (sol, dikey elips)
    PL, PA, PM = C('#c8fcff'), C('#5ed8e8'), C('#1c8ca0')
    d.ellipse((4, 12, 14, 36), fill=PM)
    d.ellipse((6, 15, 12, 33), fill=C('#062a34'))
    d.arc((4, 12, 14, 36), 100, 260, fill=PL)
    d.arc((5, 13, 13, 35), 280, 80, fill=PA)
    # cift chevron ok (isinlanma ileri)
    AL, AA, AM = C('#f2ffff'), C('#a8f0f8'), C('#48b8cc')
    for ox in (0, 11):
        d.polygon([(16 + ox, 12), (24 + ox, 12), (34 + ox, 24), (24 + ox, 36), (16 + ox, 36), (26 + ox, 24)], fill=AA)
        d.line((17 + ox, 12, 27 + ox, 24), fill=AL)
        d.line((27 + ox, 24, 17 + ox, 35), fill=AM)
        d.line((25 + ox, 12, 34 + ox, 23), fill=AL)
    fx = canvas()
    fd = ImageDraw.Draw(fx)
    # portaldan cikan kesik iz
    for x in (15, 19):
        fd.line((x, 23, x + 1, 23), fill=C('#9ef0ff'))
        fd.line((x, 25, x + 1, 25), fill=C('#5ed8e8'))
    sparkle(fx, 42, 9, C('#ffffff'), C('#b8fcff'), 2)
    sparkle(fx, 44, 39, C('#ffffff'), C('#7fe0ea'), 1)
    sparkle(fx, 9, 7, C('#ffffff'), C('#7fe0ea'), 1)
    put(fx, [(3, 40), (6, 42), (10, 41)], C('#7fe0ea'))
    finish(base, e, fx, "spirit_taktik_icon.png")


def spirit_dukkan():
    """Dukkan: cizgili tenteli seyyar satici tezgahi, altinda donen mor isinlanma halkasi (3 sn odaklan -> satıcıya git)."""
    base = spirit_tile(C('#5a2c7c'), C('#1a0a2a'), C('#9c5ccc'), glow_center=(24, 26))
    e = canvas()
    d = ImageDraw.Draw(e)
    WL, WM, WD = WOODC
    # isinlanma halkasi (arkada, tezgahin altinda)
    d.ellipse((5, 33, 43, 44), fill=C('#7a3cb0'))
    d.ellipse((9, 35, 39, 42), fill=C('#2a1044'))
    d.arc((5, 33, 43, 44), 180, 360, fill=C('#e0b0ff'))
    # tezgah govdesi (tahta)
    d.rectangle((11, 24, 37, 37), fill=WM)
    d.line((11, 24, 37, 24), fill=WL)
    for x in (18, 25, 32):
        d.line((x, 25, x, 37), fill=WD)
    d.line((11, 30, 37, 30), fill=WD)
    # direkler
    d.rectangle((11, 12, 12, 24), fill=WD)
    d.rectangle((36, 12, 37, 24), fill=WD)
    # tente: kirmizi-krem seritler, dalgali alt kenar
    RED, CREAM = C('#d8403a'), C('#fbe6c0')
    d.polygon([(7, 13), (41, 13), (38, 6), (10, 6)], fill=CREAM)
    for i, x in enumerate(range(7, 41, 6)):
        d.polygon([(x, 13), (x + 3, 13), (x + 3 + (1 if x > 24 else 0), 6), (x + 1 + (1 if x > 24 else 0), 6)], fill=RED)
    for x in range(8, 41, 4):
        d.rectangle((x, 13, x + 2, 14), fill=RED if (x // 4) % 2 else CREAM)
    d.line((10, 6, 38, 6), fill=C('#fff4dc'))
    # tezgahtaki mallar: kese + iksir + para
    d.ellipse((14, 18, 20, 24), fill=C('#b07a44'))
    put(e, [(16, 17), (17, 17), (18, 17)], C('#e0b070'))
    d.rectangle((23, 18, 25, 23), fill=C('#5ec0ff'))
    put(e, [(24, 17), (24, 16)], C('#d8f0ff'))
    put(e, [(23, 19)], C('#d8f0ff'))
    front_coin(d, e, 31, 21, 3)
    fx = canvas()
    for (x, y) in ((6, 29), (42, 27), (24, 45)):
        put(fx, [(x, y - 1), (x - 1, y), (x, y), (x + 1, y), (x, y + 1)], C('#e8c8ff'))
    sparkle(fx, 42, 5, C('#ffffff'), C('#e0b0ff'), 2)
    sparkle(fx, 5, 20, C('#ffffff'), C('#c890f0'), 1)
    finish(base, e, fx, "spirit_dukkan_icon.png")


def spirit_savas_sevki():
    """PASİF - Savas Sevki: asagi saplanmis kizgin kilic, dibinde kafatasi (infaz), yukari savrulan kor ve 5'li centik
    (her oldurme bir yuk)."""
    base = spirit_tile(C('#6e1612'), C('#1e0404'), C('#b8342a'), glow_center=(24, 20))
    e = canvas()
    d = ImageDraw.Draw(e)
    SL, SA, SM, SD = STEEL
    L, A, M, D = GOLD
    # kafatasi (altta)
    BONE, BONE_D = C('#f4ecd8'), C('#b8a888')
    d.ellipse((16, 30, 32, 42), fill=BONE)
    d.rectangle((19, 40, 29, 44), fill=BONE)
    d.ellipse((18, 34, 22, 38), fill=C('#2a0a08'))
    d.ellipse((26, 34, 30, 38), fill=C('#2a0a08'))
    put(e, [(19, 35), (27, 35)], C('#ff5a3a'))
    put(e, [(24, 39)], C('#2a0a08'))
    for x in (21, 23, 25, 27):
        put(e, [(x, 43)], BONE_D)
    d.line((31, 33, 31, 39), fill=BONE_D)
    # kilic (asagi dogru, ucu kafatasinin ustunde)
    d.polygon([(22, 12), (26, 12), (26, 29), (24, 33), (22, 29)], fill=SA)
    d.line((23, 12, 23, 29), fill=SL)
    d.line((25, 13, 25, 29), fill=SM)
    put(e, [(24, 32)], SL)
    # balcak + kabza + topuz
    d.rectangle((15, 9, 33, 11), fill=A)
    d.line((15, 9, 33, 9), fill=L)
    put(e, [(15, 11), (33, 11)], D)
    d.rectangle((22, 3, 26, 8), fill=C('#6a2a18'))
    for y in (4, 6):
        d.line((22, y, 26, y), fill=C('#9a4a2a'))
    d.ellipse((21, 0, 27, 4), fill=A)
    put(e, [(23, 1)], L)
    fx = canvas()
    # yukari savrulan korlar
    for (x, y, c) in ((12, 20, '#ffb040'), (35, 17, '#ff7a30'), (9, 28, '#ff7a30'), (38, 26, '#ffd060'), (14, 12, '#ffd060')):
        put(fx, [(x, y), (x, y - 1)], C(c))
    # 5'li centik (yukler)
    for i in range(4):
        put(fx, [(5 + i * 2, y) for y in range(39, 44)], C('#ffd070'))
    put(fx, [(4, 43), (6, 42), (8, 41), (10, 40), (12, 39)], C('#fff4c8'))
    sparkle(fx, 40, 6, C('#ffffff'), C('#ffc060'), 2)
    finish(base, e, fx, "spirit_savas_sevki_icon.png")


def spirit_kalkan_bagi():
    """Kalkan Bagi: altin zincirle birbirine bagli iki kalkan (hasar/kalkan %50-%50 paylasilir), aradan akan isik."""
    base = spirit_tile(C('#1e4a8a'), C('#081a34'), C('#4a8ad8'))
    e = canvas()
    d = ImageDraw.Draw(e)
    SH = (C('#e4f4ff'), C('#8cc8ff'), C('#3a78d0'), C('#1c3e7a'))
    L, A, M, D = GOLD

    def shield(x0, flip):
        # kucuk heater kalkan (13x20)
        pts = [(x0, 13), (x0 + 12, 13), (x0 + 12, 24), (x0 + 6, 33), (x0, 24)]
        d.polygon(pts, fill=M)
        d.polygon([(x0 + 1, 14), (x0 + 11, 14), (x0 + 11, 23), (x0 + 6, 31), (x0 + 1, 23)], fill=SH[2])
        d.line((x0 + 2, 15, x0 + 2, 23), fill=SH[1])
        d.line((x0 + 2, 15, x0 + 10, 15), fill=SH[1])
        d.line((x0 + 10, 16, x0 + 10, 23), fill=SH[3])
        # kalkan arması: kucuk kalp (bag)
        hx = x0 + 6
        put(e, [(hx - 2, 19), (hx - 1, 19), (hx + 1, 19), (hx + 2, 19), (hx - 2, 20), (hx - 1, 20), (hx, 20), (hx + 1, 20),
                (hx + 2, 20), (hx - 1, 21), (hx, 21), (hx + 1, 21), (hx, 22)], C('#fff0f4'))
        put(e, [(x0 + 1, 13) if not flip else (x0 + 11, 13)], L)

    shield(4, False)
    shield(31, True)
    # zincir: kalkanlarin arasinda 3 halka (dikey/yatay donusumlu)
    for i, x in enumerate((17, 22, 27)):
        if i % 2 == 0:
            d.ellipse((x - 1, 20, x + 4, 26), outline=A)
            put(e, [(x, 21)], L)
        else:
            d.ellipse((x - 1, 21, x + 4, 25), outline=M)
    fx = canvas()
    fd = ImageDraw.Draw(fx)
    # bagdan akan isik (iki yone)
    fd.line((12, 36, 36, 36), fill=C('#8cc8ff'))
    put(fx, [(13, 37), (35, 37), (24, 38)], C('#cfe8ff'))
    put(fx, [(10, 35), (38, 35)], C('#ffffff'))
    sparkle(fx, 24, 12, C('#ffffff'), C('#ffe08a'), 2)
    sparkle(fx, 6, 41, C('#ffffff'), C('#9cc8ff'), 1)
    sparkle(fx, 42, 41, C('#ffffff'), C('#9cc8ff'), 1)
    finish(base, e, fx, "spirit_kalkan_bagi_icon.png")


# ============================================================== VAMPİR ÇOCUK
BAT_BODY = C('#2a1426')
BAT_MEM = C('#4a1e3c')
BAT_MEM_L = C('#7a3a60')
BAT_BONE = C('#1a0a16')


def vampir_kan_emme():
    """Q - Kan Emme: uc yonden (en yakin 3 dusman) kivrilarak gelen kan akislari ortadaki parlak kan kuresinde birlesiyor;
    ustte vampir disleri."""
    base = tile(C('#6e0c1e'), C('#1a0206'), C('#b81c34'), C('#ff7a8a'), C('#14020a'), glow_center=(24, 27))
    e = canvas()
    d = ImageDraw.Draw(e)
    L, A, M, D = BLOOD
    # kan akislari: sol-ust, sag-ust, alt'tan kureye kivrilan seritler
    def wavy(x0, y0, x1, y1, amp, n=24):
        pts = []
        for i in range(n + 1):
            t = i / n
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            nx, ny = -(y1 - y0), (x1 - x0)
            ln = math.hypot(nx, ny) or 1.0
            w = math.sin(t * math.pi * 2.0) * amp * (1.0 - t)
            pts.append((round(x + nx / ln * w), round(y + ny / ln * w)))
        return pts
    for (x0, y0, x1, y1) in ((2, 12, 18, 26), (46, 12, 30, 26), (6, 46, 20, 35)):
        pts = wavy(x0, y0, x1, y1, 2.5)
        d.line(pts, fill=M, width=3)
        d.line(pts, fill=A)
    # kan kuresi
    d.ellipse((15, 20, 33, 38), fill=M)
    d.ellipse((16, 21, 32, 37), fill=A)
    d.arc((16, 21, 32, 37), 20, 150, fill=M)
    d.ellipse((19, 24, 24, 29), fill=C('#ff5a6a'))
    put(e, [(20, 25), (21, 25), (20, 26)], L)
    put(e, [(29, 33), (30, 31)], D)
    # vampir disleri: kavisli ust dudak + iki iri kopek disi + aradaki kucuk disler
    d.polygon([(12, 4), (36, 4), (34, 7), (29, 9), (24, 8), (19, 9), (14, 7)], fill=C('#8a1a2e'))
    d.line((13, 4, 35, 4), fill=C('#c8404e'))
    put(e, [(24, 7)], C('#5a0c18'))
    FANG, FANG_D = C('#fbf4ee'), C('#c8bcb4')
    for x in (16, 29):
        d.polygon([(x, 8), (x + 3, 8), (x + 2, 17), (x + 1, 17)], fill=FANG)
        d.line((x + 2, 9, x + 2, 16), fill=FANG_D)
    for x in (21, 23, 25):
        d.rectangle((x, 8, x + 1, 10), fill=FANG)
    d.line((31, 17, 29, 21), fill=A)    # disten kureye damlayan kan
    fx = canvas()
    # damlalar (akislardan kopan)
    for (x, y) in ((6, 16), (42, 16), (13, 45), (11, 12)):
        put(fx, [(x, y), (x, y + 1)], C('#ff4a5a'))
    sparkle(fx, 40, 40, C('#ffffff'), C('#ff8a9a'), 2)
    put(fx, [(36, 28), (37, 27), (37, 28), (38, 28), (37, 29)], C('#ffd0d8'))   # +1 maks. can
    finish(base, e, fx, "vampir_kan_emme_icon.png")


def vampir_yarasa_formu():
    """E - Yarasa Formu: dolunay onunde kanatlarini acmis buyuk yarasa (kirmizi gozler, disler), altinda ruzgar izleri."""
    base = tile(C('#3e1c52'), C('#0e0616'), C('#7040a0'), C('#b890e0'), C('#0a0410'), glow_center=(24, 16), glow_r=(13, 11))
    # dolunay (zeminin parcasi, konturlu amblemin arkasinda)
    bd = ImageDraw.Draw(base)
    bd.ellipse((12, 4, 36, 28), fill=C('#e8dcc0'))
    bd.ellipse((14, 6, 34, 26), fill=C('#f6eed8'))
    for (x, y, r) in ((19, 11, 2), (29, 17, 3), (22, 21, 1)):
        bd.ellipse((x - r, y - r, x + r, y + r), fill=C('#ddd0b0'))
    e = canvas()
    d = ImageDraw.Draw(e)
    # kanatlar
    for sx in (-1, 1):
        def X(dx):
            return 24 + sx * dx
        wing = [(X(3), 22), (X(9), 15), (X(16), 12), (X(22), 14), (X(21), 19), (X(19), 24), (X(16), 22), (X(14), 27),
                (X(11), 24), (X(8), 29), (X(5), 27), (X(3), 30)]
        d.polygon(wing, fill=BAT_MEM)
        d.line((X(3), 22, X(9), 15, X(16), 12, X(22), 14), fill=BAT_BONE)
        d.line((X(9), 15, X(11), 24), fill=BAT_BONE)
        d.line((X(16), 12, X(16), 22), fill=BAT_BONE)
        d.line((X(10), 17, X(15), 14), fill=BAT_MEM_L)
        d.line((X(18), 15, X(21), 15), fill=BAT_MEM_L)
    # govde + bas + kulaklar
    d.ellipse((19, 19, 29, 34), fill=BAT_BODY)
    d.ellipse((20, 14, 28, 22), fill=BAT_BODY)
    d.polygon([(20, 17), (20, 10), (23, 15)], fill=BAT_BODY)
    d.polygon([(28, 17), (28, 10), (25, 15)], fill=BAT_BODY)
    put(e, [(21, 12), (27, 12)], C('#6a2a50'))
    d.rectangle((21, 16, 22, 17), fill=C('#ff2a3a'))
    d.rectangle((26, 16, 27, 17), fill=C('#ff2a3a'))
    put(e, [(21, 16), (26, 16)], C('#ffd0d0'))
    put(e, [(23, 20), (25, 20), (23, 21), (25, 21)], C('#fbf4ee'))   # disler
    d.line((22, 25, 22, 31), fill=C('#3e2038'))                       # gogus kurku
    fx = canvas()
    fd = ImageDraw.Draw(fx)
    for (x0, x1, y, c) in ((6, 16, 38, '#b890e0'), (30, 42, 38, '#b890e0'), (10, 22, 42, '#7a58a8'), (26, 38, 42, '#7a58a8')):
        fd.line((x0, y, x1, y), fill=C(c))
    sparkle(fx, 42, 6, C('#ffffff'), C('#d8c0ff'), 1)
    sparkle(fx, 6, 8, C('#ffffff'), C('#d8c0ff'), 1)
    finish(base, e, fx, "vampir_yarasa_formu_icon.png")


def vampir_kan_yarasalari():
    """R - Kan Yarasalari: ortadaki kan damlasinin etrafinda donen 6 kucuk yarasa + donus yayi (vurup geri doner)."""
    base = tile(C('#5a0a16'), C('#140206'), C('#a01a2c'), C('#ff7080'), C('#10020a'))
    fx0 = canvas()
    fd0 = ImageDraw.Draw(fx0)
    # donus yayi (ince, arkada)
    fd0.arc((5, 5, 43, 43), 200, 330, fill=C('#c8404e'))
    fd0.arc((5, 5, 43, 43), 20, 150, fill=C('#c8404e'))
    base.alpha_composite(fx0)
    e = canvas()
    d = ImageDraw.Draw(e)
    blood_drop(d, e, 24, 27, 9, 5)
    # 6 yarasa, halka uzerinde, kanat cirpma fazlari donusumlu
    for i in range(6):
        ang = math.radians(-90 + i * 60)
        bx = int(round(24 + math.cos(ang) * 16))
        by = int(round(24 + math.sin(ang) * 15))
        mini_bat(e, bx, by, i % 2 == 0, C('#5e2a52'), C('#9a5a86'), BAT_BODY, C('#ff3040'))
    fx = canvas()
    # yarasalarin arkasindaki hareket izleri (saat yonunde)
    for i in range(6):
        ang = math.radians(-90 + i * 60 - 22)
        x = int(round(24 + math.cos(ang) * 16))
        y = int(round(24 + math.sin(ang) * 15))
        put(fx, [(x, y)], C('#ff8a9a'))
    sparkle(fx, 41, 42, C('#ffffff'), C('#ff8a9a'), 1)
    finish(base, e, fx, "vampir_kan_yarasalari_icon.png")


def vampir_pasif():
    """PASİF - Kan Emme: kanla dolu altin kadeh, kenarindan damlayan kan; ustunde kalp (saldiri gucu -> maks. can)."""
    base = tile(C('#4a0c24'), C('#12020a'), C('#8a1a3c'), C('#e07090'), C('#0e0208'), glow_center=(24, 26))
    e = canvas()
    d = ImageDraw.Draw(e)
    L, A, M, D = GOLD
    BL, BA, BM, BD = BLOOD
    # kadeh canağı
    d.polygon([(11, 17), (37, 17), (35, 25), (30, 30), (18, 30), (13, 25)], fill=A)
    d.line((12, 18, 14, 25, 18, 29), fill=L)
    d.line((36, 18, 34, 25, 30, 29), fill=M)
    # icindeki kan (ust yuzey elips)
    d.ellipse((12, 15, 36, 20), fill=BM)
    d.ellipse((14, 16, 34, 19), fill=BA)
    put(e, [(18, 17), (19, 17), (20, 17)], BL)
    # tasan kan (sag kenardan damla)
    d.line((36, 18, 37, 21), fill=BA)
    put(e, [(37, 22), (37, 23)], BM)
    # sap + dugum + taban
    d.rectangle((22, 30, 26, 37), fill=M)
    d.line((22, 30, 22, 37), fill=A)
    d.ellipse((20, 32, 28, 35), fill=A)
    put(e, [(21, 33)], L)
    d.polygon([(16, 42), (32, 42), (28, 37), (20, 37)], fill=A)
    d.line((16, 42, 32, 42), fill=D)
    d.line((20, 38, 28, 38), fill=L)
    # kadehin ustunde kalp (kucuk)
    heart(d, e, 24, 8, 3, (C('#ffd0d8'), C('#f0405a'), C('#c02040'), C('#780c20')))
    fx = canvas()
    put(fx, [(37, 26), (37, 27), (38, 27)], C('#ff4a5a'))
    put(fx, [(37, 31)], C('#c8102a'))
    sparkle(fx, 9, 10, C('#ffffff'), C('#ffe08a'), 2)
    sparkle(fx, 40, 12, C('#ffffff'), C('#ff9ab0'), 1)
    sparkle(fx, 10, 36, C('#ffffff'), C('#ffe08a'), 1)
    finish(base, e, fx, "vampir_passive_icon.png")


if __name__ == "__main__":
    print("Ruhani yetenek ikonlari:")
    spirit_para()
    spirit_can()
    spirit_adc()
    spirit_tank()
    spirit_taktik()
    spirit_dukkan()
    spirit_savas_sevki()
    spirit_kalkan_bagi()
    print("Vampir Cocuk ikonlari:")
    vampir_kan_emme()
    vampir_yarasa_formu()
    vampir_kan_yarasalari()
    vampir_pasif()
