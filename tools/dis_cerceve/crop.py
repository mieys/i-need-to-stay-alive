import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_ring import *
SP = sys.argv[1]
B = build_all(sys.argv[2], log=lambda *a: None)
ts = B['ts']
vis = {p: B['attrs'][p].get('visible', '1') != '0' for p in B['order']}
opac = {p: float(B['attrs'][p].get('opacity', '1')) for p in B['order']}
for spec in sys.argv[3:]:
    name, x0, y0, x1, y1, sc = spec.split(',')
    im = render_region(ts, B['grids'], B['order'], vis, opac, (int(x0), int(y0), int(x1), int(y1))).convert('RGB')
    sc = float(sc)
    im = im.resize((int(im.width * sc), int(im.height * sc)), Image.NEAREST)
    im.save(os.path.join(SP, f'crop_{name}.png'))
