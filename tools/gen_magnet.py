"""Mıknatıs (yere düşen MagnetDrop) piksel sanatı - kullanıcı isteği 2026-10-16: "oyunumdaki mıknatısın görünüşü çok eski yeni bir pixel art
mıknatıs yapar mısın, yere düşen mıknatısı kastediyorum".

Eskisi magnet_drop.gd _draw() ile çizilen düz kırmızı yay + iki gri dikdörtgendi. Yenisi silah parçacığıyla (gen_weapon_shard.py) AYNI dil:
1 piksel koyu dış çizgi, ışık soldan-yukarıdan, 5 tonlu rampa, kenar yumuşatma YOK, rastgelelik YOK. Klasik nal mıknatıs (kavis üstte, bacaklar
aşağıda), kırmızı gövde + çelik uçlar. Gövde bir TÜP gibi gölgelenir: kalınlık boyunca t in [-1,1] -> yüzey normali (radyal * t, z * sqrt(1-t^2)),
ışıkla nokta çarpımı tona çevrilir; uç ile gövde arasında 1 piksellik koyu ek yeri.
Animasyon (7 kare, dönüşlü): gövdede kayan parlama bandı + çelik uçlar arasında kısa zikzak manyetik kıvılcım (iki kare) + bekleme.

Çıktılar (proje köküne göre):
  assets/pickups/magnet/magnet_sheet.png   7 kare x 20x20 (magnet_frames.tres bunu okur; sahnede 1 sanat pikseli = 1 dünya pikseli, parçacıkla aynı)

Kullanım: python tools/gen_magnet.py [önizleme.png]   (önizleme: 12x büyütülmüş şerit çimen üstünde, istenirse PROJE DIŞINA yazılır)
"""
import math
import os
import sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "pickups", "magnet")
W = H = 20

PAL = {
    "o": (0x2b, 0x22, 0x33, 255),  # dış çizgi (parçacıkla aynı)
    # kırmızı gövde: en koyu -> en açık
    "1": (0x5e, 0x17, 0x2a, 255),
    "2": (0x93, 0x22, 0x31, 255),
    "3": (0xc8, 0x3a, 0x38, 255),
    "4": (0xec, 0x6a, 0x4f, 255),
    "5": (0xff, 0xb4, 0x8c, 255),
    # çelik uçlar (parçacık paleti)
    "d": (0x4a, 0x54, 0x72, 255),
    "n": (0x66, 0x73, 0x93, 255),
    "m": (0x86, 0x95, 0xb4, 255),
    "l": (0xb7, 0xc6, 0xe0, 255),
    "w": (0xee, 0xf5, 0xff, 255),
    # manyetik kıvılcım
    "s": (0xc9, 0x9b, 0xff, 255),
    "S": (0xf4, 0xe8, 0xff, 255),
}
RED = "12345"
STEEL = "dnmlw"

# Geometri (piksel merkezi koordinatı): kavis merkezi (CX, CY), dış/iç yarıçap, bacak alt ucu, çelik ucun başladığı y.
CX, CY = 10.0, 9.0
R_OUT, R_IN = 8.0, 2.0
LEG_END = 18.0
TIP_Y = 13.0
LIGHT = (-0.55, -0.65, 0.52)


def _norm(v):
    l = math.sqrt(sum(c * c for c in v))
    return tuple(c / l for c in v)


LIGHT = _norm(LIGHT)


def sample(x, y):
    """(içinde mi, tüp kesit koordinatı t, radyal yön) - x,y piksel merkezi."""
    dx, dy = x - CX, y - CY
    if dy <= 0.0:
        r = math.hypot(dx, dy)
        if R_IN <= r <= R_OUT:
            t = (r - R_IN) / (R_OUT - R_IN) * 2.0 - 1.0  # iç kenar -1, dış kenar +1
            return True, t, (dx / r, dy / r)
        return False, 0.0, (0.0, 0.0)
    if y > LEG_END:
        return False, 0.0, (0.0, 0.0)
    ax = abs(dx)
    if R_IN <= ax <= R_OUT:
        t = (ax - R_IN) / (R_OUT - R_IN) * 2.0 - 1.0
        return True, t, (math.copysign(1.0, dx), 0.0)
    return False, 0.0, (0.0, 0.0)


