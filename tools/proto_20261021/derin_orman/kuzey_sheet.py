# DERİN ORMAN kuzey prototipi - karşılaştırma sayfaları (oyuna bağlı DEĞİL). kuzey_run.ps1 yakalamalarını okur.
# Her çekim: ekran görüntüsü (2560x1440, 2,67 ekran px / dünya px) dünya pikseline örneklenir (her dünya pikselinin ortası) -> 1 px = 1 dünya px.
# Bölge maskesi (kuzey_mask.png, hücre başına 1 px) 2 hücre genişletilip yumuşatılır -> renk ayarı/sis/ışık geçitte yavaşça başlar.
# Karakter pikselleri = char_ ile base_ farkı; renk ayarının ÜSTÜNE tam renk konur (oyunda da ayar sadece haritaya uygulanacak).
#   a "Solgun Orman": doygunluk %52, soğuk camgöbeği-gri ton, %16 koyu + seyrek yer sisi (en çok %22, dither'lı yumuşak bulut, kontursuz)
#   b "Kadim Kara Orman": %55-68 koyu, derin yeşil-camgöbeği, gölge lekeleri; ışıyan mantar/bitki pikselleri karanlıktan muaf + ruh ışıkları
# Çıktı: out/karsilastirma_<çekim>.png (Şu an / A / B alt alta, 1x) + out/oyun_<çeşit>_<çekim>.png (2x = 1080p oyun görünüşü)
# Kullanım: python tools/proto_20261021/derin_orman/kuzey_sheet.py
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'out')
SHOTS = ['gecit', 'derin']
LABELS = {'simdi': 'ŞU AN', 'a': 'A - Solgun Orman', 'b': 'B - Kadim Kara Orman'}
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], dtype=np.float32) / 16.0


