"""Eksik eşya ikonları (2026-10-02, yeni eşya sistemi) -> assets/items/<anahtar>.png (32x32, kullanıcının ikonlarıyla aynı stil).

Kullanıcı 31 ikonu hazır verdi (İtem sistemi yeni.zip); burada metinde olup ikonu olmayan 11 eşya çiziliyor:
Çeviklik Yüzüğü, Tecrübe Kitabı, Ayakkabı Bağcığı, Kol Saati, Tornavida, Kırılmaz İrade, Ölüm Eşiği, Kızıl Hasat,
Ruhların Akışı, Zaman Kıran, Azrail'in Gözü.

Stil (kullanıcı ikonlarından): 32x32, nesne alanın çoğunu kaplar, 1 px koyu kontur (nesnenin kendi renginin çok koyusu),
4-6 tonlu rampalar, ışık sol üstten, birkaç parlak vurgu pikseli, arka plan yok.
Çalıştır: python tools/gen_item_icons.py  (önizleme: --preview <png>)
"""
import colorsys
import math
import os
import sys

from PIL import Image

N = 32
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "items")
LIGHT = (-0.62, -0.78)  # sol üst


def hexc(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def ramp(base, n=6, dark=0.22, light=1.35, hue_shift=0.04):
    """Koyudan açığa n ton: koyular maviye/mora, açıklar sarıya kayar (piksel sanat geleneği)."""
    r, g, b = [c / 255.0 for c in hexc(base)]
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    out = []
    for i in range(n):
        t = i / (n - 1)
        vv = min(1.0, v * (dark + (light - dark) * t))
        ss = min(1.0, max(0.0, s * (1.15 - 0.45 * t)))
        hh = (h + hue_shift * (0.5 - t)) % 1.0 if s > 0.08 else h
        rr, gg, bb = colorsys.hsv_to_rgb(hh, ss, vv)
        out.append((int(rr * 255), int(gg * 255), int(bb * 255)))
    return out


class Icon:
    def __init__(self):
        self.px = {}  # (x,y) -> (r,g,b)
        self.part = {}  # (x,y) -> parça kimliği (kontur rengi için)
        self.outline_of = {}

    # ---- temel çizim
    def put(self, x, y, c, part=None):
        if 0 <= x < N and 0 <= y < N:
            self.px[(x, y)] = c
            if part is not None:
                self.part[(x, y)] = part

    def get(self, x, y):
        return self.px.get((x, y))

    def erase(self, x, y):
        self.px.pop((x, y), None)
        self.part.pop((x, y), None)

    def shade_mask(self, mask, rmp, part, cx=None, cy=None, rx=None, ry=None, bands=None, rim=True, gloss=None):
        """mask: (x,y) kümesi. Işık yönüne göre bantlı gölgelendirme + gölge tarafında kenar koyulaşması."""
        if not mask:
            return
        xs = [p[0] for p in mask]
        ys = [p[1] for p in mask]
        if cx is None:
            cx = (min(xs) + max(xs)) / 2.0
            cy = (min(ys) + max(ys)) / 2.0
            rx = max(1.0, (max(xs) - min(xs) + 1) / 2.0)
            ry = max(1.0, (max(ys) - min(ys) + 1) / 2.0)
        n = len(rmp)
        for (x, y) in mask:
            dx = (x + 0.5 - cx) / rx
            dy = (y + 0.5 - cy) / ry
            d = math.hypot(dx, dy)
            lit = -(dx * LIGHT[0] + dy * LIGHT[1])  # -1..1
            t = 0.55 + 0.45 * lit - 0.25 * max(0.0, d - 0.6)
            t = max(0.0, min(0.999, t))
            idx = 1 + int(t * (n - 2))
            if rim:
                # gölge tarafındaki komşusu maske dışındaysa bir ton koyu
                sx = 1 if LIGHT[0] < 0 else -1
                sy = 1 if LIGHT[1] < 0 else -1
                if (x + sx, y) not in mask or (x, y + sy) not in mask:
                    idx = max(1, idx - 1)
            self.put(x, y, rmp[idx], part)
        if gloss:
            for (x, y) in gloss:
                if (x, y) in mask:
                    self.put(x, y, rmp[-1], part)

    def outline(self, color_for_part=None, default=(20, 12, 18)):
        filled = set(self.px.keys())
        add = {}
        for (x, y) in filled:
            for ddx, ddy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                q = (x + ddx, y + ddy)
                if q in filled or not (0 <= q[0] < N and 0 <= q[1] < N):
                    continue
                part = self.part.get((x, y))
                c = color_for_part.get(part, default) if color_for_part else default
                add[q] = c
        for q, c in add.items():
            self.px[q] = c

    def image(self):
        im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c + (255,) if len(c) == 3 else c)
        return im


