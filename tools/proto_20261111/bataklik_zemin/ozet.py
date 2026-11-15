# Kara Bataklık zemin prototipleri (yol + çimen) karşılaştırma sayfaları: out/ozet_<nokta>.png (ŞU AN + A-D, oyun görüntüsü) ve
# out/ozet_yakin_<nokta>.png (piksel ayrıntısı). Kullanım: python -I tools/proto_20261111/bataklik_zemin/ozet.py [olcek]
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'out')
VAR = [('su_an', 'ŞU AN'), ('A', 'A - Islak Kıyı'), ('B', 'B - Taş ve Kök'), ('C', 'C - Sakin Doku'), ('D', 'D - Akış Kıvrımları')]
POINTS = ['kamp', 'yol_su', 'cayir', 'koru']


def font(sz):
    for f in ['C:/Windows/Fonts/segoeuib.ttf', 'C:/Windows/Fonts/arialbd.ttf']:
        if os.path.exists(f):
            return ImageFont.truetype(f, sz)
    return ImageFont.load_default()


def sheet(names, out, scale, cols=3):
    names = [(n, t) for n, t in names if os.path.exists(os.path.join(OUT, n))]
    ims = [Image.open(os.path.join(OUT, n)).convert('RGB') for n, _ in names]
    w, h = int(ims[0].width * scale), int(ims[0].height * scale)
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


## Tek sayfa: satır = varyant, sütun = yol yakın / çimen yakın / kıyıya inen patika / koru zemini (oyun ölçeği)
COLS = [('kamp_%s_yakin.png', 'YOL (yakın)'), ('cayir_%s_yakin.png', 'ÇİMEN (yakın)'), ('yol_su_%s.png', 'Kıyıya inen patika'),
        ('koru_%s.png', 'Koru altı çamur')]


def genel(out, scale=0.4):
    w, h = int(960 * scale), int(540 * scale)
    pad, lab, side = 8, 30, 210
    can = Image.new('RGB', (side + len(COLS) * (w + pad) + pad, lab + len(VAR) * (h + pad) + pad), (24, 22, 20))
    d = ImageDraw.Draw(can)
    f, fs = font(22), font(18)
    for j, (_, t) in enumerate(COLS):
        d.text((side + pad + j * (w + pad) + 4, 4), t, fill=(200, 190, 160), font=fs)
    for i, (v, title) in enumerate(VAR):
        y = lab + pad + i * (h + pad)
        d.text((10, y + h // 2 - 12), title, fill=(236, 214, 160), font=f)
        for j, (pat, _) in enumerate(COLS):
            pth = os.path.join(OUT, pat % v)
            if os.path.exists(pth):
                can.paste(Image.open(pth).convert('RGB').resize((w, h), Image.NEAREST), (side + pad + j * (w + pad), y))
    can.save(out)
    print(out, can.size)


def main():
    scale = float(sys.argv[1]) if len(sys.argv) > 1 else 0.7
    genel(os.path.join(OUT, 'ozet.png'))
    for p in POINTS:
        sheet([('%s_%s.png' % (p, v), t) for v, t in VAR], os.path.join(OUT, 'ozet_%s.png' % p), scale)
        sheet([('%s_%s_yakin.png' % (p, v), t) for v, t in VAR], os.path.join(OUT, 'ozet_yakin_%s.png' % p), 0.6)


if __name__ == '__main__':
    main()
