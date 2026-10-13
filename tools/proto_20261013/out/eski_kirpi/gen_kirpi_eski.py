"""Evcil hayvan KİRPİ (2026-10-13, kullanıcı masaüstüne iki sayfa koydu: "kirpi diken açık.png" / "kirpi diken kapalı.png").
Her sayfa 128x128 = 4 sütun (yön) x 4 satır (kare), hücre 32x32. Sütunlar: 0 = sağa bakar (yan), 1 = ön (down), 2 = arka (up), 3 = sola bakar.
4 kare 2 farklı kareyi tekrar eder (0=2, 1=3: nefes alma). Tek sayfaya yan yana birleştirilir (açık solda x 0..127, kapalı sağda x 128..255).
Çıktı: assets/pets/kirpi/kirpi_sheet.png + kirpi_frames.tres. Animasyonlar: acik_<down|up|left|right>, kapali_<...> (4 kare döngü).
Kullanım: python tools/gen_kirpi.py [acik.png] [kapali.png]  (varsayılan: masaüstündeki iki dosya)
"""
import os
import sys

from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), '..'))
OUT = os.path.join(ROOT, 'assets', 'pets', 'kirpi')
CELL = 32
DIRS = ['right', 'down', 'up', 'left']  # sütun sırası
FPS = 3.0


def main():
    desk = os.path.join(os.path.expanduser('~'), 'Desktop')
    open_png = sys.argv[1] if len(sys.argv) > 1 else os.path.join(desk, 'kirpi diken acık.png')
    closed_png = sys.argv[2] if len(sys.argv) > 2 else os.path.join(desk, 'kirpi diken kapalı.png')
    a = Image.open(open_png).convert('RGBA')
    b = Image.open(closed_png).convert('RGBA')
    assert a.size == (128, 128) and b.size == (128, 128), (a.size, b.size)
    sheet = Image.new('RGBA', (256, 128), (0, 0, 0, 0))
    sheet.alpha_composite(a, (0, 0))
    sheet.alpha_composite(b, (128, 0))
    os.makedirs(OUT, exist_ok=True)
    sheet.save(os.path.join(OUT, 'kirpi_sheet.png'))

    lines = ['[gd_resource type="SpriteFrames" format=3]', '',
             '[ext_resource type="Texture2D" path="res://assets/pets/kirpi/kirpi_sheet.png" id="1"]', '']
    anims = []
    at = 0
    for prefix, x0 in (('acik', 0), ('kapali', 128)):
        for col, d in enumerate(DIRS):
            ids = []
            for row in range(4):
                lines += ['[sub_resource type="AtlasTexture" id="AT_%d"]' % at, 'atlas = ExtResource("1")',
                          'region = Rect2(%d, %d, %d, %d)' % (x0 + col * CELL, row * CELL, CELL, CELL), '']
                ids.append(at)
                at += 1
            anims.append((prefix + '_' + d, ids))
    lines.append('[resource]')
    blocks = []
    for name, ids in anims:
        fr = ',\n'.join('{\n"duration": 1.0,\n"texture": SubResource("AT_%d")\n}' % i for i in ids)
        blocks.append('{\n"frames": [%s],\n"loop": true,\n"name": &"%s",\n"speed": %s\n}' % (fr, name, FPS))
    lines.append('animations = [%s]' % ', '.join(blocks))
    lines.append('')
    with open(os.path.join(OUT, 'kirpi_frames.tres'), 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines))
    print('wrote', OUT, sheet.size)


if __name__ == '__main__':
    main()
