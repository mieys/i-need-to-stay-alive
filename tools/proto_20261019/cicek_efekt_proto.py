"""2026-10-19 prototipi: OAKLEY PASİF ÇİÇEĞİNİN ALTINDAKİ SİHİRLİ EFEKT (kullanıcı: "oakleyin pasifinin çiçeğinin altındaki sihirli efekti
yeniden tasarla 4 prototip oluştur, efekt çiçek büyüyünce büyüyüp gelişsin"). OYUNA BAĞLI DEĞİL, mekanik aynı (oakley_flower.gd: 3 aşama,
5 sn'de bir büyür, her büyümede can/kalkan +%40). Bugünkü efekt = CraftPix Life Recovery (her aşamada AYNI boy, nokta nokta yükselen zerreler).
Her yön AYRI çizim dili (sandık prototipi dersi: "hep aynı kişi çizmiş gibi" olmasın) ve dither/serpiştirilmiş tek piksel YOK
(sandık v3 dersi: "parazit gibi, çok ai"): düz bantlı saydamlık, sürekli 1 px çizgiler, az sayıda biçimli parıltı.
  A Druid Mührü     serin nane yeşili, konturSUZ ince sürekli halkalar; filiz = tek halka, tomurcuk = iç halka + 4 yaprak rünü,
                    açmış = kesikli dış halka (ters döner) + 8 rün sırayla yanar + rünlerden seyrek yükselen parıltı.
  B Işıyan Kökler   toprak dili, koyu konturlu dolu kökler (çiçeğin kendi kontur rengi); filiz = 3 kısa kök, tomurcuk = 5 dallanan kök
                    + uçta tomurcuklar, açmış = 7 kök ağı + uçlardan çiçeğe akan ışık damlaları (besleniyor) + verimli toprak lekesi.
  C Yaprak Halkası  çizgi film dili, çiçeğin sanatıyla aynı kalın konturlu küçük yapraklar 2:1 yörüngede döner (arkadakiler çiçeğin
                    arkasında, öndekiler önünde, yerde gölgeleri); filiz = 2 yaprak, tomurcuk = 4, açmış = 4 yaprak + 3 altın taç yaprağı.
  D Güneş Kuyusu    ayçiçeği = güneş: sıcak altın, konturSUZ yumuşak bantlı ışık; filiz = yerde küçük ışık, tomurcuk = 4 ışın + soluk
                    ışık sütunu, açmış = 8 ışın (uzun/kısa) + parlak sütun + sütunda süzülen 4 uçlu parıltılar.
Büyüme anı: A dalga halkası + rünler tek tek belirir, B kökler uzar, C yapraklar dışa savrulup yerine oturur, D parlama + ışınlar uzanır.
Ölçek: 1 piksel = 1 dünya birimi (çiçek sanatıyla aynı yoğunluk), arka plan gerçek çizici yakalaması (cicek_capture.gd CC_BG=1, kamera
x2; oyuncu/arayüz gizli). Karakter pikseli 0,903 dünya (Oakley). Zaman sıkıştırıldı: aşama 5 sn yerine ~2,6 sn.
Çıktı (out/cicek_efekt/): cicek_{A,B,C,D}.gif (x3 yakın), cicek_ozet.png (ŞU AN + 4 yön x 3 aşama, x4), cicek_oyun_olcegi.gif
(5'i yan yana, x2 = 1080p oyun görüşü).
Kullanım (proje kökünden): python -I tools/proto_20261019/cicek_efekt_proto.py
"""
import math
import os
import re

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.normpath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(HERE, 'out', 'cicek_efekt')
BG_PATH = os.path.join(HERE, 'out', 'cicek', 'cc_bg_dunya.png')

DT = 0.07
TAU = math.tau
CHAR_S = 2.2368375 * 0.8075 * 0.5  ## Oakley sanat pikseli -> dünya (0,903)
T_BIRTH = 0.0
T_GROW = [2.9, 5.5]  ## aşama 0 -> 1, 1 -> 2
T_END = 8.8
TRANS = 0.6
NAMES = {'N': 'ŞU AN (Life Recovery)', 'A': 'Druid Mührü', 'B': 'Işıyan Kökler', 'C': 'Yaprak Halkası', 'D': 'Güneş Kuyusu'}
STAGE_NAMES = ['filiz', 'tomurcuk', 'açmış']

OUTL = (26, 59, 41)  ## çiçeğin kontur rengi
LEAF = [(26, 59, 41), (64, 112, 48), (122, 162, 61), (168, 204, 92), (214, 236, 150)]
PETAL = [(84, 48, 35), (181, 118, 57), (220, 168, 61), (228, 186, 76), (250, 232, 160)]
MINT = [(18, 70, 52), (40, 140, 96), (88, 210, 140), (170, 244, 190), (236, 255, 236)]
GOLD = [(120, 70, 20), (196, 128, 36), (240, 186, 70), (255, 226, 130), (255, 250, 222)]
ROOT = [(26, 40, 26), (70, 46, 30), (112, 76, 44), (156, 112, 64)]
LIME = [(118, 170, 50), (176, 226, 86), (228, 252, 168)]


# ====================================================================== yardımcılar
def rgba(p):
    return Image.open(p).convert('RGBA')


def nscale(im, s):
    return im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.NEAREST)


def comp(dst, src, x, y):
    x, y = int(round(x)), int(round(y))
    sx0, sy0 = max(0, -x), max(0, -y)
    sx1, sy1 = min(src.width, dst.width - x), min(src.height, dst.height - y)
    if sx1 <= sx0 or sy1 <= sy0:
        return
    dst.alpha_composite(src.crop((sx0, sy0, sx1, sy1)), (x + sx0, y + sy0))


