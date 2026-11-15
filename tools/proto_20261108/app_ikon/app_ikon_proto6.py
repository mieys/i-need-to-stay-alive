"""UYGULAMA İKONU v6: v3 D "Büyücü / Alacakaranlık" KENAR DÜZELTMESİ (madde 488, oyuna bağlı DEĞİL).

Çalıştır:  python tools/proto_20261108/app_ikon/app_ikon_proto6.py      -> out/ozet_v6.png + out/ikon_v6_*.png

Kullanıcı (2026-11-10): "büyücü alacakaranlığın kenarlarını düzeltir misin v3 ün". v3 D'de (gen_app_icon.art) kenar sorunları:
  1) açık iç hat yalnız üst/sol/sağda (alt yok), alt köşelerde tek tük açık piksel;
  2) büst kanvasın 1. satırından başlar -> şapka ucu üst iç hattı deler, cübbe alt konturun dibine yapışır;
  3) köşe çalı taçları neredeyse siyah (kenarlar kirli);
  4) iç hat köşede konturu izlemez (4 komşuluk + "y-2" kuralı basamak bırakır).
Düzeltme: kanvas 26 -> 28 (256'da yine 9x, ikon 234 -> 252 px dolar), kontur = maskenin dış halkası, iç hat = konturun 8 komşulu
iç halkası (dört kenar + köşeler kesintisiz), büst iç hattın İÇİNE yerleşir ve oraya kırpılır, kırpım bir satır yukarı (şapka
ucunun üstünde 1 px gök), çalı taçları gecenin koyu morunda silüet. Zemin bantları v3 D'nin aynısı; yıldız/meteor iç hattan en az 1 px uzakta.
"""
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
sys.path.insert(0, HERE)
import gen_app_icon as gai  # noqa: E402
import gen_menu_bg as mb  # noqa: E402
import app_ikon_proto as v1  # noqa: E402
import app_ikon_proto2 as v2  # noqa: E402
import app_ikon_proto3 as v3  # noqa: E402

N = 28
LIGHT = (150, 124, 176, 255)
PORTRAIT = os.path.join(ROOT, 'assets', 'characters', 'buyucu_portrait.png')
BUST = (12, 1, 36, 25)  # v3 D (12,2,36,26)'nın bir satır yukarısı: şapka ucunun üstünde gök


def alacakaranlik(img, crowns_fn):
    """v3 D zemini, 28 kanvasa: aynı 7 bant, motifler +1 kayık (iç alan bir piksel içeri kaydı)."""
    # yıldız / meteor iç hatta değmez (en az 1 px gök): v3 D'de hatta yapışan piksel çerçeveyi "şişmiş" gösteriyordu
    v2.bands(img, ['#252c5c', '#33386e', '#4e4280', '#7a4c82', '#a8587a', '#d0745e', '#e8a064'], [2] * 7)
    for (x, y) in [(4, 4), (22, 10)]:
        v2.star(img, x, y, '#e8e4f6')
    v2.px(img, [(3, 8), (10, 3), (24, 4)], '#b8b8dc')
    v2.px(img, [(18 + k, 3 + k) for k in range(5)], '#f0b070')
    v2.px(img, [(23, 8), (24, 8), (23, 9)], '#fff0d0')
    v2._crowns(img, crowns_fn)


def frame_rings(n, r=3):
    m = gai.rounded_mask(n, r)

    def inside(x, y):
        return 0 <= x < n and 0 <= y < n and m[y][x]

    outline = [[inside(x, y) and any(not inside(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                for x in range(n)] for y in range(n)]
    light = [[inside(x, y) and not outline[y][x] and any(
        0 <= x + dx < n and 0 <= y + dy < n and outline[y + dy][x + dx]
        for dx in (-1, 0, 1) for dy in (-1, 0, 1) if dx or dy)
        for x in range(n)] for y in range(n)]
    return m, outline, light


def art(crowns_fn, light_col=LIGHT, bust=BUST):
    v2.N = N
    m, outline, light = frame_rings(N)
    bg = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    alacakaranlik(bg, crowns_fn)
    bp = bg.load()
    img = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    px = img.load()
    for y in range(N):
        for x in range(N):
            if not m[y][x]:
                continue
            if outline[y][x]:
                px[x, y] = gai.OUTL
            elif light[y][x] and light_col:
                px[x, y] = light_col
            else:
                px[x, y] = bp[x, y]
    # büst iç hattın İÇİNDE: 24x24 kırpım, iç alan 2..25 (kontur 0/27, iç hat 1/26)
    sprite = Image.open(PORTRAIT).convert('RGBA').crop(bust)
    layer = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    layer.alpha_composite(sprite, ((N - sprite.width) // 2, N - 2 - sprite.height))
    lp = layer.load()
    for y in range(N):
        for x in range(N):
            if not m[y][x] or outline[y][x] or (light_col and light[y][x]):
                lp[x, y] = (0, 0, 0, 0)
    img.alpha_composite(layer)
    return img


def old_d():
    gai.N = 26
    v2.N = 26
    gai.PORTRAIT = PORTRAIT
    gai.BUST = (12, 2, 36, 26)
    gai.VARIANTS['v6_old'] = (v3.buyucu_alacakaranlik, LIGHT)
    return gai.art('v6_old')


PROTOS = {
    'once': ('ÖNCE - v3 D', None),
    'sonra': ('SONRA - kenar düzeltildi', mb.shade(0.42, (52, 30, 70), 0.55)),
}


def main():
    os.makedirs(v1.OUT, exist_ok=True)
    arts = {'once': old_d()}
    gai.N = N
    arts['sonra'] = art(PROTOS['sonra'][1])
    gai.at_size(arts['sonra'], 256).save(os.path.join(v1.OUT, 'ikon_v6_sonra.png'))
    v1.PROTOS = {k: (v[0], None, None) for k, v in PROTOS.items()}
    out = os.path.join(v1.OUT, 'ozet_v6.png')
    v1.summary(arts).save(out)
    print(out)


if __name__ == '__main__':
    main()