# ---- maske yardımcıları
def ellipse(cx, cy, rx, ry):
    m = set()
    for y in range(N):
        for x in range(N):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                m.add((x, y))
    return m


def ring(cx, cy, rx, ry, w):
    outer = ellipse(cx, cy, rx, ry)
    inner = ellipse(cx, cy, rx - w, ry - w * ry / rx)
    return outer - inner


def poly(pts):
    m = set()
    for y in range(N):
        for x in range(N):
            px, py = x + 0.5, y + 0.5
            inside = False
            j = len(pts) - 1
            for i in range(len(pts)):
                xi, yi = pts[i]
                xj, yj = pts[j]
                if (yi > py) != (yj > py) and px < (xj - xi) * (py - yi) / (yj - yi + 1e-9) + xi:
                    inside = not inside
                j = i
            if inside:
                m.add((x, y))
    return m


def thick_line(x0, y0, x1, y1, w):
    m = set()
    L = max(1e-6, math.hypot(x1 - x0, y1 - y0))
    for y in range(N):
        for x in range(N):
            px, py = x + 0.5, y + 0.5
            t = max(0.0, min(1.0, ((px - x0) * (x1 - x0) + (py - y0) * (y1 - y0)) / (L * L)))
            qx, qy = x0 + t * (x1 - x0), y0 + t * (y1 - y0)
            if math.hypot(px - qx, py - qy) <= w / 2.0:
                m.add((x, y))
    return m


def rect(x0, y0, x1, y1):
    return {(x, y) for x in range(x0, x1 + 1) for y in range(y0, y1 + 1)}


def dark_of(c, k=0.28):
    return tuple(int(v * k) for v in c)


# ===================================================================== ikonlar
def ceviklik_yuzugu():
    ic = Icon()
    gold = ramp("#d9a63a", 6)
    gem = ramp("#2fd6b0", 6)
    band = ring(16, 20, 11, 7.5, 3.2)
    ic.shade_mask(band, gold, "gold", 16, 20, 11, 7.5)
    # yüzük taşı yuvası (üstte)
    setting = ellipse(16, 12, 5.2, 3.6)
    ic.shade_mask(setting, gold, "gold")
    stone = ellipse(16, 10.5, 4.0, 4.4)
    ic.shade_mask(stone, gem, "gem", gloss=[(14, 8), (15, 8), (14, 9)])
    ic.put(17, 12, gem[1], "gem")
    # hız çizgileri (çeviklik): yüzüğün solunda kısalan yatay izler
    wind = ramp("#bfeaff", 5)
    for (x0, y, ln) in [(1, 15, 4), (2, 19, 3), (0, 23, 4), (27, 13, 3), (28, 17, 3)]:
        for i in range(ln):
            ic.put(x0 + i, y, wind[4 - min(3, i)] if x0 < 16 else wind[1 + min(3, i)], "wind")
    for (x, y) in [(20, 7), (21, 6), (22, 7), (21, 8), (11, 23)]:
        ic.put(x, y, (255, 255, 235), "spark")
    ic.outline({"gold": (40, 22, 6), "gem": (5, 40, 34), "wind": (24, 48, 70), "spark": (60, 60, 40)})
    return ic


