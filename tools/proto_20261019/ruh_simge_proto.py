# -*- coding: utf-8 -*-
"""Ruh Kıymığı SİMGE prototipleri (madde 319; oyuna bağlı DEĞİL).

16x16 ızgara (altın simgesi icon_gold_coin.png ile aynı yoğunluk), 1 px dış hat, oyunda
NEAREST + tam katlı ölçek (16/32/48) düşünülerek çizildi.
  A Ruh Kristali   - bugünkü 4 yüzlü elmasın piksel sanatı hâli (en az değişiklik)
  B Kırık Kıymık   - eğik, alt ucu kırık cam kıymığı, içinde parlayan ruh kıvrımı
  C Ruh Alevi      - camgöbeği ruh alevi (damla gövde, sağa kıvrılan uç)
  D Ruh Taşı       - mor ametist kümesi (Oyun Bitti ekranındaki mor desenle aynı aile)

Çıktı tools/proto_20261019/out/ruh_simge/:
  ruh_simge_karsilastirma.png  - büyük çizim + gerçek boylar + kilitli + para ailesi
  ruh_simge_baglam.png         - gerçek Ruh Mağazası yakalamasında eski simgenin yerine
  ruh_<x>_16.png               - tek tek 16x16 dokular

Çalıştır: python tools/proto_20261019/ruh_simge_proto.py
"""
import math
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "tools", "proto_20261019", "out", "ruh_simge")
FONT = os.path.join(ROOT, "assets", "fonts", "m5x7.ttf")
CAPTURE = os.path.join(ROOT, "tools", "proto_20261016", "out", "ruh_magaza", "gercek", "gercek_f_ana.png")
COIN = os.path.join(ROOT, "assets", "ui", "newui", "icon_gold_coin.png")
WSHARD = os.path.join(ROOT, "assets", "pickups", "weapon_shard", "shard_icon.png")

N = 16


def hx(s):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


# ------------------------------------------------------------------ yardımcılar
def inside(poly, x, y):
    """Nokta çokgende mi (çift-tek kuralı)."""
    c = False
    n = len(poly)
    for i in range(n):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % n]
        if (y1 > y) != (y2 > y):
            t = (y - y1) / (y2 - y1)
            if x < x1 + t * (x2 - x1):
                c = not c
    return c


def grid():
    return [[None] * N for _ in range(N)]


def outline(g, col):
    """Dolu piksellerin 4 komşusundaki boş hücreler dış hat olur (küçük harf = hatsız süs)."""
    add = []
    for y in range(N):
        for x in range(N):
            if g[y][x] is not None:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < N and 0 <= yy < N and g[yy][xx] is not None and not g[yy][xx][1]:
                    add.append((x, y))
                    break
    for x, y in add:
        g[y][x] = (col, False)


def to_img(g):
    im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    for y in range(N):
        for x in range(N):
            if g[y][x] is not None:
                im.putpixel((x, y), g[y][x][0])
    return im


def put(g, x, y, col, deco=False):
    if 0 <= x < N and 0 <= y < N:
        g[y][x] = (col, deco)


def sparkle(g, cx, cy, core, arm):
    """Hatsız 4 kollu küçük parıltı (düz, dither yok)."""
    put(g, cx, cy, core, True)
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        put(g, cx + dx, cy + dy, arm, True)


# ------------------------------------------------------------------ A Ruh Kristali
def icon_a():
    W, L, M, D, E = hx("#f2feff"), hx("#b4f1f5"), hx("#73d2dc"), hx("#3f9fb0"), hx("#27707f")
    O = hx("#0e2129")
    g = grid()
    poly = [(8.0, 1.0), (14.6, 6.6), (8.0, 15.0), (1.4, 6.6)]
    for y in range(N):
        for x in range(N):
            px, py = x + 0.5, y + 0.5
            if not inside(poly, px, py):
                continue
            up = py < 6.6
            left = px < 8.0
            col = (L if left else M) if up else (D if left else E)
            g[y][x] = (col, False)
    # sol üst yüzün kenarı boyunca ince parlaklık + orta sırtta ışık
    for y in range(N):
        row = [x for x in range(N) if g[y][x] is not None]
        if row and y <= 6:
            put(g, row[0], y, W)
    put(g, 7, 2, W)
    put(g, 7, 3, W)
    put(g, 8, 7, M)  # alt sağ yüzün tepesinde yansıma
    put(g, 6, 7, L)
    outline(g, O)
    sparkle(g, 13, 2, hx("#ffffff"), hx("#b4f1f5"))
    return to_img(g)


