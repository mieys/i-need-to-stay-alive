# PANEL DOKUSU 3. set (2026-11-16, kullanıcı: oda listesi görüntüsüyle "bu texture'ı daha kaliteli ve okunurluğu daha iyi bir pixel tona
# çevirmen mümkün mü?"). Seçilmiş E "Akan Damar"ın (madde 662) arıtılmışları - malzeme aynı (tek levha ahşap, ek yeri yok), çizim dili temiz:
#   - çizgi yalnız DİKEY bant değişiminde (sütun başına 1 piksel -> temiz 1 px merdiven, köşede çift piksel yok; dik yerde yatay da),
#   - akış alanı çok yumuşak (uzun basamak koşuları, 1 px'lik "titreme" yok), aralık düzensiz ama periyodik (sık/seyrek halka),
#   - çizgiler uzun parçalara bölünür, uçları bir ton açık (inceltme), boşlukla biter; kontrast E'nin yarısı kadar (yazı öne çıksın).
# Varyantlar:
#   R1 Sade Damar    - seyrek, kesik, tek budak
#   R2 Kabartma      - R1 + çizginin altında 1 px RIM_HI ışık (oyma çizgi)
#   R3 Ton Akışı     - çizgi yerine geniş ton bantları (3 ton, düz alfa) + çok seyrek ince damar
#   R4 Kesik Lif     - kısa/orta yatay lif çizgileri (klasik piksel sanatı ahşap), budaksız
# Renk kuralı aynı (gen_panel_doku.py to_rgba): yalnız RIM_HI / DEEP alfa bantları, yeni hex yok, dither yok.
# Çıktı: out/tiles/r{1..4}.png (sanat px) + r?_x3.png (oyuna hazır). Kullanım: python gen_panel_doku3.py   (--oyun r2 -> oyun karosu)
import os
import sys
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "proto_20261113", "panel_doku"))
from gen_panel_doku import to_rgba  # noqa: E402

OUT = os.path.join(HERE, "out", "tiles")
os.makedirs(OUT, exist_ok=True)

W, H = 320, 192  # sanat px (x3 = 960x576 ekran px): E'den büyük -> tekrar daha az belli


def smooth_periodic(rng, h, w, sx, sy=None):
    sy = sx if sy is None else sy
    noise = rng.standard_normal((h, w))
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    k = np.exp(-(((fx * 2 * np.pi * sx) ** 2) + ((fy * 2 * np.pi * sy) ** 2)) / 2)
    v = np.real(np.fft.ifft2(np.fft.fft2(noise) * k))
    return v / v.std()


def flow(rng, knots, warp=1.0):
    """f(x, y + H) = f(x, y) + H, x'te periyodik. knots: [(x, y, güç)]"""
    y, x = np.mgrid[0:H, 0:W].astype(float)
    f = y + warp * (5.0 * np.sin(2 * np.pi * x / W + 0.7) + 2.2 * np.sin(2 * np.pi * 2 * x / W + 2.1)
                    + 1.3 * smooth_periodic(rng, H, W, 26, 18))
    for kx, ky, a in knots:
        dx = (x - kx + W / 2) % W - W / 2
        dy = (y - ky + H / 2) % H - H / 2
        f += a * np.exp(-((dx / 13.0) ** 2 + (dy / 6.0) ** 2))
    return f


def levels(f, n, wob=0.38, k=3):
    """Düzensiz aralıklı bant numarası: g(f + H) = g(f) + n (karo dikeyde dikişsiz). wob < 1 -> monoton."""
    c = wob * H / (2 * np.pi * k)
    g = (f + c * np.sin(2 * np.pi * k * f / H) + 0.35 * c * np.sin(2 * np.pi * (k + 2) * f / H + 1.3)) * n / H
    return np.floor(g)


def contour(band, n, f=None, steep=0.9):
    """Sütun başına 1 piksel çizgi (bant alttaki satırda değişiyor). Dik yerde (|df/dx| > steep) yatay değişim de çizgi."""
    below = np.roll(band, -1, axis=0)
    below[-1] += n  # son satırın altı = sonraki karonun ilk satırı (bant n büyük)
    line = band != below
    if f is not None:
        dfx = np.abs(np.roll(f, -1, axis=1) - f)
        right = np.roll(band, -1, axis=1)
        line |= (band != right) & (dfx > steep)
    return line


def knot_eye(s, kx, ky, val=-1.0, ring=-0.5):
    for dy in range(-3, 4):
        for dx in range(-5, 6):
            r = (dx / 4.6) ** 2 + (dy / 2.4) ** 2
            if r <= 0.45:
                s[(ky + dy) % H, (kx + dx) % W] = val
            elif r <= 1.0 and s[(ky + dy) % H, (kx + dx) % W] == 0:
                s[(ky + dy) % H, (kx + dx) % W] = ring


def broken(line, rng, sx, sy, gap, weak):
    """Çizgiyi parçalara böl: n > weak -> güçlü, gap < n <= weak -> uç (bir ton açık), altı boşluk."""
    nz = smooth_periodic(rng, H, W, sx, sy)
    strong = line & (nz > weak)
    soft = line & (nz > gap) & (nz <= weak)
    return strong, soft


