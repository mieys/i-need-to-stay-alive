"""DÜNYA HARİTASI prototipleri: out/dunya_A..D.png -> out/ozet.png (2x2, yarı boy, başlıklı)."""
import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'out')
NAMES = {'A': 'A - Açık Atlas', 'B': 'B - Atlas Defteri', 'C': 'C - Yakın Bakış', 'D': 'D - Sefer Yolu'}
font = ImageFont.truetype(os.path.join(HERE, '..', '..', '..', 'assets', 'fonts', 'm5x7.ttf'), 32)
sheet = Image.new('RGB', (1920 + 12, (540 + 40) * 2 + 4), (20, 14, 9))
d = ImageDraw.Draw(sheet)
for i, v in enumerate('ABCD'):
    x = (i % 2) * (960 + 12)
    y = (i // 2) * (540 + 44)
    d.text((x + 8, y + 2), NAMES[v], font=font, fill=(240, 192, 112))
    sheet.paste(Image.open(os.path.join(OUT, 'dunya_%s.png' % v)).resize((960, 540), Image.LANCZOS), (x, y + 40))
sheet.save(os.path.join(OUT, 'ozet.png'))
print('ozet.png', sheet.size)