# ------------------------------------------------------------------ B Kırık Kıymık
def side(a, b, px, py):
    return (b[0] - a[0]) * (py - a[1]) - (b[1] - a[1]) * (px - a[0])


def icon_b():
    W, L, M, D, E = hx("#effcff"), hx("#a6e9f2"), hx("#5fc6d6"), hx("#2f8ea3"), hx("#1d5f73")
    O = hx("#0d1f27")
    g = grid()
    # uzun, eğik, köşeli kıymık: sağ üstte sivri uç, sol altta kırık (zikzak) kenar
    poly = [(12.4, 0.4), (14.4, 3.6), (9.2, 14.6), (7.4, 12.2), (6.0, 14.8),
            (4.6, 12.6), (2.2, 14.0), (2.0, 10.8), (8.2, 2.0)]
    top = (12.4, 0.4)
    ridge = (5.4, 14.0)  # sol (aydınlık) yüz | sağ (gölge) yüz
    core = (8.4, 7.4)
    for y in range(N):
        for x in range(N):
            px, py = x + 0.5, y + 0.5
            if not inside(poly, px, py):
                continue
            sd = side(top, ridge, px, py) / math.hypot(ridge[0] - top[0], ridge[1] - top[1])
            col = L if sd > 0 else (M if sd > -0.7 else D)
            # içte hapsolmuş küçük ruh ışığı
            dd = math.hypot(px - core[0], py - core[1])
            if dd < 1.1:
                col = W
            elif dd < 1.9 and col == M:
                col = L
            g[y][x] = (col, False)
    for y in range(N):
        row = [x for x in range(N) if g[y][x] is not None]
        if not row:
            continue
        if 2 <= y <= 10:
            put(g, row[0], y, W)   # sol dış kenar parlak
        if y >= 3:
            put(g, row[-1], y, E)  # sağ dış kenar koyu
    outline(g, O)
    sparkle(g, 3, 3, hx("#ffffff"), hx("#a6e9f2"))
    return to_img(g)


# ------------------------------------------------------------------ C Ruh Alevi
def icon_c():
    W, L, M, D, E = hx("#f4ffff"), hx("#bff8f6"), hx("#6fe0e0"), hx("#2fa6b4"), hx("#1d6e84")
    O = hx("#0c1f2a")
    g = grid()
    cx, cy, r = 7.6, 11.0, 4.0  # yuvarlak gövde

    def tongue(px, py, base, tip, w):
        if py > base[1] or py < tip[1]:
            return False
        t = (base[1] - py) / (base[1] - tip[1])
        mid = base[0] + (tip[0] - base[0]) * (t ** 1.6)
        return abs(px - mid) <= w * (1.0 - t) ** 1.1

    def flame(px, py):
        if (px - cx) ** 2 + (py - cy) ** 2 <= r * r:
            return True
        return (tongue(px, py, (7.8, 10.6), (9.8, 0.6), 4.0)
                or tongue(px, py, (5.2, 9.6), (2.6, 3.6), 2.2)
                or tongue(px, py, (10.6, 9.6), (12.8, 5.2), 1.7))

    core = (7.0, 11.2)
    for y in range(N):
        for x in range(N):
            px, py = x + 0.5, y + 0.5
            if not flame(px, py):
                continue
            d = math.hypot(px - core[0], (py - core[1]) * 0.7)
            if d < 1.6:
                col = W
            elif d < 2.8:
                col = L
            elif d < 4.6:
                col = M
            else:
                col = D
            if px > cx + 2.0 and py > cy + 0.6:
                col = E if col == D else D
            g[y][x] = (col, False)
    outline(g, O)
    # yükselen ruh kıvılcımları
    put(g, 1, 1, M, True)
    put(g, 13, 2, L, True)
    return to_img(g)


