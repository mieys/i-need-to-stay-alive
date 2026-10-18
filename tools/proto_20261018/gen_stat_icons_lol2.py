# -*- coding: utf-8 -*-
"""Mini stat paneli LoL tarzı PÜRÜZSÜZ simgeler (2026-10-18, kullanıcı: "mini stat penceresindeki yazılar ve ikonlar çok çirkin,
league of legends gibi olsun, okunurluk kolaylığı").

Piksel simge yerine (madde 152) vektör gibi pürüzsüz simge: her stat TEK net siluet + tek kategori rengi. Şekiller 64 birimlik
uzayda maske (çokgen/daire/kalın çizgi) olarak tanımlı, 768 px tuvalde çizilip 48 px'e kutu küçültmeyle (16x, kenar yumuşatma)
indirilir; oyun 48 px'i 24 px'te (0,5, doğrusal süzgeç) çizer -> 1080p'de birebir, 1440p'de de keskin.

Üç çizim dili (aynı şekil, farklı el) - kullanıcı "B çok iyi" dedi: OYUNA sadece b yazılır, a/c sadece önizlemede:
  a = "Altın Çerçeve"  : dikey renk geçişi + üst-sol parlak / alt-sağ koyu kenar (kabartma), ince koyu dış hat + yumuşak gölge
  b = "Düz Glif"       : LoL HUD'u gibi tek renk düz siluet, dış hat yok, parçalar arası ince boşluk, kakma = açık ton, alt gölge
  c = "Madalyon"       : kategori renginde koyu yuvarlak madalyon + altın halka, içinde krem beyaz siluet
Çıktı: assets/ui/stat_mini_lol/<id>.png (48x48, el b; hud_stat_panel.gd) + tools/proto_20261018/out/stat_lol/ikonlar_onizleme.png (3 el)
Kullanım: python tools/proto_20261018/gen_stat_icons_lol2.py
"""
import math
import os
from functools import reduce

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ASSET_DIR = os.path.join(ROOT, "assets", "ui", "stat_mini_lol")
OUT_DIR = os.path.join(ROOT, "tools", "proto_20261018", "out", "stat_lol")
S = 768
U = S / 64.0
OUT_PX = 48
GAME_HAND = "b"  # oyuna giden el (2026-10-18 kullanıcı seçimi)
XF = [1.0]  # siluet ölçeği (madalyonda küçülür), merkez (32,32)


# ------------------------------------------------------------------ renk
def hx(c):
    c = c.lstrip("#")
    return tuple(int(c[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def light(c, t):
    return mix(c, (255, 255, 255), t)


def dark(c, t):
    return mix(c, (0, 0, 0), t)


# ------------------------------------------------------------------ maskeler
def P(x, y):
    k = XF[0]
    return ((32 + (x - 32) * k) * U, (32 + (y - 32) * k) * U)


def new():
    return Image.new("L", (S, S), 0)


def poly(pts):
    m = new()
    ImageDraw.Draw(m).polygon([P(*p) for p in pts], fill=255)
    return m


def circ(cx, cy, r):
    m = new()
    x, y = P(cx, cy)
    rr = r * U * XF[0]
    ImageDraw.Draw(m).ellipse((x - rr, y - rr, x + rr, y + rr), fill=255)
    return m


def line(pts, w):
    m = new()
    d = ImageDraw.Draw(m)
    q = [P(*p) for p in pts]
    ww = w * U * XF[0]
    d.line(q, fill=255, width=max(1, int(round(ww))), joint="curve")
    for x, y in (q[0], q[-1]):
        d.ellipse((x - ww / 2, y - ww / 2, x + ww / 2, y + ww / 2), fill=255)
    return m


def arc(cx, cy, r, a0, a1, w, n=48):
    pts = [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)), cy + r * math.sin(math.radians(a0 + (a1 - a0) * i / n)))
           for i in range(n + 1)]
    return line(pts, w)


