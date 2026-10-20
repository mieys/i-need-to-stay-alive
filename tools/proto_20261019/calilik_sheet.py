"""Gerçek çizici yakalamalarını (calilik_run.ps1 -> out/calilik/oyun_<tag>_p0.png) başlıklı tek karşılaştırma sayfasında birleştirir + yakın plan (içerideki karakterler, x2).
Kullanım: python -I tools/proto_20261019/calilik_sheet.py"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gen_calilik_proto as P  # noqa: E402
import gen_lol_calilik as LOL  # noqa: E402
P.STYLES.update(LOL.STYLES)

OUT = P.OUT
TAGS = ['simdi', 'a', 'b', 'c', 'd']
NAME = ''
if '--tags' in sys.argv:
    TAGS = sys.argv[sys.argv.index('--tags') + 1].split(',')
if '--ad' in sys.argv:
    NAME = '_' + sys.argv[sys.argv.index('--ad') + 1]


def font(n):
    try:
        return ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf', n)
    except OSError:
        return ImageFont.load_default()


def title(tag):
    return 'ŞU AN (oyundaki)' if tag == 'simdi' else P.STYLES[tag]['name']


def sheet(imgs, name, cols=3):
    pw, ph = imgs[0][1].size
    rows = (len(imgs) + cols - 1) // cols
    s = Image.new('RGB', (pw * cols + 12 * (cols + 1), (ph + 64) * rows + 12), (24, 24, 28))
    d = ImageDraw.Draw(s)
    f, f2 = font(26), font(17)
    for i, (tag, im) in enumerate(imgs):
        x, y = 12 + (i % cols) * (pw + 12), 12 + (i // cols) * (ph + 64)
        s.paste(im.convert('RGB'), (x, y + 58))
        d.text((x, y + 2), title(tag), fill=(240, 236, 220), font=f)
        if tag != 'simdi':
            d.text((x, y + 34), P.STYLES[tag]['desc'], fill=(170, 166, 150), font=f2)
    s.save(os.path.join(OUT, name))


if __name__ == '__main__' and 'gif' not in sys.argv:
    imgs = [(t, Image.open(os.path.join(OUT, 'oyun_%s_p0.png' % t))) for t in TAGS if os.path.exists(os.path.join(OUT, 'oyun_%s_p0.png' % t))]
    w = min(im.width for _, im in imgs)
    h = min(im.height for _, im in imgs)
    imgs = [(t, im.crop((0, 0, w, h))) for t, im in imgs]
    sheet(imgs, 'karsilastirma%s.png' % NAME)
    ## yakın plan: karakterlerin olduğu orta-sağ bölge, x2
    box = (int(w * 0.36), int(h * 0.30), int(w * 0.92), int(h * 0.66))
    close = [(t, im.crop(box).resize(((box[2] - box[0]) * 2, (box[3] - box[1]) * 2), Image.NEAREST)) for t, im in imgs]
    sheet(close, 'yakin%s.png' % NAME)
    print('tamam', w, h)


def walk_gif(fps=15, cols=3):
    """walk_<tag>/ karelerini (calilik_run.ps1 -Walk) zaman damgasına göre sabit fps'e örnekleyip başlıklı ızgara GIF yapar: out/calilik/hisirti.gif"""
    sets = []
    for t in TAGS:
        d = os.path.join(OUT, 'walk_' + t)
        if not os.path.exists(os.path.join(d, 'times.txt')):
            continue
        ts = [float(x) for x in open(os.path.join(d, 'times.txt')).read().split()]
        sets.append((t, d, ts))
    first = Image.open(os.path.join(sets[0][1], 'f_000.png'))
    pw, ph = first.size
    rows = (len(sets) + cols - 1) // cols
    W, H = pw * cols + 8 * (cols + 1), (ph + 34) * rows + 8
    f = font(20)
    frames = []
    n = int(min(ts[-1] for _, _, ts in sets) * fps)
    for k in range(n):
        s = k / fps
        canvas = Image.new('RGB', (W, H), (24, 24, 28))
        d = ImageDraw.Draw(canvas)
        for i, (tag, folder, ts) in enumerate(sets):
            j = min(range(len(ts)), key=lambda q: abs(ts[q] - s))
            x, y = 8 + (i % cols) * (pw + 8), 8 + (i // cols) * (ph + 34)
            canvas.paste(Image.open(os.path.join(folder, 'f_%03d.png' % j)).convert('RGB'), (x, y + 30))
            d.text((x, y + 2), title(tag), fill=(240, 236, 220), font=f)
        frames.append(canvas.quantize(colors=255, method=Image.Quantize.MEDIANCUT))
    path = os.path.join(OUT, 'hisirti%s.gif' % NAME)
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=int(1000 / fps), loop=0, optimize=True)
    return path


if __name__ == '__main__' and 'gif' in sys.argv:
    print(walk_gif())