def band(a, n=5):
    return max(0.0, min(1.0, round(a * n) / n))


def clamp01(v):
    return max(0.0, min(1.0, v))


def ease_out(t):
    t = clamp01(t)
    return 1 - (1 - t) ** 3


def ease_back(t):  ## hafif taşma (yerine oturma)
    t = clamp01(t)
    c = 1.9
    return 1 + (c + 1) * (t - 1) ** 3 + c * (t - 1) ** 2


def font(sz):
    for c in (r'C:\Windows\Fonts\segoeuib.ttf', r'C:\Windows\Fonts\segoeui.ttf', r'C:\Windows\Fonts\arial.ttf'):
        if os.path.exists(c):
            return ImageFont.truetype(c, sz)
    return ImageFont.load_default()


def glyph(rows, pal):
    h, w = len(rows), max(len(r) for r in rows)
    im = Image.new('RGBA', (w, h))
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in pal:
                im.putpixel((x, y), tuple(pal[ch]) + (255,))
    return im


def tres_frames(path):
    txt = open(path, encoding='utf-8').read()
    sheet = rgba(os.path.join(PROJECT, re.search(r'path="res://([^"]+)"', txt).group(1)))
    regs = {}
    for m in re.finditer(r'id="([^"]+)"\]([^\[]*?)region = Rect2\(([^)]*)\)', txt, re.S):
        x, y, w, h = [int(float(v)) for v in m.group(3).split(',')]
        regs[m.group(1)] = sheet.crop((x, y, x + w, y + h))
    res = txt[txt.index('[resource]'):]
    anims, pos = {}, 0
    for m in re.finditer(r'"name": &"([^"]+)"', res):
        anims[m.group(1)] = [regs[i] for i in re.findall(r'SubResource\("([^"]+)"\)', res[pos:m.start()])]
        pos = m.end()
    return anims


