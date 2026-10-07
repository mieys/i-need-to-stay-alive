"""Silah parçacığı (Weapon Shard) piksel sanatı - kullanıcı isteği 2026-10-08: "silah parçacığı için pixel sanatı bir şey hazırlaman lazım".

Kırık bir silahtan kopmuş, yüzeyli (faceted) çelik parça: elle tasarlanmış tırtıklı siluet, ışığı soldan-yukarıdan alan 5 çelik tonu (her yüz tek
ton, yüz sınırlarında 1 piksellik parlak/koyu kenar), 1 piksel koyu dış çizgi ve kırık kenarlarda parlayan kızıl-turuncu kor. Oyunun sanatı 48x48
yoğunlukta (bkz. memory feedback-pixel-density-48): iri 2-3 pikselli bloklar, dither, kenar yumuşatma YOK. Her şey deterministik (rastgelelik yok).
Animasyon (6 kare, dönüşlü): yüzeyde kayan bir parlama bandı + kor titremesi + kısa bir kıvılcım.

Çıktılar (proje köküne göre):
  assets/pickups/weapon_shard/shard_sheet.png   6 kare x 22x22 (yerde duran drop; weapon_shard_frames.tres bunu okur)
  assets/pickups/weapon_shard/shard_icon.png    22x22 durağan kare (HUD sayacı + dükkan fiyat satırı; parlama bandı yok)

Kullanım: python tools/gen_weapon_shard.py [önizleme.png]   (önizleme: 12x büyütülmüş şerit, istenirse PROJE DIŞINA yazılır)
"""
import os
import sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "pickups", "weapon_shard")
W = H = 22

PAL = {
    "o": (0x2b, 0x22, 0x33, 255),  # dış çizgi
    "d": (0x4a, 0x54, 0x72, 255),  # çelik en koyu
    "n": (0x66, 0x73, 0x93, 255),  # çelik koyu-orta
    "m": (0x86, 0x95, 0xb4, 255),  # çelik orta
    "l": (0xb7, 0xc6, 0xe0, 255),  # çelik açık
    "w": (0xee, 0xf5, 0xff, 255),  # parlak vurgu
    "r": (0xb8, 0x3a, 0x1a, 255),  # kor koyu kırmızı
    "e": (0xff, 0x86, 0x2a, 255),  # kor turuncu
    "y": (0xff, 0xd0, 0x58, 255),  # kor sarı
}

# Siluet (piksel merkezi koordinatı, y aşağı). Sol-aşağıda sivri uç, üstte iki sivri diş ve bir çentik, sağda kırık omuz.
POLY = [
    (1.2, 19.8), (4.2, 11.6), (7.6, 7.4), (8.6, 3.2), (11.6, 6.4), (14.4, 2.0), (16.6, 6.8),
    (20.2, 8.6), (17.2, 13.2), (12.4, 17.0), (6.6, 20.6),
]

# Yüzler: (tohum x, tohum y, ton). Her piksel en yakın tohumun tonunu alır (hafif dikey/yatay oran farkıyla uzun yüzler elde edilir).
FACETS = [
    (4.0, 16.5, "m"), (6.0, 12.0, "l"), (8.6, 8.6, "w"), (9.4, 13.2, "m"), (12.0, 10.0, "n"),
    (14.4, 8.4, "d"), (12.6, 14.4, "d"), (15.6, 10.6, "d"),
]
# Kor: kırık kenar piksellerinin yakınındaki elle seçilmiş noktalar (x, y) -> ton.
EMBERS = {
    (9, 4): "y", (8, 5): "e", (9, 5): "r",                                  # sol diş
    (14, 3): "y", (14, 4): "e", (13, 5): "e", (13, 4): "r",                 # orta diş
    (18, 8): "y", (17, 8): "e", (17, 9): "r",                               # sağ omuz
}
CRACK = {(11, 10), (11, 11), (12, 12)}  # yüzeyde ince bir kor çatlağı (parlama bandı dışında hep yanar)


def point_in_poly(px, py, poly):
    inside = False
    n = len(poly)
    j = n - 1
    for i in range(n):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > py) != (yj > py) and px < (xj - xi) * (py - yi) / (yj - yi + 1e-9) + xi:
            inside = not inside
        j = i
    return inside


