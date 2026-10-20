# -*- coding: utf-8 -*-
"""KALKAN (silah) sanatı PROTOTİPLERİ (2026-10-20, oyuna bağlı DEĞİL). Kullanıcı: "güzel kalkan prototipi hazırla 4 tane"
(yeni silah Kalkan: geniş darbe %80 saldırı gücü + itme; özellik "Siper", madde 329).

Zanaatkâr seti (madde 196) altyapısıyla (silah_zanaat_proto.py: TA seviye merdiveni, Cv tuvali), 48x48, ÖNDEN bakış (frame "horiz":
a = sağa, b = aşağı, ışık sol-üst). 4 silüet:
  A Yuvarlak  - tahta kalaslı yuvarlak kalkan + ortada demir göbek (umbo)
  B Şövalye   - üstü düz, altı sivri "ısıtıcı" kalkan, alanı boyalı / levhalı
  C Kule      - uzun dikdörtgen kule kalkanı, ortada sırt + yatay kuşaklar
  D Hilal     - üstünden hilal oyulmuş, iki boynuzlu kalkan; boynuzlar üst seviyede çelik diken
Seviye merdiveni (TA): 1 Paslı / 2 Demir / 3 Çelik + pirinç / 4 Kara Çelik + gümüş + kırmızı / 5 Yadigâr çelik + altın + lal.

Çıktılar (out/kalkan/): sanat/kalkan_<A..D>_L<n>.png (48x48), kalkan_sanat_sayfa.png (x4), kalkan_sanat_oyun.png (oyun ölçeği:
1 sanat px = 0,575 dünya px, zoom 2, Talon + Uzunkılıç L3 + Mızrak L3 boy kıyası, resim x2).
Çalıştırma: python tools/proto_20261020/kalkan_sanat.py
"""
import math
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
P16 = os.path.normpath(os.path.join(HERE, "..", "proto_20261016"))
sys.path.insert(0, P16)
import silah_zanaat_proto as Z  # noqa: E402
import silah_proto48 as S  # noqa: E402
from silah_proto48 import Cv, frame, LV, E, P, facet, spike, circle_pts, font, N  # noqa: E402

TA = Z.TA
hsh = S.hsh
OUT = os.path.join(HERE, "out", "kalkan")
ART = os.path.join(OUT, "sanat")


