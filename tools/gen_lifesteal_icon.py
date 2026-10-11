"""Can Çalma stat ikonu (2026-10-11, kullanıcı: "can çalma statı ikonunu yeniden tasarla - level atlama kartlarında ve envanterde").
48x48 piksel ızgarada çizilir, 6x en yakın komşuyla 288 px'e büyütülür (diğer stat ikonlarıyla aynı boy, assets/ui/level_up_icons/).
Motif: kırmızı kalp + üstüne gömülmüş iki beyaz vampir dişi + dişlerden süzülen kan damlaları (can EMME okunuşu).
Kullanım: python tools/gen_lifesteal_icon.py  ->  assets/ui/level_up_icons/stat_lifesteal.png
"""
import math
import os
from PIL import Image

N = 48
SCALE = 6
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui", "level_up_icons", "stat_lifesteal.png")

OUTLINE = (58, 14, 20, 255)
RED_D = (150, 22, 34, 255)
RED = (214, 44, 56, 255)
RED_L = (244, 96, 96, 255)
HI = (255, 196, 190, 255)
FANG = (246, 240, 228, 255)
FANG_S = (190, 178, 168, 255)
BLOOD = (176, 10, 24, 255)
BLOOD_L = (232, 60, 64, 255)


def heart(x, y):
    # klasik kalp: (x^2 + y^2 - 1)^3 - x^2 y^3 <= 0, y yukarı
    return (x * x + y * y - 1.0) ** 3 - x * x * y ** 3 <= 0.0


def main():
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    px = img.load()
    cx, cy, sx, sy = 23.5, 25.5, 16.5, 15.5
    inside = [[False] * N for _ in range(N)]
    for j in range(N):
        for i in range(N):
            x = (i - cx) / sx
            y = -(j - cy) / sy
            inside[j][i] = heart(x * 1.05, y * 1.05 + 0.15)
    # gövde gölgeleme (sol üst ışık)
    for j in range(N):
        for i in range(N):
            if not inside[j][i]:
                continue
            x = (i - cx) / sx
            y = -(j - cy) / sy
            d = x * 0.55 - y * 0.45  # sağ-alt koyu
            col = RED_L if d < -0.35 else (RED if d < 0.35 else RED_D)
            px[i, j] = col
    # parlama
    for (i, j) in [(14, 16), (15, 16), (13, 17), (14, 17), (13, 18), (15, 15), (16, 15)]:
        if inside[j][i]:
            px[i, j] = HI
    # dişler: kalbin üstüne yukarıdan batan iki büyük sivri diş (aşağı bakar, koyu çizgili); gövdenin üstünden 3 px taşar
    fang_px = set()
    for base_x in (18, 29):
        for k in range(13):  # yükseklik (y 11..23)
            half = max(0, 3 - (k * 4) // 13)
            for dx in range(-half, half + 1):
                fang_px.add((base_x + dx, 11 + k))
    for (i, j) in fang_px:
        px[i, j] = FANG
    for (i, j) in fang_px:  # sağ kenar gölgesi
        if (i + 1, j) not in fang_px:
            px[i, j] = FANG_S
    for (i, j) in list(fang_px):  # dişin kendi çizgisi (kalp üstünde de okunsun)
        for (di, dj) in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (i + di, j + dj)
            if q not in fang_px and 0 <= q[0] < N and 0 <= q[1] < N:
                px[q[0], q[1]] = OUTLINE
    # dişlerin battığı yerden kalbe süzülen kan
    for (bx, top, ln) in [(18, 25, 4), (29, 25, 6)]:
        for k in range(ln):
            px[bx, top + k] = BLOOD
            px[bx + 1, top + k] = BLOOD_L if k < 2 else BLOOD
    # dış çizgi: dolu piksele komşu boş pikseller
    solid = [[px[i, j][3] > 0 for i in range(N)] for j in range(N)]
    for j in range(N):
        for i in range(N):
            if solid[j][i]:
                continue
            for (di, dj) in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                a, b = i + di, j + dj
                if 0 <= a < N and 0 <= b < N and solid[b][a]:
                    px[i, j] = OUTLINE
                    break
    img.resize((N * SCALE, N * SCALE), Image.NEAREST).save(os.path.abspath(OUT))
    print("yazıldı:", os.path.abspath(OUT))


if __name__ == "__main__":
    main()
