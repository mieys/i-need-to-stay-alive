"""Mini stat paneli için LoL TARZI ama kopyası olmayan 32x32 piksel simgeler (PROTOTİP 3, 2026-10-14).

Kullanıcı: "fikrimi değiştirdim, LoL'dekilere benzesin ama kopyası gibi de olmasın, kendi yorumunu katabilirsin".
Dil (LoL stat simgelerinden alınan ilke, şekiller bize ait): her stat TEK kalın siluet, kategori rengi (fiziksel turuncu,
saldırı hızı sarı, kritik/can çalma kırmızı, bekleme/sıvışma camgöbeği, hareket/menzil krem, mana kalkanları mavi,
şifa yeşil, şans altın), sol üstten sağ alta bantlı geçiş, üst kenarda 1 px parlama, alt kenarda koyulaşma, kategoriye
boyanmış koyu kontur; iç ayrıntı = koyu OYMA ya da açık KAKMA. Sahne/ışıltı/ek nesne yok.

Çıktı: assets/ui/stat_mini/<id>.png (24 px, OYUNDA) + out/stat_ikon_lol{,_24,_20}/<id>.png + out/stat_ikon_lol_onizleme.png (x5) + out/stat_ikon_lol_1x.png
Kullanım: python tools/proto_20261014/gen_stat_icons_lol.py
"""
import math
import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(HERE, "out", "stat_ikon_lol")
N = 32
K = 1.0  ## çizim ölçeği: şekiller 32 birimlik uzayda tanımlı, N = 32 x K piksele yeniden ÇİZİLİR (küçültme değil)


def hx(c):
    c = c.lstrip("#")
    return (int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16), 255)


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3)) + (255,)


def ramp(*cs):
    return [hx(c) for c in cs]


INK = hx("#0d0710")
ORANGE = ramp("#5a2408", "#a8460f", "#e57a1f", "#ffae45", "#ffe2a6")
AMBER = ramp("#4f2a06", "#93520c", "#d0861a", "#f5b648", "#ffe7b0")
YELLOW = ramp("#5e4206", "#b08408", "#eec11e", "#ffe164", "#fff8cc")
RED = ramp("#4a0a12", "#8e1622", "#d43a32", "#ff7a5a", "#ffcdb6")
CRIMSON = ramp("#3e0614", "#7a0f26", "#b81e36", "#e8485a", "#ffb0b8")
CYAN = ramp("#0e3f4f", "#1c7c92", "#3cc0d6", "#8eeaf4", "#e8feff")
CREAM = ramp("#4e4030", "#8c7a5c", "#cdb88c", "#efe0b8", "#fffaf0")
BLUE = ramp("#0f2450", "#1e4ea0", "#3a7fe0", "#7ab8ff", "#dcefff")
GREEN = ramp("#10401c", "#1f7a30", "#3cbf4a", "#8be86a", "#e2ffcc")
GOLD = ramp("#5e3a08", "#a8680e", "#e6a524", "#ffd75a", "#fff6c8")
WHITE = ramp("#5b6378", "#a3acc0", "#dde3ee", "#f4f7fb", "#ffffff")


# ------------------------------------------------------------------------------------------- maskeler

def m_poly(pts):
    im = Image.new("1", (N, N), 0)
    ImageDraw.Draw(im).polygon([(float(x) * K, float(y) * K) for x, y in pts], fill=1)
    return {(x, y) for y in range(N) for x in range(N) if im.getpixel((x, y))}


def m_line(pts, w):
    im = Image.new("1", (N, N), 0)
    ImageDraw.Draw(im).line([(float(x) * K, float(y) * K) for x, y in pts], fill=1, width=max(1, int(round(w * K))), joint="curve")
    return {(x, y) for y in range(N) for x in range(N) if im.getpixel((x, y))}


def m_fn(f):
    return {(x, y) for y in range(N) for x in range(N) if f((x + 0.5) / K, (y + 0.5) / K)}


