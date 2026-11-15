"""DÜNYA HARİTASI (madde 606, "B - Atlas Defteri"): render.gd'nin gerçek çizici görüntülerinden harita seçim ekranının dokuları.

Arka plan kıtası: 1 piksel = 1 hücre (16 dünya px; tam çözünürlüklü render1 kutu filtresiyle 16'ya küçültülür). Bölgeler haritaların KENDİ pikselleri;
aradaki dolgu (orman / deniz) da haritalardan alınmış yamalarla (rastgele yama dikişi), hiçbir şey elle çizilmez. Zindanlar dağdaki
koyu taş kütlesi (planın kendi boşluk dokusu). Önizleme = haritanın 1 px = 4 dünya px gerçek görüntüsü (render1'in 4x4 ortalaması), oyun alanının ortasından.

Çıktı (assets/ui/dunya_haritasi/):
  dunya.png              kıta (ekranın kısık arka planı), 960x544
  onizleme_<id>.png      seçili haritanın büyük görüntüsü (PREVIEW_SIZE, oyun alanı ortası ya da PREVIEW_FOCUS)
  kucuk_<id>.png         listedeki küçük resim (oyun alanının tamamı, THUMB_SIZE kare, kutu filtresi)
Kullanım: tools/dunya_haritasi/uret.ps1 (render) -> python -I tools/dunya_haritasi/uret.py -> Godot --headless --import
Yeni harita: REGIONS'a ekle (kıtadaki sol üst hücre, görüntü içindeki oyun alanı, çerçeveden kalan hücre); test_world_map
her seçilebilir haritanın önizlemesini arar.
"""
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(HERE, 'out')
ASSET_DIR = os.path.join(ROOT, 'assets', 'ui', 'dunya_haritasi')
W, H = 960, 544
RNG = np.random.default_rng(7)

## (kimlik, dünyadaki sol üst hücre, oyun alanı görüntü içinde (x, y, w, h), çerçeveden kalan hücre)
## Ayaz Dağı (2026-11-12, madde 629): orta sütunun ÜSTÜNE (kuzey = soğuk dağ), ana harita aynı sütunda alta indi (eski (322, 112), keep 9);
## ikisi 256x256 olduğu için orta sütunda kıyı payları dar (keep 4 / 6), 544 piksel boya sığar.
REGIONS = [
    ('kis', (327, -10), (32, 20, 256, 256), 4),
    ('ana', (322, 260), (28, 20, 256, 256), 6),
    ('bataklik', (30, 252), (32, 20, 214, 214), 10),
    ('col', (626, 230), (32, 20, 243, 243), 12),
    ('batik_nekropol', (84, 22), (0, 0, 214, 214), 0),
    ('lagim_agi', (676, 18), (0, 0, 214, 214), 0),
]
DUNGEONS = ('batik_nekropol', 'lagim_agi')
B = 12 ## yama boyu
PREVIEW_SIZE = (1050, 494) ## world_map_screen.gd PREVIEW_SIZE ile aynı
THUMB_SIZE = 96
PREVIEW_FOCUS = {} ## kimlik -> (x, y) oyun alanında hücre; yoksa oyun alanının ortası


def lum(a):
    return a[..., 0] * 0.3 + a[..., 1] * 0.59 + a[..., 2] * 0.11


def load_full(rid):
    """render.gd'nin tam çözünürlüklü (1 px = 1 dünya px) görüntüsü, önbellekli."""
    if rid not in _FULL:
        _FULL[rid] = Image.open(os.path.join(OUT, 'render1_%s.png' % rid)).convert('RGBA')
    return _FULL[rid]


_FULL = {}


def load_cells(rid):
    return np.asarray(load_full(rid).reduce(16)).astype(np.float32)