def build_template():
    mask = [[sample(x + 0.5, y + 0.5)[0] for x in range(W)] for y in range(H)]

    def solid(x, y):
        return 0 <= x < W and 0 <= y < H and mask[y][x]

    grid = [["." for _ in range(W)] for _ in range(H)]
    for y in range(H):
        for x in range(W):
            if not mask[y][x]:
                continue
            if not (solid(x + 1, y) and solid(x - 1, y) and solid(x, y + 1) and solid(x, y - 1)):
                grid[y][x] = "o"
                continue
            _, t, (rx, ry) = sample(x + 0.5, y + 0.5)
            t = max(-1.0, min(1.0, t))
            z = math.sqrt(max(0.0, 1.0 - t * t))
            n = _norm((rx * t, ry * t, z))
            lum = n[0] * LIGHT[0] + n[1] * LIGHT[1] + n[2] * LIGHT[2]
            steel = y + 0.5 >= TIP_Y
            ramp = STEEL if steel else RED
            if lum > 0.88:
                k = 4
            elif lum > 0.64:
                k = 3
            elif lum > 0.36:
                k = 2
            elif lum > 0.0:
                k = 1
            else:
                k = 0
            grid[y][x] = ramp[k]
    # çelik ucun gövdeye eklendiği yerde 1 piksellik koyu ek yeri (okunurluk)
    seam = int(TIP_Y)
    for x in range(W):
        if grid[seam][x] in STEEL:
            grid[seam][x] = "1"
    return ["".join(r) for r in grid]


def render(sablon, shine=None, spark=0):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()
    for y, row in enumerate(sablon):
        for x, ch in enumerate(row):
            if ch != ".":
                px[x, y] = PAL[ch]
    if shine is not None:
        # sol-aşağıdan sağ-yukarıya kayan 2 piksellik diyagonal parlama bandı (x - y sabiti; dolu pikseller -13..14 arası)
        target = shine * 30.0 - 15.0
        for y in range(H):
            for x in range(W):
                ch = sablon[y][x]
                if ch in RED or ch in STEEL:
                    dpos = (x - y) - target
                    if abs(dpos) < 1.5:
                        base = px[x, y]
                        lift = 0.8 if abs(dpos) < 0.5 else 0.35
                        px[x, y] = tuple(min(255, int(base[i] + (PAL["w"][i] - base[i]) * lift)) for i in range(3)) + (255,)
    if spark:
        # iki çelik uç arasındaki boşlukta (x 8..11) zikzak manyetik kıvılcım; iki kare zıt fazda titrer
        if spark == 1:
            pts = [(8, 15, "s"), (9, 16, "S"), (10, 15, "S"), (11, 16, "s")]
        else:
            pts = [(8, 16, "s"), (9, 15, "s"), (10, 16, "S"), (11, 15, "s")]
        for x, y, c in pts:
            if 0 <= x < W and 0 <= y < H and px[x, y][3] == 0:
                px[x, y] = PAL[c]
    return img


# Kareler (magnet_frames.tres, 8 fps): 4 parlama karesi, 2 kıvılcım karesi, son kare 3 birim bekleme -> döngü ~1,1 sn.
FRAMES = [(0.1, 0), (0.37, 0), (0.63, 0), (0.9, 0), (None, 1), (None, 2), (None, 0)]


def main():
    os.makedirs(OUT, exist_ok=True)
    sablon = build_template()
    for row in sablon:
        print(row)
    n = len(FRAMES)
    sheet = Image.new("RGBA", (W * n, H), (0, 0, 0, 0))
    for i, (shine, spark) in enumerate(FRAMES):
        sheet.paste(render(sablon, shine, spark), (i * W, 0))
    sheet.save(os.path.join(OUT, "magnet_sheet.png"))
    if len(sys.argv) > 1:
        prev = sheet.resize((W * n * 12, H * 12), Image.NEAREST)
        bg = Image.new("RGBA", prev.size, (86, 112, 60, 255))  # çimen zemini üstünde nasıl durur
        bg.alpha_composite(prev)
        bg.save(sys.argv[1])
    print("ok", OUT)


if __name__ == "__main__":
    main()
