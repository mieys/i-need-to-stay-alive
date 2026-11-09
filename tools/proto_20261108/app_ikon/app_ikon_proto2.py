"""UYGULAMA İKONU prototipleri v2: her karaktere KENDİ arka planı (madde 488'in devamı, oyuna bağlı DEĞİL).

Çalıştır:  python tools/proto_20261108/app_ikon/app_ikon_proto2.py      -> out/ozet_v2.png + out/ikon_v2_*.png

Kullanıcı (2026-11-08, v1'den sonra): "arkaplanı da değiştir daha farklı prototipler yap". v1'de dört karakter de bugünkü
çayırın önündeydi. v2'de her karakterin arka planı oyundaki portre temasından (tools/proto_20261108/portre_tema, madde 464:
"karakterin temasıyla uyumlu" onaylı) büyütülüp ikon kanvasına (26x26 sanat pikseli, 256'da 9x) yeniden kurulur: düz bantlar + tek
motif, dither / hale / parıltı yok. Ayrıca her biri ayrı renk ailesinde (lacivert / mor-ay / gök mavisi / turuncu) ki görev
çubuğunda yan yana karışmasınlar. Koyu zeminlilerde çerçevenin içinde 1 px açık hat (koyu görev çubuğunda kenar seçilsin).
Çerçeve, büst kırpımı, ICO boy kuralı tools/gen_app_icon.py'den aynen.
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

N = gai.N  # 26


def C(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def bands(img, cols, weights):
    tot, acc, edges = sum(weights), 0, []
    for w in weights:
        acc += w
        edges.append(round(N * acc / tot))
    p = img.load()
    for y in range(N):
        c = C(cols[next(k for k, e in enumerate(edges) if y < e)])
        for x in range(N):
            p[x, y] = c


def px(img, pts, col):
    c = C(col)
    p = img.load()
    for x, y in pts:
        if 0 <= x < N and 0 <= y < N:
            p[x, y] = c


def rect(img, x, y, w, h, col):
    px(img, [(i, j) for i in range(x, x + w) for j in range(y, y + h)], col)


def disc(img, cx, cy, r, col):
    px(img, [(x, y) for x in range(N) for y in range(N) if (x - cx + 0.5) ** 2 + (y - cy + 0.5) ** 2 <= r * r], col)


def star(img, x, y, col):
    px(img, [(x, y), (x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)], col)


def bat(img, x, y, col):
    # 7x3 yarasa: kanat uçları yukarıda, gövde ortada
    px(img, [(x, y), (x + 6, y), (x + 1, y + 1), (x + 2, y + 1), (x + 4, y + 1), (x + 5, y + 1),
             (x + 3, y + 1), (x + 3, y + 2), (x + 2, y), (x + 4, y)], col)


def silhouette(img, heights, col):
    for x, h in enumerate(heights[:N]):
        rect(img, x, N - h, 1, h, col)


def _crowns(img, shade_fn, top=False):
    """Harita tileset'inin iki yuvarlak çalı tacı (bugünkü ikondakilerle aynı sprite'lar), verilen tona boyanmış,
    alt (ya da üst) köşelerden çeyrek olarak taşar."""
    tr = [t for t in mb.sprites(mb.TREES) if t.height <= 100]
    left, right = tr[14], tr[12].transpose(Image.FLIP_LEFT_RIGHT)
    if top:
        ly, ry = -left.height // 2 - 3, -right.height // 2 - 3
    else:
        ly, ry = N - left.height // 2 + 3, N - right.height // 2 + 3
    img.alpha_composite(mb.recolor(left, shade_fn), (-left.width // 2 - 3, ly))
    img.alpha_composite(mb.recolor(right, shade_fn), (N - right.width // 2 + 3, ry))


def gece(img):
    """A - Yıldızlı Gece (Büyücü Kız): gece mavisi bantlar + ufukta sıcak şerit (soğuk/sıcak set), köşelerde yıldız,
    sağ üstten R'nin meteoru düşer; alt köşelerde geceye boyanmış çalı taçları (dünyanın ormanı)."""
    bands(img, ['#2c3a6c', '#34447a', '#3e4e86', '#4a4a7e', '#a8664a'], [3, 3, 3, 2, 1])
    for (x, y) in [(2, 3), (5, 10), (22, 12), (3, 16)]:
        star(img, x, y, '#e8e4f6')
    px(img, [(1, 7), (24, 2), (8, 1), (20, 9)], '#b8b8dc')  # tek piksel uzak yıldızlar
    px(img, [(18 + k, 1 + k) for k in range(5)], '#f0b070')  # meteor izi
    px(img, [(23, 6), (24, 6), (23, 7)], '#fff0d0')        # meteorun başı
    _crowns(img, mb.shade(0.46, (20, 26, 60), 0.45))


