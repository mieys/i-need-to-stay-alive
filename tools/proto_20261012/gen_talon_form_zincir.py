"""2026-10-12 prototipleri (kullanıcı onaylayınca oyuna bağlanır): Talon E zinciri + R Ayna Formu yeniden üretimi.
 1) talon_e_zincir.gif - Silah Salvosu (E): yeni zincir. Halkalar karakterin piksel yoğunluğunda (1 halka pikseli = 1 karakter sanat pikseli),
    zincirin BÜTÜNÜ tek koyu konturla çevrili, 32 yönde önceden çizilmiş halka; zincir gerçek ip fiziğiyle (Verlet, 14 parça) silahın arkasında
    oval bir yay çizer. A = oval yay (%10 bolluk), B = girdap (%28 bolluk).
 2) talon_r_form.gif  - Ayna Formu (R): kırmızı-siyah form, beyaz parlayan gözler, kırmızı-beyaz silahlar, alev aurası kızıl-beyaza boyanmış.
    A = Kızıl (gövde kızıl, gölgeler siyah, dışta ince kızıl ışıma), B = Gölge (gövde siyah, kenarda kızıl ışık, silahlarda beyaz kontur).
 3) talon_r_e.gif     - R açıkken E: 10 silah + form renginde (kızıl, beyaz akkor nabız) zincirler.
 4) talon_r_yakin.png - yakın plan: şu anki / A / B (3 yön) + silahların şu anki / A / B hali.
 5) talon_r_partikul.gif - arkadaki alev aurası YERİNE partikül (kullanıcı isteği): P1 yükselen kor, P2 dönen zerreler; x4 yakın plan.
    (2 ve 3 hâlâ eski alev aurasını gösterir; yalnız bu sahne: python -I tools/proto_20261012/gen_talon_form_zincir.py partikul)
Hepsi oyundaki ekran ölçeğinde birleştirilir: karakter sanat pikseli = 2 çıktı pikseli (oyunda 1,8), 1 dünya pikseli = 2,215 çıktı pikseli.
Renk dönüşümleri piksel başına parlaklık -> renk rampasıdır (oyunda tek bir shader ile birebir yapılabilir; göz = (255,240,247) renk anahtarı).
DİKKAT (oyuna bağlarken çıktı): bu prototipte silah çemberi 2 KAT GENİŞ çizildi - SALVO_RADIUS 130 YEREL birimdir, weapon.gd ofseti kök
ölçeğiyle (0,5) çarpar -> gerçekte 65 dünya pikseli. Oyunda zincir bu yüzden yarı boyda; halkalar 0,5 dünya pikseline küçültülerek aynı
oran korundu (scripts/fx_talon_chains.gd LINK_PX). Seçilenler: zincir A, karakter A, silah A, partikül P1 (madde 97).
Kullanım (proje kökünden): python -I tools/proto_20261012/gen_talon_form_zincir.py
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageOps

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.normpath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(HERE, 'out')
os.makedirs(OUT, exist_ok=True)

TAU = math.tau
S = 2  ## çıktı pikseli / karakter sanat pikseli
ART_WORLD = 0.903  ## 1 karakter sanat pikseli = 2.2368375 (characters.gd) x EntityScale.SIZE 0.8075 x kök 0.5 dünya pikseli
W2O = S / ART_WORLD  ## dünya pikseli -> çıktı pikseli
AURA_O = 1.212 * 0.5 * W2O  ## fx_talon_form sayfa pikseli (PixelDraw.TEXEL, kök 0.5) -> çıktı pikseli
GRASS = (126, 176, 84)
FPS = 25

SALVO_RADIUS = 130.0  ## talon_formation_math.gd
MIRROR_RADIUS = 110.0
SALVO_DURATION = 3.0
SALVO_SPEED = TAU * 2.0 / SALVO_DURATION
FORM_SCALE = 1.1
GROW_TIME = 0.2
RETRACT_TIME = 0.25


def font(sz):
    for c in (r'C:\Windows\Fonts\segoeui.ttf', r'C:\Windows\Fonts\arial.ttf'):
        if os.path.exists(c):
            return ImageFont.truetype(c, sz)
    return ImageFont.load_default()


# ====================================================================== küçük yardımcılar
def shift(m, dx, dy):
    out = np.zeros_like(m)
    h, w = m.shape[:2]
    x0, x1 = max(0, -dx), min(w, w - dx)
    y0, y1 = max(0, -dy), min(h, h - dy)
    out[y0 + dy:y1 + dy, x0 + dx:x1 + dx] = m[y0:y1, x0:x1]
    return out


def dilate4(m):
    return m | shift(m, 1, 0) | shift(m, -1, 0) | shift(m, 0, 1) | shift(m, 0, -1)


def dilate8(m):
    return dilate4(m) | shift(m, 1, 1) | shift(m, -1, 1) | shift(m, 1, -1) | shift(m, -1, -1)


def ramp(t, stops):
    xs = [s[0] for s in stops]
    out = np.zeros(t.shape + (3,))
    for c in range(3):
        out[..., c] = np.interp(t, xs, [s[1][c] for s in stops])
    return out


def lum(rgb):
    return (rgb @ np.array([0.299, 0.587, 0.114])) / 255.0


def to_img(arr):
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), 'RGBA')


_GR = {}


def grass(w, h):
    if (w, h) not in _GR:
        cw, ch = w // S + 1, h // S + 1
        img = Image.new('RGBA', (cw, ch), GRASS + (255,))
        rng = random.Random(4)
        px = img.load()
        for _ in range(cw * ch // 14):
            px[rng.randrange(cw), rng.randrange(ch)] = rng.choice([(116, 166, 76), (134, 184, 92), (110, 158, 72)]) + (255,)
        _GR[(w, h)] = img.resize((cw * S, ch * S), Image.NEAREST).crop((0, 0, w, h))
    return _GR[(w, h)].copy()


def comp(dst, src, x, y):
    x, y = int(round(x)), int(round(y))
    sx0, sy0 = max(0, -x), max(0, -y)
    sx1, sy1 = min(src.width, dst.width - x), min(src.height, dst.height - y)
    if sx1 <= sx0 or sy1 <= sy0:
        return
    dst.alpha_composite(src.crop((sx0, sy0, sx1, sy1)), (x + sx0, y + sy0))


def save_gif(name, frames, ms):
    big = [fr.convert('RGB').quantize(colors=220, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE) for fr in frames]
    big[0].save(os.path.join(OUT, name), save_all=True, append_images=big[1:], duration=ms, loop=0, disposal=1)


def label(img, x, y, text, sz=17):
    d = ImageDraw.Draw(img)
    f = font(sz)
    d.text((x + 1, y + 1), text, fill=(20, 30, 14), font=f)
    d.text((x, y), text, fill=(250, 246, 226), font=f)


# ====================================================================== karakter: form boyaması
def _sheet(name):
    return Image.open(os.path.join(PROJECT, 'assets', 'characters', 'talon', 'sheets', name + '.png')).convert('RGBA')


IDLE = _sheet('idle')  ## 4 sütun; satırlar: aşağı, sol, sağ, yukarı
EYE = np.array([255.0, 240.0, 247.0])  ## göz akı: Talon sayfalarında SADECE gözde geçen renk (tüm sayfalar tarandı)

## A · Kızıl: gövde kızıl, gölgeler/saç siyah. B · Gölge: gövde neredeyse siyah, sadece en açık yerler koyu kızıl + kenar ışığı.
RAMP_A = [(0.0, (14, 4, 8)), (0.25, (70, 8, 16)), (0.5, (136, 14, 22)), (0.75, (190, 26, 30)), (1.0, (214, 36, 38))]
RAMP_B = [(0.0, (6, 3, 7)), (0.35, (26, 5, 10)), (0.7, (84, 10, 18)), (1.0, (150, 20, 26))]
RIM_B = np.array([236.0, 36.0, 40.0])
HALO = {'A': np.array([255.0, 128.0, 120.0]), 'B': np.array([255.0, 84.0, 84.0])}
GLOW_A = (255, 56, 48)


def cell(sh, col, row):
    return sh.crop((col * 48, row * 48, col * 48 + 48, row * 48 + 48))


def form_char(fr, variant, amount=1.0, pulse=1.0, glint=0.0):
    """fr: 48x48 kare. amount 0..1 dönüşüm, pulse 0..1 ışıma nabzı, glint 0..1 göz parıltısı (kısa "+" çakması)."""
    a = np.array(fr, dtype=np.float64)
    al = a[..., 3] > 0
    rgb = a[..., :3]
    L = lum(rgb)
    t = np.clip((L - 0.04) / 0.66, 0.0, 1.0) ** 0.75
    new = ramp(t, RAMP_A if variant == 'A' else RAMP_B)
    eye_w = al & np.all(rgb == EYE, axis=-1)
    pupil = al & ~eye_w & (L < 0.2) & (shift(eye_w, 1, 0) | shift(eye_w, -1, 0))
    eyes = eye_w | pupil
    if variant == 'B':  ## kenar ışığı: üstü/solu/sağı boş olan gövde pikseli
        rim = al & ~(shift(al, 0, 1) & shift(al, 1, 0) & shift(al, -1, 0))
        new[rim] = RIM_B * (0.72 + 0.28 * pulse)
    halo = dilate4(eyes) & al & ~eyes
    k = 0.42 * (0.7 + 0.3 * pulse)
    new[halo] = new[halo] * (1.0 - k) + HALO[variant] * k
    new[eyes] = 255.0
    out = np.zeros_like(a)
    out[..., :3] = rgb * (1.0 - amount) + new * amount
    out[..., 3] = a[..., 3]
    if variant == 'A':  ## gövdenin dışında 1 piksel kızıl ışıma
        glow = dilate4(al) & ~al
        out[glow, :3] = GLOW_A
        out[glow, 3] = 150.0 * amount * (0.6 + 0.4 * pulse)
    if glint > 0.0 and amount >= 1.0:  ## göz çakması: yatayda 1 piksel beyaz, dikeyde soluk
        side = (shift(eyes, 1, 0) | shift(eyes, -1, 0)) & ~eyes
        vert = (shift(eyes, 0, 1) | shift(eyes, 0, -1)) & ~eyes & ~side
        for m, col, kk in ((side, np.array([255.0, 255.0, 255.0]), glint), (vert, np.array([255.0, 214.0, 210.0]), 0.6 * glint)):
            base = np.where(out[..., 3:4] > 0, out[..., :3], col)
            out[..., :3] = np.where(m[..., None], base * (1.0 - kk) + col * kk, out[..., :3])
            out[..., 3] = np.where(m, np.maximum(out[..., 3], 255.0 * kk), out[..., 3])
    return to_img(out)


def put_char(dst, fr, cx, cy, mult=1.0):
    """Karakter kökü (cx, cy): kare pikseli (24, 25.8). Altına piksel elips ayak gölgesi."""
    size = int(round(48 * S * mult))
    feet = cy + (40.5 - 25.8) * S * mult
    rx, ry = 9.5 * mult, 3.2 * mult
    sh = Image.new('RGBA', (int(rx * 2 + 3), int(ry * 2 + 3)), (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse((0, 0, sh.width - 1, sh.height - 1), fill=(34, 52, 26, 96))
    sh = sh.resize((sh.width * S, sh.height * S), Image.NEAREST)
    comp(dst, sh, cx - sh.width / 2, feet - sh.height / 2)
    comp(dst, fr.resize((size, size), Image.NEAREST), cx - 24 * S * mult, cy - 25.8 * S * mult)


# ====================================================================== silahlar
## (ikon, Icon ölçeği (tscn), sprite_forward_angle_deg, mirror_icon_when_aiming_left)
WEAPON_DEFS = [
    ('tabanca/icon_v2.png', 0.28875, -13.51, True),
    ('uzunkilic/icon.png', 0.32077, -0.47, False),
    ('tufek/icon.png', 0.35475, -5.74, True),
    ('base_knife/icon_v2.png', 0.2805, -45.25, False),
    ('topuz/icon.png', 0.25900875, -1.31, False),
]
RAMP_WA = [(0.0, (70, 6, 14)), (0.3, (176, 16, 26)), (0.55, (238, 46, 46)), (0.78, (255, 168, 158)), (1.0, (255, 255, 255))]
RAMP_WB = [(0.0, (40, 4, 10)), (0.4, (150, 12, 22)), (0.75, (228, 36, 40)), (1.0, (255, 96, 84))]


def form_weapon(img, variant):
    a = np.array(img, dtype=np.float64)
    t = np.clip((lum(a[..., :3]) - 0.05) / 0.85, 0.0, 1.0)
    a[..., :3] = ramp(t, RAMP_WA if variant == 'A' else RAMP_WB)
    return to_img(a)


class Weapon:
    def __init__(self, path, icon_scale, forward_deg, mirror):
        self.src = Image.open(os.path.join(PROJECT, 'assets', 'weapons', path)).convert('RGBA')
        self.k = icon_scale * 0.9 * 0.85 * 0.5 * W2O  ## kaynak pikseli -> çıktı pikseli (weapon.gd: x0.9, ICON_SIZE_MULT 0.85, kök 0.5)
        self.forward = math.radians(forward_deg)
        self.mirror = mirror
        self.form = {v: form_weapon(self.src, v) for v in 'AB'}

    def render(self, angle, variant=None, mult=1.0, pulse=1.0):
        """angle: namlunun/ucun bakacağı yön (radyan, ekran: +y aşağı). TalonFormationMath.compute_icon_pose ile aynı kural."""
        im = self.form[variant] if variant else self.src
        flip = self.mirror and math.cos(angle) < 0.0
        rot = (angle - math.pi + self.forward) if flip else (angle - self.forward)
        if flip:
            im = ImageOps.mirror(im)
        im = im.rotate(-math.degrees(rot), resample=Image.NEAREST, expand=True)
        k = self.k * mult
        im = im.resize((max(1, int(round(im.width * k))), max(1, int(round(im.height * k)))), Image.NEAREST)
        if variant == 'B':  ## beyaz kontur (oyunda: shader'da alfa komşuluğu)
            a = np.array(im, dtype=np.float64)
            a = np.pad(a, ((1, 1), (1, 1), (0, 0)))
            al = a[..., 3] > 0
            edge = dilate4(al) & ~al
            a[edge, :3] = 255.0
            a[edge, 3] = 235.0 * (0.75 + 0.25 * pulse)
            im = to_img(a)
        return im


_W = None


def weapons():
    global _W
    if _W is None:
        _W = [Weapon(*d) for d in WEAPON_DEFS]
    return _W


def put_center(dst, im, x, y):
    comp(dst, im, x - im.width / 2.0, y - im.height / 2.0)


# ====================================================================== aura (mevcut fx_talon_form sayfaları, kızıl-beyaza boyanmış)
RAMP_AURA = [(0.0, (30, 3, 8)), (0.35, (72, 6, 12)), (0.6, (150, 12, 20)), (0.85, (222, 32, 36)), (1.0, (255, 104, 96))]


def _aura_frames(name, fw, scale):
    sh = Image.open(os.path.join(PROJECT, 'assets', 'fx', 'talon_form', name + '.png')).convert('RGBA')
    a = np.array(sh, dtype=np.float64)
    t = np.clip((lum(a[..., :3]) - 0.12) / 0.8, 0.0, 1.0)
    a[..., :3] = ramp(t, RAMP_AURA)
    sh = to_img(a)
    out = []
    for i in range(sh.width // fw):
        fr = sh.crop((i * fw, 0, i * fw + fw, sh.height))
        out.append(fr.resize((int(round(fr.width * scale)), int(round(fr.height * scale))), Image.NEAREST))
    return out


_AURA = {}


def aura(name, fw, scale=AURA_O):
    if (name, scale) not in _AURA:
        _AURA[(name, scale)] = _aura_frames(name, fw, scale)
    return _AURA[(name, scale)]


def put_aura(dst, cx, cy, t, front):
    """t: form açılalı geçen süre. İlk 0,7 sn "intro" (20 fps), sonra "loop" (11,94 fps) - fx_talon_form.gd ile aynı."""
    if t < 0.0:
        return
    if t < 0.7:
        frames = aura('front_intro' if front else 'back_intro', 184 if front else 112)
        fr = frames[min(len(frames) - 1, int(t * 20.0))]
    else:
        frames = aura('front_loop' if front else 'back_loop', 112)
        fr = frames[int(t * 11.9366) % len(frames)]
    ## Sayfa merkezi köke göre: ön (-0.5, -0.5), arka (-0.5, -26.5) sayfa pikseli.
    oy = -0.5 if front else -26.5
    comp(dst, fr, cx - 0.5 * AURA_O - fr.width / 2.0, cy + oy * AURA_O - fr.height / 2.0)


# ====================================================================== zincir
LINK_DIRS = 32  ## 180 derece üzerinde (halka 180 derece dönünce aynı) -> 5,6 derecelik adım
LINK_SIZE = 13
LINK_C = 6
LINK_PITCH = 4.8  ## halka pikseli: iki halka merkezi arası
LIGHT = (-0.507, -0.862)  ## ışık sol üstten


def _make_links():
    """Her yön için (yüzü dönük oval halka, kenardan görünen halka): gövde maskesi + ton (1.0 parlak / 0.78 orta / 0.55 gölge)."""
    out = []
    sub = [-0.375, -0.125, 0.125, 0.375]
    ys, xs = np.mgrid[0:LINK_SIZE, 0:LINK_SIZE]
    for d in range(LINK_DIRS):
        ang = math.pi * d / LINK_DIRS
        ux, uy = math.cos(ang), math.sin(ang)
        nx, ny = -uy, ux
        cov_o = np.zeros((LINK_SIZE, LINK_SIZE))
        cov_i = np.zeros((LINK_SIZE, LINK_SIZE))
        for sy in sub:
            for sx in sub:
                dx, dy = xs - LINK_C + sx, ys - LINK_C + sy
                al, ac = dx * ux + dy * uy, dx * nx + dy * ny
                outer = (np.abs(al) / 4.3) ** 2.6 + (np.abs(ac) / 2.9) ** 2.6 <= 1.0
                hole = (al / 2.3) ** 2 + (ac / 1.0) ** 2 <= 1.0
                cov_o += outer & ~hole
                ex = np.maximum(np.abs(al) - 2.3, 0.0)
                cov_i += ex * ex + ac * ac <= 1.0
        dx, dy = xs - LINK_C, ys - LINK_C
        lit = dx * LIGHT[0] + dy * LIGHT[1]
        m_o = cov_o >= 8
        tone_o = np.where(lit > 1.1, 1.0, np.where(lit < -1.1, 0.55, 0.78))
        m_i = cov_i >= 8
        side = (dx * nx + dy * ny) * (1.0 if (nx * LIGHT[0] + ny * LIGHT[1]) >= 0.0 else -1.0)
        tone_i = np.where(side >= 0.0, 1.0, 0.6)
        out.append(((m_o, tone_o), (m_i, tone_i)))
    return out


LINKS = _make_links()

## renk şemaları: gövde, nabız ortası, nabız tepesi, kontur
SCHEME_STEEL = {'body': (150, 154, 172), 'mid': (255, 150, 50), 'peak': (255, 244, 204), 'outline': (26, 22, 30)}
SCHEME_FORM = {'body': (182, 20, 28), 'mid': (255, 128, 118), 'peak': (255, 255, 255), 'outline': (18, 4, 8)}


class Rope:
    """Verlet ip: 14 parça, iki ucu sabit (kemer + silah), parçalar uzamaz; hız sönümü = hava direnci. Birimler dünya pikseli."""
    N = 14
    ITER = 6

    def __init__(self, p0, p1, length, bow_dir):
        self.seg = length / self.N
        chord = float(np.hypot(*(p1 - p0)))
        slack = max(length / max(chord, 1.0) - 1.0, 0.0)
        f = np.linspace(0.0, 1.0, self.N + 1)[:, None]
        self.x = p0 + (p1 - p0) * f + bow_dir * (chord * math.sqrt(0.375 * slack)) * 4.0 * f * (1.0 - f)
        for _ in range(40):
            self._solve(p0, p1)
        self.px = self.x.copy()

    def _solve(self, p0, p1):
        x = self.x
        x[0] = p0
        x[-1] = p1
        for i in range(self.N):
            d = x[i + 1] - x[i]
            dist = math.hypot(d[0], d[1]) or 1e-6
            corr = d * (1.0 - self.seg / dist)
            if i == 0:
                x[i + 1] -= corr
            elif i == self.N - 1:
                x[i] += corr
            else:
                x[i] += corr * 0.5
                x[i + 1] -= corr * 0.5

    def step(self, p0, p1, damp):
        v = (self.x - self.px) * (1.0 - damp)
        self.px = self.x.copy()
        self.x = self.x + v
        for _ in range(self.ITER):
            self._solve(p0, p1)

    def curve(self, per=6):
        """Düğümlerden geçen Catmull-Rom eğrisi -> sık örneklenmiş nokta dizisi + birikimli uzunluk."""
        p = np.vstack([self.x[0] * 2 - self.x[1], self.x, self.x[-1] * 2 - self.x[-2]])
        pts = []
        for i in range(1, len(p) - 2):
            for k in range(per):
                u = k / per
                pts.append(0.5 * ((2 * p[i]) + (-p[i - 1] + p[i + 1]) * u + (2 * p[i - 1] - 5 * p[i] + 4 * p[i + 1] - p[i + 2]) * u * u
                                  + (-p[i - 1] + 3 * p[i] - 3 * p[i + 1] + p[i + 2]) * u ** 3))
        pts.append(self.x[-1])
        pts = np.array(pts)
        cum = np.concatenate([[0.0], np.cumsum(np.hypot(*np.diff(pts, axis=0).T))])
        return pts, cum


class ChainLayer:
    """Halka çözünürlüğünde (1 piksel = 1 karakter sanat pikseli) katman: gölge + ortak kontur + gövde; sonra x S büyütülür."""

    def __init__(self, w, h, scheme):
        self.w, self.h = w // S + 2, h // S + 2
        self.scheme = scheme
        self.ol = np.zeros((self.h, self.w), bool)
        self.body = np.zeros((self.h, self.w), bool)
        self.rgb = np.zeros((self.h, self.w, 3))

    def stamp(self, mask, tone, x, y, col):
        x0, y0 = int(round(x)) - LINK_C, int(round(y)) - LINK_C
        if x0 < 1 or y0 < 1 or x0 + LINK_SIZE >= self.w - 1 or y0 + LINK_SIZE >= self.h - 1:
            return
        sl = (slice(y0, y0 + LINK_SIZE), slice(x0, x0 + LINK_SIZE))
        self.ol[sl] |= dilate4(mask)
        self.body[sl] |= mask
        self.rgb[sl] = np.where(mask[..., None], np.array(col)[None, None, :] * tone[..., None], self.rgb[sl])

    def block(self, x, y, r, col):
        x, y = int(round(x)), int(round(y))
        if x - r < 1 or y - r < 1 or x + r + 2 >= self.w or y + r + 2 >= self.h:
            return
        sl = (slice(y - r, y + r + 1), slice(x - r, x + r + 1))
        self.ol[sl] |= True
        if r > 0:
            sl2 = (slice(y - r + 1, y + r), slice(x - r + 1, x + r))
            self.body[sl2] = True
            self.rgb[sl2] = col

    def add_chain(self, rope, extent, t, j, to_px):
        """rope dünya pikselinde; to_px(nokta) -> katman pikseli. extent 0..1: merkezden dışa açılan kısım."""
        sc = self.scheme
        pts, cum = rope.curve()
        total = cum[-1]
        pitch = LINK_PITCH * ART_WORLD
        count = int(total * extent / pitch)
        pulse_f = (t * 1.5 + j * 0.27) % 1.0
        stamps = []
        for i in range(count):
            sd = (i + 0.5) * pitch
            k = min(int(np.searchsorted(cum, sd)), len(pts) - 1)
            k = max(k, 1)
            seg = max(cum[k] - cum[k - 1], 1e-6)
            c = pts[k - 1] + (pts[k] - pts[k - 1]) * ((sd - cum[k - 1]) / seg)
            tan = pts[k] - pts[k - 1]
            d_i = int(round(math.atan2(tan[1], tan[0]) / (math.pi / LINK_DIRS))) % LINK_DIRS
            f = sd / max(total, 1.0)
            dp = min(abs(f - pulse_f), 1.0 - abs(f - pulse_f))
            heat = max(0.0, 1.0 - dp / 0.1)
            col = np.array(sc['body'], dtype=float)
            if heat > 0.0:
                col = col + (np.array(sc['mid']) - col) * min(1.0, heat * 2.0)
                if heat > 0.5:
                    col = col + (np.array(sc['peak']) - col) * (heat * 2.0 - 1.0)
            stamps.append((i % 2, to_px(c), d_i, col))
        for kind in (0, 1):  ## önce yüzü dönük ovaller, üstüne kenardan görünen halkalar (deliklerden geçer)
            for (kd, p, d_i, col) in stamps:
                if kd == kind:
                    m, tone = LINKS[d_i][kind]
                    self.stamp(m, tone, p[0], p[1], col)
        if extent >= 0.999:  ## silah ucundaki kelepçe
            p = to_px(pts[-1])
            self.block(p[0], p[1], 2, sc['body'])
            self.block(p[0], p[1], 0, sc['peak'])
            self.rgb[int(round(p[1])), int(round(p[0]))] = sc['peak']
        elif stamps:  ## uzarken/toplanırken uçta akkor nokta
            p = stamps[-1][1]
            self.block(p[0], p[1], 1, sc['peak'])

    def image(self):
        a = np.zeros((self.h, self.w, 4))
        shadow = shift(self.ol, 0, 3) & ~self.ol
        a[shadow] = (30, 44, 22, 84)
        a[self.ol & ~self.body] = tuple(self.scheme['outline']) + (255,)
        a[self.body, :3] = self.rgb[self.body]
        a[self.body, 3] = 255
        im = to_img(a)
        return im.resize((im.width * S, im.height * S), Image.NEAREST)


BELT_OFF = np.array([0.0, -6.0])  ## dünya pikseli: zincirlerin bağlandığı bel noktası (fx_talon_chains.gd origin)
BELT_R = 7.5  ## bel halkası yarı eni (dünya pikseli); yarı boyu BELT_RY (yukarıdan bakış -> basık oval)
BELT_RY = 3.6
TIP_INSET = 10.0  ## zincir silah merkezinin bu kadar içinde biter (silahın iç ucu)


class Salvo:
    """Bir Silah Salvosu: count silah yarıçapta döner, her birine bir ip. Zaman adımı 1/125 sn (oyunda 2 alt adım/kare)."""
    SUB = 5

    def __init__(self, count, slack, damp, a0=-TAU / 4):
        self.count, self.damp, self.a0 = count, damp, a0
        self.t = 0.0
        self.length = (SALVO_RADIUS - TIP_INSET - BELT_R) * (1.0 + slack)
        self.ropes = []
        for i in range(count):
            p0, p1, ang = self.anchors(i)
            self.ropes.append(Rope(p0, p1, self.length, -np.array([-math.sin(ang), math.cos(ang)])))

    def angle(self, i):
        return self.a0 + self.t * SALVO_SPEED + TAU * i / self.count

    def weapon_pos(self, i):
        a = self.angle(i)
        return np.array([math.cos(a), math.sin(a)]) * SALVO_RADIUS

    def anchors(self, i):
        a = self.angle(i)
        wp = self.weapon_pos(i)
        d = (wp - BELT_OFF)
        d = d / np.hypot(*d)
        return BELT_OFF + np.array([d[0] * BELT_R, d[1] * BELT_RY]), wp - d * TIP_INSET, a

    def advance(self, dt):
        for _ in range(self.SUB):
            self.t += dt / self.SUB
            for i, r in enumerate(self.ropes):
                p0, p1, _a = self.anchors(i)
                r.step(p0, p1, self.damp)


def draw_salvo(dst, cx, cy, salvo, extent, scheme, front):
    """front=False: silahı karakterin üstünde (kuzeyinde) kalan zincirler (karakterin arkasına); True: güneydekiler (önüne)."""
    ly = ChainLayer(dst.width, dst.height, scheme)

    def to_px(p):
        return ((cx + p[0] * W2O) / S, (cy + p[1] * W2O) / S)

    any_chain = False
    for i, r in enumerate(salvo.ropes):
        if (salvo.weapon_pos(i)[1] > BELT_OFF[1]) != front:
            continue
        ly.add_chain(r, extent, salvo.t, i, to_px)
        any_chain = True
    if extent > 0.0:  ## bel halkası: arka yarısı karakterin arkasında, ön yarısı önünde
        for k in range(40):
            a = TAU * k / 40.0
            if (math.sin(a) > 0.0) != front:
                continue
            p = to_px(BELT_OFF + np.array([math.cos(a) * BELT_R, math.sin(a) * BELT_RY]))
            ly.block(p[0], p[1], 1, scheme['body'])
            ly.rgb[int(round(p[1])), int(round(p[0]))] = np.array(scheme['body']) * (1.0 if front else 0.6)
        any_chain = True
    if any_chain:
        comp(dst, ly.image(), 0, 0)


def rest_pose(i, n):
    """Yetenek yokken silahlar: başın üstünde yelpaze (temsili)."""
    return np.array([(i - (n - 1) / 2.0) * 16.0, -40.0 - 4.0 * math.cos((i - (n - 1) / 2.0) * 0.9)]), -TAU / 4 + (i - (n - 1) / 2.0) * 0.28


def idle_frame(t, row=0):
    return cell(IDLE, int(t * 5.0) % 4, row)


# ====================================================================== sahne 1: E (normal form)
def scene_e():
    W = 660
    variants = [('A · Oval yay', 0.10, 0.07), ('B · Girdap', 0.28, 0.07)]
    pre, post = 0.32, 0.6
    n = int((pre + SALVO_DURATION + RETRACT_TIME + post) * FPS)
    ws = weapons()
    frames = []
    salvos = [Salvo(5, sl, dm) for (_n, sl, dm) in variants]
    for fi in range(n):
        t = fi / FPS - pre
        canvas = Image.new('RGBA', (W * 2, W), (0, 0, 0, 255))
        for vi, (name, _sl, _dm) in enumerate(variants):
            pan = grass(W, W)
            cx, cy = W // 2, W // 2 + 8
            sv = salvos[vi]
            active = 0.0 <= t < SALVO_DURATION + RETRACT_TIME
            if active and fi > 0:
                sv.advance(1.0 / FPS)
            extent = 0.0
            if active:
                extent = min(1.0, t / GROW_TIME, max(0.0, (SALVO_DURATION + RETRACT_TIME - t) / RETRACT_TIME))
            if active:
                draw_salvo(pan, cx, cy, sv, extent, SCHEME_STEEL, False)
            put_char(pan, idle_frame(fi / FPS), cx, cy)
            if active:
                draw_salvo(pan, cx, cy, sv, extent, SCHEME_STEEL, True)
            for i, w in enumerate(ws):
                if active:
                    p, a = sv.weapon_pos(i), sv.angle(i)
                else:
                    p, a = rest_pose(i, len(ws))
                put_center(pan, w.render(a), cx + p[0] * W2O, cy + p[1] * W2O)
            label(pan, 10, 8, name)
            canvas.paste(pan, (vi * W, 0))
        frames.append(canvas)
    save_gif('talon_e_zincir.gif', frames, int(1000 / FPS))
    return frames


# ====================================================================== sahne 2/3: R formu (+E)
def _pulse(t):
    return 0.5 + 0.5 * math.sin(t * 5.0)


def _glint(t):
    """1,3 sn'de bir kısa göz çakması (0,16 sn)."""
    k = (t % 1.3) / 0.16
    return math.sin(k * math.pi) if k < 1.0 else 0.0


