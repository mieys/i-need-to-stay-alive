# -*- coding: utf-8 -*-
"""Asa prototipleri (2026-10-16): 4 asa x 3 stil ailesi, eski sanata bakmadan sıfırdan.

Asalar 32x32 tuvalde, sol-alttan sağ-üste 45 derece çizilir (oyundaki sprite_forward_angle_deg ~ -45 ile aynı yön).
Oyunda asa ikonunun uzun kenarı 28 dünya px; 31 px kutu -> 0.903 dünya px / sanat pikseli = büyücü/karakter pikseliyle
aynı yoğunluk (2.2368 x 0.8075 x 0.5). Çizim (a, b) çerçevesinde: a = asa ekseni boyunca (sağ-üste +),
b = eksene dik (b<0 sol-üst = ışıklı taraf). Dış çizgi otomatik (4-komşu, malzemenin koyu tonu).

Çıktılar (bu klasöre): asa_<stil>_<asa>.png (32x32 ham), asa_sayfa.png (x6 karşılaştırma), asa_oyun_olcegi.png.
Çalıştırma: python tools/proto_20261016/asa_proto.py
"""
import math
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.normpath(os.path.join(ROOT, "..", ".."))
N = 32
O = (16.25, 16.25)  # eksen merkezi (x+y = 32.5 -> gövde tam iki köşegen)
R2 = math.sqrt(2.0)


