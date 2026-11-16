"""Y SIRASI ÇEKİM NOKTALARI - oyunun KENDİ derinlik verisinden (2026-11-15). denetim.gd dökümünün "depth" bölümünden (ön kopya kök tabloları)
her katmanın en uzun nesneleri (ulaşılabilir alana yakın) için önünde / hemen arkasında / gövdesinin ortasında ayak noktaları ve bölünmüş
(dikey bitişik, farklı köklü) parça çiftleri için iki kök ARASINDA bir nokta yazar (üst parçanın kökü nesnenin ortasındaysa karakter o parçanın
ÜSTÜNE çizilir). Ana harita ve zindan haritaları için (üretilen haritalarda y_noktalar.py da var).
Kullanım: python -I tools/harita_cila/y_noktalar_dok.py <id> <çıktı.txt> [katman başına nesne=4] [bölünme örneği=16]
"""
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import analiz  # noqa: E402


def main():
    mid, out = sys.argv[1], sys.argv[2]
    per = int(sys.argv[3]) if len(sys.argv) > 3 else 4
    nsplit = int(sys.argv[4]) if len(sys.argv) > 4 else 16
    meta, g = analiz.load(mid)
    x0, y0, w, h = meta['rect']
    ox, oy, sc = meta['forest_xform']
    blocked = (g & analiz.B_WALL) > 0
    _, comps = analiz.components(~blocked)
    comps.sort(key=len, reverse=True)
    reach = analiz.np.zeros_like(blocked)
    for p in comps[0]:
        reach[p] = True

    def near_reach(px, py, r=3):
        cy, cx = int((py - oy) // 16) - y0, int((px - ox) // 16) - x0
        return reach[max(0, cy - r):cy + r + 1, max(0, cx - r):cx + r + 1].any()
    pts, info = [], {}
    for L in meta.get('depth', []):
        ofx, ofy = L['ofs']
        tag = re.sub(r'[^a-z0-9]', '', L['path'].split('/')[-1].lower().translate(str.maketrans('çğıöşü', 'cgiosu')))[:10]
        cand = []
        for gi, (gx0, gy0, gx1, gy1, root, n) in enumerate(L['groups']):
            top = ofy + gy0 * 16
            hgt = root - top
            cx = ofx + (gx0 + gx1 + 1) * 8
            if hgt >= 32 and near_reach(cx, root):
                cand.append((hgt, gi, cx, root))
        cand.sort(reverse=True)
        for hgt, gi, cx, root in cand[:per]:
            for nm, fy in (('on', root + 5), ('arka', root - 6), ('ic', root - min(hgt * 0.45, 40.0))):
                name = '%s%d_%s' % (tag, gi, nm)
                pts.append('%s:%.0f,%.0f' % (name, cx, fy))
                info[name] = {'layer': L['path'], 'h': hgt, 'root': root}
        k = 0
        for (ua, lb) in L['splits']:
            if k >= nsplit:
                break
            ug, lg = L['groups'][ua], L['groups'][lb]
            if ug[4] >= lg[4]:
                continue
            cx = ofx + (max(ug[0], lg[0]) + min(ug[2], lg[2]) + 1) * 8
            fy = (ug[4] + lg[4]) / 2.0
            if not near_reach(cx, fy):
                continue
            name = '%sB%d_%d' % (tag, ua, lb)
            pts.append('%s:%.0f,%.0f' % (name, cx, fy))
            info[name] = {'layer': L['path'], 'split': [ug, lg]}
            k += 1
    with open(out, 'w', encoding='utf-8') as f:
        f.write(';'.join(pts))
    json.dump(info, open(out + '.json', 'w', encoding='utf-8'), ensure_ascii=False)
    nspl = sum(len(L['splits']) for L in meta.get('depth', []))
    print('%s: %d derinlik katmanı, %d bölünme çifti (toplam), %d nokta -> %s' % (mid, len(meta.get('depth', [])), nspl, len(pts), out))
    for L in meta.get('depth', []):
        if L['splits']:
            print('   bölünme %-40s %d' % (L['path'], len(L['splits'])))


if __name__ == '__main__':
    main()