def scene_r():
    W = 580
    pre = 0.6
    n = int((pre + 3.2) * FPS)
    ws = weapons()
    frames = []
    for fi in range(n):
        t = fi / FPS - pre  ## form açılalı geçen süre
        canvas = Image.new('RGBA', (W * 2, W), (0, 0, 0, 255))
        for vi, v in enumerate('AB'):
            pan = grass(W, W)
            cx, cy = W // 2, W // 2 + 14
            on = t >= 0.0
            amount = min(1.0, max(0.0, t / 0.25))
            mult = 1.0 + (FORM_SCALE - 1.0) * amount
            if on:
                put_aura(pan, cx, cy, t, False)
            fr = idle_frame(fi / FPS)
            if on:
                fr = form_char(fr, v, amount, _pulse(t), _glint(t))
            put_char(pan, fr, cx, cy, mult)
            if on:
                put_aura(pan, cx, cy, t, True)
            if on:
                cnt = len(ws) * 2
                rr = MIRROR_RADIUS * min(1.0, 0.25 + t / 0.2)
                for i in range(cnt):
                    a = -TAU / 4 + TAU * i / cnt
                    bob = math.sin(t * 2.4 + i * 1.1) * 1.5
                    im = ws[i % len(ws)].render(a, v if amount >= 0.5 else None, mult, _pulse(t + i * 0.4))
                    put_center(pan, im, cx + math.cos(a) * rr * W2O, cy + (math.sin(a) * rr + bob) * W2O)
            else:
                for i, w in enumerate(ws):
                    p, a = rest_pose(i, len(ws))
                    put_center(pan, w.render(a), cx + p[0] * W2O, cy + p[1] * W2O)
            label(pan, 10, 8, 'A · Kızıl' if v == 'A' else 'B · Gölge')
            canvas.paste(pan, (vi * W, 0))
        frames.append(canvas)
    save_gif('talon_r_form.gif', frames, int(1000 / FPS))
    return frames


