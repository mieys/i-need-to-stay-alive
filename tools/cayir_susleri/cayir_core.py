# -*- coding: utf-8 -*-
"""BAŞLANGIÇ ÇAYIRI SÜSLERİ (madde 383) - ortak yardımcılar: sonsuz Harita.tmx katman okuma (chunk), karo çizici (önizleme),
tileset nesne (sprite) çıkarımı. Tüm görseller haritanın ZATEN bağlı olduğu tileset'lerden; yeni sanat yok."""
import os
import re
import sys
import xml.etree.ElementTree as ET

import numpy as np
from PIL import Image

sys.stdout.reconfigure(encoding='utf-8')
HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.normpath(os.path.join(HERE, '..', '..'))
HARITA = os.path.join(PROJECT, 'harita')
TMX = os.path.join(HARITA, 'Harita.tmx')
T = 16
FLIP_MASK = 0x0FFFFFFF


def read_tmx(path=TMX):
    return open(path, encoding='utf-8').read()


def layer_list(text):
    """[(ad, opaklık, görünür, {(x, y): gid})] belge sırasında (çizim sırası)."""
    root = ET.fromstring(text)
    out = []

    def walk(el):
        for c in el:
            if c.tag == 'group':
                walk(c)
            elif c.tag == 'layer':
                cells = {}
                for ch in c.find('data').findall('chunk'):
                    cx, cy, w = int(ch.get('x')), int(ch.get('y')), int(ch.get('width'))
                    vals = [int(v) for v in ch.text.replace('\r', '').replace('\n', '').split(',') if v.strip()]
                    for i, v in enumerate(vals):
                        if v:
                            cells[(cx + i % w, cy + i // w)] = v
                out.append((c.get('name'), float(c.get('opacity', '1')), c.get('visible') != '0', cells))
    walk(root)
    return out


class Tilesets:
    """gid -> 16x16 RGBA karo (çevirme bayrakları dahil)."""

    def __init__(self, text):
        self.list = []
        for fg, src in re.findall(r'<tileset firstgid="(\d+)" source="([^"]+)"/>', text):
            p = os.path.join(HARITA, src)
            if not os.path.exists(p):
                continue
            try:
                tr = ET.parse(p).getroot()
            except ET.ParseError:   ## bilinen bozuk eski tsx (Yeni klasör-default.tsx gibi) - çizilmez
                continue
            im = tr.find('image')
            if im is None:
                continue
            ip = os.path.normpath(os.path.join(os.path.dirname(p), im.get('source')))
            if not os.path.exists(ip):
                continue
            self.list.append((int(fg), src, Image.open(ip).convert('RGBA'), int(tr.get('columns')), int(tr.get('tilecount'))))
        self.list.sort(key=lambda t: t[0])
        self.by_src = {t[1]: t for t in self.list}
        self.cache = {}

    def find(self, g):
        best = None
        for t in self.list:
            if t[0] <= g:
                best = t
        return best

    def firstgid(self, src):
        return self.by_src[src][0]

    def tile(self, gid):
        if gid in self.cache:
            return self.cache[gid]
        g = gid & FLIP_MASK
        res = None
        t = self.find(g)
        if t:
            fg, src, img, cols, cnt = t
            i = g - fg
            if 0 <= i < cnt:
                x, y = (i % cols) * T, (i // cols) * T
                res = img.crop((x, y, x + T, y + T))
                if gid & 0x20000000:
                    res = res.transpose(Image.TRANSPOSE)
                if gid & 0x80000000:
                    res = res.transpose(Image.FLIP_LEFT_RIGHT)
                if gid & 0x40000000:
                    res = res.transpose(Image.FLIP_TOP_BOTTOM)
        self.cache[gid] = res
        return res


def render(layers, ts, region, extra=None, skip=()):
    """Bölgeyi (x0, y0, x1, y1 hücre) karolardan çizer. extra: {katman: {hücre: gid}} - o katmanın ÜSTÜNE eklenecek yeni hücreler."""
    x0, y0, x1, y1 = region
    out = Image.new('RGBA', ((x1 - x0) * T, (y1 - y0) * T), (0, 0, 0, 255))
    for name, op, vis, cells in layers:
        if not vis or name in skip:
            continue
        add = (extra or {}).get(name, {})
        lay = Image.new('RGBA', out.size, (0, 0, 0, 0))
        for src in (cells, add):
            for (x, y), g in src.items():
                if x0 <= x < x1 and y0 <= y < y1:
                    t = ts.tile(g)
                    if t:
                        lay.alpha_composite(t, ((x - x0) * T, (y - y0) * T))
        if op < 1:
            lay.putalpha(lay.getchannel('A').point(lambda v: int(v * op)))
        out.alpha_composite(lay)
    return out


class Sprite:
    """Tileset resmindeki bir nesne: hücre ofseti -> gid (yalnız opak karolar)."""

    def __init__(self, name, src, tiles, w, h, rgba):
        self.name, self.src, self.tiles, self.w, self.h, self.rgba = name, src, tiles, w, h, rgba

    def cells(self, ax, ay):
        """(ax, ay) = sol üst hücre."""
        return {(ax + i, ay + j): g for i, j, g in self.tiles}


## terrain_collision.gd "props" kuralının (madde 364) birebir kopyası: Animasyonsuz çalılar'daki hangi nesne oyunda ENGEL olur.
PROP_SKIP = ('Ground_grass', 'derin_orman_zemin', 'spots_lianas', 'Flowers', 'Yol par', 'Water')


def is_solid_prop(spr):
    if any(k in spr.src for k in PROP_SKIP):
        return False
    a = np.asarray(spr.rgba, np.float32) / 255.0
    op = a[..., 3] > 0.4
    if not op.any():
        return False
    ys, xs = np.nonzero(op)
    w, h = xs.max() - xs.min() + 1, ys.max() - ys.min() + 1
    px = int(op.sum())
    if w < 18 or h < 14 or px < 220 or px / float(w * h) < 0.35:
        return False
    c = a[..., 3] > 0.5
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    green = int((c & (g > r + 0.05) & (g > b + 0.05)).sum()) / px
    red = int((c & ~((g > r + 0.05) & (g > b + 0.05)) & (r > 0.55) & (r > g + 0.3) & (r > b + 0.3)).sum()) / px
    if w * h <= 700 and green + red >= 0.15:
        return False
    return green < 0.4


def center_blocked(spr, y_sorted=True):
    """tests/test_deep_forest.gd test_props_are_solid_but_soft_plants_are_not kuralı: katı nesnenin (genişlik >= 24 px) yatay ortası, tabanın
    3 + FEET_SHIFT px üstünde ENGEL olmalı. terrain_collision._add_band'ın taklidi: y-sıralı katmanda bant = boyun %50'si (8..24 px), ayak
    kaydırması 15 px, hücre en az 20 opak piksel. Ortası boş nesne (iki bacaklı kurutma çerçevesi gibi) False."""
    a = np.asarray(spr.rgba)[..., 3] > 102
    placed = {(i, j) for i, j, g in spr.tiles}
    for j in range(spr.h):
        for i in range(spr.w):
            if (i, j) not in placed:
                a[j * T:(j + 1) * T, i * T:(i + 1) * T] = False
    ys, xs = np.nonzero(a)
    if not len(ys) or xs.max() - xs.min() + 1 < 24:
        return True
    base = ys.max() + 1
    hpx = ys.max() - ys.min() + 1
    band = min(max(hpx * 0.5, 8.0), 24.0) if y_sorted else min(hpx, 48.0)
    txs = [i for i, j in placed]
    gx = int((min(txs) + max(txs) + 1) * 0.5 * T // T)
    gy = int((base - 18) // T)
    cnt = 0
    for y in range(max(0, int(np.ceil(base - band))), base):
        if int((y + 0.5 - 15) // T) != gy:
            continue
        cnt += int(a[y, gx * T:(gx + 1) * T].sum())
    return cnt >= 20


def sprite(ts, name, src, tx, ty, tw, th, min_alpha=8):
    """Tileset'in (tx, ty) karosundan tw x th dikdörtgen; tamamen saydam karolar atlanır."""
    fg, _s, img, cols, _c = ts.by_src[src]
    a = np.asarray(img)[..., 3]
    tiles = []
    for j in range(th):
        for i in range(tw):
            blk = a[(ty + j) * T:(ty + j + 1) * T, (tx + i) * T:(tx + i + 1) * T]
            if blk.size and blk.max() >= min_alpha:
                tiles.append((i, j, fg + (ty + j) * cols + (tx + i)))
    rgba = img.crop((tx * T, ty * T, (tx + tw) * T, (ty + th) * T))
    return Sprite(name, src, tiles, tw, th, rgba)


## ---------------- chunk yazımı (place_derin_orman.py ile aynı biçim) ----------------
def layer_span(text, name):
    m = re.search(r'\n  <layer id="\d+" name="%s"[^>]*>\n   <data encoding="csv">\n(.*?)\n   </data>\n  </layer>' % re.escape(name), text, re.S)
    assert m, 'katman yok: ' + name
    return m


def parse_chunks(body):
    chunks = {}
    for cm in re.finditer(r'<chunk x="(-?\d+)" y="(-?\d+)" width="16" height="16">\s*(.*?)\s*</chunk>', body, re.S):
        vals = np.array([int(v) for v in cm.group(3).replace('\n', '').split(',') if v.strip()], np.int64).reshape(16, 16)
        chunks[(int(cm.group(1)), int(cm.group(2)))] = vals
    return chunks


def write_chunks(chunks):
    parts = []
    for (cx, cy) in sorted(chunks, key=lambda k: (k[1], k[0])):
        rows = [','.join(str(int(v)) for v in r) for r in chunks[(cx, cy)]]
        parts.append('    <chunk x="%d" y="%d" width="16" height="16">\n%s\n</chunk>' % (cx, cy, ',\n'.join(rows)))
    return '\n'.join(parts)


def add_cells(text, name, cells):
    """Katmana SADECE boş hücrelere ekler (dolu hücreye yazmak assert)."""
    m = layer_span(text, name)
    ch = parse_chunks(m.group(1))
    for (x, y), g in cells.items():
        cx, cy = (x // 16) * 16, (y // 16) * 16
        if (cx, cy) not in ch:
            ch[(cx, cy)] = np.zeros((16, 16), np.int64)
        assert ch[(cx, cy)][y - cy, x - cx] == 0, ('dolu hücreye yazılıyordu', name, x, y)
        ch[(cx, cy)][y - cy, x - cx] = g
    return text[:m.start(1)] + write_chunks(ch) + text[m.end(1):]
