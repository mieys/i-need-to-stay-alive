# DUVAR DİKİŞ DENETİMİ (madde 492): üretecin çıktısında duvar hücrelerinin içinden ZEMİN görünen pikselleri arar (yapısal duvar katmanlarının birleşik
# alfası < 255 ve altında zemin karosu var). Kullanıcı: "atladığın yerler var" - gözle aramak yerine bütün harita taranır.
# Kullanım: python -I tools/zindan/duvar_denetim.py [lagim_agi]   -> sınıf başına sayı + örnek hücreler, out/duvar_denetim_<id>.png (işaretli önizleme)
import os
import sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import numpy as np  # noqa: E402

import zindan_core as Z  # noqa: E402
import zindan_paint as P  # noqa: E402

GENS = {'lagim_agi': 'gen_lagim_agi', 'batik_nekropol': 'gen_batik_nekropol', 'taskin_hisar': 'gen_taskin_hisar'}
WALL_LAYERS = ('Duvar', 'Duvar kenarı', 'Duvar kenarı 2', 'Su kapısı', 'Su kapısı 2')
FH, FV, FD = Z.FH, Z.FV, Z.FD


def tile_alpha(bank, gid):
    if not gid:
        return None
    ts, lid = bank.decode(gid)
    if ts is None:
        return None
    t = ts.tile(lid)
    if gid & FD:
        t = t.transpose(Z.Image.TRANSPOSE)
    if gid & FH:
        t = t.transpose(Z.Image.FLIP_LEFT_RIGHT)
    if gid & FV:
        t = t.transpose(Z.Image.FLIP_TOP_BOTTOM)
    return np.array(t)[:, :, 3]


def tile_name(bank, gid):
    if not gid:
        return '-'
    ts, lid = bank.decode(gid)
    return '%s(%d,%d)' % (ts.key, lid % ts.cols, lid // ts.cols) if ts else '?'


def audit(pl, verbose=True):
    lay, tl, bank = pl.lay, pl.tl, pl.bank
    t = lay.t
    H, W = t.shape
    groups = defaultdict(list)
    for y in range(H):
        for x in range(W):
            if t[y, x] != Z.S:
                continue
            if not tl.get('Zemin', x, y):
                continue  # altında zemin yok: delik siyah boşluk gösterir (görünmez)
            cover = np.zeros((16, 16), bool)
            for ln in WALL_LAYERS:
                if ln not in tl.L:
                    continue
                a = tile_alpha(bank, tl.get(ln, x, y))
                if a is not None:
                    cover |= a > 0
            holes = int((~cover).sum())
            if holes == 0:
                continue
            k = P.k_below(t, x, y)
            nb = ''.join(c for c, (dx, dy) in zip('KDGB', ((0, -1), (1, 0), (0, 1), (-1, 0)))
                         if 0 <= x + dx < W and 0 <= y + dy < H and t[y + dy, x + dx] != Z.S)
            key = (k, tile_name(bank, tl.get('Duvar', x, y)), nb)
            groups[key].append((x, y, holes))
    total = sum(len(v) for v in groups.values())
    if verbose:
        print('delikli duvar hücresi:', total)
        for key, cells in sorted(groups.items(), key=lambda kv: -len(kv[1])):
            print('  k=%s karo=%s zemin komşusu=%s : %d hücre, örnek %s' % (key[0], key[1], key[2] or '-', len(cells),
                                                                          [(c[0], c[1], c[2]) for c in cells[:4]]))
    return groups


def side_extent(pl, x, y, s):
    """Duvar hücresi (x, y)'nin s (-1 batı / +1 doğu) yanındaki kenar çizgisinin konumu (px, satır 8): komşu zemin hücresine taşan opak sütun sayısı
    (> 0) ya da duvar hücresinin o yanında saydam kalan sütun sayısı (< 0)."""
    tl, bank = pl.tl, pl.bank
    nx = x + s
    out = 0
    cols = range(16) if s > 0 else range(15, -1, -1)
    for ln in WALL_LAYERS:
        if ln not in tl.L:
            continue
        a = tile_alpha(bank, tl.get(ln, nx, y))
        if a is None:
            continue
        n = 0
        for c in cols:
            if a[8, c] > 0:
                n += 1
            else:
                break
        out = max(out, n)
    if out > 0:
        return out
    cover = np.zeros(16, bool)
    for ln in WALL_LAYERS:
        if ln not in tl.L:
            continue
        a = tile_alpha(bank, tl.get(ln, x, y))
        if a is not None:
            cover |= a[8] > 0
    n = 0
    for c in (range(15, -1, -1) if s > 0 else range(16)):
        if not cover[c]:
            n += 1
        else:
            break
    return -n


def steps(pl, verbose=True):
    """Dikey duvar kenarında (duvar | zemin) ardışık iki satırın kenar çizgisi >= 2 px kayıyorsa basamak."""
    t = pl.lay.t
    H, W = t.shape
    groups = defaultdict(list)
    for x in range(1, W - 1):
        for s in (-1, 1):
            for y in range(1, H - 1):
                if not (t[y, x] == Z.S and t[y + 1, x] == Z.S and t[y, x + s] == Z.F and t[y + 1, x + s] == Z.F):
                    continue
                if ('Duvar kenarı 2' in pl.tl.L and pl.tl.get('Duvar kenarı 2', x + s, y + 1)) or (y + 2 < H and t[y + 2, x] == Z.W):
                    continue  # doğru durumlar: iç köşe (üst kenar parçası hücreyi boydan geçer) / suya inen yüzün su çizgisi satırı
                e0, e1 = side_extent(pl, x, y, s), side_extent(pl, x, y + 1, s)
                if abs(e0 - e1) >= 2:
                    k0, k1 = P.k_below(t, x, y), P.k_below(t, x, y + 1)
                    groups[(s, k0, k1, e0, e1)].append((x, y))
    if verbose:
        print('dikey kenarda basamak:', sum(len(v) for v in groups.values()))
        for key, cells in sorted(groups.items(), key=lambda kv: -len(kv[1])):
            print('  yan=%s k %s->%s kenar %spx->%spx : %d yer, örnek %s' % ((('B' if key[0] < 0 else 'D'),) + key[1:] + (len(cells), cells[:4])))
    return groups


def main():
    mid = sys.argv[1] if len(sys.argv) > 1 else 'lagim_agi'
    gen = __import__(GENS[mid])
    pl = gen.main(write=False)
    groups = audit(pl)
    st = steps(pl)
    for cells in st.values():
        groups.setdefault(('basamak',), []).extend((x, y, 0) for (x, y) in cells)
    img = Z.render(pl.bank, pl.tl, pl.lay.t.shape[1], pl.lay.t.shape[0], skip=('Engel',)).convert('RGB')
    from PIL import ImageDraw
    d = ImageDraw.Draw(img)
    for cells in groups.values():
        for (x, y, _h) in cells:
            d.rectangle((x * 16, y * 16, x * 16 + 15, y * 16 + 15), outline=(255, 0, 255))
    out = os.path.join(Z.OUT, 'duvar_denetim_%s.png' % mid)
    img.save(out)
    print('işaretli önizleme:', out)


if __name__ == '__main__':
    main()