def dolunay(img):
    """B - Dolunay (Vampir): mor gece + başın tam arkasında büyük soluk ay (siyah saç ayın üstünde siluet olur),
    ayda iki krater, köşelerde yarasalar."""
    bands(img, ['#2c2440', '#3a2e52', '#4a3862', '#3a2a4c'], [3, 3, 3, 2])
    disc(img, 13, 9, 9.2, '#eadccb')
    disc(img, 17, 6, 1.8, '#d6c4b2')
    disc(img, 8, 12, 1.3, '#d6c4b2')
    # yarasalar ayın kenarına biner (koyu gökte kayboluyorlardı): ay üstünde siluet
    bat(img, 2, 6, '#1a1424')
    bat(img, 19, 12, '#1a1424')
    bat(img, 20, 1, '#1a1424')


def gok(img):
    """C - Gökyüzü (Melek): açık gök bantları yukarıdan aşağı KOYULAŞIR (beyaz kanatlar altta seçilsin), üst köşelerde
    beyaz bulutlar, altın hale mavide okunur."""
    bands(img, ['#b8d3ec', '#a3c4e4', '#8fb6dc', '#7aa4d0'], [3, 3, 3, 2])
    for (cx, cy) in [(3, 3), (22, 2)]:
        rect(img, cx - 3, cy, 7, 2, '#f4f8fc')
        rect(img, cx - 1, cy - 1, 3, 1, '#f4f8fc')
        rect(img, cx - 3, cy + 2, 7, 1, '#d8e6f4')
    rect(img, 0, 13, 3, 1, '#e4eef8')   # uzak ince bulut çizgileri
    rect(img, 22, 11, 4, 1, '#e4eef8')


def gun_batimi(img):
    """D - Gün Batımı (Shaman): turuncu bantlar + iki kat ALÇAK kahve dağ silueti (yalnız omuz hizasında; yüksek dağlar
    kahve sakalla karışıyordu), boynuzların sağındaki boşlukta batan düz güneş diski."""
    bands(img, ['#ecbc78', '#e6a866', '#d98e50', '#c4763e'], [3, 3, 3, 2])
    disc(img, 21, 14, 3.4, '#f8dc96')
    h = [5, 6, 8, 9, 10, 9, 8, 7, 6, 7, 8, 9, 10, 11, 10, 9, 8, 7, 6, 7, 8, 9, 10, 9, 8, 6]
    silhouette(img, h, '#8a5634')
    silhouette(img, [max(0, v - 4) for v in h[::-1]], '#64391f')


# ad: (başlık, portre, büst kırpımı, zemin, çerçeve içi açık hat ya da None)
PROTOS = {
    'simdi': ('ŞU AN - Hadime', 'hadime', (12, 6, 36, 30), None, None),
    'A': ('A - Büyücü / Gece', 'buyucu', (12, 2, 36, 26), gece, (128, 136, 190, 255)),
    'B': ('B - Vampir / Dolunay', 'vampir', (12, 6, 36, 30), dolunay, (150, 124, 176, 255)),
    'C': ('C - Melek / Gök', 'melek', (12, 1, 36, 25), gok, None),
    'D': ('D - Shaman / Gün Batımı', 'shaman', (12, 3, 36, 27), gun_batimi, None),
}


def main():
    os.makedirs(v1.OUT, exist_ok=True)
    arts = {}
    for k, (_, portrait, bust, paint, light) in PROTOS.items():
        gai.PORTRAIT = os.path.join(ROOT, 'assets', 'characters', portrait + '_portrait.png')
        gai.BUST = bust
        if paint is None:
            arts[k] = gai.art('cayir')
        else:
            gai.VARIANTS['v2_' + k] = (paint, light)
            arts[k] = gai.art('v2_' + k)
        gai.at_size(arts[k], 256).save(os.path.join(v1.OUT, f'ikon_v2_{k}.png'))
    v1.PROTOS = {k: v[:3] for k, v in PROTOS.items()}  # özet başlıkları
    out = os.path.join(v1.OUT, 'ozet_v2.png')
    v1.summary(arts).save(out)
    print(out)


if __name__ == '__main__':
    main()