class Ov:
    """Kayan nokta RGBA katmanı (W x H); maskelerle 'üstüne' karıştırma."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.c = np.zeros((h, w, 4), np.float32)

    def put(self, x0, y0, m, rgb, a):
        if a <= 0.001:
            return
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

    def px(self, x, y, rgb, a):
        self.put(int(round(x)), int(round(y)), np.ones((1, 1), bool), rgb, a)

    def img(self):
        return Image.fromarray(np.clip(self.c * 255.0, 0, 255).astype(np.uint8), 'RGBA')


def ell(cx, cy, rx, ry):
    rx, ry = max(rx, 0.6), max(ry, 0.6)
    x0, y0 = int(math.floor(cx - rx)) - 1, int(math.floor(cy - ry)) - 1
    w, h = int(2 * rx) + 4, int(2 * ry) + 4
    Y, X = np.mgrid[0:h, 0:w]
    dx = (X + x0 + 0.5 - cx) / rx
    dy = (Y + y0 + 0.5 - cy) / ry
    return x0, y0, dx * dx + dy * dy, np.arctan2(dy, dx)


def fill_ell(ov, cx, cy, rx, ry, rgb, a):
    x0, y0, d, _ = ell(cx, cy, rx, ry)
    ov.put(x0, y0, d <= 1.0, rgb, a)


def ring(ov, cx, cy, rx, ry, rgb, a, th=1.0, arc=None):
    """Sürekli 1 px (th) elips halka; arc = (başlangıç açısı, uzunluk) radyan ile kesik parça."""
    x0, y0, d, ang = ell(cx, cy, rx, ry)
    m = (d <= 1.0) & (d >= ((rx - th) / rx) ** 2)
    if arc is not None:
        a0, ln = arc
        rel = np.mod(ang - a0, TAU)
        m &= rel <= ln
    ov.put(x0, y0, m, rgb, a)


def sparkle(k, c_core, c_arm):
    n = 2 * k + 1
    im = Image.new('RGBA', (n, n))
    for i in range(1, k + 1):
        for (dx, dy) in ((i, 0), (-i, 0), (0, i), (0, -i)):
            im.putpixel((k + dx, k + dy), tuple(c_arm if i > 1 or k == 1 else c_core) + (255,))
    im.putpixel((k, k), tuple(c_core) + (255,))
    return im


def faded(im, a):
    if a >= 0.999:
        return im
    arr = np.array(im)
    arr[:, :, 3] = (arr[:, :, 3].astype(np.float32) * max(0.0, a)).astype(np.uint8)
    return Image.fromarray(arr)


# ====================================================================== sanat
FLOWER = [rgba(os.path.join(PROJECT, 'assets', 'generated', 'fx_oakley_flower_stages.png')).crop((i * 31, 0, i * 31 + 31, 42)) for i in range(3)]
FOOT_Y = 20  ## oakley_flower.gd FOOT_Y: 31x42 ortalı karenin alt opak satırı
_OAK = rgba(os.path.join(PROJECT, 'assets', 'characters', 'oakley', 'sheets', 'idle.png'))
OAK_IDLE_R = [nscale(_OAK.crop((c * 48, 2 * 48, c * 48 + 48, 3 * 48)), CHAR_S) for c in range(4)]  ## satır 2 = sağa
CHAR_FEET, CHAR_CX = 40 * CHAR_S, 24 * CHAR_S
RECOVERY = tres_frames(os.path.join(PROJECT, 'assets', 'fx', 'recovery', 'life_recovery_small_frames.tres'))['loop']
BG = rgba(BG_PATH)

## C: çiçeğin sanat diliyle küçük yaprak / taç yaprağı (kalın kontur, 3 ton), 4 yön (yörüngede gidiş yönüne döner)
_LEAF_ROWS = ['.oo..',
              'o23o.',
              'o2233o',
              '.o112o',
              '..ooo.']
_PETAL_ROWS = ['.oo.',
               'o34o',
               'o23o',
               'o22o',
               '.oo.']
LEAF_PAL = {'o': OUTL, '1': LEAF[1], '2': LEAF[2], '3': LEAF[3]}
PETAL_PAL = {'o': PETAL[0], '2': PETAL[2], '3': PETAL[3], '4': PETAL[4]}
LEAF_SPR = glyph(_LEAF_ROWS, LEAF_PAL)
PETAL_SPR = glyph(_PETAL_ROWS, PETAL_PAL)
LEAF_ROT = [LEAF_SPR, LEAF_SPR.transpose(Image.ROTATE_90), LEAF_SPR.transpose(Image.FLIP_LEFT_RIGHT), LEAF_SPR.transpose(Image.ROTATE_270)]
## A: rün = küçük yaprak işareti (konturSUZ, 2 ton)
RUNE = glyph(['.x.', 'xyx', '.x.'], {'x': MINT[3], 'y': MINT[4]})
RUNE_DIM = glyph(['.x.', 'xyx', '.x.'], {'x': MINT[2], 'y': MINT[3]})


# ====================================================================== zaman / aşama
def stage_at(t):
    return 0 if t < T_GROW[0] else (1 if t < T_GROW[1] else 2)


def grow_k(t):
    """Büyüme geçişi: (eski aşama, yeni aşama, 0..1 ilerleme) - geçiş yoksa k = 1."""
    for i, tg in enumerate(T_GROW):
        if tg <= t < tg + TRANS:
            return i, i + 1, (t - tg) / TRANS
    s = stage_at(t)
    return s, s, 1.0


def birth_k(t):
    return ease_out((t - T_BIRTH) / 0.45)


def end_k(t):
    return 1.0 - clamp01((t - (T_END - 0.35)) / 0.35)


def lerp_stage(vals, t, f=ease_out):
    a, b, k = grow_k(t)
    return vals[a] + (vals[b] - vals[a]) * f(k)


# ====================================================================== yönler
class Fx:
    """Her yön: ground(ov, t, bx, by) zeminde (çiçeğin altı), back(...) çiçeğin arkasında havada, front(...) çiçeğin önünde."""

    def ground(self, ov, t, bx, by):
        pass

    def back(self, ov, t, bx, by):
        pass

    def front(self, ov, t, bx, by):
        pass


class Now(Fx):
    """Bugünkü: Life Recovery, kök + (0, 14), 25 kare/sn, her aşamada aynı."""

    def __init__(self):
        self.sprite_layer = True

    def ground_img(self, t):
        return RECOVERY[int(t * 25) % len(RECOVERY)]


def erode4(m):
    o = m.copy()
    o[1:] &= m[:-1]
    o[:-1] &= m[1:]
    o[:, 1:] &= m[:, :-1]
    o[:, :-1] &= m[:, 1:]
    o[0, :] = False
    o[-1, :] = False
    o[:, 0] = False
    o[:, -1] = False
    return o


def dilate4(m):
    o = m.copy()
    o[1:] |= m[:-1]
    o[:-1] |= m[1:]
    o[:, 1:] |= m[:, :-1]
    o[:, :-1] |= m[:, 1:]
    return o


def ell_fill(cx, cy, rx, ry, pad=2):
    rx, ry = max(rx, 0.6), max(ry, 0.6)
    x0, y0 = int(math.floor(cx - rx)) - pad, int(math.floor(cy - ry)) - pad
    w, h = int(2 * rx) + 2 * pad + 2, int(2 * ry) + 2 * pad + 2
    Y, X = np.mgrid[0:h, 0:w]
    dx = (X + x0 + 0.5 - cx) / rx
    dy = (Y + y0 + 0.5 - cy) / ry
    return x0, y0, (dx * dx + dy * dy) <= 1.0, np.arctan2(dy, dx)


def outline_ring(ov, cx, cy, rx, ry, rgb, a, th=1, arc=None):
    """Kesintisiz piksel kontur (dolu elipsin kenarı, 4-komşu aşındırma) - 2:1'de üst/alt kopmaz."""
    x0, y0, m, ang = ell_fill(cx, cy, rx, ry)
    inner = m
    for _ in range(th):
        inner = erode4(inner)
    r = m & ~inner
    if arc is not None:
        a0, ln = arc
        r &= np.mod(ang - a0, TAU) <= ln
    ov.put(x0, y0, r, rgb, a)


def layer_mask(w, h, fn):
    lay = Image.new('L', (w, h))
    fn(ImageDraw.Draw(lay))
    return np.array(lay) > 0


