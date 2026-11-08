"""biyom_run.ps1 çekimlerinden karşılaştırma sayfası: satır = öbek, sütun = şu an / A / B (out/biyom_karsilastirma_<bolge>.png)."""
import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'out')
F = ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf', 18)
TITLES = {'simdi': 'ŞU AN (L1 + bölge boyası)', 'ka': 'K-A Kara Diken', 'kb': 'K-B Ruh Otu', 'ga': 'G-A Kamışlık', 'gb': 'G-B Eğrelti Yatağı'}
SHEETS = {'kuzey': (['k1', 'k2'], ['simdi', 'ka', 'kb']), 'guney': (['g1', 'g2'], ['simdi', 'ga', 'gb'])}
H = 330

for name, (rows, cols) in SHEETS.items():
    grid = []
    for r in rows:
        line = []
        for c in cols:
            im = Image.open(os.path.join(OUT, 'oyun_%s_%s.png' % (r, c))).convert('RGB')
            im = im.resize((round(im.width * H / im.height), H), Image.LANCZOS)
            d = ImageDraw.Draw(im)
            d.text((8, 6), TITLES[c], font=F, fill=(255, 245, 215), stroke_width=3, stroke_fill=(15, 12, 10))
            line.append(im)
        grid.append(line)
    W = max(sum(i.width for i in line) + 6 * (len(line) - 1) for line in grid)
    out = Image.new('RGB', (W, len(grid) * (H + 6) - 6), (18, 18, 18))
    y = 0
    for line in grid:
        x = 0
        for im in line:
            out.paste(im, (x, y))
            x += im.width + 6
        y += H + 6
    out.save(os.path.join(OUT, 'biyom_karsilastirma_%s.png' % name))
    print(name, out.size)