def hx(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


# 0 = dış çizgi, sonra koyudan açığa
P = {k: [hx(c) for c in v] for k, v in {
    "wood": ["#2a170f", "#56301d", "#84502c", "#ad7442", "#d29a62"],
    "ash": ["#24222a", "#4c4850", "#77716e", "#a29b92", "#cdc6b6"],
    "plum": ["#1d1226", "#402746", "#623c5f", "#87597a", "#ad809e"],
    "birch": ["#283040", "#77808e", "#b9c2cc", "#e2e7ec", "#ffffff"],
    "iron": ["#111119", "#262834", "#424556", "#676c82", "#9ba1b8"],
    "steel": ["#181d2a", "#3b4558", "#637089", "#95a2bb", "#d0d9ea"],
    "silver": ["#212a38", "#546478", "#8999ae", "#bdcbdb", "#eff4fa"],
    "gold": ["#311e0b", "#784d16", "#b6822b", "#e4b64a", "#fde488"],
    "copper": ["#33190f", "#6c341f", "#a65833", "#d4824d", "#f4ae7a"],
    "leather": ["#2a140e", "#4e2618", "#713a22", "#94532f", "#b4703f"],
    "fire": ["#4a0f10", "#9c2316", "#d84e1a", "#f28823", "#fcc63e", "#fff2ae"],
    "bolt": ["#3a2a08", "#9e7510", "#dfb628", "#f7e257", "#fff8b4", "#ffffff"],
    "arc": ["#1c0c30", "#3e196c", "#6b33b6", "#9c62e6", "#cfa6ff", "#f4e8ff"],
    "ice": ["#112942", "#22588a", "#3d8dc6", "#76c4ec", "#bce9ff", "#f2fdff"],
    "obsid": ["#09070d", "#18141f", "#2a2433", "#3f374a", "#5a5068"],
    "stone": ["#14121b", "#2b2835", "#44404f", "#615c6e", "#827c90"],
    "glass": ["#141a30", "#26365f", "#3a5690", "#6a8cc4", "#b6cff2", "#ffffff"],
}.items()}


def ab(x, y):
    """Piksel merkezinin (a, b) koordinatı."""
    px, py = x + 0.5 - O[0], y + 0.5 - O[1]
    return (px - py) / R2, (px + py) / R2


def seg_dist(pa, pb, q):
    (ax, ay), (bx, by), (qx, qy) = pa, pb, q
    dx, dy = bx - ax, by - ay
    L = dx * dx + dy * dy
    t = 0.0 if L == 0 else max(0.0, min(1.0, ((qx - ax) * dx + (qy - ay) * dy) / L))
    cx, cy = ax + t * dx, ay + t * dy
    return math.hypot(qx - cx, qy - cy), t


def in_poly(pts, q):
    x, y = q
    inside = False
    j = len(pts) - 1
    for i in range(len(pts)):
        xi, yi = pts[i]
        xj, yj = pts[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            inside = not inside
        j = i
    return inside


class Spr:
    ## Baş büyütme: tasarım koordinatında a > T olan her şey K kat büyür ve TP'den başlar, gövde (a <= T) sıkışır.
    ## Oyun ölçeğinde 1:1 başlar küçük kalıyordu (ilk tur); asa kutusu yine 31 px.
    T, TP, END, BOT = 4.5, 0.0, 20.2, -19.6
    K = (END - TP) / (END - T)
    S = (TP - BOT) / (T - BOT)

    def __init__(self):
        self.body = {}  # (x,y) -> (rgb, outline_rgb or None)
        self.post = {}  # dış çizgiden sonra (parıltı, kıvılcım)

    def to_design(self, a, b):
        if a <= self.TP:
            return self.BOT + (a - self.BOT) / self.S, b
        return self.T + (a - self.TP) / self.K, b / self.K

    def to_pixel(self, a, b):
        if a <= self.T:
            return self.BOT + (a - self.BOT) * self.S, b
        return self.TP + (a - self.T) * self.K, b * self.K

    def put(self, x, y, c, mat=None):
        if 0 <= x < N and 0 <= y < N:
            self.body[(x, y)] = (c, P[mat][0] if mat else None)

    def glow(self, x, y, c):
        if 0 <= x < N and 0 <= y < N:
            self.post[(x, y)] = c

    def glow_ab(self, a, b, c):
        a, b = self.to_pixel(a, b)
        x = O[0] + (a + b) / R2
        y = O[1] + (b - a) / R2
        self.glow(int(math.floor(x)), int(math.floor(y)), c)

    def fill(self, pred, col, mat):
        for y in range(N):
            for x in range(N):
                a, b = self.to_design(*ab(x, y))
                if pred(a, b):
                    c = col(a, b)
                    if c is not None:
                        self.put(x, y, c, mat)

    def erase(self, pred):
        for k in list(self.body):
            if pred(*ab(*k)):
                del self.body[k]

    def poly(self, pts, col, mat):
        self.fill(lambda a, b: in_poly(pts, (a, b)), col, mat)

    def stroke(self, pts, r, col, mat):
        """Kalınlığı r (veya (r0, r1) uçtan uca) olan çoklu çizgi."""
        segs = list(zip(pts[:-1], pts[1:]))
        lens = [math.dist(p, q) for p, q in segs]
        total = sum(lens) or 1.0

        def hit(a, b):
            acc = 0.0
            for (p, q), L in zip(segs, lens):
                d, t = seg_dist(p, q, (a, b))
                s = (acc + t * L) / total
                rr = r if isinstance(r, (int, float)) else r[0] + (r[1] - r[0]) * s
                if d <= rr:
                    return True
                acc += L
            return False

        self.fill(hit, col, mat)

    def render(self):
        img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
        out = {}
        for (x, y), (c, ol) in self.body.items():
            img.putpixel((x, y), c + (255,))
        for (x, y), (c, ol) in self.body.items():
            if ol is None:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                k = (x + dx, y + dy)
                if k in self.body or not (0 <= k[0] < N and 0 <= k[1] < N):
                    continue
                prev = out.get(k)
                if prev is None or sum(ol) < sum(prev):
                    out[k] = ol
        for (x, y), c in out.items():
            img.putpixel((x, y), c + (255,))
        for (x, y), c in self.post.items():
            img.putpixel((x, y), c + (255,))
        return img


# ---------------------------------------------------------------- ortak parçalar
def shade_b(mat, b, lo=2, hi=3):
    """İki köşegenli gövde: ışıklı taraf (b<0) hi, gölge lo."""
    return P[mat][hi] if b < 0 else P[mat][lo]


def shaft(s, a0, a1, mat, knots=(), lo=2, hi=3):
    def col(a, b):
        for k in knots:
            if abs(a - k) < 0.5 and b > 0:
                return P[mat][1]
        return shade_b(mat, b, lo, hi)

    s.fill(lambda a, b: a0 <= a <= a1 and abs(b) < 0.75, col, mat)


def band(s, a0, a1, mat, wide=True):
    w = 1.2 if wide else 0.75

    def col(a, b):
        if b < -0.75:
            return P[mat][4]
        if b < 0:
            return P[mat][3]
        if b < 0.75:
            return P[mat][2]
        return P[mat][1]

    s.fill(lambda a, b: a0 <= a <= a1 and abs(b) < w, col, mat)


def pommel(s, mat, a_end=-19.6, a_top=-17.4):
    band(s, a_end + 0.6, a_top, mat)
    s.fill(lambda a, b: a_end - 0.4 <= a < a_end + 0.6 and abs(b) < 0.75, lambda a, b: shade_b(mat, b, 1, 3), mat)


def orb(s, a0, b0, r, mat, idx=(1, 2, 3, 4, 5), spec=True):
    """Işık sol-üstten (b eksi tarafı)."""
    ha, hb = a0 + r * 0.25, b0 - r * 0.45

    def col(a, b):
        d = math.hypot(a - ha, b - hb) / (r * 1.45)
        k = len(idx) - 1 - min(len(idx) - 1, int(d * len(idx)))
        return P[mat][idx[k]]

    s.fill(lambda a, b: (a - a0) ** 2 + (b - b0) ** 2 <= r * r, col, mat)
    if spec:
        s.glow_ab(ha + 0.3, hb - 0.2, P[mat][-1])


def crystal(s, pts, mat, axis_a=None, ridge=True):
    """Yüzeyli kristal: eksenin ışıklı tarafı açık, diğer tarafı orta; uçta parlak sırt."""
    if axis_a is None:
        axis_a = (pts[0], pts[len(pts) // 2])
    (a1, b1), (a2, b2) = axis_a
    dx, dy = a2 - a1, b2 - b1
    L = math.hypot(dx, dy) or 1.0

    def col(a, b):
        side = ((a - a1) * dy - (b - b1) * dx) / L  # >0: eksenin b- tarafı
        t = ((a - a1) * dx + (b - b1) * dy) / (L * L)
        if ridge and abs(side) < 0.45 and t > 0.25:
            return P[mat][5]
        if side > 0:
            return P[mat][4] if t > 0.15 else P[mat][3]
        return P[mat][3] if t > 0.35 else P[mat][2]

    s.poly(pts, col, mat)


def flame(s, outer, inner, core, mat="fire"):
    s.poly(outer, lambda a, b: P[mat][3], mat)
    s.poly(inner, lambda a, b: P[mat][4], mat)
    if core:
        s.poly(core, lambda a, b: P[mat][5], mat)


def scale_poly(pts, ca, cb, k):
    return [(ca + (a - ca) * k, cb + (b - cb) * k) for a, b in pts]


# ---------------------------------------------------------------- A: AHŞAP (doğal dal + element çekirdeği)
def a_fire(s):
    """Köz Kütüğü: budaklı kütük başı, içine gömülü köz taşı, üstünden yükselen alev."""
    pommel(s, "wood")
    shaft(s, -17.4, 8, "wood", knots=(-11, -1))
    band(s, -6.5, -3.5, "leather")
    s.fill(lambda a, b: -6.0 <= a <= -4.0 and abs(b) < 1.2 and int(a * 2) % 2 == 0, lambda a, b: P["leather"][1], "leather")
    fo = [(13.0, -2.6), (15.5, -3.2), (16.6, -1.9), (17.6, -2.4), (18.2, -0.9), (20.2, 0.0),
          (18.4, 1.0), (17.8, 2.4), (16.6, 1.7), (15.4, 2.8), (13.0, 2.4)]
    flame(s, fo, scale_poly(fo, 14.0, 0.0, 0.62), scale_poly(fo, 13.6, 0.0, 0.3))
    burl = [(7.0, -0.9), (8.6, -2.6), (10.6, -3.4), (12.4, -3.2), (14.0, -2.2), (14.6, -0.4),
            (14.2, 1.6), (12.8, 3.2), (10.6, 3.4), (8.8, 2.6), (7.0, 0.9)]
    s.poly(burl, lambda a, b: P["wood"][4] if b < -2.0 else (P["wood"][3] if b < 0.2 else (P["wood"][2] if b < 2.2 else P["wood"][1])), "wood")
    orb(s, 11.6, -0.2, 1.9, "fire", idx=(2, 3, 4, 5))
    s.glow_ab(18.8, -3.4, P["fire"][4])
    s.glow_ab(16.4, 3.9, P["fire"][3])
    s.glow_ab(20.6, 1.9, P["fire"][4])


def a_lightning(s):
    """Fırtına Çatalı: yıldırım çarpmış soluk dal, çatallı uç, arada süzülen sarı kristal, bakır tel sargı."""
    pommel(s, "copper")
    shaft(s, -17.4, 5.2, "ash", knots=(-9, -2))
    for k in (0.4, 2.0, 3.6):
        band(s, k, k + 0.9, "copper")
    band(s, -13.0, -10.4, "copper", wide=False)
    s.stroke([(5.0, -0.2), (8.6, -1.9), (12.4, -3.3), (16.4, -3.5), (17.6, -2.6)], 0.72,
             lambda a, b: P["ash"][3] if b < -2.6 or a < 9 else P["ash"][2], "ash")
    s.stroke([(5.0, 0.2), (8.6, 1.9), (12.2, 3.1), (15.0, 3.1), (15.9, 2.2)], 0.72,
             lambda a, b: P["ash"][3] if a < 8.6 else P["ash"][2], "ash")
    crystal(s, [(10.6, 0.0), (13.4, -1.5), (17.4, 0.0), (13.4, 1.5)], "bolt")
    s.glow_ab(16.6, -2.0, P["bolt"][5])
    s.glow_ab(15.2, 2.0, P["bolt"][4])
    s.glow_ab(19.2, -0.4, P["bolt"][4])
    s.glow_ab(9.0, 0.0, P["bolt"][3])


def a_arcane(s):
    """Sarmal Kök: iki ince kök yukarıda kıvrılıp mor bir küreyi kafes gibi sarar."""
    pommel(s, "plum")
    shaft(s, -17.4, 6.2, "plum", knots=(-12, -4), lo=2, hi=3)
    band(s, -7.0, -5.0, "gold", wide=False)
    orb(s, 12.8, 0.0, 2.8, "arc", idx=(2, 3, 4, 5))
    s.stroke([(6.0, -0.4), (8.6, -2.6), (11.2, -3.9), (14.0, -3.7), (16.4, -2.0), (17.4, 0.4)], 0.62,
             lambda a, b: P["plum"][4] if b < -2.4 else P["plum"][3], "plum")
    s.stroke([(6.0, 0.4), (8.6, 2.6), (11.4, 3.7), (14.0, 3.2), (15.6, 1.6), (16.8, -0.6)], 0.62,
             lambda a, b: P["plum"][2], "plum")
    s.glow_ab(19.4, -2.2, P["arc"][4])
    s.glow_ab(9.6, -5.2, P["arc"][3])
    s.glow_ab(17.0, 3.4, P["arc"][4])


def a_ice(s):
    """Kayın Buzu: beyaz kayın gövde (kara benekler), uçta yelpaze açan üç buz kristali."""
    pommel(s, "silver")
    def birch(a, b):
        for k in (-14.2, -8.6, -3.2, 2.4):
            if k <= a <= k + 0.9:
                return P["birch"][0] if b > 0 else P["birch"][1]
        return shade_b("birch", b, 2, 3)
    s.fill(lambda a, b: -17.4 <= a <= 7.6 and abs(b) < 0.75, birch, "birch")
    crystal(s, [(7.6, -0.9), (10.0, -2.5), (15.2, -6.0), (11.4, -1.4)], "ice", axis_a=((8.0, -1.0), (15.2, -6.0)))
    crystal(s, [(7.6, 0.9), (10.4, 2.2), (14.6, 4.6), (11.6, 1.2)], "ice", axis_a=((8.0, 1.0), (14.6, 4.6)))
    crystal(s, [(7.4, -1.1), (11.0, -2.0), (19.8, 0.0), (11.0, 2.0), (7.4, 1.1)], "ice", axis_a=((7.4, 0.0), (19.8, 0.0)))
    band(s, 6.0, 7.6, "silver")
    s.glow_ab(17.2, -3.4, P["ice"][5])
    s.glow_ab(16.6, 4.0, P["ice"][4])


# ---------------------------------------------------------------- B: DÖVME METAL (asa = asa-sopa, işlenmiş baş)
def b_fire(s):
    """Mangal: demir gövde, altın bilezikler, ucunda içinden alev taşan küçük mangal kâse."""
    pommel(s, "gold")
    shaft(s, -17.4, 8.4, "iron", lo=2, hi=3)
    band(s, -12.0, -10.6, "gold")
    band(s, -1.0, 0.6, "gold")
    band(s, 5.4, 7.0, "gold")
    fo = [(11.0, -3.4), (14.2, -3.6), (15.4, -2.4), (16.4, -3.0), (17.4, -1.2), (20.2, 0.0),
          (18.0, 1.2), (17.2, 2.6), (15.8, 1.8), (14.6, 3.2), (11.0, 3.2)]
    flame(s, fo, scale_poly(fo, 13.6, 0.0, 0.6), scale_poly(fo, 13.0, 0.0, 0.28))
    cup = [(8.0, -1.0), (10.0, -2.8), (12.2, -3.9), (13.2, -3.9), (13.2, -3.0), (12.2, -2.4), (12.2, 2.4),
           (13.2, 3.0), (13.2, 3.9), (12.2, 3.9), (10.0, 2.8), (8.0, 1.0)]
    s.poly(cup, lambda a, b: P["iron"][4] if b < -2.2 else (P["iron"][3] if b < 0 else (P["iron"][2] if b < 2.2 else P["iron"][1])), "iron")
    s.fill(lambda a, b: 11.6 <= a <= 13.4 and abs(b) <= 4.1 and (abs(b) >= 2.6 or a <= 12.4) and in_poly(cup, (a, b)),
           lambda a, b: P["gold"][4] if b < 0 else P["gold"][3], "gold")
    s.glow_ab(18.0, -3.6, P["fire"][4])
    s.glow_ab(20.0, 2.0, P["fire"][3])


def b_lightning(s):
    """Plazma Küresi: çelik gövde, bakır bobinler, cam küre içinde sarı şimşek dalları, tepede paratoner iğnesi."""
    pommel(s, "copper")
    shaft(s, -17.4, 7.6, "steel", lo=2, hi=3)
    for k in (-1.6, 0.2, 2.0):
        band(s, k, k + 1.0, "copper")
    band(s, -10.0, -8.0, "copper", wide=False)
    s.stroke([(15.4, 0.0), (19.8, 0.0)], (0.75, 0.35), lambda a, b: shade_b("steel", b, 3, 4), "steel")
    orb(s, 11.8, 0.0, 3.5, "glass", idx=(1, 2, 2, 3), spec=False)
    band(s, 6.6, 8.2, "copper")
    for pts in ([(11.8, 0.0), (13.0, -1.2), (12.6, -2.2), (13.6, -2.8)],
                [(11.8, 0.0), (13.4, 0.6), (14.6, 0.2)],
                [(11.8, 0.0), (11.0, 1.4), (11.8, 2.6)],
                [(11.8, 0.0), (10.2, -0.8), (9.6, -2.0)]):
        s.stroke(pts, 0.42, lambda a, b: P["bolt"][4], None)
    s.glow_ab(11.8, 0.0, P["bolt"][5])
    s.glow_ab(10.6, -2.6, P["glass"][5])
    s.glow_ab(18.4, -2.2, P["bolt"][4])
    s.glow_ab(20.6, 1.4, P["bolt"][5])


def b_arcane(s):
    """Hale: koyu çelik gövde, altın halka (hale) ve ortasında süzülen mor elmas."""
    pommel(s, "gold")
    shaft(s, -17.4, 9.4, "iron", lo=2, hi=3)
    band(s, -9.0, -7.4, "gold")
    band(s, 7.4, 9.4, "gold")
    c_a, r_in, r_out = 14.0, 3.6, 4.9

    def ring(a, b):
        d = math.hypot(a - c_a, b)
        if not (r_in <= d <= r_out):
            return None
        lit = -b / d  # sol-üst tarafı parlak
        return P["gold"][4] if lit > 0.45 else (P["gold"][3] if lit > -0.25 else P["gold"][2])

    s.fill(lambda a, b: r_in <= math.hypot(a - c_a, b) <= r_out, ring, "gold")
    s.fill(lambda a, b: 18.6 <= a <= 19.8 and abs(b) < 0.75, lambda a, b: shade_b("gold", b, 3, 4), "gold")
    crystal(s, [(11.6, 0.0), (14.0, -1.6), (16.4, 0.0), (14.0, 1.6)], "arc")
    s.glow_ab(14.0, -6.4, P["arc"][4])
    s.glow_ab(20.4, 2.4, P["arc"][3])


def b_ice(s):
    """Pençe Yuvası: gümüş gövde, buz-mavi taşlı bilezik; iki altın pençenin kavradığı iri, köşeli buz taşı."""
    pommel(s, "silver")
    shaft(s, -17.4, 8.6, "silver", lo=2, hi=3)
    band(s, -6.4, -4.6, "ice")
    gem = [(8.6, -1.2), (10.6, -2.9), (15.4, -2.9), (19.6, 0.0), (15.4, 2.9), (10.6, 2.9), (8.6, 1.2)]
    crystal(s, gem, "ice", axis_a=((8.6, 0.0), (19.6, 0.0)))
    s.fill(lambda a, b: in_poly(gem, (a, b)) and abs(a - 15.4) < 0.45 and b < 0, lambda a, b: P["ice"][5], "ice")
    s.fill(lambda a, b: in_poly(gem, (a, b)) and abs(a - 10.6) < 0.45 and b > 0, lambda a, b: P["ice"][2], "ice")
    for sg in (-1, 1):
        s.stroke([(7.4, 0.5 * sg), (9.0, 2.6 * sg), (11.6, 3.5 * sg), (13.4, 3.2 * sg), (13.9, 2.3 * sg)], 0.62,
                 (lambda a, b: P["gold"][4]) if sg < 0 else (lambda a, b: P["gold"][3]), "gold")
    band(s, 6.6, 8.2, "gold")
    s.glow_ab(17.4, -3.6, P["ice"][5])
    s.glow_ab(20.4, 2.0, P["ice"][4])


# ---------------------------------------------------------------- C: SAF ELEMENT (malzemenin kendisi, sade)
def c_fire(s):
    """Obsidyen Alev: lav damarlı obsidyen gövde, içi erimiş, pürüzlü obsidyen uç; kor kıvılcımları."""
    pommel(s, "obsid")

    def obs(a, b):
        v = int(math.floor(a * 0.9))
        if a < 7 and v % 5 == 0 and b < 0:
            return P["fire"][3]
        if a < 7 and v % 5 == 1 and b > 0:
            return P["fire"][2]
        return shade_b("obsid", b, 2, 4)

    s.fill(lambda a, b: -17.4 <= a <= 7.6 and abs(b) < 0.75, obs, "obsid")
    shard = [(6.6, -1.2), (9.6, -2.6), (12.4, -2.0), (15.0, -3.8), (15.8, -1.4), (19.8, 0.0),
             (16.2, 1.4), (14.4, 3.2), (12.4, 1.8), (9.6, 2.6), (6.6, 1.2)]
    s.poly(shard, lambda a, b: P["obsid"][4] if b < -1.0 else (P["obsid"][3] if b < 0.6 else P["obsid"][2]), "obsid")
    s.stroke([(8.0, 0.0), (10.6, -0.7), (12.6, 0.5), (15.4, -0.4), (18.4, 0.0)], 0.5,
             lambda a, b: P["fire"][4], None)
    s.stroke([(10.6, -0.7), (11.4, -1.8)], 0.4, lambda a, b: P["fire"][3], None)
    s.stroke([(15.4, -0.4), (16.0, 1.0)], 0.4, lambda a, b: P["fire"][3], None)
    s.glow_ab(13.0, 0.0, P["fire"][5])
    s.glow_ab(18.6, -2.8, P["fire"][4])
    s.glow_ab(17.6, 3.2, P["fire"][3])
    s.glow_ab(20.8, 1.4, P["fire"][4])


def c_lightning(s):
    """Şimşek: koyu çelik gövde, pirinç bilezik; baş kısmı kalın bir şimşek zikzağı."""
    pommel(s, "gold")
    shaft(s, -17.4, 6.4, "iron", lo=2, hi=3)
    band(s, 4.6, 6.4, "gold")
    band(s, -8.0, -6.6, "gold", wide=False)
    zz = [(6.4, 0.0), (10.2, -2.6), (11.6, 1.4), (15.6, -1.6), (16.8, 1.4), (20.0, -0.2)]
    s.stroke(zz, (1.25, 0.55), lambda a, b: P["bolt"][3], "bolt")
    s.stroke(zz, (0.55, 0.25), lambda a, b: P["bolt"][5], "bolt")
    s.glow_ab(8.8, -4.0, P["bolt"][4])
    s.glow_ab(14.0, 3.6, P["bolt"][4])
    s.glow_ab(18.6, -3.2, P["bolt"][5])


def c_arcane(s):
    """Rün Taşı: rün oyuklu taş gövde, uçta süzülen çekirdek ve çevresinde üç ayrık mor kıymık."""
    pommel(s, "stone")

    def rune(a, b):
        for k in (-13.0, -7.0, -1.0):
            if k <= a <= k + 1.0:
                return P["arc"][4] if b < 0 else P["arc"][3]
        return shade_b("stone", b, 2, 3)

    s.fill(lambda a, b: -17.4 <= a <= 8.0 and abs(b) < 0.75, rune, "stone")
    s.poly([(7.0, -1.3), (9.0, -1.3), (10.4, 0.0), (9.0, 1.3), (7.0, 1.3)],
           lambda a, b: P["stone"][4] if b < 0 else P["stone"][3], "stone")
    orb(s, 13.2, 0.0, 1.3, "arc", idx=(3, 4, 5), spec=False)
    crystal(s, [(15.6, -0.9), (17.2, -1.0), (20.0, 0.0), (17.2, 1.0), (15.6, 0.9)], "arc", axis_a=((15.6, 0.0), (20.0, 0.0)))
    crystal(s, [(10.8, -2.2), (12.4, -2.8), (15.0, -5.0), (12.2, -4.0)], "arc", axis_a=((11.0, -2.4), (15.0, -5.0)))
    crystal(s, [(10.8, 2.2), (12.4, 2.8), (14.4, 4.4), (12.0, 3.8)], "arc", axis_a=((11.0, 2.4), (14.4, 4.4)))
    s.glow_ab(13.2, 0.0, P["arc"][5])
    s.glow_ab(17.8, -3.4, P["arc"][4])
    s.glow_ab(9.0, 3.8, P["arc"][3])


def c_ice(s):
    """Buz Sarkıtı: gövde dahil tamamen buz; köşeli büyük kristal uç, dibinde iki küçük kristal."""
    s.fill(lambda a, b: -19.6 <= a <= -17.6 and abs(b) < 1.2, lambda a, b: P["ice"][2] if b > 0 else P["ice"][3], "ice")
    s.fill(lambda a, b: -17.6 <= a <= 6.0 and abs(b) < 0.75,
           lambda a, b: P["ice"][3] if b < 0 else (P["ice"][2] if int(a) % 6 else P["ice"][1]), "ice")
    s.fill(lambda a, b: -15.0 <= a <= -14.0 and -0.75 < b < 0, lambda a, b: P["ice"][5], "ice")
    s.fill(lambda a, b: -6.0 <= a <= -5.0 and -0.75 < b < 0, lambda a, b: P["ice"][5], "ice")
    crystal(s, [(5.0, -1.0), (8.2, -2.8), (17.6, -1.4), (20.2, 0.0), (17.6, 1.4), (8.2, 2.8), (5.0, 1.0)], "ice",
            axis_a=((5.0, 0.0), (20.2, 0.0)))
    crystal(s, [(5.6, -1.6), (8.0, -2.6), (10.6, -5.0), (7.0, -2.6)], "ice", axis_a=((5.8, -1.8), (10.6, -5.0)))
    crystal(s, [(5.6, 1.6), (8.0, 2.6), (10.2, 4.6), (7.0, 2.6)], "ice", axis_a=((5.8, 1.8), (10.2, 4.6)))
    s.glow_ab(17.6, -3.4, P["ice"][5])
    s.glow_ab(13.0, 4.4, P["ice"][4])


STAFFS = [("ates", "Ateş Asası"), ("yildirim", "Yıldırım Asası"), ("arcane", "Arcane Asası"), ("buz", "Buz Asası")]
STYLES = [
    ("A", "Ahşap + çekirdek", [a_fire, a_lightning, a_arcane, a_ice],
     ["Köz Kütüğü", "Fırtına Çatalı", "Sarmal Kök", "Kayın Buzu"]),
    ("B", "Dövme metal", [b_fire, b_lightning, b_arcane, b_ice],
     ["Mangal", "Plazma Küresi", "Hale", "Pençe Yuvası"]),
    ("C", "Saf element", [c_fire, c_lightning, c_arcane, c_ice],
     ["Obsidyen Alev", "Şimşek", "Rün Taşı", "Buz Sarkıtı"]),
]


def font(sz, bold=False):
    for f in (("C:/Windows/Fonts/segoeuib.ttf" if bold else "C:/Windows/Fonts/segoeui.ttf"), "C:/Windows/Fonts/arial.ttf"):
        if os.path.exists(f):
            return ImageFont.truetype(f, sz)
    return ImageFont.load_default()


def build_all():
    out = {}
    for sid, _, fns, _ in STYLES:
        for (key, _), fn in zip(STAFFS, fns):
            s = Spr()
            fn(s)
            img = s.render()
            img.save(os.path.join(ROOT, "asa_%s_%s.png" % (sid, key)))
            out[(sid, key)] = img
    return out


def sheet(imgs, z=6):
    cell = N * z
    lw, gap, top = 150, 18, 46
    W = lw + len(STYLES) * (cell + gap) + gap
    H = top + len(STAFFS) * (cell + 30 + gap)
    im = Image.new("RGB", (W, H), (34, 38, 40))
    d = ImageDraw.Draw(im)
    for si, (sid, sname, _, names) in enumerate(STYLES):
        x0 = lw + gap + si * (cell + gap)
        d.text((x0, 12), "%s - %s" % (sid, sname), fill=(235, 230, 215), font=font(20, True))
        for ri, (key, label) in enumerate(STAFFS):
            y0 = top + ri * (cell + 30 + gap)
            d.rectangle([x0, y0, x0 + cell - 1, y0 + cell - 1], fill=(70, 92, 62))
            big = imgs[(sid, key)].resize((cell, cell), Image.NEAREST)
            im.paste(big, (x0, y0), big)
            d.text((x0 + 4, y0 + cell + 4), names[ri], fill=(200, 196, 182), font=font(16))
            if si == 0:
                d.text((12, y0 + cell // 2 - 10), label, fill=(235, 230, 215), font=font(18, True))
    im.save(os.path.join(ROOT, "asa_sayfa.png"))


def blit_world(dst, src, cx, cy, world_per_px, zoom, rot=0.0):
    """Godot NEAREST örneklemesi taklidi: sprite merkezi (cx, cy) ekran px; dönüş rot (radyan)."""
    sw, sh = src.size
    k = world_per_px * zoom  # ekran px / sanat pikseli
    c, s_ = math.cos(rot), math.sin(rot)
    rad = int(math.hypot(sw, sh) * k / 2) + 2
    sp = src.load()
    dp = dst.load()
    for y in range(int(cy) - rad, int(cy) + rad):
        for x in range(int(cx) - rad, int(cx) + rad):
            if not (0 <= x < dst.size[0] and 0 <= y < dst.size[1]):
                continue
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            u = (c * dx + s_ * dy) / k + sw / 2
            v = (-s_ * dx + c * dy) / k + sh / 2
            iu, iv = int(math.floor(u)), int(math.floor(v))
            if 0 <= iu < sw and 0 <= iv < sh:
                p = sp[iu, iv]
                if p[3] > 0:
                    dp[x, y] = p[:3]


def context(imgs):
    """Oyun ölçeği: kamera zoom 2 (1 dünya px = 2 ekran px), büyücü idle + 4 asa; üst satır doğal açı, alt satır sağa nişan."""
    zoom = 2.0
    char_world_px = 2.2368375 * 0.8075 * 0.5
    staff_world_px = 28.0 / 31.0
    wiz = Image.open(os.path.join(GAME, "assets/characters/buyucu/sheets/idle.png")).convert("RGBA").crop((0, 0, 48, 48))
    panel_w, panel_h = 300, 150
    W = 20 + len(STYLES) * (panel_w + 20)
    H = 40 + 2 * (panel_h + 20)
    im = Image.new("RGB", (W, H), (34, 38, 40))
    d = ImageDraw.Draw(im)
    slots = [(-34, -18), (34, -18), (-34, 20), (34, 20)]  # dünya px, yaklaşık
    for si, (sid, sname, _, _) in enumerate(STYLES):
        x0 = 20 + si * (panel_w + 20)
        d.text((x0, 10), "%s - %s (oyun ölçeği, zoom 2)" % (sid, sname), fill=(235, 230, 215), font=font(15, True))
        for row, aim in enumerate((None, -0.35)):
            y0 = 40 + row * (panel_h + 20)
            d.rectangle([x0, y0, x0 + panel_w - 1, y0 + panel_h - 1], fill=(74, 98, 64))
            pc = Image.new("RGB", (panel_w, panel_h), (74, 98, 64))
            cx, cy = panel_w / 2, panel_h / 2
            blit_world(pc, wiz, cx, cy, char_world_px, zoom)
            for (key, _), (sx, sy) in zip(STAFFS, slots):
                rot = 0.0 if aim is None else aim + math.radians(45.0)
                blit_world(pc, imgs[(sid, key)], cx + sx * zoom, cy + sy * zoom, staff_world_px, zoom, rot)
            im.paste(pc, (x0, y0))
            d.text((x0 + 6, y0 + panel_h - 20), "doğal açı" if aim is None else "sağa nişan", fill=(225, 230, 210), font=font(13))
    im.save(os.path.join(ROOT, "asa_oyun_olcegi.png"))


if __name__ == "__main__":
    imgs = build_all()
    sheet(imgs)
    context(imgs)
    print("ok", len(imgs))
