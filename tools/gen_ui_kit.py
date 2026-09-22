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


def blit(a, x0, y0, rows, pal):
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in pal:
                a.set(x0 + x, y0 + y, pal[ch])


def bar_frame(kind):
    """40x18 sanat pikseli, uçları yuvarlak: sol uçta ikonlu ahşap 'boss', ortası yatayda esneyen çerçeve. Delik (dolgu) x=15..34, y=3..14."""
    w, h = 40, 18
    a = Art(w, h)
    accent = hexc('#8a2a36') if kind == 'hp' else hexc('#2f5f9f')
    m = rr_mask(w, h, 8)
    d = depth_map(m)
    hole = {(x, y) for y in range(3, 15) for x in range(15, w - 5)}
    for y in range(h):
        for x in range(w):
            if d[y][x] < 0 or (x, y) in hole:
                continue
            dd = d[y][x]
            light = light_side(x, y, w, h)
            if dd == 0:
                c = OUT
            elif dd == 1:
                c = W4 if light else W1
            elif dd == 2:
                c = W3 if light else W2
            else:
                c = W2 if light else W1
            a.set(x, y, c)
    # deliğe bitişik ince vurgu çizgisi (can: bordo, kalkan: mavi)
    for (x, y) in hole:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if n not in hole and 0 <= n[0] < w and 0 <= n[1] < h and a.get(n[0], n[1]) is not None and n[0] >= 15:
                a.set(n[0], n[1], accent)
    # sol boss (daire)
    cx, cy, R = 7.5, 8.5, 8.0
    for y in range(h):
        for x in range(0, 16):
            dx, dy = (x + 0.5) - (cx + 0.5), (y + 0.5) - (cy + 0.5)
            r = math.hypot(dx, dy)
            if r > R:
                continue
            if r > R - 1.0:
                c = OUT
            elif r > R - 2.0:
                c = W4 if (dx + dy) < 0 else W1
            elif r > R - 3.4:
                c = W3 if (dx + dy) < 0 else W2
            elif r > R - 4.4:
                c = OUT
            else:
                c = hexc('#2a1a10')
            a.set(x, y, c)
    if kind == 'hp':
        blit(a, 4, 5, HEART, HEART_PAL)
    else:
        blit(a, 4, 5, SHIELD, SHIELD_PAL)
    a.set(4, 2, GOLD_L)
    return a


def bar_under(w=4, h=12):
    a = Art(w, h)
    for y in range(h):
        c = hexc('#140c07') if y == 0 else (hexc('#1d1209') if y == 1 else (hexc('#2c1d11') if y < h - 1 else hexc('#3c2918')))
        for x in range(w):
            a.set(x, y, c)
    return a


def bar_fill(w=4, h=12):
    a = Art(w, h)
    bright = [255, 246, 226, 226, 226, 226, 226, 190, 190, 190, 150, 118]
    for y in range(h):
        v = bright[y]
        for x in range(w):
            a.set(x, y, (v, v, v, 255))
    return a


LEAF = [
    ".gGG..",
    "gGGGg.",
    ".gggg.",
    "..gg..",
]
LEAF_PAL = {'g': hexc('#2f6a2a'), 'G': hexc('#6fc04a')}