# ------------------------------------------------------------------ D Ruh Taşı (mor küme)
def icon_d():
    W, L, M, D, E = hx("#f6f1ff"), hx("#e6dcff"), hx("#b49cf0"), hx("#6f52bc"), hx("#45307f")
    O = hx("#1a1030")
    g = grid()

    def crystal(poly, ridge_x, z):
        for y in range(N):
            for x in range(N):
                px, py = x + 0.5, y + 0.5
                if inside(poly, px, py):
                    g[y][x] = ((L if px < ridge_x else D), False, z)

    # yan kristaller (arkada), sonra orta (önde)
    side_l = [(2.2, 5.0), (5.4, 7.4), (6.2, 14.2), (3.0, 14.2), (1.6, 8.6)]
    side_r = [(14.0, 6.6), (14.6, 10.2), (13.2, 14.2), (10.0, 14.2), (10.8, 8.6)]
    mid = [(8.0, 0.6), (10.6, 3.4), (10.6, 13.2), (8.0, 15.0), (5.4, 13.2), (5.4, 3.4)]
    for y in range(N):
        for x in range(N):
            px, py = x + 0.5, y + 0.5
            if inside(mid, px, py):
                col = M
                if px < 6.6:
                    col = L
                elif px > 9.4:
                    col = D
                if py > 12.6:
                    col = D if px < 8.0 else E
                g[y][x] = (col, False)
            elif inside(side_l, px, py):
                col = M if px < 3.6 + (py - 5.0) * 0.15 else D
                if py > 12.4:
                    col = E
                g[y][x] = (col, False)
            elif inside(side_r, px, py):
                col = M if px < 12.4 - (py - 7.0) * 0.12 else E
                if py > 12.4:
                    col = E
                g[y][x] = (col, False)
    # orta kristal ile yanlar arasında koyu ayrım çizgisi (kümede okunurluk)
    for y in range(4, 14):
        for x in (4, 5, 10, 11):
            if g[y][x] is not None and not inside(mid, x + 0.5, y + 0.5):
                nb = x + (1 if x < 8 else -1)
                if g[y][nb] is not None and inside(mid, nb + 0.5, y + 0.5):
                    g[y][x] = (O, False)
    # orta kristal tepesine ışık
    put(g, 7, 2, W)
    put(g, 6, 4, W)
    put(g, 6, 5, W)
    outline(g, O)
    sparkle(g, 13, 2, hx("#ffffff"), hx("#e6dcff"))
    return to_img(g)


# ------------------------------------------------------------------ bugünkü simgeler
def current_vector(s):
    """menu_dark_kit.gd / soul_shop_screen.gd ShardIcon._draw (aynı köşe noktaları)."""
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = s * 0.5
    top, l, r, bot, m = (c, s * 0.04), (s * 0.12, s * 0.38), (s * 0.88, s * 0.38), (c, s * 0.96), (c, s * 0.38)
    d.polygon([top, m, l], fill=hx("#b4f1f5"))
    d.polygon([top, r, m], fill=hx("#73d2dc"))
    d.polygon([l, m, bot], fill=hx("#3f9fb0"))
    d.polygon([m, r, bot], fill=hx("#27707f"))
    d.line([top, r, bot, l, top], fill=hx("#0b1418"), width=int(max(2, round(s / 12.0))), joint="curve")
    return im


SOUL_GO = [  # game_over_board.gd SOUL
    "...O...",
    "..OLO..",
    ".OLLMO.",
    ".OLMMO.",
    "OLLMMDO",
    "OLMMMDO",
    "OLMMDDO",
    ".OMMDO.",
    ".OMDDO.",
    "..ODO..",
    "...O...",
]


def current_gameover():
    pal = {"O": hx("#20150d"), "L": hx("#e6dcff"), "M": hx("#b49cf0"), "D": hx("#6f52bc")}
    im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    ox, oy = (N - 7) // 2, (N - 11) // 2
    for y, row in enumerate(SOUL_GO):
        for x, ch in enumerate(row):
            if ch in pal:
                im.putpixel((ox + x, oy + y), pal[ch])
    return im


