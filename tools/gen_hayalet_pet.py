"""Evcil hayvan HAYALET - kullanıcının çizimi (2026-11-09, Desktop.zip "hayalet_spritesheet.png" 256x224 = 8x7 kare, hücre 32x32; kaynak
tools/pet_kaynak/). Kullanıcının kareleri DEĞİŞMEZ; sayfa olduğu gibi kopyalanır ve bölgeleri .tres'e yazılır. Oyunda yarı opak çizilir
(hayalet_pet.gd GHOST_ALPHA - saydamlık dokuya pişirilmez, şekil keskin kalır).

Kaynak kare sırası (indeks = satır*8 + sütun):
    0-7   süzülme (önden)                  -> idle
    10-17 sağa eğilip süzülme (yana gidiş)  -> move_right (sol = ayna)
    18-19 gözyaşı                           -> cry (sahibi yerde/ölüyken)
    35-41 kıvrılıp küçülerek kaybolma + boş kare 53 -> vanish ; tersi appear (küçük bir noktadan açılıp belirme)
          (kullanıcı 2026-11-09: "bir tane daha yok olma animasyonu vardı onu kullan, bu parçalanma yerine" - 21-29 toz olup
          dağılma artık KULLANILMIYOR; 30-34 ikinci süzülme, 42-52 mavi gözlü yan gidiş de kullanılmadı)
Kaplama ("kendi bedeniyle senin üstünü kaplayarak"): süzülme + kaybolma kareleri Scale2x (EPX) ile 2 kat çözünürlükte yeniden örneklenir -
AYNI piksel boyunda (gerdirilmiş iri piksel yok, madde FX doku yoğunluğu kuralı) 2 kat büyük hayalet: assets/pets/hayalet/hayalet_buyuk.png
(64x64 hücre; 0-7 süzülme -> cover, 8-15 kıvrılıp küçülme -> cover_out, tersi cover_in = noktadan açılıp seni kaplar, 16-23 yana eğilme
-> cover_move_right: sahip yürürken örtü de doğal hâlindeki gibi gidiş yönüne eğilir, sola aynalanır - madde 513).
Ayrıca assets/ui/status/hayalet_ortu.png (24x24, buff rozeti: hayaletin üst gövdesi 1:1).
Kullanım (proje kökünden): python -I tools/gen_hayalet_pet.py   sonra   Godot --headless --path . --import
Önizleme (oyuna girmez): --onizleme <klasör>
"""
import os
import shutil
import sys

from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
SRC = os.path.join(ROOT, 'tools', 'pet_kaynak', 'hayalet_spritesheet.png')
OUT = os.path.join(ROOT, 'assets', 'pets', 'hayalet')
STATUS = os.path.join(ROOT, 'assets', 'ui', 'status')
CELL = 32
BIG = 64
COLS = 8
IDLE = list(range(0, 8))
MOVE = list(range(10, 18))
CRY = [18, 19]
VANISH = list(range(35, 42)) + [53] ## kıvrılıp küçülme + boş kare (8 kare)
CLEAR = (0, 0, 0, 0)


def cell(sheet, i):
    c, r = i % COLS, i // COLS
    return sheet.crop((c * CELL, r * CELL, c * CELL + CELL, r * CELL + CELL))


def scale2x(im):
    """EPX / Scale2x: her piksel 2x2 olur, çapraz kenarlar yumuşar (iri piksel blokları değil, aynı boyda daha ince silüet)."""
    w, h = im.size
    src = im.load()

    def g(x, y):
        if 0 <= x < w and 0 <= y < h:
            p = src[x, y]
            return CLEAR if p[3] == 0 else p
        return CLEAR

    out = Image.new('RGBA', (w * 2, h * 2), CLEAR)
    dst = out.load()
    for y in range(h):
        for x in range(w):
            p = g(x, y)
            a, b, c, d = g(x, y - 1), g(x + 1, y), g(x - 1, y), g(x, y + 1)
            e1 = a if (c == a and c != d and a != b) else p
            e2 = b if (a == b and a != c and b != d) else p
            e3 = c if (d == c and d != b and c != a) else p
            e4 = d if (b == d and b != a and d != c) else p
            dst[2 * x, 2 * y] = e1
            dst[2 * x + 1, 2 * y] = e2
            dst[2 * x, 2 * y + 1] = e3
            dst[2 * x + 1, 2 * y + 1] = e4
    return out


