# PANEL DOKUSU prototipleri (2026-11-13, oyuna bağlı DEĞİL).
# Kullanıcı: arayüz renk/tasarımı kalsın, düz zemin "kusursuz ve ruhsuz" -> hafif piksel sanatı doku. 4 yön:
#   A Ahşap Tahta (geniş tahtalar + damar + budak), B Taş Duvar (sıralı taşlar), C Kilim (kabartma baklava kafes), D Eski Deri (lekeler + kırışık).
# Her karo sanat pikselinde (1 sanat px = 3 ekran px, stil rehberi) ve SARMALI (döşenince ek yeri görünmez).
# Renk: yeni hex YOK - yalnız hud_theme rolleri: açık = RIM_HI (#86623f) düşük alfa, koyu = DEEP (#140e09) alfa.
# Karo "gölge" değerleri s in [-1, 1] (0,25 adımlı bantlar, dither yok) -> RGBA.
# Çıktı: out/tiles/doku_{a,b,c,d}.png (+ _x4 önizleme). Kullanım: python gen_panel_doku.py
import os
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out", "tiles")
os.makedirs(OUT, exist_ok=True)

RIM_HI = (0x86, 0x62, 0x3F)
DEEP = (0x14, 0x0E, 0x09)
LIGHT_A = 0.20  # s = +1 -> RIM_HI bu alfada
DARK_A = 0.55   # s = -1 -> DEEP bu alfada


def to_rgba(s: np.ndarray, light_a=LIGHT_A, dark_a=DARK_A) -> Image.Image:
    s = np.clip(np.round(s * 4) / 4, -1, 1)  # 0,25 bantları
    h, w = s.shape
    out = np.zeros((h, w, 4), np.uint8)
    pos = s > 0
    neg = s < 0
    out[pos, :3] = RIM_HI
    out[pos, 3] = np.round(s[pos] * light_a * 255).astype(np.uint8)
    out[neg, :3] = DEEP
    out[neg, 3] = np.round(-s[neg] * dark_a * 255).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def save(name, s, **kw):
    im = to_rgba(s, **kw)
    im.save(os.path.join(OUT, name + ".png"))
    # önizleme: ortalama panel zemini (#271a11) üstünde x4, 2x2 döşenmiş
    bg = Image.new("RGBA", (im.width * 2, im.height * 2), (0x27, 0x1A, 0x11, 255))
    for yy in range(2):
        for xx in range(2):
            bg.alpha_composite(im, (xx * im.width, yy * im.height))
    bg = bg.resize((bg.width * 4, bg.height * 4), Image.NEAREST)
    bg.save(os.path.join(OUT, name + "_x4.png"))
    print(name, im.size)


