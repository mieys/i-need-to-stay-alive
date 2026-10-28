# DERİN ORMAN ışık dokuları (madde 359/360), assets/fx/derin_orman/: deep_forest_fx.gd toplamalı karışımla çizer (alfa = parlaklık payı), dither yok.
#   ruh_isigi.png (Kuzey, 9x9): artı biçimli parlak çekirdek + basamaklı camgöbeği-yeşil hale
#   spor.png (Batı, 7x7): sönük kızıl-pembe spor
#   parilti.png (Doğu, 7x7): dört kollu beyaz-mavi kristal pırıltısı
#   ates_bocegi.png (Güney, 5x5, madde 361): sıcak sarı-yeşil ateş böceği
#   kapi_isigi.png (zindan girişleri, 31x31, madde 361): beyaz basamaklı hale - renk bölgeye göre modulate ile verilir
# Kullanım: python tools/derin_orman/gen_ruh_isigi.py
import math
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, '..', '..', 'assets', 'fx', 'derin_orman', 'ruh_isigi.png'))
CORE = (225, 255, 235)
MID = (115, 250, 210)
HALO = (70, 230, 190)
## (en büyük uzaklık, renk, alfa) - içten dışa
STEPS = [(0.5, CORE, 255), (1.1, MID, 230), (1.9, HALO, 120), (2.9, HALO, 55), (4.1, HALO, 22)]


SPORE = [(0.5, (255, 200, 205), 220), (1.1, (235, 95, 125), 150), (2.1, (205, 60, 110), 60), (3.1, (190, 50, 100), 20)]


def radial(size, steps):
    im = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    m = size // 2
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - m, y - m)
            for r, col, a in steps:
                if d <= r:
                    im.putpixel((x, y), col + (a,))
                    break
    return im


FIREFLY = [(0.5, (255, 255, 200), 255), (1.1, (215, 255, 120), 170), (2.1, (170, 230, 80), 50)]
GATE = [(2.5, (255, 255, 255), 120), (5.5, (255, 255, 255), 80), (9.5, (255, 255, 255), 48), (13.5, (255, 255, 255), 24), (15.5, (255, 255, 255), 10)]


def sparkle():
    im = Image.new('RGBA', (7, 7), (0, 0, 0, 0))
    im.putpixel((3, 3), (255, 255, 255, 255))
    for d, a in [(1, 200), (2, 110), (3, 40)]:
        for x, y in [(3 - d, 3), (3 + d, 3), (3, 3 - d), (3, 3 + d)]:
            im.putpixel((x, y), (190, 230, 255, a))
    for x, y in [(2, 2), (4, 2), (2, 4), (4, 4)]:
        im.putpixel((x, y), (150, 200, 255, 60))
    return im


def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    radial(9, STEPS).save(OUT)
    radial(7, SPORE).save(os.path.join(os.path.dirname(OUT), 'spor.png'))
    sparkle().save(os.path.join(os.path.dirname(OUT), 'parilti.png'))
    radial(5, FIREFLY).save(os.path.join(os.path.dirname(OUT), 'ates_bocegi.png'))
    radial(31, GATE).save(os.path.join(os.path.dirname(OUT), 'kapi_isigi.png'))
    print('yazıldı', os.path.dirname(OUT))


if __name__ == '__main__':
    main()
