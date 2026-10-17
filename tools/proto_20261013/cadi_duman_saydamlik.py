"""Cadı Q dumanı - yaratıkların ÜSTÜNDE saydamlık karşılaştırması (kullanıcı 2026-10-13: "düşmanlar üstündeyken saydam
görünebilecekler mi? opaklık ayarı kötü durmaz mı?"). 4 satır, aynı duman (2. tur F):
  1 altta (şimdiki kural)   2 üstte, bulut başına opaklık   3 üstte, TEK PARÇA opaklık (CanvasGroup)   4 sandviç
    python -I tools/proto_20261013/cadi_duman_saydamlik.py  -> out/cadi_duman_saydamlik.png
Yaratık yerine başka karakter kareleri duruyor (sadece ölçü/örtülme için).
"""
import math
import os
import random
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import cadi_duman_proto as P  # noqa: E402
from cadi_duman_proto import G, GX, GY, Canvas, TAU  # noqa: E402

W, H, Z = 330, 80, 3
FEET_Y = 58
SPOTS = [78, 150, 214]  # dumanın içinde duran figürlerin ayak x'i
ALPHA_OVER = 0.5


def front_puffs(g, t, e):
    """Sandviçin ÖN katmanı: sadece alçak ön sıra toplar (ayak bileği - diz hizası)."""
    rng = random.Random(9)
    out = []
    for (x, y, r) in ((-23, 5, 7), (-9, 7, 8), (6, 7, 8), (21, 5, 7)):
        ph = rng.random()
        out.append((GX + x * g + math.cos(TAU * (t + ph)) * 1.2, GY + y - 4 + math.sin(TAU * (t + ph)) * 0.8,
                    r * (0.45 + 0.55 * g) * (1.0 + 0.06 * math.sin(TAU * (t + ph * 2.0)))))
    return out


def frame_front(g, t, e, u=0.0):
    cv = Canvas(P.FW, P.FH)
    P.clean_cloud(cv, front_puffs(g, t, e), P.PAL_F, scallop=True)
    return cv.rgba.copy()


def clouds():
    out = []
    for k in range(8):
        rng = random.Random(k * 7 + 3)
        out.append((W - 40 - k * 36.4, rng.random(), rng.random() < 0.5))
    return out


def layer(fn):
    """Bütün bulutlar TEK saydam tuvale (opak) - grup opaklığı bununla uygulanır."""
    buf = np.zeros((H, W, 4), np.uint8)
    for (cx, ph, flip) in reversed(clouds()):
        fr = fn(1.0, ph, 0.0)
        if flip:
            fr = fr[:, ::-1]
        x, y = int(round(cx - GX)), int(round(FEET_Y - GY))
        x0, x1 = max(0, x), min(W, x + fr.shape[1])
        y0, y1 = max(0, y), min(H, y + fr.shape[0])
        s = fr[y0 - y:y1 - y, x0 - x:x1 - x]
        m = s[:, :, 3] > 0
        buf[y0:y1, x0:x1][m] = s[m]
    return buf


def per_cloud(dst, fn, alpha):
    for (cx, ph, flip) in reversed(clouds()):
        fr = fn(1.0, ph, 0.0)
        G.blit(dst, fr, cx - GX, FEET_Y - GY, alpha=alpha, flip=flip)


def figures(dst, sheets):
    for i, x in enumerate(SPOTS):
        G.shadow(dst, x, FEET_Y + 1, 8, 2.6)
        G.char_at(dst, sheets[i % len(sheets)][0][0], x, FEET_Y)


def main():
    sheets = [G.load_game_sheet(k, 'idle') for k in ('korsan', 'hadime', 'assasin')]
    rows = []
    # 1 altta
    d = G.grass(W, H)
    per_cloud(d, P.frame_f, 0.9)
    figures(d, sheets)
    rows.append(('1 · Duman ALTTA (şimdiki kural) - yaratık dumanın üstünde durur', d))
    # 2 üstte, bulut başına
    d = G.grass(W, H)
    figures(d, sheets)
    per_cloud(d, P.frame_f, ALPHA_OVER)
    rows.append(('2 · Duman ÜSTTE, her bulut ayrı %50 - üst üste binen yerler lekeli', d))
    # 3 üstte, tek parça
    d = G.grass(W, H)
    figures(d, sheets)
    G.blit(d, layer(P.frame_f), 0, 0, alpha=ALPHA_OVER)
    rows.append(('3 · Duman ÜSTTE, tek parça %50 - leke yok ama renk soluk', d))
    # 4 sandviç
    d = G.grass(W, H)
    per_cloud(d, P.frame_f, 0.9)
    figures(d, sheets)
    G.blit(d, layer(frame_front), 0, 0, alpha=0.85)
    rows.append(('4 · SANDVİÇ: gövde altta + alçak ön toplar üstte - saydamlık gerekmez', d))
    full = np.zeros((H * len(rows), W, 3), np.uint8)
    for i, (_n, d) in enumerate(rows):
        full[i * H:(i + 1) * H] = d
        full[i * H] = (60, 86, 44)
    im = G.up(full, Z)
    for i, (n, _d) in enumerate(rows):
        G.label(im, 8, i * H * Z + 6, n, 16)
    out = os.path.join(HERE, 'out', 'cadi_duman_saydamlik.png')
    im.save(out)
    print('  tools/proto_20261013/out/cadi_duman_saydamlik.png')


if __name__ == '__main__':
    main()
