# DERİN ORMAN bölge maskesi (madde 359/361): assets/map/derin_orman_bolge.png - 256x256, hücre başına 1 px (hücre (x, y) = piksel (x, y)).
# R = Kuzey "Kadim Kara Orman", G = Batı "Kızıl Bataklık", B = Doğu "Işıyan Kayalıklar", A = Güney "Sisli Sazlık" (madde 361; .import'ta
# fix_alpha_border KAPALI olmalı - yoksa Godot saydam piksellerin RGB'sini komşudan doldurur ve R/G/B kanalları bozulur).
# Bölge hücreleri = 1. Bölgenin dışında ÇİMENLİ ve duvarsız (uçurum/su değil) hücrelere değer RAMP hücrede söner (açık arazi: kuzey-batı ortak
# kenarı, kuzeyin nehir batısındaki güney kenarı, doğunun batı kenarı, güneyin iki havzanın birleştiği batı kenarı) -> zemin/renk orada geniş,
# adacıklı bir geçişle biter (madde 361 2. tur: "ani kesikler"). Uçurum/su ile biten kenarda geçiş kısa kalır; çimensiz kuma (sağ alt düşman
# üssü) geçiş taşmaz. Sonra 2 hücre genişletme + yumuşatma (renk ayarı uçurum hattında yavaş başlar).
# Harita shader'ları global `derin_orman_maske` ile okur (harita_renk.gdshaderinc). Harita (uçurum/su) değişince yeniden çalıştır, sonra
# `--headless --import`.
# Kullanım: python tools/derin_orman/gen_bolge_maskesi.py  (place_derin_orman.py --apply bunu zaten yazar)
import os
import sys
from collections import deque

from PIL import Image, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import derin_orman_core as C  # noqa: E402

OUT = os.path.join(C.PROJECT, 'assets', 'map', 'derin_orman_bolge.png')
RAMP = 9
BLUR = {'kuzey': 3.0, 'bati': 2.2, 'dogu': 3.0, 'guney': 3.0}


def channel(layers, name, open_cells):
    zone = set().union(*(C.zone_cells(layers, n) for n in C.MASK_PARTS.get(name, [name])))
    dist = {c: 0 for c in zone}
    q = deque(zone)
    while q:
        c = q.popleft()
        d = dist[c]
        if d >= RAMP:
            continue
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (c[0] + dx, c[1] + dy)
            if 0 <= n[0] < C.N and 0 <= n[1] < C.N and n in open_cells and n not in dist:
                dist[n] = d + 1
                q.append(n)
    m = Image.new('L', (C.N, C.N), 0)
    for c, d in dist.items():
        m.putpixel(c, int(round(255 * (1.0 - d / (RAMP + 1.0)))))
    return m.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(BLUR[name]))


def build_mask(layers):
    """Katmanlardan (derin_orman_core.tmx_layers) RGBA maske görüntüsü. place_derin_orman.py yazmadan önce de çağırır (zemin karoları, madde 363)."""
    walls = (set(layers['Orman parçaları']) | set(layers['Su'])) - set(layers['Köprü alt'])
    open_cells = set(layers['Zemin Çimen']) - walls
    return Image.merge('RGBA', [channel(layers, n, open_cells) for n in C.ZONE_ORDER])


def main():
    build_mask(C.tmx_layers(open(C.TMX, encoding='utf-8').read())).save(OUT)
    print('yazıldı', OUT)


if __name__ == '__main__':
    main()