def scene_r_e():
    W = 680
    variants = [('A', 'A · Kızıl + oval yay', 0.10), ('B', 'B · Gölge + girdap', 0.28)]
    pre, post = 0.3, 0.5
    n = int((pre + SALVO_DURATION + RETRACT_TIME + post) * FPS)
    ws = weapons()
    cnt = len(ws) * 2
    salvos = [Salvo(cnt, sl, 0.07) for (_v, _n, sl) in variants]
    frames = []
    for fi in range(n):
        t = fi / FPS - pre
        tf = fi / FPS + 2.0  ## form zaten açık
        canvas = Image.new('RGBA', (W * 2, W), (0, 0, 0, 255))
        for vi, (v, name, _sl) in enumerate(variants):
            pan = grass(W, W)
            cx, cy = W // 2, W // 2 + 8
            sv = salvos[vi]
            active = 0.0 <= t < SALVO_DURATION + RETRACT_TIME
            if active and fi > 0:
                sv.advance(1.0 / FPS)
            extent = min(1.0, t / GROW_TIME, max(0.0, (SALVO_DURATION + RETRACT_TIME - t) / RETRACT_TIME)) if active else 0.0
            put_aura(pan, cx, cy, tf, False)
            if active:
                draw_salvo(pan, cx, cy, sv, extent, SCHEME_FORM, False)
            put_char(pan, form_char(idle_frame(fi / FPS), v, 1.0, _pulse(tf), _glint(tf)), cx, cy, FORM_SCALE)
            put_aura(pan, cx, cy, tf, True)
            if active:
                draw_salvo(pan, cx, cy, sv, extent, SCHEME_FORM, True)
            for i in range(cnt):
                if active:
                    p, a = sv.weapon_pos(i), sv.angle(i)
                else:
                    a = -TAU / 4 + TAU * i / cnt
                    p = np.array([math.cos(a), math.sin(a)]) * MIRROR_RADIUS
                im = ws[i % len(ws)].render(a, v, FORM_SCALE, _pulse(tf + i * 0.4))
                put_center(pan, im, cx + p[0] * W2O, cy + p[1] * W2O)
            label(pan, 10, 8, name)
            canvas.paste(pan, (vi * W, 0))
        frames.append(canvas)
    save_gif('talon_r_e.gif', frames, int(1000 / FPS))
    return frames


