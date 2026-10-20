# -*- coding: utf-8 -*-
"""GÖKKUŞAĞI ASASI görünüş + ışın efekti prototipleri (2026-10-19, oyuna bağlı DEĞİL). Kullanıcı: "evet tamam silah için görünüş ve
efekt prototiplerine başlayalım 4 adet".

Silah (onaylanan öneri): hedefe kesintisiz parıltılı lazer ışını, 0,5 sn'de bir vuruş (saniyede %150 SG), ışın ilk düşmanda durur.
Özellik GÖZ KAMAŞTIRAN IŞIK: aynı düşmanda 3 sn kesintisiz ışın -> 1,5 sn kamaşma (saldıramaz, yalpalar); gösterge YOK, ışının kendisi
tuttukça kalınlaşır/parlaklaşır. Final GÖKKUŞAĞI MIZRAĞI: ışın yolundaki herkesi delip geçer (menzil 168), delinenlerin hepsi kamaşır.

Dört yön (her biri asa + ışın; asa Zanaatkâr merdiveni: 1 Paslı / 2 Demir / 3 Çelik / 4 Kara Çelik + kırmızı püskül / 5 Yadigâr altın + lal):
  A Prizma        - uçta İLERİ bakan üçgen cam prizma, metal pençe tutar; ışın uçta BEYAZ çıkar, yol boyunca 6 renge AYRIŞIR (yan yana bantlar).
  B Kemer         - uçta küçük gökkuşağı kemeri (∩, renk bantları) + kemer ayaklarında bulut; ışın KIVRILAN KURDELE (6 bant, dönerken arkası koyu).
  C Damla Değneği - çoban değneği gibi kıvrık uç, ucunda asılı gökkuşağı DAMLASI; ışın krem çekirdek + akan renk dilimleri + PARILTI tanecikleri.
  D Vitray Gül    - uçta 6 dilimli vitray cam disk (kurşun çerçeve); ışın TEK RENK, her 0,5 sn vuruşta atımla sıradaki renge döner
                    (6 renk = 3 sn = kamaşma, tur sayaç gibi okunur).
Kamaşma (hepsinde aynı): yaratıkta beyaz parlama + 6 renkli halka genişleyip kırılır + başının üstünde 3 dönen yıldız, yaratık yalpalar.

Ölçek: asa sanat pikseli 0,575 dünya px (weapon_tier_art.gd WORLD_PX), ışın pikseli 1 dünya px (Yıldırım ışını ile aynı), sahne 1080p
(zoom 2 -> 1 dünya px = 2 ekran px), karakter Şovalye, hedef Slime, asa HÜCUM takibiyle tepe slotunda hedefe nişanlı (asa_partikul_proto).
Çıktılar (out/gokkusagi/): gk_asalar.png (4 yön x 5 kademe, x3), gk_oyun.png (oyun ölçeği L1/L3/L5 karakter yanında, x2),
gk_<A..D>.gif (sol temel L3: 3 sn tut -> kamaşma; sağ final L5: delen ışın, 3 slime).
Çalıştırma: python tools/proto_20261019/gokkusagi_proto.py [asa|gif|A|B|C|D]   (argümansız: hepsi)
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import asa_partikul_proto as AP  # noqa: E402  (proto_20261017 + proto_20261016 yollarını da ekler)
import silah_takip_proto as T  # noqa: E402
from silah_takip_proto import blit2, ellipse, WPP, CHAR_K, SLIME_K, slime_frame  # noqa: E402
from mermi_proto import label  # noqa: E402
from bicak_proto import header, stack_v, save_gif  # noqa: E402
import silah_zanaat_proto as Z  # noqa: E402
import asa_proto48 as E  # noqa: E402
from silah_proto48 import Cv, frame, LV, P, hx, spike, N  # noqa: E402

OUT = os.path.join(HERE, "out", "gokkusagi")
TA = Z.TA
bar, shiny, tassel, scr, staff_base = Z.bar, Z.shiny, Z.tassel, Z.scr, Z.staff_base

# ------------------------------------------------------------------ paletler (7 ton, 0 = dış çizgi)
for _k, _v in {
    "R_red": "#2a0a0c #5a1418 #8a2422 #b83a30 #d85a44 #f08a6a #ffd8c8",
    "R_orange": "#2c1206 #5e2a0c #8e4614 #c0661e #e08a30 #f6b25a #ffe6c0",
    "R_yellow": "#2e2406 #5e4c0e #8e7418 #c0a024 #e2c63c #f6e270 #fffbd0",
    "R_green": "#0c2410 #1a4a20 #2a6e30 #3e9442 #5cb45a #8ed486 #dcf6d4",
    "R_blue": "#0a1a30 #163a62 #22588e #3278b8 #4e9ad6 #82c0ee #dcf0ff",
    "R_violet": "#1a0c2e #36185a #522888 #6e3cb0 #8e5ad0 #b488ea #eedcff",
    "R_prism": "#1c2430 #3a4a5c #5e7288 #8aa0b4 #b4c8d8 #dce8f0 #ffffff",
    "R_quartz": "#26282c #4a4e54 #6e747a #92989c #b0b4b4 #c8cac6 #e4e4dc",
    "R_cloud": "#3a3428 #6e665a #9a9282 #c0b8a6 #dcd6c6 #f0ece0 #ffffff",
    "R_archol": "#2a1a14 #2a1a14 #2a1a14 #2a1a14 #2a1a14 #2a1a14 #2a1a14",
}.items():
    P[_k] = [hx(c) for c in _v.split()]

RB_MATS = ["R_red", "R_orange", "R_yellow", "R_green", "R_blue", "R_violet"]
SPECTRUM = {2: ["R_red", "R_blue"], 3: ["R_red", "R_yellow", "R_blue"], 4: ["R_red", "R_yellow", "R_green", "R_blue"],
            5: ["R_red", "R_orange", "R_yellow", "R_green", "R_blue"], 6: RB_MATS}
SM = ["", "A_wood", "A_wood", "A_dwood", "A_black", "A_dwood"]  # gövde
TR = ["", "A_iron", "A_iron", "A_brass", "A_silver", "A_gold"]  # süs metali (L1 ip/ahşap ayrıca)


def wood_tex(m):
    return E.grain if m.endswith("wood") else None


def sab(x, y):
    """Ekran (48x48) -> (a, b)."""
    return E.ab(x, y)


def rel_idx(idx, lv, lo=2):
    return max(lo, min(6, idx - (1 if lv == 1 else 0)))


# ------------------------------------------------------------------ A PRİZMA
def prism_plate(c, base_a, apex_a, half_w, band_s, n):
    """İleri bakan üçgen cam prizma; n renk bandı uca doğru yelpaze gibi daralır (taban %22'si ve kenar eğimi cam rengi)."""
    mats = SPECTRUM.get(n, [])

    def ptex(idx, a, b, x, y, d):
        fa = (a - base_a) / (apex_a - base_a)
        if n == 0 or fa < 0.22 or d < 0.7:
            return idx
        half = band_s * (1.0 - fa) * 1.0 + 0.35
        u = (b / half + 1.0) * 0.5
        k = int(max(0, min(n - 1, math.floor(u * n))))
        return P[mats[k]][max(3, min(6, idx + 1))]
    c.plate([(apex_a, 0.0), (base_a, -half_w), (base_a, half_w)], "R_prism", bevel=1.1, shine=0.45, tex=ptex)


def A_prism_fork(c):
    """L1 "Çatallı Dal" (madde 320; eski L1 = gri kuvars üçgen + ip sargısı mızrak ucu gibi okunuyordu): sap tepede ikiye ayrılır,
    iki ahşap kol 3 renkli prizmayı yanlardan halka gibi kavrar, prizmanın ucu halkadan çıkar (ışın + weapon_tip ucu orası)."""
    fa = 5.0
    staff_base(c, 1, LV(1, -27, -29), fa, SM[1], LV(1, 1.3, 1.45), tex=wood_tex(SM[1]))
    apex_a = fa + 3.6 + 9.8
    prism_plate(c, fa + 3.6, apex_a, 4.2, 4.2, 3)
    for sg in (-1, 1):
        c.tube([(fa - 0.4, sg * 0.6), (fa + 2.0, sg * 3.6), (fa + 5.4, sg * 5.0), (fa + 9.0, sg * 4.6), (fa + 11.0, sg * 3.2)],
               (1.05, 0.6), SM[1], tex=wood_tex(SM[1]), shine=0.35)
    c.tube([(fa - 3.4, 0), (fa - 0.6, 0)], 1.6, "A_rope", tex=E.wrap, shine=0.15)
    c.glint(apex_a - 1.4, -0.6, "R_prism", 6)


def A_prism(c, lv):
    if lv == 1:
        A_prism_fork(c)
        return
    pe = LV(lv, -27, -29)
    sm = SM[lv]
    cm = ["", "A_rope", "A_iron", "A_brass", "A_silver", "A_gold"][lv]
    s = [0, 4.6, 5.4, 6.2, 6.9, 7.5][lv]
    hc = [0, 15.0, 15.5, 16.0, 16.3, 16.6][lv]
    base_a, apex_a = hc - s * 0.7, hc + s * 1.25
    staff_base(c, lv, pe, base_a - 1.0, sm, LV(lv, 1.3, 1.45), tex=wood_tex(sm))
    prism_plate(c, base_a, apex_a, s * 1.02, s, [0, 0, 3, 4, 6, 6][lv])
    # pençe: tabandan köşelere, köşeden kenar boyunca
    for sg in (-1, 1):
        c.tube([(base_a - 2.0, sg * 0.5), (base_a - 0.5, sg * (s * 1.02 + 0.3)), (base_a + s * 0.75, sg * (s * 0.62 + 0.25))],
               0.55 if lv < 4 else 0.62, cm, shine=0.45)
    bar(c, base_a - 3.2, base_a - 1.4, (1.35, 1.75), cm, shine=0.45)
    if lv == 4:
        tassel(c, base_a - 2.4, 1.6, "A_cloth", cord="A_silver")
    if lv == 5:
        shiny(c, base_a - 2.3, -1.5, 0.8, "A_garnet")
        c.glint(*sab(*E.xy(apex_a - 1.6, -0.6)), "R_prism", 6)
    if lv >= 3:
        c.glint(*sab(*E.xy(base_a + 0.9, -s * 0.55)), "R_prism", 6)


# ------------------------------------------------------------------ B KEMER
def B_arch(c, lv):
    pe = LV(lv, -27, -29)
    sm = SM[lv]
    tr = ["", "A_wood", "A_iron", "A_brass", "A_silver", "A_gold"][lv]
    hc = [0, 12.0, 12.2, 12.4, 12.6, 12.8][lv]
    R = [0, 6.0, 6.8, 7.6, 8.3, 9.0][lv]
    bw = [0, 1.5, 1.4, 1.25, 1.15, 1.1][lv]
    nb = [0, 3, 4, 5, 6, 6][lv]
    mats = SPECTRUM[nb]
    staff_base(c, lv, pe, hc - 1.0, sm, LV(lv, 1.3, 1.45), tex=wood_tex(sm))
    hx_, hy_ = E.xy(hc, 0.0)
    cx, cy = hx_ + 0.5, hy_ - 1.2
    inner = max(1.8, R - nb * bw - 0.3)
    outer_pts = [(cx + R * math.cos(th), cy + R * math.sin(th)) for th in [math.pi + math.pi * k / 24 for k in range(25)]]
    inner_pts = [(cx + inner * math.cos(th), cy + inner * math.sin(th)) for th in [2 * math.pi - math.pi * k / 24 for k in range(25)]]
    poly = [sab(x, y) for x, y in outer_pts + inner_pts]
    step = (R - inner) / nb

    def atex(idx, a, b, x, y, d):
        rr = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
        k = int(max(0, min(nb - 1, math.floor((R - rr) / step))))
        return P[mats[k]][rel_idx(idx + 1, lv, 3)]
    c.plate(poly, "R_archol", bevel=0.9, shine=0.35, tex=atex)
    # taban çubuğu (kemerin ayakları üstünde durur)
    c.tube([sab(cx - R - 0.4, cy + 1.3), sab(cx + R + 0.4, cy + 1.3)], 0.95, tr, shine=0.45, tex=wood_tex(tr))
    if lv >= 2:
        rc = [0, 0, 1.2, 1.5, 1.7, 1.85][lv]
        for sg in (-1, 1):
            c.sphere(sab(cx + sg * (R - 0.6), cy + 0.6), rc, "R_cloud", shine=0.45)
            c.sphere(sab(cx + sg * (R - 0.6 - rc * 1.2), cy + 1.0), rc * 0.75, "R_cloud", shine=0.45)
    if lv == 4:
        tassel(c, *sab(cx + 0.5, cy + 2.4), "A_cloth", cord="A_silver")
    if lv == 5:
        c.sphere(sab(cx, cy - 0.6), 1.5, "A_gold", shine=0.5)
        shiny(c, *sab(cx - 0.2, cy + 3.2), 0.8, "A_garnet")
        c.glint(int(cx - R * 0.55), int(cy - R * 0.75), "R_red", 6)


# ------------------------------------------------------------------ C DAMLA DEĞNEĞİ
def C_crook(c, lv):
    pe = LV(lv, -27, -29)
    sm = SM[lv]
    cap = ["", "A_rope", "A_iron", "A_brass", "A_silver", "A_gold"][lv]
    hc = [0, 7.0, 7.0, 7.0, 7.0, 7.0][lv]
    k = [0, 1.1, 1.2, 1.3, 1.38, 1.45][lv]
    staff_base(c, lv, pe, hc, sm, LV(lv, 1.3, 1.45), tex=wood_tex(sm))
    sx, sy = E.xy(hc, 0.0)
    kx = k * 0.86
    hook = [(0, 0), (1.6 * kx, -4.2 * k), (3.8 * kx, -7.2 * k), (6.8 * kx, -8.0 * k), (9.2 * kx, -6.4 * k), (9.9 * kx, -3.6 * k),
            (9.2 * kx, -1.6 * k)]
    c.tube(scr(sx, sy, hook), (LV(lv, 1.3, 1.45), 0.85), sm, shine=0.35, tex=wood_tex(sm))
    ex, ey = sx + 9.2 * kx, sy - 1.6 * k
    if lv >= 3:
        for f in (0.28, 0.62):
            i = int(f * (len(hook) - 1))
            px_, py_ = hook[i]
            c.sphere(sab(sx + px_, sy + py_), 1.25, cap, shine=0.5)
    # damla
    dl = [0, 6.5, 7.5, 8.5, 9.5, 10.5][lv]
    dw = dl * 0.5
    top = ey + 1.8
    n = [0, 2, 3, 4, 6, 6][lv]
    mats = SPECTRUM[n]
    # gözyaşı: tepe sivri, dip yuvarlak (x = sin θ · sin θ/2, en geniş ~0,77)
    shape = [(math.sin(th) * math.sin(th / 2.0) / 0.77, (1.0 - math.cos(th)) / 2.0) for th in [2.0 * math.pi * i / 28 for i in range(28)]]
    poly = [sab(ex + u * dw, top + v * dl) for u, v in shape]

    def dtex(idx, a, b, x, y, d):
        f = (y + 0.5 - top) / dl
        kk = int(max(0, min(n - 1, math.floor(f * n))))
        return P[mats[kk]][rel_idx(idx + 1, lv, 3)]
    if lv >= 2:
        c.tube([sab(ex, ey + 0.2), sab(ex, top + 0.6)], 0.5, cap, shine=0.4)
    else:
        c.tube([sab(ex, ey + 0.2), sab(ex, top + 0.6)], 0.45, "A_rope", shine=0.2)
    c.plate(poly, "R_archol", bevel=1.0, shine=0.45, tex=dtex)
    if lv >= 2:
        c.sphere(sab(ex, top + 0.4), [0, 0, 0.8, 0.9, 1.0, 1.1][lv], cap, shine=0.5)
    if lv == 4:
        tassel(c, hc - 1.0, 1.4, "A_cloth", cord="A_silver")
    if lv == 5:
        shiny(c, hc - 1.4, -1.5, 0.8, "A_garnet")
        c.glint(int(ex - dw * 0.4), int(top + dl * 0.45), "R_yellow", 6)
    if lv >= 3:
        c.glint(int(ex - dw * 0.35), int(top + dl * 0.62), "R_cloud", 6)


# ------------------------------------------------------------------ D VİTRAY GÜL
def D_rose(c, lv):
    pe = LV(lv, -27, -29)
    sm = SM[lv]
    tr = ["", "A_wood", "A_iron", "A_brass", "A_silver", "A_gold"][lv]
    rr = [0, 5.4, 6.2, 7.0, 7.6, 8.0][lv]
    hc = [0, 14.0, 14.4, 14.8, 15.0, 15.0][lv]
    npane = [0, 3, 4, 6, 6, 6][lv]
    mats = SPECTRUM[npane]
    staff_base(c, lv, pe, hc - rr - 0.6, sm, LV(lv, 1.3, 1.45), tex=wood_tex(sm))
    cx, cy = E.xy(hc, 0.0)
    if lv == 5:
        for i in range(8):
            th = math.radians(22.5 + 45 * i)
            d = (math.cos(th), math.sin(th))
            c.plate(spike(sab(cx + d[0] * (rr - 0.5), cy + d[1] * (rr - 0.5)), sab(cx + d[0] * (rr + 2.0), cy + d[1] * (rr + 2.0)), 0.9,
                          shoulder=0.2), "A_gold", bevel=0.8, shine=0.45)
    poly = [sab(cx + rr * math.cos(th), cy + rr * math.sin(th)) for th in [2 * math.pi * i / 36 for i in range(36)]]
    hub = [0, 1.0, 1.1, 1.2, 1.25, 1.35][lv]
    rot = math.radians(-90.0)

    def rtex(idx, a, b, x, y, d):
        dx, dy = x + 0.5 - cx, y + 0.5 - cy
        r = math.hypot(dx, dy)
        if r > rr - 1.05:
            return P[tr][max(2, min(6, idx))]
        if r < hub:
            return P["A_garnet" if lv == 5 else tr][max(2, min(6, idx + 1))]
        ang = (math.atan2(dy, dx) - rot) % (2 * math.pi)
        sec = ang / (2 * math.pi / npane)
        kk = int(sec) % npane
        fr = sec - int(sec)
        if min(fr, 1 - fr) * (2 * math.pi / npane) * r < 0.5:
            return P["A_black"][2]
        return P[mats[kk]][rel_idx(idx + 1, lv, 3)]
    c.plate(poly, tr, bevel=1.1, shine=0.45, tex=rtex)
    bar(c, hc - rr - 1.9, hc - rr + 0.2, (1.35, 1.8), "A_rope" if lv == 1 else tr, shine=0.45, tex=E.wrap if lv == 1 else None)
    if lv == 4:
        tassel(c, hc - rr - 1.0, 1.7, "A_cloth", cord="A_silver")
    if lv >= 3:
        c.glint(int(cx - rr * 0.45), int(cy - rr * 0.5), "R_cloud", 6)


DIRS = [
    ("A", "Prizma", "uçta ileri bakan cam prizma", "uçta beyaz çıkar, yolda 6 renge ayrışır", A_prism),
    ("B", "Gökkuşağı Kemeri", "renk bantlı kemer + bulutlar", "kıvrılan 6 bantlı kurdele", B_arch),
    ("C", "Damla Değneği", "kıvrık uçta asılı renk damlası", "krem çekirdek + akan renkler + parıltı", C_crook),
    ("D", "Vitray Gül", "6 dilimli vitray cam disk", "her vuruşta atımla sıradaki renge döner", D_rose),
]
ICONS = {}


def build_icons():
    frame("diag")
    for did, _, _, _, fn in DIRS:
        for lv in range(1, 6):
            cv = Cv(lv)
            fn(cv, lv)
            img = cv.render()
            a = img.getchannel("A").point(lambda v: 255 if v == 255 else 0).getbbox()
            if a and (a[0] == 0 or a[1] == 0 or a[2] == N or a[3] == N):
                print("KENAR!", did, lv, a)
            ICONS[(did, lv)] = img
            T.ICON_PX["gk_%s_L%d" % (did, lv)] = np.asarray(img, dtype=np.float32)


def sheet_icons():
    z = 3
    cell = N * z
    lw, gap, top = 210, 12, 34
    W = lw + 5 * (cell + gap) + gap
    H = top + len(DIRS) * (cell + gap) + gap
    im = Image.new("RGB", (W, H), (34, 38, 40))
    d = ImageDraw.Draw(im)
    for lv in range(1, 6):
        label(d, lw + gap + (lv - 1) * (cell + gap) + 4, 10, "%d - %s" % (lv, TA[lv]["name"]), 14)
    for ri, (did, name, asa, isin, _) in enumerate(DIRS):
        y0 = top + ri * (cell + gap)
        label(d, 10, y0 + cell // 2 - 30, "%s · %s" % (did, name), 15)
        label(d, 10, y0 + cell // 2 - 8, asa, 10, (214, 208, 192))
        label(d, 10, y0 + cell // 2 + 8, "ışın: " + isin, 10, (214, 208, 192))
        for lv in range(1, 6):
            x0 = lw + gap + (lv - 1) * (cell + gap)
            bgc = Image.new("RGBA", (cell, cell), (58, 74, 52, 255))
            bgc.alpha_composite(ICONS[(did, lv)].resize((cell, cell), Image.NEAREST))
            im.paste(bgc.convert("RGB"), (x0, y0))
    im.save(os.path.join(OUT, "gk_asalar.png"))
    print("asalar", im.size)


def sheet_game():
    """Oyun ölçeği: Şovalye yanında L1/L3/L5 (tepe slotu, nişansız dinlenme), 1080p, resim x2."""
    z = 2
    view = (262.0, 120.0, 338.0, 222.0)
    rows = []
    for did, name, _, _, _ in DIRS:
        tiles = []
        for lv in (1, 3, 5):
            key = "gk_%s_L%d" % (did, lv)
            F = AP.bg_crop(z, view)
            st = {"t": 0.0, "P": (300.0, 200.0), "V": (0.0, 0.0), "moving": False, "face": (1, 0), "walk_t": 0.0}
            fo = AP.Follow(key, ang=-0.35)
            for _ in range(30):
                pos, rot, tip = fo.step(st, aim=(420.0, 150.0))
            AP.draw_char(F, z, view, st)
            AP.draw_staff(F, z, view, key, pos, rot, st["P"])
            tl = Image.fromarray(np.clip(F, 0, 255).astype(np.uint8), "RGB")
            tiles.append(AP.tile_label(tl, "%s L%d" % (did, lv)))
        rows.append(AP.hstack(tiles))
    body = stack_v([AP.hstack(rows[0:2], gap=10), AP.hstack(rows[2:4], gap=10)], 6)
    hd = header(body.width, "Gökkuşağı Asası · oyun ölçeği (1080p, asa pikseli 0,575 dünya px)", "her yön: L1 · L3 · L5, Şovalye tepe slotunda")
    im = stack_v([hd, body], 0)
    im = im.resize((im.width * 2, im.height * 2), Image.NEAREST)
    im.save(os.path.join(OUT, "gk_oyun.png"))
    print("oyun", im.size)


# ------------------------------------------------------------------ ışın çizimi (1 dünya px ızgara)
def hexf(s):
    return np.array(hx(s), np.float32)


RB = np.array([hx(c) for c in "#f06a5a #f7a24a #f4d85a #86d26e #62b2ec #a87ae6".split()], np.float32)
CREAM = hexf("#fffaf0")
RBL = RB * 0.5 + CREAM * 0.5
RBD = RB * 0.72
BEAM_TX = 1.0
TICK_S = 0.5
HOLD_S = 3.0
DAZE_S = 1.5
LOOP_S = HOLD_S + DAZE_S
RANGE = 168.0


def qa(a):
    return np.ceil(np.clip(a, 0.0, 1.0) * 4.0 - 1e-6) / 4.0


def beam_grid(layer, p0, p1, pad):
    Lr = math.hypot(p1[0] - p0[0], p1[1] - p0[1])
    L = max(1.0, Lr)
    ux, uy = ((p1[0] - p0[0]) / Lr, (p1[1] - p0[1]) / Lr) if Lr > 1e-9 else (1.0, 0.0)
    x0, x1 = min(p0[0], p1[0]) - pad, max(p0[0], p1[0]) + pad
    y0, y1 = min(p0[1], p1[1]) - pad, max(p0[1], p1[1]) + pad
    i0, j0 = layer.tc(x0, y0)
    i1, j1 = layer.tc(x1, y1)
    i0, j0, i1, j1 = max(0, i0), max(0, j0), min(layer.W - 1, i1), min(layer.H - 1, j1)
    I, J = np.meshgrid(np.arange(i0, i1 + 1), np.arange(j0, j1 + 1))
    I, J = I.ravel(), J.ravel()
    wx = layer.x0 + (I + 0.5) * layer.tx
    wy = layer.y0 + (J + 0.5) * layer.tx
    rx, ry = wx - p0[0], wy - p0[1]
    s = rx * ux + ry * uy
    d = -rx * uy + ry * ux
    return I, J, s, d, L


def lay_over(layer, I, J, rgb, a):
    m = a > 0.0
    if not m.any():
        return
    I, J, rgb, a = I[m], J[m], rgb[m], a[m]
    p = layer.a[J, I]
    a1 = a[:, None]
    p[:, :3] = rgb * a1 + p[:, :3] * (1.0 - a1)
    p[:, 3] = a + p[:, 3] * (1.0 - a)
    layer.a[J, I] = p


def shape_mask(s, d, L, w, final):
    """Başta 5 px incelme; temelde yuvarlak uç (hedefte), finalde sivri mızrak ucu (menzil sonu)."""
    tap = np.clip((s + 0.5) / 5.0, 0.35, 1.0)
    w = w * tap
    if final:
        w = w * np.clip((L - s) / 14.0, 0.0, 1.0) ** 0.7
        inside = (s >= -0.5) & (s <= L) & (np.abs(d) <= w + 0.15)
    else:
        inside = (s >= -0.5) & (((s <= L) & (np.abs(d) <= w + 0.15)) | ((s > L) & (d * d + (s - L) ** 2 <= w * w)))
    return inside, np.maximum(w, 0.6)


class Style:
    """Bir yönün ışını + uç parlaması + vuruş patlaması. Durumlu (parıltı tanecikleri) - kareler sırayla çizilir."""

    def __init__(self, did, final, seed):
        self.did = did
        self.final = final
        self.rng = random.Random(seed)
        self.sparks = []

    def width(self, th):
        base = 3.8 if self.final else 3.0
        if th < HOLD_S:
            return base * (0.82 + 0.33 * min(1.0, th / HOLD_S))
        return base * 1.15

    def beam(self, layer, p0, p1, t, th):
        W = self.width(th)
        I, J, s, d, L = beam_grid(layer, p0, p1, W + 3.0)
        inside, w = shape_mask(s, d, L, W, self.final)
        u = d / w
        n = s.shape[0]
        rgb = np.zeros((n, 3), np.float32)
        a = np.where(inside, 1.0, 0.0).astype(np.float32)
        did = self.did
        if did == "A":
            span = 22.0 if self.final else max(24.0, 0.32 * L)
            f = np.floor(np.clip((s - 3.0) / span, 0.0, 1.0) * 4.0) / 4.0
            ww = w * (0.68 + 0.32 * f)
            inside &= np.abs(d) <= ww + 0.15
            uu = np.clip(d / ww, -1.0, 1.0)
            k = np.clip(np.floor((uu + 1.0) * 0.5 * 6.0), 0, 5).astype(np.int32)
            rgb = RB[k] * f[:, None] + CREAM * (1.0 - f[:, None])
            core = np.abs(d) < 0.7
            rgb[core] = rgb[core] * 0.35 + CREAM * 0.65
            a = np.where(inside, np.where(np.abs(uu) > 0.84, 0.75, 1.0), 0.0)
        elif did == "B":
            ph = 2.0 * math.pi * (s / 22.0) - t * 2.0 * math.pi * 1.4
            cc = np.cos(ph)
            wa = w * (0.3 + 0.7 * np.abs(cc))
            inside &= np.abs(d) <= wa + 0.15
            uu = np.clip(d / wa, -1.0, 1.0)
            k = np.clip(np.floor((uu + 1.0) * 0.5 * 6.0), 0, 5).astype(np.int32)
            back = cc < 0.0
            k = np.where(back, 5 - k, k)
            rgb = RB[k].copy()
            rgb[back] *= 0.8
            node = (np.abs(cc) < 0.28) & (np.abs(d) < 0.9)
            rgb[node] = CREAM
            a = np.where(inside, np.where(np.abs(uu) > 0.84, 0.75, 1.0), 0.0)
        elif did == "C":
            h = np.mod(np.floor((s - t * 110.0) / 13.0), 6).astype(np.int32)
            ad = np.abs(d)
            rgb = np.where((ad <= 0.8)[:, None], CREAM, np.where((ad <= w * 0.58)[:, None], RBL[h], RB[h]))
            a = np.where(inside, np.where(ad <= w * 0.58, 1.0, 0.5), 0.0)
        else:  # D
            kt = int(math.floor(th / TICK_S))
            front = (th - kt * TICK_S) / 0.1 * L
            if self.final:
                k = np.clip(np.floor((u + 1.0) * 0.5 * 6.0), 0, 5).astype(np.int32)
                col = RB[k]
            else:
                c_new, c_old = RB[kt % 6], RB[(kt - 1) % 6]
                col = np.where((s <= front)[:, None], c_new, c_old)
            bulge = np.abs(s - front) < 3.0
            ww = np.where(bulge & (front < L), w + 1.2, w)
            inside &= np.abs(d) <= ww + 0.15
            uu = np.clip(d / ww, -1.0, 1.0)
            ad = np.abs(d)
            rgb = np.where((ad <= 0.8)[:, None], CREAM,
                           np.where((np.abs(uu) <= 0.55)[:, None], col * 0.55 + CREAM * 0.45, np.where((np.abs(uu) > 0.86)[:, None], col * 0.72, col)))
            ring = bulge & (front < L)
            rgb[ring] = rgb[ring] * 0.4 + CREAM * 0.6
            a = np.where(inside, np.where(np.abs(uu) > 0.86, 0.75, 1.0), 0.0)
        # parlama hattı: ışın boyunca hedefe akan açık bant (A/B/D) - "parıltılı"
        if did in ("A", "B", "D"):
            g = np.mod(s - t * 150.0, 30.0) < 3.0
            rgb[g] = rgb[g] * 0.55 + CREAM * 0.45
        # kamaşmaya yakın titreşim (2,4-3 sn)
        if 2.4 <= th < HOLD_S and int(t * 30) % 2 == 0:
            rgb = rgb * 0.7 + CREAM * 0.3
        lay_over(layer, I, J, rgb.astype(np.float32), qa(a).astype(np.float32))
        return L

    def update_sparks(self, p0, p1, dt, L):
        if self.did != "C":
            return
        ux, uy = (p1[0] - p0[0]) / L, (p1[1] - p0[1]) / L
        rate = 44.0 if self.final else 24.0
        nspawn = rate * dt
        while nspawn > 0.0:
            if self.rng.random() < nspawn:
                ss = self.rng.uniform(6.0, L - 2.0)
                side = self.rng.choice((-1.0, 1.0))
                off = side * self.rng.uniform(1.5, 4.5 if self.final else 3.6)
                x = p0[0] + ux * ss - uy * off
                y = p0[1] + uy * ss + ux * off
                vx = ux * 16.0 - uy * side * 7.0
                vy = uy * 16.0 + ux * side * 7.0
                self.sparks.append([x, y, vx, vy, 0.0, self.rng.uniform(0.32, 0.5), self.rng.randrange(6)])
            nspawn -= 1.0
        for p in self.sparks:
            p[0] += p[2] * dt
            p[1] += p[3] * dt
            p[4] += dt
        self.sparks = [p for p in self.sparks if p[4] < p[5]]

    def draw_sparks(self, layer):
        for x, y, _, _, age, life, ci in self.sparks:
            f = age / life
            r = 2 if f < 0.3 else (1 if f < 0.75 else 0)
            gx, gy = layer.tc(x, y)
            col = tuple(float(v) for v in RB[ci])
            layer.plus(gx, gy, r, tuple(float(v) for v in CREAM), [col, col], 1.0 if f < 0.75 else 0.5)

    def tip_flare(self, layer, tip, t):
        gx, gy = layer.tc(*tip)
        r = 2 if int(t * 15) % 2 == 0 else 1
        k = int(t * 6) % 6
        col = tuple(float(v) for v in (RBL[k] if self.did != "A" else CREAM))
        cr = tuple(float(v) for v in CREAM)
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                layer.put(gx + dx, gy + dy, cr if dx == 0 or dy == 0 else col, 1.0 if dx == 0 or dy == 0 else 0.5)
        layer.plus(gx, gy, r + 1, cr, [col, col, col], 0.75)

    def impact(self, layer, pos, th):
        bt = th % TICK_S
        if bt >= 0.2:
            return
        f = bt / 0.2
        gx, gy = layer.tc(*pos)
        cr = tuple(float(v) for v in CREAM)
        kt = int(math.floor(th / TICK_S))
        if self.did == "D" and not self.final:
            col = RB[kt % 6]
            rad = 2.5 + f * 7.0
            I, J, s, d, _ = beam_grid(layer, pos, (pos[0] + 0.01, pos[1]), rad + 2.0)
            rr = np.hypot(s, d)
            th_ = 2.0 * (1.0 - f) + 0.6
            m = np.abs(rr - rad) <= th_
            rgb = np.where((rr < rad)[:, None], col * 0.55 + CREAM * 0.45, col)
            lay_over(layer, I[m], J[m], rgb[m].astype(np.float32), np.full(int(m.sum()), float(qa(np.array([1.0 - f * f]))[0]), np.float32))
        else:
            rad = 2.0 + f * 9.0
            for i in range(6):
                an = math.radians(i * 60.0 + kt * 23.0)
                col = tuple(float(v) for v in RB[i])
                px_, py_ = gx + int(round(math.cos(an) * rad)), gy + int(round(math.sin(an) * rad))
                if f < 0.5:
                    layer.plus(px_, py_, 1, col, [col], 1.0)
                else:
                    layer.put(px_, py_, col, 0.75)
        rs = int(round(3.0 * (1.0 - f))) + 1
        layer.plus(gx, gy, rs, cr, [cr, tuple(float(v) for v in RBL[kt % 6]), tuple(float(v) for v in RBL[(kt + 2) % 6])], 1.0)


def dazzle_fx(layer, pos, dt_d, t):
    """Kamaşma anı + 1,5 sn sersemlik (hepsinde aynı)."""
    cr = tuple(float(v) for v in CREAM)
    if dt_d < 0.42:
        f = dt_d / 0.42
        r = 5.0 + 24.0 * (1.0 - (1.0 - f) ** 2)
        thk = 3.4 * (1.0 - f) + 0.9
        I, J, s, d, _ = beam_grid(layer, pos, (pos[0] + 0.01, pos[1]), r + thk + 2.0)
        rr = np.hypot(s, d)
        ang = np.mod(np.arctan2(d, s) + t * 1.5, 2.0 * math.pi)
        k = np.clip(np.floor(ang / (2.0 * math.pi / 6.0)), 0, 5).astype(np.int32)
        m = np.abs(rr - r) <= thk * 0.5
        # kırılma: sona doğru halka dilimlerin ortasında incelir (hilaller)
        frac = np.mod(ang / (2.0 * math.pi / 6.0), 1.0)
        m &= ~((f > 0.55) & (np.abs(frac - 0.5) > 0.5 - (1.0 - f) * 0.9))
        rgb = np.where((rr < r)[:, None], RBL[k], RB[k])
        lay_over(layer, I[m], J[m], rgb[m].astype(np.float32), np.full(int(m.sum()), float(qa(np.array([1.0 - f * f]))[0]), np.float32))
    if dt_d < 0.3:
        f = dt_d / 0.3
        gx, gy = layer.tc(*pos)
        ln = int(round(13.0 * (1.0 - f))) + 1
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            layer.line(gx, gy, gx + dx * ln, gy + dy * ln, cr, 1.0 if f < 0.5 else 0.75)
        for dx, dy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
            layer.line(gx, gy, gx + dx * (ln // 2), gy + dy * (ln // 2), cr, 0.75)
    # dönen yıldızlar (başın üstünde)
    hx_, hy_ = pos[0], pos[1] - 13.0
    for i in range(3):
        an = 2.0 * math.pi * 1.1 * dt_d + i * 2.0 * math.pi / 3.0
        x = hx_ + math.cos(an) * 8.0
        y = hy_ + math.sin(an) * 3.0
        gx, gy = layer.tc(x, y)
        col = tuple(float(v) for v in RB[(i * 2 + int(dt_d * 4)) % 6])
        layer.plus(gx, gy, 1, cr, [col], 1.0 if math.sin(an) > 0 else 0.5)


# ------------------------------------------------------------------ sahne
CHAR_P = (300.0, 200.0)
SLIME_BASE = (CHAR_P[0] + 118.0, CHAR_P[1] - 6.0)
VIEW_BASE = (CHAR_P[0] - 48.0, CHAR_P[1] - 37.0 - 92.0, CHAR_P[0] + 150.0, CHAR_P[1] + 30.0)
VIEW_FINAL = (CHAR_P[0] - 48.0, CHAR_P[1] - 37.0 - 92.0, CHAR_P[0] + 200.0, CHAR_P[1] + 30.0)
FPS_OUT = 25


FINAL_ANG = math.radians(16.0)


def final_slimes(tip):
    return [(tip[0] + math.cos(FINAL_ANG) * dd, tip[1] + math.sin(FINAL_ANG) * dd) for dd in (66.0, 104.0, 142.0)]


def run_panel(did, lv, final, z=2):
    key = "gk_%s_L%d" % (did, lv)
    view = VIEW_FINAL if final else VIEW_BASE
    sty = Style(did, final, 900 + "ABCD".index(did) * 7 + (1 if final else 0))
    fo = AP.Follow(key, ang=0.0)
    st0 = {"t": 0.0, "P": CHAR_P, "V": (0.0, 0.0), "moving": False, "face": (1, 0), "walk_t": 0.0}
    # hedefler: temel 1 slime; final: uçtan geçen hatta 3 slime (ışın 168 menzile kadar)
    if final:
        aim = (CHAR_P[0] + 200.0, CHAR_P[1])
        for _ in range(3):
            for _ in range(40):
                _, _, tip = fo.step(st0, aim=aim)
            aim = (tip[0] + math.cos(FINAL_ANG) * 400.0, tip[1] + math.sin(FINAL_ANG) * 400.0)
        slimes = final_slimes(tip)
    else:
        slimes = [SLIME_BASE]
        aim = SLIME_BASE
    n = int(round(LOOP_S * FPS_OUT))
    dt = 1.0 / FPS_OUT
    frames = []
    for lap in range(2):
        for i in range(n):
            t = i * dt
            th = t
            st = dict(st0, t=t)
            pos, rot, tip = fo.step(st, aim=aim)
            if final:
                ang = math.atan2(aim[1] - tip[1], aim[0] - tip[0])
                end = (tip[0] + math.cos(ang) * RANGE, tip[1] + math.sin(ang) * RANGE)
            else:
                end = aim
            L = max(1.0, math.hypot(end[0] - tip[0], end[1] - tip[1]))
            sty.update_sparks(tip, end, dt, L)
            if lap == 0:
                continue
            F = AP.bg_crop(z, view)

            def S(p):
                return ((p[0] - view[0]) * z, (p[1] - view[1]) * z)
            dazed = th >= HOLD_S
            dt_d = th - HOLD_S
            for si, sp in enumerate(slimes):
                ex, ey = S((sp[0], sp[1] - 1.0))
                rot_s = 0.15 * math.sin(2.0 * math.pi * 2.6 * dt_d) if dazed else 0.0
                fr = slime_frame(t, si)
                blit2(F, fr, ex, ey, SLIME_K * z, rot=rot_s)
                fl = (th % TICK_S) / 0.12
                if fl < 1.0:
                    blit2(F, fr, ex, ey, SLIME_K * z, rot=rot_s, alpha=0.75 * (1.0 - fl), tint=(255, 255, 255))
                if dazed:
                    wa = 0.9 * (1.0 - dt_d / 0.25) if dt_d < 0.25 else 0.18
                    blit2(F, fr, ex, ey, SLIME_K * z, rot=rot_s, alpha=wa, tint=(255, 250, 235))
            AP.draw_char(F, z, view, st)
            AP.draw_staff(F, z, view, key, pos, rot, st["P"])
            air = AP.Layer(view[0], view[1], view[2] - view[0], view[3] - view[1], tx=BEAM_TX)
            sty.beam(air, tip, end, t, th)
            sty.draw_sparks(air)
            sty.tip_flare(air, tip, t)
            for sp in slimes:
                sty.impact(air, sp, th)
                if dazed:
                    dazzle_fx(air, sp, dt_d, t)
            air.composite(F, z)
            im = Image.fromarray(np.clip(F, 0, 255).astype(np.uint8), "RGB")
            if final:
                title = "FİNAL · Gökkuşağı Mızrağı (L5)"
                sub = "delip geçer, menzil 168 · tutma %.1f sn" % th if not dazed else "HEPSİ KAMAŞTI · %.1f sn" % (DAZE_S - dt_d)
            else:
                title = "TEMEL · L3 Çelik"
                sub = "aynı hedefe kesintisiz tutma %.1f / 3,0 sn" % th if not dazed else "GÖZÜ KAMAŞTI · %.1f sn" % (DAZE_S - dt_d)
            frames.append(AP.tile_label(im, title, sub))
    return frames


def build_gif(did):
    name = next(d for d in DIRS if d[0] == did)
    left = run_panel(did, 3, False)
    right = run_panel(did, 5, True)
    frames = []
    for a, b in zip(left, right):
        row = AP.hstack([a, b])
        hd = header(row.width, "Gökkuşağı Asası · %s · %s (prototip, oyuna bağlı değil)" % (did, name[1]),
                    "1080p oyun ölçeği · ışın: %s · vuruş 0,5 sn · kamaşma 3 sn tutunca" % name[3])
        frames.append(stack_v([hd, row], 0))
    n = len(frames)
    save_gif(frames, os.path.join(OUT, "gk_%s.gif" % did), FPS_OUT, [n // 6, n // 2, int(n * 0.7), int(n * 0.9)])


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    what = sys.argv[1:] or ["asa", "gif"]
    build_icons()
    if "asa" in what:
        sheet_icons()
        sheet_game()
    gifs = [w for w in what if w in "ABCD" and len(w) == 1]
    if "gif" in what:
        gifs = ["A", "B", "C", "D"]
    for g in gifs:
        build_gif(g)
