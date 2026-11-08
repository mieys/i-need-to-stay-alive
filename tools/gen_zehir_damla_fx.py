"""ZEHİR ASASI "A - Zehir Damlası" dokuları (madde 410; prototip tools/proto_20261106/zehir_asasi_proto.py, kullanıcı seçimi A).

Çıktılar:
  assets/weapons/mermi/zehir_govde.png  - uçan damla (+x = uçuş yönü, yuvarlak baş önde, kuyruk geride sivrilir, koyu kontur),
                                          23x15 (TEK boyut: pivot pikseli tam ortada - test_projectile_art).
  assets/fx/poison/zehir_damla_a.png    - 5 hücre (12x7): 0 damla 2x2, 1 hızlı damla 2x3, 2 asa ucu damlası 3x3,
                                          3 küçük gölcük 7x3, 4 büyük gölcük 11x5 (poison_drip_fx.gd REGIONS ile AYNI).
Doku pikseli oyunda 0,575 dünya px (silah/mermi pikseli). Renkler Zehir Asası'nın yeşilleri (#9bee9d #7fda76 #6fc161 #5a9652) çevresinde.
Çalıştırma: python tools/gen_zehir_damla_fx.py  (sonra Godot --headless --import)
"""
import math
import os

import numpy as np
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))


def hx(s):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16))


P = [hx(c) for c in "#f0ffe6 #b6f4ae #86e07c #66c05a #46924a #2c5e30".split()]
OL = hx("#18261a")
PUDDLE_A = 230  # gölcük hafif saydam (prototipte 0,9)


def body():
    """Prototip A gövdesi: baş merkezi (3,0) yarıçap 4,9, kuyruk -7'ye sivrilir (ince ucu konturuz koyu yeşil); ışık (4,2, -2), 1 px koyu kontur."""
    w, h = 21, 13
    inside = np.zeros((h, w), bool)
    col = {}
    hu, hr = 3.0, 4.9
    for y in range(h):
        for x in range(w):
            u, v = x + 0.5 - w / 2.0, y + 0.5 - h / 2.0
            ok = ((u - hu) / hr) ** 2 + (v / hr) ** 2 <= 1.0
            if not ok and -7.0 <= u <= hu:
                thr = hr * ((u + 7.0) / (hu + 7.0)) ** 1.4
                ok = thr >= 0.9 and abs(v) <= thr  # orta satır sonsuza kadar 1 px çizgi olarak uzamasın
            if not ok:
                continue
            inside[y, x] = True
            d = math.hypot(u - 4.2, v + 2.0)
            col[(x, y)] = P[0] if d < 1.3 else P[min(4, 1 + int(d / 2.5))]
    A = np.zeros((h, w, 4), np.uint8)
    thick = inside.sum(axis=0)
    for (x, y), c in col.items():
        edge = any(not (0 <= x + dx < w and 0 <= y + dy < h) or not inside[y + dy, x + dx]
                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        if edge and thick[x] <= 2:  # kuyruğun ucu: kontur yerine koyu yeşil (siyah iğne gibi durmasın)
            ys = np.nonzero(inside[:, x])[0]
            A[y, x, :3] = P[3] if y == ys.min() else P[4]
        else:
            A[y, x, :3] = OL if edge else c
        A[y, x, 3] = 255
    return np.pad(A, ((1, 1), (1, 1), (0, 0)))


def puddle(rx, ry):
    """Prototip "splat": yassı elips, dış halka koyu (P4) iç P3, sol üstte P1 parlama."""
    iy, ix = int(ry), int(rx)
    w, h = 2 * ix + 1, 2 * iy + 1
    A = np.zeros((h, w, 4), np.uint8)
    for dy in range(-iy, iy + 1):
        for dx in range(-ix, ix + 1):
            q = (dx / (rx + 0.3)) ** 2 + (dy / (ry + 0.3)) ** 2
            if q <= 1.0:
                A[dy + iy, dx + ix, :3] = P[4] if q > 0.55 else P[3]
                A[dy + iy, dx + ix, 3] = PUDDLE_A
    hx_, hy_ = -int(rx * 0.4), -(1 if ry >= 1.5 else 0)
    A[hy_ + iy, hx_ + ix, :3] = P[1]
    A[hy_ + iy, hx_ + ix, 3] = PUDDLE_A
    return A


def cells():
    def grid(rows):
        h, w = len(rows), len(rows[0])
        A = np.zeros((h, w, 4), np.uint8)
        for y in range(h):
            for x in range(w):
                c = rows[y][x]
                if c is not None:
                    A[y, x, :3] = c
                    A[y, x, 3] = 255
        return A
    drop = grid([[P[1], P[2]], [P[4], P[4]]])
    fast = grid([[P[1], P[2]], [P[3], P[4]], [P[4], P[4]]])
    big = grid([[None, P[1], None], [P[1], P[2], P[4]], [None, P[4], None]])
    return [drop, fast, big, puddle(3.0, 1.5), puddle(5.0, 2.5)]


def main():
    b = body()
    assert b.shape[0] % 2 == 1 and b.shape[1] % 2 == 1, b.shape
    p1 = os.path.join(ROOT, "assets", "weapons", "mermi", "zehir_govde.png")
    Image.fromarray(b, "RGBA").save(p1)
    CW, CH = 12, 7
    cs = cells()
    S = np.zeros((CH, CW * len(cs), 4), np.uint8)
    for i, c in enumerate(cs):
        h, w = c.shape[:2]
        S[0:h, i * CW:i * CW + w] = c  # sol üst köşeye; poison_drip_fx.gd REGIONS boyutları bunlar
    os.makedirs(os.path.join(ROOT, "assets", "fx", "poison"), exist_ok=True)
    p2 = os.path.join(ROOT, "assets", "fx", "poison", "zehir_damla_a.png")
    Image.fromarray(S, "RGBA").save(p2)
    print(p1, b.shape[1], "x", b.shape[0])
    print(p2, [(c.shape[1], c.shape[0]) for c in cs])


if __name__ == "__main__":
    main()
