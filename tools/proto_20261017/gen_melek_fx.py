"""2026-10-17 prototipleri: MELEK - MEVCUT Q/E yeteneklerine yeni piksel efektler (kullanıcı: "melek'in yetenekleri için (ulti ve
pasif hariç) birer yeni efekt prototipleri üretmeni istiyorum"). MEKANİKLER/SAYILAR AYNI (madde 178 dersi: "efekt" = sadece görsel).
OYUNA HENÜZ BAĞLI DEĞİL. Değişecek eski efektler:
  Q  Can Basma       `fx_oyku_heal.gd` (vektör altıgen yıldız + yuvarlak parçacık), `_spawn_burst` yeşil, dosta `fx_wave_beam` "heal"
                     dalgası, Melek + dost üstünde `fx_melek_heal_aura` (yumuşak yeşil sütun, piksel değil)
  E  Kalkan Yenileme `fx_kalkan_yenileme.gd` + `_spawn_burst` mavi, dosta `fx_shard_stream` kırıntıları, `fx_melek_shield_aura` (mavi sütun)
Yeni efektler (Melek'in kendi kimliğinden: altın hale + kanat/tüy):
  Q  HALE İNİŞİ: başındaki halenin altın bir kopyası yükselir, genişler ve vücudundan aşağı iner (arka yarısı karakterin arkasında,
     ön yarısı önünde); ayağa değince yerde kırılan 2:1 altın halka + göğsünde yeşil artı (anlık %15). Kanadından altın bir
     "kutsama tüyü" kavis çizip dosta uçar, başının üstünde HALEYE dönüşür (dost 6 sn hale taşır = bağ kimde okunur).
     Her tik (1 sn): Melek'in halesi parlar, göğsünden yeşil-altın bir ışık tanesi dosta akar; ikisinde de küçük yeşil artı yükselir.
     Melek'in halesi süre boyunca dış ışıkla parlar, üstünde bir ışıltı döner. Bitişte dostun halesi kırılıp ışıltılarla dökülür.
  E  MANA KANATLARI: Melek'in arkasında iki büyük, açık mavi hayalet kanat açılır, bir kez çırpar, tüylerine dağılır: üç tüy dosta
     uçar, üçü Melek'in belinin çevresinde 2:1 yörüngeye girer (dostta da üç tüy döner, 6 sn). Her tik (1 sn): tüyler parlar, her
     biri gövdeye bir mana kristali bırakır, belin çevresinde İÇE daralan mavi halka (kalkan dolar) + göğüste kristal parıltısı.
     Bitişte tüyler sarmal çizip yükselir ve söner.
Renk dili: Q = hale altını (HOLY) + şifa yeşili (LIFE, oyundaki can sayısı rengi); E = mana kalkanı mavisi (MANA, pasif/kalkan
çubuğu mavisi), hayalet kanat MANA'nın açık tonları + koyu mavi kontur. Çizim dili tools/pixfx.py (dolu kütle, 5 ton
[kontur, koyu, orta, açık, parlak], 1 px kontur, uçlar incelir).
Ölçek: 1 GIF pikseli = 1 Melek sanat pikseli = 2,2368375 x 0,8075 x 0,5 = 0,903 dünya birimi (Elara/Büyücü ile aynı). Dost =
Şovalye (aynı karakter ölçeği). Gerçek bağ menzili 300 dünya (~330 px); GIF'te dost ~84 px (~76 dünya) uzakta. 6 sn süre GIF'te
kısaltıldı: 3 tik gösteriliyor (1 tik = 15 kare = 1 sn).
Çıktı: out/melek_q.gif, out/melek_e.gif
Kullanım (proje kökünden): python -I tools/proto_20261017/gen_melek_fx.py
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.normpath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(HERE, 'out')
os.makedirs(OUT, exist_ok=True)
sys.path.insert(0, os.path.join(PROJECT, 'tools'))
sys.path.insert(0, os.path.join(PROJECT, 'tools', 'proto_20261012'))
sys.path.insert(0, os.path.join(PROJECT, 'tools', 'proto_20261016'))
import pixfx as P  # noqa: E402
import gen_elara_nisanci as EL  # noqa: E402  (strip, seg_mask, BAYER)
from gen_matthew_simsek import comp, font, grass, ground_shadow  # noqa: E402

TAU = math.tau
## [kontur, koyu, orta, açık, parlak]
HOLY = [(92, 58, 18), (186, 130, 36), (240, 194, 72), (255, 230, 140), (255, 252, 222)]  ## hale altını (sprite'taki hale)
LIFE = [(22, 64, 30), (46, 142, 60), (96, 208, 98), (178, 248, 160), (242, 255, 230)]  ## şifa yeşili
MANA = [(18, 34, 88), (40, 88, 186), (86, 148, 242), (166, 208, 255), (238, 248, 255)]  ## mana kalkanı mavisi
GHOST = [(34, 62, 140), (110, 160, 236), (166, 208, 255), (210, 234, 255), (246, 252, 255)]  ## hayalet kanat (MANA'nın açığı)
CREAM = P.CREAM
FEET = 40  ## karede ayak satırı (Melek + Şovalye idle, ölçüldü: bbox alt 40)
HALO = (2.0, -35.5, 3.5, 1.0)  ## Melek idle aşağı karesinde hale: merkez (cx+2, feet-35,5), rx 3,5, ry 1 (ölçüldü)
CHEST = -20  ## göğüs yüksekliği (feet'ten)
WAIST = -13


# ====================================================================== karakterler / ortak
def _sheet(ch, name='idle'):
    return Image.open(os.path.join(PROJECT, 'assets', 'characters', ch, 'sheets', name + '.png')).convert('RGBA')


MEL = _sheet('melek')  ## 4 sütun; satırlar: aşağı, sol, sağ, yukarı
ALLY = _sheet('sovalye')


def put_char(dst, sh, f, cx, feet, row=0):
    ground_shadow(dst, cx, feet + 1)
    col = (f // 4) % 4
    comp(dst, sh.crop((col * 48, row * 48, col * 48 + 48, row * 48 + 48)), cx - 24, feet - FEET)


def layer(W, H):
    return P.Canvas(W, H)


def cc(img, cv):
    comp(img, cv.image())


def fade_cv(cv, level):
    """Bayer ile seyreltme (alfa yok): level 1 tam, 0 yok."""
    if level >= 1.0:
        return
    bay = np.tile(EL.BAYER, (cv.h // 4 + 1, cv.w // 4 + 1))[:cv.h, :cv.w]
    cv.rgba[bay >= max(level, 0.0), 3] = 0


def save(name, frames, ms, label, scale=4):
    f = font(15)
    big = []
    for fr in frames:
        im = fr.convert('RGB').resize((fr.width * scale, fr.height * scale), Image.NEAREST)
        d = ImageDraw.Draw(im)
        for i, line in enumerate(label.split('\n')):
            d.text((9, 7 + i * 19), line, fill=(20, 30, 14), font=f)
            d.text((8, 6 + i * 19), line, fill=(250, 246, 226), font=f)
        big.append(im.quantize(colors=220, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE))
    big[0].save(os.path.join(OUT, name), save_all=True, append_images=big[1:], duration=ms, loop=0, disposal=1)


# ====================================================================== ilkeller
def ring(back, front, cx, cy, rx, ry, pal, thick=2, keep=None, bright=False, edge=None):
    """İnce elips halka (hale): üst yarı (uzak) `back`'e, alt yarı (yakın) `front`'a; alt kenarı bir ton koyu (kalınlık).
    keep(a) False dönen açılar çizilmez (kırılma). bright: tamamı en açık tonlar (parlama anı). edge: 1 px kontur rengi
    (sprite'taki hale gibi; içi de konturlanır, halka çubuk gibi değil halka gibi okunur)."""
    if edge is not None:
        tb, tf = P.Canvas(back.bw, back.bh), P.Canvas(back.bw, back.bh)
        ring(tb, tf, cx, cy, rx, ry, pal, thick, keep, bright)
        o = P.outline_of(tb.filled() | tf.filled())
        _, Y = tb.grid()
        tb.put(o & (Y < cy), edge)
        tf.put(o & (Y >= cy), edge)
        for src, dst in ((tb, back), (tf, front)):
            m = src.filled()
            dst.rgba[m] = src.rgba[m]
        return
    n = int(max(rx, ry) * 9) + 24
    for i in range(n):
        a = TAU * i / n
        if keep is not None and not keep(a):
            continue
        s = math.sin(a)
        x, y = cx + math.cos(a) * rx, cy + s * ry
        tgt = front if s >= 0 else back
        if bright:
            col, under = (CREAM if s > 0.2 else pal[4]), pal[3]
        else:
            col = pal[4] if s > 0.55 else (pal[3] if s > -0.35 else pal[2])
            under = pal[2] if s > 0 else pal[1]
        if thick >= 2:
            tgt.px(x, y + 1, under)
        tgt.px(x, y, col)


def crack_keep(seed, k, lobes=5):
    """Halka kırılması: k 0..1 arttıkça boşluklar büyür (parçalar hilal gibi incelir)."""
    thr = 1.0 - 1.8 * k

    def keep(a):
        return math.sin(a * lobes + seed) * 0.6 + math.sin(a * 3 + seed * 2) * 0.4 < thr
    return keep


def plus(cv, x, y, r, pal):
    """Dolu artı (iyileşme işareti): r>=3 -> 3 px kollu, aksi halde 1 px; krem çekirdek, 1 px koyu kontur."""
    X, Y = cv.grid()
    xc, yc = math.floor(x) + 0.5, math.floor(y) + 0.5
    hw = 1.01 if r >= 3 else 0.01
    dx, dy = np.abs(X - xc), np.abs(Y - yc)
    m = ((dx <= hw) & (dy <= r + 0.01)) | ((dy <= hw) & (dx <= r + 0.01))
    cv.put(m, pal[3])
    cv.put(m & ((dx < 0.1) | (dy < 0.1)) & (dx + dy <= r - 0.9), pal[4])
    cv.put(m & (dx < 0.1) & (dy < 0.1), CREAM)
    if r >= 3:  ## alt-sağ kollar bir ton koyu (hacim)
        cv.put(m & (((X > xc + 0.1) & (dy <= hw) & (Y > yc + 0.1)) | ((Y > yc + 0.1) & (dx <= hw) & (X > xc + 0.1))), pal[2])
    cv.put(P.outline_of(m) & ~cv.filled(), pal[0])
    return m


def feather(cv, x, y, ang, L, pal, W=None, edge=None):
    """Tüy: (x, y) = uç, ang = kökten uca yön. Üst bayrak açık, alt bayrak orta ton, sap parlak, uç en parlak; 1 px kontur."""
    W = W if W is not None else max(1.8, L * 0.3)
    c, s = math.cos(ang), math.sin(ang)

    def at(u, v):  ## u: uçtan köke uzaklık, v: dik
        return (x - u * c - v * s, y - u * s + v * c)
    vane = L * 0.82
    na = 8
    side_a = [at(vane * i / na, W * 0.55 * math.sin(math.pi * min(1.0, (i / na) * 1.1 + 0.05)) ** 0.7) for i in range(na + 1)]
    side_b = [at(vane * i / na, -W * 0.42 * math.sin(math.pi * min(1.0, (i / na) * 1.1 + 0.05)) ** 0.7) for i in range(na + 1)]
    spine = [at(0, 0), at(vane, 0)]
    ma = P.poly_mask(cv, spine[:1] + side_a + spine[1:])
    mb = P.poly_mask(cv, spine[:1] + side_b + spine[1:])
    qx0, qy0 = at(vane * 0.9, 0)
    qx1, qy1 = at(L, 0)
    quill = EL.seg_mask(cv, qx0, qy0, qx1, qy1, 1.0)
    sp = EL.seg_mask(cv, x, y, qx0, qy0, 0.8) & (ma | mb)
    m = ma | mb | quill
    if not m.any():
        return m
    X, Y = cv.grid()
    tip = np.hypot(X - x, Y - y) <= max(1.2, L * 0.2)
    far = np.abs((X - x) * (-s) + (Y - y) * c) > W * 0.3  ## bayrağın dış kenarı bir ton koyu (tüy dokusu)
    cv.put(mb, pal[2])
    cv.put(mb & far, pal[1])
    cv.put(ma, pal[3])
    cv.put(ma & far, pal[2])
    cv.put(sp | quill, pal[4])
    cv.put(m & tip, pal[4])
    cv.put(P.outline_of(m) & ~cv.filled(), edge or pal[0])
    return m


def mote(cv, x, y, pal, r=1.6):
    """Işık tanesi: krem çekirdek, açık ton kenar (kontursuz - ışık)."""
    P.disc_flash(cv, x, y, r, core=CREAM, rim=pal[3])


def arc_pt(p0, p1, t, lift):
    """p0 -> p1 kavisli yol (ortada `lift` px yukarı)."""
    return (P.lerp(p0[0], p1[0], t), P.lerp(p0[1], p1[1], t) - math.sin(math.pi * t) * lift)


def trail(cv, pts, pal, w=2.6):
    """Noktalar boyunca incelen dolu iz (kuyruk ince, baş kalın)."""
    n = len(pts)
    for i in range(n - 1):
        EL.strip(cv, pts[i], pts[i + 1], w * (i / n) + 0.3, w * ((i + 1) / n) + 0.3, pal, outline=False)


def diamond(cv, x, y, a, b, pal):
    """Mana kristali (eşkenar dörtgen): sol-üst açık, sağ-alt orta, kontur."""
    X, Y = cv.grid()
    xc, yc = math.floor(x) + 0.5, math.floor(y) + 0.5
    m = np.abs(X - xc) / a + np.abs(Y - yc) / b <= 1.0
    cv.put(m, pal[2])
    cv.put(m & ((X - xc) + (Y - yc) * (a / b) < 0), pal[3])
    cv.put(m & (np.abs(X - xc) < 0.6) & (np.abs(Y - yc) < b * 0.5), pal[4])
    cv.put(P.outline_of(m) & ~cv.filled(), pal[0])


# ====================================================================== Q - Can Basma (Hale İnişi)
def scene_q():
    W, H = 176, 100
    mx, ax, feet = 54, 138, 90
    hx, hy, hrx, hry = mx + HALO[0], feet + HALO[1], HALO[2], HALO[3]
    ahx, ahy = ax + 0.5, feet - 37.0  ## dostun halesi (Şovalye kafa üstü feet-32)
    F = 68
    TICKS = (26, 41, 56)
    END = 60
    frames = []
    for f in range(F):
        img = grass(W, H, 220)
        gv, back, front, top = layer(W, H), layer(W, H), layer(W, H), layer(W, H)
        aback, afront = layer(W, H), layer(W, H)

        ## --- Melek'in halesi süre boyunca parlar (dış ışık + dönen ışıltı)
        if 1 <= f < END + 4:
            lvl = 1.0 if f < END else 1.0 - (f - END) / 4.0
            gl = layer(W, H)
            ring(gl, gl, hx, hy, hrx + 1.4, hry + 0.9, HOLY, thick=1)
            a = f * 0.55
            P.star(gl, hx + math.cos(a) * (hrx + 1.4), hy + math.sin(a) * (hry + 0.9), 1, P.WHITE, HOLY[4])
            fade_cv(gl, lvl)
            top.rgba[gl.filled()] = gl.rgba[gl.filled()]

        ## --- 1) hale kopyası yükselir, genişler, vücuttan aşağı iner
        k = f
        if 0 <= k <= 9:
            if k <= 2:
                t = k / 2.0
                cy, rx = hy - 4 * t, hrx + 3 * t
            else:
                t = P.ease_out(min(1.0, (k - 2) / 6.0))
                cy, rx = P.lerp(hy - 4, feet, t), P.lerp(hrx + 3, 13, t)
            br = k in (0, 1)
            ring(back, front, hx if k < 3 else P.lerp(hx, mx, 0.6), cy, rx, rx * 0.38, HOLY, thick=2, bright=br, edge=HOLY[1])
            if k >= 3:  ## geçtiği yerde yeşil ışıltı bırakır
                for j in range(3):
                    aa = j * 2.1 + k
                    front.px(mx + math.cos(aa) * rx * 0.9, cy - 3 - (j % 2) * 2, LIFE[4] if j == 0 else LIFE[3])
        if 9 <= k <= 16:  ## yerde altın halka genişleyip kırılır
            t = (k - 9) / 7.0
            P.shock_ring(gv, mx, feet, 13 + 10 * P.ease_out(t), 2.2, t, HOLY, 0.36, seed=3, break_from=0.25)
        if 9 <= k <= 10:
            P.disc_flash(gv, mx, feet, 8 - (k - 9) * 3, core=CREAM, rim=HOLY[3], squash=0.36)
        ## anlık can: göğüste büyük yeşil artı (5 kare, yükselip küçülür)
        if 4 <= k <= 11:
            t = (k - 4) / 7.0
            plus(top, mx + 1, feet + CHEST - 2 - 6 * t, 3 if t < 0.6 else 2, LIFE)

        ## --- 2) kutsama tüyü: kanattan dostun başına kavisle uçar, haleye dönüşür
        p0, p1 = (mx + 12, feet - 26), (ahx, ahy - 2)
        if 5 <= f <= 15:
            t = P.ease_out((f - 5) / 10.0) if f < 15 else 1.0
            pts = [arc_pt(p0, p1, max(0.0, t - d * 0.05), 22) for d in range(5, -1, -1)]
            trail(top, pts[:-1], HOLY, 1.8)
            x, y = pts[-1]
            dx, dy = arc_pt(p0, p1, min(1.0, t + 0.04), 22)
            a = math.atan2(dy - y, dx - x) + 0.35 * math.sin(f * 0.9)
            feather(top, x + math.cos(a) * 5, y + math.sin(a) * 5, a, 12, HOLY, W=4.4)
        if f == 16:
            P.star(top, ahx, ahy, 4, P.WHITE, HOLY[3], diag=True)
            plus(top, ax + 1, feet + CHEST - 2, 3, LIFE)

        ## --- 3) dostun halesi (6 sn): doğar, süzülür, tiklerde parlar, bitişte kırılır
        if 16 <= f < END + 6:
            bob = round(math.sin(f * 0.4) * 0.8)
            if f <= 19:
                rx = P.lerp(1.0, 4.5, P.ease_out((f - 16) / 3.0))
                ring(afront, afront, ahx, ahy + bob, rx, rx * 0.4, HOLY, thick=1, bright=True, edge=HOLY[0])
            elif f < END:
                tk = any(0 <= f - (t0 + 5) <= 1 for t0 in TICKS)
                ring(afront, afront, ahx, ahy + bob, 4.5, 1.8, HOLY, thick=1, bright=tk, edge=HOLY[0])
                if f % 9 == 0:  ## tek tük altın damla
                    afront.px(ahx - 2 + (f % 5), ahy + 4, HOLY[3])
            else:  ## kırılıp ışıltılarla dökülür
                t = (f - END) / 5.0
                ring(afront, afront, ahx, ahy + bob, 4.5 + t * 2, 1.8 + t * 0.5, HOLY, thick=1, keep=crack_keep(1.3, t, 4),
                     edge=HOLY[0])
                for j in range(4):
                    sx = ahx - 5 + j * 3.3
                    P.star(top, sx, ahy + 2 + t * (8 + j * 2), 1 if j % 2 else 0, HOLY[4], HOLY[3])

        ## --- 4) tikler: Melek'in halesi parlar, ışık tanesi dosta akar, ikisinde küçük artı
        for t0 in TICKS:
            k = f - t0
            if 0 <= k <= 1:
                ring(top, top, hx, hy, hrx + 0.5, hry + 0.4, HOLY, thick=1, bright=True)
            if 0 <= k <= 7:  ## Melek'in kendi tiki
                plus(top, mx - 6 + (t0 % 3), feet + CHEST - 1 - k * 1.4, 2 if k < 5 else 1, LIFE)
            if 0 <= k <= 5:
                q0, q1 = (mx + 3, feet + CHEST), (ax - 2, feet + CHEST)
                t = k / 5.0
                pts = [arc_pt(q0, q1, max(0.0, t - d * 0.08), 9) for d in range(4, -1, -1)]
                trail(top, pts, LIFE, 2.2)
                mote(top, *pts[-1], LIFE if k < 4 else HOLY)
            if 5 <= k <= 12:  ## dostta
                plus(top, ax + 6 - (t0 % 2) * 2, feet + CHEST - 1 - (k - 5) * 1.4, 2 if k < 10 else 1, LIFE)

        cc(img, gv)
        cc(img, back)
        cc(img, aback)
        put_char(img, MEL, f, mx, feet)
        put_char(img, ALLY, f + 2, ax, feet)
        cc(img, front)
        cc(img, afront)
        cc(img, top)
        frames.append(img)
    return frames


# ====================================================================== E - Kalkan Yenileme (Mana Kanatları)
WING_OPEN = [(-64, 19), (-42, 23), (-20, 24), (3, 20), (24, 14)]  ## (açı derece, boy) sağ kanat, açık
WING_FOLD = [(52, 7), (60, 8), (68, 8), (76, 7), (84, 6)]


def wing(cv, px, py, side, spread, droop=0.0, pal=GHOST):
    """Hayalet kanat: kökten yelpaze 5 tüy + kök örtüsü. side +1 sağ, -1 sol; spread 0 kapalı .. 1 açık; droop: çırpma (derece)."""
    tips = []
    for (ao, lo), (af, lf) in zip(WING_OPEN, WING_FOLD):
        a = math.radians(P.lerp(af, ao, spread) + droop)
        L = P.lerp(lf, lo, spread)
        if side < 0:
            a = math.pi - a
        tips.append((px + math.cos(a) * L, py + math.sin(a) * L, a, L))
    for (x, y, a, L) in tips:
        feather(cv, x, y, a, L, pal, W=max(2.6, L * 0.25), edge=pal[0])
    ## kök örtüsü (kısa, yuvarlak tüy kümesi)
    ca = math.radians(-18 + droop * 0.5)
    if side < 0:
        ca = math.pi - ca
    L = P.lerp(5, 11, spread)
    feather(cv, px + math.cos(ca) * L, py + math.sin(ca) * L, ca, L + 1, pal, W=6.0, edge=pal[0])
    return tips


def orbit_pts(cx, cy, rx, ry, n, a0):
    out = []
    for i in range(n):
        a = a0 + i * TAU / n
        x, y = cx + math.cos(a) * rx, cy + math.sin(a) * ry
        tang = math.atan2(math.cos(a) * ry, -math.sin(a) * rx)
        out.append((x, y, tang, math.sin(a)))
    return out


def scene_e():
    W, H = 176, 100
    mx, ax, feet = 54, 138, 90
    F = 70
    TICKS = (28, 43, 58)
    END = 62
    ORX, ORY = 14.0, 4.6
    frames = []
    for f in range(F):
        img = grass(W, H, 300)
        gv, back, front, top = layer(W, H), layer(W, H), layer(W, H), layer(W, H)

        ## --- 1) kanatlar açılır (0-4), bekler, bir kez çırpar (6-10), tüylere dağılır (11-15)
        piv = [(mx - 3, feet - 25, -1), (mx + 3, feet - 25, 1)]
        if f <= 10:
            spread = P.ease_out(min(1.0, f / 4.0))
            droop = 0.0
            if 6 <= f <= 10:
                u = (f - 6) / 4.0
                droop = 34 * math.sin(math.pi * u)
                spread = 1.0 - 0.3 * math.sin(math.pi * u)
            wl = layer(W, H)
            for (px, py, side) in piv:
                wing(wl, px, py, side, spread, droop)
            if f <= 1:  ## açılış parlaması (siluet açık tonda)
                wl.rgba[wl.filled(), :3] = GHOST[4]
            back.rgba[wl.filled()] = wl.rgba[wl.filled()]
            if 8 <= f <= 10:  ## çırpma rüzgârı: kanat uçlarından aşağı iki kavis
                for side in (-1, 1):
                    P.arc_band(gv, mx + side * 20, feet - 4, 9, math.radians(200 if side < 0 else -20) - 0.9,
                               math.radians(200 if side < 0 else -20) + 0.3, 1.6, 0.6, GHOST, squash=0.5, outline=False)
        if 0 <= f <= 7:  ## yerde mavi halka
            t = f / 7.0
            P.shock_ring(gv, mx, feet, 10 + 14 * P.ease_out(t), 2.2, t, MANA, 0.36, seed=5, break_from=0.35)

        ## dağılan tüyler: sol kanadın 1-3'ü Melek'in yörüngesine, sağ kanadın 1-3'ü dosta, uçtakiler söner
        free = []
        if 11 <= f <= 22:
            for (px, py, side) in piv:
                tips = wing(layer(W, H), px, py, side, 1.0, 0.0)
                for j, (x, y, a, L) in enumerate(tips):
                    if j in (0, 4):
                        k = (f - 11) / 4.0
                        if k <= 1.0:
                            free.append(('fade', x + math.cos(a) * 6 * k, y + math.sin(a) * 6 * k - 3 * k, a, L * (1 - k), True))
                        continue
                    slot = j - 1
                    if side < 0:  ## Melek yörüngesine
                        k = min(1.0, (f - 11) / 5.0)
                        ox, oy, tang, _ = orbit_pts(mx, feet + WAIST, ORX, ORY, 3, f * 0.32)[slot]
                        cx_, cy_ = x - math.cos(a) * L * 0.5, y - math.sin(a) * L * 0.5
                        if k < 1.0:
                            free.append(('fly', P.lerp(cx_, ox, P.ease_out(k)), P.lerp(cy_, oy, P.ease_out(k)),
                                         P.lerp(a, tang, k), P.lerp(L, 7, P.ease_out(min(1.0, k * 2.5))), k < 0.7))
                    else:  ## dosta kavisle uçar
                        k = min(1.0, (f - 11 - slot) / 8.0)
                        if 0 <= k < 1.0:
                            ox, oy, tang, _ = orbit_pts(ax, feet + WAIST, ORX - 2, ORY - 0.6, 3, f * 0.32)[slot]
                            cx_, cy_ = x - math.cos(a) * L * 0.5, y - math.sin(a) * L * 0.5
                            p = arc_pt((cx_, cy_), (ox, oy), P.ease_out(k), 16 + slot * 3)
                            pp = arc_pt((cx_, cy_), (ox, oy), max(0.0, P.ease_out(k) - 0.12), 16 + slot * 3)
                            trail(top, [arc_pt((cx_, cy_), (ox, oy), max(0.0, P.ease_out(k) - d * 0.05), 16 + slot * 3)
                                        for d in range(4, -1, -1)], MANA, 2.0)
                            free.append(('fly', p[0], p[1], math.atan2(p[1] - pp[1], p[0] - pp[0]),
                                         P.lerp(L, 8, P.ease_out(min(1.0, k * 2.0))), k < 0.3))
        ## sönen uç tüyler küçülerek biter (Bayer seyreltme çimende çizgili görünüyordu); kanattan yeni ayrılan tüyler
        ## Melek'in ARKASINDA kalır (kanat arkada), yüzünün önünden geçmez
        for kind, x, y, a, L, behind in free:
            if L < 2.5:
                continue
            fl = layer(W, H)
            feather(fl, x + math.cos(a) * L * 0.5, y + math.sin(a) * L * 0.5, a, L, GHOST if kind == 'fade' else MANA,
                    W=max(2.4, L * 0.28))
            dst = back if behind else top
            dst.rgba[fl.filled()] = fl.rgba[fl.filled()]

        ## --- 2) yörüngede dönen tüyler (Melek 16'dan, dost 20'den itibaren), tiklerde parlar + kristal bırakır
        for who, cx, start, rx, ry in (('m', mx, 16, ORX, ORY), ('a', ax, 19 + 2, ORX - 2, ORY - 0.6)):
            if not (start <= f < END + 8):
                continue
            cy = feet + WAIST
            lift = 0.0
            Lf = 7.0
            spin = f * 0.32
            if f >= END:  ## bitiş: sarmal çizip yükselir, söner
                u = (f - END) / 8.0
                lift = 22 * u * u
                rx, ry = rx * (1 - 0.5 * u), ry * (1 - 0.5 * u)
                Lf = 7 - 5 * u
                spin += (f - END) * 0.25
            flash = any(0 <= f - t0 <= 1 for t0 in TICKS)
            for (x, y, tang, s) in orbit_pts(cx, cy - lift, rx, ry, 3, spin):
                fl = layer(W, H)
                feather(fl, x + math.cos(tang) * Lf * 0.5, y + math.sin(tang) * Lf * 0.5, tang, Lf,
                        [MANA[1], MANA[3], MANA[4], CREAM, P.WHITE] if flash else MANA, W=2.8)
                tgt = front if s >= 0 else back
                tgt.rgba[fl.filled()] = fl.rgba[fl.filled()]
            ## tik: kristaller gövdeye akar, içe daralan halka, göğüste parıltı
            for t0 in TICKS:
                k = f - t0
                if 1 <= k <= 3:
                    for (x, y, tang, s) in orbit_pts(cx, cy, rx, ry, 3, t0 * 0.32 + 0.32):
                        t = (k - 1) / 2.0
                        dxy = (P.lerp(x, cx, t), P.lerp(y - 2, feet + CHEST, t))
                        diamond(front if s >= 0 else top, dxy[0], dxy[1], 1.5, 2.5, MANA)
                if 2 <= k <= 6:
                    t = (k - 2) / 4.0
                    R = P.lerp(18, 5, P.ease_out(t))
                    ring(back, front, cx, cy, R, R * 0.36, MANA, thick=2, keep=crack_keep(2.0 + t0, max(0.0, t - 0.5) * 1.6, 4),
                         bright=(k == 2))
                if 3 <= k <= 5:
                    P.star(top, cx + 1, feet + CHEST - 1, 3 - (k - 3), P.WHITE, MANA[3], diag=(k == 3))

        cc(img, gv)
        cc(img, back)
        put_char(img, MEL, f, mx, feet)
        put_char(img, ALLY, f + 2, ax, feet)
        cc(img, front)
        cc(img, top)
        frames.append(img)
    return frames


def main():
    save('melek_q.gif', scene_q(), 66,
         'Q  Can Basma: hale iner + kutsama tüyü dosta hale olur, her tikte ışık akar\n(6 sn / 6 tik - burada 3 tik)')
    save('melek_e.gif', scene_e(), 66,
         'E  Kalkan Yenileme: mana kanatları açılıp tüylere dağılır, tüyler döner,\nher tikte kristaller kalkana işler (6 sn - burada 3 tik)')
    print('tamam:', sorted(n for n in os.listdir(OUT) if n.startswith('melek')))


if __name__ == '__main__':
    main()
