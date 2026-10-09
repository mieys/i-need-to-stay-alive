"""Haritanin KENDI animasyonlu cali katmanlarindaki (Çalılar, Çalılar1) benzersiz sprite'lari cikarir + kontak sayfasi.
Kullanim: HARITA_TMX=<agac-oncesi yedek> python -I tools/forest_decor/exist_bushes.py tools/forest_decor/out"""
import sys, os, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tmxlib import *
from PIL import ImageDraw
from collections import Counter, defaultdict
out_dir = sys.argv[1]
root, ts = load()
L = {'/'.join(p): grid(l) for p, l in layers(root)}
def decode(gid):
    g = gid & 0x0FFFFFFF; fl = gid & 0xE0000000; t = ts.find(g)
    return (t[1], g - t[0], fl, t[3]) if t else None
for lname, tag in (('Shader Eklenecek/Çalılar', 'calilar'), ('Shader Eklenecek/Çalılar1', 'calilar1')):
    g = L[lname]
    cells = {(int(y), int(x)): decode(int(g[y, x])) for y, x in zip(*np.nonzero(g))}
    cells = {k: v for k, v in cells.items() if v}
    parent = {k: k for k in cells}
    def find(a):
        while parent[a] != a: parent[a] = parent[parent[a]]; a = parent[a]
        return a
    for (y, x), (src, i, fl, cols) in cells.items():
        for dy, dx, di in ((0, 1, 1), (1, 0, cols)):
            n = (y + dy, x + dx)
            if n in cells and cells[n][0] == src and cells[n][2] == fl and cells[n][1] == i + di: parent[find(n)] = find((y, x))
    groups = defaultdict(list)
    for k in cells: groups[find(k)].append(k)
    uniq = defaultdict(lambda: [0, None])
    for ks in groups.values():
        y0 = min(k[0] for k in ks); x0 = min(k[1] for k in ks)
        tiles = tuple(sorted((k[1] - x0, k[0] - y0, int(g[k])) for k in ks))
        uniq[tiles][0] += 1; uniq[tiles][1] = (x0, y0)
    items = sorted(uniq.items(), key=lambda kv: -kv[1][0])
    sc = 3; W_ = 1700; x = y = 0; rh = 0; pos = []
    for tiles, (n, _) in items:
        w = max(t[0] for t in tiles) + 1; h = max(t[1] for t in tiles) + 1
        pw, ph = w * T * sc, h * T * sc
        if x + pw + 30 > W_: x = 0; y += rh + 26; rh = 0
        pos.append((x, y)); x += pw + 30; rh = max(rh, ph)
    sheet = Image.new('RGBA', (W_, y + rh + 30), (110, 170, 80, 255)); d = ImageDraw.Draw(sheet)
    meta = []
    for idx, ((tiles, (n, first)), (px, py)) in enumerate(zip(items, pos)):
        w = max(t[0] for t in tiles) + 1; h = max(t[1] for t in tiles) + 1
        st = Image.new('RGBA', (w * T, h * T), (0, 0, 0, 0))
        for tx, ty, gid in tiles:
            im = ts.tile(gid)
            if im: st.alpha_composite(im, (tx * T, ty * T))
        sheet.alpha_composite(st.resize((w * T * sc, h * T * sc), Image.NEAREST), (px, py))
        srcs = Counter(decode(gid)[0] for _, _, gid in tiles)
        d.text((px, py - 11), f"{idx} x{n} {w}x{h} {list(srcs)[0][:8]}", fill=(255, 255, 255, 255))
        meta.append({'idx': idx, 'n': int(n), 'w': int(w), 'h': int(h), 'tiles': [[int(a) for a in t] for t in tiles], 'src': list(srcs)[0]})
    sheet.convert('RGB').save(f'{out_dir}/exist_{tag}.png'); json.dump(meta, open(f'{out_dir}/exist_{tag}.json', 'w'))
    print(lname, 'grup', len(groups), 'benzersiz', len(uniq), 'sayfa', sheet.size)
    print('  en cok kullanilan:', [(m['idx'], m['n'], f"{m['w']}x{m['h']}", m['src'][:6]) for m in meta[:12]])