def tecrube_kitabi():
    ic = Icon()
    cover = ramp("#2a6fb8", 6)
    pages = ramp("#efe2bd", 5)
    gold = ramp("#e0b24a", 5)
    # sayfa bloğu (sağ altta görünen kenar)
    pg = poly([(9, 8), (27, 6), (28, 24), (10, 27)])
    ic.shade_mask(pg, pages, "pages")
    for y in range(8, 26, 2):
        for x in range(24, 28):
            if (x, y) in pg:
                ic.put(x, y, pages[1], "pages")
    # kapak
    cv = poly([(5, 6), (24, 4), (25, 23), (6, 26)])
    ic.shade_mask(cv, cover, "cover")
    # sırt
    sp = poly([(4, 6), (7, 6), (8, 26), (5, 27)])
    ic.shade_mask(sp, ramp("#1d4f87", 6), "cover")
    # köşe kaplamaları
    for (x, y) in [(22, 5), (23, 5), (23, 6), (23, 22), (23, 23), (22, 23), (8, 25), (9, 25), (8, 24)]:
        ic.put(x, y, gold[3], "gold")
    # EXP yıldızı/orbu
    orb = ellipse(15.5, 15, 4.2, 4.2)
    ic.shade_mask(orb, ramp("#8be04a", 6), "orb", gloss=[(13, 13), (14, 12)])
    for (x, y) in [(15, 9), (15, 10), (15, 20), (15, 21), (9, 15), (10, 15), (21, 15), (22, 15)]:
        ic.put(x, y, gold[4], "gold")
    ic.put(14, 12, (255, 255, 230), "orb")
    ic.outline({"cover": (8, 20, 42), "pages": (60, 46, 24), "gold": (60, 36, 6), "orb": (20, 52, 8)})
    return ic


