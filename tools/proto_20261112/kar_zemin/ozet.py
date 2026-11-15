# Ayaz Dağı kar zemini prototipleri karşılaştırma sayfaları + parlaklık ölçümü.
# out/ozet.png (satır = varyant, sütun = yakın + 4 nokta oyun ölçeğinde), out/ozet_<nokta>.png, out/ozet_yakin_<nokta>.png.
# Ölçüm: görüş alanı içindeki merkez bölgede (sis dışı) ortalama parlaklık + çok açık piksel payı (Rec.601 luma >= 190).
# Kullanım: python -I tools/proto_20261112/kar_zemin/ozet.py
import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'out')
VAR = [('su_an', 'ŞU AN'), ('A', 'A - Bulutlu Gün'), ('B', 'B - Rüzgâr Sırtları'), ('C', 'C - İnce Kar'), ('D', 'D - Kar Yastıkları')]
POINTS = ['kamp', 'ova', 'patika', 'gol', 'koru']
COLS = [('ova_%s_yakin.png', 'Açık kar (yakın)'), ('ova_%s.png', 'Açık ova'), ('kamp_%s.png', 'Doğuş kampı'), ('gol_%s.png', 'Göl kıyısı'),
        ('koru_%s.png', 'Koru')]
CROP = (240, 120, 720, 420)  # merkez bölge (görüş elipsinin içi, panel yok)


def font(sz):
    for f in ['C:/Windows/Fonts/segoeuib.ttf', 'C:/Windows/Fonts/arialbd.ttf']:
        if os.path.exists(f):
            return ImageFont.truetype(f, sz)
    return ImageFont.load_default()


def olc(path):
    h = Image.open(path).convert('L').crop(CROP).histogram()
    n = sum(h)
    return sum(i * c for i, c in enumerate(h)) / n, 100.0 * sum(h[190:]) / n


def genel(out, scale=0.36):
    w, h = int(960 * scale), int(540 * scale)
    pad, lab, side = 8, 30, 230
    can = Image.new('RGB', (side + len(COLS) * (w + pad) + pad, lab + len(VAR) * (h + pad) + pad), (24, 22, 20))
    d = ImageDraw.Draw(can)
    f, fs = font(22), font(17)
    for j, (_, t) in enumerate(COLS):
        d.text((side + pad + j * (w + pad) + 4, 4), t, fill=(200, 190, 160), font=fs)
    for i, (v, title) in enumerate(VAR):
        y = lab + pad + i * (h + pad)
        d.text((10, y + h // 2 - 26), title, fill=(236, 214, 160), font=f)
        ort = [olc(os.path.join(OUT, '%s_%s.png' % (p, v))) for p in POINTS if os.path.exists(os.path.join(OUT, '%s_%s.png' % (p, v)))]
        if ort:
            m = sum(a for a, _ in ort) / len(ort)
            b = sum(b for _, b in ort) / len(ort)
            d.text((10, y + h // 2 + 4), 'parlaklık %.0f  çok açık %%%.0f' % (m, b), fill=(170, 160, 140), font=fs)
        for j, (pat, _) in enumerate(COLS):
            pth = os.path.join(OUT, pat % v)
            if os.path.exists(pth):
                can.paste(Image.open(pth).convert('RGB').resize((w, h), Image.NEAREST), (side + pad + j * (w + pad), y))
    can.save(out)
    print(out, can.size)


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


## BÜYÜK örnekler (kullanıcı: "çok ufak görünüyor"): her varyant + nokta tek görüntü, merkez 960x540 kırpımı 2x (en yakın komşu) = 1920x1080,
## sol üstte varyant adı. out/buyuk/<nokta>_<n>_<varyant>.png (sıra numarası dosya listesinde ŞU AN, A, B, C, D sırasını korur).
def buyuk(points=('kamp', 'ova', 'gol')):
    d_out = os.path.join(OUT, 'buyuk')
    os.makedirs(d_out, exist_ok=True)
    f = font(40)
    for p in points:
        for i, (v, title) in enumerate(VAR):
            pth = os.path.join(OUT, '%s_%s.png' % (p, v))
            if not os.path.exists(pth):
                continue
            im = Image.open(pth).convert('RGB').resize((1920, 1080), Image.NEAREST)
            d = ImageDraw.Draw(im)
            tw = d.textlength(title, font=f)
            d.rectangle((0, 0, tw + 36, 66), fill=(24, 22, 20))
            d.text((18, 10), title, fill=(236, 214, 160), font=f)
            im.save(os.path.join(d_out, '%s_%d_%s.png' % (p, i, v)))


def main():
    print('varyant   ' + '  '.join('%-14s' % p for p in POINTS) + '  (ortalama parlaklık 0-255 / çok açık %)')
    for v, _ in VAR:
        row = []
        for p in POINTS:
            pth = os.path.join(OUT, '%s_%s.png' % (p, v))
            row.append('%5.0f / %4.1f%%  ' % olc(pth) if os.path.exists(pth) else '-'.ljust(16))
        print('%-8s  ' % v + ''.join(row))
    genel(os.path.join(OUT, 'ozet.png'))
    for p in POINTS:
        sheet([('%s_%s.png' % (p, v), t) for v, t in VAR], os.path.join(OUT, 'ozet_%s.png' % p), 0.7)
        sheet([('%s_%s_yakin.png' % (p, v), t) for v, t in VAR], os.path.join(OUT, 'ozet_yakin_%s.png' % p), 0.6)
    buyuk()


if __name__ == '__main__':
    main()