def build_template():
    mask = [[point_in_poly(x + 0.5, y + 0.5, POLY) for x in range(W)] for y in range(H)]

    def solid(x, y):
        return 0 <= x < W and 0 <= y < H and mask[y][x]

    grid = [["." for _ in range(W)] for _ in range(H)]
    for y in range(H):
        for x in range(W):
            if not mask[y][x]:
                continue
            border = not (solid(x + 1, y) and solid(x - 1, y) and solid(x, y + 1) and solid(x, y - 1))
            if border:
                grid[y][x] = "o"
                continue
            best = None
            for fx, fy, tone in FACETS:
                d = (x + 0.5 - fx) ** 2 * 0.8 + (y + 0.5 - fy) ** 2
                if best is None or d < best[0]:
                    best = (d, tone)
            grid[y][x] = best[1]
    # yüz sınırlarında 1 piksellik kenar: sağ/alt komşusu daha KOYU bir yüzse bu piksel bir ton açılır (kenar parlaması)
    order = "dnmlw"
    out = [row[:] for row in grid]
    for y in range(H):
        for x in range(W):
            c = grid[y][x]
            if c in order:
                for dx, dy in ((1, 0), (0, 1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < W and 0 <= ny < H and grid[ny][nx] in order and order.index(grid[ny][nx]) < order.index(c) - 1:
                        out[y][x] = order[min(len(order) - 1, order.index(c) + 1)]
    # kor
    for (x, y), tone in EMBERS.items():
        if solid(x, y):
            out[y][x] = tone
    for (x, y) in CRACK:
        if solid(x, y) and out[y][x] in order:
            out[y][x] = "e"
    return ["".join(r) for r in out]


def render(sablon, shine=None, ember=0, sparkle=None):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()
    order = "ery"
    for y, row in enumerate(sablon):
        for x, ch in enumerate(row):
            if ch == ".":
                continue
            col = PAL[ch]
            if ch in order and (x + y + ember) % 2 == 0:
                col = PAL[order[(order.index(ch) + ember) % 3]]
            px[x, y] = col
    if shine is not None:
        target = shine * 30.0 - 2.0  # sol-aşağıdan sağ-yukarıya kayan diyagonal bant (x - y sabiti)
        for y in range(H):
            for x in range(W):
                if sablon[y][x] in "mnld":
                    dpos = (x - y) - (target - 4.0)
                    if abs(dpos) < 1.0:
                        base = px[x, y]
                        lift = 1.0 if abs(dpos) < 0.5 else 0.5
                        px[x, y] = tuple(min(255, int(base[i] + (PAL["w"][i] - base[i]) * lift)) for i in range(3)) + (255,)
    if sparkle is not None:
        sx, sy = sparkle
        for dx, dy, c in [(0, 0, "w"), (-1, 0, "l"), (1, 0, "l"), (0, -1, "l"), (0, 1, "l")]:
            xx, yy = sx + dx, sy + dy
            if 0 <= xx < W and 0 <= yy < H and px[xx, yy][3] == 0:
                px[xx, yy] = PAL[c]
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    sablon = build_template()
    for row in sablon:
        print(row)
    shines = [0.05, 0.3, 0.55, 0.8, 1.05, None]
    sparkles = [None, None, None, (4, 7), (4, 7), None]
    sheet = Image.new("RGBA", (W * 6, H), (0, 0, 0, 0))
    for i in range(6):
        sheet.paste(render(sablon, shines[i], ember=i % 3, sparkle=sparkles[i]), (i * W, 0))
    sheet.save(os.path.join(OUT, "shard_sheet.png"))
    render(sablon, None, 0, None).save(os.path.join(OUT, "shard_icon.png"))
    if len(sys.argv) > 1:
        prev = sheet.resize((W * 6 * 12, H * 12), Image.NEAREST)
        bg = Image.new("RGBA", prev.size, (86, 112, 60, 255))  # çimen zemini üstünde nasıl durur
        bg.alpha_composite(prev)
        bg.save(sys.argv[1])
    print("ok", OUT)


if __name__ == "__main__":
    main()
