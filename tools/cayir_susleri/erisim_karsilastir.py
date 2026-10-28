# -*- coding: utf-8 -*-
"""erisim_raporu.gd çıktılarını (bake öncesi / sonrası) karşılaştırır: yeni engel hücreleri + KOPAN hücreler (önce evden ulaşılabilen,
şimdi ulaşılamayan ama kendisi engel OLMAYAN = geçit/cep kapanmış). Kullanım: python -I tools/cayir_susleri/erisim_karsilastir.py [önce] [sonra]"""
import os
import sys

sys.stdout.reconfigure(encoding='utf-8')

HERE = os.path.dirname(os.path.abspath(__file__))


def load(p):
    r, b = set(), set()
    for line in open(p, encoding='utf-8'):
        k, xy = line.split()
        c = tuple(int(v) for v in xy.split(','))
        (r if k == 'R' else b).add(c)
    return r, b


def main():
    a = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, 'out', 'erisim_once.txt')
    b = sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, 'out', 'erisim_sonra.txt')
    r0, b0 = load(a)
    r1, b1 = load(b)
    new_block = b1 - b0
    gone_block = b0 - b1
    lost = r0 - r1
    cut = lost - new_block
    gained = r1 - r0
    print('ulaşılabilir: %d -> %d | yeni engel hücresi: %d (kalkan %d) | kaybedilen ulaşılabilir: %d | KOPAN (engel olmadan ulaşılamaz): %d | yeni ulaşılan: %d'
          % (len(r0), len(r1), len(new_block), len(gone_block), len(lost), len(cut), len(gained)))
    if cut:
        print('KOPAN hücreler:', sorted(cut)[:60])
    xs = [c[0] for c in new_block]
    ys = [c[1] for c in new_block]
    if new_block:
        print('yeni engel kutusu: x %d..%d y %d..%d' % (min(xs), max(xs), min(ys), max(ys)))
    ## dar aralık: yeni engel kümesinin 2 hücre (Chebyshev) yakınında ESKİ engel ya da ulaşılamaz hücre (duvar/su) = arada 1 hücrelik geçilmez boşluk
    narrow = []
    for c in sorted(new_block):
        for dx in range(-2, 3):
            for dy in range(-2, 3):
                n = (c[0] + dx, c[1] + dy)
                if max(abs(dx), abs(dy)) == 2 and n not in new_block and (n in b0 or n not in r0):
                    narrow.append((c, n))
    print('dar aralık (yeni engelin 2 hücre yakınında eski engel/duvar): %d' % len(narrow), narrow[:20])
    return 1 if cut else 0


if __name__ == '__main__':
    sys.exit(main())