def value_noise(w, h, scale, seed):
    r = np.random.default_rng(seed)
    g = r.random((h // scale + 3, w // scale + 3)).astype(np.float32)
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
    return value_noise(w, h, 40, seed) * 0.6 + value_noise(w, h, 13, seed + 1) * 0.3 + value_noise(w, h, 5, seed + 2) * 0.1


def quilt(src_list, w, h, block=B):
    """Kaynak yamalardan rastgele blok dikişi: orman/deniz dokusu tekrar etmeden."""
    out = np.zeros((h, w, 4), np.float32)
    for by in range(0, h, block):
        for bx in range(0, w, block):
            src = src_list[RNG.integers(len(src_list))]
            p = src[:block, :block]
            if RNG.random() < 0.5:
                p = p[:, ::-1]
            hh = min(block, h - by)
            ww = min(block, w - bx)
            out[by:by + hh, bx:bx + ww] = p[:hh, :ww]
    return out


def rect_dist(x, y, rw, rh):
    xs = np.arange(W)[None, :].astype(np.float32)
    ys = np.arange(H)[:, None].astype(np.float32)
    dx = np.maximum(np.maximum(x - xs, xs - (x + rw - 1)), 0)
    dy = np.maximum(np.maximum(y - ys, ys - (y + rh - 1)), 0)
    return np.sqrt(dx * dx + dy * dy)


def blocks_where(img, mask, block=B):
    out = []
    h, w = mask.shape
    for y in range(0, h - block, block // 2):
        for x in range(0, w - block, block // 2):
            if mask[y:y + block, x:x + block].all():
                out.append(img[y:y + block, x:x + block].copy())
    return out


def shift_or(m):
    return np.roll(m, 1, 0) | np.roll(m, -1, 0) | np.roll(m, 1, 1) | np.roll(m, -1, 1)


def build():
    cells = {rid: load_cells(rid) for rid, *_ in REGIONS}
    ## Dolgu: orman = ana haritanın dış çerçeve ormanı (sağ + sol şerit), deniz = ana haritanın denizi
    forest_src = []
    for x, y, w, h in ((0, 30, 26, 220), (288, 30, 24, 220)):
        a = cells['ana'][y:y + h, x:x + w]
        forest_src += blocks_where(a, a[..., 3] > 250)
    a = cells['ana']
    water = (a[..., 2] > a[..., 0] + 12) & (a[..., 2] >= a[..., 1] - 4) & (a[..., 3] > 250)
    sea_src = blocks_where(a, water)
    world = quilt(sea_src, W, H)
    forest = quilt(forest_src, W, H)
    fpad = np.pad(forest, ((1, 1), (1, 1), (0, 0)), mode='edge')
    forest = sum(fpad[dy:dy + H, dx:dx + W] for dy in range(3) for dx in range(3)) / 9.0 ## sakin orman: bölgeler öne çıksın
    forest[..., :3] *= 0.86
    n1 = fbm(W, H, 11)
    n2 = fbm(W, H, 23)

    ## Kıta: oyun alanlarının çevresi kara, tuval kenarına doğru gürültülü kıyı
    d_land = np.full((H, W), 1e9, np.float32)
    for rid, (ox, oy), (px, py, pw, ph), keep in REGIONS:
        d_land = np.minimum(d_land, rect_dist(ox + px, oy + py, pw, ph))
    xs = np.arange(W)[None, :].astype(np.float32)
    ys = np.arange(H)[:, None].astype(np.float32)
    d_edge = np.minimum(np.minimum(xs, W - 1 - xs), np.minimum(ys, H - 1 - ys))
    land = (d_land < 70 + (n1 - 0.5) * 40) & (d_edge > 12 + (n1 - 0.5) * 30)
    world[land] = forest[land]
    ## zindan: kendi boşluk dokusundan organik koyu taş kütlesi
    for rid, (ox, oy), _p, _k in REGIONS:
        if rid not in DUNGEONS:
            continue
        a = cells[rid]
        stone = quilt(blocks_where(a, (lum(a) < 34) & (a[..., 3] > 250)), W, H)
        h, w = a.shape[:2]
        mass = rect_dist(ox + 4, oy + 4, w - 8, h - 8) < 12 + (n2 - 0.5) * 26
        world[mass] = stone[mass]

    for rid, (ox, oy), (px, py, pw, ph), keep in REGIONS:
        a = cells[rid]
        h, w = a.shape[:2]
        x0, y0 = max(0, ox), max(0, oy)
        x1, y1 = min(W, ox + w), min(H, oy + h)
        sub = a[y0 - oy:y1 - oy, x0 - ox:x1 - ox]
        dist = rect_dist(ox + px, oy + py, pw, ph)[y0:y1, x0:x1]
        nz = n2[y0:y1, x0:x1]
        if rid in DUNGEONS:
            m = (dist <= 0) & (lum(sub) >= 34) ## planın boşluğu = taş kütlesi
            sub = sub.copy()
            sub[..., :3] = sub[..., :3] * np.array([0.80, 0.80, 0.88], np.float32) ## yeraltı: biraz loş + serin
        else:
            m = (dist <= 0) | (dist < keep + (nz - 0.5) * keep * 1.6)
        m &= sub[..., 3] > 200
        world[y0:y1, x0:x1][m] = sub[m]

    ## Kıyı: denize bakan kara pikseli kuma, kıyıya bitişik deniz bir ton koyu
    sea = ~land
    edge_land = land & shift_or(sea)
    edge_sea = sea & shift_or(land)
    world[edge_land] = world[edge_land] * 0.35 + np.array([196, 170, 118, 255], np.float32) * 0.65
    world[edge_sea, :3] *= 0.82
    world[..., 3] = 255

    os.makedirs(ASSET_DIR, exist_ok=True)
    Image.fromarray(np.clip(world, 0, 255).astype(np.uint8), 'RGBA').convert('RGB').save(os.path.join(ASSET_DIR, 'dunya.png'))
    for rid, _o, (px, py, pw, ph), _k in REGIONS:
        full = load_full(rid).convert('RGB').reduce(4) ## 1 px = 4 dünya px, her piksel 4x4 dünya pikselinin ortalaması (kutu filtresi)
        ## önizleme: oyun alanının ortası (ya da PREVIEW_FOCUS), görüntü sınırına kırpılır
        fx, fy = PREVIEW_FOCUS.get(rid, (px + pw / 2.0, py + ph / 2.0))
        cw, ch = PREVIEW_SIZE
        w_in, h_in = min(cw, full.width), min(ch, full.height) ## dar harita (zindan 856 px): ortalanır, yanlar köşe (boşluk) rengi
        left = int(min(max(0, round(fx * 4 - w_in / 2)), full.width - w_in))
        top = int(min(max(0, round(fy * 4 - h_in / 2)), full.height - h_in))
        pv = Image.new('RGB', (cw, ch), full.getpixel((0, 0)))
        pv.paste(full.crop((left, top, left + w_in, top + h_in)), ((cw - w_in) // 2, (ch - h_in) // 2))
        pv.save(os.path.join(ASSET_DIR, 'onizleme_%s.png' % rid))
        ## küçük resim: oyun alanının tamamı, kutu filtresi
        play = load_full(rid).convert('RGB').crop((px * 16, py * 16, (px + pw) * 16, (py + ph) * 16))
        play.resize((THUMB_SIZE, THUMB_SIZE), Image.BOX).save(os.path.join(ASSET_DIR, 'kucuk_%s.png' % rid))
    print('dunya %dx%d + onizleme/kucuk: %s' % (W, H, ', '.join(r for r, *_ in REGIONS)))


if __name__ == '__main__':
    build()
