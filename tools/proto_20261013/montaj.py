"""cadi_q_capture.gd çıktılarını tek görsele dizer: python -I tools/proto_20261013/montaj.py <klasör> <çıktı.png> [ad ...]"""
import os
import sys

from PIL import Image

d, out = sys.argv[1], sys.argv[2]
names = sys.argv[3:] or ['q_right', 'q_left', 'q_up', 'q_down', 'q_idle']
ims = [Image.open(os.path.join(d, n + '.png')).convert('RGB') for n in names]
h = max(im.height for im in ims)
m = Image.new('RGB', (sum(im.width for im in ims) + 4 * (len(ims) - 1), h), (30, 30, 30))
x = 0
for im in ims:
    m.paste(im, (x, 0))
    x += im.width + 4
m.save(out)
print(m.size)
