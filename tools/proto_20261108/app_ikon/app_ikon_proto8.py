"""UYGULAMA İKONU v8: güncel ikonun (Büyücü / Alacakaranlık, madde 488) ZEMİNİ DAHA İNCE / NET (oyuna bağlı DEĞİL).

Çalıştır:  python tools/proto_20261108/app_ikon/app_ikon_proto8.py      -> out/ozet_v8.png + out/ikon_v8_*.png

Kullanıcı (2026-11-10): "arkaplanı daha az pixel yapar mısın çok küçük pixelde bir pixel art bu" + "ben daha net dursun dedim
daha pixel değil, örneğin 32x32 ise 64x64 yap gibi". Karakter (büst) ve çerçeve karakter ızgarasında kalır; yalnız gök zemini
f kat İNCE ızgarada çizilir (1 zemin pikseli = karakter pikselinin 1/f'si). Ekran pikseli tam sayı kalsın diye:
  A / B  kanvas 28 x 9  (252 px, yüz bugünkü boyda), zemin 84 ızgara  -> 1 zemin pikseli = 3 ekran pikseli
  C      kanvas 32 x 8  (256 px, yüz %11 küçük, büst 28x28 kırpım), zemin 64 ızgara -> 1 zemin pikseli = 4 ekran pikseli
         (kullanıcının örneği birebir: 32'lik ikonun zemini 64)
(28 kanvasta "2 kat" 4,5 ekran pikseli olurdu: eşitsiz piksel, madde 508 sorunu.)
Zemin içeriği aynı fikir: düz bantlar (gradyan/dither yok), yıldızlar, alt köşelerde haritanın çalıları koyu mor silüet -
çalılar artık haritadaki kendi piksel boyunda iri büyütülmeden (tek çalı yerine iki üç çalılık öbek; iki yan farklı, ayna değil).
Yıldızlar iç hattan / büstten en az 2 zemin pikseli uzak (kendi denetimi).
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

BRIGHT = '#e8e4f6'
DIM = '#b8b8dc'
GAP = 2  # yıldız <-> iç hat / büst arası en az boş zemin pikseli


def _mix(a, b):
    ca, cb = gai._hex(a), gai._hex(b)
    return '#%02x%02x%02x' % tuple((ca[i] + cb[i]) // 2 for i in range(3))


BANDS7 = list(gai.DUSK_BANDS)
BANDS13 = [c for i, b in enumerate(BANDS7) for c in ([b] if i == 0 else [_mix(BANDS7[i - 1], b), b])]


def _star(p, nf, x, y, kind):
    def put(pts, col):
        for px_, py_ in pts:
            if 0 <= px_ < nf and 0 <= py_ < nf:
                p[px_, py_] = gai._hex(col)
    if kind == 'big':      # 5x5 artı: merkez + iç kollar parlak, uçlar sönük
        put([(x, y), (x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)], BRIGHT)
        put([(x - 2, y), (x + 2, y), (x, y - 2), (x, y + 2)], DIM)
    elif kind == 'plus':   # 3x3 artı
        put([(x, y), (x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)], BRIGHT)
    else:
        put([(x, y)], BRIGHT if kind == 'dot' else DIM)
    return {'big': 2, 'plus': 1}.get(kind, 0)


def fine_sky(nf, bands, stars, bushes):
    img = Image.new('RGBA', (nf, nf), (0, 0, 0, 255))
    p = img.load()
    edges = [round(nf * (i + 1) / len(bands)) for i in range(len(bands))]
    for y in range(nf):
        c = gai._hex(bands[next(k for k, e in enumerate(edges) if y < e)])
        for x in range(nf):
            p[x, y] = c
    star_px = []
    for x, y, kind in stars:
        r = _star(p, nf, x, y, kind)
        star_px += [(x + dx, y + dy) for dx in range(-r, r + 1) for dy in range(-r, r + 1) if dx == 0 or dy == 0]
    tr = [t for t in mb.sprites(mb.TREES) if t.height <= 100]
    for idx, x, y, k in bushes:  # (çalı, sol üst x, y, koyuluk) - arkadakiler önce
        img.alpha_composite(mb.recolor(tr[idx], mb.shade(k, (52, 30, 70), 0.55)), (x, y))
    return img, star_px


def compose(n, s, f, bust, sky, star_px):
    """Ekran çözünürlüğünde (n*s): zemin (s/f katı) + karakter ızgarasında çerçeve ve büst (s katı)."""
    m, outline, light = gai._frame_rings(n)
    frame = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    fp = frame.load()
    for y in range(n):
        for x in range(n):
            if outline[y][x]:
                fp[x, y] = gai.OUTL
            elif light[y][x]:
                fp[x, y] = gai.DUSK_LIGHT
    sprite = Image.open(gai.DUSK_PORTRAIT).convert('RGBA').crop(bust)
    layer = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    layer.alpha_composite(sprite, ((n - sprite.width) // 2, n - 2 - sprite.height))
    lp = layer.load()
    for y in range(n):
        for x in range(n):
            if not m[y][x] or outline[y][x] or light[y][x]:
                lp[x, y] = (0, 0, 0, 0)
    size = n * s
    out = sky.resize((size, size), Image.NEAREST)
    out.alpha_composite(frame.resize((size, size), Image.NEAREST))
    out.alpha_composite(layer.resize((size, size), Image.NEAREST))
    mask = Image.new('L', (n, n), 0)
    mp = mask.load()
    for y in range(n):
        for x in range(n):
            mp[x, y] = 255 if m[y][x] else 0
    out.putalpha(mask.resize((size, size), Image.NEAREST))
    # denetim: yıldız pikselinin GAP zemin pikseli çevresinde iç hat / kontur / büst / dış yok
    bad = 0
    for sx, sy in star_px:
        for dx in range(-GAP, GAP + 1):
            for dy in range(-GAP, GAP + 1):
                cx, cy = (sx + dx) // f, (sy + dy) // f
                if not (0 <= cx < n and 0 <= cy < n) or not m[cy][cx] or outline[cy][cx] or light[cy][cx] \
                        or lp[cx, cy][3] > 0:
                    bad += 1
    return out, bad


# ad: (başlık, kanvas n, ölçek s, incelik f, büst, bantlar, yıldızlar (zemin ızgarasında), çalılar)
PROTOS = {
    'A': ('A - 3 kat ince', 28, 9, 3, gai.DUSK_BUST, BANDS7,
          [(15, 15, 'big'), (66, 24, 'big'), (26, 8, 'dot'), (9, 27, 'dim'), (24, 22, 'dim'), (58, 9, 'dot'),
           (72, 12, 'dim'), (74, 36, 'dim')],
          [(12, -12, 54, 0.36), (7, 4, 62, 0.46), (10, 62, 52, 0.36), (15, 52, 64, 0.46)]),
    'B': ('B - ince + yumuşak gök', 28, 9, 3, gai.DUSK_BUST, BANDS13,
          [(15, 15, 'big'), (66, 24, 'big'), (26, 8, 'dot'), (9, 27, 'dim'), (24, 22, 'dim'), (58, 9, 'dot'),
           (72, 12, 'dim'), (74, 36, 'dim'), (18, 30, 'dim'), (11, 9, 'dim'), (55, 14, 'dim'), (75, 22, 'dot')],
          [(12, -12, 54, 0.36), (7, 4, 62, 0.46), (10, 62, 52, 0.36), (15, 52, 64, 0.46)]),
    'C': ('C - 32 kanvas, 64 zemin', 32, 8, 2, (10, 1, 38, 29), BANDS13,
          [(11, 11, 'big'), (52, 17, 'big'), (19, 6, 'dot'), (7, 20, 'dim'), (17, 17, 'dim'), (45, 6, 'dot'),
           (56, 9, 'dim'), (57, 27, 'dim')],
          [(12, -14, 40, 0.36), (7, 0, 46, 0.46), (10, 44, 38, 0.36), (15, 38, 48, 0.46)]),
}


def main():
    os.makedirs(v1.OUT, exist_ok=True)
    arts = {'simdi': gai.art_dusk()}
    titles = {'simdi': ('ŞU AN', None, None)}
    for key, (title, n, s, f, bust, bands, stars, bushes) in PROTOS.items():
        sky, star_px = fine_sky(n * f, bands, stars, bushes)
        arts[key], bad = compose(n, s, f, bust, sky, star_px)
        print(key, f'{n}x{s}={n * s} px, zemin {n * f}', 'yıldız teması:', bad)
        out = Image.new('RGBA', (256, 256), (0, 0, 0, 0))
        out.alpha_composite(arts[key], ((256 - arts[key].width) // 2, (256 - arts[key].height) // 2))
        out.save(os.path.join(v1.OUT, f'ikon_v8_{key}.png'))
        titles[key] = (title, None, None)
    v1.PROTOS = titles
    out = os.path.join(v1.OUT, 'ozet_v8.png')
    v1.summary(arts).save(out)
    print(out)


if __name__ == '__main__':
    main()