def union(*ms):
    return reduce(ImageChops.lighter, ms)


def sub(a, *bs):
    for b in bs:
        a = ImageChops.subtract(a, b)
    return a


def inter(a, b):
    return ImageChops.multiply(a, b)


def shift(m, dx, dy):
    o = new()
    o.paste(m, (int(round(dx * U)), int(round(dy * U))))
    return o


def dilate(m, r):
    """Yuvarlak genişletme (r birim): bulanıklaştır + düşük eşik (düz kenarda ~r)."""
    if r <= 0:
        return m
    b = m.filter(ImageFilter.GaussianBlur(r * U * 0.5))
    return b.point(lambda v: 255 if v > 6 else 0)


def axis(o, ang, pts):
    """Yerel (u: eksen boyunca, v: dik) -> dünya. ang derece, y aşağı."""
    c, s = math.cos(math.radians(ang)), math.sin(math.radians(ang))
    return [(o[0] + u * c - v * s, o[1] + u * s + v * c) for u, v in pts]


def axis_pt(o, ang, u, v=0.0):
    return axis(o, ang, [(u, v)])[0]


def star(cx, cy, n, r_out, r_in, rot=-90.0, jitter=None):
    pts = []
    for i in range(n * 2):
        a = math.radians(rot + i * 180.0 / n)
        r = r_out if i % 2 == 0 else r_in
        if jitter and i % 2 == 0:
            r *= jitter[(i // 2) % len(jitter)]
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return poly(pts)


def shield(cx, cy, w, h):
    """Kalkan (heater): üst kenar ortada hafif kalkık, yanlar düz iner, alt sivri uca eğri."""
    pts = []
    for i in range(9):  # üst kenar sol -> sağ
        t = i / 8.0
        x = -w + 2 * w * t
        pts.append((cx + x, cy - h + 2.2 * (x / w) ** 2 - 1.2))
    side_end = cy + h * 0.05
    pts.append((cx + w, side_end))
    for i in range(1, 13):  # sağ alt eğri -> uç
        t = i / 12.0
        x = w * (1 - t) ** 1.0
        y = side_end + (cy + h - side_end) * (1 - (1 - t) ** 1.7)
        pts.append((cx + x * (1 - t * 0.0), y))
    for p in reversed(pts[9:-1]):
        pts.append((2 * cx - p[0], p[1]))
    pts.append((cx - w, side_end))
    return poly(pts)


def heart(cx, cy, size):
    raw = []
    for i in range(96):
        t = 2 * math.pi * i / 96
        raw.append((16 * math.sin(t) ** 3, -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))))
    xs = [p[0] for p in raw]
    ys = [p[1] for p in raw]
    k = size / (max(xs) - min(xs))
    my = (max(ys) + min(ys)) / 2
    return poly([(cx + x * k, cy + (y - my) * k) for x, y in raw])


def drop(cx, cy, r, apex_h):
    d = apex_h
    phi = math.acos(r / d)
    tl = (cx - r * math.sin(phi), cy - r * math.cos(phi))
    tr = (cx + r * math.sin(phi), cy - r * math.cos(phi))
    return union(circ(cx, cy, r), poly([(cx, cy - d), tr, tl]))


# ------------------------------------------------------------------ simgeler
# Her simge: (kategori rengi, [(maske, renk, rol)]); rol fill = gövde parçası, cut = koyu oyma, inlay = açık kakma.
ORANGE = hx("#f08a35")
YELLOW = hx("#f4c842")
CORAL = hx("#ff6a45")
CRIMSON = hx("#e0383e")
CYAN = hx("#6fcbe2")
BLOOD = hx("#d42c42")
TEAL = hx("#46cdb0")
CREAM = hx("#e8dcc2")
BLUE = hx("#5b9cff")
HEART = hx("#ee4a64")
GREEN = hx("#5fcf6a")
GOLD = hx("#f0c43c")
KHAKI = hx("#d9c27f")
STEEL = hx("#a9bccf")