def ayakkabi_bagcigi():
    ic = Icon()
    leather = ramp("#9b5a2c", 6)
    sole = ramp("#4a3528", 5)
    lace = ramp("#f4efe2", 5)
    boot = poly([(9, 4), (19, 4), (20, 16), (28, 19), (29, 25), (6, 25), (7, 14)])
    ic.shade_mask(boot, leather, "leather")
    so = rect(5, 25, 29, 27)
    ic.shade_mask(so, sole, "sole")
    # dil + bağcık delikleri
    for y in (7, 10, 13, 16):
        ic.put(11, y, leather[0], "leather")
        ic.put(17, y, leather[0], "leather")
    # çapraz bağcık
    for y in (7, 10, 13):
        for i in range(6):
            ic.put(11 + i, y + i // 2, lace[3 if i % 2 else 2], "lace")
            ic.put(17 - i, y + i // 2, lace[4 if i % 2 else 3], "lace")
    # sarkan uçlar + fiyonk
    for (x, y) in [(13, 4), (12, 3), (11, 2), (15, 4), (16, 3), (17, 2), (18, 2), (10, 2)]:
        ic.put(x, y, lace[4], "lace")
    for (x, y) in [(20, 3), (21, 4), (22, 5), (22, 6), (23, 7), (8, 3), (7, 4), (6, 5), (6, 6)]:
        ic.put(x, y, lace[2], "lace")
    for (x, y) in [(22, 18), (24, 19), (26, 20)]:  # dikiş
        ic.put(x, y, leather[4], "leather")
    ic.outline({"leather": (38, 18, 6), "sole": (16, 10, 8), "lace": (70, 62, 50)})
    return ic


def kol_saati():
    ic = Icon()
    strap = ramp("#7a4a2a", 6)
    metal = ramp("#c9a14a", 6)
    face = ramp("#f3ead2", 5)
    top = poly([(11, 1), (21, 1), (20, 9), (12, 9)])
    bot = poly([(12, 23), (20, 23), (21, 31), (11, 31)])
    ic.shade_mask(top, strap, "strap")
    ic.shade_mask(bot, strap, "strap")
    for y in (3, 5, 26, 28):
        for x in range(13, 20):
            if (x, y) in top or (x, y) in bot:
                ic.put(x, y, strap[1], "strap")
    bezel = ellipse(16, 16, 9.2, 9.2)
    ic.shade_mask(bezel, metal, "metal")
    dial = ellipse(16, 16, 7.0, 7.0)
    ic.shade_mask(dial, face, "face", rim=False)
    # saat çizgileri
    for ang in range(0, 360, 30):
        a = math.radians(ang)
        x = int(round(16 + math.sin(a) * 5.8 - 0.5))
        y = int(round(16 - math.cos(a) * 5.8 - 0.5))
        ic.put(x, y, (90, 70, 50), "face")
    # akrep/yelkovan
    for i in range(5):
        ic.put(15, 15 - i, (40, 30, 30), "face")
    for i in range(4):
        ic.put(16 + i, 16 + i // 2, (150, 30, 30), "face")
    ic.put(15, 15, (40, 30, 30), "face")
    ic.put(26, 15, metal[4], "metal")  # kurma topuzu
    ic.put(26, 16, metal[2], "metal")
    ic.put(12, 11, (255, 255, 250), "face")
    ic.outline({"strap": (36, 18, 8), "metal": (52, 34, 6), "face": (52, 34, 6)})
    return ic


def tornavida():
    ic = Icon()
    handle = ramp("#d0402a", 6)
    grip = ramp("#2d2d38", 5)
    steel = ramp("#9fb3c4", 6)
    shaft = thick_line(14, 18, 28, 4, 2.6)
    ic.shade_mask(shaft, steel, "steel", 21, 11, 10, 10)
    tip = thick_line(26.5, 5.5, 29.5, 2.5, 3.6)
    ic.shade_mask(tip - shaft, steel, "steel")
    ferrule = thick_line(12, 20, 15, 17, 5.2)
    ic.shade_mask(ferrule, ramp("#b8b8c0", 5), "steel")
    hd = thick_line(3, 29, 13, 19, 8.0)
    ic.shade_mask(hd - ferrule, handle, "handle", 8, 24, 7, 7)
    # kauçuk kanallar
    for k in range(4):
        for t in range(5):
            x = 5 + k * 2 + t
            y = 27 - k * 2 - t
            if (x, y) in hd and (x, y) not in ferrule:
                ic.put(x, y, grip[1 + (t % 2)], "grip")
    for (x, y) in [(25, 6), (24, 7), (23, 8), (22, 9)]:
        ic.put(x, y, steel[5], "steel")
    ic.put(6, 23, handle[5], "handle")
    ic.put(7, 22, handle[5], "handle")
    ic.outline({"steel": (24, 32, 44), "handle": (50, 8, 4), "grip": (10, 10, 14)})
    return ic


def kirilmaz_irade():
    ic = Icon()
    steel = ramp("#8ea4bd", 6)
    rim = ramp("#d9b45a", 6)
    glow = ramp("#46d4ff", 6)
    sh = poly([(16, 2), (28, 6), (27, 18), (16, 30), (5, 18), (4, 6)])
    ic.shade_mask(sh, rim, "rim")
    inner = poly([(16, 5), (25, 8), (24.5, 17.5), (16, 27), (7.5, 17.5), (7, 8)])
    ic.shade_mask(inner, steel, "steel")
    # parlayan dikey bant + rün (kalkan yenileme)
    for y in range(7, 26):
        w = 1 if y < 9 or y > 22 else 2
        for x in range(16 - w, 16 + w):
            if (x, y) in inner:
                ic.put(x, y, glow[3 if (y % 3) else 4], "glow")
    for (x, y) in [(12, 12), (13, 12), (19, 12), (20, 12), (12, 13), (20, 13), (13, 15), (19, 15), (14, 16), (18, 16)]:
        ic.put(x, y, glow[4], "glow")
    for (x, y) in [(9, 8), (10, 8), (9, 9)]:
        ic.put(x, y, steel[5], "steel")
    ic.put(15, 10, (235, 255, 255), "glow")
    ic.outline({"rim": (52, 32, 4), "steel": (20, 28, 40), "glow": (4, 40, 60)})
    return ic


def olum_esigi():
    ic = Icon()
    wood = ramp("#c79a43", 6)
    glass = ramp("#5f86a8", 5, dark=0.5, light=1.6)
    sand = ramp("#c2233a", 6)
    bone = ramp("#e8dfc4", 6)
    # üst/alt kapak
    ic.shade_mask(rect(7, 6, 25, 8), wood, "wood")
    ic.shade_mask(rect(7, 27, 25, 29), wood, "wood")
    # yan direkler
    ic.shade_mask(rect(7, 9, 8, 26), wood, "wood")
    ic.shade_mask(rect(24, 9, 25, 26), wood, "wood")
    # cam (kum saati şekli)
    g = poly([(10, 9), (22, 9), (17, 17.5), (22, 26), (10, 26), (15, 17.5)])
    ic.shade_mask(g, glass, "glass", 16, 17.5, 6, 9)
    # kalan kum (üstte az, altta çok)
    top_sand = poly([(13, 13), (19, 13), (16.6, 16.5), (15.4, 16.5)])
    ic.shade_mask(top_sand & g, sand, "sand")
    bot_sand = poly([(11, 26), (21, 26), (19, 22), (16, 20.5), (13, 22)])
    ic.shade_mask(bot_sand & g, sand, "sand")
    for y in range(17, 21):
        ic.put(16, y, sand[4], "sand")
    for (x, y) in [(11, 10), (12, 10), (11, 11)]:
        ic.put(x, y, (240, 252, 255), "glass")
    # tepede küçük kafatası
    sk = ellipse(16, 3.2, 4.0, 3.2)
    ic.shade_mask(sk, bone, "bone")
    ic.put(14, 3, (30, 10, 14), "bone")
    ic.put(17, 3, (30, 10, 14), "bone")
    ic.put(15, 5, bone[1], "bone")
    ic.put(16, 5, bone[1], "bone")
    ic.outline({"wood": (48, 26, 6), "glass": (24, 50, 74), "sand": (50, 4, 10), "bone": (44, 36, 24)})
    return ic


def kizil_hasat():
    ic = Icon()
    blade = ramp("#d42b3a", 6)
    edge = ramp("#ffb3a8", 4)
    wood = ramp("#6b4426", 6)
    handle = thick_line(6, 30, 15, 13, 3.0)
    ic.shade_mask(handle, wood, "wood", 10, 21, 6, 9)
    collar = thick_line(13.5, 15.5, 16.5, 11.5, 4.2)
    ic.shade_mask(collar, ramp("#9a9aa8", 5), "metal")
    outer = ellipse(19, 13, 11.5, 10.5)
    inner = ellipse(21.5, 15.5, 9.5, 8.5)
    crescent = {p for p in outer - inner if p[1] <= 17 and p[0] >= 12}
    ic.shade_mask(crescent, blade, "blade", 19, 13, 11.5, 10.5)
    for (x, y) in crescent:
        if (x, y + 1) not in crescent and (x + 1, y + 1) in inner:
            ic.put(x, y, edge[2], "blade")
    # kan damlaları
    for (x, y) in [(28, 17), (28, 18), (27, 19), (28, 20), (25, 22), (25, 23)]:
        ic.put(x, y, blade[2] if y < 20 else blade[1], "blade")
    ic.put(14, 4, edge[3], "blade")
    ic.put(15, 3, edge[3], "blade")
    ic.outline({"wood": (30, 16, 6), "metal": (24, 24, 30), "blade": (48, 4, 10)})
    return ic


def ruhlarin_akisi():
    ic = Icon()
    soul = ramp("#3fe0c8", 6)
    core = ramp("#c8fff2", 4)
    # üç kıvrımlı ruh
    for k, (ph, r0) in enumerate([(0.0, 12.0), (2.1, 11.0), (4.2, 12.5)]):
        pts = []
        for i in range(26):
            t = i / 25.0
            a = ph + t * 3.6
            r = r0 * (1.0 - 0.75 * t)
            pts.append((16 + math.cos(a) * r, 16 + math.sin(a) * r * 0.9, 3.4 * (1.0 - 0.6 * t) + 0.6))
        m = set()
        for (x, y, w) in pts:
            m |= ellipse(x, y, w / 2 + 0.3, w / 2 + 0.3)
        ic.shade_mask(m, soul, "soul", 16, 16, 13, 13)
        hx, hy, _ = pts[0]
        head = ellipse(hx, hy, 2.6, 2.6)
        ic.shade_mask(head, soul, "soul")
        ic.put(int(hx) - 1, int(hy) - 1, core[3], "soul")
    c = ellipse(16, 16, 3.2, 3.2)
    ic.shade_mask(c, core, "core", gloss=[(15, 15)])
    for (x, y) in [(3, 4), (28, 6), (27, 27), (4, 26)]:
        ic.put(x, y, soul[4], "spark")
    ic.outline({"soul": (4, 44, 44), "core": (20, 80, 70), "spark": (10, 50, 50)})
    return ic


def zaman_kiran():
    ic = Icon()
    gold = ramp("#e2b13c", 6)
    face = ramp("#2b2f6b", 6)
    ice = ramp("#8fe8ff", 6)
    rimm = ring(15, 16, 12.5, 12.5, 2.6)
    ic.shade_mask(rimm, gold, "gold", 15, 16, 12.5, 12.5)
    dial = ellipse(15, 16, 10.2, 10.2)
    ic.shade_mask(dial, face, "face", rim=False)
    # roma çizgileri
    for ang in range(0, 360, 30):
        a = math.radians(ang)
        ic.put(int(round(15 + math.sin(a) * 8.2 - 0.5)), int(round(16 - math.cos(a) * 8.2 - 0.5)), gold[4], "gold")
    # kırık: zikzak çatlak + kopan parça (sağ üst)
    crack = [(15, 16), (17, 14), (18, 15), (20, 12), (21, 13), (23, 9), (24, 8)]
    for i in range(len(crack) - 1):
        x0, y0 = crack[i]
        x1, y1 = crack[i + 1]
        for t in range(6):
            x = int(round(x0 + (x1 - x0) * t / 5))
            y = int(round(y0 + (y1 - y0) * t / 5))
            ic.put(x, y, ice[5], "ice")
    for (x, y) in list(ic.px.keys()):
        if x >= 22 and y <= 9 and (x - 22) + (9 - y) >= 2:
            ic.erase(x, y)
    shard = poly([(25, 2), (30, 3), (28, 7)])
    ic.shade_mask(shard, gold, "gold")
    for (x, y) in [(29, 9), (30, 10), (27, 11)]:
        ic.put(x, y, ice[4], "ice")
    # akrep/yelkovan (donmuş, buzlu)
    for i in range(6):
        ic.put(15, 16 - i, ice[3], "ice")
    for i in range(5):
        ic.put(15 - i, 16 + i // 2, ice[3], "ice")
    ic.put(15, 16, (255, 255, 255), "ice")
    for (x, y) in [(6, 9), (7, 8), (8, 7)]:
        ic.put(x, y, gold[5], "gold")
    ic.outline({"gold": (56, 34, 4), "face": (8, 8, 30), "ice": (10, 50, 70)})
    return ic


def azrailin_gozu():
    ic = Icon()
    lid = ramp("#4b2a68", 6)
    white = ramp("#e9dccb", 5)
    iris = ramp("#e0213a", 6)
    feather = ramp("#2a2238", 5)
    # yan siyah tüyler
    for side in (-1, 1):
        for k in range(4):
            x0 = 16 + side * (9 + k * 1.6)
            m = thick_line(16 + side * 8, 16, x0 + side * 2, 7 + k * 4.5, 2.4)
            ic.shade_mask(m, feather, "feather")
    eye = poly([(3, 16), (9, 9), (16, 7), (23, 9), (29, 16), (23, 23), (16, 25), (9, 23)])
    ic.shade_mask(eye, lid, "lid")
    inner = poly([(7, 16), (11, 12), (16, 11), (21, 12), (25, 16), (21, 20), (16, 21), (11, 20)])
    ic.shade_mask(inner, white, "white", rim=False)
    ir = ellipse(16, 16, 4.6, 4.6)
    ic.shade_mask(ir & inner, iris, "iris")
    for y in range(13, 20):
        ic.put(16, y, (18, 4, 8), "iris")  # yarık göz bebeği
    ic.put(15, 16, (18, 4, 8), "iris")
    ic.put(17, 16, (18, 4, 8), "iris")
    ic.put(14, 13, (255, 220, 220), "iris")
    # alttan damla (kanlı gözyaşı)
    for (x, y) in [(16, 25), (16, 26), (16, 27), (15, 28), (16, 28), (17, 28), (16, 29)]:
        ic.put(x, y, iris[2], "iris")
    for (x, y) in [(10, 10), (11, 9), (12, 9)]:
        ic.put(x, y, lid[5], "lid")
    ic.outline({"lid": (16, 6, 24), "white": (40, 30, 36), "iris": (44, 2, 8), "feather": (8, 6, 12)})
    return ic


ICONS = {
    "ceviklik_yuzugu": ceviklik_yuzugu, "tecrube_kitabi": tecrube_kitabi, "ayakkabi_bagcigi": ayakkabi_bagcigi,
    "kol_saati": kol_saati, "tornavida": tornavida, "kirilmaz_irade": kirilmaz_irade, "olum_esigi": olum_esigi,
    "kizil_hasat": kizil_hasat, "ruhlarin_akisi": ruhlarin_akisi, "zaman_kiran": zaman_kiran, "azrailin_gozu": azrailin_gozu,
}


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    ims = {}
    for key, fn in ICONS.items():
        im = fn().image()
        im.save(os.path.join(OUT_DIR, key + ".png"))
        ims[key] = im
    if "--preview" in sys.argv:
        path = sys.argv[sys.argv.index("--preview") + 1]
        sc = 8
        keys = list(ims.keys())
        out = Image.new("RGBA", (6 * (N * sc + 8), 2 * (N * sc + 8)), (60, 60, 70, 255))
        for i, k in enumerate(keys):
            out.alpha_composite(ims[k].resize((N * sc, N * sc), Image.NEAREST), ((i % 6) * (N * sc + 8), (i // 6) * (N * sc + 8)))
        out.save(path)
    print("ok", len(ims))


if __name__ == "__main__":
    main()
