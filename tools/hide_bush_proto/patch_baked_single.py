"""Saklanma çalılığı hücrelerini (place_lol.py -> out/lol_hucreler.json; eskiden place_single.py -> tek_hucreler.json) pişmiş haritaya (scenes/harita_baked.tscn) yazar: SADECE iki yer değişir -
(1) çalılık atlas kaynağının karo listesi (16 çeşit), (2) "Saklanma Çalılığı" katmanının tile_map_data'sı. Tam yeniden pişirme (tools/bake_harita.gd) gerekmez;
Harita.tmx ile birebir aynı hücreler. Kullanım: python -I tools/hide_bush_proto/patch_baked_single.py"""
import base64
import json
import os
import re
import shutil
import struct

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.normpath(os.path.join(HERE, '..', '..'))
TSCN = os.path.join(PROJECT, 'scenes', 'harita_baked.tscn')
import sys
CELLS = os.path.join(HERE, 'out', sys.argv[1] if len(sys.argv) > 1 else 'lol_hucreler.json')
ATLAS_COLS, ATLAS_ROWS = 16, (int(sys.argv[2]) if len(sys.argv) > 2 else 4)

text = open(TSCN, encoding='utf-8', newline='').read()
nl = '\r\n' if '\r\n' in text else '\n'
t = text.replace('\r\n', '\n')

# --- atlas kaynağı: texture = ExtResource(saklanma_calilik.png) olan TileSetAtlasSource
ext = re.search(r'\[ext_resource type="Texture2D"[^\n]*path="res://harita/saklanma_calilik.png" id="([^"]+)"\]', t)
assert ext, 'ext_resource yok'
ext_id = ext.group(1)
m = re.search(r'(\[sub_resource type="TileSetAtlasSource" id="([^"]+)"\]\ntexture = ExtResource\("%s"\)\n)((?:\d+:\d+/\d+ = \d+\n)+)' % re.escape(ext_id), t)
assert m, 'atlas kaynağı yok'
src_id = m.group(2)
old_n = m.group(3).count('\n')
tiles = ''.join('%d:%d/0 = 0\n' % (x, y) for y in range(ATLAS_ROWS) for x in range(ATLAS_COLS))
t = t[:m.start(3)] + tiles + t[m.end(3):]

# --- kaynak numarası (sources/N = SubResource(src_id))
sm = re.search(r'sources/(\d+) = SubResource\("%s"\)' % re.escape(src_id), t)
assert sm
source_index = int(sm.group(1))

# --- katman
nm = re.search(r'(\[node name="Saklanma Çalılığı" type="TileMapLayer"[^\n]*\]\ntexture_filter = 1\ntile_map_data = PackedByteArray\(")([^"]*)("\))', t)
assert nm, 'katman yok'
old = base64.b64decode(nm.group(2))
assert (len(old) - 2) % 12 == 0
cells = json.load(open(CELLS))
data = bytearray(old[:2])
for c in cells:
    data += struct.pack('<hhHHHH', c['x'], c['y'], source_index, c.get('ax', c.get('v', 0)), c.get('ay', 0), 0)
t = t[:nm.start(2)] + base64.b64encode(bytes(data)).decode() + t[nm.end(2):]

yedek = os.path.join(PROJECT, 'harita', 'yedek', 'harita_baked_2026-10-10_oncesi_%s.tscn.bak' % os.path.splitext(os.path.basename(CELLS))[0])
if not os.path.exists(yedek):
    shutil.copy2(TSCN, yedek)
open(TSCN, 'w', encoding='utf-8', newline='').write(t.replace('\n', nl))
print('tamam: kaynak', source_index, '| eski karo', old_n, '-> %d | eski hücre %d -> %d' % (ATLAS_COLS * ATLAS_ROWS, (len(old) - 2) // 12, len(cells)))
