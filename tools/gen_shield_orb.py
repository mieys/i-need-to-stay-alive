"""Kalkan orbu piksel sanatı - kullanıcı isteği 2026-10-14: "tıpkı yiyecek gibi kalkan veren 2 adet yere düşen toplanabilir".

Mavi cam küre + ortasında açık renk kalkan arması. Küçük orb (%15) sade koyu çizgili; büyük orb (%30) daha iri ve altın halkalı. Oyunun sanatı
48x48 yoğunlukta (bkz. gen_weapon_shard.py): düz ton bantları, 1 piksel koyu dış çizgi, kenar yumuşatma YOK. Deterministik.

Çıktılar (proje köküne göre):
  assets/pickups/shield_orb/shield_orb_small.png   16x16
  assets/pickups/shield_orb/shield_orb_large.png   20x20

Kullanım: python tools/gen_shield_orb.py [önizleme.png]   (önizleme: 12x büyütülmüş, istenirse PROJE DIŞINA yazılır)
"""
import math
import os
import sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "pickups", "shield_orb")

OUTLINE = (0x1c, 0x22, 0x44, 255)
BLUE = [(0x2a, 0x4f, 0xa8, 255), (0x3d, 0x7b, 0xd9, 255), (0x62, 0xa8, 0xf2, 255), (0x9b, 0xd2, 0xff, 255)]  # koyu -> açık
SHINE = (0xf2, 0xfa, 0xff, 255)
GOLD = [(0xa8, 0x6a, 0x1c, 255), (0xf0, 0xb8, 0x3c, 255), (0xff, 0xe8, 0x8a, 255)]
EMBLEM = (0xee, 0xf6, 0xff, 255)
EMBLEM_SHADE = (0xb4, 0xcc, 0xee, 255)

# Kalkan arması satırları (merkeze göre x aralıkları, üstten alta): düz üst kenar, sivrilen alt uç.
EMBLEM_SMALL = [(-2, 2), (-2, 2), (-2, 2), (-1, 1), (0, 0)]
EMBLEM_LARGE = [(-3, 3), (-3, 3), (-3, 3), (-3, 3), (-2, 2), (-1, 1), (0, 0)]


def draw_orb(size, gold_ring, emblem):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    c = (size - 1) / 2.0
    r_out = size / 2.0
    ring = 2.0 if gold_ring else 1.0
    lx, ly = c - r_out * 0.35, c - r_out * 0.4  # ışık sol-üstten
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - c, y - c)
            if d > r_out - 0.2:
                continue
            if d > r_out - 1.2:
                img.putpixel((x, y), OUTLINE)
            elif gold_ring and d > r_out - 1.2 - ring + 1.0:
                t = (x - c) + (y - c)  # sol-üst açık, sağ-alt koyu
                img.putpixel((x, y), GOLD[2] if t < -r_out * 0.5 else (GOLD[1] if t < r_out * 0.6 else GOLD[0]))
            else:
                k = math.hypot(x - lx, y - ly) / r_out
                tone = 3 if k < 0.35 else (2 if k < 0.75 else (1 if k < 1.15 else 0))
                img.putpixel((x, y), BLUE[tone])
    # Kalkan arması: merkezde, sağ sütunu gölgeli.
    ci = int(round(c + 0.01)) if size % 2 else size // 2
    top = ci - len(emblem) // 2
    # Arma açık renkli cam üstünde kaybolmasın: önce 1 piksel koyu mavi çerçeve.
    for row, (x0, x1) in enumerate(emblem):
        for dx in range(x0 - 1, x1 + 2):
            for dy in (-1, 0, 1):
                px, py = ci + dx, top + row + dy
                if img.getpixel((px, py)) in BLUE:
                    img.putpixel((px, py), BLUE[0])
    for row, (x0, x1) in enumerate(emblem):
        for dx in range(x0, x1 + 1):
            img.putpixel((ci + dx, top + row), EMBLEM_SHADE if (dx == x1 and x1 > 0) else EMBLEM)
    # Cam parlaması (sol-üst).
    hx, hy = int(c - r_out * 0.45), int(c - r_out * 0.5)
    img.putpixel((hx, hy), SHINE)
    if gold_ring:
        img.putpixel((hx + 1, hy), SHINE)
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    small = draw_orb(16, False, EMBLEM_SMALL)
    large = draw_orb(20, True, EMBLEM_LARGE)
    small.save(os.path.join(OUT, "shield_orb_small.png"))
    large.save(os.path.join(OUT, "shield_orb_large.png"))
    if len(sys.argv) > 1:
        prev = Image.new("RGBA", (44, 24), (0x3a, 0x6b, 0x35, 255))
        prev.alpha_composite(small, (3, 4))
        prev.alpha_composite(large, (22, 2))
        prev.resize((44 * 12, 24 * 12), Image.NEAREST).save(sys.argv[1])


if __name__ == "__main__":
    main()
