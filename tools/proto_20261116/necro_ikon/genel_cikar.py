# "Genel iconlar" önizleme görsellerinden (craftpix 48x48 ikon paketleri, tamsayı olmayan ölçek + webp/jpg) tek ikonu
# 48x48 sanat pikseline geri örnekler (her hücrenin orta bölgesinin medyanı), x3 = 144 (HUD skill ikonu boyu).
import numpy as np
from PIL import Image
GEN = "C:/Users/perva/Desktop/Genel iconlar/"

def grid(path, thr=40, frac=0.3):
    a = np.asarray(Image.open(GEN + path).convert("RGB")).astype(int)
    m = np.abs(a - a[2, 2]).sum(2) > thr
    def spans(v):
        s, on = [], False
        for i, x in enumerate(v > frac):
            if x and not on: st, on = i, True
            if not x and on:
                if i - st > 20: s.append((st, i))
                on = False
        if on and len(v) - st > 20: s.append((st, len(v)))
        return s
    return a, spans(m.mean(0)), spans(m.mean(1))

def icon(path, row, col, n=48):
    a, xs, ys = grid(path)
    (x0, x1), (y0, y1) = xs[col], ys[row]
    sx, sy = (x1 - x0) / n, (y1 - y0) / n
    out = np.zeros((n, n, 3), np.uint8)
    for j in range(n):
        for i in range(n):
            cx, cy = x0 + (i + .5) * sx, y0 + (j + .5) * sy
            rx, ry = max(1, sx * .25), max(1, sy * .25)
            blk = a[int(cy - ry + .5):int(cy + ry + .5) or None, int(cx - rx + .5):int(cx + rx + .5) or None]
            if blk.size == 0: blk = a[int(cy):int(cy) + 1, int(cx):int(cx) + 1]
            out[j, i] = np.median(blk.reshape(-1, 3), 0)
    return Image.fromarray(out).convert("RGBA").resize((n * 3, n * 3), Image.NEAREST)
