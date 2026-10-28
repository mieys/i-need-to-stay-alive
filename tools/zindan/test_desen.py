# ZİNDAN BOYAMA TEST DESENİ (madde 373): tüm duvar köşe durumlarını (dış/iç köşe, çentik, yarımada, basamak, T, ince sütun) içeren
# küçük bir ızgarayı seçilen zindanın boyayıcısıyla çizer -> tools/zindan/out/desen_<id>.png (3x). Duvar kenarı / zemin değişikliklerini
# tam haritayı üretmeden denemek için.  Kullanım: python tools/zindan/test_desen.py kemik|et|boynuz
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import zindan_core as Z  # noqa: E402

DESEN = """
########################################################
########################################################
########################################################
#####......................................#############
#####......................................#############
#####......................................#############
#####...######.......#####.........####....#############
#####...######.......#####.........####....#############
#####...######.......#####.........####........#########
#####...######.......##########....####........#########
#####...######.......##########....####........#########
#####...######.......##########....####........#########
#####...######.......##########................#########
#####........................#####.............#########
#####........................#####.............#########
#####.....................................##############
#####...........##########................##############
#####...........##########.......#####....##############
#####...........######...........#####....##############
#####...........######.....###...#####.....#############
#####.......####......#....###...#####.....#############
#####.......####......#....###.............#############
#####.......####...............................#########
#####.....###########..........................#########
#####.....###########.........########.........#########
#####.........................########.........#########
#####.........................########.........#########
#####..........................................#########
########################################################
########################################################
########################################################
"""


def layout():
    rows = [r for r in DESEN.strip('\n').split('\n')]
    h, w = len(rows), max(len(r) for r in rows)
    extra = 26  # sağa açık bir oda (oda zemini: levha / plaka / halı denemesi) + ona giden koridor
    lay = Z.Layout(w + extra, h, 1)
    t = np.full((h, w + extra), Z.S, dtype=lay.t.dtype)
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch == '.':
                t[y, x] = Z.F
    rx, ry, rw, rh = w + 2, 4, 21, 18
    t[ry:ry + rh, rx:rx + rw] = Z.F
    t[13:16, 43:rx] = Z.F
    lay.t = t
    lay.room_id[ry:ry + rh, rx:rx + rw] = 1
    lay.rooms = [Z.Room(0, 5, 3, 38, 25, 'oda'), Z.Room(1, rx, ry, rw, rh, 'kalp')]
    return lay


def main():
    which = sys.argv[1] if len(sys.argv) > 1 else 'kemik'
    mod = {'kemik': 'gen_kemik_mahzeni', 'et': 'gen_et_kuyusu', 'boynuz': 'gen_boynuzlu_kapi'}[which]
    gen = __import__(mod)
    lay = layout()
    bank, tl = gen.paint_test(lay)
    img = Z.render(bank, tl, lay.t.shape[1], lay.t.shape[0], skip=('Engel',))
    os.makedirs(Z.OUT, exist_ok=True)
    out = os.path.join(Z.OUT, 'desen_%s.png' % which)
    img.resize((img.width * 3, img.height * 3), Z.Image.NEAREST).save(out)
    print(out)


if __name__ == '__main__':
    main()
