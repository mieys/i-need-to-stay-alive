# İki donmuş kare klasörünü piksel piksel karşılaştırır (madde 371). Kullanım: python tools/fps_micro/donmus_karsilastir.py <klasör A> <klasör B>
import os
import sys

import numpy as np
from PIL import Image

a, b = sys.argv[1], sys.argv[2]
bad = 0
for f in sorted(os.listdir(a)):
    if not f.endswith('.png') or not os.path.exists(os.path.join(b, f)):
        continue
    x = np.asarray(Image.open(os.path.join(a, f)).convert('RGBA')).astype(int)
    y = np.asarray(Image.open(os.path.join(b, f)).convert('RGBA')).astype(int)
    if x.shape != y.shape:
        print(f, 'BOYUT FARKLI', x.shape, y.shape)
        bad += 1
        continue
    d = np.abs(x - y)
    n = int((d.max(axis=2) > 0).sum())
    print('%-18s farklı piksel %7d / %d  (en büyük kanal farkı %d)' % (f, n, x.shape[0] * x.shape[1], d.max()))
    if n:
        bad += 1
print('SONUC', 'BIREBIR AYNI' if bad == 0 else 'FARKLI (%d dosya)' % bad)