# ====================================================================== yakın plan sayfası
def close_sheet():
    Z = 5
    cw = 48 * Z
    ws = weapons()
    wk = 2.0  ## silahlar oyun boyutunun 2 katı
    wcell = 150
    rows = [('Şu anki', None), ('A · Kızıl', 'A'), ('B · Gölge', 'B')]
    Wd = 3 * cw + len(ws) * wcell + 30
    sheet = Image.new('RGBA', (Wd, len(rows) * cw), GRASS + (255,))
    sheet.paste(grass(Wd, len(rows) * cw), (0, 0))
    for ri, (name, v) in enumerate(rows):
        y = ri * cw
        for ci, row in enumerate((0, 2, 3)):  ## aşağı, sağ, yukarı
            fr = cell(IDLE, 0, row)
            if v:
                fr = form_char(fr, v, 1.0, 1.0, 0.0)
            comp(sheet, fr.resize((cw, cw), Image.NEAREST), ci * cw, y)
        for wi, w in enumerate(ws):
            im = w.render(-0.5, v, wk, 1.0)
            put_center(sheet, im, 3 * cw + 20 + wi * wcell + wcell // 2, y + cw // 2)
        label(sheet, 8, y + 6, name, 19)
    sheet.convert('RGB').save(os.path.join(OUT, 'talon_r_yakin.png'))


# ====================================================================== R: arkadaki alev yerine partikül (yakın plan)
## Kullanıcı (2026-10-12): "arkasındaki ateş efekti yerine partikül tarzı basit bir efekt istiyorum". Arka katman (alev + noktalı ışıma diski)
## tamamen kalkar; yerine birkaç pikselden oluşan partiküller gelir. Ön katmandaki zikzak çizgiler alevsiz tek başına tuhaf durduğu için
## o da kalkar; gövdedeki "+" parıltıları partikül olarak yeniden yapılır (Twinkles). Dönüşüm anı: beyaz siluet çakması + dışa saçılan pikseller.
## Birimler karakter sanat pikseli, kök (0,0) = karakter kökü; renk yaşa göre BASAMAKLI (yumuşak saydamlık yok - piksel sanatı).
P_COLS = [(255, 96, 84), (214, 30, 34), (120, 10, 18), (40, 4, 10)]
P_WHITE = (255, 240, 236)


def _p_color(k, white):
    if k < 0.25:
        return P_WHITE if white else P_COLS[0]
    return P_COLS[1] if k < 0.6 else (P_COLS[2] if k < 0.85 else P_COLS[3])


class Embers:
    """P1 · Yükselen kor: ayak/bel çevresinden doğup hafif salınarak yükselen pikseller (sn'de 26, ömür 0,9-1,4 sn -> aynı anda ~30; %35'i gövdenin önünde)."""
    RATE = 26.0

    def __init__(self, seed):
        self.rng = random.Random(seed)
        self.acc = 0.0
        self.ps = []

    def step(self, dt, emitting):
        self.acc += dt * self.RATE if emitting else 0.0
        while self.acc >= 1.0:
            self.acc -= 1.0
            r = self.rng
            self.ps.append({'x': r.uniform(-17, 17), 'y': r.uniform(6, 15), 'vy': -r.uniform(24, 40), 'amp': r.uniform(1.0, 2.5),
                            'fr': r.uniform(3, 5), 'ph': r.uniform(0, TAU), 'life': r.uniform(0.9, 1.4), 'age': 0.0,
                            'white': r.random() < 0.15, 'big': r.random() < 0.7, 'front': r.random() < 0.35})
        for q in self.ps:
            q['age'] += dt
        self.ps = [q for q in self.ps if q['age'] < q['life']]

    def items(self, _t):
        out = []
        for q in self.ps:
            k = q['age'] / q['life']
            x = q['x'] + q['amp'] * math.sin(q['fr'] * q['age'] + q['ph'])
            y = q['y'] + q['vy'] * q['age'] * (1.0 - 0.25 * k)
            out.append((x, y, 2 if (q['big'] and k < 0.7) else 1, _p_color(k, q['white']), q['front']))
        return out


class Helix:
    """P2 · Dönen zerreler: 16 piksel gövdenin etrafında oval bir sarmalda dönerek ayaktan başa yükselir; yarısı önde, yarısı arkada."""
    N = 16

    def step(self, dt, emitting):
        pass

    def items(self, t):
        out = []
        for i in range(self.N):
            h = (t * 0.55 + i / self.N) % 1.0
            if h * 1.8 > t or h > 0.95:  ## form yeni açıldıysa henüz doğmamış olanlar
                continue
            th = i * 2.4 + t * 3.2
            x = 15.0 * math.cos(th) * (1.0 - 0.25 * h)
            y = 14.0 - 38.0 * h + 4.5 * math.sin(th)
            out.append((x, y, 2 if h < 0.6 else 1, _p_color(h, i % 4 == 0), math.sin(th) > 0.0))
        return out


class Twinkles:
    """Gövdenin önünde ara ara beliren beyaz "+" parıltısı (0,22 sn'de bir, 0,3 sn sürer) - eski ön katmandaki parıltıların yerine."""

    def __init__(self, seed):
        self.rng = random.Random(seed)
        self.acc = 0.0
        self.ps = []

    def step(self, dt, emitting):
        self.acc += dt if emitting else 0.0
        while self.acc >= 0.22:
            self.acc -= 0.22
            self.ps.append([self.rng.uniform(-7, 7), self.rng.uniform(-18, 12), 0.0])
        for q in self.ps:
            q[2] += dt
        self.ps = [q for q in self.ps if q[2] < 0.3]

    def items(self):
        out = []
        for (x, y, age) in self.ps:
            out.append((x, y, 1, (255, 255, 255), True))
            if 0.25 < age / 0.3 < 0.75:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    out.append((round(x) + dx, round(y) + dy, 1, (255, 204, 198), True))
        return out


def _burst(t):
    """Dönüşüm anı (iki seçenekte de): merkezden dışa saçılan 28 piksel, 0,45 sn."""
    if not (0.0 <= t < 0.45):
        return []
    k = t / 0.45
    e = 1.0 - (1.0 - k) ** 3
    out = []
    for i in range(28):
        a = TAU * i / 28.0 + (i % 3) * 0.11
        r = 6.0 + (26.0 + 10.0 * (i % 2)) * e
        out.append((math.cos(a) * r, -6.0 + math.sin(a) * r * 0.8, 2 if k < 0.6 else 1, _p_color(k, i % 5 == 0), math.sin(a) > 0.0))
    return out


def scene_r_particles():
    Z = 4
    CW, CH = 100, 112  ## hücre (karakter sanat pikseli)
    pre = 0.5
    n = int((pre + 3.6) * FPS)
    rows = [('P1 · Yükselen kor', lambda: Embers(7)), ('P2 · Dönen zerreler', lambda: Helix())]
    sims = [[mk(), mk()] for (_n, mk) in rows]
    twk = [[Twinkles(3), Twinkles(3)] for _r in rows]
    frames = []
    for fi in range(n):
        t = fi / FPS - pre
        canvas = grass(CW * Z * 2, CH * Z * 2)
        for ri, (rname, _mk) in enumerate(rows):
            for vi, v in enumerate('AB'):
                ox, oy = vi * CW * Z, ri * CH * Z
                cx, cy = ox + CW * Z // 2, oy + 68 * Z
                on = t >= 0.0
                amount = min(1.0, max(0.0, t / 0.25))
                mult = 1.0 + (FORM_SCALE - 1.0) * amount
                sim = sims[ri][vi]
                if fi > 0:
                    sim.step(1.0 / FPS, on)
                    twk[ri][vi].step(1.0 / FPS, on and t > 0.3)
                parts = (sim.items(t) + _burst(t) + twk[ri][vi].items()) if on else []

                def draw_parts(front):
                    d = ImageDraw.Draw(canvas)
                    for (x, y, sz, col, fr_flag) in parts:
                        if fr_flag != front:
                            continue
                        px = cx + int(round(x * mult)) * Z
                        py = cy + int(round(y * mult)) * Z
                        if ox <= px and px + sz * Z <= ox + CW * Z and oy <= py and py + sz * Z <= oy + CH * Z:
                            d.rectangle((px, py, px + sz * Z - 1, py + sz * Z - 1), fill=col + (255,))

                ## ayak gölgesi + arka partiküller + karakter + ön katman + ön partiküller
                feet = cy + (40.5 - 25.8) * Z * mult
                sh = Image.new('RGBA', (int(19 * mult) * Z, int(6 * mult) * Z), (0, 0, 0, 0))
                ImageDraw.Draw(sh).ellipse((0, 0, sh.width - 1, sh.height - 1), fill=(34, 52, 26, 96))
                comp(canvas, sh, cx - sh.width / 2, feet - sh.height / 2)
                draw_parts(False)
                fr = idle_frame(fi / FPS)
                if on:
                    fr = form_char(fr, v, amount, _pulse(t), _glint(t))
                    if t < 0.09:  ## dönüşüm çakması: beyaz siluet
                        fa = np.array(fr)
                        fa[fa[..., 3] > 0, :3] = (255, 236, 232)
                        fr = Image.fromarray(fa, 'RGBA')
                size = int(round(48 * Z * mult))
                comp(canvas, fr.resize((size, size), Image.NEAREST), cx - 24 * Z * mult, cy - 25.8 * Z * mult)
                draw_parts(True)
                label(canvas, ox + 8, oy + 6, '%s  |  %s' % (rname, 'A · Kızıl' if v == 'A' else 'B · Gölge'), 15)
        frames.append(canvas)
    save_gif('talon_r_partikul.gif', frames, int(1000 / FPS))
    tmp = os.path.join(os.environ.get('TEMP', OUT), 'claude_talon')
    os.makedirs(tmp, exist_ok=True)
    frames[int((pre + 2.0) * FPS)].convert('RGB').save(os.path.join(tmp, 'p_mid.png'))
    frames[int((pre + 0.2) * FPS)].convert('RGB').save(os.path.join(tmp, 'p_intro.png'))


def main():
    if 'partikul' in sys.argv[1:]:
        scene_r_particles()
        return
    close_sheet()
    fe = scene_e()
    fr = scene_r()
    fre = scene_r_e()
    ## Hızlı bakış kareleri (doğrulama için; kullanıcıya GIF gösterilir)
    tmp = os.path.join(os.environ.get('TEMP', OUT), 'claude_talon')
    os.makedirs(tmp, exist_ok=True)
    fe[int(1.6 * FPS)].convert('RGB').save(os.path.join(tmp, 'e_mid.png'))
    fe[int(0.42 * FPS)].convert('RGB').save(os.path.join(tmp, 'e_start.png'))
    fr[int(2.4 * FPS)].convert('RGB').save(os.path.join(tmp, 'r_mid.png'))
    fr[int(0.75 * FPS)].convert('RGB').save(os.path.join(tmp, 'r_intro.png'))
    fre[int(1.8 * FPS)].convert('RGB').save(os.path.join(tmp, 're_mid.png'))
    scene_r_particles()


if __name__ == '__main__':
    main()