# ------------------------------------------------------------------ R1 Sade Damar
def r1(highlight=False, seed=11):
    rng = np.random.default_rng(seed)
    knots = [(92, 58, 7.0)]
    f = flow(rng, knots)
    n = 22  # ort. 8,7 sanat px aralık (E: 6)
    band = levels(f, n)
    line = contour(band, n, f)
    strong, soft = broken(line, rng, 18, 2.5, -1.0, -0.35)
    s = np.zeros((H, W))
    ## halka tonu: her 2. bandın içi çok hafif açık (E'deki gibi ama aralık düzensiz -> eş yükselti haritası gibi durmaz)
    s[(~line) & ((band.astype(int) % 2) == 0)] = 0.25
    s[soft] = -0.25
    s[strong] = -0.5
    if highlight:  # oyma: güçlü çizginin hemen altı ışık (üstten gelen ışık oluğun alt duvarına vurur)
        hl = np.roll(strong, 1, axis=0) & (s >= 0)
        s[hl] = 0.75
    for kx, ky, _ in knots:
        knot_eye(s, kx, ky)
    return s


# ------------------------------------------------------------------ R3 Ton Akışı
def r3(seed=5):
    rng = np.random.default_rng(seed)
    knots = [(210, 120, 6.0)]
    f = flow(rng, knots, warp=1.15)
    n = 12
    band = levels(f, n, wob=0.45, k=2)
    ## ton sırası (n'ye bölünür -> dikişsiz): açık, düz, koyu bantları düzensiz
    tones = np.array([0.5, 0.25, 0.0, -0.25, 0.0, 0.5, 0.25, -0.25, -0.5, -0.25, 0.25, 0.0])
    assert len(tones) == n
    s = tones[(band.astype(int) % n)]
    s = s.copy()
    ## çok seyrek damar: yalnız koyu banda girilen sınırda, kesik
    below = np.roll(band, -1, axis=0)
    below[-1] += n
    edge = band != below
    tb = tones[(below.astype(int) % n)]
    dark_edge = edge & (tb < 0)
    strong, soft = broken(dark_edge, rng, 20, 2.5, -0.8, -0.1)
    s[soft] = -0.75
    s[strong] = -1.0
    for kx, ky, _ in knots:
        knot_eye(s, kx, ky, -1.0, -0.75)
    return s


# ------------------------------------------------------------------ R4 Kesik Lif
def r4(seed=23):
    rng = np.random.default_rng(seed)
    f = flow(rng, [], warp=0.8)
    n = 24  # ort. 8 px
    band = levels(f, n, wob=0.3, k=4)
    line = contour(band, n)
    strong, soft = broken(line, rng, 6, 1.2, -0.15, 0.35)  # kısa/orta lifler, yarısı boşluk
    s = np.zeros((H, W))
    s[soft] = -0.25
    s[strong] = -0.5
    return s


VARIANTS = {
    "r1": lambda: r1(False),
    "r2": lambda: r1(True),
    "r3": r3,
    "r4": r4,
}
KW = {  # alfa: s=-1 -> DEEP dark_a, s=+1 -> RIM_HI light_a (E: 0,55 / 0,20)
    "r1": dict(dark_a=0.62, light_a=0.20),
    "r2": dict(dark_a=0.62, light_a=0.22),
    "r3": dict(dark_a=0.50, light_a=0.22),
    "r4": dict(dark_a=0.66, light_a=0.20),
}


def check_seam(s, name):
    """Karo 2x2 döşenince sınır satırı/sütunu iç satırlardan belirgin koyu olmamalı. Ton bantlı R3'te yalnız çizgiler (s <= -0,75)."""
    dark = s <= -0.75 if name == "r3" else s < 0
    cov = dark.mean(axis=1)
    inner = cov[1:-1].max()
    assert cov[0] <= inner + 1e-9 and cov[-1] <= inner + 1e-9, (name, cov[0], cov[-1], inner)
    assert cov.max() < 0.9, (name, cov.max())
    colc = dark.mean(axis=0)
    assert colc.max() < 0.5, (name, "dikey çizgi", colc.max())


def write(name, s):
    check_seam(s, name)
    im = to_rgba(s, **KW[name])
    im.save(os.path.join(OUT, name + ".png"))
    big = im.resize((im.width * 3, im.height * 3), Image.NEAREST)
    big.save(os.path.join(OUT, name + "_x3.png"))
    dark = (s < 0).mean()
    print(name, im.size, "koyu kaplama %.1f%%" % (dark * 100))
    return big


GAME_TILE = os.path.join(HERE, "..", "..", "..", "assets", "ui", "panel_doku", "ahsap_damar.png")

if __name__ == "__main__":
    if "--oyun" in sys.argv:
        name = sys.argv[sys.argv.index("--oyun") + 1]
        big = write(name, VARIANTS[name]())
        big.save(GAME_TILE)
        print("oyun karosu", os.path.normpath(GAME_TILE), big.size)
        sys.exit(0)
    for k, fn in VARIANTS.items():
        write(k, fn())
