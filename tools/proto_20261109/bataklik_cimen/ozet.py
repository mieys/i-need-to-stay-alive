# Kara Bataklık çimen prototipleri karşılaştırma sayfaları: out/ozet_<nokta>.png (ŞU AN + A-D, oyun görüntüsü) ve out/ozet_yakin.png (piksel ayrıntısı).
# Kullanım: python -I tools/proto_20261109/bataklik_cimen/ozet.py
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'out')
VAR = [('su_an', 'ŞU AN'), ('A', 'A - Islak Çayır'), ('B', 'B - Ot Tutamları'), ('C', 'C - Yosun ve Yaprak'), ('D', 'D - Sade')]
POINTS = ['kamp', 'cayir', 'bati']


def font(sz):
    for f in ['C:/Windows/Fonts/segoeuib.ttf', 'C:/Windows/Fonts/arialbd.ttf']:
        if os.path.exists(f):
            return ImageFont.truetype(f, sz)
    return ImageFont.load_default()


def sheet(names, out, scale):
    ims = [Image.open(os.path.join(OUT, n)).convert('RGB') for n, _ in names]
    w, h = int(ims[0].width * scale), int(ims[0].height * scale)
    cols = 3
    rows = (len(ims) + cols - 1) // cols
    pad, lab = 8, 34
    can = Image.new('RGB', (cols * (w + pad) + pad, rows * (h + lab + pad) + pad), (24, 22, 20))
    d = ImageDraw.Draw(can)
    f = font(22)
    for i, (im, (_, title)) in enumerate(zip(ims, names)):
        x = pad + (i % cols) * (w + pad)
        y = pad + (i // cols) * (h + lab + pad)
        d.text((x + 4, y + 4), title, fill=(236, 214, 160), font=f)
        can.paste(im.resize((w, h), Image.NEAREST), (x, y + lab))
    can.save(out)
    print(out, can.size)


def main():
    for p in POINTS:
        sheet([('%s_%s.png' % (p, v), t) for v, t in VAR], os.path.join(OUT, 'ozet_%s.png' % p), 0.7)
    sheet([('kamp_%s_yakin.png' % v, t) for v, t in VAR], os.path.join(OUT, 'ozet_yakin.png'), 0.6)


if __name__ == '__main__':
    main()