def m_circle(cx, cy, r):
    return m_fn(lambda x, y: (x - cx) ** 2 + (y - cy) ** 2 <= r * r)


def m_ring(cx, cy, r0, r1, a0=None, a1=None):
    def f(x, y):
        d = math.hypot(x - cx, y - cy)
        if not (r0 <= d <= r1):
            return False
        if a0 is None:
            return True
        a = math.degrees(math.atan2(y - cy, x - cx)) % 360
        return (a0 <= a <= a1) if a0 <= a1 else (a >= a0 or a <= a1)
    return m_fn(f)


def m_star(cx, cy, n, r_out, r_in, rot=0.0, radii=None):
    pts = []
    for k in range(2 * n):
        a = rot + math.pi * k / n - math.pi / 2
        r = (radii[k // 2] if radii else r_out) if k % 2 == 0 else r_in
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return m_poly(pts)


def along(a, b, profile):
    """a->b ekseni boyunca (s 0..1, yarı genişlik) profiline göre simetrik çokgen."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    L = math.hypot(dx, dy)
    ux, uy = dx / L, dy / L
    vx, vy = -uy, ux
    left, right = [], []
    for s, hw in profile:
        px, py = a[0] + ux * L * s, a[1] + uy * L * s
        left.append((px + vx * hw, py + vy * hw))
        right.append((px - vx * hw, py - vy * hw))
    return m_poly(left + list(reversed(right)))


def heater(cx, top, w, h, straight=0.42):
    def f(x, y):
        t = (y - top) / h
        if t < 0 or t > 1:
            return False
        if t <= straight:
            half = w / 2
        else:
            u = (t - straight) / (1 - straight)
            half = w / 2 * math.sqrt(max(0.0, 1 - u ** 1.7))
        return abs(x - cx) <= half
    return m_fn(f)


def heart(cx, cy, s):
    def f(x, y):
        px = (x - cx) / s
        py = -(y - cy) / s
        return (px * px + py * py - 1) ** 3 - px * px * py ** 3 <= 0
    return m_fn(f)


def drop(cx, cy, r, top):
    return m_fn(lambda x, y: ((x - cx) ** 2 + (y - cy) ** 2 <= r * r) or
                (top < y < cy and abs(x - cx) <= (y - top) / (cy - top) * r * 0.98))


# ------------------------------------------------------------------------------------------- çizici

class Glyph:
    def __init__(self):
        self.px = {}

    def _ring(self, mask, col):
        for (x, y) in mask:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                q = (x + dx, y + dy)
                if q not in mask and 0 <= q[0] < N and 0 <= q[1] < N:
                    self.px[q] = col

    def solid(self, mask, rmp, outline=True):
        """Bantlı geçişli dolu siluet (sol üst açık), üst kenar parlak, alt kenar koyu."""
        if not mask:
            return self
        if outline:
            self._ring(mask, mix(rmp[0], INK, 0.55))
        xs = [p[0] for p in mask]
        ys = [p[1] for p in mask]
        x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
        for (x, y) in mask:
            t = 0.72 * (y - y0) / max(1, y1 - y0) + 0.28 * (x - x0) / max(1, x1 - x0)
            tone = 3 if t < 0.3 else (2 if t < 0.64 else 1)
            if (x, y - 1) not in mask:
                tone = 4 if t < 0.5 else 3
            elif (x, y + 1) not in mask or (x + 1, y) not in mask and t > 0.5:
                tone = max(0, tone - 1)
            self.px[(x, y)] = rmp[tone]
        return self

    def cut(self, mask, rmp):
        """Koyu oyma (siluetin içinden)."""
        col = mix(rmp[0], INK, 0.55)
        for p in mask:
            if p in self.px:
                self.px[p] = col
        return self

    def inlay(self, mask, rmp, light=4, mid=3):
        """Açık kakma: koyu çerçeveli, üst yarı en açık ton."""
        self._ring(mask, mix(rmp[0], INK, 0.55))
        ys = [p[1] for p in mask]
        y0, y1 = min(ys), max(ys)
        for (x, y) in mask:
            self.px[(x, y)] = rmp[light] if (y - y0) <= (y1 - y0) * 0.45 else rmp[mid]
        return self

    def image(self):
        im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
        for p, c in self.px.items():
            if 0 <= p[0] < N and 0 <= p[1] < N:
                im.putpixel(p, c)
        return im


# ------------------------------------------------------------------------------------------- simgeler
A, B = (3.5, 28.5), (29.0, 3.0)  # sol alt -> sağ üst çapraz eksen


def g_damage():
    """Geniş ağızlı kılıç (turuncu), ortada oluk."""
    g = Glyph()
    blade = along(A, B, [(0.30, 3.2), (0.86, 3.2), (1.0, 0.0)])
    guard = along(lerp(A, B, 0.24), lerp(A, B, 0.31), [(0, 6.5), (1, 6.5)])
    grip = along(A, B, [(0.06, 1.5), (0.25, 1.5)])
    pom = m_circle(A[0] + 1.6, A[1] - 1.6, 2.6)
    g.solid(grip | pom, ORANGE).solid(guard, ORANGE).solid(blade, ORANGE)
    g.cut(along(A, B, [(0.36, 0.6), (0.8, 0.6)]), ORANGE)
    return g


def g_fire_rate():
    """Hançer + arkasında üç hız çubuğu (sarı)."""
    g = Glyph()
    for off, s0, s1 in ((-5.0, 0.04, 0.3), (0.0, 0.0, 0.2), (5.0, 0.04, 0.3)):
        a2 = shift(A, off)
        b2 = shift(B, off)
        g.solid(along(a2, b2, [(s0, 1.4), (s1, 1.4)]), YELLOW)
    blade = along(A, B, [(0.5, 2.6), (0.86, 2.4), (1.0, 0.0)])
    guard = along(lerp(A, B, 0.44), lerp(A, B, 0.5), [(0, 5.2), (1, 5.2)])
    grip = along(A, B, [(0.3, 1.5), (0.45, 1.5)])
    g.solid(grip, YELLOW).solid(guard, YELLOW).solid(blade, YELLOW)
    return g


def g_crit_chance():
    """Büyük dört köşeli kritik kıvılcımı + küçük eşi (kırmızı-turuncu)."""
    g = Glyph()
    g.solid(m_star(13.5, 18.0, 4, 13.5, 3.6), RED)
    g.solid(m_star(26.0, 6.0, 4, 5.5, 1.7), RED)
    g.inlay(m_star(13.5, 18.0, 4, 4.2, 1.4), RED, 4, 4)
    return g


def g_crit_damage():
    """Düzensiz patlama + oyma ünlem (koyu kırmızı)."""
    g = Glyph()
    g.solid(m_star(16, 16.5, 9, 0, 9.0, rot=0.35, radii=[15, 12, 14.5, 11.5, 15.5, 12, 14, 12.5, 13.5]), CRIMSON)
    g.cut(m_poly([(13.6, 7.5), (18.4, 7.5), (17.4, 17.5), (14.6, 17.5)]) | m_circle(16, 22.6, 2.2), CRIMSON)
    return g


def g_cooldown():
    """Kum saati: üst hazne boş (oyma), alt hazne kumla dolu (camgöbeği)."""
    g = Glyph()
    frame = m_poly([(5, 2), (27, 2), (27, 6), (5, 6)]) | m_poly([(5, 26), (27, 26), (27, 30), (5, 30)])
    glass = m_poly([(8, 6), (24, 6), (17.6, 15), (17.6, 17), (24, 26), (8, 26), (14.4, 17), (14.4, 15)])
    g.solid(glass, CYAN).solid(frame, CYAN)
    g.cut(m_poly([(11, 8.5), (21, 8.5), (16.8, 13.8), (15.2, 13.8)]), CYAN)
    g.cut(m_poly([(15.2, 18.5), (16.8, 18.5), (21, 23.5), (11, 23.5)]) - m_poly([(9, 21), (23, 21), (23, 26), (9, 26)]), CYAN)
    return g


def g_lifesteal():
    """Kan damlası + içinde iki açık diş kakması (kızıl)."""
    g = Glyph()
    g.solid(drop(16, 20, 9.6, 1.5), RED)
    for (x0, x1, tip) in ((9.5, 14.5, (12.0, 23.5)), (17.5, 22.5, (20.0, 23.5))):
        g.inlay(m_poly([(x0, 14), (x1, 14), tip]), WHITE, 4, 2)
    g.cut(m_line([(9, 14), (23, 14)], 1) - m_poly([(9.5, 13), (22.5, 13), (22.5, 15), (9.5, 15)]), RED)
    return g


def g_dodge():
    """Kıvrılan üç rüzgâr çizgisi (camgöbeği)."""
    g = Glyph()
    w1 = [(2, 10), (16, 10), (21, 9), (23, 6), (21, 3.5), (18, 4.5), (17.5, 7)]
    w2 = [(5, 17), (26, 17), (29.5, 15), (29.5, 12.5), (27, 11.5)]
    w3 = [(2, 24), (14, 24), (19, 25.5), (19.5, 28.5), (16.5, 29.5), (14.5, 27.5)]
    for w in (w1, w2, w3):
        g.solid(m_line(w, 3), CYAN)
    return g


def g_speed():
    """Kanat çentikli çizme + üç hız çubuğu (krem)."""
    g = Glyph()
    boot = m_poly([(12, 3), (22, 3), (22, 17), (28, 19.5), (30, 23), (30, 27), (11, 27), (12, 17)])
    g.solid(boot, CREAM)
    g.cut(m_line([(12, 7), (22, 7)], 1), CREAM)
    g.cut(m_line([(11, 23), (30, 23)], 1), CREAM)
    for y, x0 in ((9, 2), (15, 4), (21, 3)):
        g.solid(m_poly([(x0, y - 1), (x0 + 6, y - 1), (x0 + 6, y + 1.2), (x0, y + 1.2)]), CREAM)
    return g


def g_shield_pen():
    """Mızrağın saplandığı kalkan: darbe noktasından yayılan çatlaklar (kehribar + krem)."""
    g = Glyph()
    sh = heater(13.5, 6, 23, 25)
    g.solid(sh, AMBER)
    hit = (15.0, 16.0)
    cracks = [[hit, (12, 12), (12.5, 8.5), (10, 6)], [hit, (19, 14.5), (21, 10), (25, 9)], [hit, (11, 19), (7, 18)],
              [hit, (16.5, 21), (14, 25), (14.5, 30)]]
    for c in cracks:
        g.cut(m_line(c, 1) & sh, AMBER)
    spear = along(hit, (31.0, 0.0), [(0.0, 0.0), (0.2, 3.4), (0.3, 1.3), (1.0, 1.3)])
    g.solid(spear, CREAM)
    g.solid(along((22.0, 9.0), (25.5, 5.5), [(0, 2.4), (1, 2.4)]), CREAM)
    return g


def g_range():
    """Uçan ok + altında uçları çentikli uzaklık cetveli (krem)."""
    g = Glyph()
    g.solid(m_poly([(2, 23), (30, 23), (30, 25.5), (2, 25.5)]) | m_poly([(2, 19), (4.5, 19), (4.5, 29.5), (2, 29.5)]) |
            m_poly([(27.5, 19), (30, 19), (30, 29.5), (27.5, 29.5)]), CREAM)
    g.solid(m_poly([(15, 21), (16.8, 21), (16.8, 23), (15, 23)]), CREAM)
    g.solid(m_poly([(7, 10.5), (24, 10.5), (24, 12.5), (7, 12.5)]), CREAM)
    g.solid(m_poly([(2, 7), (6, 7), (9, 10.5), (9, 12.5), (6, 16), (2, 16), (5, 11.5)]), CREAM)
    g.solid(m_poly([(22, 5.5), (30.5, 11.5), (22, 17.5)]), CREAM)
    return g


def _mana(g):
    sh = heater(16, 2, 26, 29)
    g.solid(sh, BLUE)
    g.cut(sh - heater(16, 4.5, 21, 24.5), BLUE)  # iç kenar oluğu
    g.solid(heater(16, 5.5, 19, 22.5), BLUE, outline=False)


def g_shield_prot():
    g = Glyph()
    _mana(g)
    pts = set()
    cx, cy = 16.0, 14.0
    for k in range(400):
        t = k / 400 * math.pi * 3.0
        r = 0.8 + t * 0.66
        pts.add((int(math.floor((cx + math.cos(t) * r) * K)), int(math.floor((cy + math.sin(t) * r) * K))))
    thick = {(x + dx, y) for (x, y) in pts for dx in ((0, 1) if K > 0.8 else (0,))}
    g.inlay(thick, BLUE, 4, 4)
    return g


def g_shield_amount():
    g = Glyph()
    _mana(g)
    g.inlay(m_poly([(14, 6.5), (18, 6.5), (18, 11.5), (23, 11.5), (23, 15.5), (18, 15.5), (18, 20.5), (14, 20.5),
                    (14, 15.5), (9, 15.5), (9, 11.5), (14, 11.5)]), BLUE)
    return g


def g_shield_regen():
    g = Glyph()
    _mana(g)
    g.inlay(m_ring(16, 14, 3.6, 6.2, 320, 235) | m_poly([(18.5, 4.8), (25.5, 9.0), (18.5, 12.6)]), BLUE)
    return g


def g_health_regen():
    """Kalp + içinde iki yükselen ok kakması (kırmızı)."""
    g = Glyph()
    g.solid(heart(16, 15.5, 13.0), RED)
    for y in (9.0, 15.0):
        g.inlay(m_poly([(16, y), (22, y + 5.5), (19.4, y + 5.5), (16, y + 2.4), (12.6, y + 5.5), (10, y + 5.5)]), WHITE, 4, 3)
    return g


def g_heal_power():
    """Yuvarlak uçlu kalın artı + iç kakma + köşede küçük artı (yeşil)."""
    g = Glyph()
    cross = m_poly([(11, 4), (21, 4), (21, 11), (28, 11), (28, 21), (21, 21), (21, 28), (11, 28), (11, 21), (4, 21), (4, 11), (11, 11)])
    g.solid(cross, GREEN)
    g.inlay(m_poly([(14.5, 8), (17.5, 8), (17.5, 14.5), (24, 14.5), (24, 17.5), (17.5, 17.5), (17.5, 24), (14.5, 24),
                    (14.5, 17.5), (8, 17.5), (8, 14.5), (14.5, 14.5)]), GREEN, 4, 4)
    return g


def g_luck():
    """Dört yapraklı yonca (altın), yapraklar arası oyma."""
    g = Glyph()
    leaves = set()
    for a in (0, 90, 180, 270):
        r = math.radians(a)
        cx, cy = 15 + math.cos(r) * 6.3, 14 + math.sin(r) * 6.3
        leaves |= _rot_heart(cx, cy, 5.6, a + 90)
    stem = m_line([(15, 15), (19, 23), (24, 29)], 3)
    g.solid(stem, GOLD).solid(leaves, GOLD)
    g.cut(m_line([(15, 4), (15, 24)], 1) | m_line([(5, 14), (25, 14)], 1), GOLD)
    return g


def _rot_heart(cx, cy, s, deg):
    a = math.radians(deg)
    ca, sa = math.cos(a), math.sin(a)

    def f(x, y):
        dx, dy = x - cx, y - cy
        rx = dx * ca + dy * sa
        ry = -dx * sa + dy * ca
        px, py = rx / s, -ry / s
        return (px * px + py * py - 1) ** 3 - px * px * py ** 3 <= 0
    return m_fn(f)


def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def shift(p, off):
    """Çapraz eksene dik kaydırma."""
    d = (B[0] - A[0], B[1] - A[1])
    L = math.hypot(*d)
    vx, vy = -d[1] / L, d[0] / L
    return (p[0] + vx * off, p[1] + vy * off)


ICONS = [
    ("damage", "Saldırı Gücü", g_damage),
    ("fire_rate", "Saldırı Hızı", g_fire_rate),
    ("crit_chance", "Kritik Şansı", g_crit_chance),
    ("crit_damage", "Kritik Hasarı", g_crit_damage),
    ("cooldown_reduction", "Bekleme Azaltma", g_cooldown),
    ("lifesteal", "Can Çalma", g_lifesteal),
    ("dodge", "Sıvışma", g_dodge),
    ("speed", "Hareket Hızı", g_speed),
    ("shield_pen_percent", "Kalkan Delme", g_shield_pen),
    ("range", "Menzil", g_range),
    ("shield_protection", "MK Soğurma", g_shield_prot),
    ("shield_amount", "MK Miktarı", g_shield_amount),
    ("shield_regen", "MK Yenilenmesi", g_shield_regen),
    ("health_regen", "Can Yenilenmesi", g_health_regen),
    ("heal_power", "İyileştirme Gücü", g_heal_power),
    ("luck", "Şans", g_luck),
]


SIZES = [(32, "stat_ikon_lol"), (24, "stat_ikon_lol_24"), (20, "stat_ikon_lol_20")]
## Oyundaki sayfalar (kullanıcı 24 px seçti, 2026-10-14): scripts/hud_stat_panel.gd buradan yükler.
ASSET_SIZE = 24
ASSET_DIR = os.path.join(ROOT, "assets", "ui", "stat_mini")


def main():
    global N, K
    font = ImageFont.truetype(os.path.join(ROOT, "assets", "fonts", "PixeloidSans.ttf"), 9)
    rows = []
    for size, folder in SIZES:
        N, K = size, size / 32.0
        out = os.path.join(HERE, "out", folder)
        os.makedirs(out, exist_ok=True)
        imgs = []
        for key, name, fn in ICONS:
            im = fn().image()
            im.save(os.path.join(out, key + ".png"))
            if size == ASSET_SIZE:
                os.makedirs(ASSET_DIR, exist_ok=True)
                im.save(os.path.join(ASSET_DIR, key + ".png"))
            imgs.append((name, im))
        rows.append((size, imgs))
        if size == 32:
            z, cols = 5, 8
            cw, chh = N * z + 24, N * z + 30
            sheet = Image.new("RGBA", (cols * cw + 16, 2 * chh + 16), "#2a1a10")
            d = ImageDraw.Draw(sheet)
            for i, (name, im) in enumerate(imgs):
                x = 16 + (i % cols) * cw
                y = 12 + (i // cols) * chh
                d.rectangle([x - 3, y - 3, x + N * z + 2, y + N * z + 2], fill="#1c1009")
                sheet.alpha_composite(im.resize((N * z, N * z), Image.NEAREST), (x, y))
                d.text((x, y + N * z + 7), name, fill="#f7eed6", font=font)
            sheet.save(os.path.join(HERE, "out", "stat_ikon_lol_onizleme.png"))
    ## Boyut karşılaştırması: her satır bir boyut, 1:1 çizilip x3 büyütülür.
    strip = Image.new("RGBA", (16 * 36 + 40, sum(sz + 10 for sz, _ in rows) + 10), "#211409")
    d = ImageDraw.Draw(strip)
    y = 8
    for size, imgs in rows:
        d.text((4, y + size // 2 - 5), str(size), fill="#f7eed6", font=font)
        for i, (_, im) in enumerate(imgs):
            strip.alpha_composite(im, (34 + i * 36 + (32 - size) // 2, y))
        y += size + 10
    strip.resize((strip.width * 3, strip.height * 3), Image.NEAREST).save(os.path.join(HERE, "out", "stat_ikon_lol_boyutlar.png"))


if __name__ == "__main__":
    main()