def world_sample(path, ox, oy, s):
    im = np.asarray(Image.open(path).convert('RGB')).astype(np.float32) / 255.0
    h, w = im.shape[:2]
    p = s / 16.0
    k0x = int(np.ceil(-ox / p))
    k0y = int(np.ceil(-oy / p))
    nx = int((w - (ox + k0x * p)) // p)
    ny = int((h - (oy + k0y * p)) // p)
    xs = (ox + (k0x + np.arange(nx) + 0.5) * p).astype(int)
    ys = (oy + (k0y + np.arange(ny) + 0.5) * p).astype(int)
    return im[ys][:, xs], k0x, k0y


def zone_world(k0x, k0y, w, h):
    m = Image.open(os.path.join(OUT, 'kuzey_mask.png')).convert('L')
    m = m.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(2.2))
    m = np.asarray(m).astype(np.float32) / 255.0
    cx = (k0x + np.arange(w) + 0.5) / 16.0 - 0.5
    cy = (k0y + np.arange(h) + 0.5) / 16.0 - 0.5
    x0 = np.clip(np.floor(cx).astype(int), 0, 254)
    y0 = np.clip(np.floor(cy).astype(int), 0, 254)
    fx = np.clip(cx - x0, 0, 1)[None, :]
    fy = np.clip(cy - y0, 0, 1)[:, None]
    a = m[y0][:, x0]
    b = m[y0][:, x0 + 1]
    c = m[y0 + 1][:, x0]
    d = m[y0 + 1][:, x0 + 1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def value_noise(k0x, k0y, w, h, cell, seed):
    gx = (k0x + np.arange(w)) / cell
    gy = (k0y + np.arange(h)) / cell
    ix = np.floor(gx).astype(int)
    iy = np.floor(gy).astype(int)
    fx = gx - ix
    fy = gy - iy
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)

    def hsh(x, y):
        v = np.sin(x[None, :] * 127.1 + y[:, None] * 311.7 + seed * 74.7) * 43758.5453
        return v - np.floor(v)
    a = hsh(ix, iy)
    b = hsh(ix + 1, iy)
    c = hsh(ix, iy + 1)
    d = hsh(ix + 1, iy + 1)
    return (a * (1 - fx[None, :]) + b * fx[None, :]) * (1 - fy[:, None]) + (c * (1 - fx[None, :]) + d * fx[None, :]) * fy[:, None]


def luma(c):
    return c[..., 0] * 0.299 + c[..., 1] * 0.587 + c[..., 2] * 0.114


def glow_mask(c):
    # ışıyan mantar/bitki: mavi-camgöbeği-mor ya da turuncu, doygun ve parlak pikseller
    mx = c.max(-1)
    mn = c.min(-1)
    sat = (mx - mn) / np.maximum(mx, 1e-4)
    r, g, b = c[..., 0], c[..., 1], c[..., 2]
    blue = (b > r + 0.12) & (b > g - 0.05)
    orange = (r > 0.75) & (g > 0.35) & (b < 0.35) & (r > g + 0.2)
    return ((blue | orange) & (sat > 0.45) & (mx > 0.55)).astype(np.float32)


def grade_a(c, z, k0x, k0y):
    l = luma(c)[..., None]
    g = l + (c - l) * 0.52
    g = g * np.array([0.88, 0.97, 1.0]) * 0.84 + np.array([0.01, 0.02, 0.03])
    out = c + (np.clip(g, 0, 1) - c) * z[..., None]
    # yer sisi: iki katlı gürültü, yumuşak eşik, en çok %30, 4x4 Bayer dither (kontursuz yumuşak bulut)
    h, w = z.shape
    n = value_noise(k0x, k0y, w, h, 70.0, 3) * 0.65 + value_noise(k0x, k0y, w, h, 26.0, 9) * 0.35
    a = np.clip((n - 0.54) / 0.2, 0, 1) * 0.22 * z
    yy, xx = np.mgrid[0:h, 0:w]
    thr = BAYER[(yy + k0y) % 4, (xx + k0x) % 4]
    a = np.where(a * 3.0 > thr, a, a * 0.45)
    fog = np.array([0.70, 0.75, 0.78])
    return out + (fog - out) * a[..., None]


def grade_b(c, z, k0x, k0y):
    h, w = z.shape
    l = luma(c)[..., None]
    g = l + (c - l) * 0.85
    shade = 0.55 + 0.13 * value_noise(k0x, k0y, w, h, 60.0, 5)
    g = g * np.array([0.78, 0.98, 0.98]) * shade[..., None]
    g = np.clip(g, 0, 1) ** 1.08 + np.array([0.004, 0.012, 0.022])
    keep = glow_mask(c)
    keep = np.clip(np.asarray(Image.fromarray((keep * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3))) / 255.0, 0, 1)
    wgt = z * (1.0 - keep * 0.8)
    out = c + (np.clip(g, 0, 1) - c) * wgt[..., None]
    # ışıyan piksellerin çevresine hafif hale
    halo = np.asarray(Image.fromarray((keep * z * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(4))).astype(np.float32) / 255.0
    out = out + halo[..., None] * np.array([0.10, 0.22, 0.26]) * 0.5
    # ruh ışıkları: bölge içinde sabit tohumla dağılmış küçük çekirdek + yumuşak hale (dünya konumlu)
    rng = np.random.default_rng(11)
    lay = np.zeros((h, w), np.float32)
    for _ in range(400):
        wx, wy = rng.uniform(1280, 2800), rng.uniform(0, 900)
        x, y = int(wx - k0x), int(wy - k0y)
        if 0 <= x < w and 0 <= y < h and z[y, x] > 0.7 and rng.random() < 0.35:
            lay[y, x] = 1.0
    core = np.asarray(Image.fromarray((lay * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3))).astype(np.float32) / 255.0
    soft = np.asarray(Image.fromarray((core * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(5))).astype(np.float32) / 255.0
    out = out + soft[..., None] * np.array([0.35, 0.95, 0.80]) * 1.6 + core[..., None] * np.array([0.55, 0.95, 0.85])
    return np.clip(out, 0, 1)


def render(variant, shot):
    d = os.path.join(OUT, variant)
    ox, oy, s = [float(v) for v in open(os.path.join(d, f'meta_{shot}.txt')).read().split(',')]
    base, k0x, k0y = world_sample(os.path.join(d, f'base_{shot}.png'), ox, oy, s)
    char, _, _ = world_sample(os.path.join(d, f'char_{shot}.png'), ox, oy, s)
    cm = (np.abs(char - base).max(-1) > 0.02)
    h, w = base.shape[:2]
    z = zone_world(k0x, k0y, w, h)
    if variant == 'a':
        out = grade_a(base, z, k0x, k0y)
    elif variant == 'b':
        out = grade_b(base, z, k0x, k0y)
    else:
        out = base
    out = np.where(cm[..., None], char, out)
    return Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8))


def main():
    try:
        font = ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf', 20)
    except OSError:
        font = ImageFont.load_default()
    for shot in SHOTS:
        panels = []
        for v in ['simdi', 'a', 'b']:
            if not os.path.exists(os.path.join(OUT, v, f'meta_{shot}.txt')):
                continue
            im = render(v, shot)
            im.resize((im.width * 2, im.height * 2), Image.NEAREST).save(os.path.join(OUT, f'oyun_{v}_{shot}.png'))
            dr = ImageDraw.Draw(im)
            dr.text((10, 8), LABELS[v], font=font, fill=(255, 245, 210), stroke_width=3, stroke_fill=(20, 16, 12))
            panels.append(im)
        sheet = Image.new('RGB', (panels[0].width, sum(p.height for p in panels) + 6 * (len(panels) - 1)), (20, 16, 12))
        y = 0
        for p in panels:
            sheet.paste(p, (0, y))
            y += p.height + 6
        sheet.save(os.path.join(OUT, f'karsilastirma_{shot}.png'))
        print('sayfa', shot, sheet.size)


if __name__ == '__main__':
    main()
