"""DIS CERCEVE (2026-10-13) - ortak ihtiyaclar: dolgulu genis izgara, TMX okuma/yazma (sonsuz harita, parca/chunk), onizleme cizimi.
Kullanici istegi: "haritanin dis kenarlarina gecilemez orman / deniz kisimlarina su; kose yaklasinca kamera durdugu icin bogucu"
-> mevcut 256x256 alan ve TUM hucre koordinatlari AYNI kalir; harita sonsuz (infinite) TMX'e cevrilip dis halka NEGATIF / 256+ hucrelere eklenir."""
import os, re, sys
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'forest_decor'))
import tmxlib
from tmxlib import T, layers, grid, load

PLAY = 256          # eski harita hucre sayisi (kare)
RX, RY = 32, 20     # dis halka kalinligi (hucre): sol/sag, ust/alt. Kamera yarisi: 480x270 px (zoom 2.0) = 30x16.9 hucre; oyuncu kenardan 16 px iceride
X0, Y0 = -RX, -RY
W2, H2 = PLAY + 2 * RX, PLAY + 2 * RY
CHUNK = 16


def play_slice():
    return (slice(RY, RY + PLAY), slice(RX, RX + PLAY))


def pad(old):
    """256x256 izgarayi (H2,W2) sifir dolgulu izgaraya yerlestir."""
    out = np.zeros((H2, W2), np.int64)
    out[play_slice()] = old
    return out


def ring_mask():
    m = np.ones((H2, W2), bool)
    m[play_slice()] = False
    return m


def clamp_src(x, y):
    """Halka hucresi (mutlak hucre x,y) -> en yakin oyun alani kenar hucresi."""
    return min(max(x, 0), PLAY - 1), min(max(y, 0), PLAY - 1)


def abs_to_idx(x, y):
    return y - Y0, x - X0


# ------------------------------------------------------------------ TMX yazma (sonsuz harita)
def csv_chunks(g):
    """(H2,W2) izgara -> Tiled parca (chunk) metni. Bos parcalar atlanir."""
    parts = []
    cy0 = (Y0 // CHUNK) * CHUNK
    cx0 = (X0 // CHUNK) * CHUNK
    for cy in range(cy0, Y0 + H2, CHUNK):
        for cx in range(cx0, X0 + W2, CHUNK):
            blk = np.zeros((CHUNK, CHUNK), np.int64)
            ys = max(cy, Y0); ye = min(cy + CHUNK, Y0 + H2)
            xs = max(cx, X0); xe = min(cx + CHUNK, X0 + W2)
            blk[ys - cy:ye - cy, xs - cx:xe - cx] = g[ys - Y0:ye - Y0, xs - X0:xe - X0]
            if not blk.any():
                continue
            rows = [','.join(str(int(v)) for v in r) for r in blk]
            body = ',\n'.join(rows)
            parts.append(f'<chunk x="{cx}" y="{cy}" width="{CHUNK}" height="{CHUNK}">\n{body}\n</chunk>')
    return '\n'.join(parts)


def data_block(g, indent='   '):
    return f'{indent}<data encoding="csv">\n{csv_chunks(g)}\n{indent}</data>'


# ------------------------------------------------------------------ onizleme (python cizimi; oyun golgeleyicileri YOK)
def render_region(ts, grids, order, vis, opac, region):
    """region = (x0,y0,x1,y1) mutlak hucre. grids: yol -> (H2,W2). order: belge sirasindaki yollar."""
    x0, y0, x1, y1 = region
    out = Image.new('RGBA', ((x1 - x0) * T, (y1 - y0) * T), (0, 0, 0, 255))
    for p in order:
        if not vis.get(p, True):
            continue
        g = grids[p]
        sub = g[y0 - Y0:y1 - Y0, x0 - X0:x1 - X0]
        ys, xs = np.nonzero(sub)
        if len(ys) == 0:
            continue
        lay = Image.new('RGBA', out.size, (0, 0, 0, 0))
        for y, x in zip(ys, xs):
            t = ts.tile(int(sub[y, x]))
            if t:
                lay.alpha_composite(t, (int(x * T), int(y * T)))
        op = opac.get(p, 1.0)
        if op < 1:
            a = lay.getchannel('A').point(lambda v: int(v * op)); lay.putalpha(a)
        out.alpha_composite(lay)
    return out
