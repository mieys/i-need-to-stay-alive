"""DÜNYA HARİTASI prototipi (2026-11-12, oyuna bağlı DEĞİL) - 2. adım: render.gd'nin gerçek çizici görüntülerinden tek kıta kurar.

1 dünya haritası pikseli = 1 hücre (16 dünya px; render4 kutu filtresiyle 4'e küçültülür). Bölgeler haritaların KENDİ pikselleri;
aradaki dolgu (orman / kaya / deniz) da haritalardan alınmış yamalarla (rastgele yama dikişi), hiçbir şey elle çizilmez.
Zindanlar dağın içindeki yıkıntılar gibi: planın boşluğu (koyu duvar tepesi) kaya dolgusuna açılır.

Çıktı out/: dunya.png (dünya), bolge_<id>.png (bölge maskesi, beyaz), bolgeler.json (dikdörtgen + merkez + etiket yeri)
  python -I tools/proto_20261112/dunya_haritasi/compose.py
"""
import json
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'out')
W, H = 960, 544
RNG = np.random.default_rng(7)
DARK = {}

## (kimlik, dünyadaki sol üst hücre, oyun alanı görüntü içinde (x, y, w, h), çerçeveden kalan hücre)
REGIONS = [
    ('ana', (322, 112), (28, 20, 256, 256), 9),
    ('bataklik', (30, 252), (32, 20, 214, 214), 10),
    ('col', (626, 230), (32, 20, 243, 243), 12),
    ('batik_nekropol', (84, 22), (0, 0, 214, 214), 0),
    ('lagim_agi', (676, 18), (0, 0, 214, 214), 0),
]
DUNGEONS = ('batik_nekropol', 'lagim_agi')


def load_cells(rid):
    im = Image.open(os.path.join(OUT, 'render4_%s.png' % rid)).convert('RGBA')
    return np.asarray(im.reduce(4)).astype(np.float32)


def value_noise(w, h, scale, seed):
    r = np.random.default_rng(seed)
    gw, gh = w // scale + 3, h // scale + 3
    g = r.random((gh, gw)).astype(np.float32)
    ys = np.arange(h) / scale
    xs = np.arange(w) / scale
    y0 = ys.astype(int)
    x0 = xs.astype(int)
    fy = ys - y0
    fx = xs - x0
    fy = fy * fy * (3 - 2 * fy)
    fx = fx * fx * (3 - 2 * fx)
    a = g[y0][:, x0]
    b = g[y0][:, x0 + 1]
    c = g[y0 + 1][:, x0]
    d = g[y0 + 1][:, x0 + 1]
    top = a + (b - a) * fx[None, :]
    bot = c + (d - c) * fx[None, :]
    return top + (bot - top) * fy[:, None]


def fbm(w, h, seed):
    return (value_noise(w, h, 40, seed) * 0.6 + value_noise(w, h, 13, seed + 1) * 0.3 + value_noise(w, h, 5, seed + 2) * 0.1)


def quilt(src_list, w, h, block=10):
    """Kaynak yamalardan (H x W x 4) rastgele blok dikişi: orman/kaya/deniz dokusu tekrar etmeden."""
    out = np.zeros((h, w, 4), np.float32)
    for by in range(0, h, block):
        for bx in range(0, w, block):
            src = src_list[RNG.integers(len(src_list))]
            sh, sw = src.shape[:2]
            yy = RNG.integers(0, sh - block + 1)
            xx = RNG.integers(0, sw - block + 1)
            p = src[yy:yy + block, xx:xx + block]
            if RNG.random() < 0.5:
                p = p[:, ::-1]
            hh = min(block, h - by)
            ww = min(block, w - bx)
            out[by:by + hh, bx:bx + ww] = p[:hh, :ww]
    return out


def rect_dist(w, h, x, y, rw, rh):
    xs = np.arange(w)[None, :].astype(np.float32)
    ys = np.arange(h)[:, None].astype(np.float32)
    dx = np.maximum(np.maximum(x - xs, xs - (x + rw - 1)), 0)
    dy = np.maximum(np.maximum(y - ys, ys - (y + rh - 1)), 0)
    return np.sqrt(dx * dx + dy * dy)


