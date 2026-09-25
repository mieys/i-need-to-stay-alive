"""Cozy/RPG piksel UI kiti: butonlar, paneller, HUD çerçeveleri -> assets/ui/kit/*.png (her sanat pikseli = 2 ekran pikseli).

Çalıştır:  python tools/gen_ui_kit.py   (sonra Godot'ta `--headless --import`)
Tasarım: sıcak turuncu-kahve ahşap plaka (ana menüdeki mevcut buton kimliği korunur), koyu deri panel içleri, demir köşe
bağlantıları + altın perçinler (seviye atlama kartlarındaki köşe braketleriyle akraba), yeşil yaprak vurguları.
9-slice dokularda esneyen bölge DÜZ renktir (bkz. ui_kit_lib.py), bu yüzden hiçbir boyutta bulanıklaşma/bozulma olmaz.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from ui_kit_lib import *  # noqa: F401,F403

OUTDIR = os.path.join(os.path.dirname(__file__), '..', 'assets', 'ui', 'kit')


def out(name):
    return os.path.join(OUTDIR, name)


# ------------------------------------------------------------------ butonlar
# (2026-09-22, ana menü geri bildirimi: "çok açık renkli, zor okunuyor" -> ahşap/yeşil paletler koyulaştırıldı, krem yazıyla kontrast arttı.)
# Kullanıcı geri bildirimi (2026-09-22): "butonları pek beğenmedim kalitesiz duruyorlar" - ilk sürüm düz renkli, ince kenarlıklı
# ve küçük perçinliydi. Yeni tasarım: KALIN 3D "kabartma" düğme (üstte parlak ışık pahı, yumuşak dither geçişli yüz, altta 3 satırlık
# koyu kalın taban dudağı), kenar kapaklarında büyük altın perçin + ahşap birleşim çizgisi, yüzde yatay ahşap damarı.
# Damar/degrade satırları SADECE 9-slice'ın kenar bantlarında (margin: 10 sanat px yatay, 8 dikey) ve 12x4'lük orta karo desende;
# UIKit.button_style bu bölgeleri TILE modunda (esnetmeden, tam sayı tekrarla) çizer => hiçbir boyutta bulanıklık/bozulma yok.
PAL_WOOD = dict(out=hexc('#22100a'), hi=hexc('#d99c5f'), lt=hexc('#b9773b'), md=hexc('#93592b'), dk=hexc('#744421'), dd=hexc('#52301a'), lip=hexc('#3a2010'))
PAL_GREEN = dict(out=hexc('#11200b'), hi=hexc('#b3df7c'), lt=hexc('#78b04a'), md=hexc('#4f8a30'), dk=hexc('#39692a'), dd=hexc('#264a19'), lip=hexc('#1a3411'))
PAL_DARK = dict(out=hexc('#1c0f08'), hi=hexc('#b27842'), lt=hexc('#8f5b32'), md=hexc('#6f4526'), dk=hexc('#57341c'), dd=hexc('#3c2413'), lip=hexc('#2a180d'))
PAL_RED = dict(out=hexc('#2e0c0c'), hi=hexc('#f7a898'), lt=hexc('#dc6a55'), md=hexc('#b23d31'), dk=hexc('#8a2b26'), dd=hexc('#5c1d1a'), lip=hexc('#40120f'))

TILE_W = 12  # orta karo genişliği (sanat px)
LIP_ROWS = 3  # alt kalın taban dudağı


def _state_pal(pal, state):
    p = dict(pal)
    if state == 'hover':
        p = {k: (lighten(v, 0.13) if k != 'out' else v) for k, v in p.items()}
    elif state == 'pressed':
        p = {k: (darken(v, 0.10) if k != 'out' else v) for k, v in p.items()}
    elif state == 'disabled':
        p = {k: darken(gray_mix(v, 0.80), 0.12) for k, v in p.items()}
    elif state == 'focus':
        p['out'] = GOLD_L
    return p


def plank(w, h, pal, state='normal', studs=True, radius=8):
    """Kalın 3D ahşap düğme. state: normal / hover / pressed / disabled / focus."""
    p = _state_pal(pal, state)
    pressed = (state == 'pressed')
    a = Art(w, h)
    m = rr_mask(w, h, radius)
    d = depth_map(m)
    lip = 1 if pressed else LIP_ROWS  # basılı düğme: taban dudağı ezilir
    face_lo = p['dk'] if pressed else p['lt']
    for y in range(h):
        for x in range(w):
            dd = d[y][x]
            if dd < 0:
                continue
            from_bottom = h - 1 - y
            if dd == 0:
                c = p['out']
            elif from_bottom <= lip:  # taban dudağı
                c = p['lip']
                if from_bottom == lip:
                    c = p['dd']
            elif y == 1:
                c = p['dd'] if pressed else p['hi']
            elif y == 2:
                c = p['dk'] if pressed else p['lt']
            elif y == 3:
                c = mix(p['md'], face_lo, 0.5) if ((x + y) & 1) == 0 else face_lo
            elif y == 4:
                c = mix(p['md'], face_lo, 0.5) if ((x + y) & 1) == 0 else p['md']
            elif from_bottom == lip + 1:
                c = p['dk']  # yüz -> dudak geçişi (koyu şerit)
            elif from_bottom == lip + 2:
                c = mix(p['md'], p['dk'], 0.5) if ((x + y) & 1) == 0 else p['md']
            else:
                c = p['md']
                # ahşap damarı (12 px'lik periyot): yatay kısa dashlar
                phase = x % TILE_W
                if y == 6 and 2 <= phase <= 5:
                    c = mix(p['md'], p['dk'], 0.30)
                elif y == 8 and 7 <= phase <= 10:
                    c = mix(p['md'], p['lt'], 0.28)
                elif y == 10 and 0 <= phase <= 3:
                    c = mix(p['md'], p['dk'], 0.24)
                elif y == 12 and 5 <= phase <= 8:
                    c = mix(p['md'], p['lt'], 0.22)
            a.set(x, y, c)
    # sol/sağ iç pah
    for y in range(3, h - lip - 2):
        for x, left in ((1, True), (w - 2, False)):
            if d[y][x] == 1:
                a.set(x, y, p['hi'] if (left and not pressed) else p['dk'])
    if state == 'focus':
        for y in range(h):
            for x in range(w):
                if d[y][x] == 1:
                    a.set(x, y, GOLD)
    # kenar kapakları: ahşap birleşim çizgisi + büyük altın perçin (sadece geniş plakalarda)
    if studs and w >= 28:
        cy = (h - lip - 2) // 2 + 1
        dim = (0, 0, 0, 255)
        for sx, seam, dirn in ((3, 8, 1), (w - 5, w - 9, -1)):
            for yy in range(4, h - lip - 3):
                a.set(seam, yy, mix(p['md'], p['out'], 0.45))
                a.set(seam + dirn, yy, mix(p['md'], p['hi'], 0.25))
            gl, gm, gd = GOLD_L, GOLD, GOLD_D
            if state == 'disabled':
                gl, gm, gd = mix(gl, dim, 0.4), mix(gm, dim, 0.4), mix(gd, dim, 0.4)
            a.set(sx, cy - 1, gl)
            a.set(sx + 1, cy - 1, gm)
            a.set(sx, cy, gm)
            a.set(sx + 1, cy, gd)
            a.set(sx, cy + 1, mix(p['md'], p['out'], 0.5))
            a.set(sx + 1, cy + 1, mix(p['md'], p['out'], 0.5))
    return a


# ------------------------------------------------------------------ paneller
def window_panel(w=48, h=48, radius=12, studs=True):
    """Yuvarlatılmış (oval köşeli) ahşap pencere: kalın pervaz + koyu deri iç; köşe eğrilerinde altın perçinler.
    radius: köşe yarıçapı (sanat px) - varsayılan diğer pencerelerle (merchant/envanter/stat) AYNI, ama
    ability_bar_panel() gibi çağıranlar daha büyük bir yarıçapla (neredeyse yarım yükseklik) hap/oval uçlar
    isteyebilir (bkz. kullanıcı isteği: "çerçeveler oval olmalı").
    studs: köşe perçinleri SABİT (4,4) konumuna çizilir - küçük varsayılan radius'ta eğrinin üstüne denk gelir
    ama BÜYÜK radius'ta maskenin TAMAMEN DIŞINA düşüp havada asılı "tuhaf köşe parçaları" gibi görünür
    (kullanıcı bildirimi 2026-09-22) - bu yüzden ability_bar_panel() studs=False geçiyor."""
    a = Art(w, h)
    m = rr_mask(w, h, radius)
    d = depth_map(m)
    for y in range(h):
        for x in range(w):
            dd = d[y][x]
            if dd < 0:
                continue
            light = light_side(x, y, w, h)
            if dd == 0:
                c = OUT
            elif dd == 1:
                c = W4 if light else W1
            elif dd == 2:
                c = W3 if light else W2
            elif dd in (3, 4, 5):
                c = W2 if light else W1
                if dd == 4:
                    c = W3 if light else W2  # orta şerit biraz aydınlık: yükseltilmiş pervaz hissi
            elif dd == 6:
                c = W0 if light else W3  # iç pah: içe doğru çukur
            elif dd == 7:
                c = OUT
            elif dd == 8:
                c = LEATHER_D if light else LEATHER
            else:
                c = LEATHER
            a.set(x, y, c)
    # köşe eğrilerinde 2x2 altın perçinler (pervazın ortası) - SADECE studs=True iken (bkz. üstteki not)
    if studs:
        for (x, y, c) in ((4, 4, GOLD_L), (5, 4, GOLD), (4, 5, GOLD), (5, 5, GOLD_D)):
            paste_mirror4(a, x, y, c)
    return a


def inset_panel(w=16, h=16):
    a = Art(w, h)
    m = rr_mask(w, h, 6)
    d = depth_map(m)
    for y in range(h):
        for x in range(w):
            dd = d[y][x]
            if dd < 0:
                continue
            light = light_side(x, y, w, h)
            if dd == 0:
                c = OUT
            elif dd == 1:
                c = hexc('#150d07') if light else W0
            else:
                c = INSET
            a.set(x, y, c)
    return a


def ability_bar_panel(w=96, h=40, radius=14):
    """Yetenek çubuğunun arkasını kaplayan panel (kullanıcı isteği 2026-09-22: "skill kutucuklarının olduğu
    yere arkasını kaplayacak bir çerçeve... diğer arayüzlerle uyumlu olacak şekilde... çerçeveler oval
    olmalı"). window_panel'le AYNI PALETİ (W0-4/LEATHER/OUT) kullanıyor ama KENDİ İNCE pervazı var -
    window_panel'in 9 katmanlı (dd 0-8) kalın çerçevesi merchant/envanter/stat gibi BÜYÜK pencereler için
    tasarlandı; bu küçük barda AYNI mutlak piksel kalınlığı orantısız kalın görünüyordu (kullanıcı bildirimi:
    "çerçeve çok kalın... kenarlardaki açık kahverengi kontürler çok büyük"). Burada sadece 3 katman var
    (~3 sanat px = 6 gerçek px, window_panel'in ~9 sanat px'inin YAKLAŞIK ÜÇTE BİRİ)."""
    a = Art(w, h)
    m = rr_mask(w, h, radius)
    d = depth_map(m)
    for y in range(h):
        for x in range(w):
            dd = d[y][x]
            if dd < 0:
                continue
            light = light_side(x, y, w, h)
            if dd == 0:
                c = OUT
            elif dd == 1:
                c = W3 if light else W1
            elif dd == 2:
                c = W1 if light else LEATHER_D
            else:
                c = LEATHER
            a.set(x, y, c)
    return a


def status_badge_panel(w=16, h=16, radius=5):
    """Buff/debuff durum rozetlerinin (hud.gd StatusBar, status_effect_badge.gd) arka planı - kullanıcı
    isteği (2026-09-22, referans görsel): "bunların da ince dış açık kahverengi çerçeveleri olsun" - eski
    inset_panel'in tek düz koyu konturu yerine ability_bar_panel'le AYNI ince ahşap pervaz dili (ince açık
    kahverengi/koyu kahverengi kenar + koyu çukur iç), sadece küçük bir rozete sığacak kadar İNCE (tek katman)."""
    a = Art(w, h)
    m = rr_mask(w, h, radius)
    d = depth_map(m)
    for y in range(h):
        for x in range(w):
            dd = d[y][x]
            if dd < 0:
                continue
            light = light_side(x, y, w, h)
            if dd == 0:
                c = OUT
            elif dd == 1:
                c = W3 if light else W1
            else:
                c = INSET
            a.set(x, y, c)
    return a


def card_panel(w=28, h=36, state='normal'):
    a = Art(w, h)
    m = rr_mask(w, h, 8)
    d = depth_map(m)
    body = hexc('#4f331d')
    hi = hexc('#7a5230')
    lo = hexc('#3a2414')
    outc = OUT
    r1 = (hi, lo)
    r2 = (hexc('#65431f'), hexc('#432a17'))
    if state == 'selected':
        body = hexc('#5d3c22')
        outc = hexc('#5a3a08')
        r1 = (GOLD_L, GOLD_D)
        r2 = (GOLD, hexc('#b57a20'))
    elif state == 'sold':
        body = hexc('#3a3128')
        hi = hexc('#4f463b')
        lo = hexc('#2b241d')
        r1 = (hi, lo)
        r2 = (hexc('#463d33'), hexc('#302921'))
    for y in range(h):
        for x in range(w):
            dd = d[y][x]
            if dd < 0:
                continue
            light = light_side(x, y, w, h)
            if dd == 0:
                c = outc
            elif dd == 1:
                c = r1[0] if light else r1[1]
            elif dd == 2:
                c = r2[0] if light else r2[1]
            else:
                c = body
            a.set(x, y, c)
    # köşe süsleri: seviye kartlarındaki braketlere akraba küçük L işaretleri
    acc = GOLD if state == 'selected' else (hexc('#8a6a44') if state != 'sold' else hexc('#5c5145'))
    for (x, y) in ((6, 6), (7, 6), (6, 7)):
        paste_mirror4(a, x, y, acc)
    return a


def plaque_panel(w=32, h=18):
    return plank(w, h, PAL_DARK, 'normal', studs=True, radius=8)


# ------------------------------------------------------------------ HUD
HEART = [
    ".rr.rr.",
    "rhhRrRr",
    "rhRRRRr",
    "rRRRRRd",
    ".rRRRd.",
    "..rRd..",
    "...d...",
]
HEART_PAL = {'r': hexc('#7a1218'), 'R': hexc('#e0424e'), 'h': hexc('#ffb0b0'), 'd': hexc('#8f1c26')}
SHIELD = [
    "kkkkkkk",
    "kBhBBBk",
    "kBhBBBk",
    "kBBBBdk",
    ".kBBdk.",
    "..kdk..",
    "...k...",
]
SHIELD_PAL = {'k': hexc('#16305a'), 'B': hexc('#4c8de0'), 'h': hexc('#bfe0ff'), 'd': hexc('#2c62b0')}


# ------------------------------------------------------------------ HUD (2026-09-24 yeniden çizim)
# Kullanıcı isteği (2026-09-24): "mini mapi ve sol üstteki karakter kalkan can avatar çerçeve v.b unutma" - HUD parçaları da
# menülerle aynı dile geçti: ahşap çerçeve + parşömen paspas/disk + pirinç çiviler + yaprak sarmaşığı. GEOMETRİ AYNI
# (hud.tscn yerleşimi bu dokuların delik/pay ölçülerine bağlı: avatar deliği 6..42, bar deliği x15..34 y3..14, minimap iç
# yarıçapı 40 sanat px) - sadece çizim değişti.
LINE = hexc('#5a361d')
PARCH_HI = hexc('#d9bd8f')
PARCH_MID = hexc('#c8a878')
PARCH_SH = hexc('#ae8e60')


def blit(a, x0, y0, rows, pal):
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in pal:
                a.set(x0 + x, y0 + y, pal[ch])


# Kullanıcı isteği (2026-09-24): "can ve kalkan barını da uyumlu şekilde yeniden tasarla lütfen çerçeveler iç bar v.b kötü",
# ardından "barlar hiç değişmemiş çok çirkinler" (ilk deneme eskisine fazla benziyordu: disk + ince ahşap + koyu tüp).
# Yeni tasarım sağdaki ENVANTER/altın levhalarıyla AYNI dil: ahşap kenarlı bej PARŞÖMEN LEVHA, sol ucunda levhanın üstünde
# büyük kalp/kalkan ikonu, ortada levhaya gömülü (oyuk kenarlı) çubuk yuvası, sağ uçta pirinç çivi.
# Geometri (sanat px, S=2) - hud.gd _layout_bar_kit aynı ölçüleri kullanır:
#   doku 48x22 (96x44 px); NinePatch sol payı 20 (40 px), sağ payı 6 (12 px);
#   satırlar: 0 kontur, 1 ahşap, 2 koyu çizgi, 3-4 parşömen, 5 oyuk üst kenarı, 6..15 ÇUBUK (10 satır = 20 px),
#   16 oyuk alt ışığı, 17-18 parşömen, 19 koyu çizgi, 20 ahşap, 21 kontur.
# Çubuk deliği ŞEFFAF DEĞİL: üstte iç gölge + parlama, altta koyulaşma (yarı saydam) - dolu ve boş kısma aynı hacmi verir;
# satır bazlı olduğu için 9-slice'ın yatay esnemesinde bozulmaz. Dolgunun kendisi düz beyaz (hud.gd tint ile boyar).
BAR_W, BAR_H = 48, 22
BAR_PATCH_L, BAR_PATCH_R = 20, 6
BAR_HOLE_Y0, BAR_HOLE_Y1 = 6, 15
BAR_RECESS = hexc('#3a2616')
BAR_GLOSS = {6: (30, 14, 4, 130), 7: (255, 250, 230, 95), 8: (255, 250, 230, 40), 13: (30, 14, 4, 40), 14: (30, 14, 4, 70),
             15: (30, 14, 4, 105)}
BAR_P_HI = hexc('#d9bd8f')
BAR_P = hexc('#c8a878')
BAR_P_SH = hexc('#ae8e60')
BAR_IN_EDGE = hexc('#7f613b')
BAR_IN_HI = hexc('#e2c99c')
HEART11 = [
    ".rrr...rrr.",
    "rhhRr.rRRRr",
    "rhRRRrRRRRr",
    "rhRRRRRRRdr",
    "rRRRRRRRRdr",
    ".rRRRRRRdr.",
    "..rRRRRdr..",
    "...rRRdr...",
    "....rdr....",
    ".....r.....",
]
HEART11_PAL = {'r': hexc('#5e1016'), 'R': hexc('#d8404a'), 'h': hexc('#ffb4b0'), 'd': hexc('#962430')}
SHIELD11 = [
    "kkkkkkkkkkk",
    "khhBBBBBBdk",
    "khBBBhBBBdk",
    "khBBhhhBBdk",
    "khBBBhBBBdk",
    "kBBBBBBBBdk",
    ".kBBBBBBdk.",
    "..kBBBBdk..",
    "...kBBdk...",
    "....kdk....",
    ".....k.....",
]
SHIELD11_PAL = {'k': hexc('#172c52'), 'B': hexc('#4a86d6'), 'h': hexc('#bcdcff'), 'd': hexc('#2b5aa6')}


def bar_frame(kind):
    """Can/kalkan çubuğu levhası (48x22): ahşap kenarlı parşömen levha + solda ikon + ortada oyuk çubuk yuvası + sağda çivi."""
    w, h = BAR_W, BAR_H
    a = Art(w, h)
    m = rr_mask(w, h, 6)
    d = depth_map(m)
    in_x0, in_x1 = BAR_PATCH_L - 1, w - BAR_PATCH_R  # oyuk kenar sütunları (19 ve 42)
    in_y0, in_y1 = BAR_HOLE_Y0 - 1, BAR_HOLE_Y1 + 1   # oyuk kenar satırları (5 ve 16)
    for y in range(h):
        for x in range(w):
            dd = d[y][x]
            if dd < 0:
                continue
            top = y < h / 2
            if dd == 0:
                c = OUT
            elif dd == 1:
                c = W3 if top else W1
            elif dd == 2:
                c = LINE
            elif dd == 3:
                c = BAR_P_HI if top else BAR_P_SH
            else:
                c = BAR_P
            if in_x0 <= x <= in_x1 and in_y0 <= y <= in_y1:
                if y == in_y0 or x == in_x0:
                    c = BAR_IN_EDGE
                elif y == in_y1 or x == in_x1:
                    c = BAR_IN_HI
                else:
                    c = BAR_GLOSS.get(y)
            if c is not None:
                a.set(x, y, c)
    # sağ uç: pirinç çivi (parşömen üstünde)
    for (ox, oy, c) in ((0, 0, GOLD_L), (1, 0, GOLD), (0, 1, GOLD), (1, 1, GOLD_D)):
        a.set(w - 4 + ox, 10 + oy, c)
    # sol uç: ikon + 1 px parşömen gölgesi
    rows, pal = (HEART11, HEART11_PAL) if kind == 'hp' else (SHIELD11, SHIELD11_PAL)
    ix, iy = 5, 6 if kind == 'hp' else 5
    for yy, row in enumerate(rows):
        for xx, ch in enumerate(row):
            if ch in pal and a.get(ix + xx + 1, iy + yy + 1) == BAR_P:
                a.set(ix + xx + 1, iy + yy + 1, BAR_P_SH)
    blit(a, ix, iy, rows, pal)
    return a


def bar_under(w=4, h=12):
    """Boş kısım: düz koyu çukur - hacim gölgesi çerçevenin deliğinde (BAR_GLOSS), burada tekrar edilmez."""
    a = Art(w, h)
    for y in range(h):
        for x in range(w):
            a.set(x, y, BAR_RECESS)
    return a


def bar_fill(w=4, h=12):
    """Dolgu: düz beyaz (hud.gd tint_progress ile can rengine / kalkan mavisine boyanır); ışık/gölge çerçevedeki BAR_GLOSS'ta."""
    a = Art(w, h)
    for y in range(h):
        for x in range(w):
            a.set(x, y, (255, 255, 255, 255))
    return a


LEAF = [
    ".gGG..",
    "gGGGg.",
    ".gggg.",
    "..gg..",
]
LEAF_PAL = {'g': hexc('#2f6a2a'), 'G': hexc('#6fc04a')}


def avatar_frame(w=48, h=48, hole=6):
    """Portre çerçevesi (delik 6..42 = hud.tscn PortraitClip 12..84 px): ahşap bevel + koyu iç çizgi + parşömen paspas,
    kenar ortalarında pirinç çiviler, sol-üst ve sağ-alt köşelerde yaprak sarmaşığı."""
    a = Art(w, h)
    m = rr_mask(w, h, 12)
    d = depth_map(m)
    for y in range(h):
        for x in range(w):
            dd = d[y][x]
            if dd < 0 or dd >= hole:
                continue
            light = light_side(x, y, w, h)
            if dd == 0:
                c = OUT
            elif dd == 1:
                c = W4 if light else W1
            elif dd == 2:
                c = W3 if light else W2
            elif dd == 3:
                c = LINE
            elif dd == 4:
                c = PARCH_HI if light else PARCH_MID
            else:
                c = PARCH_SH if light else PARCH_MID
            a.set(x, y, c)
    # portrenin üst/sol kenarına ince iç gölge (çukur hissi)
    for y in range(h):
        for x in range(w):
            if d[y][x] == hole and light_side(x, y, w, h):
                a.set(x, y, (40, 22, 10, 90))
    # kenar ortalarında pirinç çiviler (ahşap bant üstünde)
    mid = w // 2 - 1
    for (x, y) in ((mid, 1), (mid, h - 3), (1, mid), (w - 3, mid)):
        for (ox, oy, c) in ((0, 0, GOLD_L), (1, 0, GOLD), (0, 1, GOLD), (1, 1, GOLD_D)):
            a.set(x + ox, y + oy, c)
    blit(a, 5, 1, LEAF, LEAF_PAL)
    blit(a, 1, 6, LEAF, LEAF_PAL)
    blit(a, w - 11, h - 5, LEAF, LEAF_PAL)
    blit(a, w - 7, h - 10, LEAF, LEAF_PAL)
    return a


def avatar_bg(w=36, h=36):
    """Portrenin ARKASI (hud.gd PortraitClip'in ilk çocuğu, 72x72 px): menü kartlarının portre penceresiyle aynı sıcak krem ->
    bej degrade (dither geçişli) + altta çimen tümseği; karakter oyun dünyası yerine bu sahnenin önünde durur."""
    a = Art(w, h)
    cols = [hexc('#eedab4'), hexc('#e5cea3'), hexc('#dcc193'), hexc('#d2b585')]
    for y in range(h):
        t = y / (h - 1)
        idx = min(3, int(t * 4))
        for x in range(w):
            c = cols[idx]
            if idx < 3 and int(((y + 1) / (h - 1)) * 4) != idx and ((x + y) & 1) == 0:
                c = cols[idx + 1]
            a.set(x, y, c)
    cx, gy = w / 2.0, h - 3
    for y in range(gy - 3, h):
        for x in range(w):
            dx = (x + 0.5 - cx) / 14.0
            dy = (y + 0.5 - (gy + 0.5)) / 3.2
            r = dx * dx + dy * dy
            if r > 1.0:
                continue
            c = hexc('#b8c67e') if y <= gy - 2 else (hexc('#8fa25a') if r > 0.72 else hexc('#a2b46a'))
            a.set(x, y, c)
    return a


def level_badge(size=26):
    """Seviye rozeti: altın halka + koyu iç çizgi + parşömen iç (seviye rakamı koyu kahve yazılır - bkz. hud.gd)."""
    a = Art(size, size)
    c0 = (size - 1) / 2.0
    R = size / 2.0
    for y in range(size):
        for x in range(size):
            dx, dy = x - c0, y - c0
            r = math.hypot(dx, dy)
            if r > R - 0.2:
                continue
            if r > R - 1.3:
                c = OUT
            elif r > R - 2.6:
                c = GOLD_L if (dx + dy) < 0 else GOLD_D
            elif r > R - 3.6:
                c = GOLD
            elif r > R - 4.6:
                c = LINE
            else:
                c = PARCH_HI if (dx + dy) < -3.0 else PARCH_MID
            a.set(x, y, c)
    return a


PAL_SLOT_WOOD = dict(hi=W4, lt=W3, md=W2, dk=W1)
PAL_SLOT_SPIRIT = dict(hi=hexc('#e2b8ff'), lt=hexc('#a566da'), md=hexc('#7a3fb0'), dk=hexc('#4f2478'))


def slot_frame(size, rim, pal, rivet=GOLD):
    a = Art(size, size)
    m = rr_mask(size, size, 9 if size > 30 else 6)
    d = depth_map(m)
    for y in range(size):
        for x in range(size):
            dd = d[y][x]
            if dd < 0:
                continue
            light = light_side(x, y, size, size)
            if dd >= rim:
                continue
            if dd == 0:
                c = OUT
            elif dd == 1:
                c = pal['hi'] if light else pal['dk']
            elif dd < rim - 1:
                c = pal['lt'] if light else pal['md']
            else:
                c = OUT
            a.set(x, y, c)
    # deliğin üst/sol iç gölgesi
    for y in range(size):
        for x in range(size):
            if d[y][x] == rim and light_side(x, y, size, size):
                a.set(x, y, (0, 0, 0, 100))
    if rim >= 5:
        for (x, y) in ((2, 2),):
            paste_mirror4(a, x, y, rivet)
    return a


def minimap_ring(size=92):
    """Minimap çerçevesi (iç yarıçap 40 sanat px = minimap.gd RADIUS 80 px): ahşap bevel halka + ince parşömen pusula bandı
    (30 derecede bir çentik, ana yönlerde uzun), üstte kuzey levhası (N), doğu/güney/batıda pirinç çiviler."""
    a = Art(size, size)
    c0 = (size - 1) / 2.0
    R = size / 2.0
    r_in = 40.0
    for y in range(size):
        for x in range(size):
            dx, dy = x - c0, y - c0
            r = math.hypot(dx, dy)
            if r > R or r < r_in:
                continue
            lit = (dx + dy) < 0
            if r > R - 1.0:
                c = OUT
            elif r > R - 2.0:
                c = W4 if lit else W1
            elif r > R - 3.2:
                c = W3 if lit else W2
            elif r > R - 4.0:
                c = LINE
            elif r > r_in + 0.9:
                c = PARCH_HI if lit else PARCH_MID
                ang = (math.degrees(math.atan2(dy, dx)) + 360.0) % 30.0
                if ang < 3.0 or ang > 27.0:
                    c = LINE
            else:
                c = OUT
            a.set(x, y, c)
    # doğu/güney/batı pirinç çiviler (ahşap bant üstünde)
    ring_r = R - 2.2
    for ang in (0, 90, 180):
        rad = math.radians(ang)
        px = int(round(c0 + math.cos(rad) * ring_r))
        py = int(round(c0 + math.sin(rad) * ring_r))
        for (ox, oy, col) in ((0, 0, GOLD_L), (1, 0, GOLD), (0, 1, GOLD), (1, 1, GOLD_D)):
            a.set(px - 1 + ox, py - 1 + oy, col)
    # kuzey levhası: küçük parşömen etiket + "N"
    lx0, ly0, lw, lh = int(c0) - 4, 0, 10, 9
    for y in range(ly0, ly0 + lh):
        for x in range(lx0, lx0 + lw):
            edge = x in (lx0, lx0 + lw - 1) or y in (ly0, ly0 + lh - 1)
            corner = (x in (lx0, lx0 + lw - 1)) and (y in (ly0, ly0 + lh - 1))
            if corner:
                continue
            a.set(x, y, OUT if edge else (PARCH_HI if y < ly0 + 3 else PARCH_MID))
    for (x, y) in ((2, 2), (2, 3), (2, 4), (2, 5), (2, 6), (3, 3), (4, 4), (5, 5), (6, 2), (6, 3), (6, 4), (6, 5), (6, 6)):
        a.set(lx0 + x - 0, ly0 + y - 0, LINE)
    return a


def build():
    """Yalnız HUD parçaları. Oyun içi PANEL/BUTON dokuları artık tools/gen_menu_kit.py build_game -> assets/ui/game
    (kullanıcı isteği 2026-09-24: oyun içi arayüzler menülerle aynı bej/ahşap kite geçti); plank/window_panel/inset_panel/
    card_panel/plaque_panel fonksiyonları yalnız ability_bar/HUD çizimlerinin ortak yardımcıları olarak duruyor."""
    ability_bar_panel().save(out('panel_ability_bar.png'), deepen=True)
    status_badge_panel().save(out('panel_status_badge.png'), deepen=True)
    bar_frame('hp').save(out('hud_bar_frame_hp.png'), deepen=True)
    bar_frame('shield').save(out('hud_bar_frame_shield.png'), deepen=True)
    bar_under().save(out('hud_bar_under.png'), deepen=True)
    bar_fill().save(out('hud_bar_fill.png'))  # dolgu çalışma anında can/kalkan rengine boyanır - oyun bilgisi, koyulaştırılmaz
    avatar_frame().save(out('hud_avatar_frame.png'), deepen=True)
    avatar_bg().save(out('hud_avatar_bg.png'), deepen=True)
    level_badge().save(out('hud_level_badge.png'), deepen=True)
    slot_frame(39, 5, PAL_SLOT_WOOD).save(out('hud_skill_frame.png'), deepen=True)
    slot_frame(47, 6, PAL_SLOT_SPIRIT).save(out('hud_skill_frame_spirit.png'), deepen=True)
    slot_frame(24, 3, PAL_SLOT_WOOD).save(out('hud_skill_frame_small.png'), deepen=True)
    minimap_ring().save(out('hud_minimap_ring.png'), deepen=True)
    print('HUD kit written to', os.path.abspath(OUTDIR))


if __name__ == '__main__':
    build()