def avatar_frame(w=48, h=48, hole=6):
    a = Art(w, h)
    m = rr_mask(w, h, 12)
    d = depth_map(m)
    for y in range(h):
        for x in range(w):
            dd = d[y][x]
            if dd < 0:
                continue
            light = light_side(x, y, w, h)
            if dd >= hole:
                continue  # delik (portre görünür)
            if dd == 0:
                c = OUT
            elif dd == 1:
                c = W4 if light else W1
            elif dd == 2:
                c = W3 if light else W2
            elif dd in (3, 4):
                c = W2 if light else W1
            else:
                c = OUT
            a.set(x, y, c)
    # iç gölge (deliğin üst/sol kenarı hafif karartılır - çukur hissi)
    for y in range(h):
        for x in range(w):
            if d[y][x] == hole and (x <= hole + 1 or y <= hole + 1) and light_side(x, y, w, h):
                a.set(x, y, (0, 0, 0, 90))
    for (x, y, c) in ((2, 2, GOLD_L), (3, 2, GOLD), (2, 3, GOLD), (3, 3, GOLD_D)):
        a.set(x, y, c)
        a.set(w - 1 - x, h - 1 - y, c)
    # yaprak sarmaşığı: sol-üst ve sağ-alt köşede
    blit(a, 5, 1, LEAF, LEAF_PAL)
    blit(a, 1, 6, LEAF, LEAF_PAL)
    blit(a, w - 11, h - 5, LEAF, LEAF_PAL)
    blit(a, w - 7, h - 10, LEAF, LEAF_PAL)
    return a


def level_badge(size=26):
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
                c = OUT
            else:
                c = hexc('#2b1c10')
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
            elif r > R - 4.0:
                c = W3 if lit else W2
            elif r > R - 5.0:
                c = W2 if lit else W1
            else:
                c = OUT
            a.set(x, y, c)
    # kuzey/doğu/güney/batı perçinleri + kuzeyde büyük altın taş
    ring_r = 42.6
    for ang in (0, 90, 180, 270):
        rad = math.radians(ang - 90)
        px = int(round(c0 + math.cos(rad) * ring_r))
        py = int(round(c0 + math.sin(rad) * ring_r))
        for (ox, oy, col) in ((0, 0, GOLD_L), (1, 0, GOLD), (0, 1, GOLD), (1, 1, GOLD_D)):
            a.set(px - 1 + ox, py - 1 + oy, col)
    nx, ny = int(round(c0)), 1
    for (ox, oy, col) in ((0, -1, GOLD_L), (-1, 0, GOLD), (0, 0, GOLD_L), (1, 0, GOLD_D), (0, 1, GOLD_D)):
        pass
    return a


def build():
    # butonlar
    for name, pal in (('wood', PAL_WOOD), ('green', PAL_GREEN), ('dark', PAL_DARK), ('red', PAL_RED)):
        for st in ('normal', 'hover', 'pressed', 'disabled', 'focus'):
            plank(32, 20, pal, st, studs=True).save(out('btn_%s_%s.png' % (name, st)))
            plank(20, 20, pal, st, studs=False, radius=10).save(out('btn_mini_%s_%s.png' % (name, st)))
    # paneller
    window_panel().save(out('panel_window.png'))
    inset_panel().save(out('panel_inset.png'))
    ability_bar_panel().save(out('panel_ability_bar.png'))
    status_badge_panel().save(out('panel_status_badge.png'))
    card_panel(state='normal').save(out('panel_card.png'))
    card_panel(state='selected').save(out('panel_card_selected.png'))
    card_panel(state='sold').save(out('panel_card_sold.png'))
    plaque_panel().save(out('panel_plaque.png'))
    # HUD
    bar_frame('hp').save(out('hud_bar_frame_hp.png'))
    bar_frame('shield').save(out('hud_bar_frame_shield.png'))
    bar_under().save(out('hud_bar_under.png'))
    bar_fill().save(out('hud_bar_fill.png'))
    avatar_frame().save(out('hud_avatar_frame.png'))
    level_badge().save(out('hud_level_badge.png'))
    slot_frame(39, 5, PAL_SLOT_WOOD).save(out('hud_skill_frame.png'))
    slot_frame(47, 6, PAL_SLOT_SPIRIT).save(out('hud_skill_frame_spirit.png'))
    slot_frame(24, 3, PAL_SLOT_WOOD).save(out('hud_skill_frame_small.png'))
    minimap_ring().save(out('hud_minimap_ring.png'))
    print('kit written to', os.path.abspath(OUTDIR))


if __name__ == '__main__':
    build()
