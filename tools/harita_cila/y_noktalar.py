"""Y SIRASI ÇEKİM NOKTALARI (2026-11-15): üretilen haritanın (bataklik / col / kis) nesne listesinden (tools/<id>/out/nesneler.json + atlas.json)
her uzun nesne ailesinin (katman + ad kökü, boy >= ESIK px) en uzun örneği için üç ayak noktası yazar: önünde (kök + 5), hemen arkasında (kök - 6),
gövdesinin ortasında arkada (kök - boyun %45'i, en çok 40 px). Çıktı: tek satır "ad:x,y;..." (y_cekim.ps1 -NoktaDosyasi) + yanına .json (ad -> nesne).
Kullanım: python -I tools/harita_cila/y_noktalar.py <id> <çıktı.txt> [ESIK=36] [aile süzgeci virgüllü]
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def main():
    mid, out = sys.argv[1], sys.argv[2]
    esik = int(sys.argv[3]) if len(sys.argv) > 3 else 36
    only = set(sys.argv[4].split(',')) if len(sys.argv) > 4 and sys.argv[4] else None
    objs = json.load(open(os.path.join(ROOT, 'tools', mid, 'out', 'nesneler.json'), encoding='utf-8'))
    atlas = json.load(open(os.path.join(ROOT, 'tools', mid, 'atlas.json'), encoding='utf-8'))['objects']
    best = {}
    for o in objs:
        a = atlas.get(o['key'])
        if not a or a['h'] < esik:
            continue
        fam = re.sub(r'(_\d+)?(_[sg])?$', '', o['key'])
        layer = 'Agac' if o['layer'].startswith('Ağaç') else o['layer']
        k = (layer, fam)
        if only and fam not in only:
            continue
        if k not in best or a['h'] > best[k][1]['h']:
            best[k] = (o, a)
    pts, info = [], {}
    for (layer, fam), (o, a) in sorted(best.items()):
        flip = bool(o.get('flip', False))
        x0 = o['cx'] - a['wt'] // 2
        y0 = o['root'] - a['ht'] + 1
        left = x0 * 16 + ((a['wt'] * 16 - a['ox'] - a['w']) if flip else a['ox'])
        top = y0 * 16 + a['oy']
        root = top + a['h']
        cx = left + a['w'] / 2.0
        tag = re.sub(r'[^a-z0-9_]', '', (layer[:3] + '_' + fam).lower().replace('ç', 'c').replace('ğ', 'g').replace('ı', 'i')
                     .replace('ö', 'o').replace('ş', 's').replace('ü', 'u'))
        for nm, fy in (('on', root + 5), ('arka', root - 6), ('ic', root - min(a['h'] * 0.45, 40.0))):
            name = '%s_%s' % (tag, nm)
            pts.append('%s:%.0f,%.0f' % (name, cx, fy))
            info[name] = {'key': o['key'], 'layer': o['layer'], 'h': a['h'], 'w': a['w'], 'root': root, 'cx': cx}
    with open(out, 'w', encoding='utf-8') as f:
        f.write(';'.join(pts))
    json.dump(info, open(out + '.json', 'w', encoding='utf-8'), ensure_ascii=False)
    print('%d nesne, %d nokta -> %s' % (len(best), len(pts), out))


if __name__ == '__main__':
    main()
