import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
"""DIS CERCEVE adim 3: sonlu Harita.tmx metnini SONSUZ (infinite) TMX'e cevir + yeni katmanlari ekle + dogrula.
Sadece her katmanin <data> blogu (ve katman etiketinin width/height'i) ile harita basligi degisir; geri kalan metin AYNEN korunur."""
import re
import xml.etree.ElementTree as ET
from ring_core import *

LAYER_RE = re.compile(r'(<layer id="(\d+)"[^>]*?)(>\s*)<data encoding="csv">(.*?)</data>(\s*</layer>)', re.S)


def write_tmx(src_path, out_path, B):
    text = open(src_path, encoding='utf-8').read()
    order = [p for p in B['order'] if p not in B['new_layers']]   # belgedeki sirayla (yeniler hariz)
    it = iter(order)
    count = 0

    def repl(m):
        nonlocal count
        path = next(it)
        count += 1
        head = re.sub(r'width="\d+" height="\d+"', f'width="{W2}" height="{H2}"', m.group(1), count=1)
        return f'{head}{m.group(3)}{data_block(B["grids"][path])}{m.group(5)}'

    text = LAYER_RE.sub(repl, text)
    assert count == len(order), (count, len(order))
    # yeni katmanlar: 'Orman parcalari 4' katmaninin hemen sonrasina (ayni grup)
    m = re.search(r'name="Orman parçaları 4".*?</layer>\n', text, re.S)
    assert m
    nid = int(re.search(r'nextlayerid="(\d+)"', text).group(1))
    new_xml = ''
    for name in B['new_layers']:
        label = name.split('/')[-1]
        new_xml += f'  <layer id="{nid}" name="{label}" width="{W2}" height="{H2}">\n{data_block(B["grids"][name])}\n  </layer>\n'
        nid += 1
    text = text[:m.end()] + new_xml + text[m.end():]
    # harita basligi
    text = re.sub(r'(<map [^>]*?)width="256" height="256"', rf'\1width="{W2}" height="{H2}"', text, count=1)
    text = text.replace('infinite="0"', 'infinite="1"', 1)
    text = re.sub(r'nextlayerid="\d+"', f'nextlayerid="{nid}"', text, count=1)
    open(out_path, 'w', encoding='utf-8', newline='\n').write(text)
    return text


def read_back(out_path):
    """Yazilan sonsuz TMX'i parcalardan (chunk) geri oku -> yol -> (H2,W2) izgara (dogrulama)."""
    root = ET.parse(out_path).getroot()
    assert root.get('infinite') == '1'
    res = {}

    def walk(el, pre):
        for c in el:
            if c.tag == 'group':
                walk(c, pre + [c.get('name')])
            elif c.tag == 'layer':
                g = np.zeros((H2, W2), np.int64)
                for ch in c.find('data').findall('chunk'):
                    cx, cy, cw, chh = int(ch.get('x')), int(ch.get('y')), int(ch.get('width')), int(ch.get('height'))
                    vals = np.array([int(v) for v in ch.text.replace('\n', '').split(',') if v.strip()], np.int64).reshape(chh, cw)
                    for yy in range(chh):
                        for xx in range(cw):
                            ax, ay = cx + xx, cy + yy
                            if X0 <= ax < X0 + W2 and Y0 <= ay < Y0 + H2:
                                g[ay - Y0, ax - X0] = vals[yy, xx]
                            else:
                                assert vals[yy, xx] == 0, ('halka disinda dolu hucre', ax, ay)
                res['/'.join(pre + [c.get('name')])] = g
    walk(root, [])
    return res
