"""Boss çubuğu prototipleri için piksel çizim kütüphanesi (oyun kitiyle aynı palet, m5x7 yazı tipi 1x)."""
import math
from PIL import Image, ImageDraw, ImageFont

PROJ = "C:/Users/perva/Desktop/I need to stay alive/I need to stay alive"
FONT = ImageFont.truetype(PROJ + "/assets/fonts/m5x7.ttf", 16)


def hexc(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


# --- palet: oyun kiti (assets/ui/game, assets/ui/kit) dokularından örneklendi ---
OUT = hexc("#382011")      # koyu kahve anahat
OUT2 = hexc("#1e120a")     # daha koyu
W_HI = hexc("#ae956d")
W_FACE = hexc("#a4875c")
W_MD = hexc("#94764c")
W_BR = hexc("#9b6b3a")
W_DK = hexc("#683e20")
W_DD = hexc("#543119")
W_SH = hexc("#725531")
GOLD_L = hexc("#c2aa6c")
GOLD = hexc("#b78b2a")
GOLD_D = hexc("#956313")
PARCH = hexc("#c8a878")
PARCH_HI = hexc("#d9bd8f")
PARCH_SH = hexc("#ae8e60")
INK = hexc("#3a2212")
CREAM = hexc("#fff0d6")
BONE = hexc("#e9ddc2")
BONE_D = hexc("#b9a98a")
BONE_DD = hexc("#8a7a60")
IRON = hexc("#3b3640")
IRON_L = hexc("#5b5563")
IRON_HI = hexc("#7d7787")
IRON_D = hexc("#24202b")
TRACK = hexc("#1d0f0b")
TRACK2 = hexc("#2a1712")
RED_HI = hexc("#f07a62")
RED_L = hexc("#d2413a")
RED = hexc("#ae2730")
RED_M = hexc("#831824")
RED_D = hexc("#570c11")
BLUE_HI = hexc("#bfe0ff")
BLUE_L = hexc("#6fa8e6")
BLUE = hexc("#3065ac")
BLUE_D = hexc("#13284d")
EMPTY_BLUE = hexc("#0f1c33")
CLEAR = (0, 0, 0, 0)

_text_cache = {}


def text_mask(s):
    """m5x7 16 boyutunda zaten 1x (büyük harf 7 px): fontmode '1' ile antialias'sız maske. y=0 büyük harf üstü (İ noktası negatife taşar)."""
    if s in _text_cache:
        return _text_cache[s]
    w = int(FONT.getlength(s)) + 4
    im = Image.new("L", (w, 24), 0)
    d = ImageDraw.Draw(im)
    d.fontmode = "1"
    d.text((0, 2), s, font=FONT, fill=255)
    cap_top = ImageFont.truetype(PROJ + "/assets/fonts/m5x7.ttf", 16).getbbox("H")[1] + 2
    px = im.load()
    pts = set()
    maxx = 0
    for y in range(im.height):
        for x in range(im.width):
            if px[x, y]:
                pts.add((x, y - cap_top))
                maxx = max(maxx, x)
    _text_cache[s] = (pts, maxx + 1)
    return _text_cache[s]


class Art:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.im = Image.new("RGBA", (w, h), CLEAR)
        self.px = self.im.load()

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = c

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[x, y]
        return CLEAR

    def rect(self, x, y, w, h, c):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.set(xx, yy, c)

    def shade(self, x, y, c, alpha):
        """Mevcut pikselin üstüne c'yi alpha (0-1) ile karıştır."""
        if 0 <= x < self.w and 0 <= y < self.h:
            b = self.px[x, y]
            if b[3] == 0:
                return
            self.px[x, y] = tuple(int(b[i] * (1 - alpha) + c[i] * alpha) for i in range(3)) + (b[3],)

    def hline(self, x, y, w, c):
        self.rect(x, y, w, 1, c)

    def vline(self, x, y, h, c):
        self.rect(x, y, 1, h, c)

    def box(self, x, y, w, h, c):
        """1 px'lik dikdörtgen çerçeve."""
        self.hline(x, y, w, c)
        self.hline(x, y + h - 1, w, c)
        self.vline(x, y, h, c)
        self.vline(x + w - 1, y, h, c)

    def rrect(self, x, y, w, h, c):
        """Köşeleri 1 px kesik dolu dikdörtgen."""
        for yy in range(h):
            for xx in range(w):
                if (xx in (0, w - 1)) and (yy in (0, h - 1)):
                    continue
                self.set(x + xx, y + yy, c)

    def blit(self, rows, pal, x, y):
        """ASCII sanat: '.' saydam, diğer karakterler pal sözlüğünden."""
        for yy, row in enumerate(rows):
            for xx, ch in enumerate(row):
                if ch != "." and ch in pal:
                    self.set(x + xx, y + yy, pal[ch])

    def paste(self, other, x, y):
        for yy in range(other.h):
            for xx in range(other.w):
                c = other.px[xx, yy]
                if c[3]:
                    self.set(x + xx, y + yy, c)

    def text(self, x, y, s, color, outline=None, shadow=None):
        pts, w = text_mask(s)
        if outline:
            for (px, py) in pts:
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        if dx or dy:
                            self.set(x + px + dx, y + py + dy, outline)
        if shadow:
            for (px, py) in pts:
                self.set(x + px, y + py + 1, shadow)
        for (px, py) in pts:
            self.set(x + px, y + py, color)
        return w

    def text_width(self, s):
        return text_mask(s)[1]

    def scaled(self, s):
        return self.im.resize((self.w * s, self.h * s), Image.NEAREST)


def vgrad(a, x, y, w, h, colors):
    """Satır satır renk bantları (colors uzunluğu h'ye bölünür)."""
    n = len(colors)
    for yy in range(h):
        c = colors[min(n - 1, yy * n // h)]
        a.hline(x, y + yy, w, c)


def fill_bar(a, x, y, w, h, ratio, bands, track=TRACK):
    """İç içe: izi çiz, sonra ratio kadar bantlı dolgu (soldan)."""
    a.rect(x, y, w, h, track)
    fw = int(round(w * max(0.0, min(1.0, ratio))))
    if ratio > 0 and fw < 1:
        fw = 1
    if fw > 0:
        vgrad(a, x, y, fw, h, bands)
        # dolgunun sağ ucunda 1 px parlak kenar (dolu uç)
        if fw < w:
            a.vline(x + fw - 1, y, h, bands[len(bands) // 2])


def circle_points(cx, cy, r):
    pts = []
    for y in range(int(cy - r - 1), int(cy + r + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            pts.append((x, y, d))
    return pts


HP_BANDS = [RED_HI, RED_L, RED, RED, RED_M, RED_D]
SH_BANDS = [BLUE_HI, BLUE_L, BLUE, BLUE, BLUE_D]
SKULL = [
    "..XXXXX..",
    ".XWWWWWX.",
    "XWWWWWWWX",
    "XWKKWKKWX",
    "XWKKWKKWX",
    ".XWWXWWX.",
    "..XWWWX..",
    "..XWXWX..",
    "...XXX...",
]


def skull(bone=BONE, shade=BONE_D, outline=OUT, eye=OUT2):
    a = Art(9, 9)
    a.blit(SKULL, {"X": outline, "W": bone, "K": eye}, 0, 0)
    # alt-sol gölge
    a.set(1, 5, shade)
    a.set(7, 5, shade)
    a.set(6, 6, shade)
    return a