def sword(center, ang, L, bw, color, scale=1.0):
    """Kılıç/hançer: u=0 siper; bıçak +u, kabza -u. center = toplam boyun ortası."""
    k = scale
    o = axis_pt(center, ang, -((L * k) - 17 * k) / 2.0)
    blade = poly(axis(o, ang, [(0, -bw * k), ((L - 8) * k, -bw * k), (L * k, 0), ((L - 8) * k, bw * k), (0, bw * k)]))
    fuller = line(axis(o, ang, [(3 * k, 0), ((L - 11) * k, 0)]), 1.8 * k)
    guard = line(axis(o, ang, [(-1 * k, -11 * k), (-1 * k, 11 * k)]), 5.2 * k)
    grip = line(axis(o, ang, [(-3.5 * k, 0), (-12 * k, 0)]), 5.0 * k)
    pommel = circ(*axis_pt(o, ang, -15.5 * k), 4.2 * k)
    return [(blade, light(color, 0.5), "fill"), (fuller, color, "cut"), (grip, dark(color, 0.45), "fill"),
            (guard, color, "fill"), (pommel, color, "fill")]


def icon_damage():
    return ORANGE, sword((32, 32), -45, 42, 5.6, ORANGE)


def icon_fire_rate():
    c = YELLOW
    parts = sword((37, 27), -45, 34, 5.0, c, 0.86)
    o = (37, 27)
    lines = []
    for v, u0, u1 in ((-10, -24, -15), (0.0, -31, -19), (10, -24, -15)):
        lines.append(line(axis(o, -45, [(u0, v), (u1, v)]), 4.4))
    return c, [(union(*lines), c, "fill")] + parts


def icon_crit_chance():
    c = CORAL
    ring = sub(circ(32, 32, 21), circ(32, 32, 16.2))
    ticks = union(line([(32, 4), (32, 15)], 4.4), line([(32, 49), (32, 60)], 4.4),
                  line([(4, 32), (15, 32)], 4.4), line([(49, 32), (60, 32)], 4.4))
    core = star(32, 32, 4, 10.5, 3.4)
    return c, [(union(ring, ticks), c, "fill"), (core, light(c, 0.55), "fill")]


def icon_crit_damage():
    c = CRIMSON
    outer = star(32, 33, 9, 29, 15.5, rot=-90, jitter=[1.0, 0.86, 0.96, 0.82, 0.98, 0.88, 0.93, 0.84, 0.95])
    inner = star(32, 33, 7, 15.5, 8.5, rot=-70, jitter=[1.0, 0.85, 0.95, 0.88, 0.97, 0.86, 0.92])
    return c, [(outer, c, "fill"), (inner, hx("#ffb347"), "fill")]


def icon_cooldown():
    c = CYAN
    glass = poly([(19, 12), (45, 12), (35.5, 30.5), (35.5, 33.5), (45, 52), (19, 52), (28.5, 33.5), (28.5, 30.5)])
    sand_top = poly([(24.5, 18.5), (39.5, 18.5), (33, 29), (31, 29)])
    sand_bot = poly([(21.5, 52), (42.5, 52), (37, 43.5), (27, 43.5)])
    stream = line([(32, 30), (32, 45)], 1.6)
    bars = union(line([(15, 9.5), (49, 9.5)], 5.4), line([(15, 54.5), (49, 54.5)], 5.4))
    return c, [(glass, light(c, 0.55), "fill"), (union(sand_top, sand_bot, stream), hx("#f2c96e"), "inlay"), (bars, c, "fill")]


def icon_lifesteal():
    c = BLOOD
    body = drop(32, 39, 16, 34)
    shine = line([(24.5, 35), (23.8, 40), (25.5, 45)], 3.6)
    return c, [(body, c, "fill"), (shine, light(c, 0.65), "inlay")]