# ---------------------------------------------------------------- ortak parçalar
def face_tex(lv, R, planks=0.0, paint=None, rust=False, ridge=False):
    """Kalkan yüzü dokusu: kenar bevel'i, büyük yüzeyde 3 tonlu dışbükeylik (sol-üst açık, sağ-alt koyu), istenirse dikey kalas
    çizgileri (planks = kalas eni, piksel), boya alanı (paint(a, b) -> malzeme ya da None), pas lekeleri."""
    def f(idx, a, b, x, y, d):
        mat = paint(a, b) if paint else None
        if d < 1.0:
            return P[mat][5 if (a + b) < 0 else 2] if mat else idx
        k = (a + b) / max(R, 1.0)
        if planks > 0 and mat is None:
            ## ahşap: yumuşak 2 kademeli dışbükeylik (3 tonlu çapraz bant ahşapta şerit gibi okunuyordu) + dikey kalas çizgisi (piksel ızgarası)
            base = 4 if k < -0.85 else (2 if k > 0.7 else 3)
            pw = int(planks)
            if (x - 24 + 64) % pw == 0:
                return 1
            if hsh((x - 24 + 64) // pw, (y + 64) // 3, 7) < 0.16:
                base -= 1
        else:
            base = 4 if k < -0.55 else (3 if k < 0.45 else 2)
        if mat:
            return P[mat][max(1, min(6, base + 1))]
        if rust and hsh(x // 2, y // 2, 13) < 0.3:
            return P["A_rust"][max(2, min(5, base))]
        return base
    return f


def rim(c, pts, r, mat, shine=0.45):
    c.tube(pts, r, mat, shine=shine)


def rivets(c, pts, mat, r=0.75):
    for a, b in pts:
        c.sphere((a, b), r, mat, shine=0.6, sep=False)


def boss(c, a, b, r, mat, ring=None, gem=None):
    if ring:
        c.tube(circle_pts(a, b, r + 0.9, n=20), 0.6, ring, shine=0.5)
    c.sphere((a, b), r, mat, shine=0.5)
    if gem:
        c.sphere((a - 0.2, b - 0.2), r * 0.45, gem, shine=0.7, sep=False)


def glint5(c, lv, a, b, mat="A_steel"):
    if lv == 5:
        c.glint(a, b, mat, 6)


def ellipse_ring(ca, cb, ra, rb, k, n=12, phase=0.0):
    return [(ca + ra * k * math.cos(phase + 2 * math.pi * i / n), cb + rb * k * math.sin(phase + 2 * math.pi * i / n)) for i in range(n)]


# ---------------------------------------------------------------- A Yuvarlak
def A_shield(c, lv):
    t = TA[lv]
    R = LV(lv, 12.5, 16.5)
    wood = "A_wood" if lv <= 3 else "A_dwood"
    out = circle_pts(0, 0, R, n=40)
    paint = None
    if lv == 4:  # kara çelik: iki karşı çeyrek kırmızı boyalı (tek vurgu)
        paint = lambda a, b: "A_cloth" if (a * b < 0 and math.hypot(a, b) > R * 0.34) else None
    c.plate(out[:-1], wood, bevel=1.4, shine=0.2, tex=face_tex(lv, R, planks=4.0 if lv != 4 else 4.0, paint=paint))
    if lv == 1:
        ## kenar yok: iki iple sarılı kuşak, küçük paslı göbek, birkaç çivi
        for bb in (-R * 0.48, R * 0.48):
            hw = math.sqrt(max(0.0, R * R - bb * bb)) - 0.6
            c.tube([(-hw, bb), (hw, bb)], 0.55, "A_rope", tex=E.wrap, shine=0.1, sep=False)
        boss(c, 0, 0, 3.0, "A_iron")
        c.sphere((-0.8, -0.8), 1.0, "A_rust", shine=0.2, sep=False)
        rivets(c, [(-R * 0.62, 0), (R * 0.62, 0), (0, -R * 0.66), (0, R * 0.66)], "A_iron", 0.6)
        return
    rm = "A_iron" if lv == 2 else (t["tr"] if lv != 4 else "A_silver")
    rim(c, out, LV(lv, 1.0, 1.4), rm)
    if lv == 2:
        boss(c, 0, 0, 3.6, "A_iron")
        rivets(c, ellipse_ring(0, 0, R, R, 0.78, n=6, phase=0.5), "A_iron", 0.7)
        return
    if lv == 3:
        boss(c, 0, 0, 4.0, "A_steel", ring=t["tr"])
        rivets(c, ellipse_ring(0, 0, R, R, 0.8, n=8, phase=0.39), t["tr"])
        return
    if lv == 4:
        boss(c, 0, 0, 4.4, "A_black", ring="A_silver")
        rivets(c, ellipse_ring(0, 0, R, R, 0.82, n=8, phase=0.39), "A_silver")
        return
    ## L5 Yadigâr: çelik iç halka + altın kenar + altın göbek halkası + lal
    boss(c, 0, 0, 4.8, "A_steel", ring="A_gold", gem="A_garnet")
    rivets(c, ellipse_ring(0, 0, R, R, 0.84, n=8, phase=0.39), "A_gold", 0.85)
    glint5(c, lv, -R * 0.55, -R * 0.55, "A_gold")


# ---------------------------------------------------------------- B Şövalye (ısıtıcı)
def heater_pts(W, top, bot, shoulder=0.42, n=14):
    """Üstü hafif kavisli, yanları düz inip sivri uca kavislenen kalkan çokgeni (saat yönünde)."""
    H = bot - top
    ys = top + H * shoulder
    right = [(W, top + 0.6), (W, ys)]
    for i in range(1, n + 1):
        u = i / float(n)
        ## (W, ys) -> (0, bot) ikinci derece eğri, kontrol (W, bot - H * 0.12)
        cx, cy = W, bot - H * 0.12
        a = (1 - u) ** 2 * W + 2 * (1 - u) * u * cx + u * u * 0.0
        b = (1 - u) ** 2 * ys + 2 * (1 - u) * u * cy + u * u * bot
        right.append((a, b))
    left = [(-a, b) for a, b in reversed(right[:-1])]
    topc = [(-W * 0.5, top - 0.5), (0, top - 0.8), (W * 0.5, top - 0.5)]
    return right + left + topc


def B_shield(c, lv):
    t = TA[lv]
    W = LV(lv, 10.5, 14.0)
    top, bot = -LV(lv, 12.5, 16.0), LV(lv, 14.0, 19.0)
    pts = heater_pts(W, top, bot)
    R = (W + bot) * 0.5
    if lv <= 2:
        c.plate(pts, "A_wood", bevel=1.3, shine=0.2, tex=face_tex(lv, R, planks=4.0))
        bb = top + (bot - top) * 0.2
        c.tube([(-W + 0.3, bb), (W - 0.3, bb)], 0.9 if lv == 2 else 0.7, "A_iron" if lv == 2 else "A_rope",
               tex=None if lv == 2 else E.wrap, shine=0.35, sep=lv == 2)
        if lv == 2:
            rim(c, pts + [pts[0]], 0.95, "A_iron")
            rivets(c, [(-W * 0.62, bb), (W * 0.62, bb), (0, bb)], "A_iron", 0.7)
        else:
            rivets(c, [(-W * 0.6, bb), (W * 0.6, bb)], "A_iron", 0.6)
            c.sphere((W * 0.25, bot * 0.35), 1.0, "A_rust", shine=0.1, sep=False)
        return
    if lv == 3:
        c.plate(pts, "A_steel", bevel=1.4, shine=0.3, tex=face_tex(lv, R))
        rim(c, pts + [pts[0]], 1.05, t["tr"])
        boss(c, 0, top + (bot - top) * 0.4, 2.6, t["tr"])
        return
    if lv == 4:
        ## kırmızı alan + gümüş kenar + ortada gümüş çavuş (^) şeridi
        c.plate(pts, "A_cloth", bevel=1.4, shine=0.25, tex=face_tex(lv, R))
        my = top + (bot - top) * 0.45
        c.tube([(-W * 0.86, my + W * 0.5), (0, my - W * 0.35), (W * 0.86, my + W * 0.5)], 1.15, "A_silver", shine=0.5, sep=True)
        rim(c, pts + [pts[0]], 1.2, "A_black")
        return
    ## L5 Yadigâr: çelik yüz, altın kenar, altın haç kabartma + lal
    c.plate(pts, "A_steel", bevel=1.5, shine=0.3, tex=face_tex(lv, R))
    cy = top + (bot - top) * 0.4
    c.tube([(0, top + 2.6), (0, bot - 5.5)], 1.15, "A_gold", shine=0.5)
    c.tube([(-W + 3.0, cy), (W - 3.0, cy)], 1.15, "A_gold", shine=0.5)
    rim(c, pts + [pts[0]], 1.35, "A_gold")
    c.sphere((0, cy), 2.0, "A_gold", shine=0.5)
    c.sphere((-0.2, cy - 0.2), 1.0, "A_garnet", shine=0.7, sep=False)
    glint5(c, lv, -W * 0.55, top + 3.5)


# ---------------------------------------------------------------- C Kule
def tower_pts(W, top, bot, n=10):
    """Uzun dikdörtgen, üstü yay biçimli, alt köşeleri hafif yuvarlak."""
    pts = []
    for i in range(n + 1):
        u = i / float(n)
        a = -W + 2 * W * u
        pts.append((a, top + 2.2 * (2 * u - 1) ** 2))
    pts += [(W, bot - 1.2), (W - 1.2, bot), (-W + 1.2, bot), (-W, bot - 1.2)]
    return pts


def C_shield(c, lv):
    t = TA[lv]
    W = LV(lv, 8.5, 11.0)
    top, bot = -LV(lv, 16.0, 19.5), LV(lv, 16.0, 19.5)
    pts = tower_pts(W, top, bot)
    R = bot
    bands = [top + (bot - top) * 0.24, top + (bot - top) * 0.74]
    if lv <= 2:
        c.plate(pts, "A_wood", bevel=1.3, shine=0.2, tex=face_tex(lv, R * 0.6, planks=4))
        for bb in bands:
            if lv == 1:
                c.tube([(-W + 0.2, bb), (W - 0.2, bb)], 0.75, "A_rope", tex=E.wrap, shine=0.1, sep=False)
            else:
                c.tube([(-W + 0.2, bb), (W - 0.2, bb)], 0.95, "A_iron", shine=0.35)
                rivets(c, [(-W * 0.55, bb), (W * 0.55, bb)], "A_iron", 0.65)
        if lv == 2:
            rim(c, pts + [pts[0]], 0.9, "A_iron")
            boss(c, 0, 0, 2.8, "A_iron")
        else:
            boss(c, 0, 0, 2.4, "A_iron")
            c.sphere((-0.6, -0.6), 0.9, "A_rust", shine=0.1, sep=False)
        return
    face = "A_steel" if lv != 4 else "A_black"
    c.plate(pts, face, bevel=1.4, shine=0.3, tex=face_tex(lv, R * 0.6))
    if lv == 4:  # tek vurgu: ortadan inen kırmızı sancak şeridi
        c.plate([(-2.8, top + 3.0), (2.8, top + 3.0), (2.8, bot - 6.0), (0, bot - 3.4), (-2.8, bot - 6.0)], "A_cloth", bevel=0.9, shine=0.25)
    tr = t["tr"] if lv != 4 else "A_silver"
    if lv != 4:
        c.tube([(0, top + 2.6), (0, bot - 2.4)], 0.8, tr, shine=0.55)
    rim(c, pts + [pts[0]], LV(lv, 0.95, 1.3), tr)
    rivets(c, [(-W + 2.0, top + 3.6), (W - 2.0, top + 3.6), (-W + 2.0, bot - 2.2), (W - 2.0, bot - 2.2)], tr, 0.75)
    if lv == 5:
        c.plate([(0, -4.4), (3.0, 0), (0, 4.4), (-3.0, 0)], "A_gold", bevel=1.0, shine=0.5)
        c.sphere((-0.2, -0.2), 1.1, "A_garnet", shine=0.7, sep=False)
        glint5(c, lv, -W * 0.5, top + 4.0)
    else:
        boss(c, 0, 0, LV(lv, 3.0, 3.6), "A_steel" if lv == 3 else "A_black", ring=tr if lv == 3 else None)


# ---------------------------------------------------------------- D Hilal
def crescent_pts(W, H, cy, horn, dip, n=26):
    """Alt yarısı elips, üstü boynuzlar arası içe kavisli oyuk. horn = boynuz ucunun açısı (radyan, yatayın üstü), dip = oyuğun en
    alçak noktası (b)."""
    pts = []
    t0, t1 = math.pi - horn, 2 * math.pi + horn  # sol boynuz -> alt -> sağ boynuz
    for i in range(n + 1):
        t = t0 + (t1 - t0) * i / float(n)
        pts.append((W * math.cos(t), cy - H * math.sin(t)))
    ra, rb = pts[-1]
    la, lb = pts[0]
    for i in range(1, 12):
        u = i / 12.0
        a = (1 - u) ** 2 * ra + 2 * (1 - u) * u * 0.0 + u * u * la
        b = (1 - u) ** 2 * rb + 2 * (1 - u) * u * (2 * dip - rb) + u * u * lb
        pts.append((a, b))
    return pts


def D_shield(c, lv):
    t = TA[lv]
    W = LV(lv, 12.5, 16.0)
    H = LV(lv, 13.0, 17.0)
    cy = LV(lv, 1.5, 1.0)
    pts = crescent_pts(W, H, cy, horn=LV(lv, 0.62, 0.78), dip=-LV(lv, 2.5, 3.5))
    R = W
    hl, hr = pts[0], pts[26]
    if lv <= 2:
        c.plate(pts, "A_wood", bevel=1.3, shine=0.2, tex=face_tex(lv, R, planks=4.0))
        if lv == 1:
            c.tube([(-W * 0.7, cy + H * 0.25), (W * 0.7, cy + H * 0.25)], 0.6, "A_rope", tex=E.wrap, shine=0.1, sep=False)
            boss(c, 0, cy + 1.5, 2.8, "A_iron")
            c.sphere((-0.7, cy + 0.8), 0.9, "A_rust", shine=0.1, sep=False)
        else:
            rim(c, pts + [pts[0]], 0.95, "A_iron")
            boss(c, 0, cy + 1.5, 3.3, "A_iron")
            rivets(c, [(-W * 0.6, cy + 1.5), (W * 0.6, cy + 1.5), (0, cy + H * 0.62)], "A_iron", 0.65)
        return
    face = "A_steel" if lv != 4 else "A_black"
    paint = None
    if lv == 4:  # tek vurgu: alt yarıda kırmızı yay bandı
        paint = lambda a, b: "A_cloth" if (b > cy + H * 0.22 and (a / W) ** 2 + ((b - cy) / H) ** 2 < 0.78) else None
    c.plate(pts, face, bevel=1.4, shine=0.3, tex=face_tex(lv, R, paint=paint))
    tr = t["tr"] if lv != 4 else "A_silver"
    rim(c, pts + [pts[0]], LV(lv, 1.0, 1.35), tr)
    ## boynuzlar: L3 kısa, L4-5 uzun çelik diken
    hk = LV(lv, 2.4, 5.0)
    for (ha, hb), sg in ((hl, -1), (hr, 1)):
        tip = (ha + sg * hk * 0.55, hb - hk)
        facet(c, spike((ha - sg * 0.6, hb + 1.4), tip, LV(lv, 1.4, 1.9), shoulder=0.3), "A_steel" if lv != 4 else "A_silver")
    if lv == 5:
        boss(c, 0, cy + 2.0, 3.9, "A_steel", ring="A_gold", gem="A_garnet")
        rivets(c, [(-W * 0.62, cy + 1.2), (W * 0.62, cy + 1.2), (0, cy + H * 0.68)], "A_gold", 0.85)
        glint5(c, lv, -W * 0.5, cy - 1.0, "A_gold")
    else:
        boss(c, 0, cy + 1.8, LV(lv, 3.6, 4.2), "A_steel" if lv == 3 else "A_black", ring=tr)


DIRS = [("A", "A - Yuvarlak", A_shield), ("B", "B - Şövalye", B_shield), ("C", "C - Kule", C_shield), ("D", "D - Hilal", D_shield)]


def build():
    os.makedirs(ART, exist_ok=True)
    gi = os.path.join(HERE, "out", ".gdignore")
    if not os.path.exists(gi):
        open(gi, "w").close()
    imgs = {}
    frame("horiz")
    for did, _, fn in DIRS:
        for lv in range(1, 6):
            cv = Cv(lv)
            fn(cv, lv)
            img = cv.render()
            img.save(os.path.join(ART, "kalkan_%s_L%d.png" % (did, lv)))
            bb = img.getchannel("A").point(lambda v: 255 if v == 255 else 0).getbbox()
            if bb and (bb[0] == 0 or bb[1] == 0 or bb[2] == N or bb[3] == N):
                print("KENAR!", did, lv, bb)
            imgs[(did, lv)] = img
    return imgs


def sheet(imgs, path, z=4):
    cell = N * z
    lw, gap, top = 170, 14, 40
    W = lw + 5 * (cell + gap) + gap
    H = top + len(DIRS) * (cell + gap) + gap
    im = Image.new("RGBA", (W, H), (34, 38, 40, 255))
    d = ImageDraw.Draw(im)
    for lv in range(1, 6):
        x0 = lw + gap + (lv - 1) * (cell + gap)
        d.text((x0, 10), "%d - %s" % (lv, TA[lv]["name"]), fill=(235, 230, 215), font=font(20, True))
    for ri, (did, label, _) in enumerate(DIRS):
        y0 = top + ri * (cell + gap)
        d.text((12, y0 + cell // 2 - 10), label, fill=(235, 230, 215), font=font(18, True))
        for lv in range(1, 6):
            x0 = lw + gap + (lv - 1) * (cell + gap)
            d.rectangle([x0, y0, x0 + cell - 1, y0 + cell - 1], fill=S.BG)
            im.alpha_composite(imgs[(did, lv)].resize((cell, cell), Image.NEAREST), (x0, y0))
    im.convert("RGB").save(path)
    print("sayfa", path, im.size)


def context(imgs):
    """Oyun ölçeği: 1 sanat px = 0,575 dünya px x zoom 2, Talon + Uzunkılıç L3 + Mızrak L3 boy kıyası, resim x2."""
    zoom, wpp = 2.0, 0.575
    cwp = 2.2368375 * 0.8075 * 0.5
    ch_img = Image.open(os.path.join(E.GAME, "assets/characters/talon/sheets/idle.png")).convert("RGBA").crop((0, 96, 48, 144))
    sword = Image.open(os.path.join(E.GAME, "assets/weapons/zanaat/uzunkilic_L3.png")).convert("RGBA")
    spear = Image.open(os.path.join(E.GAME, "assets/weapons/zanaat/mizrak_L3.png")).convert("RGBA")
    cw, chh, lw, top = 50, 70, 120, 24
    lead = 160
    W = lw + lead + 5 * cw + 10
    H = top + len(DIRS) * (chh + 6)
    im = Image.new("RGB", (W, H), (34, 38, 40))
    d = ImageDraw.Draw(im)
    d.text((8, 4), "Kalkan - oyun ölçeği (zoom 2)  ·  solda Talon + Uzunkılıç L3 + Mızrak L3", fill=(235, 230, 215), font=font(12, True))
    for ri, (did, label, _) in enumerate(DIRS):
        y0 = top + ri * (chh + 6)
        d.text((8, y0 + chh // 2 - 8), label, fill=(235, 230, 215), font=font(12, True))
        pc = Image.new("RGB", (lead + 5 * cw, chh), S.BG)
        E.blit_world(pc, ch_img, 34, chh // 2 + 4, cwp, zoom)
        E.blit_world(pc, sword, 82, chh // 2, wpp, zoom)
        E.blit_world(pc, spear, 128, chh // 2, wpp, zoom)
        for lv in range(1, 6):
            E.blit_world(pc, imgs[(did, lv)], lead + (lv - 1) * cw + cw // 2, chh // 2, wpp, zoom)
        im.paste(pc, (lw, y0))
    path = os.path.join(OUT, "kalkan_sanat_oyun.png")
    im.resize((W * 2, H * 2), Image.NEAREST).save(path)
    print("oyun", path)


if __name__ == "__main__":
    imgs = build()
    sheet(imgs, os.path.join(OUT, "kalkan_sanat_sayfa.png"))
    context(imgs)
