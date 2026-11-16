"""2026-11-16 prototipi: RUHANİ YETENEK efektleri (kullanıcı: "ruhani yeteneklerin efektleri çok kötü hepsinin görünüşü için
yeni prototipler hazırla"). OYUNA BAĞLI DEĞİL; mekanik/sayı değişmez, yalnız görünüş.
Kendi efekti olan 5 ruhani: Can, Adc, Tank, Taktiksel, Kalkan Bağı (Para / Savaş Şevki / Toplayıcı'nın kendi efekti yok).
Her biri: 0 Şimdiki (oyundaki dokular + prosedürel kısımların yakın kopyası) + 3 yeni yön. Yönler AİLE (hepsinde aynı dil):
  A Ruh Işığı   konturuz, düz alfa bantlı ışık; soluk çekirdek dışı renkli (Şovalye E'de beğenilen hafif ışık dili)
  B Rün Mührü   ince 1 px çizgiler + minik rünler, çoğu yer düzleminde; en sakin, en az yer kaplayan
  C Dolu Piksel 1 px koyu kontur + düz ton dolgu + krem parlama; oyunun vuruş/patlama/ateş dili
TİTREŞİM (Bayer/dama/gürültü) YOK - yumuşaklık yalnız düz alfa bantlarıyla (hafıza no-dither).
Ölçek: tuval 1 px = 0,5 dünya (oyun kamerası x2, 1080p). Karakter sanat pikseli 0,903 dünya; yeni FX pikseli 1 dünya birimi
(= karakter pikseli); şimdiki FX dokuları 1 px = 1 yerel = 0,5 dünya (Player kökü 0,5 ölçekli).
Arka plan: proto_20261016 gerçek çizici yakalaması. Çıktı: out/<yetenek>.gif (2x2 karşılaştırma) + out/ozet.png.
Kullanım (proje kökünden): python -I tools/proto_20261116/ruhani_fx/ruhani_fx_proto.py [can adc tank taktik kalkan] [--still]
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
OUT = os.path.join(HERE, 'out')
BG_PATH = os.path.join(PROJECT, 'tools', 'proto_20261016', 'harita_renk', 'out', 'orman2_doygun_sonra.png')
TAU = math.tau
DT = 0.07
K = 2  ## tuval px / dünya birimi
CHAR_S = 2.2368375 * 0.8075 * 0.5  ## sanat pikseli -> dünya (0,903)
SLIME_S = 0.94905
S2 = K * CHAR_S
TEXEL = 1.212
PAD = 2

CREAM = (255, 246, 220)
GOLD = [(96, 52, 14), (170, 104, 24), (232, 170, 52), (252, 222, 120), (255, 248, 214)]
HEAL = [(20, 66, 44), (44, 124, 70), (96, 186, 92), (168, 228, 132), (232, 252, 206)]
FIRE = [(84, 18, 24), (172, 40, 30), (230, 94, 36), (250, 166, 58), (255, 234, 150)]
STEEL = [(24, 34, 64), (52, 82, 136), (98, 142, 202), (172, 210, 244), (238, 248, 255)]
WIND = [(16, 62, 76), (34, 126, 142), (84, 198, 208), (172, 240, 238), (240, 255, 252)]
MANA = [(32, 38, 100), (62, 88, 182), (112, 152, 240), (184, 212, 255), (242, 247, 255)]

VAR_NAMES = {'0': '0  Şimdiki (oyunda)', 'A': 'A  Ruh Işığı', 'B': 'B  Rün Mührü', 'C': 'C  Dolu Piksel'}


# ====================================================================== yardımcılar
def rgba(p):
    return Image.open(p).convert('RGBA')


def nscale(im, s):
    return im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.NEAREST)


def grid(im, fw, fh):
    return [[im.crop((c * fw, r * fh, c * fw + fw, r * fh + fh)) for c in range(im.width // fw)] for r in range(im.height // fh)]


def comp(dst, src, x, y):
    x, y = int(round(x)), int(round(y))
    sx0, sy0 = max(0, -x), max(0, -y)
    sx1, sy1 = min(src.width, dst.width - x), min(src.height, dst.height - y)
    if sx1 <= sx0 or sy1 <= sy0:
        return
    dst.alpha_composite(src.crop((sx0, sy0, sx1, sy1)), (x + sx0, y + sy0))


def clamp01(v):
    return max(0.0, min(1.0, v))


def band(a, n=4):
    return max(0.0, min(1.0, round(a * n) / n))


def ease_out(t):
    t = clamp01(t)
    return 1 - (1 - t) ** 3


def ease_in(t):
    t = clamp01(t)
    return t * t


def ease_io(t):
    t = clamp01(t)
    return t * t * (3 - 2 * t)


def overshoot(t, k=1.6):
    t = clamp01(t)
    return 1 + (k + 1) * (t - 1) ** 3 + k * (t - 1) ** 2


def lerp(a, b, k):
    return a + (b - a) * k


def lerpc(c0, c1, k):
    return tuple(int(round(lerp(c0[i], c1[i], k))) for i in range(3))


def rnd(i, k=0):
    v = (i * 73856093) ^ (k * 19349663) ^ 0x5bd1e995
    v = (v ^ (v >> 13)) * 0x5bd1e995 & 0xffffffff
    return ((v ^ (v >> 15)) & 0xffff) / 65535.0


def font(sz):
    for c in (r'C:\Windows\Fonts\segoeuib.ttf', r'C:\Windows\Fonts\segoeui.ttf', r'C:\Windows\Fonts\arial.ttf'):
        if os.path.exists(c):
            return ImageFont.truetype(c, sz)
    return ImageFont.load_default()


def faded(im, a):
    if a >= 0.999:
        return im
    arr = np.array(im)
    arr[:, :, 3] = (arr[:, :, 3].astype(np.float32) * max(0.0, a)).astype(np.uint8)
    return Image.fromarray(arr)


# ---------------------------------------------------------------- maskeler (dünya ya da tuval koordinatı; (x0, y0, bool dizi))
def _box(xa, ya, xb, yb):
    x0, y0 = int(math.floor(xa)) - PAD, int(math.floor(ya)) - PAD
    x1, y1 = int(math.ceil(xb)) + PAD + 1, int(math.ceil(yb)) + PAD + 1
    Y, X = np.mgrid[y0:y1, x0:x1]
    return x0, y0, X + 0.5, Y + 0.5


def ell_d(cx, cy, rx, ry):
    x0, y0, X, Y = _box(cx - rx, cy - ry, cx + rx, cy + ry)
    d = np.sqrt(((X - cx) / max(rx, 0.05)) ** 2 + ((Y - cy) / max(ry, 0.05)) ** 2)
    return x0, y0, X, Y, d


def m_ell(cx, cy, rx, ry):
    x0, y0, X, Y, d = ell_d(cx, cy, rx, ry)
    return (x0, y0, d <= 1.0)


def ero(m):
    e = m.copy()
    e[1:] &= m[:-1]
    e[:-1] &= m[1:]
    e[:, 1:] &= m[:, :-1]
    e[:, :-1] &= m[:, 1:]
    e[0, :] = False
    e[-1, :] = False
    e[:, 0] = False
    e[:, -1] = False
    return e


def dil(m):
    o = m.copy()
    o[1:] |= m[:-1]
    o[:-1] |= m[1:]
    o[:, 1:] |= m[:, :-1]
    o[:, :-1] |= m[:, 1:]
    return o


def shift(m, dx, dy):
    o = np.zeros_like(m)
    h, w = m.shape
    o[max(0, dy):h + min(0, dy), max(0, dx):w + min(0, dx)] = m[max(0, -dy):h + min(0, -dy), max(0, -dx):w + min(0, -dx)]
    return o


def m_ring(cx, cy, rx, ry, th=1):
    x0, y0, m = m_ell(cx, cy, rx, ry)
    e = m
    for _ in range(th):
        e = ero(e)
    return (x0, y0, m & ~e)


def ang_in(ang, a0, a1):
    if a1 - a0 >= TAU - 1e-6:
        return np.ones_like(ang, bool)
    return ((ang - a0) % TAU) <= ((a1 - a0) % TAU)


def m_arc(cx, cy, rx, ry, a0, a1, th=1):
    x0, y0, X, Y, d = ell_d(cx, cy, rx, ry)
    m = d <= 1.0
    e = m
    for _ in range(th):
        e = ero(e)
    ang = np.arctan2((Y - cy) / max(ry, 0.05), (X - cx) / max(rx, 0.05))
    return (x0, y0, m & ~e & ang_in(ang, a0, a1))


def m_half(mk, cy, upper):
    """Elips halkasının arka (üst, y<cy) ya da ön (alt) yarısı."""
    x0, y0, m = mk
    ys = np.arange(m.shape[0])[:, None] + y0 + 0.5
    return (x0, y0, m & ((ys < cy) if upper else (ys >= cy)))


def m_line(p0, p1):
    (xa, ya), (xb, yb) = p0, p1
    n = int(max(abs(xb - xa), abs(yb - ya)) * 1.5) + 2
    xs = np.floor(np.linspace(xa, xb, n)).astype(int)
    ys = np.floor(np.linspace(ya, yb, n)).astype(int)
    x0, y0 = xs.min() - PAD, ys.min() - PAD
    m = np.zeros((ys.max() - y0 + PAD + 1, xs.max() - x0 + PAD + 1), bool)
    m[ys - y0, xs - x0] = True
    return (x0, y0, m)


def m_polyline(pts):
    return m_union(*[m_line(pts[i], pts[i + 1]) for i in range(len(pts) - 1)])


def m_stroke(pts, radii):
    P = np.array(pts, np.float32)
    R = np.array(radii, np.float32)
    rm = float(R.max())
    x0, y0, X, Y = _box(P[:, 0].min() - rm, P[:, 1].min() - rm, P[:, 0].max() + rm, P[:, 1].max() + rm)
    m = np.zeros(X.shape, bool)
    for (px, py), r in zip(P, R):
        if r <= 0.05:
            continue
        ix0, iy0 = max(0, int(px - r) - x0 - 1), max(0, int(py - r) - y0 - 1)
        ix1, iy1 = int(px + r) - x0 + 2, int(py + r) - y0 + 2
        sx, sy = X[iy0:iy1, ix0:ix1], Y[iy0:iy1, ix0:ix1]
        m[iy0:iy1, ix0:ix1] |= (sx - px) ** 2 + (sy - py) ** 2 <= r * r
    return (x0, y0, m)


def m_poly(pts):
    P = np.array(pts, np.float32)
    x0, y0 = int(math.floor(P[:, 0].min())) - PAD, int(math.floor(P[:, 1].min())) - PAD
    w, h = int(math.ceil(P[:, 0].max())) - x0 + PAD + 1, int(math.ceil(P[:, 1].max())) - y0 + PAD + 1
    im = Image.new('L', (w, h))
    ImageDraw.Draw(im).polygon([(float(x - x0), float(y - y0)) for (x, y) in P], fill=1)
    return (x0, y0, np.array(im) > 0)


def m_glyph(rows, cx, cy):
    h, w = len(rows), max(len(r) for r in rows)
    m = np.zeros((h + 2 * PAD, w + 2 * PAD), bool)
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch == '#':
                m[y + PAD, x + PAD] = True
    return (int(math.floor(cx)) - w // 2 - PAD, int(math.floor(cy)) - h // 2 - PAD, m)


def m_union(*mks):
    mks = [m for m in mks if m is not None]
    x0 = min(m[0] for m in mks)
    y0 = min(m[1] for m in mks)
    x1 = max(m[0] + m[2].shape[1] for m in mks)
    y1 = max(m[1] + m[2].shape[0] for m in mks)
    o = np.zeros((y1 - y0, x1 - x0), bool)
    for (mx, my, mm) in mks:
        o[my - y0:my - y0 + mm.shape[0], mx - x0:mx - x0 + mm.shape[1]] |= mm
    return (x0, y0, o)


def m_and_not(a, b):
    """a & ~b (b a'nın içinde ya da dışında olabilir)."""
    x0, y0, ma = a
    bx, by, mb = b
    o = ma.copy()
    ys0, xs0 = max(0, by - y0), max(0, bx - x0)
    ys1, xs1 = min(ma.shape[0], by - y0 + mb.shape[0]), min(ma.shape[1], bx - x0 + mb.shape[1])
    if ys1 > ys0 and xs1 > xs0:
        o[ys0:ys1, xs0:xs1] &= ~mb[ys0 - (by - y0):ys1 - (by - y0), xs0 - (bx - x0):xs1 - (bx - x0)]
    return (x0, y0, o)


# ---------------------------------------------------------------- katman
class Layer:
    """Kayan nokta RGBA katmanı; maske + tek alfa ile 'üstüne' karıştırma. (ox, oy) = sol üst köşenin koordinatı."""

    def __init__(self, ox, oy, w, h):
        self.ox, self.oy, self.w, self.h = ox, oy, w, h
        self.c = np.zeros((h, w, 4), np.float32)

    def put(self, x0, y0, m, rgb, a):
        a = float(a)
        if a <= 0.004:
            return
        x0, y0 = int(x0) - self.ox, int(y0) - self.oy
        h, w = m.shape
        X0, Y0, X1, Y1 = max(0, x0), max(0, y0), min(self.w, x0 + w), min(self.h, y0 + h)
        if X1 <= X0 or Y1 <= Y0:
            return
        mm = m[Y0 - y0:Y1 - y0, X0 - x0:X1 - x0]
        if not mm.any():
            return
        reg = self.c[Y0:Y1, X0:X1]
        d = reg[mm]
        oa = a + d[:, 3] * (1 - a)
        col = (np.array(rgb, np.float32) / 255.0 * a + d[:, :3] * d[:, 3:4] * (1 - a)) / np.maximum(oa[:, None], 1e-6)
        reg[mm] = np.concatenate([col, oa[:, None]], 1)

    def pm(self, mk, rgb, a):
        if mk is not None:
            self.put(mk[0], mk[1], mk[2], rgb, a)

    def blit(self, im, x, y, a=1.0, bright=1.0):
        """Görüntüyü piksel alfasıyla bindirir (x, y sol üst)."""
        if a <= 0.004:
            return
        arr = np.asarray(im, np.float32) / 255.0
        x, y = int(round(x)) - self.ox, int(round(y)) - self.oy
        h, w = arr.shape[:2]
        X0, Y0, X1, Y1 = max(0, x), max(0, y), min(self.w, x + w), min(self.h, y + h)
        if X1 <= X0 or Y1 <= Y0:
            return
        s = arr[Y0 - y:Y1 - y, X0 - x:X1 - x]
        sa = s[:, :, 3:4] * a
        sc = np.clip(s[:, :, :3] * bright, 0, 1)
        reg = self.c[Y0:Y1, X0:X1]
        oa = sa + reg[:, :, 3:4] * (1 - sa)
        reg[:, :, :3] = (sc * sa + reg[:, :, :3] * reg[:, :, 3:4] * (1 - sa)) / np.maximum(oa, 1e-6)
        reg[:, :, 3:4] = oa

    def img(self):
        return Image.fromarray(np.clip(self.c * 255.0, 0, 255).astype(np.uint8), 'RGBA')


# ---------------------------------------------------------------- çizim kalıpları
def glow(L, cx, cy, rx, ry, c_out, c_in, amax, n=3, power=1.0):
    """İçe doğru basamaklı (düz bant) yumuşak ışık."""
    if rx < 0.5 or ry < 0.5 or amax <= 0.004:
        return
    x0, y0, X, Y, d = ell_d(cx, cy, rx, ry)
    f = np.clip(1 - d, 0, 1) ** power
    q = np.ceil(f * n - 1e-6)
    for lv in range(1, n + 1):
        mm = q == lv
        if mm.any():
            L.put(x0, y0, mm, lerpc(c_out, c_in, (lv - 1) / max(1, n - 1)), amax * lv / n)


def shell(L, cx, cy, rx, ry, rgb, amax, n=3, power=3.0):
    """Kenara doğru koyulaşan (fresnel) kabuk dolgusu - ortası boş."""
    if rx < 1 or ry < 1 or amax <= 0.004:
        return
    x0, y0, X, Y, d = ell_d(cx, cy, rx, ry)
    f = np.where(d <= 1, np.clip(d, 0, 1) ** power, 0)
    q = np.round(f * n)
    for lv in range(1, n + 1):
        mm = (q == lv) & (d <= 1)
        if mm.any():
            L.put(x0, y0, mm, rgb, amax * lv / n)


def sparkle(L, x, y, k, core, arm, a=1.0):
    k = int(k)
    if k <= 0 or a <= 0.004:
        return
    n = 2 * k + 1
    mc, ma = np.zeros((n, n), bool), np.zeros((n, n), bool)
    mc[k, k] = True
    for i in range(1, k + 1):
        tgt = mc if (i == 1 and k >= 2) else ma
        for (dx, dy) in ((i, 0), (-i, 0), (0, i), (0, -i)):
            tgt[k + dy, k + dx] = True
    xi, yi = int(math.floor(x)) - k, int(math.floor(y)) - k
    L.put(xi, yi, ma, arm, a)
    L.put(xi, yi, mc, core, a)


def cel(L, mk, pal, a=1.0, outline=True, top_light=False):
    """Dolu piksel: 1 px koyu kontur + gövde + ışık kenarı (sol üst / üst) + gölge kenarı."""
    if mk is None:
        return
    x0, y0, m = mk
    if not m.any():
        return
    m = np.pad(m, 1)
    x0, y0 = x0 - 1, y0 - 1
    if outline:
        L.put(x0, y0, dil(m) & ~m, pal[0], a)
    L.put(x0, y0, m, pal[2], a)
    dx, dy = (0, 1) if top_light else (1, 1)
    sh = m & ~shift(m, -dx, -dy)
    hi = m & ~shift(m, dx, dy)
    L.put(x0, y0, sh & ~hi, pal[1], a)
    L.put(x0, y0, hi, pal[3], a)


def tongue(bx, by, hw, h, sway, wob=0.0):
    """Taban (bx, by), yarı genişlik hw, boy h, uç kayması sway - sivri alev/ışık dili poligonu."""
    left, right = [], []
    n = 10
    for i in range(n + 1):
        s = i / n
        cx = bx + sway * s ** 1.6
        w = hw * (1 - s) ** 0.75 * (1 + wob * math.sin(s * 5.0))
        y = by - h * s
        left.append((cx - w, y))
        right.append((cx + w, y))
    base = [(bx + hw * math.cos(a), by + hw * 0.45 * math.sin(a)) for a in np.linspace(0, math.pi, 7)]
    return right + left[::-1] + base[::-1][1:-1]


def quad(p0, p1, p2, u):
    return ((1 - u) ** 2 * p0[0] + 2 * (1 - u) * u * p1[0] + u * u * p2[0],
            (1 - u) ** 2 * p0[1] + 2 * (1 - u) * u * p1[1] + u * u * p2[1])


PLUS = ["..#..", "..#..", "#####", "..#..", "..#.."]
RUNES = [["#.#", ".#.", "#.#"], [".#.", "###", ".#."], ["##.", ".#.", ".##"], ["#..", "###", "..#"], [".#.", "#.#", ".#."]]
DIAM = [".#.", "#.#", ".#."]


# ====================================================================== sanat
_CH = {}


def char_frame(key, clip, row, col):
    k = (key, clip)
    if k not in _CH:
        g = grid(rgba(os.path.join(PROJECT, 'assets', 'characters', key, 'sheets', clip + '.png')), 48, 48)
        _CH[k] = [[(f, nscale(f, S2)) for f in r] for r in g]
    r = _CH[k][row]
    return r[col % len(r)]


_SL = os.path.join(PROJECT, 'visuals', 'Yaratıklar', 'Tüm Yaratıklar', 'Slime 1', 'PNG', 'Slime1', 'With_shadow')
SLIME_WALK = [[nscale(f, K * SLIME_S) for f in r] for r in grid(rgba(os.path.join(_SL, 'Slime1_Walk_with_shadow.png')), 64, 64)]
SLIME_HURT = [[nscale(f, K * SLIME_S) for f in r] for r in grid(rgba(os.path.join(_SL, 'Slime1_Hurt_with_shadow.png')), 64, 64)]


def sil_img(art, rgb, a, mode='fill', rows_from=None):
    """Karakter karesinden (sanat çözünürlüğü) silüet dolgu ya da 1 sanat px kontur; tuval ölçeğine büyütülür."""
    m = np.asarray(art)[:, :, 3] > 0
    if mode == 'outline':
        m = dil(m) & ~m
    if rows_from is not None:
        m[:max(0, min(48, int(rows_from)))] = False
    arr = np.zeros((48, 48, 4), np.uint8)
    arr[m] = tuple(rgb) + (int(255 * clamp01(a)),)
    return nscale(Image.fromarray(arr, 'RGBA'), S2)


FXD = os.path.join(PROJECT, 'assets', 'fx')
CAN_TEX = [rgba(os.path.join(FXD, 'spirit_can', n + '.png')) for n in ('dome_fill', 'ring1', 'ring2', 'ring3', 'rivets')]
CAN_SPIN = [0.0, 0.20, -0.16, -0.28, 1.2]
ADC_GROUND = rgba(os.path.join(FXD, 'spirit_adc', 'ground.png'))
ADC_FLAMES = grid(rgba(os.path.join(FXD, 'spirit_adc', 'flames.png')), 96, 96)[0]
ADC_DIAM = rgba(os.path.join(FXD, 'spirit_adc', 'diamonds.png'))
TANK_OUT = rgba(os.path.join(FXD, 'spirit_tank', 'hex_outer.png'))
TANK_IN = rgba(os.path.join(FXD, 'spirit_tank', 'hex_inner.png'))
KB_LINE = rgba(os.path.join(FXD, 'kalkan_bagi', 'link_line.png'))
KB_END = grid(rgba(os.path.join(FXD, 'kalkan_bagi', 'link_end.png')), 7, 7)[0]
KB_GLINT = grid(rgba(os.path.join(FXD, 'kalkan_bagi', 'link_glint.png')), 7, 7)[0]


def rot_scale(tex, ang, s=1.0):
    im = tex.rotate(-math.degrees(ang), resample=Image.NEAREST, expand=True)
    if s < 0.999:
        im = nscale(im, max(0.02, s))
    return im


def blit_c(L, im, cx, cy, a=1.0, bright=1.0):
    L.blit(im, cx - im.width / 2, cy - im.height / 2, a, bright)


def bright_ring(L, cx, cy, r, col, a, dash=None, phase=0.0):
    """Şimdiki PixelDraw.ring yaklaşığı (tuval px, 1 px, düz daire; dash=(açık, kapalı) yay px)."""
    if a <= 0.004 or r < 1:
        return
    x0, y0, X, Y, d = ell_d(cx, cy, r, r)
    m = (d <= 1) & ~ero(d <= 1)
    if dash:
        ang = np.arctan2(Y - cy, X - cx)
        s = (ang * r + phase) % (dash[0] + dash[1])
        m &= s < dash[0]
    L.put(x0, y0, m, col, a)


# ====================================================================== sahne
class Scene:
    def __init__(self, key, title, crop, T0, T_END, summary_t, summary_crop):
        self.key, self.title = key, title
        self.X0, self.Y0, self.W, self.H = crop
        self.T0, self.T_END = T0, T_END
        self.summary_t, self.summary_crop = summary_t, summary_crop

    def cv(self, x, y):
        return ((x - self.X0) * K, (y - self.Y0) * K)


BG = rgba(BG_PATH)
for (_x0, _y0, _x1, _y1, _dx) in ((424, 258, 445, 293, 26), (461, 294, 486, 331, -40)):
    BG.paste(BG.crop((_x0 + _dx, _y0, _x1 + _dx, _y1)), (_x0, _y0))


def char_actor(S, aid, key, x, y, clip, row, col):
    art, img = char_frame(key, clip, row, col)
    cx, cy = S.cv(x, y)
    return {'id': aid, 'kind': 'char', 'x': x, 'y': y, 'art': art, 'img': img,
            'px': cx - 24 * S2, 'py': cy - 40 * S2, 'over': [], 'pre': []}


def slime_actor(S, aid, x, y, row, t, hurt_t=None):
    if hurt_t is not None and 0 <= hurt_t < 0.36:
        img = SLIME_HURT[row][min(4, int(hurt_t / 0.072))]
    else:
        img = SLIME_WALK[row][int(t * 9 + x) % 8]
    cx, cy = S.cv(x, y - 8)
    return {'id': aid, 'kind': 'slime', 'x': x, 'y': y, 'img': img, 'px': cx - img.width / 2, 'py': cy - img.height / 2,
            'over': [], 'pre': []}


def lunge(t, th):
    """Vuruş anında yaratığın öne atılması (0..1..0)."""
    k = (t - th + 0.12) / 0.24
    if k < 0 or k > 1:
        return 0.0
    return math.sin(math.pi * k)


# ---------------------------------------------------------------- CAN
CAN_S = Scene('can', 'Can  (F: tüm takıma %8 can + %15 kalkan, 3 sn hasar görmez)', (166, 286, 268, 152), 0.35, 4.25, 0.98,
              (176, 296, 250, 130))
CAN_ACT = [('caster', 'sovalye', 300, 388, 0, 0.0), ('a1', 'korsan', 230, 360, 2, 0.3), ('a2', 'oakley', 370, 356, 1, 0.6)]
CAN_INV = 3.0


def can_actors(S, t):
    return [char_actor(S, aid, k, x, y, 'idle', row, int(t * 5 + ph * 4)) for (aid, k, x, y, row, ph) in CAN_ACT]


def can_0(S, Ly, t, actors):
    tt = t - S.T0
    if tt < 0 or tt >= CAN_INV + 0.4:
        return
    fade = clamp01((CAN_INV + 0.4 - tt) / 0.4)
    op = clamp01(tt / 0.25) * fade
    for i, a in enumerate(actors):
        ox, oy = S.cv(a['x'], a['y'] - 15)
        bx, by = ox, oy - 4
        for tex, spin in zip(CAN_TEX, CAN_SPIN):
            blit_c(Ly['F2'], rot_scale(tex, tt * spin, op), bx, by, op)
        if tt < 0.7:
            pk = tt / 0.7
            bright_ring(Ly['F2'], bx, by, 8 + pk * 110, (140, 255, 166), 1 - pk)
            bright_ring(Ly['F2'], bx, by, 4 + pk * 74, (255, 235, 128), 0.9 * (1 - pk), (3, 3), tt * 24)
        for j in range(14):
            ang, r = rnd(i * 31 + j, 1) * TAU, 8 + 20 * rnd(i * 31 + j, 2)
            p0 = (bx + math.cos(ang) * r, by + math.sin(ang) * r * 0.8)
            v = ((rnd(i * 31 + j, 3) - 0.5) * 10, -22 - 22 * rnd(i * 31 + j, 4))
            age = tt - rnd(i * 31 + j, 5) * 0.6
            life = 0.9 + 0.5 * rnd(i * 31 + j, 6)
            if age < 0 or age >= life:
                continue
            k2 = age / life
            col = (255, 115, 153) if j % 2 == 0 else (140, 255, 166)
            c = (p0[0] + v[0] * age, p0[1] + v[1] * age)
            Ly['F2'].pm(m_glyph([".#.", "###", ".#."], c[0], c[1]), col, 1 - k2)


def can_A(S, Ly, t, actors):
    G, B, F = Ly['G'], Ly['B'], Ly['F']
    for i, a in enumerate(actors):
        tt = t - S.T0 - 0.08 * i
        if tt < 0:
            continue
        x, fy = a['x'], a['y']
        ## ışık sütunu
        if tt < 0.75:
            if tt < 0.18:
                bot, wk = lerp(S.Y0 - 6, fy - 1, ease_in(tt / 0.18)), 1.0
            else:
                bot = fy - 1
                wk = 1.0 if tt < 0.42 else 1 - ease_io((tt - 0.42) / 0.33)
            top = S.Y0 - 4
            for hw, col, al, lay in ((9.0, HEAL[3], 0.20, B), (5.5, GOLD[3], 0.40, B), (2.5, CREAM, 0.80, B),
                                     (9.0, GOLD[4], 0.12, F), (2.5, CREAM, 0.30 if 0.16 < tt < 0.40 else 0.0, F)):
                w = hw * wk
                if w < 0.5 or al <= 0:
                    continue
                for (y_a, y_b, f) in ((top, top + 22, 0.34), (top + 22, top + 44, 0.67), (top + 44, bot, 1.0)):
                    if y_b <= y_a:
                        continue
                    lay.pm(m_poly([(x - w, y_a), (x + w, y_a), (x + w, y_b), (x - w, y_b)]), col, al * f)
                lay.pm(m_ell(x, bot, w, max(1.0, w * 0.45)), col, al)
        ## yere iniş: ışık havuzu + iki halka
        if 0.18 <= tt < 0.9:
            k = (tt - 0.18) / 0.72
            glow(G, x, fy, 14, 5.5, GOLD[2], CREAM, band(0.6 * (1 - k), 4), 3)
            for j, dl in enumerate((0.0, 0.12)):
                kk = (tt - 0.18 - dl) / 0.5
                if 0 <= kk < 1:
                    rx = 5 + 21 * ease_out(kk)
                    G.pm(m_ring(x, fy, rx, rx * 0.42), HEAL[3] if j else GOLD[3], band(0.9 * (1 - kk), 4))
        ## 3 sn dokunulmazlık kabuğu
        if 0.25 <= tt < CAN_INV + 0.4:
            so = ease_out((tt - 0.25) / 0.2) * clamp01((CAN_INV + 0.4 - tt) / 0.4)
            br = 0.6 * math.sin(TAU * 0.8 * tt)
            rx, ry, cy = (11 + br) * so, (18 + br) * so, fy - 16
            shell(F, x, cy, rx, ry, GOLD[4], band(0.32 * so, 4), 3, 3.0)
            x0, y0, m = m_ell(x, cy, rx, ry)
            rim = m & ~ero(m)
            ys = np.arange(m.shape[0])[:, None] + y0 + 0.5
            F.put(x0, y0, rim & (ys < cy - ry * 0.35), CREAM, band(0.8 * so, 4))
            F.put(x0, y0, rim & (ys >= cy - ry * 0.35), GOLD[3], band(0.4 * so, 4))
        ## yükselen pırıltılar
        for j in range(3):
            ph = (tt - 0.35 + j * 0.42) / 1.25
            if ph < 0 or tt > CAN_INV + 0.1:
                continue
            q = ph % 1.0
            cyc = int(ph)
            mx = x + (rnd(i * 17 + j * 5 + cyc, 1) - 0.5) * 20
            my = fy - 8 - q * 28
            kk = int(round(2 * math.sin(math.pi * q)))
            sparkle(F, mx, my, kk, CREAM, HEAL[3] if (j + cyc) % 2 else GOLD[3], 0.9)


def can_B(S, Ly, t, actors):
    G, B, F = Ly['G'], Ly['B'], Ly['F']
    for i, a in enumerate(actors):
        tt = t - S.T0 - 0.08 * i
        if tt < 0:
            continue
        x, fy = a['x'], a['y']
        ## yerde mühür (çizilerek açılır)
        if tt < 1.3:
            sw = clamp01(tt / 0.25) * TAU
            al = 1.0 if tt < 0.9 else band(1 - (tt - 0.9) / 0.4, 4)
            a0 = -math.pi / 2
            if sw > 0.05:
                G.pm(m_arc(x, fy, 16, 7, a0, a0 + sw), GOLD[3], 0.9 * al)
                G.pm(m_arc(x, fy, 12, 5, a0, a0 + sw), GOLD[2], 0.7 * al)
            for k in range(6):
                if k / 6 * TAU > sw:
                    continue
                an = a0 + k * TAU / 6 + tt * 0.6
                G.pm(m_glyph(RUNES[k % len(RUNES)], x + 14.2 * math.cos(an), fy + 6.0 * math.sin(an)), CREAM, 0.9 * al)
        ## yükselen tarama halkası
        ly = None
        if 0.25 <= tt < 0.65:
            k = (tt - 0.25) / 0.4
            ly = fy - 38 * ease_io(k)
            rx, ry = 14 - 3 * k, 6 - 1.6 * k
            for lay, up in ((B, True), (F, False)):
                lay.pm(m_half(m_ring(x, ly, rx, ry), ly, up), CREAM, 0.95)
                lay.pm(m_half(m_ring(x, ly + 2, rx, ry), ly + 2, up), GOLD[3], 0.4)
        ## altın kontur (dokunulmazlık), halkanın geçtiği yerden aşağısı görünür
        if 0.25 <= tt < CAN_INV + 0.35:
            pa = band(0.8 + 0.2 * math.sin(TAU * tt / 1.0), 4) * clamp01((CAN_INV + 0.35 - tt) / 0.35)
            rows_from = None
            if ly is not None:
                rows_from = 40 - (fy - ly) / CHAR_S
            a['over'].append((sil_img(a['art'], GOLD[3], pa, 'outline', rows_from), a['px'], a['py']))
        ## "+" işaretleri
        if 0.6 <= tt < 1.45:
            k = (tt - 0.6) / 0.85
            for s in (-1, 1):
                mk = m_glyph(PLUS, x + s * 8, fy - 34 - 10 * ease_out(k) + (3 if s > 0 else 0))
                cel(F, mk, HEAL, band(1 - k ** 2, 4))


def can_C(S, Ly, t, actors):
    G, B, F = Ly['G'], Ly['B'], Ly['F']
    tt = t - S.T0
    if tt < 0:
        return
    c = actors[0]
    sx, sy = c['x'], c['y'] - 34
    ## kasterde krem parlama
    if tt < 0.16:
        sparkle(F, sx, sy, 4 - int(tt / 0.05), CREAM, GOLD[3], 1.0)
    for i, a in enumerate(actors):
        x, fy = a['x'], a['y']
        tgt = (x, fy - 20)
        if i == 0:
            p0, p1, p2 = (sx, sy), (sx + 22, sy - 34), tgt
        else:
            p0, p2 = (sx, sy), tgt
            p1 = ((p0[0] + p2[0]) / 2, min(p0[1], p2[1]) - 40)
        t_l, fl = 0.12, 0.40 + 0.04 * i
        u = (tt - t_l) / fl
        ## kuyruklu yıldız
        if 0 <= u < 1:
            pts, rad = [], []
            for j, r in enumerate((2.6, 2.2, 1.8, 1.4, 1.0, 0.7)):
                uu = u - j * 0.055
                if uu < 0:
                    break
                pts.append(quad(p0, p1, p2, ease_io(uu)))
                rad.append(r)
            mk = m_stroke(pts, rad)
            cel(F, mk, HEAL, 1.0)
            hx, hy = pts[0]
            F.pm(m_ell(hx - 0.5, hy - 0.5, 1.2, 1.2), CREAM, 1.0)
        ta = t_l + fl
        tb = tt - ta
        if tb < 0:
            continue
        ## varış patlaması: krem parlama + 6 yaprak
        if tb < 0.08:
            glow(F, tgt[0], tgt[1], 5, 5, CREAM, CREAM, 0.6, 2)
        if tb < 0.45:
            k = tb / 0.45
            for j in range(6):
                th = j * TAU / 6 + 0.26
                dd = 4 + 10 * ease_out(k)
                lx, ly = tgt[0] + dd * math.cos(th), tgt[1] + dd * math.sin(th) * 0.8 + 4 * k * k
                L2 = 1.9 * (1 - 0.5 * k)
                ca, sa = math.cos(th), math.sin(th)
                pts = [(lx + ca * L2, ly + sa * L2), (lx - sa * 1.0, ly + ca * 1.0), (lx - ca * L2, ly - sa * L2), (lx + sa * 1.0, ly - ca * 1.0)]
                cel(F, m_poly(pts), GOLD if j % 2 else HEAL, band(1 if k < 0.6 else 1 - (k - 0.6) / 0.4, 4))
        ## hale (3 sn)
        t_end = CAN_INV - ta
        if 0.05 <= tb < t_end + 0.22:
            s = overshoot((tb - 0.05) / 0.16) if tb < t_end else 1 - (tb - t_end) / 0.22
            if s > 0.05:
                bob = round(math.sin(TAU * tb / 1.2))
                hy = fy - 36 + bob
                outer = m_ell(x, hy, 7.5 * s, 2.8 * s)
                inner = m_ell(x, hy, 5.0 * s, 1.2 * s)
                cel(F, m_and_not(outer, inner), GOLD, 1.0, False, True)
            if t_end - 0.02 <= tb < t_end + 0.25:
                sparkle(F, x, fy - 36, 2 if tb < t_end + 0.12 else 1, CREAM, GOLD[3], 1.0)


# ---------------------------------------------------------------- ADC
ADC_S = Scene('adc', 'Adc  (F: 10 sn saldırı hızı + kalkan delme + can emme)', (226, 314, 148, 100), 0.35, 3.85, 2.05,
              (191, 304, 218, 120))


def adc_actors(S, t):
    return [char_actor(S, 'caster', 'korsan', 300, 394, 'idle', 0, int(t * 5))]


def adc_0(S, Ly, t, actors):
    tt = t - S.T0
    if tt < 0:
        return
    a = actors[0]
    ox, oy = S.cv(a['x'], a['y'] - 15)
    op = clamp01(tt / 0.2)
    B2 = Ly['B2']
    B2.blit(ADC_GROUND, ox - 48, oy + 26 - 82, op)
    B2.blit(ADC_FLAMES[int(tt * 21.0) % 12], ox - 48, oy + 26 - 82, op)
    blit_c(B2, rot_scale(ADC_DIAM, tt * 5.0), ox, oy - 4, op)
    bx, by = ox, oy - 4
    if tt < 0.6:
        pk = tt / 0.6
        bright_ring(B2, bx, by, 8 + pk * 92, (255, int(255 * (0.35 + 0.4 * pk)), 30), 1 - pk)
        for k in range(10):
            an = k * TAU / 10 + 0.1
            r0 = 18 + pk * 42
            B2.pm(m_line((bx + math.cos(an) * r0, by + math.sin(an) * r0), (bx + math.cos(an) * (r0 + 18 * (1 - pk)), by + math.sin(an) * (r0 + 18 * (1 - pk)))),
                  (255, 153, 51), 1 - pk)
    n = int(tt / 0.04)
    for i in range(max(0, n - 25), n + 1):
        age = tt - i * 0.04
        life = 0.5 + 0.35 * rnd(i, 4)
        if age < 0 or age >= life:
            continue
        k2 = age / life
        px = bx + (rnd(i, 1) - 0.5) * 36 + (rnd(i, 2) - 0.5) * 16 * age
        py = by + 8 + 20 * rnd(i, 3) - (30 + 34 * rnd(i, 5)) * age
        B2.put(int(px), int(py), np.ones((1, 1), bool), (255, int(255 * (0.75 - 0.5 * k2)), 51), (1 - k2) * op)


def adc_A(S, Ly, t, actors):
    G, B, F = Ly['G'], Ly['B'], Ly['F']
    tt = t - S.T0
    if tt < 0:
        return
    a = actors[0]
    x, fy = a['x'], a['y']
    ## açılış: yerden yükselen tek büyük alev dili + yer halkası
    if tt < 0.42:
        hk = ease_out(tt / 0.18) if tt < 0.18 else 1 - ease_in((tt - 0.18) / 0.24)
        h = 46 * hk
        if h > 2:
            for wf, hf, col, al in ((1.0, 1.0, FIRE[2], 0.38), (0.62, 0.8, FIRE[3], 0.6), (0.3, 0.55, FIRE[4], 0.85)):
                B.pm(m_poly(tongue(x, fy - 1, 10 * wf, h * hf, 0.0)), col, al)
        kk = tt / 0.42
        rx = 6 + 22 * ease_out(kk)
        G.pm(m_ring(x, fy, rx, rx * 0.42), FIRE[3], band(0.9 * (1 - kk), 4))
    ## sürekli: omuzların ardından yükselen 3 ruh alevi
    gk = ease_out((tt - 0.15) / 0.3)
    if gk > 0:
        for (bxo, hh, hw, ph) in ((-9, 22, 4.4, 0.0), (0, 32, 5.6, 1.7), (9, 22, 4.4, 3.1)):
            sway = 2.6 * math.sin(TAU * 0.7 * t + ph)
            h = hh * gk * (1 + 0.1 * math.sin(TAU * 1.3 * t + ph * 2))
            for wf, hf, col, al in ((1.0, 1.0, FIRE[2], 0.36), (0.62, 0.8, FIRE[3], 0.58), (0.3, 0.55, FIRE[4], 0.85)):
                B.pm(m_poly(tongue(x + bxo, fy - 11, hw * wf, h * hf, sway * hf)), col, al)
        glow(G, x, fy, 15 + 0.6 * math.sin(TAU * 0.9 * t), 6, FIRE[2], FIRE[4], 0.4 * gk, 3)
    ## kor kıvılcımları (kısa çizgi, az)
    for i in range(int(tt / 0.2) + 1):
        age = tt - 0.2 - i * 0.2
        if age < 0 or age >= 0.7:
            continue
        px = x + (rnd(i, 1) - 0.5) * 20 + (rnd(i, 2) - 0.5) * 6 * age
        py = fy - 8 - 14 * rnd(i, 3) - 24 * age
        al = band(1 - age / 0.7, 3)
        F.put(int(px), int(py), np.ones((1, 1), bool), FIRE[4], al)
        F.put(int(px), int(py) + 1, np.ones((1, 1), bool), FIRE[3], al * 0.7)


def adc_B(S, Ly, t, actors):
    G, B, F = Ly['G'], Ly['B'], Ly['F']
    tt = t - S.T0
    if tt < 0:
        return
    a = actors[0]
    x, fy = a['x'], a['y']
    sw = clamp01(tt / 0.25) * TAU
    a0 = -math.pi / 2
    if sw > 0.05:
        glow(G, x, fy, 18, 7.5, FIRE[2], FIRE[3], 0.2 * clamp01(tt / 0.25), 2)
        G.pm(m_arc(x, fy, 18, 7.5, a0, a0 + sw), FIRE[3], 1.0)
        G.pm(m_arc(x, fy, 13.5, 5.6, a0, a0 + sw), FIRE[2], 0.75)
        for k in range(3):
            if k / 3 * TAU > sw:
                continue
            an = a0 + k * TAU / 3 + tt * 1.1
            G.pm(m_glyph(DIAM, x + 15.8 * math.cos(an), fy + 6.6 * math.sin(an)), CREAM, 1.0)
    if tt < 0.32:
        kk = tt / 0.32
        rx = 8 + 16 * ease_out(kk)
        G.pm(m_ring(x, fy, rx, rx * 0.43), FIRE[4], band(1 - kk, 4))
    ## yanlardan yükselen çift ok başı (hız ritmi)
    n = int(tt / 0.42)
    for i in range(max(0, n - 3), n + 1):
        age = tt - 0.15 - i * 0.42
        if age < 0 or age >= 0.75:
            continue
        k = age / 0.75
        s = -1 if i % 2 == 0 else 1
        cx, cy = x + s * 13, fy - 5 - 28 * ease_out(k)
        al = band(1 - k ** 1.5, 4)
        F.pm(m_glyph(["..#..", ".#.#.", "#...#"], cx, cy + 1), FIRE[2], al * 0.8)
        F.pm(m_glyph(["..#..", ".#.#.", "#...#"], cx, cy), CREAM, al)
        F.pm(m_glyph(["..#..", ".#.#.", "#...#"], cx, cy + 3), FIRE[3], al * 0.7)


def adc_C(S, Ly, t, actors):
    G, B, F = Ly['G'], Ly['B'], Ly['F']
    tt = t - S.T0
    if tt < 0:
        return
    a = actors[0]
    x, fy = a['x'], a['y']
    tq = math.floor(t * 9) / 9
    if tt < 0.12:
        glow(G, x, fy, 15, 6, CREAM, CREAM, 0.8, 2)
    n = 7
    items = []
    for k in range(n):
        th = k * TAU / n + 0.2
        bx, by = x + 13 * math.cos(th), fy - 1 + 5 * math.sin(th)
        grow = overshoot((tt - 0.03 * k) / 0.2)
        if grow <= 0.02:
            continue
        front = math.sin(th) > 0
        h = (6.0 if front else 8.5) + 1.6 * math.sin(tq * 7.3 + k * 2.1) + 1.0 * math.sin(tq * 11.1 + k)
        h *= grow
        sway = 1.6 * math.sin(tq * 6.1 + k * 1.3)
        items.append((by, front, bx, by, h, sway))
    for (_, front, bx, by, h, sway) in sorted(items):
        lay = F if front else B
        outer = m_poly(tongue(bx, by, 2.6, h, sway))
        cel(lay, outer, FIRE, 1.0, True, True)
        lay.pm(m_poly(tongue(bx, by, 1.5, h * 0.62, sway * 0.6)), FIRE[3], 1.0)
        lay.pm(m_poly(tongue(bx, by, 0.7, h * 0.32, sway * 0.3)), FIRE[4], 1.0)
    ## çizgi kıvılcımlar
    for i in range(int(tt / 0.16) + 1):
        age = tt - 0.15 - i * 0.16
        if age < 0 or age >= 0.45:
            continue
        th = rnd(i, 1) * TAU
        px = x + 13 * math.cos(th) + 8 * math.cos(th) * age
        py = fy - 7 + 5 * math.sin(th) - 40 * age
        al = 1.0 if age < 0.3 else 0.5
        F.pm(m_line((px, py), (px - 1.5 * math.cos(th) * 0.6, py + 2.5)), FIRE[2], al)
        F.put(int(px), int(py), np.ones((1, 1), bool), FIRE[4], al)


# ---------------------------------------------------------------- TANK
TANK_S = Scene('tank', 'Tank  (F: 10 sn alınan hasarın %200\'ü saldırana yansır + kalkan yenilenir)', (222, 316, 158, 108), 0.35, 3.65,
               1.31, (191, 304, 218, 120))
TANK_HITS = [(1.25, 's1'), (2.05, 's2'), (2.85, 's1')]
TANK_SL = {'s1': (262, 396, 3, 1), 's2': (340, 386, 2, -1)}


def tank_actors(S, t):
    acts = [char_actor(S, 'caster', 'sovalye', 300, 394, 'idle', 0, int(t * 5))]
    for sid, (sx, sy, row, d) in TANK_SL.items():
        lx = sum(lunge(t, th) for (th, s) in TANK_HITS if s == sid)
        hurt = None
        for (th, s) in TANK_HITS:
            if s == sid and 0 <= t - th - 0.06 < 0.36:
                hurt = t - th - 0.06
        acts.append(slime_actor(S, sid, sx + d * 6 * lx, sy, row, t, hurt))
    return acts


def tank_hits(t):
    for (th, sid) in TANK_HITS:
        if 0 <= t - th < 0.45:
            sx, sy, _, _ = TANK_SL[sid]
            yield t - th, (sx, sy - 7)


def tank_0(S, Ly, t, actors):
    tt = t - S.T0
    if tt < 0:
        return
    a = actors[0]
    ox, oy = S.cv(a['x'], a['y'] - 15)
    bx, by = ox, oy - 4
    op = clamp01(tt / 0.25)
    pulse = max([0.0] + [0.25 - k for (k, _) in tank_hits(t) if k < 0.25])
    bright = 1.0 + (pulse / 0.25) * 0.8
    F2 = Ly['F2']
    rot = tt * 0.35
    blit_c(F2, rot_scale(TANK_OUT, rot, op), bx, by, op, bright)
    blit_c(F2, rot_scale(TANK_IN, -rot * 0.8, op), bx, by, op)
    if tt < 0.55:
        pk = tt / 0.55
        bright_ring(F2, bx, by, 8 + pk * 84, (204, 235, 255), 1 - pk)
        bright_ring(F2, bx, by, 4 + pk * 56, (255, 217, 102), 0.8 * (1 - pk), (3, 3), tt * 20)
        for k in range(6):
            an = k * TAU / 6 + 0.3
            r1 = 70 * (1 - pk) + 14
            F2.pm(m_line((bx + math.cos(an) * r1, by + math.sin(an) * r1), (bx + math.cos(an) * (r1 + 14), by + math.sin(an) * (r1 + 14))),
                  (191, 230, 255), 1 - pk)
    pts = [(bx + math.cos(rot + k * TAU / 6) * 36 * op, by + math.sin(rot + k * TAU / 6) * 36 * 0.92 * op) for k in range(6)]
    sweep = (tt * 0.9 % 1.0) * 6
    e = int(sweep) % 6
    f = sweep - math.floor(sweep)
    for df, col, al in ((0.0, (255, 255, 255), 1.0), (0.08, (217, 242, 255), 0.7), (0.16, (191, 230, 255), 0.4)):
        ff = clamp01(f - df)
        p = (lerp(pts[e][0], pts[(e + 1) % 6][0], ff), lerp(pts[e][1], pts[(e + 1) % 6][1], ff))
        F2.put(int(p[0]), int(p[1]), np.ones((1, 1), bool), col, al * op)


def tank_A(S, Ly, t, actors):
    G, B, F = Ly['G'], Ly['B'], Ly['F']
    tt = t - S.T0
    if tt < 0:
        return
    a = actors[0]
    x, fy = a['x'], a['y']
    cy = fy - 15
    s = overshoot(tt / 0.25, 1.2)
    br = 0.5 * math.sin(TAU * 0.6 * t)
    rx, ry = (16 + br) * s, (19 + br) * s
    flash = max([0.0] + [1 - k / 0.3 for (k, _) in tank_hits(t) if k < 0.3])
    shell(F, x, cy, rx, ry, STEEL[3], band(0.3 + 0.18 * flash, 4), 3, 3.0)
    x0, y0, m = m_ell(x, cy, rx, ry)
    rim = m & ~ero(m)
    ys = np.arange(m.shape[0])[:, None] + y0 + 0.5
    F.put(x0, y0, rim & (ys < cy - ry * 0.3), STEEL[4], 0.8)
    F.put(x0, y0, rim & (ys >= cy - ry * 0.3), STEEL[3], 0.5)
    F.pm(m_arc(x, cy, rx - 2.5, ry - 2.5, math.radians(200), math.radians(240)), CREAM, 0.85)
    if tt < 0.4:
        kk = tt / 0.4
        r = 8 + 26 * ease_out(kk)
        F.pm(m_ring(x, cy, r, r * 1.1), STEEL[3], band(1 - kk, 4))
    for (k, (sx, sy)) in tank_hits(t):
        phi = math.atan2((sy - cy) / ry, (sx - x) / rx)
        if k < 0.3:
            F.pm(m_arc(x, cy, rx, ry, phi - 0.6, phi + 0.6, 2), CREAM, band(1 - k / 0.3, 4))
        px, py = x + rx * math.cos(phi), cy + ry * math.sin(phi)
        k2 = k / 0.14
        if k2 < 1:
            hx, hy = lerp(px, sx, ease_out(k2)), lerp(py, sy, ease_out(k2))
            dx, dy = sx - px, sy - py
            dl = math.hypot(dx, dy) or 1
            ux, uy = dx / dl, dy / dl
            for j, (col, al) in enumerate(((STEEL[4], 0.9), (STEEL[3], 0.6), (STEEL[3], 0.3))):
                F.pm(m_line((hx - ux * (2 + 2 * j), hy - uy * (2 + 2 * j)), (hx - ux * (4 + 2 * j), hy - uy * (4 + 2 * j))), col, al)
            F.pm(m_ell(hx, hy, 1.2, 1.2), CREAM, 1.0)
        elif k < 0.34:
            kk = (k - 0.14) / 0.2
            sparkle(F, sx, sy, 3 - int(kk * 3), CREAM, STEEL[3], 1.0)
            r = 3 + 6 * kk
            F.pm(m_ring(sx, sy, r, r * 0.7), STEEL[4], band(1 - kk, 4))


def tank_B(S, Ly, t, actors):
    G, B, F = Ly['G'], Ly['B'], Ly['F']
    tt = t - S.T0
    if tt < 0:
        return
    a = actors[0]
    x, fy = a['x'], a['y']
    rot = tt * 0.3
    V = [(x + 18 * math.cos(rot + k * TAU / 6), fy + 8 * math.sin(rot + k * TAU / 6), math.sin(rot + k * TAU / 6)) for k in range(6)]
    draw_k = clamp01(tt / 0.3) * 6
    for k in range(6):
        if k >= draw_k:
            break
        p, q = V[k], V[(k + 1) % 6]
        f = clamp01(draw_k - k)
        G.pm(m_line(p[:2], (lerp(p[0], q[0], f), lerp(p[1], q[1], f))), STEEL[3], 0.85)
    hits = list(tank_hits(t))
    for k, (vx, vy, sn) in enumerate(V):
        if k >= draw_k:
            continue
        lay = B if sn < 0 else F
        gk = ease_out((tt - 0.2) / 0.3)
        hflash = 0.0
        for (hk, (sx, sy)) in hits:
            j = min(range(6), key=lambda q: (V[q][0] - sx) ** 2 + (V[q][1] - sy) ** 2)
            if j == k and hk < 0.3:
                hflash = 1 - hk / 0.3
        if gk > 0:
            H = 30 * gk
            for (y_a, y_b, al) in ((vy - H / 3, vy, 0.55), (vy - 2 * H / 3, vy - H / 3, 0.32), (vy - H, vy - 2 * H / 3, 0.14)):
                if y_b - y_a >= 1:
                    lay.pm(m_line((vx, y_a), (vx, y_b)), CREAM if hflash > 0.3 else STEEL[3],
                           band(max(al * (0.85 if sn >= 0 else 1.0), hflash * 0.9), 4))
        sparkle(G, vx, vy, 2 if hflash > 0.4 else 1, GOLD[4] if hflash <= 0.4 else CREAM, GOLD[2], 1.0)
    for (hk, (sx, sy)) in hits:
        j = min(range(6), key=lambda q: (V[q][0] - sx) ** 2 + (V[q][1] - sy) ** 2)
        vx, vy = V[j][0], V[j][1] - 4
        if hk < 0.18:
            f = hk / 0.18
            F.pm(m_line((lerp(vx, sx, f), lerp(vy, sy, f)), (sx, sy)), GOLD[4], 1.0)
            F.pm(m_line((lerp(vx, sx, f), lerp(vy, sy, f) + 1), (sx, sy + 1)), GOLD[2], 0.6)
        if 0.04 < hk < 0.3:
            sparkle(F, sx, sy, 3 - int((hk - 0.04) / 0.09), CREAM, GOLD[3], 1.0)


def tank_C(S, Ly, t, actors):
    G, B, F = Ly['G'], Ly['B'], Ly['F']
    tt = t - S.T0
    if tt < 0:
        return
    a = actors[0]
    x, fy = a['x'], a['y']
    hits = list(tank_hits(t))
    items = []
    for k in range(8):
        th = k * TAU / 8 + math.pi / 8
        bx, by = x + 14 * math.cos(th), fy - 1 + 6 * math.sin(th)
        g = overshoot((tt - 0.035 * k) / 0.15)
        if g <= 0.02:
            continue
        h = 8 + round(math.sin(TAU * 0.6 * t + k))
        lean = 3.0
        for (hk, (sx, sy)) in hits:
            da = math.atan2(sy - fy, sx - x)
            diff = abs((th - da + math.pi) % TAU - math.pi)
            if diff < math.radians(55):
                p = (hk / 0.06) if hk < 0.06 else max(0.0, 1 - (hk - 0.06) / 0.25)
                h += 7 * p
                lean += 4 * p
        items.append((by, k, th, bx, by, h * g, lean, math.sin(th) >= 0))
        if 0 <= tt - 0.035 * k < 0.1:
            sparkle(F if math.sin(th) >= 0 else B, bx, by - 1, 2, CREAM, STEEL[3], 1.0)
    for (_, k, th, bx, by, h, lean, front) in sorted(items):
        lay = F if front else B
        ax, ay = bx + lean * math.cos(th), by - h + 1.5 * math.sin(th)
        tri = [(bx - 2.4, by + 0.5), (bx + 2.4, by + 0.5), (ax, ay)]
        x0, y0, m = m_poly(tri)
        cel(lay, (x0, y0, m), STEEL, 1.0)
        X = np.arange(m.shape[1])[None, :] + x0 + 0.5
        Y = np.arange(m.shape[0])[:, None] + y0 + 0.5
        cxl = bx + (ax - bx) * (by - Y) / max(1e-3, by - ay)
        lay.put(x0, y0, m & (X < cxl) & ~(m & ~shift(m, 1, 1)), STEEL[3], 1.0)
        lay.put(int(math.floor(ax)), int(math.floor(ay)), np.ones((1, 1), bool), CREAM, 1.0)
    for (hk, (sx, sy)) in hits:
        if 0.03 < hk < 0.3:
            sparkle(F, sx, sy, 3 - int((hk - 0.03) / 0.09), CREAM, STEEL[3], 1.0)


# ---------------------------------------------------------------- TAKTİKSEL
TAK_S = Scene('taktik', 'Taktiksel  (F: 230 birim ileri ışınlan + 3 sn %30 hız)', (122, 330, 336, 88), 0.35, 3.7, 0.43,
              (156, 314, 250, 120))
TAK_A, TAK_B = (165.0, 390.0), (395.0, 390.0)
TAK_V = 82.0 * 1.3


def tak_state(t):
    """(x, y, clip, row, col, hareket)"""
    T0 = TAK_S.T0
    if t < T0:
        return TAK_A[0], TAK_A[1], 'idle', 2, int(t * 5), 0.0
    if t < T0 + 0.15:
        return TAK_B[0], TAK_B[1], 'idle', 2, int(t * 5), 0.0
    x = TAK_B[0] - TAK_V * (t - T0 - 0.15)
    if x > 185:
        return x, TAK_B[1], 'run', 1, int(t * 12), -1.0
    return 185.0, TAK_B[1], 'idle', 1, int(t * 5), 0.0


def tak_actors(S, t):
    x, y, clip, row, col, _ = tak_state(t)
    return [char_actor(S, 'caster', 'elara', x, y, clip, row, col)]


def tak_0(S, Ly, t, actors):
    tt = t - S.T0
    if tt < 0:
        return
    if tt < 0.45:
        k = tt / 0.45
        fade = 1 - k
        F2 = Ly['F2']
        fx, fy_ = S.cv(TAK_A[0], TAK_A[1] - 15)
        tx, ty = S.cv(TAK_B[0], TAK_B[1] - 15)
        tail = (lerp(fx, tx, clamp01(k * 1.4)), lerp(fy_, ty, clamp01(k * 1.4)))
        if tail[0] < tx - 1:
            F2.pm(m_line(tail, (tx, ty)), (178, 247, 255), fade * 0.9)
            F2.pm(m_line((tail[0], tail[1] + 2.4), (tx, ty + 2.4)), (128, 217, 255), fade * 0.5)
            F2.pm(m_line((tail[0], tail[1] - 2.4), (tx, ty - 2.4)), (128, 217, 255), fade * 0.5)
        for i in range(10):
            f = rnd(i * 13 + 3)
            if f > k * 1.4 - 0.1:
                p = (lerp(fx, tx, f), lerp(fy_, ty, f) + (rnd(i * 7 + 1) - 0.5) * 14)
                F2.put(int(p[0]), int(p[1]), np.ones((1, 1), bool), (255, 255, 255), fade)
        bright_ring(F2, fx, fy_, 4 + k * 30, (153, 230, 255), fade * 0.8, (3, 2), tt * 20)
        bright_ring(F2, tx, ty, 4 + k * 38, (255, 255, 255), fade)
    if tt > 3.0 + 0.35:
        return
    fade = clamp01((3.35 - tt) / 0.35)
    a = actors[0]
    ox, oy = S.cv(a['x'], a['y'] - 15)
    B2 = Ly['B2']
    n = int(tt / 0.03)
    for i in range(max(0, n - 12), n + 1):
        ts = S.T0 + i * 0.03
        if tak_state(ts)[5] == 0 or ts > S.T0 + 3.0:
            continue
        age = t - ts
        life = 0.18 + 0.14 * rnd(i, 1)
        if age < 0 or age >= life:
            continue
        k = age / life
        dirx = -1.0
        off = (-dirx * (4 + 10 * rnd(i, 2)), -4 + (rnd(i, 3) - 0.5) * 32)
        ln = 12 + 16 * rnd(i, 4)
        head = (ox + off[0] + (-dirx) * ln * k * 0.5, oy + off[1])
        tail = (head[0] + (-dirx) * ln * (1 - k * 0.4), head[1])
        B2.pm(m_line(head, tail), (166, 242, 255), (1 - k) * 0.85 * fade)
    for i in range(3):
        si = int(t * 20)
        px = ox + (rnd(si * 3 + i) - 0.5) * 30
        py = oy + 26 - rnd(si * 7 + i + 5) * 6
        B2.put(int(px), int(py), np.ones((1, 1), bool), (204, 255, 255), 0.7 * fade)


def tak_A(S, Ly, t, actors):
    G, B, F = Ly['G'], Ly['B'], Ly['F']
    tt = t - S.T0
    if tt < 0:
        return
    (ax, ay), (bx, by) = TAK_A, TAK_B
    if tt < 0.45:
        art = char_frame('elara', 'idle', 2, 0)[0]
        cx, cy = S.cv(ax, ay)
        Ly['B2'].blit(sil_img(art, WIND[3], 1.0), cx - 24 * S2 + K * 3 * ease_out(tt / 0.45), cy - 40 * S2, band(0.55 * (1 - tt / 0.45), 4))
        art_r = char_frame('elara', 'run', 2, 2)[0]
        for j, (u, a0) in enumerate(((0.25, 0.25), (0.5, 0.35), (0.75, 0.45))):
            al = band(a0 * (1 - clamp01((tt - 0.05 * j) / 0.35)), 4)
            gx, gy = S.cv(lerp(ax, bx, u), ay)
            Ly['B2'].blit(sil_img(art_r, WIND[3], 1.0), gx - 24 * S2, gy - 40 * S2, al)
    if tt < 0.5:
        s_tail = ease_in(tt / 0.3)
        al = 1 - clamp01((tt - 0.15) / 0.3)
        ys = ay - 14
        L_ = bx - ax
        for hwm, col, a0 in ((2.6, WIND[3], 0.24), (1.0, WIND[4], 0.6)):
            pts, rad = [], []
            for i in range(int(L_ / 0.8)):
                s = i * 0.8 / L_
                if s < s_tail:
                    continue
                pts.append((ax + s * L_, ys))
                rad.append(max(0.5, hwm * math.sin(math.pi * s) ** 0.5))
            if len(pts) > 1:
                F.pm(m_stroke(pts, rad), col, band(a0 * al, 4))
    if tt < 0.35:
        kk = tt / 0.35
        rx = 4 + 16 * ease_out(kk)
        G.pm(m_ring(bx, by, rx, rx * 0.42), WIND[3], band(0.85 * (1 - kk), 4))
    if tt < 0.16:
        a = actors[0]
        a['over'].append((sil_img(a['art'], CREAM, 1.0), a['px'], a['py'], band(0.65 * (1 - tt / 0.16), 3)))
    if tt <= 3.3:
        n = int(tt / 0.1)
        for i in range(max(0, n - 4), n + 1):
            td = S.T0 + 0.15 + i * 0.1
            if td > t or td > S.T0 + 3.0:
                continue
            x, y, clip, row, col, mv = tak_state(td)
            if mv == 0:
                continue
            age = t - td
            if age >= 0.3:
                continue
            art = char_frame('elara', clip, row, col)[0]
            gx, gy = S.cv(x, y)
            Ly['B2'].blit(sil_img(art, WIND[3], 1.0), gx - 24 * S2, gy - 40 * S2, band(0.42 * (1 - age / 0.3), 3))


def tak_B(S, Ly, t, actors):
    G, B, F = Ly['G'], Ly['B'], Ly['F']
    tt = t - S.T0
    if tt < 0:
        return
    if tt < 0.5:
        k = tt / 0.5
        s = ease_out(k / 0.2)
        if k > 0.6:
            s *= 1 - ease_in((k - 0.6) / 0.4)
        sq = 1 + 0.35 * (1 - s) * (k > 0.6)
        for (px, py) in (TAK_A, TAK_B):
            cy = py - 15
            if s > 0.04:
                F.pm(m_ring(px, cy, 8 * sq, 17 * s), WIND[3], 0.9)
                F.pm(m_ring(px, cy, 6 * sq, 14 * s), WIND[2], 0.5)
                F.pm(m_ell(px, cy, 6 * sq, 14 * s), WIND[4], 0.14)
                for j in range(4):
                    an = tt * 2.4 + j * math.pi / 2
                    F.pm(m_glyph(RUNES[j % 5], px + 8 * sq * math.cos(an), cy + 17 * s * math.sin(an)), CREAM, 0.95)
                G.pm(m_ring(px, py, 9, 3.6), WIND[3], band(0.6 * s, 4))
        if tt < 0.15:
            F.pm(m_line((TAK_A[0], TAK_A[1] - 15), (TAK_B[0], TAK_B[1] - 15)), WIND[4], band(0.6 * (1 - tt / 0.15), 3))
    if tt <= 3.5:
        n = int(tt / 0.13)
        for i in range(max(0, n - 5), n + 1):
            td = S.T0 + 0.15 + i * 0.13
            if td > t or td > S.T0 + 3.0:
                continue
            x, y, clip, row, col, mv = tak_state(td)
            if mv == 0:
                continue
            age = t - td
            if age >= 0.45:
                continue
            al = band(0.8 * (1 - age / 0.45), 3)
            G.pm(m_glyph(["..#", ".#.", "#..", ".#.", "..#"], x + 7, y - 1), WIND[3], al)
            G.pm(m_glyph(["..#", ".#.", "#..", ".#.", "..#"], x + 10, y - 1), WIND[2], al * 0.6)


def tak_C(S, Ly, t, actors):
    G, B, F = Ly['G'], Ly['B'], Ly['F']
    tt = t - S.T0
    if tt < 0:
        return
    (ax, ay), (bx, by) = TAK_A, TAK_B
    L_ = bx - ax
    if tt < 0.3:
        s_tail = ease_in(tt / 0.3)
        Le = L_ - 9  ## iz hedefin hemen önünde biter (karakterin üstüne yığılmasın)
        for (yo, s0, s1, hmax) in ((-14, 0.0, 1.0, 1.9), (-21, 0.35, 0.82, 0.45), (-7, 0.42, 0.88, 0.45)):
            pts, rad = [], []
            for i in range(int(Le / 0.7) + 1):
                s = i * 0.7 / Le
                if s < max(s0, s_tail) or s > s1:
                    continue
                u = (s - s0) / (s1 - s0)
                pts.append((ax + s * Le, ay + yo - 4 * math.sin(math.pi * s)))
                rad.append(0.8 + hmax * (math.sin(math.pi * min(1.0, u * 1.15)) ** 0.8) * (1 - 0.6 * s_tail))
            if len(pts) > 2:
                cel(F, m_stroke(pts, rad), WIND, 1.0 if tt < 0.22 else 0.5, True, True)
    if tt < 0.3:
        k = tt / 0.3
        pts, rad = [], []
        n = int(30 * (1 - k)) + 2
        for i in range(n):
            u = i / 30
            an = u * TAU * 1.3
            r = 3 + 6 * u
            pts.append((ax + r * math.cos(an), ay - 15 + r * math.sin(an) * 0.8))
            rad.append(1.3 * (1 - 0.5 * u))
        cel(F, m_stroke(pts, rad), WIND, 1.0, True, True)
    for j, dl in enumerate((0.0, 0.06)):
        k = (tt - dl) / 0.28
        if 0 <= k < 1:
            r = 6 + 10 * ease_out(k) - 4 * j
            pts, rad = [], []
            for i in range(25):
                u = i / 24
                an = math.radians(-60 + 120 * u)
                pts.append((bx - 4 + r * math.cos(an), by - 14 + r * math.sin(an) * 1.2))
                rad.append(max(0.4, (1.6 * (1 - k) + 0.3) * math.sin(math.pi * u) ** 0.6))
            cel(F, m_stroke(pts, rad), WIND, band(1 if k < 0.6 else 1 - (k - 0.6) / 0.4, 4), True, True)
    x, y, clip, row, col, mv = tak_state(t)
    if mv != 0 and tt < 3.0:
        for j in range(2):
            yo = y - 6 - j * 9
            for i in range(16):
                s = i / 15
                px = x + 4 + 16 * s
                py = yo + 1.5 * math.sin(TAU * (s * 1.3 - t * 2.2) + j * 1.7)
                al = band((1 - s) * 0.95, 3)
                F.put(int(px), int(py), np.ones((1, 1), bool), WIND[4], al)
                F.put(int(px), int(py) + 1, np.ones((1, 1), bool), WIND[2], al)


# ---------------------------------------------------------------- KALKAN BAĞI
KB_S = Scene('kalkan', 'Kalkan Bağı  (F: en yakın arkadaşla kalkan bağı; kalkan değişimleri %50 birbirine yansır)', (196, 312, 222, 104),
             0.35, 3.75, 1.75, (196, 304, 222, 120))
KB_C = (242.0, 392.0)
KB_P = (366.0, 380.0)
KB_SL = (402.0, 384.0)
KB_HITS = [1.55, 3.05]
KB_TR = [(1.55, 'p'), (2.35, 'c'), (3.05, 'p')]


def kb_actors(S, t):
    lx = sum(lunge(t, th) for th in KB_HITS)
    hurt = None
    return [char_actor(S, 'caster', 'sovalye', KB_C[0], KB_C[1], 'idle', 2, int(t * 5)),
            char_actor(S, 'partner', 'oakley', KB_P[0], KB_P[1], 'idle', 1, int(t * 5 + 2)),
            slime_actor(S, 's1', KB_SL[0] - 6 * lx, KB_SL[1], 2, t, hurt)]


def kb_transfers(t, dur):
    for (t0, src) in KB_TR:
        if 0 <= t - t0 < dur:
            yield t - t0, src


def kb_0(S, Ly, t, actors):
    tt = t - S.T0
    if tt < 0:
        return
    F2 = Ly['F2']
    oc = S.cv(KB_C[0], KB_C[1] - 15)
    op = S.cv(KB_P[0], KB_P[1] - 15)
    for (o, p) in ((oc, op), (op, oc)):
        dx, dy = p[0] - o[0], p[1] - o[1]
        L_ = math.hypot(dx, dy)
        art_len = int(L_ / TEXEL) + 1
        scroll = int(tt * 5.0) % 8
        w8 = (art_len // 8 + 3) * 8
        strip = Image.new('RGBA', (w8, 3))
        for i in range(0, w8, 8):
            strip.alpha_composite(KB_LINE, (i, 0))
        strip = strip.crop((scroll, 0, scroll + art_len, 3))
        strip = nscale(strip, TEXEL)
        ang = math.atan2(dy, dx)
        im = strip.rotate(-math.degrees(ang), resample=Image.NEAREST, expand=True)
        blit_c(F2, im, (o[0] + p[0]) / 2, (o[1] + p[1]) / 2, 1.0)
        ef = nscale(KB_END[int(tt * 6.0) % 8], TEXEL)
        blit_c(F2, ef, o[0], o[1])
        blit_c(F2, ef, p[0], p[1])
        ph = tt % 1.8
        if ph < 1.1:
            u = ph / 1.1
            sm = u * u * (3 - 2 * u)
            g = nscale(KB_GLINT[min(5, int(u * 6))], TEXEL)
            blit_c(F2, g, o[0] + dx * sm, o[1] + dy * sm)


def kb_curve(p0, p1, sag, t, wave=0.0, n=None):
    L_ = math.hypot(p1[0] - p0[0], p1[1] - p0[1])
    n = n or int(L_ / 0.6)
    nx, ny = -(p1[1] - p0[1]) / L_, (p1[0] - p0[0]) / L_
    out = []
    for i in range(n + 1):
        s = i / n
        w = wave * math.sin(TAU * (s * L_ / 70 - t * 0.6)) * math.sin(math.pi * s)
        out.append((lerp(p0[0], p1[0], s) + nx * w, lerp(p0[1], p1[1], s) + sag * 4 * s * (1 - s) + ny * w, s))
    return out


def kb_A(S, Ly, t, actors):
    G, B, F = Ly['G'], Ly['B'], Ly['F']
    tt = t - S.T0
    if tt < 0:
        return
    p0, p1 = (KB_C[0], KB_C[1] - 16), (KB_P[0], KB_P[1] - 16)
    g = ease_out(tt / 0.25)
    cur = kb_curve(p0, p1, 6, t, 0.9)
    trs = list(kb_transfers(t, 0.42))
    beads = []
    for (k, src) in trs:
        if k < 0.4:
            u = ease_io(k / 0.4)
            beads.append(1 - u if src == 'p' else u)
    for hwm, col, a0 in ((2.6, MANA[3], 0.16), (1.6, MANA[3], 0.32)):
        pts, rad = [], []
        for (px, py, s) in cur:
            if s > g:
                break
            bump = sum(1.4 * math.exp(-((s - b) / 0.05) ** 2) for b in beads)
            pts.append((px, py))
            rad.append(hwm + bump)
        if len(pts) > 1:
            B.pm(m_stroke(pts, rad), col, a0)
    pts = [(px, py) for (px, py, s) in cur if s <= g]
    if len(pts) > 1:
        B.pm(m_polyline(pts), MANA[4], 0.85)
    if g < 1:
        hx, hy = pts[-1]
        glow(F, hx, hy, 4, 4, MANA[3], CREAM, 0.9, 3)
    for b in beads:
        idx = min(len(cur) - 1, int(b * (len(cur) - 1)))
        glow(F, cur[idx][0], cur[idx][1], 4.5, 4.5, MANA[3], CREAM, 0.95, 3)
    br = 0.5 + 0.5 * math.sin(TAU * 0.8 * t)
    for (ex, ey), on in ((p0, True), (p1, g >= 1)):
        if on:
            glow(F, ex, ey, 3.5 + br * 0.6, 3.5 + br * 0.6, MANA[3], CREAM, band(0.55 + 0.15 * br, 4), 3)
    for (k, src) in kb_transfers(t, 0.72):
        k2 = (k - 0.4) / 0.32
        if 0 <= k2 < 1:
            tx, tfy = (KB_C if src == 'p' else KB_P)
            r = 5 + 9 * ease_out(k2)
            F.pm(m_ring(tx, tfy - 16, r, r * 1.25), MANA[4], band(1 - k2, 4))
            shell(F, tx, tfy - 16, 12, 18, MANA[3], band(0.3 * (1 - k2), 4), 3, 3.0)


def kb_B(S, Ly, t, actors):
    G, B, F = Ly['G'], Ly['B'], Ly['F']
    tt = t - S.T0
    if tt < 0:
        return
    (cx, cy), (px, py) = KB_C, KB_P
    flashes = {'c': 0.0, 'p': 0.0}
    for (k, src) in kb_transfers(t, 0.7):
        k2 = (k - 0.35) / 0.35
        if 0 <= k2 < 1:
            dst = 'c' if src == 'p' else 'p'
            flashes[dst] = max(flashes[dst], 1 - k2)
    for (ex, ey, key, t_on) in ((cx, cy, 'c', 0.0), (px, py, 'p', 0.3)):
        sw = clamp01((tt - t_on) / 0.15) * TAU
        if sw <= 0.05:
            continue
        fl = flashes[key]
        G.pm(m_arc(ex, ey, 11, 4.5, -math.pi / 2, -math.pi / 2 + sw), CREAM if fl > 0.4 else MANA[3], 0.85)
        for j in range(4):
            an = -math.pi / 2 + j * TAU / 4 + t * 0.7
            if (j / 4) * TAU <= sw:
                G.pm(m_glyph(DIAM, ex + 11 * math.cos(an), ey + 4.5 * math.sin(an)), CREAM, 0.8)
        if fl > 0:
            r = 11 + 7 * (1 - fl)
            G.pm(m_ring(ex, ey, r, r * 0.41), MANA[4], band(fl, 4))
    dx, dy = px - cx, py - cy
    L_ = math.hypot(dx, dy)
    ux, uy = dx / L_, dy / L_
    nx, ny = -uy, ux
    a_pt = (cx + ux * 12, cy + uy * 12)
    b_pt = (px - ux * 12, py - uy * 12)
    ext = clamp01((tt - 0.15) / 0.18)
    if ext > 0:
        e_pt = (lerp(a_pt[0], b_pt[0], ext), lerp(a_pt[1], b_pt[1], ext))
        G.pm(m_line(a_pt, e_pt), MANA[3], 0.7)
        LL = math.hypot(b_pt[0] - a_pt[0], b_pt[1] - a_pt[1])
        for i in range(int(LL / 14) + 1):
            d = (i * 14 + t * 8) % LL
            if d > LL * ext:
                continue
            gx, gy = a_pt[0] + ux * d, a_pt[1] + uy * d
            G.pm(m_glyph(RUNES[i % 5], gx, gy), MANA[4], band(0.75 * math.sin(math.pi * d / LL) ** 0.3, 4))
    for (k, src) in kb_transfers(t, 0.35):
        u = ease_io(k / 0.35)
        if src == 'p':
            u = 1 - u
        gx, gy = lerp(a_pt[0], b_pt[0], u), lerp(a_pt[1], b_pt[1], u)
        sparkle(G, gx, gy, 2, CREAM, GOLD[3], 1.0)


def kb_C(S, Ly, t, actors):
    G, B, F = Ly['G'], Ly['B'], Ly['F']
    tt = t - S.T0
    if tt < 0:
        return
    p0, p1 = (KB_C[0] + 6, KB_C[1] - 12), (KB_P[0] - 6, KB_P[1] - 12)
    cur = kb_curve(p0, p1, 8, t, 0.0, 400)
    seg = [0.0]
    for i in range(1, len(cur)):
        seg.append(seg[-1] + math.hypot(cur[i][0] - cur[i - 1][0], cur[i][1] - cur[i - 1][1]))
    total = seg[-1]
    nlinks = int(total / 4.5)
    waves = []
    for (k, src) in kb_transfers(t, 0.5):
        u = k / 0.45
        if u <= 1:
            waves.append(1 - u if src == 'p' else u)
    ring_ = [".###.", "#...#", ".###."]
    bar = ["#####"]
    for i in range(nlinks + 1):
        d = i * total / nlinks
        j = min(len(seg) - 1, int(np.searchsorted(seg, d)))
        lx, ly, s = cur[j]
        t_on = 0.3 * s
        if tt < t_on:
            continue
        bob, hot = 0.0, False
        for w in waves:
            if abs(s - w) < 0.07:
                bob = -2 * (1 - abs(s - w) / 0.07)
                hot = True
        pal = MANA
        mk = m_glyph(ring_ if i % 2 == 0 else bar, lx, ly + bob)
        pop = tt - t_on < 0.06
        glint = math.sin(TAU * (i * 0.13 - t * 0.45)) > 0.9
        x0, y0, m = mk
        F.put(x0, y0, dil(m) & ~m, pal[1], 1.0)
        F.put(x0, y0, m, CREAM if (pop or hot) else (pal[4] if glint else pal[3]), 1.0)
        top = m & ~shift(m, 0, 1)
        F.put(x0, y0, top, CREAM, 1.0)
    for (k, src) in kb_transfers(t, 0.8):
        k2 = (k - 0.45) / 0.32
        if 0 <= k2 < 1:
            tx, tfy = (KB_C if src == 'p' else KB_P)
            hy = tfy - 16
            if k2 < 0.22:
                glow(F, tx, hy, 6, 6, CREAM, CREAM, 0.8, 2)
            for j in range(4):
                an = j * TAU / 4 + math.pi / 4
                dd = 5 + 9 * ease_out(k2)
                cel(F, m_glyph(DIAM if k2 < 0.5 else ["#"], tx + dd * math.cos(an), hy + dd * math.sin(an)), MANA, band(1 - k2 ** 2, 4))


# ====================================================================== çizim
SKILLS = {
    'can': (CAN_S, can_actors, {'0': can_0, 'A': can_A, 'B': can_B, 'C': can_C}),
    'adc': (ADC_S, adc_actors, {'0': adc_0, 'A': adc_A, 'B': adc_B, 'C': adc_C}),
    'tank': (TANK_S, tank_actors, {'0': tank_0, 'A': tank_A, 'B': tank_B, 'C': tank_C}),
    'taktik': (TAK_S, tak_actors, {'0': tak_0, 'A': tak_A, 'B': tak_B, 'C': tak_C}),
    'kalkan': (KB_S, kb_actors, {'0': kb_0, 'A': kb_A, 'B': kb_B, 'C': kb_C}),
}


def render(skill, var, t, crop=None):
    S, act_fn, fns = SKILLS[skill]
    X0, Y0, W, H = crop or (S.X0, S.Y0, S.W, S.H)
    ## sahne koordinatları S'nin kırpımına göre; özet kırpımı için geçici olarak kaydır
    oX0, oY0 = S.X0, S.Y0
    S.X0, S.Y0 = X0, Y0
    try:
        bg = nscale(BG.crop((X0, Y0, X0 + W, Y0 + H)), K)
        Ly = {n: Layer(X0, Y0, W, H) for n in ('G', 'B', 'F')}
        Ly.update({n: Layer(0, 0, W * K, H * K) for n in ('G2', 'B2', 'F2')})
        actors = act_fn(S, t)
        fns[var](S, Ly, t, actors)
        img = bg.copy()
        for n in ('G', 'G2', 'B', 'B2'):
            im = Ly[n].img()
            img.alpha_composite(nscale(im, K) if n in ('G', 'B') else im)
        for a in sorted(actors, key=lambda a: a['y']):
            comp(img, a['img'], a['px'], a['py'])
            for ov in a['over']:
                o_img, ox, oy = ov[0], ov[1], ov[2]
                if len(ov) > 3:
                    o_img = faded(o_img, ov[3])
                comp(img, o_img, ox, oy)
        for n in ('F', 'F2'):
            im = Ly[n].img()
            img.alpha_composite(nscale(im, K) if n == 'F' else im)
        return img
    finally:
        S.X0, S.Y0 = oX0, oY0


def label(img, text, sz=16, pad=6, bgc=(24, 26, 30)):
    f = font(sz)
    out = Image.new('RGBA', (img.width, img.height + sz + 2 * pad), bgc + (255,))
    ImageDraw.Draw(out).text((pad, pad - 2), text, font=f, fill=(236, 232, 220))
    out.alpha_composite(img, (0, sz + 2 * pad))
    return out


def compare_frame(skill, t):
    S = SKILLS[skill][0]
    panels = [label(render(skill, v, t), VAR_NAMES[v]) for v in ('0', 'A', 'B', 'C')]
    pw, ph = panels[0].size
    gap = 6
    head = 34
    out = Image.new('RGBA', (2 * pw + gap, head + 2 * ph + gap), (16, 17, 20, 255))
    ImageDraw.Draw(out).text((8, 6), S.title, font=font(18), fill=(255, 226, 150))
    for i, p in enumerate(panels):
        out.alpha_composite(p, ((i % 2) * (pw + gap), head + (i // 2) * (ph + gap)))
    return out


def save_gif(frames, path):
    sample = Image.new('RGB', (frames[0].width, frames[0].height * min(6, len(frames))))
    for i, f in enumerate(frames[::max(1, len(frames) // 6)][:6]):
        sample.paste(f.convert('RGB'), (0, i * frames[0].height))
    pal = sample.quantize(colors=255, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    q = [f.convert('RGB').quantize(palette=pal, dither=Image.Dither.NONE) for f in frames]
    q[0].save(path, save_all=True, append_images=q[1:], duration=int(DT * 1000), loop=0, optimize=True)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    still = '--still' in sys.argv
    os.makedirs(OUT, exist_ok=True)
    keys = args or list(SKILLS)
    if still:
        rows = []
        for k in keys:
            S = SKILLS[k][0]
            ps = [label(render(k, v, S.summary_t, S.summary_crop), f'{S.title.split("  ")[0]}  -  {VAR_NAMES[v]}', 14) for v in ('0', 'A', 'B', 'C')]
            row = Image.new('RGBA', (sum(p.width for p in ps) + 3 * 4, max(p.height for p in ps)), (16, 17, 20, 255))
            x = 0
            for p in ps:
                row.alpha_composite(p, (x, 0))
                x += p.width + 4
            rows.append(row)
        W = max(r.width for r in rows)
        sheet = Image.new('RGBA', (W, sum(r.height for r in rows) + 4 * (len(rows) - 1)), (16, 17, 20, 255))
        y = 0
        for r in rows:
            sheet.alpha_composite(r, (0, y))
            y += r.height + 4
        name = 'ozet.png' if not args else 'ozet_' + '_'.join(keys) + '.png'
        sheet.save(os.path.join(OUT, name))
        print('yazıldı', name, sheet.size)
        return
    for k in keys:
        S = SKILLS[k][0]
        nf = int(round(S.T_END / DT))
        frames = [compare_frame(k, i * DT) for i in range(nf)]
        path = os.path.join(OUT, f'{k}.gif')
        save_gif(frames, path)
        print('yazıldı', path, frames[0].size, nf, 'kare', os.path.getsize(path) // 1024, 'KB')


if __name__ == '__main__':
    main()