def icon_dodge():
    c = TEAL
    o, ang, L = (13, 53), -50.0, 52.0
    top, bot = [], []
    for i in range(25):
        u = 9 + (L - 9) * i / 24.0
        t = (u - 9) / (L - 9)
        w = 11.5 * math.sin(math.pi * min(1.0, t * 1.05)) ** 0.75
        top.append((u, -w))
        bot.append((u, w * 0.78))
    vane = poly(axis(o, ang, top + list(reversed(bot))))
    notch1 = poly(axis(o, ang, [(26, -14), (31, -5), (22, -13)]))
    notch2 = poly(axis(o, ang, [(36, -13), (40, -4.5), (32.5, -12.5)]))
    quill = line(axis(o, ang, [(0, 0), (12, 0)]), 3.2)
    spine = line(axis(o, ang, [(9, 0), (L - 7, 0)]), 1.6)
    return c, [(sub(vane, notch1, notch2), c, "fill"), (quill, light(c, 0.35), "fill"), (spine, c, "cut")]


def icon_speed():
    c = CREAM
    boot = union(poly([(23, 10), (39, 10), (39, 33), (49, 37), (55, 43), (56, 49), (23, 49)]), circ(50, 44, 5.5))
    sole = line([(22.5, 50.5), (55.5, 50.5)], 4.6)
    cuff = line([(22, 11), (40, 11)], 5.2)
    speed = union(line([(5, 22), (15, 22)], 3.4), line([(3, 31), (16, 31)], 3.4), line([(5, 40), (15, 40)], 3.4))
    return c, [(speed, c, "fill"), (boot, c, "fill"), (sole, dark(c, 0.42), "fill"), (cuff, light(c, 0.5), "fill")]


def icon_shield_pen():
    c = hx("#ff7a3d")
    sh = shield(30, 34, 17, 22)
    crack = line([(30, 13), (26, 23), (33, 30), (27.5, 39)], 1.9)
    shaft = line([(57, 7), (21, 43)], 3.8)
    head = poly(axis((15, 49), 135, [(-1, -6.5), (10, 0), (-1, 6.5), (2, 0)]))
    fletch = poly(axis((57, 7), 135, [(-2, -6), (5, 0), (-2, 6), (0, 0)]))
    return c, [(sh, STEEL, "fill"), (crack, STEEL, "cut"), (union(shaft, fletch), c, "fill"), (head, light(c, 0.35), "fill")]


def icon_range():
    c = KHAKI
    shaft = line([(16, 32), (48, 32)], 5.6)
    heads = union(poly([(8.5, 32), (21, 20.5), (21, 43.5)]), poly([(55.5, 32), (43, 20.5), (43, 43.5)]))
    bars = union(line([(4, 16), (4, 48)], 5.0), line([(60, 16), (60, 48)], 5.0))
    return c, [(union(shaft, heads), c, "fill"), (bars, dark(c, 0.15), "fill")]


def _blue_shield():
    return shield(32, 33, 21, 26)


def icon_shield_protection():
    c = BLUE
    inner = sub(shield(32, 31, 12, 15.5), shield(32, 31.2, 7.4, 10))
    return c, [(_blue_shield(), c, "fill"), (inner, light(c, 0.7), "inlay")]


def icon_shield_amount():
    c = BLUE
    plus = union(line([(32, 20), (32, 43)], 6.2), line([(20.5, 31.5), (43.5, 31.5)], 6.2))
    return c, [(_blue_shield(), c, "fill"), (plus, light(c, 0.7), "inlay")]


def icon_shield_regen():
    c = BLUE
    ring = arc(32, 32, 10, -60, 205, 4.2)
    a = math.radians(-60)
    tip = (32 + 10 * math.cos(a), 32 + 10 * math.sin(a))
    head = poly(axis(tip, -60 + 90, [(6, 0), (-3, -6), (-3, 6)]))
    return c, [(_blue_shield(), c, "fill"), (union(ring, head), light(c, 0.7), "inlay")]