# ------------------------------------------------------------------ A: Ahşap Tahta
def doku_a(seed=7):
    rng = np.random.default_rng(seed)
    W, H, BH = 192, 120, 20  # 6 tahta / karo, tahta 20 sanat px = 60 ekran px
    s = np.zeros((H, W))
    for row in range(H // BH):
        y0 = row * BH
        # tahta uç ekleri (sarmalı): 1-2 ek, satırlar kaydırılmış
        n_j = rng.integers(1, 3)
        joints = sorted((rng.integers(0, W) + np.arange(n_j) * (W // n_j)) % W)
        # her parça kendi tonu
        seg_tone = {}
        bounds = list(joints) + [joints[0] + W]
        for i in range(len(joints)):
            tone = rng.choice([-0.25, 0.0, 0.0, 0.25])
            for x in range(bounds[i], bounds[i + 1]):
                seg_tone[x % W] = tone
        for x in range(W):
            s[y0:y0 + BH, x] = seg_tone[x]
        # damar: uzun, hafif dalgalı çizgiler
        for _ in range(rng.integers(5, 8)):
            x = rng.integers(0, W)
            y = y0 + rng.integers(3, BH - 3)
            length = rng.integers(18, 70)
            col = rng.choice([-0.5, -0.5, -0.25, 0.5])
            for k in range(length):
                xx = (x + k) % W
                if k > 0 and rng.random() < 0.07:
                    y = int(np.clip(y + rng.choice([-1, 1]), y0 + 2, y0 + BH - 3))
                s[y, xx] = seg_tone[xx] + col
        # budak: küçük oval halka (bazı tahtalarda)
        if rng.random() < 0.6:
            cx = rng.integers(0, W)
            cy = y0 + rng.integers(6, BH - 6)
            for dy in range(-2, 3):
                for dx in range(-4, 5):
                    e = (dx / 4.2) ** 2 + (dy / 2.2) ** 2
                    xx = (cx + dx) % W
                    if e <= 0.35:
                        s[cy + dy, xx] = -0.75
                    elif e <= 1.0:
                        s[cy + dy, xx] = seg_tone[xx] - 0.25
            # budağın etrafından kıvrılan damar
            for dx in range(-9, 10):
                xx = (cx + dx) % W
                bend = 3 if abs(dx) <= 5 else (2 if abs(dx) <= 7 else 1)
                if 0 <= cy - bend - 1 - y0 < BH - 1:
                    s[cy - bend - 1, xx] = seg_tone[xx] - 0.5
        # üst kenar ışığı, alt ek gölgesi
        for x in range(W):
            s[y0, x] = seg_tone[x] + 0.5
            s[y0 + BH - 1, x] = -1.0
        # uç ekleri: koyu dikey çizgi + sağında ışık
        for j in joints:
            s[y0:y0 + BH, j % W] = -1.0
            s[y0 + 1:y0 + BH - 1, (j + 1) % W] = seg_tone[(j + 1) % W] + 0.5
    return s


# ------------------------------------------------------------------ B: Taş Duvar
def doku_b(seed=11):
    rng = np.random.default_rng(seed)
    W = 168
    rows = [13, 12, 14, 12, 13, 14, 12, 14]
    H = sum(rows)
    s = np.zeros((H, W))
    y0 = 0
    for rh in rows:
        # taş sınırları (sarmalı)
        xs = []
        x = int(rng.integers(0, 20))
        start = x
        while x < start + W - 18:
            xs.append(x % W)
            x += int(rng.integers(18, 36))
        xs = sorted(xs)
        bounds = xs + [xs[0] + W]
        for i in range(len(xs)):
            a, b = bounds[i], bounds[i + 1]
            tone = rng.choice([-0.25, 0.0, 0.0, 0.25])
            for xx in range(a, b):
                x2 = xx % W
                for yy in range(y0, y0 + rh):
                    ly, lx = yy - y0, xx - a
                    w = b - a
                    if lx == 0 or ly == rh - 1:
                        v = -1.0  # derz
                    elif (lx == 1 or lx == w - 1) and (ly == 0 or ly == rh - 2):
                        v = -0.75  # yuvarlatılmış köşe
                    elif ly == 0:
                        v = tone + 0.5  # üst ışık
                    elif lx == 1:
                        v = tone + 0.25  # sol ışık
                    elif ly == rh - 2:
                        v = tone - 0.5  # alt gölge
                    elif lx == w - 1:
                        v = tone - 0.25
                    else:
                        v = tone
                    s[yy, x2] = v
            # birkaç taşta küçük çatlak / oyuk
            if rng.random() < 0.3 and b - a > 12:
                cx = a + int(rng.integers(4, b - a - 4))
                cy = y0 + int(rng.integers(3, rh - 4))
                for k in range(int(rng.integers(3, 6))):
                    s[cy, (cx + k) % W] = tone - 0.5
                    if rng.random() < 0.4:
                        cy = min(cy + 1, y0 + rh - 4)
        y0 += rh
    return s


# ------------------------------------------------------------------ C: Kilim (kabartma baklava kafes)
def doku_c():
    P = 30  # baklava aralığı (sanat px) -> 90 ekran px
    W, H = P, P
    s = np.zeros((H, W))
    # çapraz kafes çizgileri: oluk (koyu) + hemen altında ışık -> kabartma
    for y in range(H):
        for x in range(W):
            d1 = (x + y) % P
            d2 = (x - y) % P
            if d1 == 0 or d2 == 0:
                s[y, x] = -0.75
            elif d1 == 1 or d2 == P - 1:
                s[y, x] = 0.5
    # baklava ortası (x = P/2, y = 0 ve P/2 kaydırmalı): küçük basamaklı baklava + kanca
    c = P // 2
    for (cx, cy) in [(c, c), (0, 0)]:
        for dy in range(-4, 5):
            for dx in range(-4, 5):
                m = abs(dx) + abs(dy)
                xx, yy = (cx + dx) % W, (cy + dy) % H
                if m == 4:
                    s[yy, xx] = 0.75
                elif m <= 1:
                    s[yy, xx] = 0.5
        # yatay kancalar (kilim "el-bel-de" kancası sade hali)
        for dx in (-6, 6):
            s[cy % H, (cx + dx) % W] = 0.5
            s[(cy - 1) % H, (cx + dx + (1 if dx > 0 else -1)) % W] = 0.5
    return s


# ------------------------------------------------------------------ D: Eski Deri (bantlı leke + kırışık)
def doku_d(seed=5):
    rng = np.random.default_rng(seed)
    N = 192
    noise = rng.standard_normal((N, N))
    f = np.fft.fftfreq(N)
    fx, fy = np.meshgrid(f, f)
    r2 = fx ** 2 + fy ** 2
    big = np.real(np.fft.ifft2(np.fft.fft2(noise) * np.exp(-r2 * (2 * np.pi * 11) ** 2 / 2)))
    mid = np.real(np.fft.ifft2(np.fft.fft2(noise[::-1]) * np.exp(-r2 * (2 * np.pi * 4) ** 2 / 2)))
    big /= big.std()
    mid /= mid.std()
    v = big * 0.8 + mid * 0.35
    s = np.zeros((N, N))
    s[v > 0.9] = 0.25
    s[v > 1.7] = 0.5
    s[v < -0.9] = -0.25
    s[v < -1.7] = -0.5
    # kırışıklar: kısa kıvrımlı çizgi, altında ışık
    for _ in range(9):
        x, y = rng.integers(0, N, 2)
        ang = rng.uniform(0, np.pi)
        L = rng.integers(8, 22)
        for k in range(L):
            ang += rng.uniform(-0.25, 0.25)
            xi = int(round(x + np.cos(ang) * k)) % N
            yi = int(round(y + np.sin(ang) * k)) % N
            s[yi, xi] = -0.75
            s[(yi + 1) % N, xi] = max(s[(yi + 1) % N, xi], 0.25)
    return s


if __name__ == "__main__":
    save("doku_a", doku_a())
    save("doku_b", doku_b())
    save("doku_c", doku_c(), light_a=0.26, dark_a=0.62)
    save("doku_d", doku_d())
