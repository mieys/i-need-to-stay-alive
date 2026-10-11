"""Ağaç görevi sanatı (2026-10-10, kullanıcının masaüstü "görev agaç" klasörü) -> assets/fx/mission_tree/.
- tree_active.png: 6 kare x 160x160, görev sürerken döngü (olduğu gibi kopyalanır).
- tree_grow.png (kaynak 282x114): 3 ağaç, sayfada TERS sıralı (en büyük solda) ve 94 px ızgaraya oturmuyor (büyük ağaç 110. sütuna taşıyor) ->
  boş sütunlardan ayrılır, KÜÇÜKTEN BÜYÜĞE sıralanır, her biri 160x160 kareye gövde dibi aktif ağacın gövde dibiyle AYNI noktaya gelecek şekilde konur
  -> tree_grow_aligned.png (3 kare x 160). Gövde dibi = en alttaki 6 opak satırın ortalama x'i, en alt opak satır.
Kullanım (proje kökünden): python -I tools/import_mission_tree.py "<görev agaç klasörü>"
"""
import os
import shutil
import sys

from PIL import Image

PROJECT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
OUT = os.path.join(PROJECT, 'assets', 'fx', 'mission_tree')
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.expanduser('~'), 'Desktop', 'görev agaç')
FRAME = 160


def base_point(im):
    """(x, y): gövde dibi - en alttaki 6 opak satırdaki piksellerin ortalama x'i, en alt opak satır"""
    w, h = im.size
    px = im.load()
    bottom = max(y for y in range(h) for x in range(w) if px[x, y][3] > 0)
    xs = [x for y in range(bottom - 5, bottom + 1) for x in range(w) if px[x, y][3] > 0]
    return sum(xs) / len(xs), bottom


def main():
    os.makedirs(OUT, exist_ok=True)
    shutil.copyfile(os.path.join(SRC, 'ağaç görev aktifken.png'), os.path.join(OUT, 'tree_active.png'))
    active = Image.open(os.path.join(OUT, 'tree_active.png')).convert('RGBA')
    ax, ay = base_point(active.crop((0, 0, FRAME, FRAME)))
    grow = Image.open(os.path.join(SRC, 'ağaç görev başlamadan önce büyüme.png')).convert('RGBA')
    w, h = grow.size
    px = grow.load()
    used = [any(px[x, y][3] > 0 for y in range(h)) for x in range(w)]
    segs = []
    x = 0
    while x < w:
        if used[x]:
            s = x
            while x < w and used[x]:
                x += 1
            segs.append((s, x))
        x += 1
    trees = [grow.crop((s, 0, e, h)) for s, e in segs]
    trees.sort(key=lambda t: t.getbbox()[3] - t.getbbox()[1])  ## küçükten büyüğe (sayfa ters sıralı)
    sheet = Image.new('RGBA', (FRAME * len(trees), FRAME), (0, 0, 0, 0))
    for i, t in enumerate(trees):
        bx, by = base_point(t)
        sheet.alpha_composite(t, (int(round(i * FRAME + ax - bx)), int(round(ay - by))))
    sheet.save(os.path.join(OUT, 'tree_grow_aligned.png'))
    shutil.copyfile(os.path.join(SRC, 'ağaç görev başlamadan önce büyüme.png'), os.path.join(OUT, 'tree_grow_source.png'))
    print('gövde dibi (aktif kare içinde):', round(ax, 1), ay, '| büyüme ağaçları:', len(trees))


if __name__ == '__main__':
    main()
