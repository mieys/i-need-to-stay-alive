"""UYGULAMA İKONU v7: v6 (kenarı düzeltilmiş Büyücü / Alacakaranlık) - YÜZ biraz YUKARI (madde 488, oyuna bağlı DEĞİL).

Çalıştır:  python tools/proto_20261108/app_ikon/app_ikon_proto7.py      -> out/ozet_v7.png + out/ikon_v7_*.png

Kullanıcı (2026-11-10): "büyücü kızın yüzünü birazcık yukarı taşır mısın odak görünmesi için". Yüz yukarı = kırpım aşağı kayar =
şapka da yukarı çıkar; v6'da şapka ucunun üstünde yalnız 1 px gök var. Üç yol:
  A 1 satır  - kırpım (12,2,36,26): şapka ucu iç hatta dayanır, gök payı yok
  B 2 satır  - kırpım (12,1,36,27) 26 satır: şapka ucu iç hattın ÜSTÜNE biner (çerçeveden taşar), şapka tam kalır
  C 2 satır  - kırpım (12,3,36,27): şapka ucunun 1 pikseli iç hatta kesilir, çerçeve kesintisiz
Zemin / çerçeve / iç hat v6'nın aynısı (app_ikon_proto6).
"""
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
sys.path.insert(0, HERE)
import gen_app_icon as gai  # noqa: E402
import app_ikon_proto as v1  # noqa: E402
import app_ikon_proto2 as v2  # noqa: E402
import app_ikon_proto6 as v6  # noqa: E402

N = v6.N
CROWNS = v6.PROTOS['sonra'][1]


def gok_yukari(img, crowns_fn):
    """Yüz yukarı çıkınca şapka kenarı 8-9. satıra çıkar ve v6'nın meteor başı / sağ yıldızıyla çarpışır: meteor kısalır ve
    yukarıda biter (kenardan 1 satır boşluk), sağdaki büyük yıldız yerine şapka ucunun yanında uzak yıldız."""
    v2.bands(img, ['#252c5c', '#33386e', '#4e4280', '#7a4c82', '#a8587a', '#d0745e', '#e8a064'], [2] * 7)
    v2.star(img, 4, 4, '#e8e4f6')
    v2.px(img, [(3, 8), (10, 3), (17, 3)], '#b8b8dc')
    v2.px(img, [(20, 3), (21, 4), (22, 5)], '#f0b070')
    v2.px(img, [(23, 6), (24, 6), (23, 7)], '#fff0d0')
    v2._crowns(img, crowns_fn)


def art(bust, over_top=False, sky=None):
    """v6.art ile aynı çerçeve + zemin; büst alttan iç hatta oturur (y = N - 2 - h). over_top: büstün iç alanın ÜSTÜNE
    taşan satırları (şapka ucu) iç hattın üstüne çizilir, dış kontura dokunmaz."""
    v2.N = N
    m, outline, light = v6.frame_rings(N)
    bg = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    (sky or v6.alacakaranlik)(bg, CROWNS)
    bp = bg.load()
    img = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    px = img.load()
    for y in range(N):
        for x in range(N):
            if not m[y][x]:
                continue
            px[x, y] = gai.OUTL if outline[y][x] else (v6.LIGHT if light[y][x] else bp[x, y])
    sprite = Image.open(v6.PORTRAIT).convert('RGBA').crop(bust)
    layer = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    layer.alpha_composite(sprite, ((N - sprite.width) // 2, N - 2 - sprite.height))
    lp = layer.load()
    for y in range(N):
        for x in range(N):
            keep = m[y][x] and not outline[y][x] and (not light[y][x] or (over_top and y < 2))
            if not keep:
                lp[x, y] = (0, 0, 0, 0)
    img.alpha_composite(layer)
    return img


PROTOS = {
    'v6': ('v6 - şimdiki', (12, 1, 36, 25), False),
    'A': ('A - 1 satır yukarı', (12, 2, 36, 26), False),
    'B': ('B - 2 satır, uç taşar', (12, 1, 36, 27), True),
    'C': ('C - 2 satır, uç kesik', (12, 3, 36, 27), False),
}


def main():
    os.makedirs(v1.OUT, exist_ok=True)
    arts = {}
    for k, (_, bust, over) in PROTOS.items():
        arts[k] = art(bust, over, None if k == 'v6' else gok_yukari)
        if k != 'v6':
            gai.at_size(arts[k], 256).save(os.path.join(v1.OUT, f'ikon_v7_{k}.png'))
    v1.PROTOS = {k: (v[0], None, None) for k, v in PROTOS.items()}
    out = os.path.join(v1.OUT, 'ozet_v7.png')
    v1.summary(arts).save(out)
    print(out)


if __name__ == '__main__':
    main()
