"""NESNE-NESNE ÇİZİM SIRASI DENETİMİ (2026-11-15, kullanıcı: "Y ekseni sorunlarına çok özen göster, saçma sapan şeyler altta ya da üstte kalıyor").
Üretilen haritanın (bataklik / col / kis) üretecini yazmadan koşar, nesne modelini alır; iki nesnenin opak pikselleri aynı hücrede üst üste
biniyorsa çizimde ÜSTTE kalan (TMX katman sırası: sonraki katman üstte) ile üstte KALMASI GEREKEN (kökü daha güneyde = daha önde olan)
karşılaştırılır. Ters olanlar = Y hatası (arkadaki nesne öndekinin üstüne çiziliyor). Yere serili nesneler (yassi / leke / su süsü) hep altta = doğru.
Karakter-nesne sırası ayrı (depth_occluders.gd ön kopyaları); bu yalnız nesne-nesne.
Kullanım: python -I tools/harita_cila/nesne_sirasi.py <id> [en çok satır]
"""
import importlib.util
import os
import sys
import tempfile
from collections import defaultdict

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FLAT_KINDS = {'yassi', 'leke', 'su', 'cicek_yassi'}


def load_gen(mid):
    for p in (os.path.join(ROOT, 'tools'), os.path.join(ROOT, 'tools', mid)):
        if p not in sys.path:
            sys.path.insert(0, p)
    spec = importlib.util.spec_from_file_location('gen_' + mid, os.path.join(ROOT, 'tools', mid, 'gen_%s.py' % mid))
    g = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(g)
    return g


def build(mid):
    """üreteci yazmadan koşar (çıktı klasörü geçici), (modül, harita modeli, sayfalar) döner"""
    g = load_gen(mid)
    holder = {}
    orig_init = g.Map.__init__

    def init(self, *a, **k):
        orig_init(self, *a, **k)
        holder['m'] = self
    g.Map.__init__ = init
    orig_sheets = g.load_sheets

    def sheets(*a, **k):
        holder['imgs'] = orig_sheets(*a, **k)
        return holder['imgs']
    g.load_sheets = sheets
    g.OUT_DIR = tempfile.mkdtemp(prefix='nesne_sirasi_')
    argv = sys.argv
    sys.argv = ['gen']
    try:
        g.main()
    finally:
        sys.argv = argv
    return g, holder['m'], holder['imgs']


def conflicts(g, m, imgs):
    order = {}
    for i, (grp, name) in enumerate(g.LAYERS):
        order[name] = i
    if os.environ.get('CALILAR1_SON'):  ## deneme: "Çalılar1" nesne + ağaç katmanlarından SONRA çizilseydi
        order['Çalılar1'] = 10 ** 6
    cell_objs = defaultdict(list)
    for oi, o in enumerate(m.objects):
        for c in o['cells']:
            cell_objs[tuple(c)].append(oi)
    alpha_cache = {}

    def alpha(layer, c):
        v = m.layers[layer].get(c)
        if v is None:
            return None
        key = (layer, v if not isinstance(v, list) else tuple(v))
        if key not in alpha_cache:
            alpha_cache[key] = g.tile_rgba(imgs, *v)[..., 3] > 127
        return alpha_cache[key]
    pairs = defaultdict(int)
    for c, lst in cell_objs.items():
        if len(lst) < 2:
            continue
        for i in range(len(lst)):
            for j in range(i + 1, len(lst)):
                a, b = m.objects[lst[i]], m.objects[lst[j]]
                if a['layer'] == b['layer'] or a['root'] == b['root']:
                    continue
                la, lb = order.get(a['layer'], -1), order.get(b['layer'], -1)
                top, bot = (lst[i], lst[j]) if la > lb else (lst[j], lst[i])
                ot, ob = m.objects[top], m.objects[bot]
                if ob.get('kind') in FLAT_KINDS:
                    continue  ## yere serili nesnenin üstüne çizilmek doğru
                if ot['root'] > ob['root']:
                    continue  ## üstte çizilen zaten daha önde
                aa, ab = alpha(ot['layer'], c), alpha(ob['layer'], c)
                if aa is None or ab is None:
                    continue
                n = int((aa & ab).sum())
                if n:
                    pairs[(top, bot)] += n
    return pairs


def main():
    mid = sys.argv[1]
    lim = int(sys.argv[2]) if len(sys.argv) > 2 else 40
    g, m, imgs = build(mid)
    pairs = conflicts(g, m, imgs)
    by_kind = defaultdict(lambda: [0, 0])
    for (t, b), n in pairs.items():
        k = (m.objects[t]['layer'], m.objects[b]['layer'])
        by_kind[k][0] += 1
        by_kind[k][1] += n
    print('== %s: ters sıralı nesne çifti %d, piksel %d' % (mid, len(pairs), sum(pairs.values())))
    for k, (cnt, px) in sorted(by_kind.items(), key=lambda kv: -kv[1][1]):
        print('   üstte %-22s altta %-22s çift %-5d piksel %d' % (k[0], k[1], cnt, px))
    for (t, b), n in sorted(pairs.items(), key=lambda kv: -kv[1])[:lim]:
        ot, ob = m.objects[t], m.objects[b]
        print('   %4d px  ÜSTTE %s (%s, kök %d) <- ALTTA %s (%s, kök %d)  hücre %s' % (
            n, ot['key'], ot['layer'], ot['root'], ob['key'], ob['layer'], ob['root'], ob['cells'][len(ob['cells']) // 2]))


if __name__ == '__main__':
    main()
