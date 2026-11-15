# PANEL DOKUSU prototipleri 2. set (2026-11-13, oyuna bağlı DEĞİL). Kullanıcı ilk 4'ten (A-D) seçmedi: "4 prototip daha hazırla".
# 1. setten farklı yönler (malzeme değil, çizim dili de farklı):
#   E Akan Damar  - tek parça ahşap levha, eş yükselti çizgisiyle akan damar + iki budak halkası (ek yeri yok)
#   F Hasır Örgü  - sepet örgüsü: 3'lü şeritler yatay/dikey dama, üstte kalan şeridin ışığı, alttakinin gölgesi
#   G Çiçek Deseni - ton-üstü-ton kabartma çiçek (yarım kaydırmalı ızgara, büyük + küçük çiçek), duvar kâğıdı gibi
#   H Oyma Pano   - kenardan 3 sanat px içerde oyma çerçeve çizgisi + köşede içe dönen yay ve baklava; zemin E damarının yarısı
# Renk kuralı 1. setle aynı (gen_panel_doku.py to_rgba): yalnız RIM_HI / DEEP alfa bantları, yeni hex yok.
# Çıktı: out/tiles/doku_{e,f,g}.png, doku_h_k{10,5}_{tl,tr,bl,br}.png. Kullanım: python gen_panel_doku2.py
import os
import numpy as np
from PIL import Image
from gen_panel_doku import OUT, save, to_rgba


def _smooth_periodic(rng, h, w, sigma):
    noise = rng.standard_normal((h, w))
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    k = np.exp(-((fx ** 2 + fy ** 2) * (2 * np.pi * sigma) ** 2) / 2)
    v = np.real(np.fft.ifft2(np.fft.fft2(noise) * k))
    return v / v.std()


