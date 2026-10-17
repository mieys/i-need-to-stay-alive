import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
"""DIS CERCEVE (2026-10-13) - agac / cali / kaya sablonlari. Yeni gorsel URETMEZ: Harita.tmx'in bagli oldugu tileset'lerden
(Objects, sade agac ve tas, sadece_agac) kesilmis karo bloklari; secimler tools/forest_decor/gen_forest.py ile AYNI kimlikler."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'forest_decor'))
from stamplib import *   # noqa  (tmxlib + Lib + footprint)

O, SA, TR = 'Objects.tsx', 'sade ağaç ve taş.tsx', 'sadece_agac.tsx'

def build(lib):
    def mk(src, ids):
        out = []
        for i in ids:
            st = lib.stamp(src, i)
            assert st['contam'] == 0, (src, i, st['contam'])
            st['name'] = f"{src.split('.')[0][:6]}{i}"
            a = st['alpha']
            rows = np.nonzero((a >= 102).any(axis=1))[0]
            st['basepx'] = int(rows.max()) + 1 if len(rows) else a.shape[0]
            out.append(st)
        return out
    TREES = {
        'lush_big':   mk(O, [2, 5, 14, 1, 0]) + mk(SA, [1, 2, 3]),
        'lush_mid':   mk(O, [13, 11, 12]) + mk(SA, [4, 5, 6]),
        'lush_small': mk(SA, [7, 8]),
        'oak_big':    mk(O, [4]),
        'dark_pine':  mk(O, [0, 11, 12]) + mk(SA, [2, 5]),
        'mossy':      mk(TR, [6, 18, 28]),
        'dead':       mk(TR, [5, 17, 27]),
        'twisted':    mk(SA, [3, 6, 7]),
    }
    SHRUBS = mk(O, [15, 20, 22, 25, 26, 31, 32, 19, 3]) + mk(SA, [9, 10, 11, 12, 13, 14, 18])
    SHRUBS_DARK = mk(O, [19, 31, 32]) + mk(SA, [9, 10, 11])
    MUSH = mk(O, [64, 65, 66, 70, 71, 72])
    STUMPS = mk(O, [24, 28, 30, 29])
    ROCKS = mk(O, [44, 49, 50, 53, 54, 56, 57, 59, 63]) + mk(SA, [20, 21, 22, 23])
    return TREES, SHRUBS, SHRUBS_DARK, MUSH, STUMPS, ROCKS

if __name__ == '__main__':
    root, ts = load(os.environ.get('HARITA_TMX'))
    lib = Lib(ts)
    TREES, SHRUBS, SHRUBS_DARK, MUSH, STUMPS, ROCKS = build(lib)
    groups = list(TREES.items()) + [('shrubs', SHRUBS), ('mush', MUSH), ('stumps', STUMPS), ('rocks', ROCKS)]
    sheet = Image.new('RGBA', (1500, 1400), (95, 150, 70, 255))
    x = y = 4; rowh = 0
    for name, lst in groups:
        print(name, [(s['name'], s['w'], s['h']) for s in lst])
        for st in lst:
            im = Image.fromarray(st['rgba'], 'RGBA')
            if x + im.width + 4 > sheet.width: x = 4; y += rowh + 4; rowh = 0
            sheet.alpha_composite(im, (x, y)); x += im.width + 6; rowh = max(rowh, im.height)
        x = 4; y += rowh + 8; rowh = 0
    sheet.crop((0, 0, 1500, y + 10)).save(sys.argv[1] if len(sys.argv) > 1 else 'stamps.png')
