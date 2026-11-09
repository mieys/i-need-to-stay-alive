"""UYGULAMA İKONU prototipleri v3: Hadime'nin ÇAYIR teması + Büyücü Kız'ın GECE teması üzerine (madde 488, oyuna bağlı DEĞİL).

Çalıştır:  python tools/proto_20261108/app_ikon/app_ikon_proto3.py      -> out/ozet_v3.png + out/ikon_v3_*.png

Kullanıcı (2026-11-08, v2'den sonra): "hadime ve büyücü kızın temasına benzer prototipler istiyorum" = beğenilen iki yön bugünkü
ikon (Hadime + çayır açıklığı) ve v2 A (Büyücü + yıldızlı gece). v3 bu iki temada kalır, iki karakteri çaprazlar ve her temanın
yeni bir tonunu dener:
  A Hadime / Yıldızlı Gece  - v2 A'nın gecesi; siyah çarşaf lacivertte kaybolmasın diye başın arkasında ay ışıklı açıklık
                              (bugünkü ikonun açıklık fikri, düz iki ton), meteor yerine Hadime'nin kendi lanet zerreleri
  B Büyücü / Gece Çayırı    - bugünkü çayır düzeni (açıklık + köşe çalı taçları + iki çiçek) geceye boyanmış + ateş böcekleri
  C Hadime / Akşam Çayırı   - bugünkü çayır, başın arkasındaki açıklık altın ikindi ışığında
  D Büyücü / Alacakaranlık  - v2 A'nın gökyüzü: lacivertten ufuktaki sıcak bandına geniş geçiş (düz bantlar), meteor + yıldız
Kurallar aynı: oyunun kendi sprite'ları (portre, harita çalı/çiçekleri, Hadime FX), düz renkler, dither/hale/parıltı yok.
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

N = gai.N
CX, CY, CR = 12.5, 10.5, 10.2  # bugünkü ikonun açıklık dairesi


def _clearing(img, col):
    p = img.load()
    for y in range(N):
        for x in range(N):
            if (x - CX) ** 2 + (y - CY) ** 2 <= CR * CR:
                p[x, y] = col


def _motes(img, spots):
    """Hadime'nin lanet zerreleri (assets/fx/hadime/curse_mote_sheet.png, 8x8 kareler) - ilk iki kare (yeşil artı/nokta)."""
    sh = Image.open(os.path.join(ROOT, 'assets', 'fx', 'hadime', 'curse_mote_sheet.png')).convert('RGBA')
    frames = [sh.crop((i * 8, 0, i * 8 + 8, 8)) for i in range(sh.width // 8)]
    for (x, y, f) in spots:
        img.alpha_composite(frames[f], (x, y))


def _meadow(img, base, lit, crowns, flowers=True):
    """Bugünkü ikonun çayırı (gen_app_icon._grass) - renk fonksiyonları parametreli."""
    img.paste(base(*mb.GRASS) + (255,), (0, 0, N, N))
    _clearing(img, lit(*mb.GRASS) + (255,))
    tr = [t for t in mb.sprites(mb.TREES) if t.height <= 100]
    left, right = tr[14], tr[12].transpose(Image.FLIP_LEFT_RIGHT)
    img.alpha_composite(mb.recolor(left, crowns), (-left.width // 2 - 3, -left.height // 2 - 3))
    img.alpha_composite(mb.recolor(right, crowns), (N - right.width // 2 + 3, -right.height // 2 - 3))
    if flowers:
        fl = mb.sprites(mb.FLOWERS)
        img.alpha_composite(fl[14], (0, N - 10))
        img.alpha_composite(fl[37], (N - 8, N - 12))


def hadime_gece(img):
    v2.bands(img, ['#2c3a6c', '#34447a', '#3e4e86', '#4a4a7e', '#a8664a'], [3, 3, 3, 2, 1])
    _clearing(img, v2.C('#56669e'))          # ay ışığı alan açıklık: siyah çarşafın arkası açık
    for (x, y) in [(2, 3), (23, 13), (2, 15)]:
        v2.star(img, x, y, '#e8e4f6')
    v2.px(img, [(1, 8), (24, 2), (21, 1), (4, 1)], '#b8b8dc')
    _motes(img, [(18, 3, 0), (-1, 8, 0)])  # iki zerre (üç tanesi konfeti gibi dağınık duruyordu)
    v2._crowns(img, mb.shade(0.46, (20, 26, 60), 0.45))


def buyucu_gece_cayir(img):
    _meadow(img,
            base=mb.shade(0.46, (24, 30, 70), 0.40),
            lit=mb.shade(0.70, (150, 170, 230), 0.22),
            crowns=mb.shade(0.40, (20, 24, 60), 0.45))
    # ateş böcekleri: tek / iki piksel, açık sarı-yeşil (parıltısız)
    v2.px(img, [(3, 12), (22, 9), (19, 1), (6, 2), (24, 16), (1, 20)], '#e6f08a')
    v2.px(img, [(4, 12), (22, 10)], '#b8c86a')


def hadime_aksam(img):
    _meadow(img,
            # çayır bugünkü yeşilinde (tümü turuncuya boyanınca zeytin/solgun oluyordu), yalnız açıklık altın ikindi ışığı
            base=mb.shade(0.80, (44, 32, 22), 0.16),
            lit=mb.shade(1.06, (255, 206, 110), 0.36),
            crowns=mb.shade(0.72, (80, 44, 22), 0.24))


def buyucu_alacakaranlik(img):
    # sıcak bantlar başın iki yanında görünsün diye geçiş yukarı çekildi (ilk denemede büst + çalılar örtüyordu)
    v2.bands(img, ['#252c5c', '#33386e', '#4e4280', '#7a4c82', '#a8587a', '#d0745e', '#e8a064'],
             [2, 2, 2, 2, 2, 2, 2])
    for (x, y) in [(2, 3), (21, 9)]:
        v2.star(img, x, y, '#e8e4f6')
    v2.px(img, [(1, 6), (24, 2), (8, 1)], '#b8b8dc')
    v2.px(img, [(18 + k, 1 + k) for k in range(5)], '#f0b070')
    v2.px(img, [(23, 6), (24, 6), (23, 7)], '#fff0d0')
    v2._crowns(img, mb.shade(0.30, (50, 20, 40), 0.45))


PROTOS = {
    'simdi': ('ŞU AN - Çayır', 'hadime', (12, 6, 36, 30), None, None),
    'v2A': ('v2 A - Gece', 'buyucu', (12, 2, 36, 26), v2.gece, (128, 136, 190, 255)),
    'A': ('A - Hadime / Gece', 'hadime', (12, 6, 36, 30), hadime_gece, (128, 136, 190, 255)),
    'B': ('B - Gece Çayırı', 'buyucu', (12, 2, 36, 26), buyucu_gece_cayir, (120, 136, 176, 255)),
    'C': ('C - Akşam Çayırı', 'hadime', (12, 6, 36, 30), hadime_aksam, None),
    'D': ('D - Alacakaranlık', 'buyucu', (12, 2, 36, 26), buyucu_alacakaranlik, (150, 124, 176, 255)),
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
            gai.VARIANTS['v3_' + k] = (paint, light)
            arts[k] = gai.art('v3_' + k)
        if k not in ('simdi', 'v2A'):
            gai.at_size(arts[k], 256).save(os.path.join(v1.OUT, f'ikon_v3_{k}.png'))
    v1.PROTOS = {k: v[:3] for k, v in PROTOS.items()}
    out = os.path.join(v1.OUT, 'ozet_v3.png')
    v1.summary(arts).save(out)
    print(out)


if __name__ == '__main__':
    main()