# ------------------------------------------------------------------ E: Akan Damar
def doku_e(seed=3):
    rng = np.random.default_rng(seed)
    ## H/SP bant sayısı 6'nın katı OLMALI: açık bant = band % 2, güçlü çizgi = band % 3. 150/6 = 25 (tek) iken karo sınırında
    ## bant sırası tersine dönüyor, panelin ortasından düz keskin bir yatay çizgi geçiyordu (kullanıcı fark etti) -> 144/6 = 24.
    W, H, SP = 240, 144, 6
    assert H % SP == 0 and (H // SP) % 6 == 0
    y, x = np.mgrid[0:H, 0:W].astype(float)
    f = y + 4.0 * np.sin(2 * np.pi * x / W + 0.7) + 2.0 * np.sin(2 * np.pi * 2 * x / W + 2.1) \
        + 1.6 * _smooth_periodic(rng, H, W, 9)
    knots = [(62, 38), (176, 104)]
    for kx, ky in knots:
        dx = (x - kx + W / 2) % W - W / 2
        dy = (y - ky + H / 2) % H - H / 2
        f += 9.0 * np.exp(-((dx / 9.0) ** 2 + (dy / 5.0) ** 2))
    band = np.floor(f / SP)
    ## alt komşu: son satırın altı bir sonraki karonun ilk satırı = f + H -> bandı H/SP büyük (yoksa son satır baştan sona çizgi olurdu)
    below = np.roll(band, -1, axis=0)
    below[-1] += H // SP
    line = (band != below) | (band != np.roll(band, -1, axis=1))
    brk = _smooth_periodic(rng, H, W, 3)
    s = np.zeros((H, W))
    strong = (band.astype(int) % 3) == 0
    s[line & (brk > -0.9)] = -0.5
    s[line & strong & (brk > -0.9)] = -0.75
    # ilkbahar/yaz halkası: her ikinci bandın içi çok hafif açık
    s[(~line) & ((band.astype(int) % 2) == 0)] = 0.25
    for kx, ky in knots:  # budak özü
        for dy in range(-1, 2):
            for dx in range(-2, 3):
                if (dx / 2.4) ** 2 + (dy / 1.4) ** 2 <= 1.0:
                    s[(ky + dy) % H, (kx + dx) % W] = -1.0
    return s


# ------------------------------------------------------------------ F: Hasır Örgü
def doku_f():
    C = 12  # hücre = 3 şerit x 4 px
    W = H = 2 * C
    s = np.zeros((H, W))
    for cy in range(2):
        for cx in range(2):
            horiz = (cx + cy) % 2 == 0
            for ly in range(C):
                for lx in range(C):
                    a, b = (ly, lx) if horiz else (lx, ly)  # a: şerit içi konum (dik eksen), b: şerit boyunca
                    k = a % 4
                    v = 0.0
                    if k == 0:
                        v = 0.5  # şeridin ışıklı kenarı
                    elif k == 3:
                        v = -0.5  # şeritler arası gölge
                    # şerit uçları komşu hücrenin altına girer: uçta koyulaşır
                    if b == 0 or b == C - 1:
                        v = -0.75
                    elif b == 1 or b == C - 2:
                        v = min(v, -0.25)
                    s[cy * C + ly, cx * C + lx] = v
    return s


# ------------------------------------------------------------------ G: Çiçek Deseni
FLOWER_BIG = [
    ".PP.PP.",
    "PooPooP",
    "PooPooP",
    ".PPcPP.",
    "PooPooP",
    "PooPooP",
    ".PP.PP.",
]


def _stamp(s, grid, cx, cy):
    H, W = s.shape
    h, w = len(grid), len(grid[0])
    val = {"P": 0.5, "o": 0.25, "c": -0.5}
    for j, row in enumerate(grid):
        for i, ch in enumerate(row):
            if ch in val:
                s[(cy - h // 2 + j) % H, (cx - w // 2 + i) % W] = val[ch]


def doku_g():
    W, H = 30, 26
    s = np.zeros((H, W))
    ## v1'deki küçük çiçek + yapraklar oyunda "/" çizik gibi okundu -> yalnız büyük çiçek, yarım kaydırmalı
    _stamp(s, FLOWER_BIG, 8, 7)
    _stamp(s, FLOWER_BIG, 23, 20)
    # kabartma: açık pikselin sağ altı boşsa gölge
    sh = np.zeros_like(s)
    for yy in range(H):
        for xx in range(W):
            if s[yy, xx] > 0 and s[(yy + 1) % H, (xx + 1) % W] == 0:
                sh[(yy + 1) % H, (xx + 1) % W] = -0.5
    s[sh < 0] = sh[sh < 0]
    return s


# ------------------------------------------------------------------ H: Oyma Pano köşeleri
def _arc_points(K):
    pts = set()
    for i in range(K * 16 + 1):
        t = (np.pi / 2) * i / (K * 16)
        pts.add((int(round(K * np.cos(t))), int(round(K * np.sin(t)))))
    # köşe cebinde küçük baklava (büyük köşe) ya da tek nokta (küçük köşe)
    if K >= 8:
        c = int(round(K * 0.34))
        for dy in range(-2, 3):
            for dx in range(-2, 3):
                if abs(dx) + abs(dy) == 2:
                    pts.add((c + dx, c + dy))
        # yayın iç yanına ikinci, kesik yay (kıvrım hissi)
        for i in range(K * 16 + 1):
            t = (np.pi / 2) * (0.2 + 0.6 * i / (K * 16))
            pts.add((int(round((K - 3) * np.cos(t))), int(round((K - 3) * np.sin(t)))))
    else:
        pts.add((2, 2))
    return pts


def corners_h(K, dark=-1.0, light=1.0):  # alfalar panel_doku_capture.gd _draw_frame çizgileriyle aynı (0,70 / 0,28)
    S = K + 3
    pts = _arc_points(K)
    P = {"tl": (1, 1, 1, 1), "tr": (S - 2, 1, -1, 1), "bl": (1, S - 2, 1, -1), "br": (S - 2, S - 2, -1, -1)}
    for name, (px, py, sx, sy) in P.items():
        s = np.zeros((S, S))
        dk = {(px + sx * dx, py + sy * dy) for dx, dy in pts}
        for (x, y) in dk:  # ışık: oyuğun sağ alt duvarı
            if (x + 1, y + 1) not in dk and 0 <= x + 1 < S and 0 <= y + 1 < S:
                s[y + 1, x + 1] = light
        for (x, y) in dk:
            s[y, x] = dark
        im = to_rgba(s, light_a=0.28, dark_a=0.70)
        im.save(os.path.join(OUT, "doku_h_k%d_%s.png" % (K, name)))
    print("doku_h_k%d" % K, S)


## OYUN VARLIĞI (madde 662, kullanıcı seçimi E "Akan Damar", saydamlık aynen): python gen_panel_doku2.py --oyun
## -> assets/ui/panel_doku/ahsap_damar.png = E karosu x3 en yakın komşu (pixel_box.gd 1:1 döşer). Sonra: Godot --headless --path . --import
GAME_TILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "assets", "ui", "panel_doku", "ahsap_damar.png")


def write_game_tile():
    im = to_rgba(doku_e())
    im = im.resize((im.width * 3, im.height * 3), Image.NEAREST)
    os.makedirs(os.path.dirname(GAME_TILE), exist_ok=True)
    im.save(GAME_TILE)
    print("oyun karosu", os.path.normpath(GAME_TILE), im.size)


if __name__ == "__main__":
    import sys
    if "--oyun" in sys.argv:
        write_game_tile()
        sys.exit(0)
    save("doku_e", doku_e())
    save("doku_f", doku_f(), light_a=0.16, dark_a=0.5)
    save("doku_g", doku_g(), light_a=0.28, dark_a=0.5)
    corners_h(10)
    corners_h(5)