def icon_health_regen():
    c = HEART
    h = heart(32, 33, 52)
    arrow = union(line([(32, 46), (32, 29)], 5.0), poly([(32, 17.5), (22.5, 29.5), (41.5, 29.5)]))
    return c, [(h, c, "fill"), (arrow, light(c, 0.75), "inlay")]


def icon_heal_power():
    c = GREEN
    cross = union(line([(30, 14), (30, 52)], 13.5), line([(11, 33), (49, 33)], 13.5))
    spark = star(51, 12, 4, 8.5, 2.6)
    return c, [(cross, c, "fill"), (spark, hx("#fff1a8"), "fill")]


def icon_luck():
    c = GOLD
    leaves = []
    for ang in (-45, 45, 135, 225):
        a = math.radians(ang)
        cx, cy = 32 + 11.5 * math.cos(a), 30 + 11.5 * math.sin(a)
        # yaprak = kalp, ucu merkeze bakar
        raw = []
        for i in range(64):
            t = 2 * math.pi * i / 64
            raw.append((16 * math.sin(t) ** 3, -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))))
        k = 0.78
        rot = math.radians(ang - 90 - 180)
        pts = []
        for x, y in raw:
            x, y = x * k, (y + 3) * k
            pts.append((cx + x * math.cos(rot) - y * math.sin(rot), cy + x * math.sin(rot) + y * math.cos(rot)))
        leaves.append(poly(pts))
    stem = line([(32, 32), (36, 46), (44, 58)], 3.6)
    vein = union(line([(32, 30), (22.5, 20.5)], 1.5), line([(32, 30), (41.5, 20.5)], 1.5),
                 line([(32, 30), (22.5, 39.5)], 1.5), line([(32, 30), (41.5, 39.5)], 1.5))
    return c, [(stem, dark(c, 0.25), "fill"), (union(*leaves), c, "fill"), (vein, c, "cut")]


ICONS = {
    "damage": icon_damage, "fire_rate": icon_fire_rate, "crit_chance": icon_crit_chance, "crit_damage": icon_crit_damage,
    "cooldown_reduction": icon_cooldown, "lifesteal": icon_lifesteal, "dodge": icon_dodge, "speed": icon_speed,
    "shield_pen_percent": icon_shield_pen, "range": icon_range, "shield_protection": icon_shield_protection,
    "shield_amount": icon_shield_amount, "shield_regen": icon_shield_regen, "health_regen": icon_health_regen,
    "heal_power": icon_heal_power, "luck": icon_luck,
}


# ------------------------------------------------------------------ çizim elleri
def paint(img, mask, color, alpha=1.0):
    if alpha < 1.0:
        mask = mask.point(lambda v: int(v * alpha))
    layer = Image.new("RGBA", (S, S), color + (255,))
    layer.putalpha(mask)
    img.alpha_composite(layer)


def paint_grad(img, mask, top, bot):
    g = Image.linear_gradient("L").resize((S, S))
    layer = Image.composite(Image.new("RGB", (S, S), bot), Image.new("RGB", (S, S), top), g).convert("RGBA")
    layer.putalpha(mask)
    img.alpha_composite(layer)


def edge(mask, dx, dy):
    """mask'ın (dx,dy) yönüne BAKMAYAN kenar bandı: mask - mask kaydırılmış."""
    return sub(mask, shift(mask, dx, dy))


def hand_a(parts):
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    fills = [m for m, _, r in parts if r == "fill"]
    total = union(*fills)
    rim = dilate(total, 2.1)
    paint(img, shift(rim, 0, 1.6).filter(ImageFilter.GaussianBlur(U * 1.2)), (0, 0, 0), 0.55)
    paint(img, rim, (12, 9, 7))
    for m, c, role in parts:
        if role == "fill":
            paint(img, dilate(m, 1.0), dark(c, 0.72))
            paint_grad(img, m, light(c, 0.32), dark(c, 0.30))
            paint(img, edge(m, 1.5, 1.5), light(c, 0.62), 0.9)
            paint(img, edge(m, -1.3, -1.3), dark(c, 0.45), 0.75)
        elif role == "cut":
            paint(img, m, dark(c, 0.62))
        else:
            paint(img, dilate(m, 0.9), dark(c, 0.62))
            paint_grad(img, m, light(c, 0.25), dark(c, 0.06))
    return img


