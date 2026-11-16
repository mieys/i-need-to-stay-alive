"""ANA HARİTA gece ateş böceği alanlarını üretir (madde 761): assets/ui/minimap_map.png'den (1 doku pikseli = 32 dünya px, her yanda
32 piksel kenar payı; tools/bake_minimap.gd) nehir / gölet kıyıları ve orman kenarındaki açıklıklar seçilir.

    python tools/ates_bocegi/gen_ana_bocek.py            -> yalnız özet + önizleme (scratch'e değil, bu klasöre onizleme.png)
    python tools/ates_bocegi/gen_ana_bocek.py --write    -> scripts/ana_harita_bocek_meta.gd'yi YENİDEN YAZAR

Harita yeniden bake edilip minimap değişince tekrar çalıştır. Koordinatlar HARİTA KÖKÜNÜN yerel koordinatı (main.tscn'de Harita (-2, 21)'de;
ates_bocegi_fx.gd global dönüşümle çevirir).
"""
import os
import random
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MINIMAP = os.path.join(ROOT, 'assets', 'ui', 'minimap_map.png')
OUT = os.path.join(ROOT, 'scripts', 'ana_harita_bocek_meta.gd')
TEXEL = 32.0  # minimap.gd MAP_TEXEL_WORLD
PAD = 32  # minimap.gd MAP_PAD_TEXELS
MARGIN = 3  # oyun alanı kenarından (dış çerçeve) bu kadar doku pikseli içeride

KIYI_ARALIK = 8  # kıyı alanları arası en az (doku pikseli; 8 = 256 dünya px)
ACIKLIK_ARALIK = 12
KIYI_EN_COK = 26
ACIKLIK_EN_COK = 18


def kind(c):
    r, g, b = c
    if b > g and b > r + 25:
        return 'su'
    if r >= g - 4:
        return 'toprak'  # patika / çıplak toprak / kaya
    if g < 125:
        return 'orman'
    return 'cayir'


def main():
    write = '--write' in sys.argv
    im = Image.open(MINIMAP).convert('RGB')
    w, h = im.size
    k = [[kind(im.getpixel((x, y))) for x in range(w)] for y in range(h)]
    lo, hi = PAD + MARGIN, w - PAD - MARGIN

    def near(x, y, what, d):
        for yy in range(y - d, y + d + 1):
            for xx in range(x - d, x + d + 1):
                if 0 <= xx < w and 0 <= yy < h and k[yy][xx] == what:
                    return True
        return False

    rng = random.Random(732)
    kiyi, aciklik = [], []
    for y in range(lo, hi):
        for x in range(lo, hi):
            if k[y][x] not in ('cayir', 'orman'):
                continue
            if near(x, y, 'su', 1):
                kiyi.append((x, y))
            elif k[y][x] == 'cayir' and near(x, y, 'orman', 2) and not near(x, y, 'toprak', 1):
                aciklik.append((x, y))
    rng.shuffle(kiyi)
    rng.shuffle(aciklik)

    chosen = []

    def pick(cands, gap, limit, rad):
        n = 0
        for (x, y) in cands:
            if n >= limit:
                break
            if any((x - cx) ** 2 + (y - cy) ** 2 < gap * gap for (cx, cy, _) in chosen):
                continue
            chosen.append((x, y, rad(rng)))
            n += 1
        return n

    nk = pick(kiyi, KIYI_ARALIK, KIYI_EN_COK, lambda r: r.uniform(64.0, 84.0))
    na = pick(aciklik, ACIKLIK_ARALIK, ACIKLIK_EN_COK, lambda r: r.uniform(56.0, 76.0))
    zones = []
    for (x, y, rad) in chosen:
        wx = (x - PAD + rng.uniform(0.2, 0.8)) * TEXEL
        wy = (y - PAD + rng.uniform(0.2, 0.8)) * TEXEL
        zones.append((round(wx, 1), round(wy, 1), round(rad, 1)))
    zones.sort(key=lambda z: (z[1], z[0]))
    print('kiyi aday %d secilen %d | aciklik aday %d secilen %d | toplam %d' % (len(kiyi), nk, len(aciklik), na, len(zones)))

    prev = im.resize((w * 3, h * 3), Image.NEAREST)
    px = prev.load()
    for (x, y, _) in chosen:
        for dy in range(-2, 3):
            for dx in range(-2, 3):
                X, Y = x * 3 + 1 + dx, y * 3 + 1 + dy
                if 0 <= X < w * 3 and 0 <= Y < h * 3:
                    px[X, Y] = (255, 240, 90)
    prev.save(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'onizleme.png'))

    if not write:
        return
    lines = [
        'extends RefCounted',
        '',
        '## ANA HARİTA gece ateş böceği alanları - tools/ates_bocegi/gen_ana_bocek.py --write ÜRETİR (elle düzenleme; üreteç ezer).',
        '## [merkez (HARİTA KÖKÜNÜN yerel koordinatı), yarıçap] - nehir / gölet kıyıları ve orman kenarındaki açıklıklar (madde 761).',
        '',
        'const FIREFLY_ZONES := [',
    ]
    for (x, y, r) in zones:
        lines.append('\t[Vector2(%.1f, %.1f), %.1f],' % (x, y, r))
    lines.append(']')
    with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(lines) + '\n')
    print('yazildi', OUT)


if __name__ == '__main__':
    main()