def build_big(sheet):
    frames = [scale2x(cell(sheet, i)) for i in IDLE + VANISH[:8] + MOVE]
    im = Image.new('RGBA', (BIG * 8, BIG * 3), CLEAR)
    for k, f in enumerate(frames):
        im.alpha_composite(f, ((k % 8) * BIG, (k // 8) * BIG))
    return im, frames


def write_tres():
    lines = ['[gd_resource type="SpriteFrames" format=3]', '',
             '[ext_resource type="Texture2D" path="res://assets/pets/hayalet/hayalet_sheet.png" id="1"]',
             '[ext_resource type="Texture2D" path="res://assets/pets/hayalet/hayalet_buyuk.png" id="2"]', '']
    used = sorted(set(IDLE + MOVE + CRY + VANISH))
    for i in used:
        lines += ['[sub_resource type="AtlasTexture" id="S_%d"]' % i, 'atlas = ExtResource("1")',
                  'region = Rect2(%d, %d, %d, %d)' % ((i % COLS) * CELL, (i // COLS) * CELL, CELL, CELL), '']
    for k in range(24):
        lines += ['[sub_resource type="AtlasTexture" id="B_%d"]' % k, 'atlas = ExtResource("2")',
                  'region = Rect2(%d, %d, %d, %d)' % ((k % 8) * BIG, (k // 8) * BIG, BIG, BIG), '']
    anims = [
        ('idle', ['S_%d' % i for i in IDLE], 8.0, True),
        ('move_right', ['S_%d' % i for i in MOVE], 10.0, True),
        ('cry', ['S_%d' % i for i in CRY], 3.0, True),
        ('vanish', ['S_%d' % i for i in VANISH], 14.0, False),
        ('appear', ['S_%d' % i for i in reversed(VANISH)], 14.0, False),
        ('cover', ['B_%d' % k for k in range(8)], 8.0, True),
        ('cover_in', ['B_%d' % k for k in reversed(range(8, 16))], 16.0, False),
        ('cover_out', ['B_%d' % k for k in range(8, 16)], 14.0, False),
        ('cover_move_right', ['B_%d' % k for k in range(16, 24)], 10.0, True),
    ]
    lines.append('[resource]')
    blocks = []
    for name, ids, fps, loop in anims:
        fr = ',\n'.join('{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % i for i in ids)
        blocks.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}' % (fr, 'true' if loop else 'false', name, fps))
    lines.append('animations = [%s]' % ', '.join(blocks))
    lines.append('')
    with open(os.path.join(OUT, 'hayalet_frames.tres'), 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines))


def status_icon(sheet):
    body = cell(sheet, 0)
    bb = body.getbbox()
    crop = body.crop((bb[0], bb[1], bb[2], min(bb[3], bb[1] + 22)))
    icon = Image.new('RGBA', (24, 24), CLEAR)
    icon.alpha_composite(crop, ((24 - crop.width) // 2, 1))
    return icon


def preview(folder, sheet, big_frames):
    os.makedirs(folder, exist_ok=True)
    bg = (90, 110, 90, 255)
    im = Image.new('RGBA', (BIG * 8, BIG * 4), bg)
    for k, f in enumerate(big_frames):
        layer = f.copy()
        layer.putalpha(layer.getchannel('A').point(lambda a: int(a * 0.6)))
        im.alpha_composite(layer, ((k % 8) * BIG, (k // 8) * BIG))
    for k, i in enumerate(IDLE):
        im.alpha_composite(cell(sheet, i), (k * BIG + 16, 3 * BIG + 16))
    im.resize((im.width * 3, im.height * 3), Image.NEAREST).convert('RGB').save(os.path.join(folder, 'hayalet_buyuk.png'))


def main():
    sheet = Image.open(SRC).convert('RGBA')
    os.makedirs(OUT, exist_ok=True)
    shutil.copyfile(SRC, os.path.join(OUT, 'hayalet_sheet.png'))
    big, big_frames = build_big(sheet)
    big.save(os.path.join(OUT, 'hayalet_buyuk.png'))
    write_tres()
    status_icon(sheet).save(os.path.join(STATUS, 'hayalet_ortu.png'))
    print('wrote', OUT, big.size)
    if '--onizleme' in sys.argv:
        preview(sys.argv[sys.argv.index('--onizleme') + 1], sheet, big_frames)


if __name__ == '__main__':
    main()