def hand_b(parts, cat):
    """LoL HUD'undaki gibi DÜZ glif: tek kategori rengi, dış hat yok; üst üste binen parçalar arasında ince BOŞLUK,
    oyma = delik, kakma = açık ton (koyu kakma kalpte çatlak gibi okundu). Koyu levhada okunsun diye sadece yumuşak alt gölge."""
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    glyph = new()
    for m, c, role in parts:
        if role == "fill":
            glyph = union(sub(glyph, dilate(m, 1.1)), m)
        else:
            glyph = sub(glyph, dilate(m, 0.0))
    inl = union(new(), *[m for m, _, r in parts if r == "inlay"])
    paint(img, shift(dilate(union(glyph, inl), 0.6), 0, 1.4).filter(ImageFilter.GaussianBlur(U * 0.9)), (0, 0, 0), 0.85)
    col = light(cat, 0.12)
    paint(img, glyph, col)
    paint(img, edge(glyph, 0, 1.6), light(cat, 0.55), 0.8)
    paint(img, inl, light(cat, 0.82))
    return img


def hand_c(make, cat):
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    XF[0] = 1.0
    disc = circ(32, 32, 31)
    paint(img, dilate(disc, 1.2), (12, 9, 7))
    paint_grad(img, disc, dark(cat, 0.35), dark(cat, 0.72))
    ring = sub(disc, circ(32, 32, 28.6))
    paint_grad(img, ring, hx("#f3d58f"), hx("#8a6428"))
    paint(img, sub(circ(32, 32, 28.6), circ(32, 32, 27.6)), (12, 9, 7), 0.8)
    XF[0] = 0.74
    _, parts = make()
    XF[0] = 1.0
    glyph = union(*[m for m, _, r in parts if r == "fill"])
    paint(img, shift(glyph, 0.6, 1.0).filter(ImageFilter.GaussianBlur(U * 0.6)), (0, 0, 0), 0.7)
    paint_grad(img, glyph, hx("#fffaf0"), hx("#e9d9b8"))
    for m, c, role in parts:
        if role == "cut":
            paint(img, m, dark(cat, 0.55))
        elif role == "inlay":
            paint(img, m, cat)
    return img


def shrink(img):
    return img.convert("RGBa").resize((OUT_PX, OUT_PX), Image.BOX).convert("RGBA")


def main():
    hands = {"a": lambda mk: hand_a(mk()[1]), "b": lambda mk: hand_b(mk()[1], mk()[0]), "c": lambda mk: hand_c(mk, mk()[0])}
    sheet = Image.new("RGBA", (16 * 52 + 8, 3 * 2 * 52 + 8), (40, 28, 19, 255))
    for hi, (hk, fn) in enumerate(hands.items()):
        for ii, (sid, mk) in enumerate(ICONS.items()):
            XF[0] = 1.0
            im = shrink(fn(mk))
            if hk == GAME_HAND:
                os.makedirs(ASSET_DIR, exist_ok=True)
                im.save(os.path.join(ASSET_DIR, sid + ".png"))
            sheet.alpha_composite(im.resize((24, 24), Image.BILINEAR), (8 + ii * 52 + 12, 8 + hi * 104 + 12))
            sheet.alpha_composite(im, (8 + ii * 52, 8 + hi * 104 + 52))
    print("yazıldı:", ASSET_DIR, "(el %s)" % GAME_HAND)
    os.makedirs(OUT_DIR, exist_ok=True)
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(os.path.join(OUT_DIR, "ikonlar_onizleme.png"))


if __name__ == "__main__":
    main()