class DruidSeal(Fx):
    """A: serin nane, konturSUZ ince kesintisiz halkalar + yaprak rünleri; dolu ama soluk iç ışık (2 bant)."""
    R = [11.0, 17.0, 23.0]
    LINE = (196, 255, 222)
    LINE_HI = (240, 255, 246)
    UNDER = (40, 150, 110)
    FILL = (120, 236, 176)
    RUNE_SPR = glyph(['..x..', '.xyx.', 'xyzyx', '.xyx.', '..x..'], {'x': (60, 190, 130), 'y': (170, 250, 200), 'z': (250, 255, 250)})
    RUNE_DIM_SPR = glyph(['.x.', 'xyx', '.x.'], {'x': (60, 190, 130), 'y': (170, 250, 200)})

    def ground(self, ov, t, bx, by):
        a_all = birth_k(t) * end_k(t)
        if a_all <= 0:
            return
        cy = by - 1
        r = lerp_stage(self.R, t, ease_back)
        s_from, s_to, k = grow_k(t)
        s = stage_at(t)
        breathe = 0.8 + 0.2 * math.sin(t * 3.1)
        x0, y0, m, _ = ell_fill(bx, cy, r, r * 0.5)
        ov.put(x0, y0, m, self.FILL, band(0.26 * a_all))
        x0, y0, m2, _ = ell_fill(bx, cy, r * 0.5, r * 0.25)
        ov.put(x0, y0, m2, self.LINE, band(0.3 * a_all))
        ## halka: 1 px koyu alt çizgi (oyma hissi) + parlak çizgi
        outline_ring(ov, bx, cy + 1, r, r * 0.5, self.UNDER, band(0.55 * a_all))
        outline_ring(ov, bx, cy, r, r * 0.5, self.LINE, band(0.95 * breathe * a_all))
        rot = t * 0.55
        if s_to >= 1:
            k1 = 1.0 if s_from >= 1 else k
            ri = r * 0.6
            outline_ring(ov, bx, cy, ri, ri * 0.5, self.FILL, band(0.8 * a_all * ease_out(k1 * 1.6)))
            n = 8 if s_to >= 2 else 4
            for i in range(n):
                ang = rot + TAU * i / n
                new_rune = (s_from == 0 and s_to == 1) or (s_from == 1 and s_to == 2 and i % 2 == 1)
                appear = clamp01(k * 1.6 - (i / n) * 0.6) if new_rune else 1.0
                if appear <= 0:
                    continue
                lit = 0.5 + 0.5 * math.sin(t * 4.0 - i * (TAU / n))
                big = s >= 2 and i % 2 == 0 or s == 1
                spr = self.RUNE_SPR if big else self.RUNE_DIM_SPR
                px_, py_ = bx + math.cos(ang) * r, cy + math.sin(ang) * r * 0.5
                comp_ov(ov, spr, px_ - spr.width // 2, py_ - spr.height // 2, band(appear * a_all * (0.7 + 0.3 * lit if s >= 2 else 1.0)))
        if s_to >= 2:
            k2 = 1.0 if s_from >= 2 else k
            ro = r + 5
            for i in range(6):
                outline_ring(ov, bx, cy, ro, ro * 0.5, self.FILL, band(0.75 * a_all * ease_out(k2 * 1.5)), arc=(-t * 0.45 + TAU * i / 6, TAU / 6 * 0.6))
        if k < 1.0:  ## büyüme dalgası
            rw = self.R[s_from] + (self.R[s_to] + 10 - self.R[s_from]) * ease_out(k)
            outline_ring(ov, bx, cy, rw, rw * 0.5, self.LINE_HI, band((1 - k) * a_all))

    def front(self, ov, t, bx, by):
        a_all = birth_k(t) * end_k(t)
        s = stage_at(t)
        if s < 1 or a_all <= 0:
            return
        r = lerp_stage(self.R, t, ease_back)
        n_sp = 1 if s == 1 else 3
        for j in range(n_sp):
            ph = (t * 0.6 + j / n_sp) % 1.0
            cyc = int(t * 0.6 + j / n_sp)
            ang = t * 0.55 + TAU * ((cyc * 3 + j * 3) % 8) / 8
            x = bx + math.cos(ang) * r
            y = by - 1 + math.sin(ang) * r * 0.5 - 2 - ph * 24
            kk = 2 if 0.25 < ph < 0.7 else 1
            comp_ov(ov, sparkle(kk, (250, 255, 250), self.LINE), x - kk, y - kk, band(a_all * math.sin(ph * math.pi) * 1.2))


class GlowRoots(Fx):
    """B: toprak dili - koyu konturlu, sivrilen, kıvrık kökler; içleri ışır (krem-limon öz), etrafında soluk hale; uçlardan çiçeğe ışık damlası."""
    ## (açı derece, uzunluk/aşama, büküm derece, çatal (oran, açı farkı, boy oranı))
    ROOTS = [(180, [11, 17, 26], 28, (0.6, -40, 0.4)), (0, [11, 17, 25], -28, (0.55, 40, 0.4)), (95, [7, 11, 15], 25, None),
             (135, [0, 15, 23], -35, (0.55, 40, 0.45)), (45, [0, 14, 22], 35, (0.5, -40, 0.45)),
             (230, [0, 0, 18], 25, None), (310, [0, 0, 17], -25, (0.5, 35, 0.5))]
    CORE = (214, 246, 128)
    CORE_HI = (252, 255, 214)
    BODY = (122, 84, 48)
    BODY_HI = (160, 116, 64)
    OUT = (40, 30, 20)
    HALO = (190, 236, 110)
    SOIL = (64, 46, 30)

    def _path(self, x, y, ang_deg, bend_deg, length):
        pts = []
        n = max(2, int(length / 1.5) + 1)
        px_, py_ = x, y
        pts.append((px_, py_))
        step = length / (n - 1)
        for i in range(1, n):
            q = i / (n - 1)
            a = math.radians(ang_deg + bend_deg * q)
            px_ += math.cos(a) * step
            py_ += math.sin(a) * step * 0.5
            pts.append((px_, py_))
        return pts

    def ground(self, ov, t, bx, by):
        a_all = birth_k(t) * end_k(t)
        if a_all <= 0:
            return
        s_from, s_to, k = grow_k(t)
        s = stage_at(t)
        W, H = ov.w, ov.h
        g = ease_out(k)
        soil = [6.0, 9.0, 12.0]
        sr = soil[s_from] + (soil[s_to] - soil[s_from]) * g
        x0, y0, m, _ = ell_fill(bx, by, sr, sr * 0.5)
        ov.put(x0, y0, m, self.SOIL, band(0.55 * a_all))
        x0, y0, m, _ = ell_fill(bx, by, sr * 0.55, sr * 0.28)
        ov.put(x0, y0, m, self.CORE, band(0.3 * a_all))
        thick, thin = [], []
        tips = []
        for ri, (ang, lens, bend, fork) in enumerate(self.ROOTS):
            L = (lens[s_from] + (lens[s_to] - lens[s_from]) * g) * birth_k(t)
            if L < 2.0:
                continue
            pts = self._path(bx, by, ang, bend, L)
            cut = max(2, int(len(pts) * 0.45))
            thick.append(pts[:cut])
            thin.append(pts[cut - 1:])
            tips.append((ri, pts))
            if fork and L > 9:
                fq, fd, fl = fork
                p0 = pts[int((len(pts) - 1) * fq)]
                fp = self._path(p0[0], p0[1], ang + fd, bend * 0.5, L * fl)
                thin.append(fp)
                tips.append((ri + 10, fp))

        def draw_body(d):
            for p in thick:
                d.line(p, fill=255, width=2)
            for p in thin:
                d.line(p, fill=255, width=1)

        def draw_core(d):
            for p in thick + thin:
                d.line(p, fill=255, width=1)
        body = layer_mask(W, H, draw_body)
        core = layer_mask(W, H, draw_core)
        outl = dilate4(body) & ~body
        pul = 0.75 + 0.25 * math.sin(t * 2.6)
        if s >= 2:
            halo = dilate4(dilate4(body)) & ~dilate4(body)
            ov.put(0, 0, halo, self.HALO, band(0.2 * pul * a_all))
        ov.put(0, 0, outl, self.OUT, band(0.8 * a_all))
        ov.put(0, 0, body, self.BODY, band(a_all))
        top_edge = body & ~np.roll(body, 1, axis=0)
        ov.put(0, 0, top_edge & ~core, self.BODY_HI, band(a_all))
        ## ışık özü: kökten uca doğru akan parlaklık (öz pikselleri zaman fazıyla bant bant)
        ov.put(0, 0, core, self.CORE, band((0.55 + 0.45 * pul) * a_all))
        ## kökte ışık: çiçeğin dibinde küçük parlak leke
        x0, y0, m, _ = ell_fill(bx, by, 4, 2)
        ov.put(x0, y0, m, self.CORE, band(0.45 * pul * a_all))
        if s >= 1:  ## uç tomurcukları: çiçeğin yaprak dilinde 3 px'lik filiz
            for (ri, pts) in tips:
                tx, ty = pts[-1]
                sprout = glyph(['o.o', 'gog', '.o.'], {'o': self.OUT, 'g': LEAF[3]}) if ri % 2 else glyph(['.o.', 'ogo', '.o.'], {'o': self.OUT, 'g': self.CORE})
                comp_ov(ov, sprout, tx - 1, ty - 2, band(a_all * (ease_out(k * 2) if (s_from == 0 and s_to == 1) else 1.0)))
        if s >= 2:  ## uçlardan çiçeğe akan ışık (besleniyor)
            for j in range(3):
                ph = (t * 0.8 + j / 3) % 1.0
                (ri, pts) = tips[(int(t * 0.8 + j / 3) * 2 + j * 3) % len(tips)]
                idx = (len(pts) - 1) * (1.0 - ph)
                i0 = int(idx)
                i1 = min(len(pts) - 1, i0 + 1)
                f = idx - i0
                x = pts[i0][0] + (pts[i1][0] - pts[i0][0]) * f
                y = pts[i0][1] + (pts[i1][1] - pts[i0][1]) * f
                ov.put(int(round(x)) - 1, int(round(y)) - 1, np.ones((2, 3), bool) if j != 1 else np.ones((2, 2), bool), self.CORE_HI, band(a_all))

    def front(self, ov, t, bx, by):
        a_all = birth_k(t) * end_k(t)
        if stage_at(t) < 2 or a_all <= 0:
            return
        ## açmış: kökten 2 yaprak gibi süzülen ışık zerresi (kısa çizgi, hız yönünde)
        for j in range(2):
            ph = (t * 0.5 + j * 0.5) % 1.0
            x = bx + (-6 if j == 0 else 7) + math.sin(t * 2 + j) * 2
            y = by - 4 - ph * 30
            ov.put(int(round(x)), int(round(y)), np.ones((2, 1), bool), self.CORE_HI, band(a_all * math.sin(ph * math.pi)))


class LeafHalo(Fx):
    """C: çizgi film dili - çiçeğin konturuyla yapraklar 2:1 yörüngede; arkalarında yörünge üstünde sürekli 1 px 'savrulma' izi."""
    R = [10.0, 15.0, 20.0]
    POOL = [10.0, 14.0, 19.0]
    H = [6.0, 9.0, 12.0]
    TRAIL = (226, 250, 170)
    POOL_C = (236, 246, 170)
    LEAF_BIG = glyph(['....ooo',
                      '..oo33o',
                      '.o3332o',
                      'o22221o',
                      'o2211o.',
                      'o11oo..',
                      '.oo....'], {'o': OUTL, '1': LEAF[1], '2': LEAF[2], '3': LEAF[3]})
    PETAL_BIG = glyph(['.oo.',
                       'o44o',
                       'o34o',
                       'o33o',
                       'o23o',
                       '.oo.'], {'o': PETAL[0], '2': PETAL[1], '3': PETAL[2], '4': PETAL[4]})

    def _items(self, t):
        s_from, s_to, k = grow_k(t)
        n_leaf = [2, 4, 4]
        n_pet = [0, 0, 3]
        items = []
        n = n_leaf[s_to] + n_pet[s_to]
        for i in range(n_leaf[s_to]):
            items.append(('leaf', i, n, i >= n_leaf[s_from]))
        for i in range(n_pet[s_to]):
            items.append(('petal', n_leaf[s_to] + i, n, i >= n_pet[s_from]))
        return items, k

    def _orbit(self, t):
        s_from, s_to, k = grow_k(t)
        r = lerp_stage(self.R, t, ease_back)
        if k < 1.0:
            r += math.sin(k * math.pi) * 8.0
        return r, lerp_stage(self.H, t), [1.3, 1.5, 1.7][stage_at(t)]

    def _pos(self, t, bx, by, idx, n, dang=0.0):
        r, h, speed = self._orbit(t)
        ang = t * speed + TAU * idx / n - dang
        bob = math.sin(t * 2.4 + idx) * 1.2
        x = bx + math.cos(ang) * r
        gy = by - 1 + math.sin(ang) * r * 0.45
        return x, gy, gy - h + bob, ang

    def ground(self, ov, t, bx, by):
        a_all = birth_k(t) * end_k(t)
        if a_all <= 0:
            return
        pool = lerp_stage(self.POOL, t, ease_back)
        x0, y0, m, _ = ell_fill(bx, by - 1, pool, pool * 0.5)
        ov.put(x0, y0, m, self.POOL_C, band(0.24 * a_all))
        x0, y0, m, _ = ell_fill(bx, by - 1, pool * 0.5, pool * 0.25)
        ov.put(x0, y0, m, (252, 252, 214), band(0.24 * a_all))
        outline_ring(ov, bx, by - 1, pool, pool * 0.5, self.POOL_C, band(0.6 * a_all))
        items, k = self._items(t)
        for (kind, idx, n, new) in items:
            x, gy, _, _ = self._pos(t, bx, by, idx, n)
            app = ease_out(k * 1.5) if new else 1.0
            ov.put(int(round(x)) - 2, int(round(gy)), np.ones((1, 4), bool), (28, 48, 22), band(0.4 * a_all * app))

    def _draw(self, ov, t, bx, by, front):
        a_all = birth_k(t) * end_k(t)
        if a_all <= 0:
            return
        items, k = self._items(t)
        r, h, speed = self._orbit(t)
        for (kind, idx, n, new) in items:
            x, gy, y, ang = self._pos(t, bx, by, idx, n)
            if (math.sin(ang) >= 0) != front:
                continue
            app = ease_out(k * 1.5) if new else 1.0
            if app <= 0:
                continue
            ## iz: yörüngenin yaprağın arkasında kalan 0,7 rad'lık parçası, 2 bantta söner (sürekli çizgi)
            pts = []
            for q in range(11):
                xx, _, yy, _ = self._pos(t, bx, by, idx, n, dang=0.09 * q)
                pts.append((xx, yy))
            m1 = layer_mask(ov.w, ov.h, lambda d: d.line(pts[:5], fill=255, width=1))
            m2 = layer_mask(ov.w, ov.h, lambda d: d.line(pts[4:], fill=255, width=1))
            ov.put(0, 0, m1, self.TRAIL, band(0.9 * a_all * app))
            ov.put(0, 0, m2 & ~m1, self.TRAIL, band(0.45 * a_all * app))
            q = int(((ang + math.pi / 4) % TAU) / (math.pi / 2)) % 4
            if kind == 'leaf':
                ## gidiş yönüne sivri ucu: sağa giden (önde) / sola giden (arkada) aynalı
                spr = self.LEAF_BIG if math.sin(ang) >= 0 else self.LEAF_BIG.transpose(Image.FLIP_LEFT_RIGHT)
                if q in (1, 3):
                    spr = spr.transpose(Image.FLIP_TOP_BOTTOM)
            else:
                spr = self.PETAL_BIG if q % 2 == 0 else self.PETAL_BIG.transpose(Image.ROTATE_90)
            comp_ov(ov, spr, x - spr.width / 2, y - spr.height / 2, band(a_all * app))
            if new and k < 0.5:
                comp_ov(ov, sparkle(2, (255, 255, 236), PETAL[3]), x - 2, y - 8, band((1 - k * 2) * a_all))

    def back(self, ov, t, bx, by):
        self._draw(ov, t, bx, by, False)

    def front(self, ov, t, bx, by):
        self._draw(ov, t, bx, by, True)


class SunWell(Fx):
    """D: sıcak altın, konturSUZ bantlı ışık; zeminde güneş diski + dönen ışınlar, tepeden daralan ışık huzmesi."""
    R = [10.0, 14.0, 20.0]
    RAYS = [0, 4, 8]
    BEAM_W = [0.0, 10.0, 15.0]
    BEAM_A = [0.0, 0.16, 0.26]
    WARM = (255, 210, 96)
    WARM_HI = (255, 236, 160)
    CREAM = (255, 250, 220)
    RIM = (255, 196, 70)

    def ground(self, ov, t, bx, by):
        a_all = birth_k(t) * end_k(t)
        if a_all <= 0:
            return
        s_from, s_to, k = grow_k(t)
        r = lerp_stage(self.R, t, ease_back)
        flash = (1 - k) * 0.3 if k < 1 else 0.0
        br = 0.88 + 0.12 * math.sin(t * 2.2)
        cy = by - 1
        n_from, n_to = self.RAYS[s_from], self.RAYS[s_to]
        n = max(n_from, n_to)
        if n:
            rot = t * 0.3
            masks_long, masks_short = [], []
            for i in range(n):
                new = i >= n_from if n_from else True
                if n_from == 4 and n_to == 8:
                    new = i % 2 == 1
                ext = ease_out(k) if (new and k < 1) else 1.0
                ang = rot + TAU * i / n
                long_ = (i % 2 == 0) or n == 4
                L = r * (1.7 if long_ else 1.35) * ext
                if L <= r * 0.85:
                    continue
                wa = ang + math.pi / 2
                br_ = r * 0.85
                hw = 2.6 if long_ else 1.8
                tip = (bx + math.cos(ang) * L, cy + math.sin(ang) * L * 0.5)
                b0 = (bx + math.cos(ang) * br_ + math.cos(wa) * hw, cy + (math.sin(ang) * br_ + math.sin(wa) * hw) * 0.5)
                b1 = (bx + math.cos(ang) * br_ - math.cos(wa) * hw, cy + (math.sin(ang) * br_ - math.sin(wa) * hw) * 0.5)
                (masks_long if long_ else masks_short).append([b0, tip, b1])
            for polys, a in ((masks_long, 0.55), (masks_short, 0.4)):
                if polys:
                    m = layer_mask(ov.w, ov.h, lambda d: [d.polygon(p, fill=255) for p in polys])
                    ov.put(0, 0, m, self.WARM, band(a * br * a_all))
        for (q, col, a) in ((1.0, self.WARM, 0.26), (0.66, self.WARM_HI, 0.3), (0.34, self.CREAM, 0.4)):
            x0, y0, m, _ = ell_fill(bx, cy, r * q, r * q * 0.5)
            ov.put(x0, y0, m, col, band((a + flash) * br * a_all))
        outline_ring(ov, bx, cy, r, r * 0.5, self.RIM, band(0.8 * br * a_all))

    def front(self, ov, t, bx, by):
        a_all = birth_k(t) * end_k(t)
        if a_all <= 0:
            return
        w = lerp_stage(self.BEAM_W, t)
        a = lerp_stage(self.BEAM_A, t)
        if w >= 2.0 and a > 0.01:
            top = by - 64
            ## tepeden yere GENİŞLEYEN huzme, yukarı doğru 5 bantta söner; ortada daha parlak çekirdek
            for bi in range(5):
                ya, yb = top + bi * 12, top + (bi + 1) * 12 if bi < 4 else by - 1
                qa, qb = bi / 5, (bi + 1) / 5
                wa_, wb_ = w * (0.45 + 0.55 * qa), w * (0.45 + 0.55 * qb)
                aa = a * (0.25 + 0.75 * qb) * (0.9 + 0.1 * math.sin(t * 2.0))
                poly = [(bx - wa_ / 2, ya), (bx + wa_ / 2, ya), (bx + wb_ / 2, yb), (bx - wb_ / 2, yb)]
                m = layer_mask(ov.w, ov.h, lambda d: d.polygon(poly, fill=255))
                ov.put(0, 0, m, self.WARM, band(aa * a_all, 10))
                core = [(bx - wa_ / 5, ya), (bx + wa_ / 5, ya), (bx + wb_ / 5, yb), (bx - wb_ / 5, yb)]
                mc = layer_mask(ov.w, ov.h, lambda d: d.polygon(core, fill=255))
                ov.put(0, 0, mc, self.CREAM, band(aa * 0.9 * a_all, 10))
        if stage_at(t) >= 2:
            for j in range(3):
                ph = (t * 0.42 + j / 3.0) % 1.0
                x = bx + math.sin(t * 1.3 + j * 2.1) * (w * 0.28)
                y = by - 8 - ph * 48
                kk = 2 if 0.3 < ph < 0.7 else 1
                comp_ov(ov, sparkle(kk, self.CREAM, self.WARM), x - kk, y - kk, band(a_all * math.sin(ph * math.pi) * 1.1))


def comp_ov(ov, spr, x, y, a):
    """Sprite'ı Ov'a renk renk (düz) bas."""
    if a <= 0:
        return
    arr = np.array(spr)
    m = arr[:, :, 3] > 0
    x, y = int(round(x)), int(round(y))
    for col in {tuple(c) for c in arr[m][:, :3]}:
        ov.put(x, y, m & np.all(arr[:, :, :3] == col, axis=2), col, a)


VARIANTS = {'N': Now(), 'A': DruidSeal(), 'B': GlowRoots(), 'C': LeafHalo(), 'D': SunWell()}


# ====================================================================== sahne
def flower_img(t):
    return FLOWER[stage_at(t)]


def bond(ov, t, ox, oy, bx, by):
    """Bugünkü anlık bağ çizgisi (fx_oakley_flower_bond.gd, 0,35 sn) - bağlam için."""
    k = t / 0.35
    if k < 0 or k >= 1:
        return
    a = 1 - k
    lay = Image.new('L', (ov.w, ov.h))
    ImageDraw.Draw(lay).line([(ox, oy), (bx, by)], fill=255, width=1)
    ov.put(0, 0, np.array(lay) > 0, (140, 255, 153), band(0.9 * a))


def scene(var, t, w, h, bg_x, bg_y, flowers, oak=None):
    """flowers: [(var, root_x, root_y)] - sahnedeki çiçekler (oyun ölçeği GIF'i için birden çok)."""
    im = BG.crop((bg_x, bg_y, bg_x + w, bg_y + h)).copy()
    ground = Ov(w, h)
    back = Ov(w, h)
    front = Ov(w, h)
    sprites = []  ## (ayak y, görsel, x, y)
    for (v, fx, fy) in flowers:
        bx, by = fx, fy + FOOT_Y
        fxo = VARIANTS[v]
        if isinstance(fxo, Now):
            spr = faded(fxo.ground_img(t), birth_k(t) * end_k(t))
            comp(im, spr, fx - spr.width / 2, fy + 14 - spr.height / 2)
        else:
            fxo.ground(ground, t, bx, by)
            fxo.back(back, t, bx, by)
            fxo.front(front, t, bx, by)
        f = flower_img(t)
        sprites.append((by, f, fx - 15.5, fy - 21))
    if oak is not None:
        ox, oy = oak
        sprites.append((oy, OAK_IDLE_R[int(t * 5) % 4], ox - CHAR_CX, oy - CHAR_FEET))
        for (v, fx, fy) in flowers[:1]:
            bond(front, t, ox + 4, oy - 14, fx, fy + 10)
    im.alpha_composite(ground.img())
    im.alpha_composite(back.img())
    for (_, spr, x, y) in sorted(sprites, key=lambda s: s[0]):
        comp(im, spr, x, y)
    im.alpha_composite(front.img())
    return im


def times():
    n = int(round(T_END / DT))
    return [i * DT for i in range(n)]


def label(im, s, s2=None, sz=17):
    dr = ImageDraw.Draw(im)
    f = font(sz)
    dr.text((11, 9), s, fill=(20, 30, 14), font=f)
    dr.text((10, 8), s, fill=(250, 246, 226), font=f)
    if s2:
        f2 = font(sz - 2)
        dr.text((11, im.height - 27), s2, fill=(20, 30, 14), font=f2)
        dr.text((10, im.height - 28), s2, fill=(250, 246, 226), font=f2)


def phase_text(t):
    s = stage_at(t)
    a, b, k = grow_k(t)
    if t < 0.4:
        return 'Oakley çiçeği bırakır (bağ çizgisi bugünkü gibi)'
    if k < 1:
        return f'BÜYÜME: {STAGE_NAMES[a]} > {STAGE_NAMES[b]} (can/kalkan +%40)'
    return f'Aşama {s + 1}/3: {STAGE_NAMES[s]}  (oyunda 5 sn, burada ~2,6 sn)'


def save_gif(path, frames):
    pal = [fr.convert('RGB').quantize(colors=220, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE) for fr in frames]
    pal[0].save(path, save_all=True, append_images=pal[1:], duration=int(DT * 1000), loop=0, disposal=1)


## yakın GIF: 240x150 dünya kırpması, x3
CROP = (150, 230, 240, 150)  ## bg x, y, w, h
FLOWER_AT = (140, 78)  ## kırpma içinde çiçek kökü
OAK_AT = (96, 104)  ## Oakley ayağı


def main():
    os.makedirs(OUT, exist_ok=True)
    bx0, by0, cw, ch = CROP
    ts = times()
    for v in 'NABCD':
        frames = []
        for t in ts:
            im = scene(v, t, cw, ch, bx0, by0, [(v, FLOWER_AT[0], FLOWER_AT[1])], OAK_AT)
            im = im.resize((cw * 3, ch * 3), Image.NEAREST)
            label(im, f'{v if v != "N" else "-"}  {NAMES[v]}    t = {t:.1f} sn'.replace('.', ','), phase_text(t))
            frames.append(im)
        p = os.path.join(OUT, f'cicek_{v if v != "N" else "simdi"}.gif')
        save_gif(p, frames)
        print('yazıldı', p)
    ## özet: 5 satır x 3 aşama, x4
    moments = [1.8, 4.6, 7.6]
    zw, zh = 96, 74
    zx, zy = FLOWER_AT[0] - zw // 2, FLOWER_AT[1] - 44
    cells = []
    for v in 'NABCD':
        row = []
        for si, tm in enumerate(moments):
            im = scene(v, tm, cw, ch, bx0, by0, [(v, FLOWER_AT[0], FLOWER_AT[1])], None)
            im = im.crop((zx, zy, zx + zw, zy + zh)).resize((zw * 4, zh * 4), Image.NEAREST)
            label(im, f'{NAMES[v]} - {STAGE_NAMES[si]}', sz=16)
            row.append(im)
        cells.append(row)
    gap = 6
    sheet = Image.new('RGB', (3 * zw * 4 + 2 * gap, 5 * zh * 4 + 4 * gap), (20, 24, 18))
    for r, row in enumerate(cells):
        for c, im in enumerate(row):
            sheet.paste(im.convert('RGB'), (c * (zw * 4 + gap), r * (zh * 4 + gap)))
    p = os.path.join(OUT, 'cicek_ozet.png')
    sheet.save(p)
    print('yazıldı', p)
    ## oyun ölçeği: 5 çiçek yan yana, x2 (1080p'de oyundaki boy)
    gw, gh = 370, 110
    gx0, gy0 = 10, 300  ## saklanma çalılığı x 380'de başlıyor - dışında kal
    fl = [(v, 37 + i * 74, 58) for i, v in enumerate('NABCD')]
    frames = []
    for t in ts:
        im = scene(None, t, gw, gh, gx0, gy0, fl, None).resize((gw * 2, gh * 2), Image.NEAREST)
        dr = ImageDraw.Draw(im)
        f = font(15)
        for (v, x, _) in fl:
            s = 'ŞU AN' if v == 'N' else v
            dr.text((x * 2 - 20 + 1, 7), s, fill=(20, 30, 14), font=f)
            dr.text((x * 2 - 20, 6), s, fill=(250, 246, 226), font=f)
        label(im, '', f'Oyun ölçeği (x2 = 1080p)  -  {phase_text(t)}', sz=16)
        frames.append(im)
    p = os.path.join(OUT, 'cicek_oyun_olcegi.gif')
    save_gif(p, frames)
    print('yazıldı', p)


if __name__ == '__main__':
    main()