def dim(im):
    """ShardIcon dim: rgb x0,5 (kilitli / yetersiz)."""
    px = im.load()
    out = im.copy()
    po = out.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g_, b, a = px[x, y]
            po[x, y] = (r // 2, g_ // 2, b // 2, a)
    return out


def up(im, k):
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


# ------------------------------------------------------------------ karşılaştırma sayfası
BG_NIGHT = hx("#1a1a2c")   # Gece Sıvası paneli (menü)
BG_WOOD = hx("#2b2119")    # Ruh Mağazası koyu ahşap panel
BG_GOLD = hx("#e3b44f")    # AÇ düğmesi
TXT_CREAM = hx("#f3e6c4")
TXT_DARK = hx("#2a1d10")


def font(px):
    return ImageFont.truetype(FONT, px)


def sheet(items):
    rowh = 150
    W = 1500
    im = Image.new("RGBA", (W, 60 + rowh * len(items)), hx("#121219"))
    d = ImageDraw.Draw(im)
    f2, f3 = font(32), font(48)
    heads = ["", "x8 ızgara", "16 / 32 / 48 (menü)", "ahşap panel", "kilitli", "para ailesi", "AÇ düğmesi"]
    xs = [16, 220, 380, 700, 900, 1010, 1290]
    for x, h in zip(xs, heads):
        d.text((x, 14), h, font=f2, fill=hx("#8a8aa0"))
    coin = Image.open(COIN).convert("RGBA")
    wsh = Image.open(WSHARD).convert("RGBA")
    for i, (name, ic) in enumerate(items):
        y0 = 60 + i * rowh
        d.rectangle([0, y0, W, y0 + rowh - 4], fill=hx("#17171f"))
        d.text((16, y0 + 50), name, font=f2, fill=TXT_CREAM)
        im.alpha_composite(up(ic, 8), (220, y0 + 11))
        # gece sıvası
        d.rectangle([380, y0 + 10, 680, y0 + 136], fill=BG_NIGHT)
        im.alpha_composite(ic, (396, y0 + 64))
        im.alpha_composite(up(ic, 2), (430, y0 + 56))
        im.alpha_composite(up(ic, 3), (480, y0 + 48))
        d.text((548, y0 + 44), "340", font=f3, fill=TXT_CREAM)
        # ahşap
        d.rectangle([700, y0 + 10, 880, y0 + 136], fill=BG_WOOD)
        im.alpha_composite(up(ic, 2), (712, y0 + 56))
        im.alpha_composite(up(ic, 3), (760, y0 + 48))
        d.text((820, y0 + 44), "25", font=f3, fill=TXT_CREAM)
        # kilitli
        d.rectangle([900, y0 + 10, 990, y0 + 136], fill=BG_WOOD)
        im.alpha_composite(up(dim(ic), 3), (921, y0 + 48))
        # para ailesi: altın + silah parçacığı + ruh kıymığı (aynı 2x)
        d.rectangle([1010, y0 + 10, 1270, y0 + 136], fill=BG_NIGHT)
        im.alpha_composite(up(coin, 3), (1022, y0 + 48))
        im.alpha_composite(up(wsh, 2), (1090, y0 + 51))
        im.alpha_composite(up(ic, 3), (1160, y0 + 48))
        d.text((1214, y0 + 44), "9", font=f3, fill=TXT_CREAM)
        # AÇ düğmesi
        d.rectangle([1290, y0 + 30, 1488, y0 + 116], fill=BG_GOLD, outline=hx("#7a5a22"), width=4)
        d.text((1306, y0 + 44), "AÇ", font=f3, fill=TXT_DARK)
        im.alpha_composite(up(ic, 2), (1370, y0 + 57))
        d.text((1408, y0 + 44), "250", font=f3, fill=TXT_DARK)
    return im


# ------------------------------------------------------------------ gerçek yakalama bağlamı
def find_old_icons(cap):
    """Eski camgöbeği elmasın (4 yüz rengi) piksel kümeleri -> kutular."""
    cols = [(0xb4, 0xf1, 0xf5), (0x73, 0xd2, 0xdc), (0x3f, 0x9f, 0xb0), (0x27, 0x70, 0x7f)]
    w, h = cap.size
    px = cap.load()
    hit = set()
    for y in range(h):
        for x in range(w):
            r, g_, b = px[x, y][:3]
            for c in cols:
                if abs(r - c[0]) + abs(g_ - c[1]) + abs(b - c[2]) < 14:
                    hit.add((x, y))
                    break
    boxes = []
    while hit:
        st = [hit.pop()]
        xs, ys = [], []
        while st:
            x, y = st.pop()
            xs.append(x)
            ys.append(y)
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    q = (x + dx, y + dy)
                    if q in hit:
                        hit.remove(q)
                        st.append(q)
        if len(xs) > 40:
            boxes.append((min(xs), min(ys), max(xs), max(ys)))
    return boxes


def ring_color(cap, box, pad):
    x0, y0, x1, y1 = box
    px = cap.load()
    vals = []
    for x in range(x0 - pad - 2, x1 + pad + 3):
        vals.append(px[x, y0 - pad - 2])
        vals.append(px[x, y1 + pad + 2])
    for y in range(y0 - pad - 2, y1 + pad + 3):
        vals.append(px[x0 - pad - 2, y])
        vals.append(px[x1 + pad + 2, y])
    vals.sort()
    return vals[len(vals) // 2]


def replaced(cap, boxes, ic):
    out = cap.copy()
    d = ImageDraw.Draw(out)
    for (x0, y0, x1, y1) in boxes:
        s = max(x1 - x0, y1 - y0) + 1
        pad = max(2, round(s / 12.0))
        d.rectangle([x0 - pad, y0 - pad, x1 + pad, y1 + pad], fill=ring_color(cap, (x0, y0, x1, y1), pad))
        if ic is None:
            continue
        k = max(1, round((s + pad) / N))
        cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
        out.alpha_composite(up(ic, k), (cx - N * k // 2, cy - N * k // 2))
    return out


def context(items):
    cap = Image.open(CAPTURE).convert("RGBA")
    boxes = find_old_icons(cap)
    print("eski simge kutuları:", len(boxes), boxes[:12])
    # kırpımlar (2560x1440 yakalamada 1:1): başlık + sağ üst sayaç, AÇ düğmesi + hedef, alt satır
    crops = [(1060, 30, 1500, 120), (2270, 30, 2520, 120), (60, 1070, 760, 1360), (820, 1330, 1300, 1400)]
    cw = sum(c[2] - c[0] for c in crops[:2]) + 20
    rows = []
    for name, ic in items:
        rep = cap if ic == "old" else replaced(cap, boxes, ic)
        a = Image.new("RGBA", (cw, 90), hx("#121219"))
        x = 0
        for c in crops[:2]:
            a.alpha_composite(rep.crop(c), (x, 0))
            x += c[2] - c[0] + 20
        b = rep.crop(crops[2])
        c3 = rep.crop(crops[3])
        rowim = Image.new("RGBA", (180 + cw + 20 + b.width, max(b.height, 90 + 20 + c3.height)), hx("#121219"))
        ImageDraw.Draw(rowim).text((12, 40), name, font=font(32), fill=TXT_CREAM)
        rowim.alpha_composite(a, (180, 0))
        rowim.alpha_composite(c3, (180, 110))
        rowim.alpha_composite(b, (180 + cw + 20, 0))
        rows.append(rowim)
    H = sum(r.height + 12 for r in rows)
    W = max(r.width for r in rows)
    out = Image.new("RGBA", (W, H), hx("#0c0c12"))
    y = 0
    for r in rows:
        out.alpha_composite(r, (0, y))
        y += r.height + 12
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    icons = [("A Ruh Kristali", icon_a()), ("B Kırık Kıymık", icon_b()),
             ("C Ruh Alevi", icon_c()), ("D Ruh Taşı", icon_d())]
    for (name, ic), key in zip(icons, "abcd"):
        ic.save(os.path.join(OUT, "ruh_%s_16.png" % key))
    cur = [("ŞU AN menü", current_vector(16).resize((N, N), Image.NEAREST)),
           ("ŞU AN oyun bitti", current_gameover())]
    sheet(cur + icons).save(os.path.join(OUT, "ruh_simge_karsilastirma.png"))
    context([("ŞU AN", "old")] + icons).save(os.path.join(OUT, "ruh_simge_baglam.png"))
    print("yazıldı:", OUT)


if __name__ == "__main__":
    main()
