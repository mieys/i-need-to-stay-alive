"""UYGULAMA İKONU v4: v3 D "Büyücü / Alacakaranlık" YÜZ ODAKLI (madde 488, oyuna bağlı DEĞİL).

Çalıştır:  python tools/proto_20261108/app_ikon/app_ikon_proto4.py      -> out/ozet_v4.png + out/ikon_v4_*.png

Kullanıcı (2026-11-08): "D iyi gibi ama yüz odaklı olsun şapka odaklı bunda". v3 D'de 24x24 büst kırpımının üst yarısı şapkaydı.
Yüz büyüsün diye kırpım küçülür ve kanvas da onunla küçülür (tek piksel ızgarası korunur: karakter pikseli = zemin pikseli, 256'da
tam sayı kat). Kırpımlar oyundaki portre "yakın yüz" çerçevesinden (scripts/portrait_face.gd + menu_lobby_ui.face_texture, madde 464):
  (D0 denendi: kanvas 26, kırpım (12,7,36,31) aşağı kaydırılmış - yüz ortaya gelir ama boyu aynı, gövde öne çıkar -> çıkarıldı)
  D1 Orta     - 20x20 (13,5,33,25), kanvas 22 -> 11x
  D2 Yakın    - 18x18 (15,7,33,25) = oyuncu paneli portresi (PANEL_N 18, FACE_OY[4][0] 6), kanvas 20 -> 12x
  D3 Çok yakın - 16x16 (16,9,32,25) = grup paneli avatarı (PARTY_N 16, FACE_OY[4][1] 8), kanvas 18 -> 14x
Yakınlaştıkça geniş mor saç yanları kapatır, alacakaranlık yalnız şapkanın çevresinde kalır (D2/D3'te üst köşeler).
Zemin v3 D'nin aynısı; bant / yıldız / meteor konumları kanvasa oranlanır, köşe çalı taçları aynı sprite.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
sys.path.insert(0, HERE)
import gen_app_icon as gai  # noqa: E402
import gen_menu_bg as mb  # noqa: E402
import app_ikon_proto as v1  # noqa: E402
import app_ikon_proto2 as v2  # noqa: E402
import app_ikon_proto3 as v3  # noqa: E402

LIGHT = (150, 124, 176, 255)


def alacakaranlik(img):
    """v3 D, kanvas boyuna (v2.N) oranlı."""
    n = v2.N
    s = n / 26.0

    def p(x, y):
        return (round(x * s), round(y * s))

    v2.bands(img, ['#252c5c', '#33386e', '#4e4280', '#7a4c82', '#a8587a', '#d0745e', '#e8a064'], [2] * 7)
    for (x, y) in [(2, 3), (21, 9)]:
        v2.star(img, *p(x, y), '#e8e4f6')
    v2.px(img, [p(1, 6), p(24, 2), p(8, 1)], '#b8b8dc')
    mx, my = p(18, 1)
    v2.px(img, [(mx + k, my + k) for k in range(max(3, round(5 * s)))], '#f0b070')
    hx, hy = mx + max(3, round(5 * s)), my + max(3, round(5 * s))
    v2.px(img, [(hx, hy), (hx + 1, hy), (hx, hy + 1)], '#fff0d0')
    v2._crowns(img, mb.shade(0.30, (50, 20, 40), 0.45))


# ad: (başlık, kanvas N, büst kırpımı)
PROTOS = {
    'D': ('v3 D - şimdiki', 26, (12, 2, 36, 26)),
    'D1': ('D1 - Orta', 22, (13, 5, 33, 25)),
    'D2': ('D2 - Yakın (panel)', 20, (15, 7, 33, 25)),
    'D3': ('D3 - Çok yakın', 18, (16, 9, 32, 25)),
}


def build(n, bust):
    gai.N = n
    v2.N = n
    gai.PORTRAIT = os.path.join(ROOT, 'assets', 'characters', 'buyucu_portrait.png')
    gai.BUST = bust
    gai.VARIANTS['v4'] = (alacakaranlik, LIGHT)
    return gai.art('v4')


def main():
    os.makedirs(v1.OUT, exist_ok=True)
    arts = {}
    for k, (_, n, bust) in PROTOS.items():
        arts[k] = build(n, bust)
        gai.at_size(arts[k], 256).save(os.path.join(v1.OUT, f'ikon_v4_{k}.png'))
    v1.PROTOS = {k: v for k, v in PROTOS.items()}
    out = os.path.join(v1.OUT, 'ozet_v4.png')
    v1.summary(arts).save(out)
    print(out)


if __name__ == '__main__':
    main()
