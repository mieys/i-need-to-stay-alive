import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
"""DIS CERCEVE ana betik. Kullanim (proje kokunden):
  python -I tools/dis_cerceve/gen_ring.py <kaynak sonlu Harita.tmx> <cikti sonsuz Harita.tmx> <onizleme klasoru>
Kaynak TMX'i DEGISTIRMEZ; sadece cikti yolunu yazar (md5 kapisi ve uygulama ayri adimdadir)."""
import time
from ring_base import *
from ring_trees import place_forest
from ring_edge import complete_edges
from ring_write import write_tmx, read_back
from ring_stamps import Lib

NEW_LAYER_PREFIX = 'Orman parçaları/Dış orman '
INSERT_AFTER = 'Orman parçaları/Orman parçaları 4'


def build_all(src, log=print):
    root, ts = load(src)
    B = build_base(root, ts)
    lib = Lib(ts)
    complete_edges(B, ts, lib, log=log)
    new_layers, covered, placed = place_forest(B, lib, log=log)
    order = list(B['order'])
    idx = order.index(INSERT_AFTER) + 1
    names = []
    for i, g in enumerate(new_layers):
        nm = f'{NEW_LAYER_PREFIX}{i + 1}'
        B['grids'][nm] = g
        B['attrs'][nm] = {}
        names.append(nm)
    order[idx:idx] = names
    B['order'] = order
    B['new_layers'] = names
    B['root'] = root; B['ts'] = ts
    return B


def previews(B, outdir):
    ts = B['ts']
    vis = {p: B['attrs'][p].get('visible', '1') != '0' for p in B['order']}
    opac = {p: float(B['attrs'][p].get('opacity', '1')) for p in B['order']}
    regs = {'nw': (-32, -20, 64, 50), 'ne': (200, -20, 288, 50), 'se': (196, 176, 288, 276), 'sw': (-32, 190, 64, 276),
            'sbot': (60, 220, 200, 276), 'wmid': (-32, 90, 60, 170), 'emid': (200, 90, 288, 170), 'ntop': (60, -20, 200, 40)}
    for k, r in regs.items():
        im = render_region(ts, B['grids'], B['order'], vis, opac, r).convert('RGB')
        im.save(os.path.join(outdir, f'ring_{k}.png'))
    # tum harita kucuk
    full = render_region(ts, B['grids'], B['order'], vis, opac, (X0, Y0, X0 + W2, Y0 + H2)).convert('RGB')
    full.resize((W2 * 3, H2 * 3), Image.LANCZOS).save(os.path.join(outdir, 'ring_full.png'))


if __name__ == '__main__':
    t0 = time.time()
    src, out, outdir = sys.argv[1], sys.argv[2], sys.argv[3]
    B = build_all(src)
    print('uretim', round(time.time() - t0, 1), 's')
    write_tmx(src, out, B)
    back = read_back(out)
    assert set(back) == set(B['grids']), (set(back) ^ set(B['grids']))
    for k, g in B['grids'].items():
        assert (back[k] == g).all(), k
    # eski 256x256 veri BIREBIR korunmus mu (kaynak TMX'ten)
    root0, _ = load(src)
    for p0, l0 in layers(root0):
        k = '/'.join(p0)
        assert (back[k][play_slice()] == grid(l0)).all(), ('oyun alani degisti', k)
    print('yazildi + geri okuma dogrulandi:', out, round(os.path.getsize(out) / 1e6, 2), 'MB', round(time.time() - t0, 1), 's')
    if len(sys.argv) > 4 and sys.argv[4] == 'onizleme':
        previews(B, outdir)
