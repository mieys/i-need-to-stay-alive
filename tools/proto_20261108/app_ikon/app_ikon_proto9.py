"""UYGULAMA İKONU v9: v8 B / C + YUMUŞAK GÜN BATIMI + yumuşak sol çalı (madde 488, oyuna bağlı DEĞİL).

Çalıştır:  python tools/proto_20261108/app_ikon/app_ikon_proto9.py      -> out/ozet_v9.png + out/ikon_v9_*.png

Kullanıcı (2026-11-10): "günbatımı ışık geçişlerinin katman katman değil smooth bir şekilde geçmesini istiyorum ayrıca soldaki ağaç
keskin duruyor biraz yumuşat onu sol tarafla tamamla".
  - Gök: bant yerine EKRAN PİKSELİNDE düz dikey geçiş (aynı 7 renk durak, satır başına 1 px; dither yok) - önceki "gradyan yok"
    kuralını kullanıcı bu ikon için kaldırdı.
  - Sol çalı: v8'deki sivri çalı (tr[12]) yerine yuvarlak tr[15], tepesi tam sol kenarda (v8'de kenarda çentik kalıyordu, gök
    görünüyordu) + önde yuvarlak tr[7]; sağ taraf aynı (tr[10] + tr[15]) -> iki yan da kenarda yüksek, saça doğru alçalır, ayna değil.
Yıldızlar / karakter / çerçeve v8 B ve C'nin aynısı.
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
import app_ikon_proto8 as v8  # noqa: E402


def gradient(size, stops):
    """Ekran pikselinde dikey düz geçiş: duraklar eşit aralıklı, satır başına tek renk."""
    cols = [gai._hex(c) for c in stops]
    img = Image.new('RGBA', (size, size))
    p = img.load()
    for y in range(size):
        t = y / (size - 1) * (len(cols) - 1)
        i = min(int(t), len(cols) - 2)
        u = t - i
        c = tuple(round(cols[i][k] + (cols[i + 1][k] - cols[i][k]) * u) for k in range(3)) + (255,)
        for x in range(size):
            p[x, y] = c
    return img


def overlay(nf, stars, bushes):
    """Yıldız + çalılar saydam zemin ızgarasında (v8.fine_sky'ın bantsız hâli)."""
    img = Image.new('RGBA', (nf, nf), (0, 0, 0, 0))
    p = img.load()
    star_px = []
    for x, y, kind in stars:
        r = v8._star(p, nf, x, y, kind)
        star_px += [(x + dx, y + dy) for dx in range(-r, r + 1) for dy in range(-r, r + 1) if dx == 0 or dy == 0]
    tr = [t for t in mb.sprites(mb.TREES) if t.height <= 100]
    for idx, x, y, k in bushes:
        img.alpha_composite(mb.recolor(tr[idx], mb.shade(k, (52, 30, 70), 0.55)), (x, y))
    return img, star_px


def build(n, s, f, bust, smooth, stars, bushes):
    size = n * s
    ov, star_px = overlay(n * f, stars, bushes)
    if smooth:
        sky = gradient(size, gai.DUSK_BANDS)
    else:
        sky, _ = v8.fine_sky(n * f, v8.BANDS13, [], [])
        sky = sky.resize((size, size), Image.NEAREST)
    sky.alpha_composite(ov.resize((size, size), Image.NEAREST))
    return v8.compose(n, s, f, bust, sky, star_px)


_, _, _, _, _, _, STARS_B, BUSH_B = v8.PROTOS['B']
_, _, _, _, BUST_C, _, STARS_C, BUSH_C = v8.PROTOS['C']
LEFT_B = [(15, -12, 53, 0.36), (7, 5, 63, 0.46)]
LEFT_C = [(15, -12, 39, 0.36), (7, 2, 48, 0.46)]

# ad: (başlık, n, s, f, büst, yumuşak gök, yıldızlar, çalılar)
PROTOS = {
    'B': ('ÖNCE - v8 B', 28, 9, 3, gai.DUSK_BUST, False, STARS_B, BUSH_B),
    'B2': ('B2 - yumuşak', 28, 9, 3, gai.DUSK_BUST, True, STARS_B, LEFT_B + BUSH_B[2:]),
    'C2': ('C2 - yumuşak, 32', 32, 8, 2, BUST_C, True, STARS_C, LEFT_C + BUSH_C[2:]),
}


def main():
    os.makedirs(v1.OUT, exist_ok=True)
    arts, titles = {}, {}
    for key, (title, n, s, f, bust, smooth, stars, bushes) in PROTOS.items():
        arts[key], bad = build(n, s, f, bust, smooth, stars, bushes)
        print(key, 'yıldız teması:', bad)
        out = Image.new('RGBA', (256, 256), (0, 0, 0, 0))
        out.alpha_composite(arts[key], ((256 - arts[key].width) // 2, (256 - arts[key].height) // 2))
        out.save(os.path.join(v1.OUT, f'ikon_v9_{key}.png'))
        titles[key] = (title, None, None)
    v1.PROTOS = titles
    out = os.path.join(v1.OUT, 'ozet_v9.png')
    v1.summary(arts).save(out)
    print(out)


if __name__ == '__main__':
    main()
