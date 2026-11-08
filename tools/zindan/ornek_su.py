# ÖRNEKTEN SU KIYISI (madde 449): Dungeon3.tmx'teki su kıyılarını hücre hücre okur; komşuluk desenine (8 komşu su mu) göre örneğin kullandığı
# Water_coasts karolarını tablolar. gen_batik_nekropol.paint_water önce bu tabloya bakar, desen örnekte yoksa kendi kuralına düşer.
#   FLOOR[desen]  -> [(sütun, satır)]  kıyıdaki ZEMİN hücresinin karosu ('Zemin')
#   OVER[desen]   -> [(sütun, satır)]  SU hücresinin üstüne binen yüz/kenar parçası ('Zemin', su hücresinde)
#   SUB[desen]    -> [(sütun, satır)]  su altı karosu (batık duvar / tuğla, 'Su altı')
# desen: 8 bit (K, KD, D, GD, G, GB, B, KB) - zemin hücresi için "komşu su mu", su hücresi için "komşu zemin mi".
import os
import sys
from collections import Counter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ornek_tmx as OT  # noqa: E402
import zindan_core as Z  # noqa: E402

SAMPLE = os.path.join(Z.ART, 'Zindan Tileseti (Roguelike)', 'Tiled_files', 'Dungeon3.tmx')
DIRS = ((0, -1), (1, -1), (1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1))
BODY = (1, 30)


def mask(fn, x, y):
    m = 0
    for i, (dx, dy) in enumerate(DIRS):
        if fn(x + dx, y + dy):
            m |= 1 << i
    return m


D1_SAMPLE = os.path.join(Z.ART, 'Piksel Zindan Assetleri', 'Tiled_files', 'Dungeon1.tmx')
KZ_SAMPLE = os.path.join(Z.ART, 'Kanalizasyon Tileseti', 'Tiled_files', 'Inside.tmx')
# Kanalizasyon (Lağım Ağı, madde 449 3. harita): su = 'Bottom' (floor_walls_under_water), platform kıyıları 'floor' katmanında Water_coasts_topside
KZ_ARGS = dict(sample=KZ_SAMPLE, water=('Bottom',), floors=('floor',), under=('Walls_under_water',), coast_sheet='Water_coasts_topside')
# Piksel Zindan (Dungeon1, madde 449 2. harita): katman adları farklı, su gövdesi (7..11, 30) opak karolar (D3'te (1, 30)); (1..6, 30) saydam batık duvar
D1_ARGS = dict(sample=D1_SAMPLE, water=('water_floor3',), floors=('Floor2_pool', 'Floor', 'Floor2_darker_surface', 'Floor_darker_surface'),
               under=('walls_under_water',), body_cols=(7, 8, 9, 10, 11))


def learn(sample=SAMPLE, water=('Water',), floors=('Floor', 'Floor2', 'Floor3'), under=('Walls_under_water',), body_cols=None,
          coast_sheet='Water_coasts_animation'):
    """Varsayılanlar Dungeon3 (Batık Nekropol); başka set için D1_ARGS gibi. body_cols: su katmanında yalnız bu sütunlardaki 30. satır karoları
    su gövdesi sayılır (None = katmandaki her karo)."""
    s = OT.Sample(sample)
    L = dict(s.layers)
    for ln in tuple(water) + tuple(floors) + tuple(under):
        L.setdefault(ln, {})

    def in_water(p):
        for ln in water:
            g = L[ln].get(p)
            if not g:
                continue
            if body_cols is None:
                return True
            sh, lid = s.sheet_of(g)
            if sh.name == 'Water_coasts_animation' and lid // sh.cols == 30 and lid % sh.cols in body_cols:
                return True
        return False

    def coast(p, layers=tuple(floors)):
        for ln in layers:
            g = L[ln].get(p)
            if g:
                sh, lid = s.sheet_of(g)
                if sh.name == coast_sheet:
                    return (lid % sh.cols, lid // sh.cols), sh.tile(lid)
        return None, None

    def is_overlay(img):
        # su hücresine binen parça: karonun alt yarısı saydam (zemin karosu değil)
        a = img.getchannel('A').crop((0, 8, 16, 16))
        return a.getextrema()[1] == 0 or sum(1 for v in a.get_flattened_data() if v > 0) < 40

    kind = {}
    for y in range(s.y0, s.y1):
        for x in range(s.x0, s.x1):
            p = (x, y)
            if in_water(p):
                t, img = coast(p)
                kind[p] = 'W' if (t is None or is_overlay(img)) else 'F'
            elif any(p in L[ln] for ln in floors):
                kind[p] = 'F'
            else:
                kind[p] = 'S'

    def k(x, y):
        return kind.get((x, y), 'S')

    FLOOR, OVER, SUB = {}, {}, {}
    for (x, y), kd in kind.items():
        if kd == 'F':
            m = mask(lambda a, b: k(a, b) == 'W', x, y)
            if not m:
                continue
            t, _ = coast((x, y))
            if t is not None:
                FLOOR.setdefault(m, Counter())[t] += 1
        elif kd == 'W':
            if any(k(x + dx, y + dy) == 'S' for (dx, dy) in DIRS):
                continue  # duvara değen su (biz kullanmıyoruz)
            m = mask(lambda a, b: k(a, b) == 'F', x, y)
            t, _ = coast((x, y))
            if t is not None and m:
                OVER.setdefault(m, Counter())[t] += 1
            g = next((L[ln][(x, y)] for ln in under if (x, y) in L[ln]), None)
            if g and m:
                sh, lid = s.sheet_of(g)
                SUB.setdefault(m, Counter())[(lid % sh.cols, lid // sh.cols)] += 1
    flat = lambda d: {m: [t for t, _ in c.most_common()] for m, c in d.items()}  # noqa: E731
    return flat(FLOOR), flat(OVER), flat(SUB)


if __name__ == '__main__':
    F, O, S_ = learn()
    names = 'K KD D GD G GB B KB'.split()
    for title, d in (('ZEMİN', F), ('ÜSTÜNE', O), ('SU ALTI', S_)):
        print('==', title, len(d))
        for m, ts in sorted(d.items()):
            print('  %-22s %s' % ('+'.join(n for i, n in enumerate(names) if m >> i & 1), ts))
