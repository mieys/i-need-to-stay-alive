import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
"""DIS CERCEVE adim 1b: haritanin eski kenarinda KESILMIS nesneleri (agac tepesi/govdesi, cali, maden...) halkaya dogru tamamla.
Karo atlasinda komsu karoyla piksel temasi olan karolar ayni nesnedir (tree_sway.gd / depth_occluders.gd ile ayni kabul)."""
from collections import deque
import numpy as np
from ring_core import *

EDGE_LAYERS_PREFIX = ('Shader Eklenecek/', 'Etkileşimler/', 'Düşman Üssü/')
FLAG_H, FLAG_V, FLAG_D = 0x80000000, 0x40000000, 0x20000000
DIRS = [(-1, 0), (1, 0), (0, -1), (0, 1)]


def tile_info(ts, lib, gid):
    g = gid & 0x0FFFFFFF
    t = ts.find(g)
    if not t:
        return None
    fg, src, img, cols, cnt = t
    i = g - fg
    if src not in lib.sets or not (0 <= i < cnt):
        return None
    return fg, src, cols, i, lib.sets[src]['alpha']


def touching(alpha, ia, ib, cols, d_atlas):
    """atlasta ia karosunun d_atlas yonundeki ib komsusu ile piksel temasi (+-1 capraz) var mi"""
    ax, ay = (ia % cols) * T, (ia // cols) * T
    bx, by = (ib % cols) * T, (ib // cols) * T
    if bx < 0 or by < 0 or by + T > alpha.shape[0] or bx + T > alpha.shape[1]:
        return False
    A = alpha[ay:ay + T, ax:ax + T] > 30
    Bm = alpha[by:by + T, bx:bx + T] > 30
    if not Bm.any():
        return False
    dx, dy = d_atlas
    if dx == -1:
        ea, eb = A[:, 0], Bm[:, T - 1]
    elif dx == 1:
        ea, eb = A[:, T - 1], Bm[:, 0]
    elif dy == -1:
        ea, eb = A[0, :], Bm[T - 1, :]
    else:
        ea, eb = A[T - 1, :], Bm[0, :]
    pad = np.pad(eb, 1)
    near = pad[:-2] | pad[1:-1] | pad[2:]
    return bool((ea & near).any())


def complete_edges(B, ts, lib, log=print):
    grids = B['grids']
    completed = np.zeros((H2, W2), bool)
    total = 0
    for path in B['order']:
        if not path.startswith(EDGE_LAYERS_PREFIX):
            continue
        g = grids[path]
        q = deque()
        for x in range(PLAY):
            for y in (0, PLAY - 1):
                if g[y - Y0, x - X0]:
                    q.append((x, y))
        for y in range(PLAY):
            for x in (0, PLAY - 1):
                if g[y - Y0, x - X0]:
                    q.append((x, y))
        added = 0
        seen = set(q)
        while q:
            x, y = q.popleft()
            gid = int(g[y - Y0, x - X0])
            if not gid or gid & FLAG_D:
                continue
            info = tile_info(ts, lib, gid)
            if not info:
                continue
            fg, src, cols, i, alpha = info
            fh, fv = bool(gid & FLAG_H), bool(gid & FLAG_V)
            for dx, dy in DIRS:
                nx, ny = x + dx, y + dy
                if 0 <= nx < PLAY and 0 <= ny < PLAY:
                    continue                       # oyun alani icine tasma yok
                if not (X0 <= nx < X0 + W2 and Y0 <= ny < Y0 + H2) or g[ny - Y0, nx - X0]:
                    continue
                da = (dx * (-1 if fh else 1), dy * (-1 if fv else 1))
                ib = i + da[0] + da[1] * cols
                if not (0 <= ib < i + 10 ** 6) or (da[0] != 0 and (i % cols) + da[0] not in range(cols)):
                    continue
                if not touching(alpha, i, ib, cols, da):
                    continue
                g[ny - Y0, nx - X0] = (fg + ib) | (gid & (FLAG_H | FLAG_V))
                completed[ny - Y0, nx - X0] = True
                added += 1
                if (nx, ny) not in seen:
                    seen.add((nx, ny))
                    q.append((nx, ny))
        if added:
            log(f'  kenar tamamlama: {path}: +{added} hucre')
        total += added
    B['completed'] = completed
    log(f'  kenar tamamlama toplam: {total} hucre')
