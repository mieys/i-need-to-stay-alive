"""Piksel-sanat UI kiti için ortak yardımcılar (tools/gen_ui_kit.py ve tools/gen_shield_icons.py kullanır).

Tasarım kuralı (kullanıcı isteği 2026-09-21: "cozy/rpg tarzında pixel, esnemeden kaynaklı kalite kaybı olmasın"):
  - Her sanat pikseli tam S=2 ekran pikselidir (NEAREST, tam sayı ölçek) - 9-slice dokularda esneyen orta bölge DÜZ renktir,
    bu yüzden ne kadar büyütülürse büyütülsün detay bozulmaz/bulanmaz.
  - Yazı tipi (m5x7) 16'nın katı boyutlarda kullanılırsa (32/48/64) yazı pikselleri de aynı 2 px ızgarasına oturur.
"""
import os
from PIL import Image

S = 2


def hexc(h, a=255):
    h = h.lstrip('#')
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3)) + (a[3],)


def lighten(c, t):
    return mix(c, (255, 255, 255, c[3]), t)


def darken(c, t):
    return mix(c, (0, 0, 0, c[3]), t)


def gray_mix(c, t):
    g = int(0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2])
    return mix(c, (g, g, g, c[3]), t)


class Art:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.p = [[None] * w for _ in range(h)]

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.p[y][x] = c

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.p[y][x]
        return None

    def rect(self, x, y, w, h, c):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.set(xx, yy, c)

    def image(self):
        im = Image.new('RGBA', (self.w, self.h), (0, 0, 0, 0))
        px = im.load()
        for y in range(self.h):
            for x in range(self.w):
                c = self.p[y][x]
                if c is not None:
                    px[x, y] = c
        return im

    def save(self, path, scale=S):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        im = self.image()
        if scale != 1:
            im = im.resize((self.w * scale, self.h * scale), Image.NEAREST)
        im.save(path)


def rr_mask(w, h, r):
    """Yuvarlatılmış dikdörtgen maskesi (True = içeride)."""
    m = [[True] * w for _ in range(h)]
    if r <= 0:
        return m
    for y in range(h):
        for x in range(w):
            cx = cy = None
            if x < r and y < r:
                cx, cy = r, r
            elif x >= w - r and y < r:
                cx, cy = w - r, r
            elif x < r and y >= h - r:
                cx, cy = r, h - r
            elif x >= w - r and y >= h - r:
                cx, cy = w - r, h - r
            if cx is not None:
                dx = (x + 0.5) - cx
                dy = (y + 0.5) - cy
                if dx * dx + dy * dy > r * r:
                    m[y][x] = False
    return m


def depth_map(mask):
    """Her içeri pikselin kenara (dışarıya) 4-komşuluk uzaklığı: 0 = dış kenar (kontur)."""
    h, w = len(mask), len(mask[0])
    d = [[-1] * w for _ in range(h)]
    cur = []
    for y in range(h):
        for x in range(w):
            if not mask[y][x]:
                continue
            edge = False
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < w and 0 <= ny < h) or not mask[ny][nx]:
                    edge = True
                    break
            if edge:
                d[y][x] = 0
                cur.append((x, y))
    level = 0
    while cur:
        nxt = []
        for x, y in cur:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and mask[ny][nx] and d[ny][nx] == -1:
                    d[ny][nx] = level + 1
                    nxt.append((nx, ny))
        cur = nxt
        level += 1
    return d


def light_side(x, y, w, h):
    """En yakın kenar üst/sol ise True (aydınlık taraf), alt/sağ ise False - 9-slice'ta esneyen bölgede tutarlı kalır."""
    dt, db, dl, dr = y, h - 1 - y, x, w - 1 - x
    m = min(dt, db, dl, dr)
    return dt == m or dl == m


def paste_mirror4(a, x, y, c):
    """Sol-üst köşe koordinatını dört köşeye yansıtarak yazar."""
    a.set(x, y, c)
    a.set(a.w - 1 - x, y, c)
    a.set(x, a.h - 1 - y, c)
    a.set(a.w - 1 - x, a.h - 1 - y, c)


# ---------------------------------------------------------------- palet
# Kullanıcı isteği (2026-09-24): oyun içi arayüzler menülerle AYNI bej/ahşap dile geçti ("biraz daha koyu") - bu palet
# tools/gen_menu_kit.py GAME_PAL ile aynı tonlar (ahşap W*, kontur OUT); eski koyu deri iç (LEATHER/INSET) yerine parşömen.
# HUD çerçeveleri (can/kalkan barı, avatar, yetenek slotları, minimap halkası, yetenek çubuğu, buff rozeti) buradan üretilir.
OUT = hexc('#3a2213')
W4 = hexc('#d8a56c')
W3 = hexc('#b9844f')
W2 = hexc('#976639')
W1 = hexc('#734727')
W0 = hexc('#55331b')
LEATHER = hexc('#c8a878')
LEATHER_D = hexc('#ae8e60')
INSET = hexc('#b99a6b')
GOLD_L = hexc('#ffe58a')
GOLD = hexc('#eab440')
GOLD_D = hexc('#9c6318')
IRON_L = hexc('#cdd3de')
IRON = hexc('#8d94a3')
IRON_D = hexc('#4d5464')
PARCH = hexc('#e9d7a9')
