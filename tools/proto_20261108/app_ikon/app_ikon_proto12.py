"""UYGULAMA İKONU v12: Büyücü Kız, C2 zemini, ARA YAKINLIK (madde 488, oyuna bağlı DEĞİL).

Çalıştır:  python tools/proto_20261108/app_ikon/app_ikon_proto12.py     -> out/ozet_v12.png + out/ikon_v12_buyucu.png

Kullanıcı (2026-11-10, v11 şapka ucu düzeltmesine): "ama kafası aşağı inince yüzü odaklı görünmüyor biraz uzaklaştırman gerek
sanırım". 8 (v10) ile 10 (v11) arasındaki tek tam sayı ölçek 9: kanvas 28 x 9 = 252, büst 24x24 (12,3,36,27) = v7 C'nin kırpımı ->
şapka ucu yine çerçevede (tek piksellik uç kesik), gözler kırpımın %58'inde (v11 düzeltmesinde %67). Zemin C2'nin birebir aynısı
(ekran uzayında sabit, v11.build).
"""
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
sys.path.insert(0, HERE)
import gen_app_icon as gai  # noqa: E402
import app_ikon_proto as v1  # noqa: E402
import app_ikon_proto11 as v11  # noqa: E402


def build_9():
    v11.N, v11.S = 28, 9
    v11.CROP = v11.N - 4
    v11.TOP_OVERRIDE['buyucu'] = 3
    art, bust, notes = v11.build('buyucu')
    print('kırpım', bust, '; '.join(notes))
    return art


def main():
    art = build_9()
    art.save(os.path.join(v1.OUT, 'ikon_v12_buyucu.png'))
    cols = [('8 px - v10', Image.open(os.path.join(v1.OUT, 'ikon_v10_buyucu.png'))),
            ('9 px - YENİ', art),
            ('10 px - v11', Image.open(os.path.join(v1.OUT, 'ikon_v11_buyucu.png')))]
    pad, cell = 28, 256
    sheet = Image.new('RGBA', (pad + len(cols) * (cell + pad), pad + 40 + cell + 20 + 64 + pad), (52, 38, 28, 255))
    d = ImageDraw.Draw(sheet)
    f = v1._font(32)
    for i, (title, im) in enumerate(cols):
        x = pad + i * (cell + pad)
        d.text((x, pad), title, font=f, fill=(240, 222, 186, 255))
        sheet.alpha_composite(im, (x, pad + 40))
        y = pad + 40 + cell + 20
        d.rectangle((x, y, x + cell - 1, y + 63), fill=(32, 32, 32, 255))
        sx = x + 8
        for z in (48, 32, 24, 16):
            sheet.alpha_composite(im.resize((z, z), Image.LANCZOS), (sx, y + (64 - z) // 2))
            sx += z + 12
    out = os.path.join(v1.OUT, 'ozet_v12.png')
    sheet.save(out)
    print(out)


if __name__ == '__main__':
    main()
