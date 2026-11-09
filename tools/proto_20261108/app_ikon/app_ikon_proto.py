"""UYGULAMA İKONU prototipleri: şu anki ikonla (Hadime büstü, çayır zemin) AYNI kalıp, farklı karakterler.

Çalıştır:  python tools/proto_20261108/app_ikon/app_ikon_proto.py      -> out/ (oyuna bağlı DEĞİL)

Kullanıcı isteği (2026-11-08): "oyunumun ikonu için yeni 4 prototip üretir misin şuanki haline benzer farklı
karakterlerden". Zemin, çerçeve, köşe çalıları, çiçekler, ölçek kuralları tools/gen_app_icon.py'den aynen alınır;
yalnız portre (karakterin kendi 48x48 sprite'ı, yeniden ÇİZİLMEZ) ve büst kırpımı değişir. Şapka/boynuz/hale gibi
baştan taşan parçalar kırpılmasın diye kırpım yukarı kayar (yükseklik 24 aynı -> sanat kanvası 26, 256 px'te 9x).

Seçilen bir prototip oyuna şöyle alınır: gen_app_icon.py'de PORTRAIT/BUST bu tablodaki değerlere çevrilip çalıştırılır.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import gen_app_icon as gai  # noqa: E402

OUT = os.path.join(HERE, 'out')

# ad: (başlık, portre dosyası, büst kırpımı (x0, y0, x1, y1) - 24x24)
PROTOS = {
    'simdi': ('ŞU AN - Hadime', 'hadime', (12, 6, 36, 30)),
    'A': ('A - Büyücü Kız', 'buyucu', (12, 2, 36, 26)),
    # Korsan da denendi (13, 5, 37, 29): koyu ten + koyu şapka 32 px'te çamurlaşıyordu -> Vampir.
    'B': ('B - Vampir', 'vampir', (12, 6, 36, 30)),
    'C': ('C - Melek', 'melek', (12, 1, 36, 25)),
    'D': ('D - Shaman', 'shaman', (12, 3, 36, 27)),
}


def icon_art(portrait, bust):
    gai.PORTRAIT = os.path.join(ROOT, 'assets', 'characters', portrait + '_portrait.png')
    gai.BUST = bust
    return gai.art('cayir')


def _font(px):
    for p in ('assets/fonts/m5x7.ttf', 'assets/fonts/m5x7.otf'):
        fp = os.path.join(ROOT, p)
        if os.path.exists(fp):
            return ImageFont.truetype(fp, px)
    return ImageFont.load_default()


def summary(arts):
    """Üst sıra 256 px; altta görev çubuğu boyları (48/32/24/16) koyu + açık şeritte."""
    keys = list(PROTOS)
    cell, gap, pad = 256, 28, 28
    small = [48, 32, 24, 16]
    strip_h = 64
    W = pad * 2 + len(keys) * cell + (len(keys) - 1) * gap
    H = pad + 40 + cell + 20 + strip_h * 2 + pad
    sheet = Image.new('RGBA', (W, H), (52, 38, 28, 255))
    d = ImageDraw.Draw(sheet)
    f = _font(32)
    for i, k in enumerate(keys):
        x = pad + i * (cell + gap)
        d.text((x, pad), PROTOS[k][0], font=f, fill=(240, 222, 186, 255))
        sheet.alpha_composite(gai.at_size(arts[k], 256), (x, pad + 40))
        for row, bg in enumerate(((32, 32, 32, 255), (238, 238, 238, 255))):
            y = pad + 40 + cell + 20 + row * strip_h
            d.rectangle((x, y, x + cell - 1, y + strip_h - 1), fill=bg)
            sx = x + 8
            for s in small:
                sheet.alpha_composite(gai.at_size(arts[k], s), (sx, y + (strip_h - s) // 2))
                sx += s + 12
    return sheet


def main():
    os.makedirs(OUT, exist_ok=True)
    arts = {}
    for k, (_, portrait, bust) in PROTOS.items():
        arts[k] = icon_art(portrait, bust)
        gai.at_size(arts[k], 256).save(os.path.join(OUT, f'ikon_{k}.png'))
    summary(arts).save(os.path.join(OUT, 'ozet.png'))
    print(os.path.join(OUT, 'ozet.png'))


if __name__ == '__main__':
    main()