def blocks_where(img, mask, block):
    """mask'in tamamen dolu olduğu block x block yamalar."""
    out = []
    h, w = mask.shape
    for y in range(0, h - block, block // 2):
        for x in range(0, w - block, block // 2):
            if mask[y:y + block, x:x + block].all():
                out.append(img[y:y + block, x:x + block].copy())
    return out


def main():
    cells = {rid: load_cells(rid) for rid, *_ in REGIONS}
    lum = lambda a: a[..., 0] * 0.3 + a[..., 1] * 0.59 + a[..., 2] * 0.11

    ## Dolgu kaynakları: orman = bataklığın + ana haritanın dış çerçeve ormanı, kaya = çölün kaya çerçevesi, deniz = ana haritanın denizi.
    B = 12
    forest_src = []
    for rid, box in (('ana', (0, 30, 26, 220)), ('ana', (288, 30, 24, 220))):
        x, y, w, h = box
        a = cells[rid][y:y + h, x:x + w]
        g = a[..., 3] > 250
        forest_src += blocks_where(a, g, B)
    rock_src = []
    for box in ((0, 0, 30, 283), (277, 0, 30, 283)):
        x, y, w, h = box
        a = cells['col'][y:y + h, x:x + w]
        rock_src += blocks_where(a, a[..., 3] > 250, B)
    a = cells['ana']
    water = (a[..., 2] > a[..., 0] + 12) & (a[..., 2] >= a[..., 1] - 4) & (a[..., 3] > 250)
    sea_src = blocks_where(a, water, B)
    print('yamalar: orman %d kaya %d deniz %d' % (len(forest_src), len(rock_src), len(sea_src)))

    world = quilt(sea_src, W, H, B)
    forest = quilt(forest_src, W, H, B)
    fpad = np.pad(forest, ((1, 1), (1, 1), (0, 0)), mode='edge')
    forest = sum(fpad[dy:dy + H, dx:dx + W] for dy in range(3) for dx in range(3)) / 9.0
    forest[..., :3] *= 0.86
    rock = quilt(rock_src, W, H, B)
    n1 = fbm(W, H, 11)
    n2 = fbm(W, H, 23)

    ## Kara: oyun alanlarına uzaklık + gürültü
    d_land = np.full((H, W), 1e9, np.float32)
    d_dungeon = np.full((H, W), 1e9, np.float32)
    for rid, (ox, oy), (px, py, pw, ph), keep in REGIONS:
        d = rect_dist(W, H, ox + px, oy + py, pw, ph)
        d_land = np.minimum(d_land, d)
        if rid in DUNGEONS:
            d_dungeon = np.minimum(d_dungeon, d)
    ## Kıta: oyun alanlarının çevresi kara, tuval kenarına doğru gürültülü kıyı (deniz kenarda kalır)
    xs = np.arange(W)[None, :].astype(np.float32)
    ys = np.arange(H)[:, None].astype(np.float32)
    d_edge = np.minimum(np.minimum(xs, W - 1 - xs), np.minimum(ys, H - 1 - ys))
    land = (d_land < 70 + (n1 - 0.5) * 40) & (d_edge > 12 + (n1 - 0.5) * 30)
    world[land] = forest[land]
    for rid, (ox, oy), _p, _k in REGIONS:
        if rid not in DUNGEONS:
            continue
        a = cells[rid]
        void_src = blocks_where(a, (lum(a) < 34) & (a[..., 3] > 250), B)
        stone = quilt(void_src, W, H, B)
        h, w = a.shape[:2]
        mass = rect_dist(W, H, ox + 4, oy + 4, w - 8, h - 8) < 12 + (n2 - 0.5) * 26
        world[mass] = stone[mass]
        DARK[rid] = mass

    regions_meta = []
    for rid, (ox, oy), (px, py, pw, ph), keep in REGIONS:
        a = cells[rid]
        h, w = a.shape[:2]
        x0, y0 = max(0, ox), max(0, oy)
        x1, y1 = min(W, ox + w), min(H, oy + h)
        sub = a[y0 - oy:y1 - oy, x0 - ox:x1 - ox]
        dist = rect_dist(W, H, ox + px, oy + py, pw, ph)[y0:y1, x0:x1]
        nz = n2[y0:y1, x0:x1]
        if rid in DUNGEONS:
            inner = -rect_dist(W, H, ox + 6, oy + 6, w - 12, h - 12)[y0:y1, x0:x1]
            m = (dist <= 0) & (lum(sub) >= 34)
        else:
            m = (dist <= 0) | (dist < keep + (nz - 0.5) * keep * 1.6)
        m &= sub[..., 3] > 200
        if rid in DUNGEONS:
            ## planın boşluğu (koyu duvar tepesi) = dağ; zindan biraz loş + serin (yeraltı)
            sub = sub.copy()
            sub[..., :3] = sub[..., :3] * np.array([0.80, 0.80, 0.88], np.float32)
        tgt = world[y0:y1, x0:x1]
        tgt[m] = sub[m]
        mask = np.zeros((H, W), np.uint8)
        mask[y0:y1, x0:x1][m] = 255
        ## bölge maskesi: oyun alanı (çerçeve değil) - vurgu dış hattı bunun kenarı
        pm = np.zeros((H, W), np.uint8)
        rx0, ry0 = max(0, ox + px), max(0, oy + py)
        rx1, ry1 = min(W, ox + px + pw), min(H, oy + py + ph)
        pm[ry0:ry1, rx0:rx1] = 255
        pm &= mask
        Image.fromarray(pm, 'L').save(os.path.join(OUT, 'bolge_%s.png' % rid))
        ys, xs = np.nonzero(pm)
        regions_meta.append({'id': rid, 'rect': [int(xs.min()), int(ys.min()), int(xs.max() - xs.min() + 1), int(ys.max() - ys.min() + 1)],
                             'center': [float(xs.mean()), float(ys.mean())]})

    ## Kıyı: denize bakan kara pikseli bir ton açık (kum), kıyıya bitişik deniz bir ton koyu
    sea = ~land
    edge_land = land & (np.roll(sea, 1, 0) | np.roll(sea, -1, 0) | np.roll(sea, 1, 1) | np.roll(sea, -1, 1))
    edge_sea = sea & (np.roll(land, 1, 0) | np.roll(land, -1, 0) | np.roll(land, 1, 1) | np.roll(land, -1, 1))
    sand = np.array([196, 170, 118, 255], np.float32)
    world[edge_land] = world[edge_land] * 0.35 + sand * 0.65
    world[edge_sea, :3] *= 0.82
    world[..., 3] = 255
    Image.fromarray(np.clip(world, 0, 255).astype(np.uint8), 'RGBA').save(os.path.join(OUT, 'dunya.png'))
    with open(os.path.join(OUT, 'bolgeler.json'), 'w', encoding='utf-8') as f:
        json.dump({'size': [W, H], 'regions': regions_meta}, f, ensure_ascii=False, indent=1)
    print('dunya', W, H, [r['id'] for r in regions_meta])


if __name__ == '__main__':
    main()
